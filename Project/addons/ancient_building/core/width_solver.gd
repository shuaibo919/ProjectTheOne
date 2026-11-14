extends RefCounted
## 宽度求解器（spec 008 §11.2）。
## S：阈值内单实例缩放；超阈值复制 n 份，每份缩放 s = W/(n·unit) ≤ MaxStretch。
## R：按单元数复制，实例不缩放（scale = 1），间距均分。
## A：刚体，恒 1 个实例。
## P：参数化重建，尺寸进入 dims。

const Registry := preload("res://addons/ancient_building/core/module_registry.gd")
const Quantize := preload("res://addons/ancient_building/core/quantize.gd")
const EPS := 0.000001


static func solve(module_id: String, target_width: float) -> Dictionary:
	var meta := Registry.get_module(module_id)
	if meta.is_empty():
		return {"error": "unknown module: %s" % module_id}

	var policy := String(meta.get("policy", ""))
	var unit := float(meta.get("unit", 1.0))
	var max_stretch := float(meta.get("max_stretch", 1.0))
	var repeat_unit := float(meta.get("repeat_unit", 0.0))

	match policy:
		"S":
			if target_width <= 0.0:
				return {"mode": "single", "count": 1, "scale": 1.0, "pitch": 0.0}
			var single_scale := target_width / unit
			if single_scale <= max_stretch + EPS:
				return {"mode": "single", "count": 1, "scale": single_scale, "pitch": 0.0}
			if repeat_unit <= 0.0:
				return {"error": "module is not stretchable beyond MaxStretch: %s" % module_id}
			var n := ceili(target_width / (unit * max_stretch) - EPS)
			var per := target_width / float(n)
			return {"mode": "repeat", "count": n, "scale": per / unit, "pitch": per}

		"R":
			if target_width <= 0.0:
				return {"mode": "repeat", "count": 1, "scale": 1.0, "pitch": unit}
			var n := maxi(1, roundi(target_width / unit))
			var pitch := target_width / float(n)
			return {"mode": "repeat", "count": n, "scale": 1.0, "pitch": pitch}

		"A":
			return {"mode": "single", "count": 1, "scale": 1.0, "pitch": 0.0}

		"P":
			return {"mode": "parametric", "count": 1, "scale": 1.0, "pitch": 0.0,
				"dims": {"width": Quantize.length(target_width)}}

	return {"error": "unsupported policy '%s' for %s" % [policy, module_id]}
