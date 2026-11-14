#!/usr/bin/env python3
"""AncientBuilding 缓存与生成物盘点 / 清理。

用途：统计 Project/Generated/AncientBuilding 的体积与版本，扫描场景引用，
      只清理“旧版本且未被场景引用”的 Mesh/材料目录；当前生成器版本永不删除。
输入：仓库根下的 Project/；可用 --project / --root 覆盖。
输出：Markdown 或 JSON；--manifest 写 manifest.json 与 README.md；--prune 实际删除。
典型命令：
  .venv/Scripts/python.exe Tools/AncientBuilding/cache_report.py
  .venv/Scripts/python.exe Tools/AncientBuilding/cache_report.py --manifest
  .venv/Scripts/python.exe Tools/AncientBuilding/cache_report.py --prune --yes --manifest
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

MESH_REF = re.compile(r"Generated/AncientBuilding/Meshes/(v\d+)/")
MAT_REF = re.compile(r"Generated/AncientBuilding/Materials/([0-9a-fA-F]{8,})/")
VERSION_DIR = re.compile(r"^v(\d+)$")
MATERIAL_DIR = re.compile(r"^[0-9a-fA-F]{8,}$")


def human_bytes(value: int) -> str:
    size = float(value)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if size < 1024.0 or unit == "TiB":
            return f"{size:.1f} {unit}"
        size /= 1024.0
    return f"{value} B"


def dir_stats(path: Path) -> tuple[int, int]:
    files = 0
    size = 0
    if not path.is_dir():
        return 0, 0
    for root, _dirs, names in os.walk(path):
        for name in names:
            try:
                size += (Path(root) / name).stat().st_size
                files += 1
            except OSError:
                pass
    return files, size


def scan_references(project: Path) -> tuple[set[int], set[str], dict[str, int]]:
    versions: set[int] = set()
    materials: set[str] = set()
    by_scene: dict[str, int] = {}
    for path in project.rglob("*"):
        if path.suffix.lower() not in {".tscn", ".tres"}:
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        found = 0
        for match in MESH_REF.finditer(text):
            versions.add(int(match.group(1)[1:]))
            found += 1
        for match in MAT_REF.finditer(text):
            materials.add(match.group(1).lower())
            found += 1
        if found:
            by_scene[str(path.relative_to(project))] = found
    return versions, materials, by_scene


def read_current_version(project: Path) -> int:
    catalog = project / "addons" / "ancient_building" / "resources" / "module_catalog.json"
    try:
        data = json.loads(catalog.read_text(encoding="utf-8"))
        return int(data.get("generator_version", 0))
    except (OSError, ValueError, TypeError):
        return 0


def report(project: Path, root: Path, current: int) -> dict:
    referenced_versions, referenced_materials, by_scene = scan_references(project)
    mesh_root = root / "Meshes"
    versions: list[dict] = []
    if mesh_root.is_dir():
        for child in mesh_root.iterdir():
            match = VERSION_DIR.match(child.name) if child.is_dir() else None
            if not match:
                continue
            number = int(match.group(1))
            files, size = dir_stats(child)
            versions.append(
                {
                    "version": number,
                    "dir": child.name,
                    "files": files,
                    "bytes": size,
                    "referenced": number in referenced_versions,
                    "current": number == current,
                    "stale": number != current and number not in referenced_versions,
                }
            )
        versions.sort(key=lambda item: item["version"])
    material_root = root / "Materials"
    materials: list[dict] = []
    if material_root.is_dir():
        for child in sorted(material_root.iterdir(), key=lambda p: p.name):
            if not child.is_dir() or not MATERIAL_DIR.match(child.name):
                continue
            files, size = dir_stats(child)
            materials.append(
                {
                    "dir": child.name,
                    "files": files,
                    "bytes": size,
                    "referenced": child.name.lower() in referenced_materials,
                    "stale": child.name.lower() not in referenced_materials,
                }
            )
    samples_root = root / "Samples"
    samples: list[dict] = []
    if samples_root.is_dir():
        for child in sorted(samples_root.glob("*.tscn")):
            try:
                size = child.stat().st_size
            except OSError:
                size = 0
            samples.append({"name": child.name, "bytes": size})
    assembly_root = root / "Assemblies"
    assemblies: list[dict] = []
    if assembly_root.is_dir():
        for child in sorted(assembly_root.glob("*.tres")):
            try:
                size = child.stat().st_size
            except OSError:
                size = 0
            assemblies.append({"name": child.name, "bytes": size})
    assembly_files = len(assemblies)
    assembly_bytes = sum(a["bytes"] for a in assemblies)
    mesh_files = sum(v["files"] for v in versions)
    mesh_bytes = sum(v["bytes"] for v in versions)
    material_files = sum(m["files"] for m in materials)
    material_bytes = sum(m["bytes"] for m in materials)
    sample_files = len(samples)
    sample_bytes = sum(s["bytes"] for s in samples)
    stale_versions = [v for v in versions if v["stale"]]
    stale_materials = [m for m in materials if m["stale"]]
    return {
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "generator_version": current,
        "root": str(root),
        "referenced_versions": sorted(referenced_versions),
        "referenced_materials": sorted(referenced_materials),
        "scenes_with_references": by_scene,
        "meshes": {
            "versions": versions,
            "files": mesh_files,
            "bytes": mesh_bytes,
            "stale_versions": [v["version"] for v in stale_versions],
            "stale_bytes": sum(v["bytes"] for v in stale_versions),
        },
        "materials": {
            "dirs": materials,
            "files": material_files,
            "bytes": material_bytes,
            "stale_dirs": [m["dir"] for m in stale_materials],
            "stale_bytes": sum(m["bytes"] for m in stale_materials),
        },
        "samples": {
            "files": sample_files,
            "bytes": sample_bytes,
            "items": samples,
            "non_preset": [s["name"] for s in samples if not s["name"].startswith("DA_")],
        },
        "assemblies": {
            "files": assembly_files,
            "bytes": assembly_bytes,
            "items": assemblies,
        },
    }


def markdown(data: dict) -> str:
    lines: list[str] = []
    current = int(data["generator_version"])
    lines.append("# AncientBuilding 生成物盘点")
    lines.append("")
    lines.append("> 由 `Tools/AncientBuilding/cache_report.py` 生成；当前生成器 "
                 f"v{current}。`Generated/` 不入库，可安全重建。")
    lines.append("")
    lines.append("## 汇总")
    lines.append("")
    lines.append("| 区域 | 文件数 | 体积 |")
    lines.append("| --- | ---: | ---: |")
    lines.append(f"| Mesh 缓存 | {data['meshes']['files']} | {human_bytes(data['meshes']['bytes'])} |")
    lines.append(f"| 材料纹理 | {data['materials']['files']} | {human_bytes(data['materials']['bytes'])} |")
    lines.append(f"| Samples | {data['samples']['files']} | {human_bytes(data['samples']['bytes'])} |")
    lines.append(f"| Assemblies | {data['assemblies']['files']} | {human_bytes(data['assemblies']['bytes'])} |")
    lines.append("")
    lines.append("## Mesh 缓存版本")
    lines.append("")
    lines.append("| 版本 | 文件 | 体积 | 场景引用 | 处理 |")
    lines.append("| ---: | ---: | ---: | --- | --- |")
    for version in data["meshes"]["versions"]:
        if version["current"]:
            action = "保留（当前）"
        elif version["referenced"]:
            action = "保留（被引用）"
        else:
            action = "可清理"
        lines.append(
            f"| v{version['version']} | {version['files']} | {human_bytes(version['bytes'])} | "
            f"{'是' if version['referenced'] else '否'} | {action} |"
        )
    lines.append("")
    lines.append(f"旧版本可释放约 **{human_bytes(data['meshes']['stale_bytes'])}**。")
    lines.append("")
    lines.append("## 材料纹理")
    lines.append("")
    if data["materials"]["dirs"]:
        lines.append("| 目录 | 文件 | 体积 | 场景引用 | 处理 |")
        lines.append("| --- | ---: | ---: | --- | --- |")
        for item in data["materials"]["dirs"]:
            action = "保留" if item["referenced"] else "可清理"
            lines.append(
                f"| `{item['dir']}` | {item['files']} | {human_bytes(item['bytes'])} | "
                f"{'是' if item['referenced'] else '否'} | {action} |"
            )
    else:
        lines.append("（没有 hash 纹理目录）")
    lines.append("")
    lines.append("## Samples")
    lines.append("")
    for item in data["samples"]["items"]:
        lines.append(f"- `{item['name']}` — {human_bytes(item['bytes'])}")
    if data["samples"]["non_preset"]:
        lines.append("")
        lines.append("非预设命名的 Sample：" + "、".join(f"`{n}`" for n in data["samples"]["non_preset"]))
    lines.append("")
    lines.append("## Assemblies")
    lines.append("")
    if data["assemblies"]["items"]:
        for item in data["assemblies"]["items"]:
            lines.append(f"- `{item['name']}` — {human_bytes(item['bytes'])}")
    else:
        lines.append("（没有 assembly）")
    lines.append("")
    lines.append("Assemblies 是被 `AncientBuilding` 节点或场景引用的构建产物，工具不自动删除；重建见 `assembly` 命令。")
    lines.append("## 引用扫描")
    lines.append("")
    if data["scenes_with_references"]:
        for scene, count in sorted(data["scenes_with_references"].items()):
            lines.append(f"- `{scene}`：{count} 处")
    else:
        lines.append("没有场景引用 `Generated/AncientBuilding`。")
    lines.append("")
    lines.append("## 清理")
    lines.append("")
    if data.get("dry_run"):
        lines.append("当前为 dry-run，未删除任何文件。将处理：")
        for item in data.get("would_remove", []):
            lines.append(f"- `{item}`")
        lines.append("")
    if data.get("pruned"):
        pruned = data["pruned"]
        lines.append(f"本次已删除 {len(pruned['removed'])} 个目录，释放 {human_bytes(pruned['freed_bytes'])}。")
        for item in pruned["removed"]:
            lines.append(f"- `{item}`")
        lines.append("")
    lines.append("```bash")
    lines.append(".venv/Scripts/python.exe Tools/AncientBuilding/cache_report.py --prune --yes --manifest")
    lines.append("```")
    lines.append("")
    lines.append("只删除 `stale` 的旧版本 Mesh 目录和未引用材料目录；当前版本与任何被场景引用的版本都会保留。")
    lines.append("")
    return "\n".join(lines)


def write_manifest(root: Path, data: dict) -> None:
    root.mkdir(parents=True, exist_ok=True)
    manifest = {
        "tool": "Tools/AncientBuilding/cache_report.py",
        "generated_at": data["generated_at"],
        "generator_version": data["generator_version"],
        "meshes": {
            "files": data["meshes"]["files"],
            "bytes": data["meshes"]["bytes"],
            "versions": data["meshes"]["versions"],
            "stale_versions": data["meshes"]["stale_versions"],
        },
        "materials": {
            "files": data["materials"]["files"],
            "bytes": data["materials"]["bytes"],
            "dirs": data["materials"]["dirs"],
        },
        "samples": data["samples"],
        "assemblies": data["assemblies"],
        "rebuild": [
            ".venv/Scripts/python.exe Tools/AncientBuilding/build_materials.py --engine Engine/bin/godot.windows.editor.x86_64.console.exe",
            "Engine/bin/godot.windows.editor.x86_64.console.exe --headless --path Project --script res://addons/ancient_building/cli/main.gd -- assembly --file <preset.json>",
            "Engine/bin/godot.windows.editor.x86_64.console.exe --headless --path Project --script res://addons/ancient_building/cli/main.gd -- bake --file <preset.json> --out <scene.tscn>",
            ".venv/Scripts/python.exe Tools/AncientBuilding/cache_report.py --manifest",
        ],
    }
    (root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    readme = [
        "# AncientBuilding 生成物",
        "",
        "本目录由生成器重建，不入库。当前生成器 v"
        f"{data['generator_version']}。",
        "",
        "重建顺序：",
        "1. 材质：`.venv/Scripts/python.exe Tools/AncientBuilding/build_materials.py --engine <godot console>`",
        "2. 装配体：CLI `assembly --file <preset.json>` 生成 `Assemblies/*.tres`（运行时节点用）",
        "3. 旧式场景（可选）：CLI `bake --file <preset.json>` 生成 `Samples/*.tscn`",
        "4. 盘点/清理：`.venv/Scripts/python.exe Tools/AncientBuilding/cache_report.py --prune --yes --manifest`",
        "",
        "不要删除当前版本 `Meshes/v" + str(data["generator_version"]) + "/`；",
        "它是已烘焙场景/装配体的外部引用。旧版本先看 `cache_report.py` 的扫描结果再清理。",
        "",
        "详见 `Wiki/Temp/008-AncientBuilding.md` §13.5。",
        "",
    ]
    (root / "README.md").write_text("\n".join(readme), encoding="utf-8")


def prune(root: Path, data: dict) -> dict:
    removed: list[str] = []
    freed = 0
    for version in data["meshes"]["versions"]:
        if not version["stale"]:
            continue
        path = root / "Meshes" / version["dir"]
        if path.is_dir():
            shutil.rmtree(path)
            removed.append(f"Meshes/{version['dir']}")
            freed += int(version["bytes"])
    for item in data["materials"]["dirs"]:
        if not item["stale"]:
            continue
        path = root / "Materials" / item["dir"]
        if path.is_dir():
            shutil.rmtree(path)
            removed.append(f"Materials/{item['dir']}")
            freed += int(item["bytes"])
    return {"removed": removed, "freed_bytes": freed}


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default=None, help="Project 目录，默认 <repo>/Project")
    parser.add_argument("--root", default=None, help="生成物根目录，默认 <project>/Generated/AncientBuilding")
    parser.add_argument("--format", choices=("md", "json"), default="md")
    parser.add_argument("--manifest", action="store_true", help="写 manifest.json 与 README.md")
    parser.add_argument("--prune", action="store_true", help="删除 stale 目录")
    parser.add_argument("--yes", action="store_true", help="与 --prune 一起确认实际删除")
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[2]
    project = Path(args.project).resolve() if args.project else repo / "Project"
    root = Path(args.root).resolve() if args.root else project / "Generated" / "AncientBuilding"
    if not project.is_dir():
        print(f"Project not found: {project}", file=sys.stderr)
        return 1
    if not root.is_dir():
        print(f"Generated root not found: {root}", file=sys.stderr)
        return 1
    current = read_current_version(project)
    data = report(project, root, current)
    if args.prune:
        if not args.yes:
            data["dry_run"] = True
            data["would_remove"] = [f"Meshes/v{v}" for v in data["meshes"]["stale_versions"]] + [
                f"Materials/{d}" for d in data["materials"]["stale_dirs"]
            ]
        else:
            pruned = prune(root, data)
            data = report(project, root, current)
            data["pruned"] = pruned
    if args.manifest:
        write_manifest(root, data)
    if args.format == "json":
        print(json.dumps(data, ensure_ascii=False, indent=2))
    else:
        print(markdown(data))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
