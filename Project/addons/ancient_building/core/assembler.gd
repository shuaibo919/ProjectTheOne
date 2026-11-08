extends RefCounted
## 装配器：实例列表 -> 场景节点。M4 起支持就地重建（revert 用）。


static func build(plan: Dictionary, cache) -> Node3D:
	var root := Node3D.new()
	root.name = "AncientBuilding"
	rebuild_into(root, plan, cache)
	return root


static func rebuild_into(root: Node3D, plan: Dictionary, cache) -> void:
	clear_children(root)
	var serial := 0
	for instance in plan.get("instances", []):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "%s_%03d" % [String(instance["module_id"]), serial]
		mesh_instance.mesh = cache.get_mesh(
				String(instance["key"]),
				String(instance["module_id"]),
				instance["params"],
				instance.get("dims", {}))
		mesh_instance.transform = instance["transform"]
		mesh_instance.set_meta("ab_key", String(instance["key"]))
		mesh_instance.set_meta("ab_module", String(instance["module_id"]))
		root.add_child(mesh_instance)
		mesh_instance.owner = root
		serial += 1
	root.set_meta("ab_state", {"mode": "individual", "instances": serial})


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
