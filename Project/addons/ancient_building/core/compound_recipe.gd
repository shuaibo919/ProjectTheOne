extends RefCounted
## 线段图先规划屋面与接榀，再生成相应外壳；不让裁切反过来决定建筑拓扑。
const Plan := preload("res://addons/ancient_building/core/plan_geometry.gd")
const Shell := preload("res://addons/ancient_building/core/building_shell.gd")
const Supports := preload("res://addons/ancient_building/core/compound_supports.gd")
const Junction := preload("res://addons/ancient_building/core/junction_roof.gd")


static func assemble(spec: Dictionary, detail: Dictionary, session: Dictionary = {}) -> Dictionary:
	var graph: Variant = spec.get("plan", {})
	if not graph is Dictionary or not graph.has("nodes") or not graph.has("segments"):
		return {"error":"plan 需要 nodes 与 segments 数组"}
	if not graph.nodes is Array or not graph.segments is Array:
		return {"error":"plan 需要 nodes 与 segments 数组"}
	if graph.nodes.size() > 32 or graph.segments.is_empty() or graph.segments.size() > 16:
		return {"error":"连体编辑支持 1–16 段、最多 32 个节点"}
	var nodes := {}
	for node in graph.nodes:
		if not node is Dictionary or String(node.get("id", "")).is_empty() or nodes.has(node.id):
			return {"error":"节点需要唯一非空 id"}
		var pos: Variant = node.get("position", [])
		if not pos is Array or pos.size() != 2:
			return {"error":"节点 %s 需要 X/Z 坐标" % node.id}
		for value in pos:
			if not (value is float or value is int) or not is_finite(value) or absf(value) > 250:
				return {"error":"节点坐标须为 ±250 m 内的有限数值"}
		nodes[node.id] = Vector2(pos[0], pos[1])
	var pieces: Array = []
	var ids := {}
	var connections := {}
	var edges := {}
	for segment in graph.segments:
		if not segment is Dictionary:
			return {"error":"segment 必须是对象"}
		var id := String(segment.get("id", ""))
		var start := String(segment.get("a", ""))
		var end := String(segment.get("b", ""))
		if id.is_empty() or ids.has(id) or not nodes.has(start) or not nodes.has(end) or start == end:
			return {"error":"线段 %s 的 id 或端点无效" % id}
		var pair: Array = [start, end]
		pair.sort()
		var edge_key := str(pair)
		if edges.has(edge_key):
			return {"error":"线段 %s 与已有线段重复" % id}
		edges[edge_key] = true
		ids[id] = true
		var a: Vector2 = nodes[start]
		var b: Vector2 = nodes[end]
		var width := float(segment.get("width", 4.0))
		var floors := int(segment.get("storeys", 1))
		var height := float(segment.get("floor_height", detail.floor_height))
		if not is_finite(width) or not is_finite(height) or width < 2 or width > 10 or height < 2.4 or height > 4.5:
			return {"error":"线段 %s：宽度需 2–10 m、层高需 2.4–4.5 m" % id}
		if a.distance_to(b) < 2 or a.distance_to(b) > 60 or floors < 1 or floors > 8:
			return {"error":"线段 %s：长度需 2–60 m、层数需 1–8" % id}
		var style := String(segment.get("construction", spec.get("construction", "timber")))
		var covering := String(segment.get("roof_covering", spec.get("roof_covering", "tile")))
		var form := String(segment.get("roof_form", "overhang"))
		if style not in ["frame", "earth", "timber", "log"] or covering not in ["tile", "thatch"] or form not in ["overhang", "hip"]:
			return {"error":"线段 %s：构造/覆盖无效；连体屋顶支持悬山或庑殿" % id}
		var dir := (b - a).normalized()
		var cross_dir := Vector2(-dir.y, dir.x)
		var poly := Plan.clean(PackedVector2Array([a - cross_dir * width * 0.5, b - cross_dir * width * 0.5,
			b + cross_dir * width * 0.5, a + cross_dir * width * 0.5]))
		pieces.append({"id":id, "a":a, "b":b, "poly":poly, "dir":dir, "width":width,
			"floors":floors, "height":height, "style":style, "covering":covering, "form":form,
			"top":float(detail.base_height) + floors * height + 0.20, "hub":false,
			"roof_group":id,
			"open":bool(segment.get("open_sides", false))})
		for node_id in [start, end]:
			if not connections.has(node_id):
				connections[node_id] = []
			connections[node_id].append(pieces.size() - 1)
	var support_plan := Supports.prepare(pieces,connections,nodes,detail)
	if support_plan.has("error"):
		return support_plan
	var roof_plan := Junction.prepare(pieces,connections,nodes,detail)
	if not String(roof_plan.get("error","")).is_empty():
		return roof_plan
	# A hub owns connecting floors only. Borrowing an arbitrary incident roof
	# creates a third, often lower slope that cuts fragments out of both wings.
	for node_id in connections:
		var incident: Array = connections[node_id]
		if incident.size() < 2:
			continue
		var corners := PackedVector2Array()
		var selected := int(incident[0])
		for index in incident:
			var piece: Dictionary = pieces[index]
			var normal := Vector2(-piece.dir.y, piece.dir.x) * float(piece.width) * 0.5
			corners.append(nodes[node_id] + normal)
			corners.append(nodes[node_id] - normal)
			if piece.top < pieces[selected].top or (is_equal_approx(piece.top,pieces[selected].top) and piece.id < pieces[selected].id):
				selected = index
		var hull := Plan.clean(Geometry2D.convex_hull(corners))
		if hull.is_empty():
			continue
		var source: Dictionary = pieces[selected]
		var hub := {"id":"joint:"+node_id,"poly":hull,"hub":true,
			"floors":source.floors,"height":source.height,"top":source.top}
		pieces.append(hub)
	var out: Array = []
	var faces: Array = []
	var footprints: Array = []
	for i in pieces.size():
		footprints.append(pieces[i].poly)
		if not pieces[i].hub:
			faces.append_array(_roof_faces(pieces[i], i, detail))
	var roof_error := Supports.validate_roofs(support_plan,pieces,faces,detail)
	if not roof_error.is_empty():
		return {"error":roof_error}
	# Only shared graph nodes authorize a roof connection. The former envelope
	# clip silently carved unrelated crossing wings but could not give them a
	# planned drainage joint; reject that unresolved geometry explicitly.
	for i in pieces.size():
		if pieces[i].hub:
			continue
		for j in range(i+1,pieces.size()):
			if pieces[j].hub or pieces[j].roof_group in pieces[i].get("separate_roof_groups",[]):
				continue
			var overlap := Plan.intersect(pieces[i].roof_poly,pieces[j].roof_poly)
			if not overlap.is_empty() and absf(Plan.area(overlap))>0.0001:
				if pieces[j].roof_group in pieces[i].get("roof_joint_groups",[]):
					return {"error":"线段 %s / %s：同高屋面分区自交，请拉开非相邻段或增大转角" % [pieces[i].id,pieces[j].id]}
				return {"error":"线段 %s / %s：存在未规划的屋面相交，请在交汇处建立共享节点或移开线段" % [pieces[i].id,pieces[j].id]}
	var seam_graph := Shell.seam_graph(faces,roof_plan)
	# 每段的几何只依赖自身和屋面范围相交的邻段；远处编辑不重算裁切。
	var previous: Dictionary = session.get("compound", {})
	var next_cache := {}
	var groups: Array = []
	var reused := 0
	for i in pieces.size():
		var relevant: Array = []
		var relevant_ids: Array = []
		var earlier: Array = []
		var local_footprints: Array = []
		var bounds := _piece_bounds(pieces[i]).grow(0.04)
		for j in pieces.size():
			if i == j or bounds.intersects(_piece_bounds(pieces[j]), true):
				relevant.append(pieces[j])
				relevant_ids.append(j)
				local_footprints.append(pieces[j].poly)
				if j < i:
					earlier.append(pieces[j])
		var inputs := {"piece":pieces[i], "neighbors":relevant, "earlier":earlier, "detail":detail, "seam_revision":3}
		var id: String = pieces[i].id
		var item: Dictionary
		if previous.has(id) and previous[id].inputs == inputs:
			item = previous[id]
			reused += 1
		else:
			var local_faces: Array = faces.filter(func(f): return f.owner in relevant_ids)
			item = {"inputs":inputs, "floors":[], "walls":[], "columns":{}, "roofs":[], "trim":[]}
			_emit_floors(item.floors, pieces[i], earlier, detail)
			item.exposed = []
			if not pieces[i].hub:
				_emit_walls(item.walls, pieces, i, local_footprints, local_faces, item.columns, detail)
				item.exposed = Shell.emit_roofs(item.roofs, local_faces, i, seam_graph)
				_roof_trim(item.trim, pieces[i], local_faces, detail, i)
		next_cache[id] = item
		groups.append(item)
	session.compound = next_cache
	session.compound_reused = reused
	session.compound_total = pieces.size()
	# 保持冷构建/增量/CLI 的顺序一致，缓存不携带 finish() 写入的材质与破损状态。
	for group in groups:
		out.append_array(group.floors.duplicate(true))
	var columns := {}
	for group in groups:
		out.append_array(group.walls.duplicate(true))
		for key in group.columns:
			if not columns.has(key):
				columns[key] = group.columns[key]
	for column in columns.values():
		Shell.post(out, column.point, column.bottom, column.top, float(detail.column_radius), column.ground)
	var exposed: Array = []
	for i in groups.size():
		out.append_array(groups[i].roofs.duplicate(true))
		for fragment in groups[i].exposed:
			var copy: Dictionary = fragment.duplicate()
			copy.owner = i
			exposed.append(copy)
	Shell.join_seams(out, faces, -1, seam_graph)
	for group in groups:
		out.append_array(group.trim.duplicate(true))
	var junctions: Array = support_plan.junctions.duplicate(true)
	junctions.append_array(roof_plan.get("junctions",[]))
	return {"placements":out, "roof_fragments":exposed, "footprints":footprints, "seam_graph":seam_graph,
		"junctions":junctions,"support_plan":support_plan,"roof_source_faces":faces}


static func _piece_bounds(piece: Dictionary) -> Rect2:
	return Plan.bounds(piece.poly).merge(Plan.bounds(piece.get("roof_poly",piece.poly)))


static func _emit_floors(out: Array, piece: Dictionary, earlier: Array, detail: Dictionary) -> void:
	for floor_index in piece.floors:
		var level: float = float(detail.base_height) + floor_index * float(piece.height)
		var floor_poly: PackedVector2Array = piece.get("frame_poly",piece.poly) if floor_index>0 else piece.poly
		var fragments: Array = [floor_poly]
		for prior in earlier:
			for prior_floor in prior.floors:
				var prior_level: float = float(detail.base_height) + prior_floor * float(prior.height)
				if roundi(prior_level * 1000) != roundi(level * 1000):
					continue
				var remaining: Array = []
				for fragment in fragments:
					var prior_poly: PackedVector2Array = prior.get("frame_poly",prior.poly) if prior_floor>0 else prior.poly
					remaining.append_array(Plan.subtract(fragment, prior_poly))
				fragments = remaining
		for fragment in fragments:
			Shell.surface(out, "B01" if floor_index == 0 else "F13", fragment, Vector3(0, 0, level),
				level if floor_index == 0 else 0.17, "M_Default" if floor_index == 0 else "M_AgedTimber")



static func _roof_height(piece: Dictionary, point: Vector2, detail: Dictionary) -> float:
	var roof_a: Vector2 = piece.get("roof_a",piece.a)
	var roof_b: Vector2 = piece.get("roof_b",piece.b)
	var center: Vector2 = (roof_a + roof_b) * 0.5
	var v := Vector2(-piece.dir.y, piece.dir.x)
	var half := float(piece.width) * 0.5 + float(detail.eave_depth)
	var t := clampf(1.0 - absf((point - center).dot(v)) / half, 0.0, 1.0)
	if piece.form == "hip":
		var along: float = (point - roof_a).dot(piece.dir) + float(detail.eave_depth)
		var length: float = roof_a.distance_to(roof_b) + float(detail.eave_depth) * 2.0
		t = minf(t, maxf(0, minf(along, length - along) / half))
	var eave_level := float(piece.get("roof_eave_level",piece.top))
	var ridge_level := float(piece.get("roof_ridge_level",eave_level+half*float(detail.roof_rise_ratio)*2.0))
	return eave_level+(ridge_level-eave_level)*t*(0.55+0.45*t)


static func _roof_trim(out: Array, piece: Dictionary, faces: Array, detail: Dictionary, owner: int) -> void:
	var eave := float(detail.eave_depth)
	var half := float(piece.width) * 0.5 + eave
	var start: Vector2 = piece.get("roof_a",piece.a) - piece.dir * eave
	var end: Vector2 = piece.get("roof_b",piece.b) + piece.dir * eave
	var inset := minf(half, start.distance_to(end) * 0.5) if piece.form == "hip" else 0.0
	var a: Vector2 = piece.get("ridge_start",start+piece.dir*inset)
	var b: Vector2 = piece.get("ridge_end",end-piece.dir*inset)
	var straw: bool = piece.covering == "thatch"
	if piece.form=="overhang" and piece.has("roof_joint_groups"):
		# Extend the source ridge past a shared node, then cut its actual shell
		# against the same miter domain as the roof. A butt cap or a short ridge
		# leaves a central hole; overlapping uncut end caps fight in depth.
		if piece.get("roof_joint_start",false):
			a -= piece.dir*0.40
		if piece.get("roof_joint_end",false):
			b += piece.dir*0.40
		var level := float(piece.roof_ridge_level)+(0.19 if straw else 0.10)
		Shell.line(out,"R06",Vector3(a.x,level,a.y),Vector3(b.x,level,b.y),"ridge",
			{"covering":piece.covering,"breadth":300 if straw else 220,"height":150,
				"ridge_domain_world":piece.roof_poly},"M_Thatch" if straw else "M_Default")
		return
	var paths: Array = [{"a":a, "b":b, "id":"R06"}]
	if piece.form == "hip":
		var cross_dir := Vector2(-piece.dir.y, piece.dir.x)
		for sign_value in [-1, 1]:
			paths.append({"a":start + cross_dir * half * sign_value, "b":a, "id":"R07"})
			paths.append({"a":end + cross_dir * half * sign_value, "b":b, "id":"R07"})
	var separated: Array = piece.get("separate_roof_groups",[])
	var blockers := faces.filter(func(f): return not f.roof_group in separated)
	for path in paths:
		if path.a.distance_to(path.b) < 0.04:
			continue
		# 跟随已有三段坡面，避免用直斜脊压穿曲屋面。
		for i in 3:
			var p: Vector2 = path.a.lerp(path.b, i / 3.0)
			var q: Vector2 = path.a.lerp(path.b, (i + 1) / 3.0)
			var offset := 0.19 if straw else 0.10
			Shell.exposed_line(out, path.id, Vector3(p.x, _roof_level(faces,owner,p,piece,detail) + offset, p.y),
				Vector3(q.x, _roof_level(faces,owner,q,piece,detail) + offset, q.y), blockers, "ridge",
				{"covering":piece.covering, "breadth":300 if straw else 220, "height":150},
				"M_Thatch" if straw else "M_Default")


static func _roof_faces(piece: Dictionary, owner: int, detail: Dictionary) -> Array:
	var boundary: PackedVector2Array = piece.get("roof_poly",PackedVector2Array())
	if boundary.is_empty():
		var expanded := Geometry2D.offset_polygon(piece.poly, float(detail.eave_depth), Geometry2D.JOIN_MITER)
		if expanded.is_empty():
			return []
		boundary = Plan.clean(expanded[0])
	var u: Vector2 = piece.dir
	var v := Vector2(-u.y, u.x)
	var roof_a: Vector2 = piece.get("roof_a",piece.a)
	var roof_b: Vector2 = piece.get("roof_b",piece.b)
	var center: Vector2 = (roof_a+roof_b)*0.5
	var local := PackedVector2Array()
	for p in boundary:
		local.append(Vector2((p - center).dot(u), (p - center).dot(v)))
	var box := Plan.bounds(local)
	var faces: Array = []
	var nx := 6 if piece.form == "hip" else 1
	# Canonical stations belong to the source segment, never the clipped hub bbox.
	# Fit each source triangle first, then clip its outline without resampling height.
	var half_length: float = roof_a.distance_to(roof_b)*0.5 + float(detail.eave_depth)
	var half_width: float = float(piece.width)*0.5 + float(detail.eave_depth)
	var xs := _roof_stations(half_length,nx,box.position.x,box.end.x)
	var zs := _roof_stations(half_width,6,box.position.y,box.end.y)
	for ix in range(xs.size()-1):
		for iz in range(zs.size()-1):
			var corners := PackedVector2Array([Vector2(xs[ix],zs[iz]),Vector2(xs[ix+1],zs[iz]),
				Vector2(xs[ix+1],zs[iz+1]),Vector2(xs[ix],zs[iz+1])])
			for triangle in [[0,1,2],[0,2,3]]:
				var source := PackedVector2Array()
				var samples := PackedVector3Array()
				for k in triangle:
					var world: Vector2 = center+u*corners[k].x+v*corners[k].y
					source.append(world)
					samples.append(Vector3(world.x,_roof_height(piece,world,detail),world.y))
				var poly := Plan.intersect(source,boundary)
				if poly.is_empty():
					continue
				var tile_direction := -u if u.x < -0.000001 or (absf(u.x)<0.000001 and u.y<0) else u
				var face := Shell.face(poly,Plan.plane(samples[0],samples[1],samples[2]),owner,tile_direction,
					piece.covering,detail.tile_pitch)
				face.roof_group = piece.roof_group
				face.body = piece.poly
				face.wall_top = piece.top
				face.separate_roof_groups = piece.get("separate_roof_groups",[])
				face.roof_joint_groups = piece.get("roof_joint_groups",[])
				faces.append(face)
	return faces


static func _roof_stations(half: float, divisions: int, low: float, high: float) -> Array[float]:
	var values: Array[float] = []
	if low < -half-0.00001:
		values.append(low)
	for i in range(divisions+1):
		values.append(lerpf(-half,half,float(i)/divisions))
	if high > half+0.00001:
		values.append(high)
	return values


static func _roof_level(faces: Array, owner: int, p: Vector2, piece: Dictionary, detail: Dictionary) -> float:
	for face in faces:
		if face.owner == owner and Plan.inside(p,face.poly):
			return Plan.height(face.plane,p)
	return _roof_height(piece,p,detail)


static func _emit_walls(out: Array, pieces: Array, index: int, footprints: Array,
		faces: Array, columns: Dictionary, detail: Dictionary) -> void:
	var piece: Dictionary = pieces[index]
	var poly: PackedVector2Array = piece.get("frame_poly",piece.poly)
	var cuts := footprints.duplicate()
	for face in faces:
		cuts.append(face.poly)
	for edge in poly.size():
		var start := poly[edge]
		var end := poly[(edge + 1) % poly.size()]
		var outward := Vector2((end - start).y, -(end - start).x).normalized()
		var times := Plan.breaks(start, end, cuts)
		var outer_rail := outward*0.01
		var inner_rail := -outward*(float(detail.get("wall_thickness",0.32))+0.01)
		# Shell.wall extrudes the full thickness inward from this boundary.
		# Both rails must share roof-station cuts; a diagonal wall's inner top
		# otherwise crosses a lower slope and protrudes through the tiles.
		# The extra 10 mm includes the planks' maximum 8 mm surface relief.
		times.append_array(Plan.breaks(start+outer_rail,end+outer_rail,cuts))
		times.append_array(Plan.breaks(start+inner_rail,end+inner_rail,cuts))
		times.sort()
		for k in range(times.size() - 1):
			if times[k+1]-times[k]<0.000001:
				continue
			var a := start.lerp(end, times[k])
			var b := start.lerp(end, times[k + 1])
			var middle := (a + b) * 0.5
			var hidden_a := float(detail.base_height)
			var hidden_b := hidden_a
			for j in pieces.size():
				if j != index and not pieces[j].hub and Plan.inside(middle + outward * 0.015, pieces[j].poly):
					hidden_a = maxf(hidden_a, _roof_level(faces,j,a,pieces[j],detail))
					hidden_b = maxf(hidden_b, _roof_level(faces,j,b,pieces[j],detail))
			for floor_index in piece.floors:
				var bottom: float = float(detail.base_height) + floor_index * float(piece.height)
				var top: float = bottom + float(piece.height)
				var top_a := top
				var top_b := top
				if floor_index == piece.floors - 1:
					top_a = minf(_roof_level(faces,index,a+outer_rail,piece,detail),_roof_level(faces,index,a+inner_rail,piece,detail))-0.102
					top_b = minf(_roof_level(faces,index,b+outer_rail,piece,detail),_roof_level(faces,index,b+inner_rail,piece,detail))-0.102
				if hidden_a >= top_a - 0.02 and hidden_b >= top_b - 0.02:
					continue
				var open := "open" if piece.open else ("door" if floor_index == 0 and edge == 0 else "window")
				if hidden_a > bottom + 0.05 or hidden_b > bottom + 0.05:
					open = "solid"
				if Supports.portal_open(piece,a,b,bottom):
					open = "open"
				Shell.wall(out, a, b, minf(top_a, maxf(bottom, hidden_a)), minf(top_b, maxf(bottom, hidden_b)),
					top_a, piece.style, open, detail, top_b)
				Shell.beam(out, a, b, top)
			# Wall removal follows adjacent bodies; flashing follows the actual roof,
			# including an eave that reaches this wall beyond its own body footprint.
			_wall_flashing(out,piece,index,faces,a,b,outward,detail)
		# 柱按开间分布，不跟随屋面裁切的每个细分点重复增加。
		var bays := maxi(1, ceili(start.distance_to(end) / 3.2))
		for bay in bays:
			var point := start.lerp(end, float(bay) / bays)
			for floor_index in piece.floors:
				var bottom: float = float(detail.base_height) + floor_index * float(piece.height)
				var top: float = bottom + float(piece.height)
				var internal := false
				for j in pieces.size():
					if j != index and not pieces[j].hub and pieces[j].top > top and Plan.inside(point + outward * 0.015, pieces[j].poly):
						internal = true
				var key := "%d:%d:%d" % [roundi(point.x * 1000), roundi(point.y * 1000), roundi(bottom * 1000)]
				if not internal and not columns.has(key):
					columns[key] = {"point":point, "bottom":bottom, "top":top, "ground":floor_index == 0}


static func _wall_flashing(out: Array, piece: Dictionary, owner: int, faces: Array,
		a: Vector2, b: Vector2, outward: Vector2, detail: Dictionary) -> void:
	var middle := (a+b)*0.5+outward*0.002
	var wall_top := _roof_level(faces,owner,middle,piece,detail)
	var lower := {}
	var height := float(detail.base_height)+0.2
	for face in faces:
		if face.roof_group == piece.roof_group or not Plan.inside(middle,face.poly):
			continue
		var level := Plan.height(face.plane,middle)
		if level > height and level < wall_top-0.40:
			lower = face
			height = level
	if lower.is_empty():
		return
	var lift := 0.33 if lower.covering == "thatch" else 0.21
	var pa := a+outward*0.008
	var pb := b+outward*0.008
	# A high eave shelters this joint; it must not erase its own flashing.
	var blockers := faces.filter(func(f): return f.roof_group != piece.roof_group)
	Shell.exposed_line(out,"R09",Vector3(pa.x,Plan.height(lower.plane,a)+lift,pa.y),
		Vector3(pb.x,Plan.height(lower.plane,b)+lift,pb.y),blockers,"gutter",
		{"upstand":true,"outward":[roundi(outward.x*10000),roundi(outward.y*10000)]})
