extends RefCounted
## 同高连体先定正脊节点、扇区归属和檐口，再生成屋面及瓦网。
## 每条缝是节点到檐口的建筑边界；不从两张已相交的屋面猜测交线。
const Plan := preload("res://addons/ancient_building/core/plan_geometry.gd")
const EPS := 0.00001


static func prepare(pieces: Array, connections: Dictionary, nodes: Dictionary, detail: Dictionary) -> Dictionary:
	var result := {"error":"", "junctions":[], "seams":[]}
	var tolerance := float(detail.get("junction_height_tolerance",0.03))
	var eave := float(detail.eave_depth)
	var pitch := float(detail.tile_pitch)
	var requested_width := float(detail.get("junction_gutter_width",0.0))
	var gutter_width := clampf(pitch*1.15,0.20,0.42) if requested_width<=0 else requested_width
	if gutter_width<maxf(0.12,pitch*0.55):
		return {"error":"连接谷沟宽度小于瓦作模数；请将谷沟宽度设为 0（自动），或增大 junction_gutter_width"}
	var parents: Array[int] = []
	for i in pieces.size():
		parents.append(i)
	var groups_at_nodes := {}
	# Establish compatible components first. An ID or input order must never choose
	# which of two roofs survives, nor which tiny height discrepancy becomes a step.
	for node_id in connections:
		var incident: Array = connections[node_id]
		var node_groups: Array = []
		for index in incident:
			var found := false
			for group in node_groups:
				if _compatible(pieces[index],pieces[group[0]],detail,tolerance):
					group.append(index)
					found = true
					break
			if not found:
				node_groups.append([index])
		groups_at_nodes[node_id] = node_groups
		for group in node_groups:
			if group.size()<2:
				continue
			for index in group:
				if pieces[index].form!="overhang":
					return {"error":"同高节点 %s 当前要求悬山支段；庑殿端坡不能直接接到正脊交点，请调整该节点的屋顶形制" % node_id}
				if pieces[index].covering!=pieces[group[0]].covering:
					return {"error":"同高节点 %s 混用了瓦顶与茅草顶；共享排水节点请使用相同的屋面覆盖类型" % node_id}
				parents[_root(parents,index)] = _root(parents,group[0])
	var components := {}
	for i in pieces.size():
		var root := _root(parents,i)
		if not components.has(root):
			components[root] = []
		components[root].append(i)
	for group in components.values():
		if group.size()<2:
			continue
		var eave_sum := 0.0
		var ridge_sum := 0.0
		var low := Vector2(INF,INF)
		var high := Vector2(-INF,-INF)
		for index in group:
			var levels := _levels(pieces[index],detail)
			eave_sum += levels.x
			ridge_sum += levels.y
			low = low.min(levels)
			high = high.max(levels)
		if high.x-low.x>tolerance+EPS or high.y-low.y>tolerance+EPS:
			return {"error":"同高连接组的累计高度差超过 junction_height_tolerance；请统一相连支段的檐高和脊高"}
		for index in group:
			pieces[index].roof_eave_level = eave_sum/group.size()
			pieces[index].roof_ridge_level = ridge_sum/group.size()
			pieces[index].roof_joint_groups = []
			for peer in group:
				if peer!=index:
					pieces[index].roof_joint_groups.append(String(pieces[peer].roof_group))
	var ends := {}
	for node_id in groups_at_nodes:
		for group in groups_at_nodes[node_id]:
			if group.size()<2:
				continue
			var point: Vector2 = nodes[node_id]
			var rays: Array = []
			var ids: Array = []
			for index in group:
				var piece: Dictionary = pieces[index]
				var at_start: bool = piece.a.distance_to(point)<0.001
				var direction: Vector2 = piece.dir if at_start else -piece.dir
				rays.append({"index":index,"direction":direction,"angle":fposmod(direction.angle(),TAU),
					"half":float(piece.width)*0.5+eave,"start":at_start})
				ids.append(String(piece.roof_group))
			rays.sort_custom(func(a,b): return a.angle<b.angle)
			var level := float(pieces[group[0]].roof_ridge_level)
			var junction := {"node":String(node_id),"point":Vector3(point.x,level,point.y),"ids":ids,"arms":[]}
			for ray in rays:
				junction.arms.append(ray.direction)
			for i in rays.size():
				var a: Dictionary = rays[i]
				var b: Dictionary = rays[(i+1)%rays.size()]
				var angle: float = fposmod(float(b.angle)-float(a.angle),TAU)
				if angle<deg_to_rad(12.0):
					return {"error":"节点 %s 的出射支段重合或夹角小于 12°；请增大夹角或拆分正脊节点" % node_id}
				var offset := Vector2.ZERO
				var left := Vector2(-a.direction.y,a.direction.x)
				var right := Vector2(-b.direction.y,b.direction.x)
				if absf(angle-PI)<0.0001:
					if absf(float(a.half)-float(b.half))>0.001:
						return {"error":"同高直线节点 %s 的檐宽不同；请统一支段宽度，或调整为独立高低屋顶" % node_id}
					offset = left*float(a.half)
				else:
					var determinant := left.cross(right)
					offset = Vector2(float(a.half)*right.y+float(b.half)*left.y,
						-float(b.half)*left.x-float(a.half)*right.x)/determinant
				var outlet := point+offset
				for ray in [a,b]:
					var key := "%d:%d" % [int(ray.index),int(ray.start)]
					if not ends.has(key):
						ends[key] = {"node":point,"left":Vector2.ZERO,"right":Vector2.ZERO}
				ends["%d:%d" % [int(a.index),int(a.start)]].left = outlet
				ends["%d:%d" % [int(b.index),int(b.start)]].right = outlet
				if absf(angle-PI)<0.0001:
					continue
				var seam_points := PackedVector3Array()
				# The same three cross-slope intervals are used by compound roof faces.
				for station in range(4):
					var t := station/3.0
					var p := point.lerp(outlet,t)
					var roof_t := 1.0-t
					var base := float(pieces[group[0]].roof_eave_level)
					var y := base+(level-base)*roof_t*(0.55+0.45*roof_t)
					seam_points.append(Vector3(p.x,y,p.y))
				result.seams.append({"kind":"valley" if angle<PI else "hip","points":seam_points,
					"groups":[String(pieces[a.index].roof_group),String(pieces[b.index].roof_group)],
					"width":gutter_width,"node":String(node_id)})
			result.junctions.append(junction)
	for i in pieces.size():
		var piece: Dictionary = pieces[i]
		if not piece.has("roof_joint_groups"):
			continue
		var direction: Vector2 = piece.dir
		var normal := Vector2(-direction.y,direction.x)
		var half := float(piece.width)*0.5+eave
		var a: Vector2 = piece.get("roof_a",piece.a)-direction*eave
		var b: Vector2 = piece.get("roof_b",piece.b)+direction*eave
		var start: Dictionary = ends.get("%d:1" % i,{})
		var end: Dictionary = ends.get("%d:0" % i,{})
		var outline := PackedVector2Array()
		if start.is_empty():
			outline.append_array(PackedVector2Array([a-normal*half,a+normal*half]))
		else:
			a = start.node
			outline.append_array(PackedVector2Array([start.right,a,start.left]))
		if end.is_empty():
			outline.append_array(PackedVector2Array([b+normal*half,b-normal*half]))
		else:
			b = end.node
			outline.append_array(PackedVector2Array([end.right,b,end.left]))
		outline = Plan.clean(outline)
		# Miter lengths are geometric constraints, not an invitation to silently
		# fold a short segment or cut its entire roof away.
		var edge_min := float(detail.get("junction_clearance",0.08))*2.0
		var start_left: Vector2 = start.get("left",a+normal*half)
		var start_right: Vector2 = start.get("right",a-normal*half)
		var end_left: Vector2 = end.get("right",b+normal*half)
		var end_right: Vector2 = end.get("left",b-normal*half)
		if (end_left-start_left).dot(direction)<edge_min or (end_right-start_right).dot(direction)<edge_min or not _convex(outline):
			return {"error":"支段 %s 无法容纳同高转角屋面；请加长支段、缩小宽度/出檐，或增大连接夹角" % piece.id}
		piece.roof_poly = outline
		piece.ridge_start = a
		piece.ridge_end = b
		piece.roof_joint_start = not start.is_empty()
		piece.roof_joint_end = not end.is_empty()
	return result


static func _root(parents: Array[int], index: int) -> int:
	while parents[index]!=index:
		index = parents[index]
	return index


static func _levels(piece: Dictionary, detail: Dictionary) -> Vector2:
	var eave := float(piece.top)
	var half := float(piece.width)*0.5+float(detail.eave_depth)
	var t := minf(1.0,(piece.a.distance_to(piece.b)+float(detail.eave_depth)*2)/(half*2)) if piece.form=="hip" else 1.0
	return Vector2(eave,eave+half*float(detail.roof_rise_ratio)*2.0*t*(0.55+0.45*t))


static func _compatible(a: Dictionary, b: Dictionary, detail: Dictionary, tolerance: float) -> bool:
	var difference := (_levels(a,detail)-_levels(b,detail)).abs()
	return difference.x<=tolerance and difference.y<=tolerance


static func _convex(poly: PackedVector2Array) -> bool:
	if poly.size()<3:
		return false
	for i in poly.size():
		if (poly[(i+1)%poly.size()]-poly[i]).cross(poly[(i+2)%poly.size()]-poly[(i+1)%poly.size()]) < -EPS:
			return false
	return true
