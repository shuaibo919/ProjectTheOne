extends RefCounted
## Parameterized ridge profiles; all geometry remains CPU-side until submission.
const Data := preload("res://addons/ancient_building/core/mesh_data.gd")
const Kit := preload("res://addons/ancient_building/core/mesh_kit.gd")


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	var n := (b-a).cross(c-a).normalized()
	if n.dot(outward)<0:
		n = -n
	if n.length_squared()>0.1:
		Kit._add_tri(st,a,b,c,n,n,n)
	n = (c-a).cross(d-a).normalized()
	if n.dot(outward)<0:
		n = -n
	if n.length_squared()>0.1:
		Kit._add_tri(st,a,c,d,n,n,n)


## Plain masonry ridge: a covering foot, tapered body and smooth round coping.
## Joints indent this same shell; they never overlay coplanar decorative strips.
static func build(points: PackedVector3Array, breadth: float, height: float,
		joint_spacing := 0.40, finish_ends := false, profile := 0, end_lift := 0.0, foot_width := 0.0) -> Data:
	if points.size()<2:
		return Data.new()
	if profile==3:
		return _arcade(points,breadth,height,joint_spacing,end_lift,foot_width)
	var distances := PackedFloat32Array([0.0])
	for i in range(1,points.size()):
		distances.append(distances[-1]+points[i-1].distance_to(points[i]))
	var length := float(distances[-1])
	if length<0.0001:
		return Data.new()
	var dir := points[-1]-points[0]
	var side := Vector3(-dir.z,0,dir.x).normalized()
	var section := _section(profile)
	var stations: Array[float] = []
	for distance in distances:
		stations.append(distance)
	if end_lift>0:
		for i in range(1,17):
			stations.append(length*i/16.0)
	var joints: Array[float] = []
	var count := mini(256,maxi(1,roundi(length/maxf(joint_spacing,0.02)))) if joint_spacing>0 else 1
	var half_joint := minf(0.004,length/count*0.08)
	for i in range(1,count):
		var distance := length*i/count
		joints.append(distance)
		stations.append_array([distance-half_joint,distance,distance+half_joint])
	var bevel := minf(minf(breadth*0.07,0.02),length*0.05) if finish_ends else 0.0
	if bevel>0:
		stations.append_array([bevel,length-bevel])
	stations.sort()
	var rings: Array = []
	var segment := 0
	var previous := -1.0
	for distance in stations:
		if distance-previous<0.00001:
			continue
		previous = distance
		while segment+1<points.size()-1 and distance>distances[segment+1]:
			segment += 1
		var t := inverse_lerp(distances[segment],distances[segment+1],distance)
		var point := points[segment].lerp(points[segment+1],t)
		var inset := 0.0
		for joint in joints:
			inset = maxf(inset,minf(0.0025,minf(breadth,height)*0.04)*maxf(0,1.0-absf(distance-joint)/half_joint))
		if bevel>0:
			inset = maxf(inset,bevel*0.65*maxf(0,1.0-minf(distance,length-distance)/bevel))
		var ring := PackedVector3Array()
		for s in section:
			# Keep the complete foot and soffit covering the tile tails.
			var weight := smoothstep(0.12,0.40,s.y)
			var width := lerpf(maxf(breadth,foot_width),breadth,smoothstep(0.12,0.55,s.y))
			var x := signf(s.x)*maxf(0,absf(s.x*width)-inset*weight)
			var y := s.y*height-inset*weight*maxf(0,(s.y-0.55)/0.45)
			y += end_lift*pow(absf(2.0*distance/length-1.0),6.0)*s.y
			ring.append(point+side*x+Vector3.UP*y)
		rings.append(ring)
	var st := _begin()
	for i in range(rings.size()-1):
		for j in section.size():
			var k := (j+1)%section.size()
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][k]
			var c: Vector3 = rings[i+1][k]
			var d: Vector3 = rings[i+1][j]
			if profile==0 and j>=3 and j<15:
				var na := _ridge_normal(section[j],side,d-a,breadth,height)
				var nb := _ridge_normal(section[k],side,c-b,breadth,height)
				Kit._add_tri(st,a,b,c,na,nb,nb)
				Kit._add_tri(st,a,c,d,na,nb,na)
			else:
				var delta := section[k]-section[j]
				_quad(st,a,b,c,d,-side*delta.y+Vector3.UP*delta.x)
	# End caps belong only to the actual path ends, never intermediate stations.
	var cap := Geometry2D.triangulate_polygon(section)
	for end in [0,rings.size()-1]:
		var normal := dir.normalized()*(-1 if end==0 else 1)
		for j in range(0,cap.size(),3):
			Kit._add_tri(st,rings[end][cap[j]],rings[end][cap[j+1]],rings[end][cap[j+2]],normal,normal,normal)
	return Data.new(st)


static func _ridge_normal(s: Vector2, side: Vector3, along: Vector3, breadth: float, height: float) -> Vector3:
	var outward := side*(s.x/(0.16*breadth))+Vector3.UP*((s.y-0.55)/(0.2025*height))
	var tangent := -side*outward.y+Vector3.UP*outward.dot(side)
	var normal := tangent.cross(along).normalized()
	return normal if normal.dot(outward)>0 else -normal


static func _section(profile: int) -> PackedVector2Array:
	if profile==1:
		return PackedVector2Array([Vector2(-0.50,0),Vector2(-0.53,0.12),Vector2(-0.47,0.72),
			Vector2(-0.32,0.93),Vector2(0,1),Vector2(0.32,0.93),Vector2(0.47,0.72),Vector2(0.53,0.12),Vector2(0.50,0)])
	if profile==2:
		return PackedVector2Array([Vector2(-0.50,0),Vector2(-0.53,0.12),Vector2(-0.38,0.23),
			Vector2(-0.30,0.88),Vector2(-0.26,1),Vector2(0.26,1),Vector2(0.30,0.88),Vector2(0.38,0.23),Vector2(0.53,0.12),Vector2(0.50,0)])
	var section := PackedVector2Array([Vector2(-0.50,0),Vector2(-0.53,0.12),Vector2(-0.46,0.22),Vector2(-0.40,0.55)])
	for i in range(1,13):
		var angle := PI*(1.0-i/12.0)
		section.append(Vector2(0.40*cos(angle),0.55+0.45*sin(angle)))
	section.append_array(PackedVector2Array([Vector2(0.46,0.22),Vector2(0.53,0.12),Vector2(0.50,0)]))
	return section


static func _append(st: SurfaceTool, data: Data) -> void:
	var vertices: PackedVector3Array = data.arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = data.arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = data.arrays[Mesh.ARRAY_INDEX] if data.arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var count := vertices.size() if indices.is_empty() else indices.size()
	for i in range(0,count,3):
		var a := i if indices.is_empty() else indices[i]
		var b := i+1 if indices.is_empty() else indices[i+1]
		var c := i+2 if indices.is_empty() else indices[i+2]
		Kit._add_tri(st,vertices[a],vertices[b],vertices[c],normals[a],normals[b],normals[c])


static func _path_point(points: PackedVector3Array, distances: PackedFloat32Array, distance: float) -> Vector3:
	var segment := 0
	while segment+1<points.size()-1 and distance>distances[segment+1]:
		segment += 1
	var t := inverse_lerp(distances[segment],distances[segment+1],distance)
	return points[segment].lerp(points[segment+1],t)


static func _arc_point(points: PackedVector3Array, distances: PackedFloat32Array,
		side: Vector3, distance: float, y: float, z: float, height: float, end_lift: float) -> Vector3:
	var lift := end_lift*pow(absf(2.0*distance/float(distances[-1])-1.0),6.0)*y/height
	return _path_point(points,distances,distance)+Vector3.UP*(y+lift)+side*z


## The visible openings are holes through the solid arch band, not dark decals.
static func _arcade(points: PackedVector3Array, breadth: float, height: float,
		joint_spacing: float, end_lift: float, foot_width: float) -> Data:
	var distances := PackedFloat32Array([0.0])
	for i in range(1,points.size()):
		distances.append(distances[-1]+points[i-1].distance_to(points[i]))
	var length := float(distances[-1])
	if length<0.0001:
		return Data.new()
	var st := _begin()
	_append(st,build(points,breadth,height*0.36,joint_spacing,false,2,end_lift*0.36,foot_width))
	var dir := points[-1]-points[0]
	var side := Vector3(-dir.z,0,dir.x).normalized()
	var count := clampi(roundi(length/maxf(joint_spacing,0.35)),1,128)
	var pitch := length/count
	var radius := pitch*0.5
	var inner_radius := radius-minf(pitch*0.12,height*0.16)
	var base := height*0.36
	var rise := height*0.58
	var inner_rise := maxf(height*0.20,rise-height*0.13)
	var half_depth := breadth*0.24
	for arch in count:
		var center := pitch*(arch+0.5)
		for step in 12:
			var angles := [PI*step/12.0,PI*(step+1)/12.0]
			var rims: Array = []
			for angle in angles:
				var outer_d: float = center+radius*cos(angle)
				var inner_d: float = center+inner_radius*cos(angle)
				var outer_y: float = base+rise*sin(angle)
				var inner_y: float = base+inner_rise*sin(angle)
				var ring := PackedVector3Array()
				for z in [-half_depth,half_depth]:
					ring.append(_arc_point(points,distances,side,outer_d,outer_y,z,height,end_lift))
					ring.append(_arc_point(points,distances,side,inner_d,inner_y,z,height,end_lift))
				rims.append(ring)
			_quad(st,rims[0][0],rims[0][1],rims[1][1],rims[1][0],-side)
			_quad(st,rims[0][2],rims[0][3],rims[1][3],rims[1][2],side)
			var radial := dir.normalized()*cos((angles[0]+angles[1])*0.5)+Vector3.UP*sin((angles[0]+angles[1])*0.5)
			_quad(st,rims[0][0],rims[0][2],rims[1][2],rims[1][0],radial)
			_quad(st,rims[0][1],rims[0][3],rims[1][3],rims[1][1],-radial)
			# Feet meet the plinth on a shared edge. Do not add hidden coplanar caps.
	_arcade_coping(st,points,distances,side,breadth,height,end_lift)
	return Data.new(st)


## Continuous narrow coping bridges the arches; their .94h crowns embed in
## its .90h underside, while different widths prevent coincident side faces.
static func _arcade_coping(st: SurfaceTool, points: PackedVector3Array, distances: PackedFloat32Array,
		side: Vector3, breadth: float, height: float, end_lift: float) -> void:
	var length := float(distances[-1])
	var stations: Array[float] = []
	for distance in distances:
		stations.append(distance)
	for i in range(1,17):
		stations.append(length*i/17.0)
	stations.sort()
	var section := PackedVector2Array([Vector2(-0.34,0.90),Vector2(-0.34,0.96),
		Vector2(-0.26,1.0),Vector2(0.26,1.0),Vector2(0.34,0.96),Vector2(0.34,0.90)])
	var rings: Array = []
	var previous := -1.0
	for distance in stations:
		if distance-previous<0.00001:
			continue
		previous = distance
		var ring := PackedVector3Array()
		for s in section:
			ring.append(_arc_point(points,distances,side,distance,s.y*height,s.x*breadth,height,end_lift))
		rings.append(ring)
	for i in range(rings.size()-1):
		for j in section.size():
			var k := (j+1)%section.size()
			var delta := section[k]-section[j]
			_quad(st,rings[i][j],rings[i][k],rings[i+1][k],rings[i+1][j],-side*delta.y+Vector3.UP*delta.x)
	var caps := Geometry2D.triangulate_polygon(section)
	var dir := (points[-1]-points[0]).normalized()
	for end in [0,rings.size()-1]:
		var normal := dir*(-1 if end==0 else 1)
		for j in range(0,caps.size(),3):
			Kit._add_tri(st,rings[end][caps[j]],rings[end][caps[j+1]],rings[end][caps[j+2]],normal,normal,normal)
