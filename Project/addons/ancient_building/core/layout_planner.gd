extends RefCounted
## 把建筑描述（模块列表）解算成实例列表：每个实例带 key、变换与参数。
## 这一步不做几何，也不碰场景树。

const Recipe := preload("res://addons/ancient_building/core/building_recipe.gd")
const Registry := preload("res://addons/ancient_building/core/module_registry.gd")
const Params := preload("res://addons/ancient_building/core/module_params.gd")
const Solver := preload("res://addons/ancient_building/core/width_solver.gd")
const Quantize := preload("res://addons/ancient_building/core/quantize.gd")
const KeyHelper := preload("res://addons/ancient_building/core/module_key.gd")
const Geometry := preload("res://addons/ancient_building/core/shell_geometry.gd")


static func from_descriptor(descriptor: Dictionary, session: Dictionary = {}, validate_external := true) -> Dictionary:
	var placements: Array = []
	var recipe: Dictionary = descriptor.get("building", {})
	if not recipe.is_empty():
		var generated := Recipe.assemble(recipe, session)
		if generated.has("error"):
			return {"instances": [], "errors": [generated.error], "layout_hash": ""}
		placements = generated.placements
	placements.append_array(descriptor.get("modules", []))
	var overrides: Dictionary = descriptor.get("mesh_overrides", {})
	for id in overrides:
		if Registry.get_module(id).is_empty() or not overrides[id] is String:
			return {"instances":[],"errors":["invalid mesh_overrides entry: %s" % id],"layout_hash":""}
	if not overrides.is_empty():
		placements = placements.duplicate(true)
		for entry in placements:
			if entry is Dictionary and not entry.has("mesh_path") and overrides.has(entry.get("id", "")):
				entry["mesh_path"] = overrides[entry.id]
	var result := plan(placements, validate_external)
	var surface: Variant = recipe.get("surface", descriptor.get("surface", {}))
	if not surface is Dictionary:
		result.errors.append("surface must be an object")
		return result
	for instance in result.instances:
		var settings: Dictionary = surface.duplicate(true)
		settings.merge(instance.get("surface",{}),true)
		instance.surface = settings
	return result


static func plan(modules: Array, validate_external := true) -> Dictionary:
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

		var raw: Variant = placement.get("params", {})
		if not placement.get("surface",{}) is Dictionary:
			errors.append("%s: surface must be an object" % id)
			continue
		if not raw is Dictionary:
			errors.append("%s: params must be an object" % id)
			continue
		var schema: Dictionary = meta.get("params", {})
		for field in raw:
			if not schema.has(field):
				errors.append("%s: unknown parameter %s" % [id,field])
		var params := Params.quantize(id, raw)
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
		var shape: Variant = placement.get("geometry", {})
		if not shape is Dictionary:
			errors.append("%s: geometry must be an object" % id)
			continue
		if shape.is_empty() and id == "W01" and int(params.get("wall_kind", 0)) > 0:
			shape = {"kind":"wall", "style":int(params.wall_kind), "points":[
				[-roundi(target*500), -int(params.height)/2, 0], [roundi(target*500), -int(params.height)/2, 0],
				[roundi(target*500), int(params.height)/2, 0], [-roundi(target*500), int(params.height)/2, 0]]}
		if not shape.is_empty():
			var geometry_error := Geometry.validate(shape)
			if not geometry_error.is_empty():
				errors.append("%s: %s" % [id, geometry_error])
				continue
			policy = "P"
			solved = {"count":1, "scale":1.0, "pitch":0.0, "dims":{"geometry":shape}}
		var count := int(solved.get("count", 1))
		var scale := float(solved.get("scale", 1.0))
		var pitch := float(solved.get("pitch", 0.0))
		var position: Vector3 = placement.get("position", Vector3.ZERO)
		var rotation := Vector3(float(placement.get("rotation_x", 0.0)), float(placement.get("rotation_y", 0.0)), float(placement.get("rotation_z", 0.0)))
		var orientation := Basis.from_euler(rotation * (PI / 180.0))
		var mesh_path := String(placement.get("mesh_path", ""))
		if validate_external and not mesh_path.is_empty() and not (ResourceLoader.exists(mesh_path) and load(mesh_path) is Mesh):
			errors.append("%s: expected a Mesh at %s" % [id, mesh_path])
			continue
		var key := KeyHelper.make(id, params,
				String(placement.get("material_set", "M_Default")),
				int(placement.get("lod", 0)),
				solved.get("dims", null), mesh_path)

		for index in count:
			var offset := Vector3.ZERO
			if count > 1:
				offset.x = (float(index) - float(count - 1) * 0.5) * pitch

			var basis := orientation
			if policy == "S":
				var local_scale := Vector3(1.0,scale,1.0) if id=="F01" else Vector3(scale,1.0,1.0)
				basis = orientation * Basis.from_scale(local_scale)
				if id=="F01":
					offset = Vector3.UP*offset.x*float(params.height)/1000.0

			instances.append({
				"key": key,
				"module_id": id,
				"transform": Transform3D(basis, position + orientation * offset),
				"mesh_path": mesh_path, "material_set": placement.get("material_set", "M_Default"),
				"surface": placement.get("surface",{}),
				"surface_override": placement.get("surface",{}),
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
		var basis: Array = []
		for axis in [xf.basis.x, xf.basis.y, xf.basis.z]:
			for component in 3:
				basis.append(Quantize.ratio(axis[component]))
		rows.append([
			String(instance["key"]),
			Quantize.length(xf.origin.x),
			Quantize.length(xf.origin.y),
			Quantize.length(xf.origin.z),
			basis,
		])
	return ModuleKey.make_key({
		"generator_version": Registry.generator_version(),
		"layout": rows,
	})
