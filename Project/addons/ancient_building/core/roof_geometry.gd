extends RefCounted
const Data := preload("res://addons/ancient_building/core/mesh_data.gd")
## One face in eave coordinates: X along the eave, -Z uphill, t=0 at the drip.
## The left/right distances let identical interior courses share a mesh across bays.
const Ridge := preload("res://addons/ancient_building/core/ridge_geometry.gd")
const Plan := preload("res://addons/ancient_building/core/plan_geometry.gd")
const Joinery := preload("res://addons/ancient_building/core/joinery.gd")

# Physical assembly clearances; no renderer depth bias.
const BOARD_RECESS := 0.025
const CAP_BACK := 0.080
const CAP_BASE := 0.078
const CORNER_CLEARANCE := 0.015
const FASCIA_FRONT := 0.008
const FASCIA_DEPTH := 0.084
const FASCIA_TOP_RECESS := 0.030

const Kit := preload("res://addons/ancient_building/core/mesh_kit.gd")


static func height_at(t: float, edge_distance: float, rise: float, lift: float, curve := 0.52) -> float:
	var wing := pow(maxf(0.0, 1.0 - edge_distance / 1.35), 2.0)
	return rise * t * (1.0 - curve + curve * t) + lift * wing * (1.0 - t) * (1.0 - t)


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot(outward) < 0.0:
		n = -n
	if n.length_squared() > 0.1:
		Kit._add_tri(st, a, b, c, n, n, n)
	n = (c - a).cross(d - a).normalized()
	if n.dot(outward) < 0.0:
		n = -n
	if n.length_squared() > 0.1:
		Kit._add_tri(st, a, c, d, n, n, n)


static func _face_point(u: float, t: float, half: float, run: float, inset: float, rise: float, lift: float, curve := 0.52) -> Vector3:
	var x := u * (half - inset * t)
	return Vector3(x, height_at(t, half - absf(x), rise, lift, curve), -run * t)


static func boarding(width: float, run: float, inset: float, rise: float, lift: float, curve := 0.52) -> Data:
	var st := _begin()
	var half := width * 0.5
	var nx := maxi(4, ceili(width / 0.32))
	var thickness := Vector3.UP * 0.08
	for i in nx:
		var u := 2.0 * i / nx - 1.0
		var v := 2.0 * (i + 1) / nx - 1.0
		for j in 12:
			var t := j / 12.0
			var s := (j + 1) / 12.0
			var a := _face_point(u, t, half, run, inset, rise, lift, curve) - Vector3.UP*BOARD_RECESS
			var b := _face_point(v, t, half, run, inset, rise, lift, curve) - Vector3.UP*BOARD_RECESS
			var c := _face_point(v, s, half, run, inset, rise, lift, curve) - Vector3.UP*BOARD_RECESS
			var d := _face_point(u, s, half, run, inset, rise, lift, curve) - Vector3.UP*BOARD_RECESS
			_quad(st, a, b, c, d, Vector3.UP)
			_quad(st, a-thickness, b-thickness, c-thickness, d-thickness, Vector3.DOWN)
			if j == 0:
				_quad(st, a, b, b-thickness, a-thickness, Vector3.BACK)
			if i == 0:
				_quad(st, a, d, d-thickness, a-thickness, Vector3.LEFT)
			if i == nx-1:
				_quad(st, b, c, c-thickness, b-thickness, Vector3.RIGHT)
	return Data.new(st)


## Half-pan, barrel, half-pan across X. Each physical tile overlaps the next downhill.
static func course(p: Dictionary) -> Data:
	if int(p.get("pattern",0))!=0:
		return _flat_courses(p)
	var st := _begin()
	var run := float(p.length) * 0.001
	var pitch := float(p.pitch) * 0.001
	var inset := float(p.inset) * 0.001
	var rise := float(p.rise) * 0.001
	var lift := float(p.lift) * 0.001
	var left := float(p.left) * 0.001
	var right := float(p.right) * 0.001
	var radius := minf(p.radius * 0.001, pitch * 0.30)
	var max_t := minf(1.0, (minf(left, right) + pitch * 0.5) / inset) if inset > 0.0 else 1.0
	var n := maxi(1, roundi(Vector2(run, rise).length() / 0.32))
	var profile := PackedVector2Array()
	for i in 5:
		var a := i / 4.0
		profile.append(Vector2(lerpf(-pitch*0.5, -radius, a), 0.012 + a*a*0.041))
	for i in 13:
		var angle := PI * i / 12.0
		profile.append(Vector2(-radius*cos(angle), 0.054 + radius*sin(angle)))
	for i in range(1, 6):
		var a := i / 5.0
		profile.append(Vector2(lerpf(radius, pitch*0.5, a), 0.012 + (1.0-a)*(1.0-a)*0.041))
	var curve := float(p.get("curve",5200))/10000.0
	for j in mini(n, ceili(max_t*n)):
		var low := maxf(0.0, (j - 0.10) / n)*run
		var high := (j + 1.0) / n*run
		for i in range(profile.size()-1):
			var a := profile[i]
			var b := profile[i+1]
			# Clip the tile footprint before lifting it. Clamping vertices on the
			# hip line stacked many folded triangles onto that same plane.
			var poly := PackedVector2Array([Vector2(a.x,low),Vector2(b.x,low),Vector2(b.x,high),Vector2(a.x,high)])
			poly = Plan.clip(poly,Vector2(1,inset/run),right)
			poly = Plan.clip(poly,Vector2(-1,inset/run),left)
			if poly.is_empty():
				continue
			var surface := PackedVector3Array()
			for point in poly:
				var relief := lerpf(a.y,b.y,inverse_lerp(a.x,b.x,point.x))
				var lap := lerpf(0.024,0.004,inverse_lerp(low,high,point.y))
				var distance := minf(left+point.x,right-point.x)
				surface.append(Vector3(point.x,height_at(point.y/run,distance,rise,lift,curve)+relief+lap,-point.y))
			tile_surface(st,poly,surface,low,0.018,Vector3.BACK)
	return Data.new(st)


## Shared ridge implementation, also used by clipped shells.
static func ridge(points: PackedVector3Array, breadth: float, height: float,
		joint_spacing := 0.40, finish_ends := false, profile := 0, end_lift := 0.0, foot_width := 0.0) -> Data:
	return Ridge.build(points,breadth,height,joint_spacing,finish_ends,profile,end_lift,foot_width)


## Restrained eave tile. The concave pan edge and a short water-shedding tip
## remain; its 32 mm body keeps the existing fascia/cap contact envelope.
static func plain_drip(width: float) -> Data:
	var st := _begin()
	var outline := PackedVector2Array()
	for point in [Vector2(-0.5,0.04),Vector2(-0.36,-0.05),Vector2(0,-0.14),
			Vector2(0.36,-0.05),Vector2(0.5,0.04),Vector2(0.46,-0.17),
			Vector2(0.31,-0.24),Vector2(0,-0.34),Vector2(-0.31,-0.24),Vector2(-0.46,-0.17)]:
		outline.append(point*width)
	Joinery.panel(st,outline,0.032)
	return Data.new(st)


static func gable(width: float, rise: float, thickness: float, curve := 0.52) -> Data:
	var st := _begin()
	for i in 24:
		var x0 := width*(i/24.0-0.5)
		var x1 := width*((i+1)/24.0-0.5)
		var h0 := height_at(1.0-absf(2.0*x0/width), 2, rise, 0, curve)
		var h1 := height_at(1.0-absf(2.0*x1/width), 2, rise, 0, curve)
		for sign_z in [-1.0, 1.0]:
			var z: float = sign_z*thickness*0.5
			_quad(st, Vector3(x0,0,z), Vector3(x1,0,z), Vector3(x1,h1,z), Vector3(x0,h0,z), Vector3.BACK*sign_z)
	return Data.new(st)


## A tiled strip owns its top and downhill lip only. Neighbouring strips and
## clipped roof fragments must not each emit a coincident internal side wall.
static func tile_surface(st: SurfaceTool, outline: PackedVector2Array, surface: PackedVector3Array,
		front: float, thickness: float, outward: Vector3) -> void:
	var indices := Geometry2D.triangulate_polygon(outline)
	for i in range(0,indices.size(),3):
		var a := surface[indices[i]]
		var b := surface[indices[i+1]]
		var c := surface[indices[i+2]]
		var normal := (b-a).cross(c-a).normalized()
		if normal.y < 0:
			normal = -normal
		if normal.length_squared() > 0.1:
			Kit._add_tri(st,a,b,c,normal,normal,normal)
	for i in outline.size():
		var j := (i+1)%outline.size()
		if absf(outline[i].y-front)<0.000001 and absf(outline[j].y-front)<0.000001:
			_quad(st,surface[i],surface[j],surface[j]-Vector3.UP*thickness,surface[i]-Vector3.UP*thickness,outward)


## Alternate flat pans own only their strip. Odd rows meet at half-tile offsets;
## rounded toes are actual scalloped outlines, not painted zigzags.
static func _flat_courses(p: Dictionary) -> Data:
	var st := _begin()
	var run := float(p.length)*0.001
	var pitch := float(p.pitch)*0.001
	var inset := float(p.inset)*0.001
	var rise := float(p.rise)*0.001
	var lift := float(p.lift)*0.001
	var left := float(p.left)*0.001
	var right := float(p.right)*0.001
	var curve := float(p.get("curve",5200))/10000.0
	var pattern := int(p.get("pattern",1))
	var rows := maxi(1,roundi(Vector2(run,rise).length()/0.30))
	for row in rows:
		var low := maxf(0,(row-0.22)*run/rows)
		var high := (row+1.0)*run/rows
		var centers := PackedFloat32Array([0.0]) if row%2==0 else PackedFloat32Array([-pitch*0.5,pitch*0.5])
		for center in centers:
			var half := pitch*0.5-0.0015
			var outline := PackedVector2Array()
			for i in 9:
				var u := i/4.0-1.0
				var setback := run/rows*0.20*(1.0-sqrt(maxf(0,1-u*u))) if pattern==2 else 0.0
				outline.append(Vector2(center+u*half,low+setback))
			outline.append(Vector2(center+half,high))
			outline.append(Vector2(center-half,high))
			var poly := Plan.clip(outline,Vector2.RIGHT,pitch*0.5)
			poly = Plan.clip(poly,Vector2.LEFT,pitch*0.5)
			poly = Plan.clip(poly,Vector2(1,inset/run),right)
			poly = Plan.clip(poly,Vector2(-1,inset/run),left)
			if poly.is_empty():
				continue
			var surface := PackedVector3Array()
			for point in poly:
				var u := clampf((point.x-center)/half,-1,1)
				var cup := 0.022+0.008*u*u
				var lap := lerpf(0.027,0.003,inverse_lerp(low,high,point.y))
				var distance := minf(left+point.x,right-point.x)
				surface.append(Vector3(point.x,height_at(point.y/run,distance,rise,lift,curve)+cup+lap,-point.y))
			# Top only here; explicit original toe-edge matching below excludes
			# virtual course boundaries and hip clipping edges from end caps.
			tile_surface(st,poly,surface,-1000.0,0.012,Vector3.BACK)
			for i in poly.size():
				var next := (i+1)%poly.size()
				var is_toe := false
				for edge in 8:
					var a := outline[edge]
					var b := outline[edge+1]
					if absf((b-a).cross(poly[i]-a))<0.0000001 and absf((b-a).cross(poly[next]-a))<0.0000001:
						is_toe = true
						break
				if is_toe:
					_quad(st,surface[i],surface[next],surface[next]-Vector3.UP*0.012,surface[i]-Vector3.UP*0.012,Vector3.BACK)
	return Data.new(st)
