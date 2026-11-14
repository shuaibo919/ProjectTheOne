extends RefCounted
## 外壳公共装配：可见围护、柱梁、楼面及相交屋面；不复原隐藏榫卯。
const Plan := preload("res://addons/ancient_building/core/plan_geometry.gd")
const Roof := preload("res://addons/ancient_building/core/roof_layout.gd")
const Damage := preload("res://addons/ancient_building/core/mesh_damage.gd")
const Variation := preload("res://addons/ancient_building/core/building_variation.gd")
const VALLEY_CUTBACK := 0.11
const SEAM_EPS := 0.001
# Covers both tile relief and the thickest custom thatch patch. A roof entirely
# below another body's wall top meets that wall, not the overhanging upper roof.
const COVER_CLEARANCE := 0.32


static func surface(out: Array, id: String, poly: PackedVector2Array, plane: Vector3,
		depth: float, finish: String, extra: Dictionary = {}, precise := false) -> void:
	if poly.size() < 3:
		return
	var center := Vector2.ZERO
	for p in poly:
		center += p / poly.size()
	# Quantize in one building-wide grid, not relative to independent centroids.
	center = center.snapped(Vector2.ONE*0.001)
	var position := Vector3(center.x, Plan.height(plane, center), center.y)
	var points := PackedVector3Array()
	for p in poly:
		if not precise:
			p = p.snapped(Vector2.ONE*0.001)
		points.append(Vector3(p.x, Plan.height(plane, p), p.y) - position)
	var rounded := PackedVector2Array()
	for p in points:
		rounded.append(Vector2(p.x,p.z))
	var minimum_area := 0.00001 if precise and extra.get("kind","prism") in ["prism","gutter"] else 0.0001
	if absf(Plan.area(rounded)) < minimum_area:
		return
	var shape := {"kind":"prism", "points":Plan.encode(points), "depth":roundi(depth * 1000)}
	if precise:
		# 模板尺寸仍为整数毫米；定制屋面交点保留整数微米残差。
		# 不独立移动裁片的顶点，避免 T 点、短边在毫米舍入后折回/开裂。
		var residuals: Array = []
		for i in points.size():
			var residual: Array = []
			for axis in 3:
				var micrometres := roundi(points[i][axis]*1000000.0)
				shape.points[i][axis] = roundi(micrometres/1000.0)
				residual.append(micrometres-int(shape.points[i][axis])*1000)
			residuals.append(residual)
		shape.point_residuals = residuals
	shape.merge(extra, true)
	if shape.kind == "cover":
		shape.grid_origin = [roundi(position.x * 1000), roundi(position.z * 1000)]
		# A sliver can start with three collinear rounded points. Keep the solved
		# source plane rather than reconstructing a different plane from them.
		shape.plane = [roundi(plane.x*1000000),roundi(plane.y*1000000),0]
	out.append({"id":id, "position":position, "geometry":shape, "material_set":finish})


static func line(out: Array, id: String, a: Vector3, b: Vector3, kind := "ridge", extra: Dictionary = {}, finish := "M_Default") -> void:
	var minimum_length := SEAM_EPS if bool(extra.get("upstand", false)) or bool(extra.get("seam", false)) else 0.04
	if a.distance_to(b) < minimum_length:
		return
	if kind=="ridge" and extra.has("ridge_domain_world"):
		var axis := Vector2(b.x-a.x,b.z-a.z).normalized()
		var normal := Vector2(-axis.y,axis.x)
		var origin := Vector2(a.x,a.z)
		var domain := PackedVector2Array()
		for point in extra.ridge_domain_world:
			var offset: Vector2 = point-origin
			domain.append(Vector2(offset.dot(axis),offset.dot(normal)))
		# Only the part of the miter domain reached by the actual ridge section
		# matters. At a narrow roof angle that reach can exceed the old 0.40 m
		# source extension, even though the main roof itself is perfectly valid.
		var half_width := maxf(float(extra.get("breadth",180)),float(extra.get("foot_width",0)))*0.00053
		domain = Plan.clip(Plan.clip(Plan.clean(domain),Vector2.UP,half_width),Vector2.DOWN,half_width)
		if not domain.is_empty():
			var reach := Plan.bounds(domain)
			var length := Vector2(b.x-a.x,b.z-a.z).length()
			var along := (b-a)/length
			var original_a := a
			# Keep free-end caps exactly where they already are. Extend only a
			# source end that fails to cover its miter, then remove that cap outside
			# the final domain when ShellGeometry clips the complete ridge shell.
			if reach.position.x < -0.00001:
				a = original_a+along*(reach.position.x-0.002)
			if reach.end.x > length+0.00001:
				b = original_a+along*(reach.end.x+0.002)
	var center := (a + b) * 0.5
	var shape := {"kind":kind, "points":Plan.encode(PackedVector3Array([a - center, b - center]))}
	shape.merge(extra, true)
	if shape.has("ridge_domain_world"):
		var domain := PackedVector3Array()
		for point in shape.ridge_domain_world:
			domain.append(Vector3(point.x-center.x,0,point.y-center.z))
		shape.erase("ridge_domain_world")
		shape.ridge_domain = Plan.encode(domain)
		shape.domain_residuals = _point_residuals(domain,shape.ridge_domain)
	out.append({"id":id, "position":center, "geometry":shape, "material_set":finish})


## 裁掉落在其他屋面以下的线饰；跨第三个体量时也必须分段判断。
static func exposed_line(out: Array, id: String, a: Vector3, b: Vector3, faces: Array,
		kind := "ridge", extra: Dictionary = {}, finish := "M_Default") -> void:
	var p := Vector2(a.x, a.z)
	var q := Vector2(b.x, b.z)
	var minimum_length := SEAM_EPS if bool(extra.get("upstand", false)) or bool(extra.get("seam", false)) else 0.04
	if p.distance_to(q) < minimum_length:
		return
	var polygons: Array = []
	for face in faces:
		polygons.append(face.poly)
		if _has_body(face):
			polygons.append(face.body)
	var cuts := Plan.breaks(p, q, polygons)
	for face in faces:
		var da: float = a.y - Plan.height(face.plane, p)
		var db: float = b.y - Plan.height(face.plane, q)
		if da * db < 0 and absf(da - db) > 0.00001:
			cuts.append(da / (da - db))
		if _has_body(face):
			var low_a: float = a.y + COVER_CLEARANCE - float(face.wall_top)
			var low_b: float = b.y + COVER_CLEARANCE - float(face.wall_top)
			if low_a * low_b < 0 and absf(low_a - low_b) > 0.00001:
				cuts.append(low_a / (low_a - low_b))
	cuts.sort()
	var visible_start := -1.0
	var visible_end := 0.0
	for i in range(cuts.size() - 1):
		if cuts[i + 1] <= cuts[i]:
			continue
		var middle := a.lerp(b, (cuts[i] + cuts[i + 1]) * 0.5)
		var hidden := false
		for face in faces:
			if _line_hidden(middle, face):
				hidden = true
				break
		if not hidden:
			if visible_start < 0.0:
				visible_start = cuts[i]
			visible_end = cuts[i + 1]
		elif visible_start >= 0.0:
			line(out, id, a.lerp(b, visible_start), a.lerp(b, visible_end), kind, extra, finish)
			visible_start = -1.0
	# Face subdivision is not a physical gap. Merge contiguous visible spans
	# before the length threshold, while every genuinely hidden span breaks a run.
	if visible_start >= 0.0:
		line(out, id, a.lerp(b, visible_start), a.lerp(b, visible_end), kind, extra, finish)


static func _has_body(face: Dictionary) -> bool:
	return face.has("body") and face.has("wall_top") and face.body.size() >= 3


static func _same_roof(a: Dictionary, b: Dictionary) -> bool:
	if a.has("roof_group") and b.has("roof_group"):
		return a.roof_group == b.roof_group
	return a.owner == b.owner


static func _body_pair(a: Dictionary, b: Dictionary) -> bool:
	return _has_body(a) and _has_body(b) and not _same_roof(a, b)


## 已规划的屋面分区只有共边，没有上下包络竞争。高低独立屋顶同样
## 必须保留自身结构，不能再被另一个体量的墙顶/屋面二次吞掉。
static func _planned_pair(a: Dictionary, b: Dictionary) -> bool:
	var id := _roof_id(b)
	return id in a.get("roof_joint_groups",[]) or id in a.get("separate_roof_groups",[]) or _roof_id(a) in b.get("roof_joint_groups",[]) or _roof_id(a) in b.get("separate_roof_groups",[])


static func _line_hidden(point: Vector3, face: Dictionary) -> bool:
	var xz := Vector2(point.x, point.z)
	if not Plan.inside(xz, face.poly):
		return false
	if _has_body(face) and point.y + COVER_CLEARANCE <= float(face.wall_top):
		return Plan.inside(xz, face.body)
	return Plan.height(face.plane, xz) > point.y + 0.01


## Only the portion where both roofs reach the neighbouring wall top can form
## a roof-to-roof joint. Lower portions instead terminate against the body.
static func _roof_joint_region(poly: PackedVector2Array, a: Dictionary, b: Dictionary) -> PackedVector2Array:
	if not _body_pair(a, b):
		return poly
	var a_plane: Vector3 = a.plane
	var b_plane: Vector3 = b.plane
	var region := Plan.clip(poly, -Vector2(a_plane.x, a_plane.y),
		a_plane.z + COVER_CLEARANCE - float(b.wall_top))
	return Plan.clip(region, -Vector2(b_plane.x, b_plane.y),
		b_plane.z + COVER_CLEARANCE - float(a.wall_top))


static func beam(out: Array, a: Vector2, b: Vector2, y: float) -> void:
	var d := b - a
	var center := (a + b) * 0.5
	Roof.part(out, "F04", Vector3(center.x, y, center.y), {"height":0.22, "depth":0.22},
		d.length(), rad_to_deg(-atan2(d.y, d.x)))


static func post(out: Array, p: Vector2, bottom: float, top: float, radius: float, ground: bool) -> void:
	var foot := 0.25 if ground else 0.0
	if ground:
		Roof.part(out, "B12", Vector3(p.x, bottom, p.y), {"height":foot, "radius":radius * 1.65})
	Roof.part(out, "F01", Vector3(p.x, (bottom + foot + top) * 0.5, p.y),
		{"radius":radius, "height":top - bottom - foot, "sides":24})
	Roof.part(out, "F08", Vector3(p.x, top, p.y), {"width":radius * 1.9})


static func wall(out: Array, a: Vector2, b: Vector2, low_a: float, low_b: float,
		top: float, construction: String, opening: String, detail: Dictionary, top_b := -INF) -> void:
	if not is_finite(top_b):
		top_b = top
	var delta := b - a
	var width := delta.length()
	if width < 0.05 or top <= minf(low_a, low_b) + 0.02:
		return
	var center := (a + b) * 0.5
	# 围护落在柱网内侧，让柱、额枋与门窗框实际露出，不能被厚墙埋住。
	var inward := Vector2(-delta.y, delta.x).normalized()
	var thickness := float(detail.get("wall_thickness", 0.32))
	var wall_center := center + inward * thickness * 0.5
	var base := minf(low_a, low_b)
	var poly := Plan.clean(PackedVector2Array([Vector2(-width * 0.5, low_a - base),
		Vector2(width * 0.5, low_b - base), Vector2(width * 0.5, top_b - base), Vector2(-width * 0.5, top - base)]))
	if poly.is_empty():
		return
	var pieces: Array = [poly]
	var yaw := rad_to_deg(-atan2(delta.y, delta.x))
	if opening == "open":
		return
	if opening in ["door", "window"] and width >= 1.25 and top - base >= 2.1:
		var hole_w := minf(1.45 if opening == "door" else 1.0, width - 0.44)
		var sill := 0.0 if opening == "door" else 0.85
		var hole_h := minf(2.15 if opening == "door" else 1.35, top - base - sill - 0.25)
		var cut := PackedVector2Array([Vector2(-hole_w * 0.5, sill), Vector2(hole_w * 0.5, sill),
			Vector2(hole_w * 0.5, sill + hole_h), Vector2(-hole_w * 0.5, sill + hole_h)])
		pieces = Plan.subtract(poly, cut)
		var opening_center := center + inward * 0.10
		var pos := Vector3(opening_center.x, base + sill + hole_h * 0.5, opening_center.y)
		Roof.part(out, "O01" if opening == "door" else "O06", pos,
			{"width":hole_w, "height":hole_h, "depth":0.24, "frame":0.09}, -1, yaw)
		if opening == "window":
			Roof.part(out, "O02", pos, {"width":hole_w - 0.1, "height":hole_h - 0.1, "thickness":0.06,
				"pattern":int(detail.get("lattice_style", 0)), "bars":int(detail.lattice_bars), "bar":float(detail.lattice_bar)}, -1, yaw)
	var style := int({"frame":0, "earth":1, "timber":2, "log":3}.get(construction, 0))
	var finish := String({"frame":"M_Default", "earth":"M_Earth", "timber":"M_Planks", "log":"M_Log"}[construction])
	for piece in pieces:
		var points := PackedVector3Array()
		var rounded := PackedVector2Array()
		for p in piece:
			points.append(Vector3(p.x, p.y, 0))
			rounded.append(p.snapped(Vector2.ONE * 0.001))
		if absf(Plan.area(rounded)) < 0.0001:
			continue
		out.append({"id":"W01", "position":Vector3(wall_center.x, base, wall_center.y), "rotation_y":yaw,
			"geometry":{"kind":"wall", "points":Plan.encode(points), "style":style},
			"params":{"height":maxf(0.3, maxf(top, top_b) - base), "thickness":thickness,
				"wall_kind":style, "board_width":float(detail.get("board_width", 0.18)),
				"log_diameter":float(detail.get("log_diameter", 0.22))}, "material_set":finish})


static func face(poly: PackedVector2Array, plane: Vector3, owner: int, direction: Vector2,
		covering: String, pitch: float) -> Dictionary:
	return {"poly":Plan.clean(poly), "plane":plane, "owner":owner, "direction":direction,
		"covering":covering, "pitch":pitch, "bounds":Plan.bounds(poly)}


static func emit_roofs(out: Array, faces: Array, only_owner := -1, seams: Dictionary = {}) -> Array:
	if seams.is_empty():
		seams = seam_graph(faces)
	var exposed: Array = []
	for i in faces.size():
		var current: Dictionary = faces[i]
		if only_owner >= 0 and current.owner != only_owner:
			continue
		var cells: Dictionary = seams.surfaces[seams.faces.find(current)]
		var visible: Array = cells.visible
		# 望板保持连续；瓦层和谷沟从同一有限责任带分割，不能各自猜退让边界。
		var boarding: Array = cells.field if seams.get("explicit",false) else visible
		for poly in boarding:
			surface(out, "R01", poly, current.plane - Vector3(0,0,0.025), 0.075, "M_AgedTimber",{},true)
		if seams.get("explicit",false):
			for cell in cells.channels:
				_channel_surface(out,"R01",cell,current.plane,-0.025,0.075,"M_AgedTimber")
		var fragments: Array = cells.field
		for poly in fragments:
			var direction: Vector2 = current.direction
			var id := "R01" if current.covering == "thatch" else "R03"
			surface(out, id, poly, current.plane + Vector3(0, 0, 0.035), 0.02,
				"M_Thatch" if current.covering == "thatch" else "M_Default", {"kind":"cover",
				"covering":current.covering, "pitch":roundi(current.pitch * 1000),
					"direction":[roundi(direction.x * 10000), roundi(direction.y * 10000)],
					"edge_seals":_gutter_edge_seals(poly,cells.gutter)},true)
			exposed.append({"poly":poly, "plane":current.plane, "owner":current.owner})
	return exposed


static func _visible_roof(faces: Array, index: int) -> Array:
	var current: Dictionary = faces[index]
	var fragments: Array = [current.poly]
	for j in faces.size():
		if index == j or not current.bounds.intersects(faces[j].bounds):
			continue
		var other: Dictionary = faces[j]
		if _planned_pair(current,other):
			continue
		var delta: Vector3 = current.plane - other.plane
		var masks: Array = []
		if _body_pair(current, other):
			var body := Plan.intersect(other.poly, other.body)
			var plane: Vector3 = current.plane
			body = Plan.clip(body, Vector2(plane.x, plane.y), float(other.wall_top) - COVER_CLEARANCE - plane.z)
			if not body.is_empty():
				masks.append(body)
		var mask := PackedVector2Array()
		if delta.length() < 0.0001:
			if j < index:
				mask = other.poly
		else:
			# 两侧必须共享同一等高线；高度偏移在近乎平行的缓坡上会放大成毫米重叠。
			mask = Plan.clip(other.poly, Vector2(delta.x, delta.y), -delta.z)
		mask = _roof_joint_region(mask, current, other)
		if not mask.is_empty():
			masks.append(mask)
		for cut in masks:
			var remaining: Array = []
			for fragment in fragments:
				remaining.append_array(Plan.subtract(fragment, cut))
			fragments = remaining
		if fragments.is_empty():
			break
	return fragments


static func _roof_id(face: Dictionary) -> String:
	return String(face.roof_group) if face.has("roof_group") else str(face.owner)


static func _seam_node_key(point: Vector3) -> String:
	return "%d,%d,%d" % [roundi(point.x/SEAM_EPS),roundi(point.y/SEAM_EPS),roundi(point.z/SEAM_EPS)]


## 原段和 hub 全局解出有限交线，拆交点和重叠区间后生成唯一边图。
static func seam_graph(faces: Array, explicit_plan: Dictionary = {}) -> Dictionary:
	if not explicit_plan.is_empty():
		return _planned_seam_graph(faces,explicit_plan)
	var segments: Array = []
	for i in faces.size():
		for j in range(i + 1, faces.size()):
			var a: Dictionary = faces[i]
			var b: Dictionary = faces[j]
			if _same_roof(a, b) or _planned_pair(a,b) or not a.bounds.intersects(b.bounds):
				continue
			var overlap := _roof_joint_region(Plan.intersect(a.poly, b.poly), a, b)
			if overlap.is_empty():
				continue
			var delta: Vector3 = a.plane - b.plane
			var normal := Vector2(delta.x, delta.y)
			if normal.length() < 0.001:
				continue
			var points: Array[Vector2] = []
			for k in overlap.size():
				var p: Vector2 = overlap[k]
				var q: Vector2 = overlap[(k + 1) % overlap.size()]
				var dp := normal.dot(p) + delta.z
				var dq := normal.dot(q) + delta.z
				if absf(dp) < 0.0001:
					points.append(p)
				elif dp * dq < 0:
					points.append(p.lerp(q, dp / (dp - dq)))
			if points.size() < 2:
				continue
			var tangent := Vector2(-normal.y, normal.x).normalized()
			points.sort_custom(func(p, q): return p.dot(tangent) < q.dot(tangent))
			if points[0].distance_to(points[-1]) < SEAM_EPS:
				continue
			exposed_line(segments, "R09", Vector3(points[0].x, Plan.height(a.plane, points[0]) + 0.035, points[0].y),
				Vector3(points[-1].x, Plan.height(a.plane, points[-1]) + 0.035, points[-1].y), faces, "gutter",
				{"seam":true,"groups":[_roof_id(a),_roof_id(b)]})
	var raw: Array = []
	for row in segments:
		var points := Plan.decode(row.geometry.points)
		raw.append({"a":points[0]+row.position,"b":points[-1]+row.position,"groups":row.geometry.groups})
	var edges := {}
	var nodes := {}
	for segment in raw:
		var a: Vector3 = segment.a
		var b: Vector3 = segment.b
		var length := a.distance_to(b)
		if length < SEAM_EPS:
			continue
		var cuts: Array[float] = [0.0, 1.0]
		var direction := b-a
		var p := Vector2(a.x,a.z)
		var d := Vector2(direction.x,direction.z)
		for other in raw:
			# 端点投影同时拆开部分重叠边，不以中点哈希误删旁边的短边。
			for point in [other.a,other.b]:
				var t: float = clampf((point-a).dot(direction)/direction.length_squared(),0,1)
				if point.distance_to(a+direction*t) <= SEAM_EPS*2.0:
					cuts.append(t)
			var q := Vector2(other.a.x,other.a.z)
			var e := Vector2(other.b.x-other.a.x,other.b.z-other.a.z)
			var cross_value := d.cross(e)
			if absf(cross_value) > 0.0000001:
				var t := (q-p).cross(e)/cross_value
				var u := (q-p).cross(d)/cross_value
				if t>0 and t<1 and u>=0 and u<=1 and absf(lerpf(a.y,b.y,t)-lerpf(other.a.y,other.b.y,u))<SEAM_EPS*2.0:
					cuts.append(t)
		cuts.sort()
		for k in range(cuts.size()-1):
			var first := a.lerp(b,cuts[k]).snapped(Vector3.ONE*SEAM_EPS)
			var last := a.lerp(b,cuts[k+1]).snapped(Vector3.ONE*SEAM_EPS)
			if first.distance_to(last) < SEAM_EPS:
				continue
			var first_key := _seam_node_key(first)
			var last_key := _seam_node_key(last)
			if first_key > last_key:
				var swap := first
				first = last
				last = swap
				first_key = _seam_node_key(first)
				last_key = _seam_node_key(last)
			var key := first_key+":"+last_key
			if not edges.has(key):
				edges[key] = {"a":first,"b":last,"groups":[]}
				for point_key in [first_key,last_key]:
					if not nodes.has(point_key):
						nodes[point_key] = []
					nodes[point_key].append(key)
			for group in segment.groups:
				if group not in edges[key].groups:
					edges[key].groups.append(group)
	var keys: Array = edges.keys()
	keys.sort()
	var bands: Array = []
	for key in keys:
		var edge: Dictionary = edges[key]
		var a := Vector2(edge.a.x,edge.a.z)
		var b := Vector2(edge.b.x,edge.b.z)
		var n := Vector2(-(b-a).y,(b-a).x).normalized()*VALLEY_CUTBACK
		edge.poly = Plan.clean(PackedVector2Array([a-n,b-n,b+n,a+n]))
		bands.append(edge)
	var result := {"edges":edges,"nodes":nodes,"bands":bands,"paths":_seam_paths(edges,nodes),"faces":faces}
	result.surfaces = _roof_surfaces(faces,result)
	return result


## 同高屋面由正脊拓扑直接提供谷/凸脊。这里仅将曲线坡段离散为
## 共享责任带；凸脊不退瓦、不生成谷沟，也不重新求任意屋面交线。
static func _planned_seam_graph(faces: Array, plan: Dictionary) -> Dictionary:
	var edges := {}
	var nodes := {}
	var bands: Array = []
	var paths: Array = []
	for seam in plan.get("seams",[]):
		var points: PackedVector3Array = seam.points
		paths.append(points)
		for i in range(points.size()-1):
			var a: Vector3 = points[i]
			var b: Vector3 = points[i+1]
			var first := _seam_node_key(a)
			var last := _seam_node_key(b)
			var key := first+":"+last
			var edge := {"a":a,"b":b,"groups":seam.groups,"kind":seam.kind,"width":seam.width}
			edges[key] = edge
			for point_key in [first,last]:
				if not nodes.has(point_key):
					nodes[point_key] = []
				nodes[point_key].append(key)
			if seam.kind!="valley":
				continue
			var p := Vector2(a.x,a.z)
			var q := Vector2(b.x,b.z)
			var n := Vector2(-(q-p).y,(q-p).x).normalized()*float(seam.width)*0.5
			var band: Dictionary = edge.duplicate()
			# At the ridge intersection a valley starts at one point. A rectangular
			# butt across the ridge would create a lowered channel edge against the
			# unlowered tile cut. The outlet extends past the roof and is clipped by
			# its real eave, so it cannot create that same false butt at the other end.
			var start_n := Vector2.ZERO if i==0 else n
			if i==points.size()-2:
				var extension: Vector3 = (b-a)*(float(seam.width)*2.0/p.distance_to(q))
				band.b = b+extension
				q = Vector2(band.b.x,band.b.z)
			band.start_width = 0.0 if i==0 else float(seam.width)
			band.poly = Plan.clean(PackedVector2Array([p-start_n,q-n,q+n,p+start_n]))
			bands.append(band)
	var result := {"edges":edges,"nodes":nodes,"bands":bands,"paths":paths,"faces":faces,
		"explicit":true,"planned_seams":plan.get("seams",[]),"junctions":plan.get("junctions",[])}
	result.surfaces = _roof_surfaces(faces,result)
	return result


## 只在二度节点继续路径；分叉点绝不被贪心连接成自交折线。
static func _seam_paths(edges: Dictionary, nodes: Dictionary) -> Array:
	var paths: Array = []
	var used := {}
	var starts: Array = []
	for key in nodes:
		if nodes[key].size() != 2:
			starts.append(key)
	starts.sort()
	# 第二轮覆盖闭环；共享 used 使每条边只进入一个路径。
	for key in nodes:
		if nodes[key].size() == 2:
			starts.append(key)
	for start in starts:
		for first_edge in nodes[start]:
			if used.has(first_edge):
				continue
			var path := PackedVector3Array()
			var current: String = start
			var edge_key: String = first_edge
			while not used.has(edge_key):
				used[edge_key] = true
				var edge: Dictionary = edges[edge_key]
				var a: Vector3 = edge.a if _seam_node_key(edge.a)==current else edge.b
				var b: Vector3 = edge.b if _seam_node_key(edge.a)==current else edge.a
				if path.is_empty():
					path.append(a)
				path.append(b)
				current = _seam_node_key(b)
				if nodes[current].size() != 2:
					break
				var next_edges: Array = nodes[current]
				edge_key = next_edges[1] if next_edges[0]==edge_key else next_edges[0]
			paths.append(path)
	return paths


static func _split_seam_bands(visible: Array, current: Dictionary, seams: Dictionary) -> Dictionary:
	var remaining := visible.duplicate()
	var gutters: Array = []
	var channels: Array = []
	for band in seams.bands:
		if _roof_id(current) not in band.groups or band.poly.is_empty():
			continue
		var next: Array = []
		for poly in remaining:
			var contact := Plan.intersect(poly,band.poly)
			if not contact.is_empty():
				gutters.append(contact)
				channels.append({"poly":contact,"band":band})
			next.append_array(Plan.subtract(poly,band.poly))
		remaining = next
	# 亚平方厘米的裁切余片无法容纳一个稳定瓦片截面，交给同平面的谷沟
	# 收口；不把它们删除成孔洞，也不在瓦面上另外叠盖一层。
	if not seams.bands.is_empty() and not seams.get("explicit",false):
		var fields: Array = []
		for poly in remaining:
			if absf(Plan.area(poly))<0.0001:
				gutters.append(poly)
			else:
				fields.append(poly)
		remaining = fields
	return {"field":remaining,"gutter":gutters,"channels":channels}


## 瓦层与谷沟共享一次求解的可见面和分割，缓存不会各自生成不同边界。
static func _roof_surfaces(faces: Array, seams: Dictionary) -> Array:
	var surfaces: Array = []
	for i in faces.size():
		var visible := _visible_roof(faces,i)
		var cells := _split_seam_bands(visible,faces[i],seams)
		cells.visible = visible
		surfaces.append(cells)
	return surfaces


## 标记真实瓦作—谷沟交界，不能封闭内部坡面细分边或整条延长裁切线。
## 每段为 [轮廓边索引, 起点百万分比, 终点百万分比]，不改变顶点协议。
static func _gutter_edge_seals(poly: PackedVector2Array, gutters: Array) -> Array:
	var result: Array = []
	for i in poly.size():
		var a := poly[i]
		var delta := poly[(i+1)%poly.size()]-a
		var length := delta.length()
		if length<0.00001:
			continue
		var intervals: Array[Vector2] = []
		for gutter in gutters:
			for j in gutter.size():
				var c: Vector2 = gutter[j]-a
				var d: Vector2 = gutter[(j+1)%gutter.size()]-a
				if absf(delta.cross(c))/length>0.00002 or absf(delta.cross(d))/length>0.00002:
					continue
				var t := c.dot(delta)/delta.length_squared()
				var u := d.dot(delta)/delta.length_squared()
				var low := clampf(minf(t,u),0,1)
				var high := clampf(maxf(t,u),0,1)
				if (high-low)*length>0.00001:
					intervals.append(Vector2(low,high))
		intervals.sort_custom(func(a,b): return a.x<b.x)
		var merged: Array[Vector2] = []
		for interval in intervals:
			if not merged.is_empty() and interval.x<=merged[-1].y+0.00001:
				merged[-1].y = maxf(merged[-1].y,interval.y)
			else:
				merged.append(interval)
		for interval in merged:
			result.append([i,roundi(interval.x*1000000),roundi(interval.y*1000000)])
	return result


static func join_seams(out: Array, faces: Array, only_owner := -1, seams: Dictionary = {}) -> void:
	if seams.is_empty():
		seams = seam_graph(faces)
	if seams.get("explicit",false):
		_join_planned_seams(out,faces,only_owner,seams)
		return
	for i in faces.size():
		var current: Dictionary = faces[i]
		if only_owner >= 0 and current.owner != only_owner:
			continue
		var split: Dictionary = seams.surfaces[seams.faces.find(current)]
		for poly in split.gutter:
			# 与瓦层使用同一个分割结果。支沟交点由各自坡面的无重叠片共同封口，
			# 不叠放盖片，也不把断开的细分边当成开放的物理缝隙。
			surface(out,"R09",poly,current.plane+Vector3(0,0,0.035),0.012,"M_Default",{},true)


static func _join_planned_seams(out: Array, faces: Array, only_owner: int, seams: Dictionary) -> void:
	for i in faces.size():
		var current: Dictionary = faces[i]
		if only_owner>=0 and current.owner!=only_owner:
			continue
		var split: Dictionary = seams.surfaces[seams.faces.find(current)]
		for cell in split.channels:
			_channel_surface(out,"R09",cell,current.plane,0.035,0.028,"M_Default")
	if only_owner>=0:
		return
	for seam in seams.planned_seams:
		if seam.kind!="hip":
			continue
		var points: PackedVector3Array = seam.points.duplicate()
		for i in points.size():
			points[i] += Vector3.UP*0.10
		var origin: Vector3 = points[0]
		for i in points.size():
			points[i] -= origin
		out.append({"id":"R07","position":origin,"geometry":{"kind":"ridge","points":Plan.encode(points),
			"breadth":220,"height":150,"joint_spacing":400,"seam_kind":"hip"},"material_set":"M_Default"})


static func _channel_surface(out: Array, id: String, cell: Dictionary, plane: Vector3,
		offset: float, depth: float, material: String) -> void:
	var before := out.size()
	surface(out,id,cell.poly,plane+Vector3(0,0,offset),depth,material,
		{"kind":"gutter","channel":true,"breadth":roundi(float(cell.band.width)*1000),
			"start_breadth":roundi(float(cell.band.get("start_width",cell.band.width))*1000),"rim_height":80},true)
	if out.size()==before:
		return
	var origin: Vector3 = out[-1].position
	var a: Vector3 = cell.band.a+Vector3.UP*offset-origin
	var b: Vector3 = cell.band.b+Vector3.UP*offset-origin
	out[-1].geometry.channel_line = Plan.encode(PackedVector3Array([a,b]))
	out[-1].geometry.channel_residuals = _point_residuals(PackedVector3Array([a,b]),out[-1].geometry.channel_line)


static func _point_residuals(points: PackedVector3Array, rounded: Array) -> Array:
	var result: Array = []
	for i in points.size():
		var row: Array = []
		for axis in 3:
			row.append(roundi(points[i][axis]*1000000)-int(rounded[i][axis])*1000)
		result.append(row)
	return result


static func finish(out: Array, spec: Dictionary, detail: Dictionary) -> void:
	var seed_value := int(spec.get("variation", {}).get("seed", 0))
	for row in out:
		if not row.has("material_set"):
			row.material_set = String(spec.get("material_set", "M_AgedTimber"))
		if row.id == "B12":
			row.params.style = int(detail.get("column_base",0))
		if row.id in ["R03","R04","R05","R06","R07","R08","R09","R11","R12"] and row.material_set != "M_Thatch":
			row.material_set = ["M_Default","M_GlazedGreen","M_GlazedSlate"][int(detail.get("roof_palette",0))]
		if row.id in ["F02","F05"] and int(detail.get("beam_pattern",0))>0:
			row.material_set = ["M_AgedTimber","M_TimberLines","M_TimberDiamond"][int(detail.beam_pattern)]
		if int(detail.get("surface_palette",0))==1:
			_street_palette(row,detail)
		if String(row.id) not in Damage.TARGETS:
			continue
		var family := Damage.family(row.id)
		if row.id == "R01" and (int(row.get("params", {}).get("covering", 0)) == 1 or row.get("geometry", {}).get("covering", "") == "thatch"):
			family = "roof"
		if row.id == "W01" and int(row.get("params", {}).get("wall_kind", 0)) >= 2:
			family = "wood"
		var amount := float(detail.get("damage", 0.0)) * float(detail.get("damage_" + family, 1.0))
		if amount <= 0:
			continue
		var p: Dictionary = row.get("params", {})
		p.damage = snappedf(amount, 0.05)
		p.damage_depth = detail.get("damage_depth", 0.06)
		p.damage_density = detail.get("damage_density", 0.7)
		p.damage_seed = int(Variation._sample(seed_value, "%s:%s" % [row.id, row.position]) * 8.0)
		row.params = p


static func _street_palette(row: Dictionary, detail: Dictionary) -> void:
	var id := String(row.id)
	var finish := String(row.material_set)
	if finish in ["M_Thatch","M_Earth","M_Paper","M_Bronze","M_RedLacquer","M_TimberLines","M_TimberDiamond"]:
		return
	if id=="R19":
		if finish=="M_ReedMat":
			row.material_set = "M_StreetReed"
		elif finish=="M_Planks":
			row.material_set = "M_StreetTimber"
	elif id in ["R03","R04","R05","R06","R07","R08","R09","R11","R12"]:
		if int(detail.get("roof_palette",0))==0:
			row.material_set = "M_StreetTile"
	elif finish=="M_Plaster" or id=="W01" and int(row.get("params",{}).get("wall_kind",0))<2:
		row.material_set = "M_StreetPlaster"
	elif id in ["B09","B10"] and finish!="M_Stone":
		row.material_set = "M_StreetTimber"
	elif id.begins_with("B") or id in ["W02","O05"]:
		row.material_set = "M_StreetStone"
	elif id not in ["O04","D03","O08"]:
		row.material_set = "M_StreetTimber"
