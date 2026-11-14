extends RefCounted
const Data := preload("res://addons/ancient_building/core/mesh_data.gd")
## 定制轮廓仍是普通模块叶件；尺寸与裁切边界进入缓存身份。
const Plan := preload("res://addons/ancient_building/core/plan_geometry.gd")
const Kit := preload("res://addons/ancient_building/core/mesh_kit.gd")
const Roof := preload("res://addons/ancient_building/core/roof_geometry.gd")
const Damage := preload("res://addons/ancient_building/core/mesh_damage.gd")


static func validate(shape: Variant) -> String:
	if not shape is Dictionary or shape.get("kind", "") not in ["prism", "wall", "cover", "ridge", "gutter", "paving", "fascia"]:
		return "unsupported geometry kind"
	var points: Variant = shape.get("points", [])
	var minimum := 2 if shape.kind in ["ridge", "gutter"] else 3
	if not points is Array or points.size() < minimum or points.size() > 64:
		return "geometry requires %d–64 points" % minimum
	if shape.kind == "fascia" and (points.size()<4 or points.size()%2!=0):
		return "fascia requires paired front/back stations"
	if shape.has("point_residuals"):
		if shape.kind not in ["prism","cover","gutter"] or not shape.point_residuals is Array or shape.point_residuals.size()!=points.size():
			return "roof point residuals must match prism/cover/gutter points"
		for residual in shape.point_residuals:
			if not residual is Array or residual.size()!=3:
				return "roof point residuals require three integer micrometres"
			for value in residual:
				if not (value is int or value is float) or not is_finite(value) or value!=floorf(value) or absf(value)>500:
					return "roof point residual exceeds half a millimetre"
	if shape.has("edge_seals"):
		if shape.kind!="cover" or not shape.edge_seals is Array or shape.edge_seals.size()>256:
			return "edge seals require a bounded cover edge list"
		for seal in shape.edge_seals:
			if not seal is Array or seal.size()!=3:
				return "edge seal requires edge index and fixed-point interval"
			for value in seal:
				if not (value is int or value is float) or not is_finite(value) or value!=floorf(value):
					return "edge seal values must be finite integers"
			if seal[0]<0 or seal[0]>=points.size() or seal[1]<0 or seal[1]>=seal[2] or seal[2]>1000000:
				return "edge seal interval is outside its source edge"
	var point_sets: Array = [points]
	if shape.has("ridge_domain"):
		if shape.kind!="ridge" or not shape.ridge_domain is Array or shape.ridge_domain.size()<3 or shape.ridge_domain.size()>64:
			return "ridge miter requires a convex roof domain"
		if not shape.get("domain_residuals",null) is Array or shape.domain_residuals.size()!=shape.ridge_domain.size():
			return "ridge domain residual count mismatch"
		for row in shape.domain_residuals:
			if not row is Array or row.size()!=3:
				return "ridge domain residual requires three micrometres"
			for value in row:
				if not (value is int or value is float) or not is_finite(value) or value!=floorf(value) or absf(value)>500:
					return "ridge domain residual exceeds half a millimetre"
		point_sets.append(shape.ridge_domain)
	if shape.get("channel",false):
		if shape.kind!="gutter" or not shape.get("channel_line",null) is Array or shape.channel_line.size()!=2 or points.size()<3:
			return "channel requires a clipped roof polygon and two shared drainage stations"
		if not shape.get("channel_residuals",null) is Array or shape.channel_residuals.size()!=2:
			return "channel drainage stations require fixed-point residuals"
		for residual in shape.channel_residuals:
			if not residual is Array or residual.size()!=3:
				return "channel residual requires three micrometres"
			for value in residual:
				if not (value is int or value is float) or not is_finite(value) or value!=floorf(value) or absf(value)>500:
					return "channel residual exceeds half a millimetre"
		if not is_finite(float(shape.get("breadth",0))) or float(shape.get("breadth",0))<120:
			return "channel is too narrow"
		point_sets.append(shape.channel_line)
	if shape.has("plane"):
		if shape.kind != "cover" or not shape.plane is Array or shape.plane.size() != 3:
			return "cover plane requires three fixed-point integers"
		for value in shape.plane:
			if not (value is int or value is float) or not is_finite(value) or value != floorf(value) or absf(value)>1000000000:
				return "cover plane is not a bounded finite integer"
	if shape.has("edges"):
		if shape.kind != "gutter" or not shape.edges is Array or shape.edges.size() != 2:
			return "gutter requires two edge rails"
		for rail in shape.edges:
			if not rail is Array or rail.size() != points.size():
				return "gutter edge stations must match its path"
			point_sets.append(rail)
	for point_set in point_sets:
		for point in point_set:
			if not point is Array or point.size() != 3:
				return "geometry points require three integer millimetres"
			for value in point:
				if not (value is int or value is float) or not is_finite(value) or value != floorf(value):
					return "geometry point is not a finite integer"
				if absf(value) > 1000000:
					return "geometry point exceeds local size budget"
	return ""


static func decode_points(shape: Dictionary) -> PackedVector3Array:
	var points := Plan.decode(shape.points)
	if shape.has("point_residuals"):
		for i in points.size():
			var residual: Array = shape.point_residuals[i]
			points[i] += Vector3(residual[0],residual[1],residual[2])*0.000001
	return points


static func build(shape: Dictionary, params: Dictionary) -> Data:
	if shape.has("ridge_domain"):
		var source := shape.duplicate(true)
		source.erase("ridge_domain")
		source.erase("domain_residuals")
		return _miter_ridge(build(source,params),shape)
	var points := decode_points(shape)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match String(shape.kind):
		"fascia":
			var drop := Vector3.DOWN*float(params.get("height",95))*0.001
			for i in range(0,points.size()-2,2):
				var a := points[i]
				var b := points[i+2]
				var c := points[i+3]
				var d := points[i+1]
				Roof._quad(st,a,b,c,d,Vector3.UP)
				Roof._quad(st,a+drop,b+drop,c+drop,d+drop,Vector3.DOWN)
				Roof._quad(st,a,b,b+drop,a+drop,Vector3.BACK)
				Roof._quad(st,d,c,c+drop,d+drop,Vector3.FORWARD)
			for i in [0,points.size()-2]:
				Roof._quad(st,points[i],points[i+1],points[i+1]+drop,points[i]+drop,Vector3.LEFT if i==0 else Vector3.RIGHT)
		"paving":
			_paving(st, points, float(shape.get("pitch",750))*0.001)
		"prism":
			_prism(st, points, Vector3.DOWN * float(shape.get("depth", 80)) * 0.001, 1)
		"wall":
			_wall(st, points, params, int(shape.get("style", 0)))
		"cover":
			_cover(st, points, shape)
		"ridge":
			if shape.get("covering", "tile") == "thatch":
				var width := float(shape.get("breadth", 300)) * 0.001
				var axis := (points[-1] - points[0]).normalized()
				var side := Vector3(-axis.z, 0, axis.x).normalized()
				for i in 12:
					var angle_a := PI * i / 12.0
					var angle_b := PI * (i + 1) / 12.0
					var offset_a := (side * cos(angle_a) + Vector3.UP * sin(angle_a)) * width * 0.5
					var offset_b := (side * cos(angle_b) + Vector3.UP * sin(angle_b)) * width * 0.5
					Roof._quad(st, points[0] + offset_a, points[-1] + offset_a, points[-1] + offset_b,
						points[0] + offset_b, (offset_a + offset_b).normalized())
				return Data.new(st)
			return Roof.ridge(points, float(shape.get("breadth", 180)) * 0.001,
				float(shape.get("height", 130)) * 0.001,float(shape.get("joint_spacing",400))*0.001,false,int(shape.get("profile",0)),
				float(shape.get("end_lift",0))*0.001,float(shape.get("foot_width",0))*0.001)
		"gutter":
			if shape.get("channel",false):
				_channel(st,points,shape)
				return Data.new(st)
			if shape.has("edges"):
				var left := Plan.decode(shape.edges[0])
				var right := Plan.decode(shape.edges[1])
				var thickness := Vector3.DOWN*0.012
				for i in range(points.size()-1):
					for rail in [left,right]:
						Roof._quad(st,points[i],points[i+1],rail[i+1],rail[i],Vector3.UP)
						Roof._quad(st,points[i]+thickness,points[i+1]+thickness,rail[i+1]+thickness,rail[i]+thickness,Vector3.DOWN)
						Roof._quad(st,rail[i],rail[i+1],rail[i+1]+thickness,rail[i]+thickness,rail[i]-points[i])
				for i in [0,points.size()-1]:
					var outward := points[0]-points[1] if i==0 else points[-1]-points[-2]
					for rail in [left,right]:
						Roof._quad(st,points[i],rail[i],rail[i]+thickness,points[i]+thickness,outward)
				return Data.new(st)
			if shape.get("upstand", false):
				var direction: Array = shape.outward
				var outward := Vector3(direction[0], 0, direction[1]).normalized()
				_flashing(st,points[0],points[-1],outward)
				return Data.new(st)
			var along := (points[-1] - points[0]).normalized()
			var across := Vector3(-along.z, 0, along.x).normalized() * float(shape.get("breadth",240))*0.0005
			var lifts: Array = shape.get("edge_lifts",[60,60])
			for side in 2:
				var offset := across*(-1 if side==0 else 1)+Vector3.UP*float(lifts[side])*0.001
				_prism(st,PackedVector3Array([points[0],points[-1],points[-1]+offset,points[0]+offset]),Vector3.DOWN*0.012,1)
	return Data.new(st)


## Trim the entire profiled ridge shell by the same roof-sector domain. Each
## branch extends through the junction before clipping; the cut profiles meet
## on a shared miter, without crossing end caps or an unrelated floating lid.
static func _miter_ridge(source: Data, shape: Dictionary) -> Data:
	var domain := Plan.decode(shape.ridge_domain)
	var polygon := PackedVector2Array()
	for i in domain.size():
		var residual: Array = shape.domain_residuals[i]
		domain[i] += Vector3(residual[0],residual[1],residual[2])*0.000001
		polygon.append(Vector2(domain[i].x,domain[i].z))
	polygon = Plan.clean(polygon)
	var vertices: PackedVector3Array = source.arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source.arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = source.arrays[Mesh.ARRAY_INDEX] if source.arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var count := vertices.size() if indices.is_empty() else indices.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,count,3):
		var points: Array = []
		for j in 3:
			var index := i+j if indices.is_empty() else indices[i+j]
			points.append({"p":vertices[index],"n":normals[index]})
		for edge in polygon.size():
			if points.is_empty():
				break
			var a := polygon[edge]
			var delta := polygon[(edge+1)%polygon.size()]-a
			var next: Array = []
			for j in points.size():
				var p: Dictionary = points[j]
				var q: Dictionary = points[(j+1)%points.size()]
				var dp := delta.cross(Vector2(p.p.x,p.p.z)-a)
				var dq := delta.cross(Vector2(q.p.x,q.p.z)-a)
				if dp>=-0.0000001:
					next.append(p)
				if (dp<0 and dq>0) or (dp>0 and dq<0):
					var t := dp/(dp-dq)
					next.append({"p":p.p.lerp(q.p,t),"n":p.n.lerp(q.n,t).normalized()})
			points = next
		for j in range(1,points.size()-1):
			var a: Dictionary = points[0]
			var b: Dictionary = points[j]
			var c: Dictionary = points[j+1]
			if (b.p-a.p).cross(c.p-a.p).length_squared()>0.000000000001:
				Kit._add_tri(st,a.p,b.p,c.p,a.n,b.n,c.n)
	return Data.new(st)


## A valley is one continuous U section on the solved slope, clipped by the
## very same boundaries as the tile fields. The outer rim lands on the cover's
## lower edge; subdivisions are not independently capped metal-like strips.
static func _channel(st: SurfaceTool, points: PackedVector3Array, shape: Dictionary) -> void:
	var path := Plan.decode(shape.channel_line)
	for i in path.size():
		var residual: Array = shape.channel_residuals[i]
		path[i] += Vector3(residual[0],residual[1],residual[2])*0.000001
	var p := Vector2(path[0].x,path[0].z)
	var q := Vector2(path[-1].x,path[-1].z)
	var axis := (q-p).normalized()
	var normal := Vector2(-axis.y,axis.x)
	var half := float(shape.breadth)*0.0005
	var start_half := float(shape.get("start_breadth",shape.breadth))*0.0005
	var widening := (half-start_half)/p.distance_to(q)
	var rim := float(shape.get("rim_height",80))*0.001
	var depth := float(shape.get("depth",28))*0.001
	var outline := PackedVector2Array()
	for point in points:
		outline.append(Vector2(point.x,point.z))
	var plane := Vector3.ZERO
	for i in range(1,points.size()-1):
		if absf((outline[i]-outline[0]).cross(outline[i+1]-outline[0]))>0.00000001:
			plane = Plan.plane(points[0],points[i],points[i+1])
			break
	var cuts := PackedFloat32Array([-1.0,-0.86,-0.65,-0.35,0.0,0.35,0.65,0.86,1.0])
	for i in range(cuts.size()-1):
		var low_normal := normal-axis*widening*float(cuts[i])
		var high_normal := normal-axis*widening*float(cuts[i+1])
		var low := low_normal.dot(p)+float(cuts[i])*start_half
		var high := high_normal.dot(p)+float(cuts[i+1])*start_half
		var poly := Plan.clip(Plan.clip(outline,-low_normal,-low),high_normal,high)
		if poly.is_empty():
			continue
		var top := PackedVector3Array()
		for point in poly:
			top.append(Vector3(point.x,_channel_height(point,plane,path,normal,half,start_half,rim),point.y))
		var indices := Geometry2D.triangulate_polygon(poly)
		for j in range(0,indices.size(),3):
			var a := top[indices[j]]
			var b := top[indices[j+1]]
			var c := top[indices[j+2]]
			var n := (b-a).cross(c-a).normalized()
			if n.y<0:
				n = -n
			if n.length_squared()>0.1:
				Kit._add_tri(st,a,b,c,n,n,n)
				Kit._add_tri(st,a-Vector3.UP*depth,c-Vector3.UP*depth,b-Vector3.UP*depth,-n,-n,-n)
	# Only the two actual outer rails need a thickness wall. Face/course cuts
	# meet neighbour channel pieces at a shared cross section without end caps.
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		var da := normal.dot(a-p)
		var db := normal.dot(b-p)
		var half_a := start_half+(a-p).dot(axis)*widening
		var half_b := start_half+(b-p).dot(axis)*widening
		if absf(absf(da)-half_a)>0.00002 or absf(absf(db)-half_b)>0.00002 or da*db<0:
			continue
		var top_a := Vector3(a.x,Plan.height(plane,a),a.y)
		var top_b := Vector3(b.x,Plan.height(plane,b),b.y)
		Roof._quad(st,top_a,top_b,top_b-Vector3.UP*depth,top_a-Vector3.UP*depth,Vector3(normal.x,0,normal.y)*signf(da))


static func _channel_height(point: Vector2, plane: Vector3, path: PackedVector3Array,
		normal: Vector2, half: float, start_half: float, rim: float) -> float:
	var first := Vector2(path[0].x,path[0].z)
	var delta := Vector2(path[-1].x-path[0].x,path[-1].z-path[0].z)
	var along := (point-first).dot(delta)/delta.length_squared()
	var center := lerpf(path[0].y,path[-1].y,along)
	var local_half := maxf(0.000001,lerpf(start_half,half,along))
	var t := clampf(absf(normal.dot(point-first))/local_half,0,1)
	var lip := 0.0
	if t>0.65:
		lip = inverse_lerp(0.65,0.86,t) if t<0.86 else inverse_lerp(1.0,0.86,t)
	return center+(Plan.height(plane,point)-center)*t*t+rim*lip


## Closed wall upstand with a bedded apron, rather than two zero-thickness sheets.
## The apron covers tile crests; its lower bedding closes the intervening grooves.
static func _flashing(st: SurfaceTool, a: Vector3, b: Vector3, outward: Vector3) -> void:
	var section := Plan.clean(PackedVector2Array([Vector2(0,-0.15),Vector2(0.22,-0.20),
		Vector2(0.22,-0.05),Vector2(0.012,0),Vector2(0.012,0.20),Vector2(0,0.20)]))
	var first := PackedVector3Array()
	var last := PackedVector3Array()
	var center := Vector3.ZERO
	for p in section:
		var offset := outward*p.x+Vector3.UP*p.y
		first.append(a+offset)
		last.append(b+offset)
		center += offset/section.size()
	for i in section.size():
		var j := (i+1)%section.size()
		Roof._quad(st,first[i],last[i],last[j],first[j],(first[i]+first[j])*0.5-a-center)
	var triangles := Geometry2D.triangulate_polygon(section)
	var direction := (b-a).normalized()
	for i in range(0,triangles.size(),3):
		var x := triangles[i]
		var y := triangles[i+1]
		var z := triangles[i+2]
		Kit._add_tri(st,first[x],first[y],first[z],-direction,-direction,-direction)
		Kit._add_tri(st,last[x],last[y],last[z],direction,direction,direction)


static func _prism(st: SurfaceTool, points: PackedVector3Array, offset: Vector3, axis: int) -> void:
	var outline := PackedVector2Array()
	for p in points:
		outline.append(Vector2(p.x, p.z) if axis == 1 else Vector2(p.x, p.y))
	var indices := Geometry2D.triangulate_polygon(outline)
	var outward := -offset.normalized()
	for i in range(0, indices.size(), 3):
		var a := points[indices[i]]
		var b := points[indices[i + 1]]
		var c := points[indices[i + 2]]
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot(outward) < 0:
			normal = -normal
		Kit._add_tri(st, a, b, c, normal, normal, normal)
		Kit._add_tri(st, a + offset, b + offset, c + offset, -normal, -normal, -normal)
	var center := Vector3.ZERO
	for p in points:
		center += p / points.size()
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		Roof._quad(st, a, b, b + offset, a + offset, (a + b) * 0.5 - center)


static func _wall(st: SurfaceTool, points: PackedVector3Array, p: Dictionary, style: int) -> void:
	var thickness := float(p.thickness) * 0.001
	var poly := PackedVector2Array()
	for point in points:
		poly.append(Vector2(point.x, point.y))
	poly = Plan.clean(poly)
	if poly.is_empty():
		return
	if style in [0, 1]:
		var front := PackedVector3Array()
		for point in poly:
			front.append(Vector3(point.x, point.y, thickness * 0.5))
		_prism(st, front, Vector3.FORWARD * thickness, 2)
		return
	var box := Plan.bounds(poly)
	var pitch := float(p.get("board_width", 180)) * 0.001
	if style == 3:
		pitch = float(p.get("log_diameter", 220)) * 0.001
	var start := box.position.x if style == 2 else box.position.y
	var finish := box.end.x if style == 2 else box.end.y
	var count := maxi(1, ceili((finish - start) / pitch))
	for i in count:
		var low := start + i * pitch + 0.003
		var high := minf(finish, start + (i + 1) * pitch - 0.003)
		var direction := Vector2.RIGHT if style == 2 else Vector2.DOWN
		var strip := Plan.clip(Plan.clip(poly, -direction, -low), direction, high)
		if strip.is_empty():
			continue
		if style == 2:
			var front := PackedVector3Array()
			var relief := 0.008 * sin(i * 4.7)
			for point in strip:
				front.append(Vector3(point.x, point.y, thickness * 0.5 + relief))
			_prism(st, front, Vector3.FORWARD * thickness, 2)
		else:
			_log(st, strip, (low + high) * 0.5, pitch * 0.49, thickness * 0.5)


static func _log(st: SurfaceTool, poly: PackedVector2Array, y: float, radius: float, depth: float) -> void:
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	var box := Plan.bounds(poly)
	for i in 12:
		var angle := TAU * i / 12.0
		var py := clampf(y + sin(angle) * radius, box.position.y + 0.0001, box.end.y - 0.0001)
		var xs: Array[float] = []
		for j in poly.size():
			var a := poly[j]
			var b := poly[(j + 1) % poly.size()]
			if absf(a.y - b.y) > 0.00001 and py >= minf(a.y, b.y) and py <= maxf(a.y, b.y):
				xs.append(lerpf(a.x, b.x, (py - a.y) / (b.y - a.y)))
		if xs.is_empty():
			return
		xs.sort()
		left.append(Vector3(xs[0], py, cos(angle) * depth))
		right.append(Vector3(xs[-1], py, cos(angle) * depth))
	for i in 12:
		var j := (i + 1) % 12
		Roof._quad(st, left[i], right[i], right[j], left[j], Vector3(0, left[i].y - y, left[i].z))
		Kit._add_tri(st, Vector3(left[i].x, y, 0), left[i], left[j], Vector3.LEFT, Vector3.LEFT, Vector3.LEFT)
		Kit._add_tri(st, Vector3(right[i].x, y, 0), right[j], right[i], Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT)


static func _cover(st: SurfaceTool, points: PackedVector3Array, shape: Dictionary) -> void:
	var plane := Plan.plane(points[0], points[1], points[2])
	if shape.has("plane"):
		plane = Vector3(shape.plane[0],shape.plane[1],shape.plane[2])*0.000001
	var direction: Array = shape.get("direction", [10000, 0])
	var u := Vector2(direction[0], direction[1]).normalized()
	var v := Vector2(-u.y, u.x)
	var grid_origin: Array = shape.get("grid_origin", [0, 0])
	var origin := Vector2(grid_origin[0], grid_origin[1]) * 0.001
	var poly := PackedVector2Array()
	for point in points:
		var xz := Vector2(point.x, point.z) + origin
		poly.append(Vector2(xz.dot(u), xz.dot(v)))
	var seals: Array = []
	for interval in shape.get("edge_seals",[]):
		var edge := int(interval[0])
		var a := poly[edge]
		var b := poly[(edge+1)%poly.size()]
		seals.append(PackedVector2Array([a.lerp(b,interval[1]*0.000001),a.lerp(b,interval[2]*0.000001)]))
	poly = Plan.clean(poly)
	if poly.is_empty():
		return
	var box := Plan.bounds(poly)
	var straw: bool = shape.get("covering", "tile") == "thatch"
	var pitch := 0.16 if straw else float(shape.get("pitch", 285)) * 0.001
	var course := 0.45 if straw else 0.32
	for row in range(floori(box.position.y / course), ceili(box.end.y / course)):
		for col in range(floori(box.position.x / pitch), ceili(box.end.x / pitch)):
			var seed_value := absi(row * 137 + col * 53)
			var jitter := Damage.sample(seed_value, 4)
			var slices := 4 if straw else 20
			for slice_index in slices:
				var low_x := pitch * (col + float(slice_index) / slices)
				var high_x := pitch * (col + float(slice_index + 1) / slices)
				var low_y := course * row - (0.05 if straw else 0.018)
				var high_y := course * (row + 1)
				var cell := Plan.intersect(poly, PackedVector2Array([
					Vector2(low_x, low_y), Vector2(high_x, low_y), Vector2(high_x, high_y), Vector2(low_x, high_y)]))
				if cell.is_empty():
					continue
				var surface := PackedVector3Array()
				for point in cell:
					var xz := u * point.x + v * point.y - origin
					var phase := clampf((point.x / pitch - col), 0.0, 1.0)
					var cap_distance := absf(phase-0.5)*pitch
					var cap_radius := pitch*0.205
					var relief := 0.054+sqrt(maxf(0,cap_radius*cap_radius-cap_distance*cap_distance)) if cap_distance <= cap_radius else 0.012+0.041*pow(1.0-(cap_distance-cap_radius)/(pitch*0.5-cap_radius),2)
					relief += 0.024
					var overlap := (1.0 - clampf((point.y - low_y) / course, 0.0, 1.0)) * 0.022
					if straw:
						relief = 0.15 + jitter * 0.045 + sin(PI * phase) * 0.035
						overlap *= 2.0
					surface.append(Vector3(xz.x, Plan.height(plane, xz) + relief + overlap, xz.y))
				if straw:
					_prism(st,surface,Vector3.DOWN*0.10,1)
				else:
					Roof.tile_surface(st,cell,surface,maxf(low_y,box.position.y),0.018,Vector3(-v.x,0,-v.y))
				var seal_end := high_y-(0.05 if straw else 0.018)
				if row+1>=ceili(box.end.y/course):
					seal_end = box.end.y
				# Straw already owns a 100 mm prism side wall: the additional seal
				# starts below that wall, but still ends at the unlifted channel plane.
				_seal_cover_edges(st,cell,surface,seals,plane,seal_end,0.10 if straw else 0.0)


## 裁断筒瓦的真实弧形截面封至沟底。相邻瓦片搭接区只由较高一片负责，
## 否则侧壁自身又会共面重叠；茅草只补既有束厚下方的空隙。
static func _seal_cover_edges(st: SurfaceTool, cell: PackedVector2Array, surface: PackedVector3Array,
		seals: Array, plane: Vector3, end: float, top_offset: float) -> void:
	for i in cell.size():
		var j := (i+1)%cell.size()
		var a := cell[i]
		var b := cell[j]
		var direction := b-a
		var length := direction.length()
		if length<0.00001:
			continue
		for seal in seals:
			if absf(direction.cross(seal[0]-a))/length>0.00002 or absf(direction.cross(seal[1]-a))/length>0.00002:
				continue
			var first: float = (seal[0]-a).dot(direction)/direction.length_squared()
			var last: float = (seal[1]-a).dot(direction)/direction.length_squared()
			var low := clampf(minf(first,last),0,1)
			var high := clampf(maxf(first,last),0,1)
			if absf(direction.y)>0.000001:
				var stop := (end-a.y)/direction.y
				if direction.y>0:
					high = minf(high,stop)
				else:
					low = maxf(low,stop)
			elif a.y>end+0.00001:
				continue
			if (high-low)*length<0.00001:
				continue
			var p := surface[i].lerp(surface[j],low)-Vector3.UP*top_offset
			var q := surface[i].lerp(surface[j],high)-Vector3.UP*top_offset
			var bottom_p := Vector3(p.x,Plan.height(plane,Vector2(p.x,p.z)),p.z)
			var bottom_q := Vector3(q.x,Plan.height(plane,Vector2(q.x,q.z)),q.z)
			Roof._quad(st,p,q,bottom_q,bottom_p,Vector3(q.z-p.z,0,p.x-q.x))


static func _paving(st: SurfaceTool, points: PackedVector3Array, pitch: float) -> void:
	var poly := PackedVector2Array()
	for p in points:
		poly.append(Vector2(p.x,p.z))
	poly = Plan.clean(poly)
	var bounds := Plan.bounds(poly)
	for row in range(floori(bounds.position.y/pitch),ceili(bounds.end.y/pitch)):
		for col in range(floori(bounds.position.x/pitch),ceili(bounds.end.x/pitch)):
			var low := Vector2(col,row)*pitch+Vector2.ONE*0.006
			var high := low+Vector2.ONE*(pitch-0.012)
			var cell := Plan.intersect(poly,PackedVector2Array([low,Vector2(high.x,low.y),high,Vector2(low.x,high.y)]))
			if cell.size() < 3:
				continue
			var surface := PackedVector3Array()
			var level := points[0].y+Damage.sample(absi(col*97+row*137),9)*0.006
			for p in cell:
				surface.append(Vector3(p.x,level,p.y))
			_prism(st,surface,Vector3.DOWN*0.045,1)


static func thatch_patch(width: float, p: Dictionary) -> Data:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var run := float(p.depth)*0.001
	var inset := float(p.inset)*0.001
	var rise := float(p.rise)*0.001
	var lift := float(p.lift)*0.001
	var curve := float(p.get("curve",5200))/10000.0
	var thickness := float(p.get("straw_depth",240))*0.001
	var ragged := float(p.get("ragged",6000))/10000.0
	var bundle := float(p.get("bundle",160))*0.001
	var columns := maxi(2,ceili(width/bundle))
	var rows := maxi(2,ceili(run/0.44))
	for row in rows:
		for col in columns:
			var seed_value := int(p.get("straw_seed",0))+row*137+col*53
			var jitter := Damage.sample(seed_value,4)
			var low := maxf(0.0,(row-0.36)/rows)
			var high := minf(1.0,(row+1.0)/rows)
			var offset := (jitter-0.5)*0.4
			var u := clampf((col+offset)*2.0/columns-1.0,-1.0,1.0)
			var v := clampf((col+1+offset)*2.0/columns-1.0,-1.0,1.0)
			for strand in 15:
				var x0 := lerpf(u,v,strand/15.0)
				var x1 := lerpf(u,v,(strand+1.0)/15.0)
				var tip := Damage.sample(seed_value,strand+17)
				var t0 := low-(0.025+tip*0.13)*ragged/run
				var a := Roof._face_point(x0,t0,width*0.5,run,inset,rise,lift,curve)
				var b := Roof._face_point(x1,t0,width*0.5,run,inset,rise,lift,curve)
				var c := Roof._face_point(x1,high,width*0.5,run,inset,rise,lift,curve)
				var d := Roof._face_point(x0,high,width*0.5,run,inset,rise,lift,curve)
				var belly := thickness*(0.80+jitter*0.25)+sin(PI*(strand+0.5)/15.0)*0.025
				a.y += belly + tip*0.025
				b.y += belly + tip*0.025
				c.y += thickness*0.64
				d.y += thickness*0.64
				# 厚实的分束切口；草梢短裂隙保持底层覆盖，不穿透屋面。
				_prism(st,PackedVector3Array([a,b,c,d]),Vector3.DOWN*thickness*0.52,1)
				if ragged > 0.01:
					var point := (a+b)*0.5+Vector3(0,-thickness*0.36,0.025+tip*0.10*ragged)
					Kit._add_tri(st,a,b,point,Vector3.UP,Vector3.UP,Vector3.BACK)
	return Data.new(st)
