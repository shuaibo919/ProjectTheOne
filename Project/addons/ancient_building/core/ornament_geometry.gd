extends RefCounted
## 独立轮廓几何：倒角只改变可见边，承托面和安装基准保持固定。
const Data := preload("res://addons/ancient_building/core/mesh_data.gd")
const Kit := preload("res://addons/ancient_building/core/mesh_kit.gd")


static func begin(axis := -1) -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_meta("ab_grain_axis", axis)
	return st


static func prism(st: SurfaceTool, source: PackedVector2Array, depth: float, bevel: float,
		xf := Transform3D.IDENTITY) -> void:
	var outline := source.duplicate()
	if Geometry2D.is_polygon_clockwise(outline):
		outline.reverse()
	var inner := PackedVector2Array()
	var edge_bevel := minf(bevel, depth * 0.22)
	for i in outline.size():
		var incoming := outline[i] - outline[posmod(i - 1, outline.size())]
		var outgoing := outline[(i + 1) % outline.size()] - outline[i]
		var a := Vector2(-incoming.y, incoming.x).normalized()
		var b := Vector2(-outgoing.y, outgoing.x).normalized()
		var bisector := (a + b).normalized()
		var move := edge_bevel / maxf(0.25, bisector.dot(b))
		move = minf(move, minf(incoming.length(), outgoing.length()) * 0.24)
		inner.append(outline[i] + bisector * move)
	var triangles := Geometry2D.triangulate_polygon(inner)
	if triangles.is_empty():
		inner = outline
		edge_bevel = 0.0
		triangles = Geometry2D.triangulate_polygon(inner)
	for side in [-1.0, 1.0]:
		var normal := xf.basis * Vector3(0, 0, side)
		for i in range(0, triangles.size(), 3):
			var a := inner[triangles[i]]
			var b := inner[triangles[i + 1]]
			var c := inner[triangles[i + 2]]
			Kit._add_tri(st, xf * Vector3(a.x,a.y,side*depth*0.5),
				xf * Vector3(b.x,b.y,side*depth*0.5), xf * Vector3(c.x,c.y,side*depth*0.5),
				normal, normal, normal)
	for i in outline.size():
		var j := (i + 1) % outline.size()
		var a := outline[i]
		var b := outline[j]
		var edge := b - a
		var n := Vector3(edge.y, -edge.x, 0).normalized()
		var half := depth * 0.5 - edge_bevel
		Kit._add_quad(st, xf * Vector3(a.x,a.y,-half), xf * Vector3(b.x,b.y,-half),
			xf * Vector3(b.x,b.y,half), xf * Vector3(a.x,a.y,half), xf.basis * n)
		if edge_bevel <= 0.00001:
			continue
		for side in [-1.0, 1.0]:
			var bevel_n := xf.basis * (n + Vector3(0,0,side)).normalized()
			Kit._add_quad(st, xf * Vector3(a.x,a.y,side*half), xf * Vector3(b.x,b.y,side*half),
				xf * Vector3(inner[j].x,inner[j].y,side*depth*0.5),
				xf * Vector3(inner[i].x,inner[i].y,side*depth*0.5), bevel_n)


static func beam(w: float, h: float, d: float, shoulder := true, bevel := 0.004) -> Data:
	var st := begin(0)
	var half := w * 0.5
	var points := PackedVector2Array()
	# 短梁无法容纳两组肩部时保留完整矩形承托，避免交错或反转。
	if shoulder and w > h * 3.2:
		var head := minf(h * 0.72, w * 0.16)
		var ramp := minf(h * 0.85, w * 0.16)
		for p in [[-half,-h*0.08],[-half,h*0.33],[-half+head,h*0.33],
			[-half+head+ramp,h*0.5],[half-head-ramp,h*0.5],[half-head,h*0.33],
			[half,h*0.33],[half,-h*0.08],[half-head,-h*0.08],
			[half-head-ramp,-h*0.5],[-half+head+ramp,-h*0.5],[-half+head,-h*0.08]]:
			points.append(Vector2(p[0],p[1]))
	else:
		points = PackedVector2Array([Vector2(-half,-h*0.5),Vector2(half,-h*0.5),
			Vector2(half,h*0.5),Vector2(-half,h*0.5)])
	prism(st, points, d, minf(bevel, h * 0.08))
	return Data.new(st)


static func arm(w: float, h: float, d: float, bevel := 0.003, fork := false, fork_angle := 90) -> Data:
	var st := begin(0)
	if fork:
		# 角部顶承托由合并的十字平面挤出；交叉中心不叠两张共面顶面。
		var first := PackedVector2Array([Vector2(-w*0.5,-d*0.5),Vector2(w*0.5,-d*0.5),
			Vector2(w*0.5,d*0.5),Vector2(-w*0.5,d*0.5)])
		var second := PackedVector2Array()
		for point in first:
			second.append(point.rotated(deg_to_rad(float(fork_angle))))
		var merged := Geometry2D.merge_polygons(first, second)
		for poly in merged:
			prism(st, poly, h, bevel, Transform3D(Basis(Vector3.RIGHT, PI*0.5),Vector3.UP*h*0.5))
	else:
		var outline := PackedVector2Array([Vector2(-w*0.5,h),Vector2(w*0.5,h)])
		for i in range(9,-1,-1):
			var t := i/9.0
			outline.append(Vector2(w*(0.12+0.38*t),h*0.80*t*t))
		for i in 10:
			var t := i/9.0
			outline.append(Vector2(-w*(0.12+0.38*t),h*0.80*t*t))
		prism(st, outline, d, minf(bevel,h*0.06))
	return Data.new(st)


static func block(w: float, slot: float, bevel := 0.003) -> Data:
	var st := begin(0)
	var h := w*0.62
	var low := w*0.34
	var half := w*0.5
	var floor_y := h*0.72
	var bottom := PackedVector3Array([Vector3(-low,0,-low),Vector3(low,0,-low),
		Vector3(low,0,low),Vector3(-low,0,low)])
	var rim := PackedVector3Array([Vector3(-half,floor_y,-half),Vector3(half,floor_y,-half),
		Vector3(half,floor_y,half),Vector3(-half,floor_y,half)])
	Kit._add_quad(st,bottom[0],bottom[1],bottom[2],bottom[3],Vector3.DOWN)
	Kit._add_quad(st,rim[0],rim[1],rim[2],rim[3],Vector3.UP)
	for i in 4:
		var j := (i+1)%4
		var n := (bottom[j]-bottom[i]).cross(rim[i]-bottom[i]).normalized()
		if n.dot((bottom[i]+bottom[j])*0.5)<0:
			n = -n
		Kit._add_quad(st,bottom[i],bottom[j],rim[j],rim[i],n)
	# 四耳间的真实十字槽，槽底承托栱身；没有整盒体藏在槽中。
	var channel := clampf(slot, w*0.30, w*0.80)
	var ear := (w-channel)*0.5
	var y := (floor_y+h)*0.5
	for x in [-1.0,1.0]:
		for z in [-1.0,1.0]:
			var center := Vector3(x*(channel+ear)*0.5,y,z*(channel+ear)*0.5)
			var p := PackedVector2Array([Vector2(-ear*0.5,-(h-floor_y)*0.5),
				Vector2(ear*0.5,-(h-floor_y)*0.5),Vector2(ear*0.5,(h-floor_y)*0.5),
				Vector2(-ear*0.5,(h-floor_y)*0.5)])
			prism(st,p,ear,minf(bevel,ear*0.12),Transform3D(Basis.IDENTITY,center))
	return Data.new(st)


static func ang(length: float, bevel := 0.003) -> Data:
	var st := begin(2)
	var outline := PackedVector2Array([Vector2(-length*0.5,-0.06),Vector2(length*0.28,-0.06),
		Vector2(length*0.48,-0.12),Vector2(length*0.5,-0.095),Vector2(length*0.41,0.065),
		Vector2(-length*0.5,0.065)])
	prism(st,outline,0.135,bevel,Transform3D(Basis(Vector3.UP,-PI*0.5),Vector3.ZERO))
	return Data.new(st)
