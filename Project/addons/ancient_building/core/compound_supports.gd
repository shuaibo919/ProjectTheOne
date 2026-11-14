extends RefCounted
## 高低接榀：完整低端檐嵌入高檐下，高侧斜接柱榀向内退让。
const Plan := preload("res://addons/ancient_building/core/plan_geometry.gd")


static func rectangle(a: Vector2, b: Vector2, half_width: float, end_eave := 0.0) -> PackedVector2Array:
	var u := (b-a).normalized()
	var v := Vector2(-u.y,u.x)*half_width
	return Plan.clean(PackedVector2Array([a-u*end_eave-v,b+u*end_eave-v,b+u*end_eave+v,a-u*end_eave+v]))


static func prepare(pieces: Array, connections: Dictionary, nodes: Dictionary, detail: Dictionary) -> Dictionary:
	var tolerance := float(detail.get("junction_height_tolerance",0.03))
	var clearance := float(detail.get("junction_clearance",0.08))
	var eave := float(detail.eave_depth)
	# F04 is 220 mm wide; the F08 cap is narrower than the column diameter.
	var envelope := maxf(float(detail.column_radius),0.11)+clearance+0.004
	var junctions: Array = []
	var entries := {}
	for piece in pieces:
		piece.source_a = piece.a
		piece.source_b = piece.b
		piece.roof_a = piece.a
		piece.roof_b = piece.b
		piece.frame_a = piece.a
		piece.frame_b = piece.b
		piece.separate_roof_groups = []
		piece.portals = []
		piece.frame_constraints = []
	for node_id in connections:
		var incident: Array = connections[node_id]
		for ia in incident.size():
			for ib in range(ia+1,incident.size()):
				var first: Dictionary = pieces[incident[ia]]
				var second: Dictionary = pieces[incident[ib]]
				var ridge_a := _ridge_height(first,detail)
				var ridge_b := _ridge_height(second,detail)
				if absf(float(first.top)-float(second.top))<=tolerance and absf(ridge_a-ridge_b)<=tolerance:
					continue
				if absf(float(first.top)-float(second.top))<=tolerance:
					return {"error":"节点 %s：檐高相同但脊高不匹配；请统一支段宽度，或为高低接榀增加层高差" % node_id}
				var low: Dictionary = first if first.top < second.top else second
				var high: Dictionary = second if first.top < second.top else first
				var point: Vector2 = nodes[node_id]
				var low_start := point.distance_squared_to(low.a)<0.000001
				var high_start := point.distance_squared_to(high.a)<0.000001
				var away: Vector2 = low.dir if low_start else -low.dir
				var high_roof := rectangle(high.a,high.b,float(high.width)*0.5+eave,eave)
				# Solve for the WHOLE low terminal eave, not a nonempty roof corner
				# intersection. The latter leaves an exposed wedge at oblique entries.
				var interval := _axis_interval(high_roof,point,away,float(low.width)*0.5+eave)
				if interval.x>interval.y:
					return {"error":"节点 %s：高檐无法容纳完整低端檐，请调整宽度/方向或分开交接节点" % node_id}
				var entry_key := String(low.id)+":"+String(node_id)
				if not entries.has(entry_key):
					entries[entry_key] = {"low":low,"point":point,"away":away,"start":low_start,"bounds":interval}
				else:
					entries[entry_key].bounds = Vector2(maxf(entries[entry_key].bounds.x,interval.x),minf(entries[entry_key].bounds.y,interval.y))
				if not high.roof_group in low.separate_roof_groups:
					low.separate_roof_groups.append(high.roof_group)
				if not low.roof_group in high.separate_roof_groups:
					high.separate_roof_groups.append(low.roof_group)
				junctions.append({"kind":"high_low","node":node_id,"low":low.id,"high":high.id,
					"low_owner":incident[ia] if low==first else incident[ib],
					"high_owner":incident[ib] if low==first else incident[ia],
					"lower_original":point,"entry_key":entry_key,"high_start":high_start,
					"support_envelope":envelope,
					"clearance":clearance,"low_ridge":_ridge_height(low,detail)})
	for entry in entries.values():
		var landing := maxf(0.08,clearance)
		if entry.bounds.y-entry.bounds.x<landing*2.0:
			return {"error":"低段 %s：完整端檐没有足够搭接带，请增大檐口挑出或调整方向" % entry.low.id}
		# Prefer the original node plane; move deeper only where the oblique
		# terminal line needs it. This may extend a low source by a few cm.
		entry.front = clampf(0.0,float(entry.bounds.x)+landing,float(entry.bounds.y)-landing)
		var retreat: float = entry.front+eave
		entry.low["roof_a" if entry.start else "roof_b"] = entry.point+entry.away*retreat
		_set_end(entry.low,"frame",entry.start,entry.point+entry.away*maxf(retreat,envelope))
	for joint in junctions:
		var entry: Dictionary = entries[joint.entry_key]
		var low: Dictionary = pieces[joint.low_owner]
		var high: Dictionary = pieces[joint.high_owner]
		var normal: Vector2 = entry.away
		var offset: float = normal.dot(entry.point)+entry.front-envelope
		high.frame_constraints.append({"normal":normal,"offset":offset})
		high.portals.append({"normal":normal,"offset":offset,"top":low.top})
		low.portals.append({"start":entry.start,"top":high.top})
		joint.lower_roof_endpoint = entry.point+normal*entry.front
		joint.roof_retreat = entry.front+eave
		joint.entry_normal = normal
		joint.frame_cut_offset = offset
		joint.entry_landing = maxf(0.08,clearance)
	# A lower pair cannot both retain a shared ridge node after that very node
	# was moved away from an upper wing. Require separate nodes rather than
	# allowing the subsequent same-height planner to undo their safe setback.
	for node_id in connections:
		var incident: Array = connections[node_id]
		if incident.size()<3:
			continue
		for ia in incident.size():
			for ib in range(ia+1,incident.size()):
				var a: Dictionary = pieces[incident[ia]]
				var b: Dictionary = pieces[incident[ib]]
				if absf(float(a.top)-float(b.top))>tolerance or absf(_ridge_height(a,detail)-_ridge_height(b,detail))>tolerance:
					continue
				for piece in [a,b]:
					var at_start: bool = piece.a.distance_squared_to(nodes[node_id])<0.000001
					var roof_end: Vector2 = piece.roof_a if at_start else piece.roof_b
					if roof_end.distance_squared_to(nodes[node_id])>0.000001:
						return {"error":"节点 %s：低翼退让与同高合脊冲突；请把低翼合脊节点与高低交接节点分开" % node_id}
	for piece in pieces:
		var roof_run: float = (piece.roof_b-piece.roof_a).dot(piece.dir)
		piece.frame_poly = rectangle(piece.frame_a,piece.frame_b,float(piece.width)*0.5)
		for constraint in piece.frame_constraints:
			piece.frame_poly = Plan.clip(piece.frame_poly,constraint.normal,constraint.offset)
		if piece.frame_poly.is_empty():
			return {"error":"线段 %s：斜接柱榀退让后无有效体量，请延长高段或减小低段宽度" % piece.id}
		var axis := _axis_interval(piece.frame_poly,piece.a,piece.dir,0.0)
		var frame_run: float = axis.y-axis.x
		if roof_run < 1.0 or frame_run < 1.0:
			return {"error":"线段 %s：高低接榀退让后仅剩 %.2f m，需延长线段或减小宽度/出檐" % [piece.id,minf(roof_run,frame_run)]}
		piece.frame_a = piece.a+piece.dir*axis.x
		piece.frame_b = piece.a+piece.dir*axis.y
		piece.roof_poly = rectangle(piece.roof_a,piece.roof_b,float(piece.width)*0.5+eave,eave)
	return {"junctions":junctions,"pieces":pieces,"clearance":clearance,"support_envelope":envelope}


static func _axis_interval(poly: PackedVector2Array, origin: Vector2, direction: Vector2, half_width: float) -> Vector2:
	var interval := Vector2(-INF,INF)
	var side := Vector2(-direction.y,direction.x)
	for i in poly.size():
		var edge := poly[(i+1)%poly.size()]-poly[i]
		var normal := Vector2(edge.y,-edge.x).normalized()
		var numerator := normal.dot(poly[i]-origin)-absf(normal.dot(side))*half_width
		var denominator := normal.dot(direction)
		if absf(denominator)<0.000001:
			if numerator < -0.00001:
				return Vector2(INF,-INF)
		elif denominator>0:
			interval.y = minf(interval.y,numerator/denominator)
		else:
			interval.x = maxf(interval.x,numerator/denominator)
	return interval


static func _set_end(piece: Dictionary, kind: String, start: bool, value: Vector2) -> void:
	var key := kind+("_a" if start else "_b")
	var original: Vector2 = piece.a if start else piece.b
	var away: Vector2 = piece.dir if start else -piece.dir
	# Multiple neighbors can demand different setbacks at one node. Keep the
	# strongest requirement and never undo the setback from an earlier pair.
	if (value-original).dot(away) > (piece[key]-original).dot(away):
		piece[key] = value


static func _ridge_height(piece: Dictionary, detail: Dictionary) -> float:
	var half := float(piece.width)*0.5+float(detail.eave_depth)
	var t := 1.0
	if piece.form=="hip":
		var a: Vector2 = piece.get("roof_a",piece.a)
		var b: Vector2 = piece.get("roof_b",piece.b)
		t = minf(1.0,(a.distance_to(b)+2.0*float(detail.eave_depth))/(2.0*half))
	return float(piece.top)+half*float(detail.roof_rise_ratio)*2.0*t*(0.55+0.45*t)


static func validate_roofs(plan: Dictionary, pieces: Array, faces: Array, detail: Dictionary) -> String:
	# Test the actual overlapping polygon vertices of the final affine patches.
	# A whole-roof high-ridge/low-eave comparison would reject valid hip entries.
	for joint in plan.junctions:
		var low: Dictionary = pieces[joint.low_owner]
		var high: Dictionary = pieces[joint.high_owner]
		var side := Vector2(-joint.entry_normal.y,joint.entry_normal.x)*(float(low.width)*0.5+float(detail.eave_depth))
		var entry_line := PackedVector2Array([joint.lower_roof_endpoint-side,joint.lower_roof_endpoint+side])
		for point in entry_line:
			if not Plan.inside(point,high.roof_poly):
				return "节点 %s：最终高屋面无法连续覆盖低端檐，请分开高低与同高交接节点" % joint.node
		var overlap := Plan.intersect(low.roof_poly,high.roof_poly)
		if overlap.is_empty():
			return "节点 %s：高低接榀没有檐口搭接；请增大出檐或减小柱径/转角" % joint.node
		var structural_envelopes := Geometry2D.offset_polygon(high.frame_poly,float(plan.support_envelope),Geometry2D.JOIN_MITER)
		if not structural_envelopes.is_empty():
			var collision := Plan.intersect(low.roof_poly,structural_envelopes[0])
			if not collision.is_empty() and absf(Plan.area(collision))>0.00001:
				return "节点 %s：低屋面进入高侧柱梁净距包络；请减小转角或延长低段" % joint.node
		var gap := INF
		for low_face in faces:
			if low_face.owner!=joint.low_owner:
				continue
			for high_face in faces:
				if high_face.owner!=joint.high_owner or not low_face.bounds.intersects(high_face.bounds,true):
					continue
				var shared := Plan.intersect(low_face.poly,high_face.poly)
				for p in shared:
					gap = minf(gap,Plan.height(high_face.plane,p)-Plan.height(low_face.plane,p))
		# Include boards below the upper roof and ridge/thatch relief above the
		# lower surface; eave heights alone cannot establish geometric clearance.
		var covering := 0.40 if low.covering=="thatch" else 0.27
		var required := 0.10+covering+float(detail.get("junction_clearance",0.08))
		if not is_finite(gap) or gap < required:
			return "节点 %s：高低屋面搭接净高 %.2f m 不足 %.2f m；请提高高段层高或降低低段层高" % [joint.node,gap,required]
		joint.height_gap = gap
		joint.required_height_gap = required
		joint.lower_roof_polygon = low.roof_poly
		joint.lower_frame_polygon = low.frame_poly
		joint.high_frame_polygon = high.frame_poly
		joint.lower_roof_a = low.roof_a
		joint.lower_roof_b = low.roof_b
		joint.low_ridge = _ridge_height(low,detail)
		joint.high_frame_retreat = high.frame_a.distance_to(high.source_a) if joint.high_start else high.frame_b.distance_to(high.source_b)
		joint.entry_line = entry_line
	return ""


static func portal_open(piece: Dictionary, a: Vector2, b: Vector2, bottom: float) -> bool:
	for portal in piece.get("portals",[]):
		var normal: Vector2 = portal.get("normal",piece.dir)
		var offset := float(portal.get("offset",0.0))
		if not portal.has("normal"):
			var end: Vector2 = piece.frame_a if portal.start else piece.frame_b
			offset = normal.dot(end)
		if absf(a.dot(normal)-offset)<0.001 and absf(b.dot(normal)-offset)<0.001 and bottom<float(portal.top)-0.25:
			return true
	return false
