"""可重复离线烘焙 AncientBuilding 程序 PBR；不依赖 Blender 或外部素材。

Usage (repository root):
    python Tools/AncientBuilding/build_materials.py
    python Tools/AncientBuilding/build_materials.py --resolution 2048 --seed 82173
    python Tools/AncientBuilding/build_materials.py --engine Engine/bin/godot.windows.editor.x86_64.console.exe

Requires: numpy, Pillow (authoring only). Input:
Project/Data/Profiles/AncientBuilding/DA_SurfaceLibrary.json
Output: Project/Generated/AncientBuilding/Materials/<content-hash>/T_<Family>_{BC,N,ORM}.png
Index:  Project/Generated/AncientBuilding/Materials/DA_SurfaceLibrary.json

源配方、脚本、参数及外部输入内容共同决定摘要；命中完整输出时复用缓存。
改变尺寸应修改 tile_size_m；这会同时影响法线坡度与运行时纹理重复尺度。
木纹沿纹理 V。PNG 行号向下：NormalGL = normalize(-dH/dU, +dH/drow, 1)。
AO 是高度凹陷的局部遮蔽近似，不是整栋建筑的烘焙光照。材质没有瓦缝或砖缝。

可用自己许可明确的成套贴图替换某族，在其源配方加入：
"source": {"base_color": "res://Assets/..._BC.png", "normal": "res://Assets/..._N.png",
           "orm": "res://Assets/..._ORM.png", "normal_format": "OpenGL"}
仅支持工程内文件；BC/N/ORM 同尺寸同 UV，法线重采样后归一，不做联网下载。
--force 重写当前内容摘要的派生图；不删除历史摘要或其他资产。
--engine 在 .build-temp 下创建仅含当前 24 张图的隔离工程，保持相同 res:// 路径导入，
只回写这些图的 .import、ctex 和 md5，避免扫描主工程历史网格。退出后清理隔离目录。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "Project"
SOURCE = PROJECT / "Data/Profiles/AncientBuilding/DA_SurfaceLibrary.json"
OUTPUT = PROJECT / "Generated/AncientBuilding/Materials"
FAMILIES = ("Wood", "WoodEnd", "Tile", "Plaster", "Earth", "Stone", "Reed", "Thatch")


def smoothstep(low, high, value):
	t = np.clip((value - low) / (high - low), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def wrap_distance(value):
	return (value + 0.5) % 1.0 - 0.5


def srgb_to_linear(color):
	return np.where(color <= 0.04045, color / 12.92, ((color + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(color):
	color = np.clip(color, 0.0, 1.0)
	return np.where(color <= 0.0031308, color * 12.92, 1.055 * color ** (1.0 / 2.4) - 0.055)


def color_array(hex_color):
	if not isinstance(hex_color, str) or len(hex_color) != 7 or hex_color[0] != "#":
		raise ValueError("reference_color_srgb must be #RRGGBB")
	return np.array([int(hex_color[i:i + 2], 16) / 255.0 for i in (1, 3, 5)], dtype=np.float32)


class Field:
	"""周期晶格噪声；频率为整数，所有随机数仅依赖族种子。"""

	def __init__(self, resolution, seed):
		self.n = resolution
		self.rng = np.random.default_rng(seed)
		axis = (np.arange(resolution, dtype=np.float32) + 0.5) / resolution
		self.u, self.v = np.meshgrid(axis, axis)

	def noise(self, nx, ny, u=None, v=None):
		u = self.u if u is None else u
		v = self.v if v is None else v
		lattice = self.rng.random((ny, nx), dtype=np.float32)
		x, y = u * nx, v * ny
		ix, iy = np.floor(x).astype(np.int32), np.floor(y).astype(np.int32)
		fx, fy = x - ix, y - iy
		fx = fx * fx * fx * (fx * (fx * 6 - 15) + 10)
		fy = fy * fy * fy * (fy * (fy * 6 - 15) + 10)
		a = lattice[iy % ny, ix % nx] * (1 - fx) + lattice[iy % ny, (ix + 1) % nx] * fx
		b = lattice[(iy + 1) % ny, ix % nx] * (1 - fx) + lattice[(iy + 1) % ny, (ix + 1) % nx] * fx
		return (a * (1 - fy) + b * fy).astype(np.float32)

	def cloud(self):
		return self.noise(4, 4) * 0.56 + self.noise(13, 13) * 0.29 + self.noise(41, 41) * 0.15


def wood(f):
	u, v = f.u, f.v
	warp = (f.noise(6, 3) - 0.5) * 0.018 + np.sin(v * math.tau * 2) * 0.003
	knot = np.zeros_like(u)
	knot_rings = np.zeros_like(u)
	for _ in range(2):
		x, y = f.rng.uniform(0.1, 0.9, 2)
		dx = wrap_distance(u - x)
		dy = wrap_distance(v - y)
		radius = np.sqrt((dx / 0.085) ** 2 + (dy / 0.048) ** 2 + 0.001)
		mask = np.exp(-radius * radius * 0.65)
		warp += dx * mask * 0.60
		knot = np.maximum(knot, np.exp(-radius * radius * 3.2))
		knot_rings += mask * (0.5 + 0.5 * np.sin(radius * 15))
	grain_u = u + warp
	annual = 0.5 + 0.5 * np.sin((grain_u * 28 + f.noise(7, 4) * 0.32) * math.tau)
	fiber = f.noise(230, 9, grain_u, v)
	long = f.noise(63, 3, grain_u, v)
	fine = f.noise(420, 79, grain_u, v)
	crack = np.zeros_like(u)
	for _ in range(12):
		x, y = f.rng.random(2)
		width = f.rng.uniform(0.0014, 0.0035)
		length = f.rng.uniform(0.025, 0.13)
		dx = wrap_distance(grain_u - x)
		dy = wrap_distance(v - y)
		line = np.exp(-(dx / width) ** 2 * 2) * np.exp(-(dy / length) ** 4)
		crack = np.maximum(crack, line * (0.60 + 0.40 * long))
	weather = f.noise(6, 8)
	tone = 0.87 + 0.15 * long + 0.09 * fiber + 0.06 * annual + 0.10 * weather
	tone -= 0.36 * crack + 0.24 * knot + 0.07 * knot_rings
	height = 0.00030 * annual + 0.00025 * fiber + 0.00012 * fine + 0.00032 * long
	height -= 0.00078 * crack + 0.00012 * knot_rings
	return height, tone, 0.08 * (weather - 0.5) + 0.05 * crack, crack * 0.24, None


def wood_end(f):
	u, v = f.u, f.v
	# 正弦嵌入形成连续环纹；边界处梯度连续，避免径向距离在图边折断。
	x = np.sin(math.pi * (u - 0.5))
	y = np.sin(math.pi * (v - 0.5))
	radius = np.sqrt(x * x + y * y + 0.001)
	warp = f.noise(11, 11) * 0.28 + f.noise(4, 4) * 0.45
	ring = 0.5 + 0.5 * np.sin((radius * 23 + warp) * math.tau)
	latewood = smoothstep(0.67, 0.91, ring)
	fine = f.noise(280, 280)
	pores = smoothstep(0.72, 0.91, fine)
	cloud = f.cloud()
	height = 0.00019 * ring + 0.00010 * fine - pores * 0.00025
	tone = 0.96 + cloud * 0.15 - latewood * 0.17 - pores * 0.13
	return height, tone, (cloud - 0.5) * 0.08, pores * 0.15, None


def mineral(f, kind):
	cloud = f.cloud()
	grit = f.noise(186, 186)
	fine = f.noise(389, 389)
	pores = smoothstep(0.70, 0.93, grit)
	if kind == "Tile":
		fired = f.noise(11, 17)
		height = (grit - 0.5) * 0.00022 + (fine - 0.5) * 0.00008 - pores * 0.00022
		height += (fired - 0.5) * 0.00030
		tone = 0.86 + cloud * 0.20 + fired * 0.10 - pores * 0.10
		tint = np.stack((1 + fired * 0.045, np.ones_like(fired), 1 - fired * 0.045), axis=-1)
		return height, tone, (fired - 0.5) * 0.13 + pores * 0.04, pores * 0.14, tint
	if kind == "Plaster":
		strokes = f.noise(19, 7) * 0.48 + f.noise(9, 28) * 0.52
		edge = smoothstep(0.42, 0.58, strokes)
		height = (edge - 0.5) * 0.00065 + grit * 0.00025 - pores * 0.00045
		tone = 0.88 + cloud * 0.18 + strokes * 0.06 - pores * 0.08
		return height, tone, (cloud - 0.5) * 0.05, pores * 0.10, None
	if kind == "Earth":
		phase = f.v * 17 + (f.noise(8, 3) - 0.5) * 0.22
		layers = 0.5 + 0.5 * np.sin(phase * math.tau)
		aggregate = f.noise(82, 82)
		top = smoothstep(0.73, 0.92, aggregate)
		height = grit * 0.00055 + aggregate * 0.0010 + layers * 0.00042 - pores * 0.0004
		tone = 0.82 + cloud * 0.20 + layers * 0.07 + aggregate * 0.12 - pores * 0.10
		tint = np.stack((1 + top * 0.06, 1 + top * 0.025, 1 - top * 0.025), axis=-1)
		return height, tone, (aggregate - 0.5) * 0.05, pores * 0.12, tint
	tooling = f.noise(67, 18)
	crystal = f.noise(103, 119)
	dark = smoothstep(0.71, 0.89, crystal)
	height = (grit - 0.5) * 0.00065 + (tooling - 0.5) * 0.00075 + fine * 0.00009
	tone = 0.83 + cloud * 0.22 + crystal * 0.10 - dark * 0.10
	return height, tone, (tooling - 0.5) * 0.12, dark * 0.08, None


def reed(f):
	u, v = f.u, f.v
	phase = u * 18
	center_distance = (phase + 0.5) % 1.0 - 0.5
	strand = np.sqrt(np.clip(1 - (center_distance * 2.05) ** 2, 0, 1))
	color_by_strand = f.noise(18, 2, (np.floor(phase) + 0.5) / 18, v)
	fiber = f.noise(420, 17)
	thread_distance = np.abs((v * 3 + 0.5) % 1.0 - 0.5)
	thread = np.exp(-(thread_distance / 0.035) ** 2)
	# 横向绑线在苇条上下交替，BC、法线和遮蔽共享同一经纬关系。
	over = np.cos(phase * math.pi) * 0.5 + 0.5
	height = strand * 0.00110 + fiber * 0.00010 + thread * (over * 0.00055 + 0.00015)
	groove = 1 - smoothstep(0.1, 0.35, strand)
	tone = 0.83 + color_by_strand * 0.20 + strand * 0.08 + fiber * 0.04
	tone *= 1 - thread * 0.19 - groove * 0.15
	return height, tone, (fiber - 0.5) * 0.05, groove * 0.22 + thread * (1 - over) * 0.10, None


def thatch(f):
	u, v = f.u, f.v
	warp = (f.noise(19, 5) - 0.5) * 0.003
	phase = (u + warp) * 128
	fiber = (0.5 + 0.5 * np.sin(phase * math.tau)) ** 0.55
	bundle = f.noise(25, 5)
	stalks = f.noise(128, 6, (np.floor(phase) + 0.5) / 128, v)
	fine = f.noise(430, 41)
	height = fiber * 0.00085 + bundle * 0.00095 + fine * 0.00010
	tone = 0.78 + stalks * 0.28 + bundle * 0.14 + fiber * 0.08
	tint = np.stack((1 + stalks * 0.06, np.ones_like(stalks), 1 - stalks * 0.04), axis=-1)
	return height, tone, (stalks - 0.5) * 0.06, (1 - fiber) * 0.15, tint


def generated_maps(name, config, resolution, seed):
	family_seed = int.from_bytes(hashlib.sha256(f"{seed}:{name}".encode()).digest()[:8], "little")
	f = Field(resolution, family_seed)
	if name == "Wood":
		result = wood(f)
	elif name == "WoodEnd":
		result = wood_end(f)
	elif name == "Reed":
		result = reed(f)
	elif name == "Thatch":
		result = thatch(f)
	else:
		result = mineral(f, name)
	height, tone, rough_offset, cavity, tint = result
	height *= float(config.get("height_scale", 1.0))
	base = srgb_to_linear(color_array(config["reference_color_srgb"]))
	color = base * tone[..., None]
	if tint is not None:
		color *= tint
	bc = linear_to_srgb(color)
	size_u, size_v = config["tile_size_m"]
	du = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * resolution / (2 * size_u)
	dv = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * resolution / (2 * size_v)
	normal = np.stack((-du, dv, np.ones_like(du)), axis=-1)
	normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
	roughness = np.clip(float(config["roughness"]) + rough_offset, 0.18, 1.0)
	orm = np.stack((np.clip(1 - cavity, 0.45, 1), roughness, np.zeros_like(height)), axis=-1)
	return {"BC": bc, "N": normal * 0.5 + 0.5, "ORM": orm}


def source_path(value):
	if not isinstance(value, str) or not value.startswith("res://"):
		raise ValueError("External input paths must use res:// inside Project")
	path = (PROJECT / value[6:]).resolve()
	if not path.is_relative_to(PROJECT.resolve()) or not path.is_file():
		raise ValueError(f"Missing or out-of-project material input: {value}")
	return path


def imported_maps(config, resolution):
	source = config["source"]
	if source.get("normal_format") != "OpenGL":
		raise ValueError("External source requires normal_format: OpenGL")
	maps = {}
	sizes = []
	for channel, key in (("BC", "base_color"), ("N", "normal"), ("ORM", "orm")):
		with Image.open(source_path(source[key])) as image:
			sizes.append(image.size)
			image = image.convert("RGB").resize((resolution, resolution), Image.Resampling.BICUBIC)
			maps[channel] = np.asarray(image, dtype=np.float32) / 255.0
	if len(set(sizes)) != 1:
		raise ValueError("External BC/N/ORM must have equal dimensions and matching UV")
	normal = maps["N"] * 2 - 1
	normal /= np.maximum(np.linalg.norm(normal, axis=-1, keepdims=True), 0.0001)
	maps["N"] = normal * 0.5 + 0.5
	return maps


def save_maps(directory, name, maps):
	for channel, pixels in maps.items():
		if not np.isfinite(pixels).all():
			raise ValueError(f"Non-finite {name} {channel} pixels")
		encoded = np.rint(np.clip(pixels, 0, 1) * 255).astype(np.uint8)
		Image.fromarray(encoded).save(directory / f"T_{name}_{channel}.png", compress_level=6)


def import_settings(path, normal):
	"""只维护制作约定；保留 Godot 已生成的 UID、deps、平台路径等内容。"""
	meta = Path(str(path) + ".import")
	text = meta.read_text(encoding="utf-8") if meta.exists() else (
		'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n'
	)
	settings = {"mipmaps/generate": "true", "compress/mode": "0",
		"compress/normal_map": "1" if normal else "0", "detect_3d/compress_to": "0"}
	if "[params]" not in text:
		text += "\n[params]\n"
	start = text.index("[params]") + len("[params]")
	end_match = re.search(r"^\[", text[start:], re.MULTILINE)
	end = start + end_match.start() if end_match else len(text)
	params = text[start:end]
	for key, value in settings.items():
		pattern = re.compile(r"^" + re.escape(key) + r"=.*$", re.MULTILINE)
		if pattern.search(params):
			params = pattern.sub(key + "=" + value, params)
		else:
			params = params.rstrip() + "\n" + key + "=" + value + "\n"
	updated = text[:start] + params + text[end:]
	if updated != text or not meta.exists():
		meta.write_text(updated, encoding="utf-8", newline="\n")


def import_with_engine(engine, directory):
	"""使用相同资源路径的最小工程导入当前纹理，不启动主工程插件或扫描网格缓存。"""
	engine = engine.expanduser().resolve()
	if not engine.is_file():
		raise ValueError(f"Godot engine not found: {engine}")
	scratch = (ROOT / ".build-temp").resolve()
	scratch.mkdir(parents=True, exist_ok=True)
	stage = Path(tempfile.mkdtemp(prefix="ancient_material_import_", dir=scratch)).resolve()
	if stage.parent != scratch or not stage.name.startswith("ancient_material_import_"):
		raise ValueError("Isolated import directory must remain directly inside .build-temp")
	try:
		(stage / "project.godot").write_text(
			'config_version=5\n\n[application]\nconfig/name="AncientMaterialImport"\n'
			'\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
		pngs = [directory / f"T_{name}_{channel}.png" for name in FAMILIES for channel in ("BC", "N", "ORM")]
		for png in pngs:
			local = stage / png.relative_to(PROJECT)
			local.parent.mkdir(parents=True, exist_ok=True)
			shutil.copy2(png, local)
			shutil.copy2(Path(str(png) + ".import"), Path(str(local) + ".import"))
		env = os.environ.copy()
		env["APPDATA"] = str(ROOT / ".appdata")
		env["LOCALAPPDATA"] = env["APPDATA"]
		log_path = stage / "import.log"
		command = [str(engine), "--headless", "--path", str(stage), "--editor", "--import"]
		print("IMPORTING 24 textures in isolated project (no historical mesh scan)", flush=True)
		with log_path.open("wb") as log:
			process = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT,
				timeout=300, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
		log_text = log_path.read_text(encoding="utf-8", errors="replace")
		if process.returncode != 0 or re.search(r"(?:^|\n)(?:ERROR|SCRIPT ERROR):", log_text):
			raise RuntimeError(f"Isolated Godot import failed ({process.returncode}):\n{log_text[-5000:]}")
		# 先完整核实 24 张图的输出，再发布任何 remap，避免半成品破坏当前材质入口。
		copies = {}
		cache = (stage / ".godot/imported").resolve()
		texture_count = 0
		for png in pngs:
			meta = Path(str(stage / png.relative_to(PROJECT)) + ".import")
			text = meta.read_text(encoding="utf-8")
			outputs = set(re.findall(r'"res://(\.godot/imported/[^"\r\n]+\.ctex)"', text))
			if not outputs:
				raise RuntimeError(f"Godot produced no texture remap for {png.name}")
			for output in outputs:
				resource = (stage / output).resolve()
				if resource.parent != cache or not resource.is_file() or resource.stat().st_size == 0:
					raise RuntimeError(f"Invalid isolated texture output: {output}")
				md5 = resource.with_suffix(".md5")
				if not md5.is_file():
					raise RuntimeError(f"Missing import digest: {md5.name}")
				copies[resource] = PROJECT / output
				copies[md5] = PROJECT / md5.relative_to(stage)
				texture_count += 1
			copies[meta] = Path(str(png) + ".import")
		for source, target in copies.items():
			if not target.resolve().is_relative_to(PROJECT.resolve()):
				raise ValueError("Imported output escaped Project")
			target.parent.mkdir(parents=True, exist_ok=True)
			shutil.copy2(source, target)
		print(f"ANCIENT_MATERIAL_IMPORT_OK textures={texture_count} metadata=24 md5={texture_count}", flush=True)
	finally:
		# 仅清理由本次 mkdtemp 创建且仍位于指定根下的目录，不删除主工程缓存。
		resolved = stage.resolve()
		if resolved.parent != scratch or not resolved.name.startswith("ancient_material_import_"):
			raise RuntimeError("Refusing cleanup outside the isolated import directory")
		shutil.rmtree(resolved)


def main():
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--recipe", type=Path, default=SOURCE)
	parser.add_argument("--resolution", type=int)
	parser.add_argument("--seed", type=int)
	parser.add_argument("--force", action="store_true")
	parser.add_argument("--engine", type=Path, help="Import only current textures using an isolated Godot project")
	args = parser.parse_args()
	recipe = json.loads(args.recipe.read_text(encoding="utf-8"))
	resolution = args.resolution or int(recipe["resolution"])
	seed = args.seed if args.seed is not None else int(recipe["seed"])
	if resolution not in (256, 512, 1024, 2048, 4096):
		raise ValueError("resolution must be 256, 512, 1024, 2048 or 4096")
	if set(recipe["families"]) != set(FAMILIES):
		raise ValueError("Recipe must declare all eight supported families")
	digest = hashlib.sha256()
	digest.update(Path(__file__).read_bytes())
	digest.update(json.dumps(recipe, sort_keys=True, separators=(",", ":")).encode())
	digest.update(f"{resolution}:{seed}".encode())
	for name in FAMILIES:
		config = recipe["families"][name]
		size = config["tile_size_m"]
		if len(size) != 2 or any(not math.isfinite(float(s)) or float(s) <= 0 for s in size):
			raise ValueError(f"Invalid tile_size_m for {name}")
		color_array(config["reference_color_srgb"])
		if "source" in config:
			for key in ("base_color", "normal", "orm"):
				digest.update(source_path(config["source"][key]).read_bytes())
	content_hash = digest.hexdigest()[:20]
	directory = OUTPUT / content_hash
	directory.mkdir(parents=True, exist_ok=True)
	manifest = {"version": 1, "content_hash": content_hash, "seed": seed, "resolution": resolution,
		"normal_convention": "OpenGL +Y; PNG rows down: normalize(-dHdu,+dHdv,1)",
		"orm_channels": {"R": "ambient_occlusion", "G": "roughness", "B": "metallic"}, "families": {}}
	built = 0
	for name in FAMILIES:
		config = recipe["families"][name]
		paths = {channel: directory / f"T_{name}_{channel}.png" for channel in ("BC", "N", "ORM")}
		if args.force or not all(path.is_file() for path in paths.values()):
			maps = imported_maps(config, resolution) if "source" in config else generated_maps(name, config, resolution, seed)
			save_maps(directory, name, maps)
			built += 1
			print(f"BAKED {name} {resolution}x{resolution}", flush=True)
		for channel, path in paths.items():
			import_settings(path, channel == "N")
		entry = {key: "res://" + paths[channel].relative_to(PROJECT).as_posix()
			for key, channel in (("base_color", "BC"), ("normal", "N"), ("orm", "ORM"))}
		entry.update(tile_size_m=config["tile_size_m"], reference_color_srgb=config["reference_color_srgb"])
		entry["source"] = "external" if "source" in config else "original_procedural"
		manifest["families"][name] = entry
	if args.engine is not None:
		import_with_engine(args.engine, directory)
	text = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"
	index = OUTPUT / "DA_SurfaceLibrary.json"
	# 发布索引最后一步进行；失败的烘焙不改变当前可用材质入口。
	if not index.exists() or index.read_text(encoding="utf-8") != text:
		index.write_text(text, encoding="utf-8", newline="\n")
	print(f"ANCIENT_MATERIALS_OK families=8 generated={built} cached={8-built} resolution={resolution} hash={content_hash}")


if __name__ == "__main__":
	main()
