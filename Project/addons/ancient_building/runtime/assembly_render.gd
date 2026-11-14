@tool
extends RefCounted
## 把一组 (mesh, material, entries) 转成 MultiMeshInstance3D。
## entries 每项：{"transform": Transform3D, "seed": float}。

static func clear(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		if child is MultiMeshInstance3D:
			container.remove_child(child)
			child.queue_free()


static func add_group(parent: Node3D, mesh: Mesh, material: Material, entries: Array,
		cast_shadow: bool, top_level := false, name_hint := "") -> MultiMeshInstance3D:
	if parent == null or mesh == null or entries.is_empty():
		return null
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = entries.size()
	var buffer := PackedFloat32Array()
	buffer.resize(entries.size() * 16)
	var cursor := 0
	for entry in entries:
		var xf: Transform3D = entry.transform
		var b := xf.basis
		var o := xf.origin
		buffer[cursor + 0] = b.x.x
		buffer[cursor + 1] = b.y.x
		buffer[cursor + 2] = b.z.x
		buffer[cursor + 3] = o.x
		buffer[cursor + 4] = b.x.y
		buffer[cursor + 5] = b.y.y
		buffer[cursor + 6] = b.z.y
		buffer[cursor + 7] = o.y
		buffer[cursor + 8] = b.x.z
		buffer[cursor + 9] = b.y.z
		buffer[cursor + 10] = b.z.z
		buffer[cursor + 11] = o.z
		buffer[cursor + 12] = float(entry.get("seed", 0.0))
		buffer[cursor + 13] = 0.0
		buffer[cursor + 14] = 0.0
		buffer[cursor + 15] = 1.0
		cursor += 16
	multimesh.buffer = buffer

	var node := MultiMeshInstance3D.new()
	node.name = "MM_%s" % (name_hint if not name_hint.is_empty() else str(entries.size()))
	node.multimesh = multimesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = top_level
	parent.add_child(node)
	return node
