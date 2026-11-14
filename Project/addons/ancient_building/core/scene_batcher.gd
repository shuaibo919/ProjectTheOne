extends RefCounted
## MultiMesh 批量转换与还原（M4）。
## 同几何 key 且共享同一材质的实例合成 MultiMesh，独立表面覆盖分别分组。

const Assembler := preload("res://addons/ancient_building/core/assembler.gd")


static func convert(root: Node3D) -> Dictionary:
	var state: Dictionary = root.get_meta("ab_state",{})
	if state.get("mode","") == "multimesh":
		return {"groups":state.groups,"instances":state.instances}
	var groups: Dictionary = {}
	for child in root.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var key := String(child.get_meta("ab_key", ""))
			if key.is_empty():
				continue
			# 同几何也可能使用独立纹理集，不能把材质不同的件合进同一批。
			var group_key := key+"_"+str(child.material_override.get_instance_id() if child.material_override else 0)
			if not groups.has(group_key):
				groups[group_key] = []
			groups[group_key].append(child)

	var created := 0
	var total := 0
	for key in groups:
		var list: Array = groups[key]
		if list.is_empty():
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = list[0].mesh
		multimesh.use_custom_data = list[0].has_meta("ab_surface_seed")
		multimesh.instance_count = list.size()
		# The headless dummy renderer only persists bulk buffers, not per-instance
		# setters. Use the same row-major payload for CLI baking and GPU preview.
		var buffer := PackedFloat32Array()
		for index in list.size():
			var t: Transform3D = list[index].transform
			buffer.append_array(PackedFloat32Array([
				t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x,
				t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y,
				t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z]))
			if multimesh.use_custom_data:
				buffer.append_array(PackedFloat32Array([float(list[index].get_meta("ab_surface_seed")),0,0,1]))
		multimesh.buffer = buffer

		var node := MultiMeshInstance3D.new()
		# 分组可用进程内 Resource ID；保存节点名使用稳定的首次出现次序。
		node.name = "MM_%s_%d" % [String(list[0].get_meta("ab_key")),created]
		node.multimesh = multimesh
		node.material_override = list[0].material_override
		node.set_meta("ab_key", list[0].get_meta("ab_key"))
		node.set_meta("ab_module", list[0].get_meta("ab_module", ""))
		if list[0].has_meta("ab_finish"):
			node.set_meta("ab_finish", list[0].get_meta("ab_finish"))
			node.set_meta("ab_surface_override",list[0].get_meta("ab_surface_override",{}))
		root.add_child(node)
		node.owner = root
		created += 1
		total += list.size()

	for key in groups:
		for child in groups[key]:
			root.remove_child(child)
			child.queue_free()

	root.set_meta("ab_state", {"mode": "multimesh", "groups": created, "instances": total})
	return {"groups": created, "instances": total}


static func revert(root: Node3D, plan: Dictionary, cache) -> void:
	Assembler.rebuild_into(root, plan, cache)
