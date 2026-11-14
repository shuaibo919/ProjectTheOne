extends RefCounted
## 工作线程只持有 CPU 数组；Mesh/RID 在主线程提交。盒体保留 BoxMesh 身份供遮挡代理使用。
var arrays: Array = []
var box_size := Vector3.ZERO
var _bounds := AABB()
var _has_bounds := false


func _init(surface: SurfaceTool = null, primitive_box := Vector3.ZERO) -> void:
	if surface != null:
		arrays = surface.commit_to_arrays()
	box_size = primitive_box


func to_mesh() -> Mesh:
	assert(Thread.is_main_thread(), "Mesh resources must be submitted on the main thread")
	if box_size != Vector3.ZERO:
		var box := BoxMesh.new()
		box.size = box_size
		return box
	var mesh := ArrayMesh.new()
	if not arrays.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func get_surface_count() -> int:
	return 0 if arrays.is_empty() else 1


func surface_get_arrays(_index: int) -> Array:
	return arrays


func get_aabb() -> AABB:
	if not _has_bounds and not arrays.is_empty():
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if not points.is_empty():
			_bounds = AABB(points[0], Vector3.ZERO)
			for point in points:
				_bounds = _bounds.expand(point)
		_has_bounds = true
	return _bounds


func translate(offset: Vector3) -> void:
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in points.size():
		points[i] += offset
	arrays[Mesh.ARRAY_VERTEX] = points
	_has_bounds = false


func byte_size() -> int:
	var size := 0
	for values in arrays:
		if values is PackedVector3Array:
			size += values.size() * 12
		elif values is PackedVector2Array:
			size += values.size() * 8
		elif values is PackedFloat32Array or values is PackedInt32Array:
			size += values.size() * 4
	return size
