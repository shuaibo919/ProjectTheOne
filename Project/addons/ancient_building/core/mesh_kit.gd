extends RefCounted
## 基础几何工具。局部坐标约定：X = 宽度轴（复制方向），Y = 高度，Z = 进深；单位米。


static func box(size: Vector3) -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


## 双坡屋面：屋脊沿 X，屋面沿 Z 下坡；返回双面三角面。
static func gable_roof(width: float, depth: float, rise: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w := width * 0.5
	var half_d := depth * 0.5
	var n_pos := Vector3(0.0, half_d, rise).normalized()
	var n_neg := Vector3(0.0, half_d, -rise).normalized()

	_add_quad(st,
			Vector3(-half_w, rise, 0.0), Vector3(half_w, rise, 0.0),
			Vector3(half_w, 0.0, half_d), Vector3(-half_w, 0.0, half_d), n_pos)
	_add_quad(st,
			Vector3(half_w, rise, 0.0), Vector3(-half_w, rise, 0.0),
			Vector3(-half_w, 0.0, -half_d), Vector3(half_w, 0.0, -half_d), n_neg)
	_add_tri(st,
			Vector3(half_w, 0.0, -half_d), Vector3(half_w, 0.0, half_d), Vector3(half_w, rise, 0.0),
			Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT)
	_add_tri(st,
			Vector3(-half_w, 0.0, half_d), Vector3(-half_w, 0.0, -half_d), Vector3(-half_w, rise, 0.0),
			Vector3.LEFT, Vector3.LEFT, Vector3.LEFT)
	return st.commit()


static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_add_tri(st, a, b, c, normal, normal, normal)
	_add_tri(st, a, c, d, normal, normal, normal)


static func cylinder_x(radius: float, length: float, sides: int) -> ArrayMesh:
	return _cylinder(radius, length, sides, 0)


static func cylinder_y(radius: float, length: float, sides: int) -> ArrayMesh:
	return _cylinder(radius, length, sides, 1)


static func cylinder_z(radius: float, length: float, sides: int) -> ArrayMesh:
	return _cylinder(radius, length, sides, 2)


static func _cylinder(radius: float, length: float, sides: int, axis: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := maxi(3, sides)
	var half := length * 0.5
	var axis_vec := _axis_vec(axis)

	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var d0 := _radial(a0, axis)
		var d1 := _radial(a1, axis)
		var p0 := d0 * radius - axis_vec * half
		var p1 := d1 * radius - axis_vec * half
		var p2 := d1 * radius + axis_vec * half
		var p3 := d0 * radius + axis_vec * half
		_add_tri(st, p0, p1, p2, d0, d1, d1)
		_add_tri(st, p0, p2, p3, d0, d1, d0)

	var cap0 := -axis_vec * half
	var cap1 := axis_vec * half
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var d0 := _radial(a0, axis)
		var d1 := _radial(a1, axis)
		_add_tri(st, cap0, d0 * radius, d1 * radius, -axis_vec, -axis_vec, -axis_vec)
		_add_tri(st, cap1, d1 * radius, d0 * radius, axis_vec, axis_vec, axis_vec)

	return st.commit()


static func _axis_vec(axis: int) -> Vector3:
	match axis:
		0:
			return Vector3.RIGHT
		1:
			return Vector3.UP
		_:
			return Vector3.BACK


static func _radial(angle: float, axis: int) -> Vector3:
	match axis:
		0:
			return Vector3(0.0, cos(angle), sin(angle))
		1:
			return Vector3(cos(angle), 0.0, sin(angle))
		_:
			return Vector3(cos(angle), sin(angle), 0.0)


static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3) -> void:
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)
