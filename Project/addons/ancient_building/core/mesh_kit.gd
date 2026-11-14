extends RefCounted
const Data := preload("res://addons/ancient_building/core/mesh_data.gd")
## 基础几何工具。局部坐标约定：X = 宽度轴（复制方向），Y = 高度，Z = 进深；单位米。


static func box(size: Vector3) -> Data:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st, size, Vector3.ZERO)
	return Data.new(st, size)


## 双坡屋面：屋脊沿 X，屋面沿 Z 下坡；返回双面三角面。
static func gable_roof(width: float, depth: float, rise: float) -> Data:
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
	return Data.new(st)


static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_add_tri(st, a, b, c, normal, normal, normal)
	_add_tri(st, a, c, d, normal, normal, normal)


static func cylinder_x(radius: float, length: float, sides: int) -> Data:
	return _cylinder(radius, length, sides, 0)


static func cylinder_y(radius: float, length: float, sides: int) -> Data:
	return _cylinder(radius, length, sides, 1)


static func cylinder_z(radius: float, length: float, sides: int) -> Data:
	return _cylinder(radius, length, sides, 2)


static func _cylinder(radius: float, length: float, sides: int, axis: int) -> Data:
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
		_add_tri(st, cap0, cap0 + d0 * radius, cap0 + d1 * radius, -axis_vec, -axis_vec, -axis_vec)
		_add_tri(st, cap1, cap1 + d1 * radius, cap1 + d0 * radius, axis_vec, axis_vec, axis_vec)

	return Data.new(st)


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
		na: Vector3, nb: Vector3, nc: Vector3,
		uva := Vector2.ZERO, uvb := Vector2.ZERO, uvc := Vector2.ZERO) -> void:
	# UV2 专用于原生构件的逐片木纹轴；0 使用材质默认，1/2/3 为 X/Y/Z。
	st.set_uv2(Vector2(float(st.get_meta("ab_grain_axis", -1)) + 1.0, 7.0))
	# Godot uses clockwise front faces, including on mirrored profiles.
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		var point := b
		b = c
		c = point
		var normal := nb
		nb = nc
		nc = normal
		var texture_uv := uvb
		uvb = uvc
		uvc = texture_uv
	st.set_normal(na)
	st.set_uv(uva)
	st.add_vertex(a)
	st.set_normal(nb)
	st.set_uv(uvb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.set_uv(uvc)
	st.add_vertex(c)


## 把多个盒体合并成一个 ArrayMesh。门框、窗框、牌匾、斗栱这类小构件用。
## parts: [{ "size": Vector3, "position": Vector3 }]
static func boxes(parts: Array) -> Data:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		_add_box(st, part["size"], part.get("position", Vector3.ZERO))
	return Data.new(st)


static func _add_box(st: SurfaceTool, size: Vector3, center: Vector3) -> void:
	var prior_axis := int(st.get_meta("ab_grain_axis", -1))
	st.set_meta("ab_grain_axis", size.max_axis_index())
	var h := size * 0.5
	var p000 := center + Vector3(-h.x, -h.y, -h.z)
	var p100 := center + Vector3(h.x, -h.y, -h.z)
	var p110 := center + Vector3(h.x, h.y, -h.z)
	var p010 := center + Vector3(-h.x, h.y, -h.z)
	var p001 := center + Vector3(-h.x, -h.y, h.z)
	var p101 := center + Vector3(h.x, -h.y, h.z)
	var p111 := center + Vector3(h.x, h.y, h.z)
	var p011 := center + Vector3(-h.x, h.y, h.z)

	_add_quad(st, p001, p101, p111, p011, Vector3.BACK)
	_add_quad(st, p100, p000, p010, p110, Vector3.FORWARD)
	_add_quad(st, p000, p001, p011, p010, Vector3.LEFT)
	_add_quad(st, p101, p100, p110, p111, Vector3.RIGHT)
	_add_quad(st, p010, p011, p111, p110, Vector3.UP)
	_add_quad(st, p000, p100, p101, p001, Vector3.DOWN)
	st.set_meta("ab_grain_axis", prior_axis)


## 门窗框：左右两根竖梃 + 上槛（窗再加下槛）。
static func frame(width: float, height: float, thickness: float, depth: float, with_sill := false) -> Data:
	var half := maxf(0.0, (width - thickness) * 0.5)
	var parts: Array = [
		{ "size": Vector3(thickness, height, depth), "position": Vector3(-half, 0.0, 0.0) },
		{ "size": Vector3(thickness, height, depth), "position": Vector3(half, 0.0, 0.0) },
		{ "size": Vector3(width, thickness, depth), "position": Vector3(0.0, height * 0.5 - thickness * 0.5, 0.0) },
	]
	if with_sill:
		parts.append({
			"size": Vector3(width, thickness, depth),
			"position": Vector3(0.0, -height * 0.5 + thickness * 0.5, 0.0),
		})
	return boxes(parts)


## 棂条单元：一根竖棂 + 上下横档 + 中档。R 策略沿宽度重复后形成格栅。
static func lattice(width: float, height: float, bar: float, depth: float) -> Data:
	return boxes([
		{ "size": Vector3(bar, height, depth), "position": Vector3.ZERO },
		{ "size": Vector3(width, bar, depth), "position": Vector3(0.0, height * 0.5 - bar * 0.5, 0.0) },
		{ "size": Vector3(width, bar, depth), "position": Vector3(0.0, -height * 0.5 + bar * 0.5, 0.0) },
		{ "size": Vector3(width, bar * 0.8, depth), "position": Vector3.ZERO },
	])


## 踏跺：沿 Z 的实体台阶，高端在 -Z（面向建筑时贴在台明前沿）。
static func stairs(width: float, height: float, depth: float, steps: int) -> Data:
	var n := maxi(1, steps)
	var step_h := height / float(n)
	var tread := depth / float(n)
	var parts: Array = []
	for index in n:
		var h := step_h * float(index + 1)
		var z := depth * 0.5 - tread * (float(index) + 0.5)
		parts.append({
			"size": Vector3(width, h, tread),
			"position": Vector3(0.0, h * 0.5, z),
		})
	return boxes(parts)


## 匾额：板芯 + 四周边框。
static func plaque(width: float, height: float, depth: float, border: float) -> Data:
	var outer_w := width + border * 2.0
	var outer_h := height + border * 2.0
	return boxes([
		{ "size": Vector3(width, height, depth), "position": Vector3.ZERO },
		{ "size": Vector3(border, outer_h, depth * 1.15), "position": Vector3(-width * 0.5 - border * 0.5, 0.0, 0.0) },
		{ "size": Vector3(border, outer_h, depth * 1.15), "position": Vector3(width * 0.5 + border * 0.5, 0.0, 0.0) },
		{ "size": Vector3(outer_w, border, depth * 1.15), "position": Vector3(0.0, height * 0.5 + border * 0.5, 0.0) },
		{ "size": Vector3(outer_w, border, depth * 1.15), "position": Vector3(0.0, -height * 0.5 - border * 0.5, 0.0) },
	])


## 简化斗栱：座 + 挑臂 + 顶板，R 策略沿檐口重复。
static func bracket(width: float, height: float, depth: float) -> Data:
	return boxes([
		{ "size": Vector3(width, height * 0.35, depth), "position": Vector3(0.0, height * 0.175, 0.0) },
		{ "size": Vector3(width * 1.15, height * 0.30, depth * 1.25), "position": Vector3(0.0, height * 0.50, 0.0) },
		{ "size": Vector3(width * 1.30, height * 0.20, depth * 1.45), "position": Vector3(0.0, height * 0.75, 0.0) },
	])
