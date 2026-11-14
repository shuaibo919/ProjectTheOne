extends RefCounted
## BuildingAssembly 烘焙：descriptor → layout → 共享 Mesh/材质 profile → .tres。
## 只处理 LOD0；占位模块、缺失外部 Mesh 直接报错，不生成 unit box。

const Registry := preload("res://addons/ancient_building/core/module_registry.gd")
const Planner := preload("res://addons/ancient_building/core/layout_planner.gd")
const MeshCache := preload("res://addons/ancient_building/core/mesh_cache.gd")
const Materials := preload("res://addons/ancient_building/core/material_library.gd")
const ModuleMesh := preload("res://addons/ancient_building/core/module_mesh.gd")
const Quantize := preload("res://addons/ancient_building/core/quantize.gd")
const AssemblyScript := preload("res://addons/ancient_building/core/building_assembly.gd")
const ProfileScript := preload("res://addons/ancient_building/core/building_material_profile.gd")

const CACHE_ROOT := "res://Generated/AncientBuilding"
const ASSEMBLY_ROOT := "res://Generated/AncientBuilding/Assemblies"
const TRANSFORM_FLOATS := 12


static func bake(descriptor: Dictionary, options: Dictionary = {}) -> Dictionary:
	if descriptor.is_empty():
		return _error("empty descriptor")
	if not descriptor.get("building", {}) is Dictionary:
		return _error("descriptor.building must be an object")
	if not descriptor.get("modules", []) is Array:
		return _error("descriptor.modules must be an array")

	var plan := Planner.from_descriptor(descriptor)
	if not plan.get("errors", []).is_empty():
		return _error("layout: " + _join_errors(plan.errors), 1, plan.errors)

	var instances: Array = plan.get("instances", [])
	if instances.is_empty():
		return _error("descriptor produces no instances")
	var generator_version := Registry.generator_version()
	var cache := MeshCache.new("%s/Meshes" % CACHE_ROOT, generator_version)

	var mesh_keys := PackedStringArray()
	var meshes: Array[Mesh] = []
	var mesh_slot_by_key := {}
	var module_ids := PackedStringArray()
	var module_slot_by_id := {}
	var profiles: Array[Resource] = []
	var profile_slot_by_id := {}

	var transforms := PackedFloat32Array()
	var mesh_index := PackedInt32Array()
	var module_index := PackedInt32Array()
	var material_index := PackedInt32Array()
	var surface_seeds := PackedFloat32Array()
	var bounds := AABB()
	var has_bounds := false
	var triangle_count := 0
	var triangle_by_mesh := {}

	for instance in instances:
		if not instance is Dictionary:
			return _error("invalid instance record")
		var module_id := String(instance.get("module_id", ""))
		var key := String(instance.get("key", ""))
		if module_id.is_empty() or key.is_empty():
			return _error("instance without module/key")
		var external_path := String(instance.get("mesh_path", ""))
		if external_path.is_empty() and not ModuleMesh.supports(module_id):
			return _error("module %s has no runtime mesh; placeholders are not allowed in assemblies" % module_id)

		if not mesh_slot_by_key.has(key):
			var mesh: Mesh = null
			if external_path.is_empty():
				cache.get_mesh(key, module_id, instance.get("params", {}), instance.get("dims", {}))
				var mesh_path := "%s/Meshes/v%d/%s.res" % [CACHE_ROOT, generator_version, key]
				if not ResourceLoader.exists(mesh_path):
					return _error("mesh cache missing: " + mesh_path, 2)
				mesh = ResourceLoader.load(mesh_path, "Mesh") as Mesh
			else:
				if not ResourceLoader.exists(external_path):
					return _error("external mesh missing: " + external_path, 1)
				mesh = ResourceLoader.load(external_path, "Mesh") as Mesh
			if mesh == null:
				return _error("cannot load mesh for %s" % module_id, 2)
			mesh_slot_by_key[key] = meshes.size()
			mesh_keys.append(key)
			meshes.append(mesh)
			var faces := mesh.get_faces().size()
			var triangles := int(faces / 3)
			triangle_by_mesh[key] = triangles
			triangle_count += triangles

		var mesh_slot := int(mesh_slot_by_key[key])
		if not module_slot_by_id.has(module_id):
			module_slot_by_id[module_id] = module_ids.size()
			module_ids.append(module_id)
		var module_slot := int(module_slot_by_id[module_id])

		var material_set := String(instance.get("material_set", "M_Default"))
		var surface: Dictionary = instance.get("surface", {})
		if not surface is Dictionary:
			return _error("surface must be an object")
		var profile_id := _material_profile_id(module_id, material_set, surface)
		if not profile_slot_by_id.has(profile_id):
			var profile = ProfileScript.new()
			profile.profile_id = profile_id
			profile.module_id = module_id
			profile.material_set = material_set
			profile.surface = surface.duplicate(true)
			profile.material = Materials.for_module(module_id, material_set, surface)
			if profile.material == null:
				return _error("cannot create material for %s" % module_id, 2)
			profile_slot_by_id[profile_id] = profiles.size()
			profiles.append(profile)
		var profile_slot := int(profile_slot_by_id[profile_id])

		var xf: Transform3D = instance.get("transform", Transform3D.IDENTITY)
		_write_transform(transforms, xf)
		mesh_index.append(mesh_slot)
		module_index.append(module_slot)
		material_index.append(profile_slot)
		surface_seeds.append(Materials.piece_seed(module_id, xf))

		var mesh_aabb := _transform_aabb(xf, meshes[mesh_slot].get_aabb())
		if has_bounds:
			bounds = bounds.merge(mesh_aabb)
		else:
			bounds = mesh_aabb
			has_bounds = true

	var assembly = AssemblyScript.new()
	assembly.format_version = AssemblyScript.FORMAT_VERSION
	assembly.generator_version = generator_version
	assembly.layout_hash = String(plan.get("layout_hash", ""))
	assembly.aabb = bounds
	assembly.instance_count = instances.size()
	assembly.unique_mesh_count = meshes.size()
	assembly.triangle_count = triangle_count
	assembly.transforms = transforms
	assembly.mesh_index = mesh_index
	assembly.mesh_keys = mesh_keys
	assembly.meshes = meshes
	assembly.module_index = module_index
	assembly.module_ids = module_ids
	assembly.material_index = material_index
	assembly.materials = profiles
	assembly.surface_seeds = surface_seeds
	assembly.source_descriptor = descriptor.duplicate(true)
	assembly.source_path = String(options.get("source_path", ""))
	assembly.source_name = String(descriptor.get("name", ""))
	assembly.assembly_hash = _assembly_hash(assembly)

	var validation: Array = assembly.validate()
	if not validation.is_empty():
		return _error("assembly validation: " + _join_errors(validation), 2, validation)

	var out_path := String(options.get("out", ""))
	if out_path.is_empty():
		out_path = "%s/%s.tres" % [ASSEMBLY_ROOT, assembly.assembly_hash]
	if not _ensure_dir(out_path.get_base_dir()):
		return _error("cannot create assembly directory: " + out_path.get_base_dir(), 2)
	var save_error := ResourceSaver.save(assembly, out_path)
	if save_error != OK:
		return _error("save failed: %s" % error_string(save_error), 2)

	var manifest_error := _update_manifest(out_path, assembly)
	if not manifest_error.is_empty():
		return _error(manifest_error, 2)

	var bytes := 0
	var file := FileAccess.open(out_path, FileAccess.READ)
	if file != null:
		bytes = file.get_length()
		file.close()
	return {
		"assembly": out_path,
		"hash": assembly.assembly_hash,
		"layout_hash": assembly.layout_hash,
		"instances": assembly.instance_count,
		"unique_meshes": assembly.unique_mesh_count,
		"materials": assembly.materials.size(),
		"triangles": assembly.triangle_count,
		"bytes": bytes,
	}


static func _write_transform(buffer: PackedFloat32Array, xf: Transform3D) -> void:
	var b := xf.basis
	var o := xf.origin
	buffer.append_array(PackedFloat32Array([
		b.x.x, b.y.x, b.z.x, o.x,
		b.x.y, b.y.y, b.z.y, o.y,
		b.x.z, b.y.z, b.z.z, o.z,
	]))


static func _transform_aabb(xf: Transform3D, box: AABB) -> AABB:
	var first := true
	var result := AABB()
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			for z in [box.position.z, box.end.z]:
				var point := xf * Vector3(x, y, z)
				if first:
					result = AABB(point, Vector3.ZERO)
					first = false
				else:
					result = result.expand(point)
	return result


static func _material_profile_id(module_id: String, material_set: String, surface: Dictionary) -> String:
	var payload := {
		"module_id": module_id,
		"material_set": material_set,
		"surface": _quantize_surface(surface),
	}
	var canonical := ModuleKey.canonicalize(payload)
	return "mat1_" + ModuleKey.sha1_hex(canonical).substr(0, 16)


static func _quantize_surface(surface: Dictionary) -> Dictionary:
	var out := {}
	for key in surface:
		var value: Variant = surface[key]
		match typeof(value):
			TYPE_FLOAT:
				out[key] = Quantize.ratio(float(value))
			TYPE_INT:
				out[key] = int(value)
			TYPE_BOOL:
				out[key] = bool(value)
			TYPE_STRING, TYPE_STRING_NAME:
				out[key] = String(value)
			_:
				out[key] = str(value)
	return out


static func _assembly_hash(assembly) -> String:
	var transform_ints: Array = []
	for index in assembly.instance_count:
		var xf: Transform3D = assembly.get_instance_transform(index)
		transform_ints.append([
			Quantize.ratio(xf.basis.x.x), Quantize.ratio(xf.basis.y.x), Quantize.ratio(xf.basis.z.x),
			Quantize.length(xf.origin.x),
			Quantize.ratio(xf.basis.x.y), Quantize.ratio(xf.basis.y.y), Quantize.ratio(xf.basis.z.y),
			Quantize.length(xf.origin.y),
			Quantize.ratio(xf.basis.x.z), Quantize.ratio(xf.basis.y.z), Quantize.ratio(xf.basis.z.z),
			Quantize.length(xf.origin.z),
		])
	var seed_ints: Array = []
	for seed in assembly.surface_seeds:
		seed_ints.append(Quantize.ratio(seed))
	var material_ids: Array = []
	for profile in assembly.materials:
		material_ids.append(profile.profile_id)
	var payload := {
		"format_version": assembly.format_version,
		"generator_version": assembly.generator_version,
		"layout_hash": assembly.layout_hash,
		"mesh_keys": _to_array(assembly.mesh_keys),
		"module_ids": _to_array(assembly.module_ids),
		"material_ids": material_ids,
		"transforms": transform_ints,
		"surface_seeds": seed_ints,
	}
	var canonical := ModuleKey.canonicalize(payload)
	return "asm1_" + ModuleKey.sha1_hex(canonical).substr(0, 16)


static func _to_array(source) -> Array:
	var out: Array = []
	for value in source:
		out.append(value)
	return out


static func _update_manifest(out_path: String, assembly) -> String:
	var manifest_path := "%s/manifest.json" % out_path.get_base_dir()
	var data := {"format_version": AssemblyScript.FORMAT_VERSION, "assemblies": []}
	if FileAccess.file_exists(manifest_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary:
			data = parsed
			if not data.get("assemblies", null) is Array:
				data["assemblies"] = []
	var entries: Array = []
	for entry in data.get("assemblies", []):
		if entry is Dictionary and String(entry.get("hash", "")) != assembly.assembly_hash:
			entries.append(entry)
	entries.append({
		"name": assembly.source_name,
		"hash": assembly.assembly_hash,
		"path": out_path,
		"format_version": assembly.format_version,
		"generator_version": assembly.generator_version,
		"instances": assembly.instance_count,
		"unique_meshes": assembly.unique_mesh_count,
		"materials": assembly.materials.size(),
		"triangles": assembly.triangle_count,
	})
	data["assemblies"] = entries
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		return "cannot write manifest: " + manifest_path
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return ""


static func _ensure_dir(path: String) -> bool:
	var abs_path := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(abs_path):
		return true
	return DirAccess.make_dir_recursive_absolute(abs_path) == OK


static func _join_errors(errors: Array) -> String:
	var parts := PackedStringArray()
	for error in errors:
		parts.append(str(error))
	return "; ".join(parts)


static func _error(message: String, code := 1, details: Array = []) -> Dictionary:
	return {"error": message, "exit": code, "details": details}
