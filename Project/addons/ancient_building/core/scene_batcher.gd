extends RefCounted
## MultiMesh 批量转换与还原（M4）。
## key 已包含材质集与 LOD，所以同 key 的实例可以合成一个 MultiMesh。

const Assembler := preload("res://addons/ancient_building/core/assembler.gd")


static func convert(root: Node3D) -> Dictionary:
	var groups: Dictionary = {}
	for child in root.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var key := String(child.get_meta("ab_key", ""))
			if key.is_empty():
				continue
			if not groups.has(key):
				groups[key] = []
			groups[key].append(child)

	var created := 0
	var total := 0
	for key in groups:
		var list: Array = groups[key]
		if list.is_empty():
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = list[0].mesh
		multimesh.instance_count = list.size()
		for index in list.size():
			multimesh.set_instance_transform(index, list[index].transform)

		var node := MultiMeshInstance3D.new()
		node.name = "MM_%s" % String(key)
		node.multimesh = multimesh
		node.set_meta("ab_key", String(key))
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
