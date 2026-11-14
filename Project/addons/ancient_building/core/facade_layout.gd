extends RefCounted
## a→b 的右侧是立面外侧。墙分块留洞，格窗与落地格扇不共用裙板比例。
const Roof := preload("res://addons/ancient_building/core/roof_layout.gd")
const Shell := preload("res://addons/ancient_building/core/building_shell.gd")


static func elevation(out: Array, a: Vector2, b: Vector2, base: float, height: float,
		bays: int, style: int, construction: String, detail: Dictionary, central_door := false) -> void:
	if style == 3:
		_shopfront(out,a,b,base,height,bays,detail)
		return
	var along := (b - a).normalized()
	var inward := Vector2(-along.y, along.x)
	var yaw := rad_to_deg(-atan2(along.y, along.x))
	for i in bays:
		var left := a.lerp(b, float(i) / bays)
		var right := a.lerp(b, float(i + 1) / bays)
		var width := left.distance_to(right)
		var door := central_door and i == bays / 2
		if style == 0 and not door:
			Shell.wall(out, left, right, base, base, base + height, construction, "", detail)
		else:
			var sill := 0.08 if door or style == 2 else height * 0.32
			var head := height * 0.89
			var margin := 0.13 if door or style == 2 else minf(0.38, width * 0.16)
			var p := left + along * margin
			var q := right - along * margin
			Shell.wall(out, left, p, base, base, base + height, construction, "", detail)
			Shell.wall(out, q, right, base, base, base + height, construction, "", detail)
			if sill > 0.10:
				Shell.wall(out, p, q, base, base, base + sill, construction, "", detail)
			Shell.wall(out, p, q, base + head, base + head, base + height, construction, "", detail)
			var center := (p + q) * 0.5 + inward * 0.025
			var pos := Vector3(center.x, base + (sill + head) * 0.5, center.y)
			var opening_width := p.distance_to(q)
			Roof.part(out, "O06", pos, {"width":opening_width, "height":head - sill,
				"depth":0.16, "frame":0.07}, -1, yaw)
			var leaves := maxi(2, ceili((opening_width - 0.12) / 0.72))
			var leaf_w := (opening_width - 0.12) / leaves
			for j in leaves:
				var leaf_pos := pos + Vector3(along.x, 0, along.y) * ((j + 0.5) * leaf_w - (opening_width - 0.12) * 0.5)
				Roof.part(out, "O02", leaf_pos, {"width":leaf_w - 0.006, "height":head - sill - 0.12,
					"thickness":0.065, "window":int(not door and style != 2), "pattern":detail.lattice_style,
					"bars":detail.lattice_bars, "bar":detail.lattice_bar}, -1, yaw)
			if int(detail.window_backing) == 1:
				var backing_h := (head - sill) * (0.48 if door or style == 2 else 0.91)
				var backing := pos + Vector3(inward.x, 0, inward.y) * 0.065
				if door or style == 2:
					backing.y += (head - sill) * 0.23
				Roof.part(out, "O08", backing, {"height":backing_h}, opening_width - 0.13, yaw)
				out.back().material_set = "M_Paper"
			if door:
				for sign_value in [-1, 1]:
					var handle: Vector3 = pos + Vector3(along.x,0,along.y) * sign_value * 0.11 - Vector3(inward.x,0,inward.y) * 0.055
					handle.y = base + height * 0.36
					Roof.part(out, "O04", handle, {"radius":0.055}, -1, yaw)
		# 墙面分格落在外皮上；侧/背面也显露柱、地栿与中槛。
		Shell.beam(out, left, right, base + 0.13)
		Shell.beam(out, left, right, base + height - 0.11)
		if style == 1 and not door:
			Shell.beam(out, left, right, base + height * 0.32)
		if i > 0:
			Roof.part(out, "F01", Vector3(left.x,base+height*0.5,left.y),
				{"height":height, "radius":float(detail.column_radius)*0.72, "sides":24})


## Counter windows flank a walk-through entrance. Folding boards rotate about
## their hinges; opening a shop never scales a wall away or seals the doorway.
static func _shopfront(out: Array, a: Vector2, b: Vector2, base: float, height: float,
		bays: int, detail: Dictionary) -> void:
	var along := (b-a).normalized()
	var inward := Vector2(-along.y,along.x)
	var yaw := rad_to_deg(-atan2(along.y,along.x))
	var head := height*0.84
	var sill := float(detail.counter_height)
	var timber := detail.duplicate()
	timber.wall_thickness = 0.08
	timber.board_width = 0.14
	for i in bays:
		var left := a.lerp(b,float(i)/bays)
		var right := a.lerp(b,float(i+1)/bays)
		var margin := float(detail.column_radius)+0.035
		var p := left+along*margin
		var q := right-along*margin
		var width := p.distance_to(q)
		var central := i == floori(bays*0.5)
		var bottom := 0.04 if central else sill+0.055
		# A narrow boarded transom carries the head frame; no dense lattice wall.
		Shell.wall(out,left,right,base+head+0.09,base+head+0.09,base+height,"timber","",timber)
		var center := (p+q)*0.5
		Roof.part(out,"F02",Vector3(center.x,base+head+0.045,center.y),{"height":0.09,"depth":0.12},width,yaw)
		for jamb in [p,q]:
			Roof.part(out,"F01",Vector3(jamb.x,base+(bottom+head)*0.5,jamb.y),
				{"height":head-bottom,"radius":0.037,"sides":12})
		if not central:
			Shell.wall(out,p,q,base,base,base+sill,"timber","",timber)
			var counter := center-inward*0.10
			Roof.part(out,"F13",Vector3(counter.x,base+sill+0.025,counter.y),
				{"thickness":0.05,"length":0.43},width+0.06,yaw)
		var leaf_detail := timber.duplicate()
		leaf_detail.wall_thickness = 0.05
		var angle := deg_to_rad(float(detail.shop_opening)*85.0)
		var leaf_width := width*0.25
		for side in [1.0,-1.0]:
			var hinge: Vector2 = p if side>0 else q
			for fold in 2:
				var direction: Vector2 = along*side*cos(angle)-inward*sin(angle)*(1.0 if fold==0 else -1.0)
				var end := hinge+direction*leaf_width
				# A 4 mm meeting gap prevents coincident folded board edges.
				_board_leaf(out,hinge+direction*0.002,end-direction*0.002,base+bottom,base+head-0.02,leaf_detail)
				hinge = end
		if i>0 and float(detail.porch_depth)>0.28:
			Roof.part(out,"F01",Vector3(left.x,base+height*0.5,left.y),
				{"height":height,"radius":float(detail.column_radius)*0.68,"sides":16})


static func _board_leaf(out: Array, a: Vector2, b: Vector2, low: float, high: float, detail: Dictionary) -> void:
	Shell.wall(out,a,b,low,low,high,"timber","",detail)
	var inward := Vector2(-(b-a).y,(b-a).x).normalized()
	var center := (a+b)*0.5-inward*0.025
	var yaw := rad_to_deg(-atan2((b-a).y,(b-a).x))
	for t in [0.18,0.82]:
		Roof.part(out,"F02",Vector3(center.x,lerpf(low,high,t),center.y),
			{"height":0.055,"depth":0.08},a.distance_to(b),yaw)
