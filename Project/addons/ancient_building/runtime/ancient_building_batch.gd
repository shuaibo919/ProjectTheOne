@tool
class_name AncientBuildingBatch
extends Node3D
## 跨建筑 MultiMesh 批次：按 (chunk, mesh_key, material_profile, cast_shadow) 合并实例。
## 本阶段固定 LOD0；移动/增删建筑时整批重建，先保证正确性，后续再做增量。

const AssemblyRender := preload("res://addons/ancient_building/runtime/assembly_render.gd")

@export_range(1.0, 256.0, 1.0) var chunk_size := 32.0

var _buildings: Array = []
var _group_root: Node3D
var _dirty := false
var _rebuilding := false
var _group_count := 0


func _init() -> void:
	# Moving the batch changes every building's global transform; rebuild is deferred.
	set_notify_transform(true)


func _ready() -> void:
	_group_root = Node3D.new()
	_group_root.name = "AssemblyGroups"
	add_child(_group_root)
	mark_dirty()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree():
		mark_dirty()


func register_building(building: Node3D) -> void:
	if building == null:
		return
	if not _buildings.has(building):
		_buildings.append(building)
		mark_dirty()


func unregister_building(building: Node3D) -> void:
	if _buildings.has(building):
		_buildings.erase(building)
		mark_dirty()


func building_count() -> int:
	return _buildings.size()


func group_count() -> int:
	return _group_count


func rebuild() -> void:
	mark_dirty()


func mark_dirty() -> void:
	if _dirty:
		return
	_dirty = true
	call_deferred("_rebuild")


func _rebuild() -> void:
	if _rebuilding:
		return
	if not is_inside_tree():
		return
	_dirty = false
	_rebuilding = true
	if _group_root == null:
		_group_root = Node3D.new()
		_group_root.name = "AssemblyGroups"
		add_child(_group_root)
	AssemblyRender.clear(_group_root)
	var groups := {}
	var chunk_scale := maxf(1.0, chunk_size)
	for building in _buildings:
		if not is_instance_valid(building) or not building.is_inside_tree():
			continue
		var assembly: Resource = building.get("assembly")
		if assembly == null:
			continue
		var count := int(assembly.get("instance_count"))
		var mesh_index = assembly.get("mesh_index")
		var mesh_keys = assembly.get("mesh_keys")
		var meshes = assembly.get("meshes")
		var material_index = assembly.get("material_index")
		var materials = assembly.get("materials")
		var surface_seeds = assembly.get("surface_seeds")
		var salt := float(building.get("seed_salt"))
		var cast_shadow := bool(building.get("cast_shadow"))
		for index in count:
			var mesh_slot := int(mesh_index[index])
			var material_slot := int(material_index[index])
			if mesh_slot < 0 or mesh_slot >= meshes.size():
				continue
			if material_slot < 0 or material_slot >= materials.size():
				continue
			var world: Transform3D = building.global_transform * assembly.get_instance_transform(index)
			var chunk := Vector2i(floori(world.origin.x / chunk_scale), floori(world.origin.z / chunk_scale))
			var mesh_key := String(mesh_keys[mesh_slot])
			var profile: Resource = materials[material_slot]
			var profile_id := String(profile.get("profile_id"))
			var key := "%d:%d|%s|%s|%s" % [chunk.x, chunk.y, mesh_key, profile_id, str(cast_shadow)]
			if not groups.has(key):
				groups[key] = {
					"mesh": meshes[mesh_slot],
					"material": profile.get("material"),
					"cast_shadow": cast_shadow,
					"entries": [],
				}
			var seed := fposmod(float(surface_seeds[index]) + salt, 1.0)
			groups[key]["entries"].append({"transform": world, "seed": seed})
	_group_count = groups.size()
	var serial := 0
	for key in groups:
		var group: Dictionary = groups[key]
		AssemblyRender.add_group(_group_root, group["mesh"], group["material"], group["entries"],
			bool(group["cast_shadow"]), true, "%03d" % serial)
		serial += 1
	_rebuilding = false
