extends RefCounted
## 正多边形、多层木构塔；檐层、层间楼板与收分按实际标高装配。
const Terrace := preload("res://addons/ancient_building/core/terrace_layout.gd")
const Facade := preload("res://addons/ancient_building/core/facade_layout.gd")
const Shell := preload("res://addons/ancient_building/core/building_shell.gd")
const Plan := preload("res://addons/ancient_building/core/plan_geometry.gd")
const Geometry := preload("res://addons/ancient_building/core/roof_geometry.gd")
const Roof := preload("res://addons/ancient_building/core/roof_layout.gd")


static func regular(sides: int, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in sides:
		var angle := TAU * i / sides - PI * 0.5
		result.append(Vector2(cos(angle), sin(angle)) * radius)
	return Plan.clean(result)


static func assemble(spec: Dictionary, detail: Dictionary) -> Dictionary:
	var sides := int(spec.get("sides", 6))
	var floors := int(spec.get("storeys", 4))
	var radius := float(spec.get("radius", 4.5))
	var setback := float(spec.get("setback", 0.3))
	var height := float(detail.floor_height)
	if sides < 4 or sides > 8 or floors < 1 or floors > 8:
		return {"error":"塔需要 4–8 边、1–8 层"}
	if not is_finite(radius) or not is_finite(setback) or radius < 2.0 or radius > 10 or setback < 0 or setback > 0.6:
		return {"error":"塔半径需要 2–10 m，逐层收进需要 0–0.6 m"}
	if radius - setback * (floors - 1) < 1.4:
		return {"error":"塔顶层半径不足 1.4 m；请增大底层半径或减小收进/层数"}
	var construction := String(spec.get("construction", "timber"))
	var covering := String(spec.get("roof_covering", "tile"))
	var out: Array = []
	var level := float(detail.base_height)
	Shell.surface(out, "B01", regular(sides, radius + 0.65), Vector3(0, 0, level), level, "M_Default")
	if int(detail.platform_paving) == 1:
		Terrace.paving(out,regular(sides,radius+0.65),level+0.015,float(detail.paving_size))
	for floor_index in floors:
		var r := radius - floor_index * setback
		var poly := regular(sides, r)
		var column_top := level + height
		var balcony := float(detail.balcony_depth)
		var gallery := regular(sides,r+balcony/cos(PI/sides))
		if floor_index > 0:
			Shell.surface(out, "F13", gallery, Vector3(0, 0, level), 0.22, "M_AgedTimber")
			if balcony > 0.10:
				Terrace.ring(out,gallery,level,detail)
				for edge in sides:
					Shell.beam(out,gallery[edge],gallery[(edge+1)%sides],level-0.12)
					_supports(out,poly[edge],poly[(edge+1)%sides],
						level-0.22-Terrace.bracket_height(),detail,balcony,sides)
		for i in sides:
			var a := poly[i]
			var b := poly[(i + 1) % sides]
			Shell.post(out, a, level, column_top, float(detail.column_radius), floor_index == 0)
			Shell.beam(out, a, b, column_top)
			var bays := maxi(1, ceili(a.distance_to(b) / 3.2))
			for bay in bays:
				var left := a.lerp(b, float(bay) / bays)
				var right := a.lerp(b, float(bay + 1) / bays)
				var opening := "door" if floor_index == 0 and i == 0 and bay == bays / 2 else "window"
				Facade.elevation(out,left,right,level,height-0.12,1,2,construction,detail,opening=="door")
				if bay > 0:
					Shell.post(out, left, level, column_top, float(detail.column_radius) * 0.8, floor_index == 0)
			_supports(out,a,b,column_top+0.02,detail,float(detail.eave_depth),sides)
		var eave_radius := r + maxf(float(detail.eave_depth),balcony+0.30) / cos(PI / sides)
		var roof_y := column_top+0.02+Terrace.bracket_height()+0.18
		var top_layer := floor_index == floors - 1
		var inner_radius := 0.0 if top_layer else r - setback - 0.12
		var rise := r * float(detail.roof_rise_ratio) * 2.2 if top_layer else 0.55
		var faces: Array = []
		for ring in 6:
			var t0 := ring / 6.0
			var t1 := (ring + 1) / 6.0
			var outer := regular(sides, lerpf(eave_radius, inner_radius, t0))
			var inner := regular(sides, lerpf(eave_radius, inner_radius, t1)) if t1 < 1 or not top_layer else PackedVector2Array()
			var y0 := roof_y + _roof_height(t0,rise,detail)
			var y1 := roof_y + _roof_height(t1,rise,detail)
			for i in sides:
				var j := (i + 1) % sides
				var c := inner[j] if not inner.is_empty() else Vector2.ZERO
				var d := inner[i] if not inner.is_empty() else Vector2.ZERO
				var patch := Plan.clean(PackedVector2Array([outer[i], outer[j], c, d]))
				var plane := Plan.plane(Vector3(outer[i].x, y0, outer[i].y),
					Vector3(outer[j].x, y0, outer[j].y), Vector3(c.x, y1, c.y))
				faces.append(Shell.face(patch, plane, i, (outer[j] - outer[i]).normalized(), covering, detail.tile_pitch))
		Shell.emit_roofs(out, faces)
		var edge_poly := regular(sides, eave_radius)
		var inner_poly := regular(sides, inner_radius) if inner_radius > 0 else PackedVector2Array()
		for i in sides:
			_eave(out,edge_poly[i],edge_poly[(i+1)%sides],inner_radius/eave_radius,roof_y,rise,detail,covering)
			var point := inner_poly[i] if not inner_poly.is_empty() else Vector2.ZERO
			for ring in 6:
				var t0 := ring / 6.0
				var t1 := (ring + 1) / 6.0
				var a := edge_poly[i].lerp(point, t0)
				var b := edge_poly[i].lerp(point, t1)
				var offset := 0.19 if covering == "thatch" else 0.10
				Shell.line(out, "R07", Vector3(a.x, roof_y + _roof_height(t0,rise,detail) + offset, a.y),
					Vector3(b.x, roof_y + _roof_height(t1,rise,detail) + offset, b.y), "ridge",
					{"covering":covering}, "M_Thatch" if covering == "thatch" else "M_Default")
		if top_layer:
			Roof.part(out, "R14", Vector3(0, roof_y + rise + 0.12, 0), {"height":detail.finial_height,"radius":0.32,"style":1})
			out.back().material_set = "M_Bronze" # independent crown finish
		level = roof_y + rise + 0.12
	return {"placements":out}


static func _roof_height(t: float, rise: float, detail: Dictionary) -> float:
	var curve := float(detail.roof_curve)
	return rise*t*(1.0-curve+curve*t)+float(detail.corner_lift)*pow(1.0-t,3)*0.45


static func _supports(out: Array,a: Vector2,b: Vector2,y: float,detail: Dictionary,reach: float,sides: int) -> void:
	var delta := b-a
	var outward := Vector2(delta.y,-delta.x).normalized()
	var yaw := rad_to_deg(atan2(outward.x,outward.y))
	var count := maxi(1,ceili(delta.length()/float(detail.bracket_spacing)))
	var projection := minf(reach,float(detail.bracket_projection))
	Terrace.bracket(out,Vector3(a.x,y,a.y),yaw,projection,2,true,1.0,roundi(360.0/sides))
	for j in count:
		var point := a.lerp(b,(j+0.5)/count)
		Terrace.bracket(out,Vector3(point.x,y,point.y),yaw,projection,1)


static func _eave(out: Array,a: Vector2,b: Vector2,inner_scale: float,y: float,rise: float,detail: Dictionary,covering: String) -> void:
	var direction := (b-a).normalized()
	var outward := Vector2(direction.y,-direction.x)
	var yaw := rad_to_deg(atan2(outward.x,outward.y))
	var edge_y := y+_roof_height(0,rise,detail)
	Shell.beam(out,a,b,edge_y-0.11)
	var count := maxi(2,ceili(a.distance_to(b)/float(detail.rafter_spacing)))
	for i in count:
		var toe := a.lerp(b,(i+0.5)/count)
		var inner := toe*inner_scale
		var t := minf(1.0,1.3/toe.distance_to(inner))
		var head := toe.lerp(inner,t)
		var start := Vector3(toe.x,edge_y-0.20,toe.y)
		var end := Vector3(head.x,y+_roof_height(t,rise,detail)-0.20,head.y)
		var delta := end-start
		var horizontal := Vector2(delta.x,delta.z).length()
		Roof.part(out,"F11",(start+end)*0.5,{"radius":detail.rafter_radius,"length":delta.length(),"sides":12},
			-1,rad_to_deg(atan2(-delta.x,-delta.z)),rad_to_deg(atan2(delta.y,horizontal)))
	if covering != "tile":
		return
	var pitch := float(detail.tile_pitch)
	var low := a.dot(direction)
	var high := b.dot(direction)
	for i in range(ceili((low+pitch*0.265+Geometry.CORNER_CLEARANCE)/pitch-0.5),floori((high-pitch*0.265-Geometry.CORNER_CLEARANCE)/pitch-0.5)+1):
		var point := a+direction*((i+0.5)*pitch-low)
		var station := -outward.dot(a)
		var lap := (1.0-clampf((fposmod(station,0.32)+0.018)/0.32,0,1))*0.022
		Roof.cap(out,Vector3(point.x,edge_y+0.035+Geometry.CAP_BASE+lap,point.y),pitch,int(detail.cap_pattern),yaw)
