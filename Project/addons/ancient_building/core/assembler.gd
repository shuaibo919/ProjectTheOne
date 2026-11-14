extends RefCounted
## 装配器：实例列表 -> 场景节点。M4 起支持就地重建（revert 用）。

const Materials := preload("res://addons/ancient_building/core/material_library.gd")


static func build(plan: Dictionary, cache) -> Node3D:
	var root := Node3D.new()
	root.name = "AncientBuilding"
	rebuild_into(root, plan, cache)
	return root


static func rebuild_into(root: Node3D, plan: Dictionary, cache) -> void:
	clear_children(root)
	var serial := 0
	for instance in plan.get("instances", []):
		var mesh_instance := create_instance(instance, cache, serial)
		root.add_child(mesh_instance)
		mesh_instance.owner = root
		serial += 1
	root.set_meta("ab_state", {"mode": "individual", "instances": serial})


static func identity(instance: Dictionary) -> String:
	# 不把材质/网格 key 当作实例身份；相同位置的不同模块也不能互相借用。
	return String(instance.module_id) + ":" + str(instance.transform)


static func create_instance(instance: Dictionary, cache, serial: int, external: Mesh = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "%s_%03d" % [String(instance.module_id), serial]
	var mesh_path := String(instance.get("mesh_path", ""))
	if mesh_path.is_empty():
		node.mesh = cache.get_mesh(instance.key, instance.module_id, instance.params, instance.get("dims", {}))
		node.material_override = Materials.for_module(instance.module_id, instance.get("material_set", "M_Default"), instance.get("surface", {}))
		node.set_meta("ab_finish", String(instance.get("material_set", "M_Default")))
		node.set_meta("ab_surface_override", instance.get("surface_override",{}).duplicate(true))
		var surface_seed := Materials.piece_seed(instance.module_id, instance.transform)
		node.set_instance_shader_parameter("surface_seed", surface_seed)
		node.set_meta("ab_surface_seed", surface_seed)
	else:
		node.mesh = external if external != null else load(mesh_path) as Mesh
	node.transform = instance.transform
	node.set_meta("ab_key", String(instance.key))
	node.set_meta("ab_module", String(instance.module_id))
	node.set_meta("ab_instance_id", identity(instance))
	return node


static func clear_children(root: Node) -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()


static func stats(plan: Dictionary) -> Dictionary:
	var keys: Dictionary = {}
	var modules: Dictionary = {}
	for instance in plan.get("instances", []):
		keys[instance["key"]] = true
		modules[instance["module_id"]] = int(modules.get(instance["module_id"], 0)) + 1
	return {
		"instances": plan.get("instances", []).size(),
		"unique_meshes": keys.size(),
		"modules": modules,
	}
