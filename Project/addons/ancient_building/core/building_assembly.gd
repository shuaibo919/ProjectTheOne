class_name BuildingAssembly
extends Resource
## 一栋建筑烘焙后的不可变运行时数据（LOD0）。
## 实例数据用 SoA 数组；世界变换由引用它的 AncientBuilding 节点提供。
## Meshes/materials 是共享引用；相同 ModuleKey 只出现一次。

const FORMAT_VERSION := 1
const TRANSFORM_FLOATS := 12

@export var format_version := FORMAT_VERSION
@export var generator_version := 0
@export var layout_hash := ""
@export var assembly_hash := ""
@export var aabb := AABB()
@export var instance_count := 0
@export var unique_mesh_count := 0
@export var triangle_count := 0

## 每实例 12 个 float：basis.x/basis.y/basis.z 三行 + origin（局部空间）。
@export var transforms := PackedFloat32Array()
@export var mesh_index := PackedInt32Array()
@export var mesh_keys := PackedStringArray()
@export var meshes: Array[Mesh] = []
@export var module_index := PackedInt32Array()
@export var module_ids := PackedStringArray()
@export var material_index := PackedInt32Array()
@export var materials: Array[Resource] = []
@export var surface_seeds := PackedFloat32Array()

## 编辑器重建用；运行时不需要。用户明确要求保留完整描述。
@export var source_descriptor: Dictionary = {}
@export var source_path := ""
@export var source_name := ""


func get_instance_transform(index: int) -> Transform3D:
	var offset := index * TRANSFORM_FLOATS
	if index < 0 or offset + TRANSFORM_FLOATS > transforms.size():
		return Transform3D.IDENTITY
	var basis := Basis(
		Vector3(transforms[offset + 0], transforms[offset + 4], transforms[offset + 8]),
		Vector3(transforms[offset + 1], transforms[offset + 5], transforms[offset + 9]),
		Vector3(transforms[offset + 2], transforms[offset + 6], transforms[offset + 10])
	)
	var origin := Vector3(transforms[offset + 3], transforms[offset + 7], transforms[offset + 11])
	return Transform3D(basis, origin)


func get_instance_mesh(index: int) -> Mesh:
	if index < 0 or index >= mesh_index.size():
		return null
	var mesh_slot := int(mesh_index[index])
	if mesh_slot < 0 or mesh_slot >= meshes.size():
		return null
	return meshes[mesh_slot]


func get_instance_material(index: int) -> Material:
	if index < 0 or index >= material_index.size():
		return null
	var material_slot := int(material_index[index])
	if material_slot < 0 or material_slot >= materials.size():
		return null
	var profile: Resource = materials[material_slot]
	return profile.get("material") as Material if profile != null else null


func get_instance_profile(index: int) -> Resource:
	if index < 0 or index >= material_index.size():
		return null
	var material_slot := int(material_index[index])
	if material_slot < 0 or material_slot >= materials.size():
		return null
	return materials[material_slot]


func get_instance_module_id(index: int) -> String:
	if index < 0 or index >= module_index.size():
		return ""
	var module_slot := int(module_index[index])
	if module_slot < 0 or module_slot >= module_ids.size():
		return ""
	return module_ids[module_slot]


func get_instance_seed(index: int) -> float:
	if index < 0 or index >= surface_seeds.size():
		return 0.0
	return surface_seeds[index]


func validate() -> Array[String]:
	var errors: Array[String] = []
	if format_version != FORMAT_VERSION:
		errors.append("unsupported assembly format %d" % format_version)
	if assembly_hash.is_empty():
		errors.append("assembly_hash is empty")
	if instance_count != mesh_index.size():
		errors.append("instance_count/mesh_index mismatch")
	if instance_count != module_index.size():
		errors.append("instance_count/module_index mismatch")
	if instance_count != material_index.size():
		errors.append("instance_count/material_index mismatch")
	if instance_count != surface_seeds.size():
		errors.append("instance_count/surface_seeds mismatch")
	if transforms.size() != instance_count * TRANSFORM_FLOATS:
		errors.append("transforms size mismatch")
	if unique_mesh_count != meshes.size():
		errors.append("unique_mesh_count/meshes mismatch")
	if mesh_keys.size() != meshes.size():
		errors.append("mesh_keys/meshes mismatch")
	for index in meshes.size():
		if meshes[index] == null:
			errors.append("mesh %d is null" % index)
	for index in instance_count:
		var mesh_slot := int(mesh_index[index])
		if mesh_slot < 0 or mesh_slot >= meshes.size():
			errors.append("instance %d has invalid mesh index" % index)
		var material_slot := int(material_index[index])
		if material_slot < 0 or material_slot >= materials.size():
			errors.append("instance %d has invalid material index" % index)
		var module_slot := int(module_index[index])
		if module_slot < 0 or module_slot >= module_ids.size():
			errors.append("instance %d has invalid module index" % index)
	for profile in materials:
		if profile == null:
			errors.append("material profile is null")
			continue
		if not profile.has_method("validate"):
			errors.append("material profile has no validate()")
			continue
		var profile_errors: Array = profile.call("validate")
		errors.append_array(profile_errors)
	return errors
