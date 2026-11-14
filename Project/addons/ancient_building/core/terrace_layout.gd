extends RefCounted
## 栏杆按完整边划分，端柱共享；入口以两个独立区间留空。
const Roof := preload("res://addons/ancient_building/core/roof_layout.gd")
const Plan := preload("res://addons/ancient_building/core/plan_geometry.gd")


static func rail(out: Array, a: Vector2, b: Vector2, y: float, detail: Dictionary, end_post := true) -> void:
	var style := int(detail.railing_style)
	if style == 0 or a.distance_to(b) < 0.25:
		return
	var delta := b - a
	var count := maxi(1, ceili(delta.length() / 1.15))
	var yaw := rad_to_deg(-atan2(delta.y, delta.x))
	var finish := "M_Stone" if style == 2 else "M_AgedTimber"
	for i in count + int(end_post):
		var p := a.lerp(b, float(i) / count)
		Roof.part(out, "B09", Vector3(p.x, y, p.y), {"height":detail.railing_height + 0.12, "style":int(style == 2)})
		out.back().material_set = finish
	for i in count:
		var p := a.lerp(b, (i + 0.5) / count)
		Roof.part(out, "B10", Vector3(p.x, y, p.y), {"width":maxf(0.28, delta.length() / count - 0.14),
			"height":detail.railing_height, "style":int(style == 2)}, -1, yaw)
		out.back().material_set = finish


static func ring(out: Array, poly: PackedVector2Array, y: float, detail: Dictionary) -> void:
	for i in poly.size():
		rail(out, poly[i], poly[(i + 1) % poly.size()], y, detail, false)


static func paving(out: Array, poly: PackedVector2Array, y: float, size: float) -> void:
	var points := PackedVector3Array()
	for p in poly:
		points.append(Vector3(p.x, 0, p.y))
	out.append({"id":"B01", "position":Vector3.UP * y, "material_set":"M_Stone",
		"geometry":{"kind":"paving", "points":Plan.encode(points), "pitch":roundi(size * 1000)}})


static func bracket_height() -> float:
	# 坐斗槽底 + 首栱 + 出跳栱 + 顶栱；所有角色共用承托标高。
	return 0.31*0.62*0.72 + 0.16 + 0.14 + 0.13


static func bracket(out: Array, position: Vector3, yaw: float, reach := 0.36,
		role := 0, ornate := false, corner_hand := 1.0, corner_angle := 90) -> void:
	var b := Basis(Vector3.UP, deg_to_rad(yaw))
	var first_y := 0.31*0.62*0.72
	var second_y := first_y+0.16
	var top_y := second_y+0.14
	var width := 0.82 if role==1 else 0.96
	var projection := clampf(reach,0.24,0.60)
	Roof.part(out,"F08",position,{"width":0.31,"slot":0.16},-1,yaw)
	Roof.part(out,"F09",position+Vector3.UP*first_y,
		{"width":width,"height":0.16,"depth":0.16},-1,yaw)
	Roof.part(out,"F09",position+b*Vector3(0,second_y,projection*0.30),
		{"width":0.60+projection,"height":0.14,"depth":0.14},-1,yaw+90)
	# 小斗坐在首栱两端；其槽底恰好等于顶栱底，不靠悬空叠盒。
	var upper_block := 0.14/(0.62*0.72)
	for side in [-1.0,1.0]:
		Roof.part(out,"F08",position+b*Vector3(side*width*0.32,second_y,0),
			{"width":upper_block,"slot":0.18},-1,yaw)
	Roof.part(out,"F09",position+Vector3.UP*top_y,
		{"width":width+0.18,"height":0.13,"depth":0.18,"fork":int(role==2),
		"fork_angle":corner_angle},-1,yaw)
	if ornate or role==2:
		var ang_yaw := yaw+corner_hand*corner_angle*0.5 if role==2 else yaw
		var direction := Basis(Vector3.UP,deg_to_rad(ang_yaw))
		Roof.part(out,"F10",position+direction*Vector3(0,second_y-0.025,projection*0.34),
			{"length":0.55+projection*0.65},-1,ang_yaw,-12)
