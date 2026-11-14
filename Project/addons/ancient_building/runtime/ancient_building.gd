class_name AncientBuilding
extends Node3D
## 运行时建筑节点：引用 BuildingAssembly，自身不重新求解。
## 有祖先 AncientBuildingBatch 时注册到跨建筑批次；否则在本地生成 MultiMesh 组。

const AssemblyRender := preload("res://addons/ancient_building/runtime/assembly_render.gd")

@export var assembly: Resource:
	set(value):
		assembly = value
		if is_inside_tree():
			rebuild()
@export var seed_salt := 0.0:
	set(value):
		seed_salt = value
		if is_inside_tree():
			rebuild()
@export var batch_mode := true:
	set(value):
		batch_mode = value
		if is_inside_tree():
			_reconfigure()
@export var cast_shadow := true:
	set(value):
		cast_shadow = value
		if is_inside_tree():
			rebuild()

var _batch: Node3D
var _local_root: Node3D
var _reconfiguring := false


func _ready() -> void:
	_reconfigure()


func _exit_tree() -> void:
	if is_instance_valid(_batch) and _batch.has_method("unregister_building"):
		_batch.call("unregister_building", self)
	_batch = null


func rebuild() -> void:
	if _reconfiguring:
		return
	if is_instance_valid(_batch):
		_batch.call("rebuild")
	else:
		_build_local()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree() and is_instance_valid(_batch):
		_batch.call_deferred("rebuild")


func _reconfigure() -> void:
	if _reconfiguring:
		return
	_reconfiguring = true
	if is_instance_valid(_batch) and _batch.has_method("unregister_building"):
		_batch.call("unregister_building", self)
	_batch = null
	_clear_local()
	if batch_mode:
		_batch = _find_batch()
	if is_instance_valid(_batch):
		_batch.call("register_building", self)
	else:
		_build_local()
	_reconfiguring = false


func _find_batch() -> Node3D:
	var current := get_parent()
	while current != null:
		if current.has_method("register_building") and current.has_method("unregister_building") and current.has_method("rebuild"):
			return current as Node3D
		current = current.get_parent()
	return null


func _clear_local() -> void:
	if is_instance_valid(_local_root):
		remove_child(_local_root)
		_local_root.queue_free()
	_local_root = null


func _build_local() -> void:
	_clear_local()
	if assembly == null:
		return
	_local_root = Node3D.new()
	_local_root.name = "AssemblyLocal"
	add_child(_local_root)
	var count := int(assembly.get("instance_count"))
	var mesh_index = assembly.get("mesh_index")
	var mesh_keys = assembly.get("mesh_keys")
	var meshes = assembly.get("meshes")
	var material_index = assembly.get("material_index")
	var materials = assembly.get("materials")
	var surface_seeds = assembly.get("surface_seeds")
	var groups := {}
	for index in count:
		var mesh_slot := int(mesh_index[index])
		var material_slot := int(material_index[index])
		if mesh_slot < 0 or mesh_slot >= meshes.size():
			continue
		if material_slot < 0 or material_slot >= materials.size():
			continue
		var key := String(mesh_keys[mesh_slot])
		var profile: Resource = materials[material_slot]
		var profile_id := String(profile.get("profile_id"))
		var group_key := key + "|" + profile_id
		if not groups.has(group_key):
			groups[group_key] = {
				"mesh": meshes[mesh_slot],
				"material": profile.get("material"),
				"entries": [],
			}
		var seed := fposmod(float(surface_seeds[index]) + seed_salt, 1.0)
		groups[group_key]["entries"].append({
			"transform": assembly.get_instance_transform(index),
			"seed": seed,
		})
	for group_key in groups:
		var group: Dictionary = groups[group_key]
		AssemblyRender.add_group(_local_root, group["mesh"], group["material"], group["entries"], cast_shadow, false, str(group_key.hash()))
