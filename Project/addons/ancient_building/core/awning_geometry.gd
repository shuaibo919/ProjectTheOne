extends RefCounted
## Lightweight shopfront covers. X spans a bay, Z runs outward from the rear tie.
## Parameters arrive in integer millimetres; output remains CPU-only mesh data.
const Data := preload("res://addons/ancient_building/core/mesh_data.gd")
const Kit := preload("res://addons/ancient_building/core/mesh_kit.gd")


static func build(width: float, params: Dictionary) -> Data:
	var depth := float(params.get("depth",1300))*0.001
	var drop := float(params.get("drop",250))*0.001
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if int(params.get("covering",0)) == 1:
		_boards(st,width,depth,drop,int(params.get("seed",0)))
	elif int(params.get("edge",0))>0:
		_reed_mat(st,width,depth,drop,float(params.get("sag",60))*0.001,
			float(params.edge)*0.001,int(params.get("pattern",0)),int(params.get("seed",0)))
	else:
		_mat(st,width,depth,drop,float(params.get("sag",60))*0.001,
			int(params.get("pattern",0)),int(params.get("seed",0)))
	return Data.new(st)


static func _mat(st: SurfaceTool, width: float, depth: float, drop: float,
		sag: float, pattern: int, seed_value: int) -> void:
	var nx := clampi(ceili(width/0.035),12,110)
	var nz := clampi(ceili(depth/0.070),8,48)
	var thickness := Vector3.DOWN*0.012
	for i in nx:
		for j in nz:
			var a := _mat_point(float(i)/nx,float(j)/nz,width,depth,drop,sag,pattern,seed_value)
			var b := _mat_point(float(i+1)/nx,float(j)/nz,width,depth,drop,sag,pattern,seed_value)
			var c := _mat_point(float(i+1)/nx,float(j+1)/nz,width,depth,drop,sag,pattern,seed_value)
			var d := _mat_point(float(i)/nx,float(j+1)/nz,width,depth,drop,sag,pattern,seed_value)
			_quad(st,a,b,c,d,Vector3.UP)
			_quad(st,a+thickness,b+thickness,c+thickness,d+thickness,Vector3.DOWN)
			if i==0:
				_quad(st,a,d,d+thickness,a+thickness,Vector3.LEFT)
			if i==nx-1:
				_quad(st,b,c,c+thickness,b+thickness,Vector3.RIGHT)
			if j==0:
				_quad(st,a,b,b+thickness,a+thickness,Vector3.FORWARD)
			if j==nz-1:
				_quad(st,d,c,c+thickness,d+thickness,Vector3.BACK)


static func _mat_point(u: float, t: float, width: float, depth: float, drop: float,
		sag: float, pattern: int, seed_value: int) -> Vector3:
	var x := (u-0.5)*width
	var z := t*depth
	# Keep all four bearing edges on the pole frame. Sag occurs between supports.
	var interior := sin(PI*u)*sin(PI*t)
	var phase := float(seed_value%997)*0.171
	var reed := sin(TAU*x/0.070+phase)
	if pattern==1:
		reed = (reed+sin(TAU*z/0.140+phase*0.73))*0.5
	elif pattern==2:
		reed = sin(TAU*(x+z)/0.140+phase)*sin(TAU*(x-z)/0.140)
	var y := -drop*t-sag*interior+reed*0.0022*interior
	return Vector3(x,y,z)


## A light reed sheet bears on the frame, then extends beyond the front pole.
## The pole is an explicit station: changing sag never moves the bearing line.
static func _reed_mat(st: SurfaceTool, width: float, depth: float, drop: float,
		sag: float, edge: float, pattern: int, seed_value: int) -> void:
	var nx := clampi(ceili(width/0.045),12,100)
	var nz := clampi(ceili(depth/0.070),8,48)
	var stations := PackedFloat32Array()
	for j in range(nz+1):
		stations.append(float(j)/nz)
	# Keep the front support at exactly t=1, separate from the free overhang.
	for j in range(1,5):
		stations.append(1.0+float(j)/4.0)
	var thickness := Vector3.DOWN*0.006
	for i in nx:
		for j in range(stations.size()-1):
			var a := _reed_point(float(i)/nx,stations[j],width,depth,drop,sag,edge,pattern,seed_value)
			var b := _reed_point(float(i+1)/nx,stations[j],width,depth,drop,sag,edge,pattern,seed_value)
			var c := _reed_point(float(i+1)/nx,stations[j+1],width,depth,drop,sag,edge,pattern,seed_value)
			var d := _reed_point(float(i)/nx,stations[j+1],width,depth,drop,sag,edge,pattern,seed_value)
			_quad(st,a,b,c,d,Vector3.UP)
			_quad(st,a+thickness,b+thickness,c+thickness,d+thickness,Vector3.DOWN)
			if i==0:
				_quad(st,a,d,d+thickness,a+thickness,Vector3.LEFT)
			if i==nx-1:
				_quad(st,b,c,c+thickness,b+thickness,Vector3.RIGHT)
			if j==0:
				_quad(st,a,b,b+thickness,a+thickness,Vector3.FORWARD)
			if j==stations.size()-2:
				_quad(st,d,c,c+thickness,d+thickness,Vector3.BACK)


static func _reed_point(u: float, t: float, width: float, depth: float, drop: float,
		sag: float, edge: float, pattern: int, seed_value: int) -> Vector3:
	var x := (u-0.5)*width
	var phase := float(seed_value%997)*0.171
	if t>1.0:
		var f := t-1.0
		# A broad, coherent edge rather than a sawtooth on every vertex. The
		# support remains straight; only the exposed ends can curl and vary.
		var reach := edge*(0.94+0.06*sin(TAU*u*1.5+phase))
		var z := depth+reach*f
		var curl := edge*0.22*f*f*(0.86+0.14*sin(TAU*u+phase*0.7))
		return Vector3(x,-drop*z/depth-curl,z)
	# A wide trough between front/rear ties, gently arrested near side poles.
	# Unlike sin(pi*u)*sin(pi*t), this does not inflate each bay like a cushion.
	var edge_band := minf(0.20,width*0.14)
	var lateral := smoothstep(0.0,edge_band,u*width)*smoothstep(0.0,edge_band,(1.0-u)*width)
	var longitudinal := 4.0*t*(1.0-t)
	var coherence := 0.88+0.08*sin(TAU*u+phase)+0.04*sin(PI*t+phase*0.73)
	var reed := sin(TAU*x/0.045+phase)
	if pattern==1:
		reed = (reed+sin(TAU*t*depth/0.085+phase*0.73))*0.5
	elif pattern==2:
		reed = sin(TAU*(x+t*depth)/0.085+phase)
	var y := -drop*t-sag*longitudinal*lateral*coherence
	y += reed*0.0006*longitudinal*lateral
	return Vector3(x,y,t*depth)


static func _boards(st: SurfaceTool, width: float, depth: float, drop: float, seed_value: int) -> void:
	var count := maxi(2,roundi(width/0.15))
	var pitch := width/count
	var thickness := Vector3.DOWN*0.026
	for i in count:
		var left := -width*0.5+i*pitch+(0.003 if i>0 else 0.0)
		var right := -width*0.5+(i+1)*pitch-(0.003 if i<count-1 else 0.0)
		# The straight board bears on front and rear poles; only its exposed tip
		# varies. It must not inherit a hanging mat's flexible sag.
		var tip := 0.004+0.009*(0.5+0.5*sin(float(seed_value%997)*1.7+i*4.731))
		var a := Vector3(left,0,0)
		var b := Vector3(right,0,0)
		var c := Vector3(right,-drop*(1.0+tip/depth),depth+tip)
		var d := Vector3(left,c.y,c.z)
		_quad(st,a,b,c,d,Vector3.UP)
		_quad(st,a+thickness,b+thickness,c+thickness,d+thickness,Vector3.DOWN)
		_quad(st,a,d,d+thickness,a+thickness,Vector3.LEFT)
		_quad(st,b,c,c+thickness,b+thickness,Vector3.RIGHT)
		_quad(st,a,b,b+thickness,a+thickness,Vector3.FORWARD)
		_quad(st,d,c,c+thickness,d+thickness,Vector3.BACK)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.dot(outward)<0:
		normal = -normal
	Kit._add_tri(st,a,b,c,normal,normal,normal)
	normal = (c-a).cross(d-a).normalized()
	if normal.dot(outward)<0:
		normal = -normal
	Kit._add_tri(st,a,c,d,normal,normal,normal)
