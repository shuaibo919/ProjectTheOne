extends RefCounted
## 把建筑描述（模块列表）解算成实例列表：每个实例带 key、变换与参数。
## 这一步不做几何，也不碰场景树。

const Registry := preload("res://addons/ancient_building/core/module_registry.gd")
const Params := preload("res://addons/ancient_building/core/module_params.gd")
const Solver := preload("res://addons/ancient_building/core/width_solver.gd")
const Quantize := preload("res://addons/ancient_building/core/quantize.gd")
const KeyHelper := preload("res://addons/ancient_building/core/module_key.gd")


static func plan(modules: Array) -> Dictionary:
	var instances: Array = []
	var errors: Array = []

	for placement in modules:
		if typeof(placement) != TYPE_DICTIONARY:
			errors.append("module placement is not a dictionary")
			continue

		var id := String(placement.get("id", ""))
		var meta := Registry.get_module(id)
		if meta.is_empty():
			errors.append("unknown module: %s" % id)
			continue

		var params := Params.quantize(id, placement.get("params", {}))
		var defaults := Params.defaults(id)
		for key in defaults:
			if not params.has(key):
				params[key] = defaults[key]
		for message in Params.validate(id, params):
			errors.append("%s: %s" % [id, message])

		var unit := float(meta.get("unit", 1.0))
		var target := float(placement.get("width", unit))
		var solved := Solver.solve(id, target)
		if solved.has("error"):
			errors.append(String(solved["error"]))
			continue

		var policy := String(meta.get("policy", ""))
		var count := int(solved.get("count", 1))
		var scale := float(solved.get("scale", 1.0))
		var pitch := float(solved.get("pitch", 0.0))
		var position: Vector3 = placement.get("position", Vector3.ZERO)
		var rotation_y := float(placement.get("rotation_y", 0.0))
		var key := KeyHelper.make(id, params,
				String(placement.get("material_set", "M_Default")),
				int(placement.get("lod", 0)),
				solved.get("dims", null))

		for index in count:
			var offset := Vector3.ZERO
			if count > 1:
				offset.x = (float(index) - float(count - 1) * 0.5) * pitch

			var basis := Basis(Vector3.UP, rotation_y)
			if policy == "S":
				basis = basis.scaled(Vector3(scale, 1.0, 1.0))

			instances.append({
				"key": key,
				"module_id": id,
				"transform": Transform3D(basis, position + offset),
				"params": params,
				"dims": solved.get("dims", {}),
				"index": index,
			})

	return {
		"instances": instances,
		"errors": errors,
		"layout_hash": _layout_hash(instances),
	}


static func _layout_hash(instances: Array) -> String:
	var rows: Array = []
	for instance in instances:
		var xf: Transform3D = instance["transform"]
		var scale := xf.basis.get_scale()
		rows.append([
			String(instance["key"]),
			Quantize.length(xf.origin.x),
			Quantize.length(xf.origin.y),
			Quantize.length(xf.origin.z),
			Quantize.ratio(scale.x),
			Quantize.ratio(scale.y),
			Quantize.ratio(scale.z),
		])
	return ModuleKey.make_key({
		"generator_version": Registry.generator_version(),
		"layout": rows,
	})
