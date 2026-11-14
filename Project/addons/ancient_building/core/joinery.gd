extends RefCounted
const Data := preload("res://addons/ancient_building/core/mesh_data.gd")
## Profiled and pierced leaf pieces. XY is the elevation, +Z faces the viewer.
const Kit := preload("res://addons/ancient_building/core/mesh_kit.gd")
const Ornament := preload("res://addons/ancient_building/core/ornament_geometry.gd")


static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func lathe(st: SurfaceTool, profile: PackedVector2Array, sides: int, center := Vector3.ZERO) -> void:
	# Profile from bottom to top: radius, height. Duplicate heights form horizontal ledges.
	for j in range(profile.size()-1):
		var low := profile[j]
		var high := profile[j+1]
		for i in sides:
			var r0 := Vector3(cos(TAU*i/sides),0,sin(TAU*i/sides))
			var r1 := Vector3(cos(TAU*(i+1)/sides),0,sin(TAU*(i+1)/sides))
			var a := center + r0*low.x + Vector3.UP*low.y
			var b := center + r1*low.x + Vector3.UP*low.y
			var c := center + r1*high.x + Vector3.UP*high.y
			var d := center + r0*high.x + Vector3.UP*high.y
			var slope := high-low
			var n0 := (r0*slope.y - Vector3.UP*slope.x).normalized()
			var n1 := (r1*slope.y - Vector3.UP*slope.x).normalized()
			Kit._add_tri(st,a,b,c,n0,n1,n1)
			Kit._add_tri(st,a,c,d,n0,n1,n0)


static func turned(profile: Array, radius: float, height: float, sides := 28) -> Data:
	var st := begin()
	var points := PackedVector2Array()
	for p in profile:
		points.append(Vector2(p[0]*radius, p[1]*height))
	lathe(st, points, sides)
	return Data.new(st)


static func panel(st: SurfaceTool, outline: PackedVector2Array, depth: float, offset := Vector3.ZERO) -> void:
	var faces := Geometry2D.triangulate_polygon(outline)
	for side in [-1,1]:
		var normal := Vector3.BACK*float(side)
		var mid := offset+normal*depth*0.5
		for i in range(0,faces.size(),3):
			var a := outline[faces[i]]
			var b := outline[faces[i+1]]
			var c := outline[faces[i+2]]
			Kit._add_tri(st,mid+Vector3(a.x,a.y,0),mid+Vector3(b.x,b.y,0),mid+Vector3(c.x,c.y,0),normal,normal,normal)
	var clockwise := Geometry2D.is_polygon_clockwise(outline)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		var edge := b-a
		var n := Vector3(edge.y,-edge.x,0).normalized() * (-1 if clockwise else 1)
		var p := offset + Vector3(a.x,a.y,-depth*0.5)
		var q := offset + Vector3(b.x,b.y,-depth*0.5)
		Kit._add_quad(st,p,q,q+Vector3.BACK*depth,p+Vector3.BACK*depth,n)


static func sweep(st: SurfaceTool, path: PackedVector3Array, radii: PackedFloat32Array, sides := 8, squash := 1.0) -> void:
	# Paths lie primarily in elevation, including the closed coils of relief work.
	var last := PackedVector3Array()
	var last_n := PackedVector3Array()
	for i in path.size():
		var tangent := (path[mini(i+1,path.size()-1)]-path[maxi(i-1,0)]).normalized()
		var up := Vector3.BACK.cross(tangent).normalized()
		var back := tangent.cross(up).normalized()
		var ring := PackedVector3Array()
		var normals := PackedVector3Array()
		for j in sides:
			var a := TAU*j/sides
			ring.append(path[i]+radii[i]*(up*cos(a)+back*sin(a)*squash))
			normals.append((up*cos(a)+back*sin(a)/squash).normalized())
		if i > 0:
			for j in sides:
				var k := (j+1)%sides
				Kit._add_tri(st,last[j],last[k],ring[k],last_n[j],last_n[k],normals[k])
				Kit._add_tri(st,last[j],ring[k],ring[j],last_n[j],normals[k],normals[j])
		last = ring
		last_n = normals


static func _scroll(st: SurfaceTool, center: Vector3, radius: float, mirror: float, start: float, turns: float, cord: float) -> void:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 26:
		var t := i/25.0
		var a := start + t*TAU*turns
		var r := radius*(1.0-0.88*t)
		path.append(center+Vector3(mirror*cos(a)*r,sin(a)*r,0))
		radii.append(cord*(1.0-0.83*t))
	sweep(st,path,radii,7,0.83)


static func hanging(width: float, height: float, pattern := 0) -> Data:
	var st := begin()
	Kit._add_box(st,Vector3(width,0.075,0.105),Vector3(0,-0.037,0))
	if pattern != 0:
		for side in [-1,1]:
			var x: float = side * width * 0.5
			var edge := PackedVector2Array([Vector2(x,0),Vector2(x-side*height*0.85,-0.075),
				Vector2(x-side*height*0.55,-height*0.4),Vector2(x,-height)])
			panel(st,edge,0.085)
		if pattern == 1:
			Kit._add_box(st,Vector3(width,0.045,0.065),Vector3(0,-height*0.84,0))
			var cells := maxi(1,roundi(width/0.48))
			var pitch := width/cells
			for i in cells:
				var x := (i+0.5)*pitch-width*0.5
				var diamond := PackedVector3Array([Vector3(x,-0.06,0),Vector3(x+pitch*0.46,-height*0.44,0),
					Vector3(x,-height*0.82,0),Vector3(x-pitch*0.46,-height*0.44,0),Vector3(x,-0.06,0)])
				sweep(st,diamond,PackedFloat32Array([0.018,0.018,0.018,0.018,0.018]),6)
		return Data.new(st)
	# Solid carved spandrels spring from the post with open ground between the lobes.
	for side in [-1,1]:
		var origin := Vector3(side*width*0.5,-0.04,0)
		var edge := PackedVector2Array()
		for uv in [[0,0],[0.85,0],[0.84,-0.10],[0.71,-0.21],[0.61,-0.23],[0.64,-0.13],[0.52,-0.19],[0.47,-0.36],[0.55,-0.43],[0.44,-0.51],[0.33,-0.47],[0.29,-0.35],[0.19,-0.46],[0.17,-0.74],[0.08,-0.89],[0,-1.03]]:
			edge.append(Vector2(-side*uv[0]*height*1.48,uv[1]*height*1.46))
		panel(st,edge,0.085,origin)
		_scroll(st,origin+Vector3(-side*height*0.29,-height*0.29,0.048),height*0.15,side,PI*0.45,1.09,0.019)
	var cells := maxi(1,roundi(width/0.58))
	var pitch := width/cells
	for i in cells:
		var x := (i+0.5)*pitch-width*0.5
		var r := minf(height*0.37,pitch*0.26)
		for side in [-1,1]:
			var center := Vector3(x+side*r,-0.06-r,0)
			_scroll(st,center,r,side,PI*0.5,1.15,0.028)
			var stem := PackedVector3Array([Vector3(x+side*pitch*0.46,-0.035,0),Vector3(x+side*pitch*0.39,-height*0.56,0),Vector3(x+side*pitch*0.23,-height*0.78,0),Vector3(x,-height*0.84,0)])
			sweep(st,stem,PackedFloat32Array([0.039,0.033,0.028,0.024]))
		Kit._add_box(st,Vector3(0.042,height*0.8,0.065),Vector3(x,-height*0.44,0))
	return Data.new(st)


static func arm(width: float, height: float, depth: float, bevel := 0.003, fork := false, fork_angle := 90) -> Data:
	return Ornament.arm(width,height,depth,bevel,fork,fork_angle)


static func block(width: float, slot := 0.16, bevel := 0.003) -> Data:
	return Ornament.block(width,slot,bevel)


static func column(radius: float, height: float, sides: int, taper: float, entasis: float) -> Data:
	var profile: Array = [[0,-0.5]]
	for i in 17:
		var t := i/16.0
		var radius_scale := 1.0-taper*t+entasis*sin(PI*t)
		profile.append([radius_scale,t-0.5])
	profile.append([0,0.5])
	return turned(profile,radius,height,sides)


static func leaf(w: float, h: float, d: float, pattern := 0, bars := 5, bar := 0.021, window := false) -> Data:
	var st := begin()
	if window:
		return window_grid(w,h,d,pattern,bars,bar)
	for side in [-1,1]:
		Kit._add_box(st,Vector3(w*0.09,h,d),Vector3(side*w*0.455,0,0))
	for y in [-0.47,-0.11,-0.055,0.36,0.47]:
		Kit._add_box(st,Vector3(w*0.84,h*0.049,d*1.12),Vector3(0,y*h,0))
	Kit._add_box(st,Vector3(w*0.82,h*0.36,d*0.62),Vector3(0,-h*0.29,-d*0.1))
	for side in [-1,1]:
		Kit._add_box(st,Vector3(w*0.036,h*0.31,d*0.86),Vector3(w*0.35*side,-h*0.29,0))
	for y in [-0.435,-0.145]:
		Kit._add_box(st,Vector3(w*0.72,h*0.018,d*0.86),Vector3(0,h*y,0))
	# Pierced upper lattice with narrow double rails and a separately framed transom.
	if pattern == 2:
		# 菱格按上下边界裁切，保持在格心内部；顶部横披仍用短直棂。
		var left := -w*0.40 + bar
		var right := w*0.40 - bar
		var low := -h*0.025
		var high := h*0.33
		var pitch := (right-left)/maxi(2,bars-1)
		for direction in [-1.0,1.0]:
			for i in range(-ceili((high-low)/pitch),bars+ceili((high-low)/pitch)):
				var start := left+i*pitch
				var t0 := maxf(0,minf((left-start)/direction,(right-start)/direction))
				var t1 := minf(high-low,maxf((left-start)/direction,(right-start)/direction))
				if t1-t0 <= bar:
					continue
				var a := Vector3(start+direction*t0,low+t0,0)
				var b := Vector3(start+direction*t1,low+t1,0)
				sweep(st,PackedVector3Array([a,b]),PackedFloat32Array([bar*0.5,bar*0.5]),4)
		for i in bars:
			var x := (float(i)/maxi(1,bars-1)-0.5)*w*0.62
			Kit._add_box(st,Vector3(bar,h*0.07,d*0.57),Vector3(x,h*0.415,0))
	else:
		for i in bars:
			var x := (float(i)/maxi(1,bars-1)-0.5)*w*0.62
			Kit._add_box(st,Vector3(bar,h*0.51,d*0.57),Vector3(x,h*0.205,0))
		var crossbars := [0.02,0.065,0.18,0.295,0.405] if pattern==0 else [0.065,0.295]
		if pattern == 3:
			crossbars = []
			var pitch := w * 0.62 / maxi(1,bars-1)
			var rows := maxi(2,roundi(h*0.51/pitch))
			for j in rows:
				crossbars.append(-0.035 + 0.51*(j+0.5)/rows)
		for y in crossbars:
			Kit._add_box(st,Vector3(w*0.83,bar,d*0.56),Vector3(0,h*y,d*0.035))
	return Data.new(st)


static func window_grid(w: float, h: float, d: float, pattern: int, bars: int, bar: float) -> Data:
	var st := begin()
	var frame := minf(0.045, w * 0.08)
	for side in [-1, 1]:
		Kit._add_box(st,Vector3(frame,h,d),Vector3(side*(w-frame)*0.5,0,0))
		Kit._add_box(st,Vector3(w-frame*2,frame,d),Vector3(0,side*(h-frame)*0.5,0))
	var inner_w := w - frame * 2
	var inner_h := h - frame * 2
	if pattern == 2:
		var pitch := inner_w / (bars + 1)
		for direction in [-1.0,1.0]:
			for i in range(-ceili(inner_h/pitch), bars+2+ceili(inner_h/pitch)):
				var x := -inner_w*0.5 + i*pitch
				var t0 := maxf(0,minf((-inner_w*0.5-x)/direction,(inner_w*0.5-x)/direction))
				var t1 := minf(inner_h,maxf((-inner_w*0.5-x)/direction,(inner_w*0.5-x)/direction))
				if t1 > t0 + bar:
					sweep(st,PackedVector3Array([Vector3(x+direction*t0,t0-inner_h*0.5,0),
						Vector3(x+direction*t1,t1-inner_h*0.5,0)]),PackedFloat32Array([bar*0.5,bar*0.5]),4)
	else:
		var count := maxi(2, roundi(inner_h / (inner_w / (bars + 1))))
		for i in bars:
			Kit._add_box(st,Vector3(bar,inner_h,d*0.60),Vector3(inner_w*((i+1.0)/(bars+1)-0.5),0,0))
		for i in count - 1:
			if pattern == 1 and i % 3 != 0:
				continue
			Kit._add_box(st,Vector3(inner_w,bar,d*0.60),Vector3(0,inner_h*((i+1.0)/count-0.5),0))
	return Data.new(st)


static func stone_post(h: float) -> Data:
	var st := begin()
	Kit._add_box(st,Vector3(0.22,0.10,0.22),Vector3.UP*0.05)
	Kit._add_box(st,Vector3(0.16,h*0.75,0.16),Vector3.UP*(0.10+h*0.375))
	var profile := PackedVector2Array()
	for p in [[0,0.78],[1,0.78],[1,0.82],[0.72,0.84],[0.68,0.87],[1,0.90],[0.95,0.94],[0.65,0.98],[0,1.06]]:
		profile.append(Vector2(p[0]*0.12,p[1]*h))
	lathe(st,profile,16)
	return Data.new(st)


static func chiwei(w: float, h: float, d: float, relief := 0.6, curl := 1.0) -> Data:
	# 鸱尾母型以整片凹曲扇面为主，羽脊是低浮雕，不堆成兽身。
	var st := begin()
	var outline := PackedVector2Array()
	for p in [[-0.43,0],[0.20,0],[0.08,0.16],[-0.05,0.30],[-0.12,0.45],[-0.10,0.60],
		[0.02,0.72],[0.27,0.77],[0.49,0.77],[0.31,0.90],[0.04,0.98],[-0.22,1.02],
		[-0.41,0.92],[-0.52,0.72],[-0.55,0.46],[-0.49,0.20]]:
		var bend := maxf(0,float(p[1])-0.45)*(curl-1.0)*0.7
		outline.append(Vector2((float(p[0])+bend)*w,(float(p[1])*0.92+0.06)*h))
	outline = _soft_outline(outline,2)
	Ornament.prism(st,outline,d*0.68,minf(h*0.014,d*0.08))
	Ornament.prism(st,PackedVector2Array([Vector2(-w*0.48,0),Vector2(w*0.23,0),
		Vector2(w*0.23,h*0.07),Vector2(-w*0.48,h*0.07)]),d*0.94,minf(h*0.01,d*0.05))
	if relief>0.001:
		for side in [-1.0,1.0]:
			for i in 13:
				var t := i/12.0
				var start := Vector3(-w*0.22,h*0.29,side*d*0.35)
				var end_y := 0.43+0.48*sin(t*PI*0.64)
				var end_x := lerpf(-0.47,0.06,t)+maxf(0,end_y-0.45)*(curl-1.0)*0.7
				var end := Vector3(end_x*w,end_y*h,side*d*0.35)
				var middle := start.lerp(end,0.50)+Vector3(-w*0.05,h*0.045,0)
				_rounded_sweep(st,PackedVector3Array([start.lerp(middle,0.35),middle,end]),
					PackedFloat32Array([h*0.008*relief,h*0.010*relief,h*0.003*relief]),6,0.75)
	return _ornament_data(st,w,h)


static func pagoda_finial(r: float, h: float) -> Data:
	var st := begin()
	var profile := PackedVector2Array([Vector2(0,0),Vector2(r,0),Vector2(r*1.2,h*0.07),
		Vector2(r*0.65,h*0.13),Vector2(r*0.42,h*0.18),Vector2(r*0.35,h*0.77),Vector2(0,h)])
	lathe(st,profile,32)
	for i in 9:
		var y := h*(0.20+i*0.065)
		var radius := r*(1.0-i*0.071)
		lathe(st,PackedVector2Array([Vector2(r*0.35,y),Vector2(radius,y+h*0.012),
			Vector2(radius,y+h*0.025),Vector2(r*0.35,y+h*0.044)]),32)
	lathe(st,PackedVector2Array([Vector2(0,h*0.79),Vector2(r*0.36,h*0.82),
		Vector2(r*0.38,h*0.87),Vector2(r*0.16,h*0.91),Vector2(0,h)]),24)
	return Data.new(st)


static func eave_cap(r: float, pattern := 0, neck_length := 0.0, neck_radius := 0.0) -> Data:
	var st := begin()
	var outline := PackedVector2Array()
	for i in 32:
		outline.append(Vector2(cos(TAU*i/32),sin(TAU*i/32))*r)
	panel(st,outline,r*0.48)
	if neck_length>0.0 and neck_radius>0.0:
		# Hollow half-cylinder connects the tile toe to the disk's back. It has
		# no end cap on either mating plane, hence no duplicated contact faces.
		var inner := maxf(neck_radius*0.65,neck_radius-0.012)
		var back := -r*0.24
		var rear := back-neck_length
		for i in 12:
			var a := Vector3(-cos(PI*i/12.0),sin(PI*i/12.0),0)
			var b := Vector3(-cos(PI*(i+1)/12.0),sin(PI*(i+1)/12.0),0)
			var normal := (a+b).normalized()
			Kit._add_quad(st,a*neck_radius+Vector3.BACK*rear,b*neck_radius+Vector3.BACK*rear,
				b*neck_radius+Vector3.BACK*back,a*neck_radius+Vector3.BACK*back,normal)
			Kit._add_quad(st,a*inner+Vector3.BACK*rear,b*inner+Vector3.BACK*rear,
				b*inner+Vector3.BACK*back,a*inner+Vector3.BACK*back,-normal)
		for side in [-1.0,1.0]:
			Kit._add_quad(st,Vector3(side*inner,0,rear),Vector3(side*neck_radius,0,rear),
				Vector3(side*neck_radius,0,back),Vector3(side*inner,0,back),Vector3.DOWN)
	var center := Vector3.BACK*(r*(0.24+0.055)+0.0015)
	var ring := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 33:
		ring.append(center+Vector3(cos(TAU*i/32),sin(TAU*i/32),0)*r*0.85)
		radii.append(r*0.055)
	sweep(st,ring,radii,6)
	if pattern == 0:
		for i in 6:
			var a := TAU*i/6
			_scroll(st,center+Vector3(cos(a),sin(a),0)*r*0.48,r*0.25,1.0,a,0.92,r*0.055)
	elif pattern == 1:
		for i in 8:
			var a := TAU*i/8
			var petal := PackedVector3Array()
			var cord := PackedFloat32Array()
			for j in 17:
				var t := TAU*j/16
				var radial := (0.43+0.28*cos(t))*r
				var tangent := sin(t)*r*0.11
				petal.append(center+Vector3(cos(a)*radial-sin(a)*tangent,sin(a)*radial+cos(a)*tangent,0))
				cord.append(r*0.04)
			sweep(st,petal,cord,6)
	else:
		var inner := PackedVector3Array()
		for point in ring:
			inner.append(center+(point-center)*0.52)
		sweep(st,inner,radii,6)
	return Data.new(st)


static func drip(w: float) -> Data:
	var st := begin()
	var outline := PackedVector2Array()
	for uv in [[-0.5,0.04],[-0.36,-0.05],[0,-0.14],[0.36,-0.05],[0.5,0.04],[0.45,-0.23],[0.32,-0.38],[0.19,-0.35],[0,-0.55],[-0.19,-0.35],[-0.32,-0.38],[-0.45,-0.23]]:
		outline.append(Vector2(uv[0]*w,uv[1]*w))
	panel(st,outline,0.032)
	for side in [-1,1]:
		_scroll(st,Vector3(side*w*0.23,-w*0.19,0.0255),w*0.12,side,0.0,0.9,0.009)
	return Data.new(st)


static func lantern(h: float) -> Data:
	var st := begin()
	var profile := PackedVector2Array()
	for p in [[0,-0.52],[0.12,-0.52],[0.12,-0.46],[0.24,-0.45],[0.24,-0.38],[0.30,-0.33],[0.36,-0.18],[0.38,0],[0.36,0.18],[0.30,0.33],[0.24,0.38],[0.24,0.45],[0.08,0.45],[0.014,0.49],[0.014,0.69],[0,0.69]]:
		profile.append(Vector2(p[0],p[1])*h)
	lathe(st,profile,48)
	for rib in 12:
		var a := TAU*rib/12
		var radial := Vector3(cos(a),0,sin(a))
		for i in range(5,10):
			var p0 := radial*profile[i].x+Vector3.UP*profile[i].y
			var p1 := radial*profile[i+1].x+Vector3.UP*profile[i+1].y
			var thickness := 0.007*h
			var tangent := Vector3(-sin(a),0,cos(a))*thickness
			Kit._add_quad(st,p0-tangent,p0+tangent,p1+tangent,p1-tangent,radial)
	lathe(st,PackedVector2Array([Vector2(0,-0.82)*h,Vector2(0.046,-0.80)*h,Vector2(0.018,-0.54)*h,Vector2(0.03,-0.51)*h]),12)
	return Data.new(st)


## 吻兽母型：卷尾躯干、张口与低浮雕分别控制，底座安装面固定在 Y=0。
static func beast(w: float, h: float, d: float, relief := 0.6, curl := 1.0) -> Data:
	var st := begin()
	var outline := PackedVector2Array()
	for p in [[-0.40,0.05],[0.34,0.05],[0.45,0.12],[0.43,0.20],[0.21,0.22],
		[0.17,0.28],[0.43,0.28],[0.50,0.34],[0.46,0.43],[0.35,0.50],[0.18,0.48],
		[0.03,0.41],[-0.11,0.46],[-0.11,0.57],[0.03,0.63],[0.19,0.72],
		[0.22,0.83],[0.17,0.94],[0.05,1.0],[-0.10,0.99],[-0.25,0.90],
		[-0.29,0.75],[-0.26,0.62],[-0.22,0.52],[-0.34,0.39],[-0.40,0.17]]:
		var bend := maxf(0,float(p[1])-0.53)*(curl-1.0)*0.55
		outline.append(Vector2((float(p[0])+bend)*w,float(p[1])*h))
	Ornament.prism(st,_soft_outline(outline,2),d*0.62,minf(d*0.12,h*0.035))
	# 低矮完整台座包住躯干根部，正脊端不再悬着一条蛇形躯干。
	Ornament.prism(st,PackedVector2Array([Vector2(-w*0.44,0),Vector2(w*0.35,0),
		Vector2(w*0.35,h*0.07),Vector2(-w*0.44,h*0.07)]),d*0.96,minf(h*0.012,d*0.05))
	for side in [-1.0,1.0]:
		var z: float = side*d*0.30
		# 鼻梁、眼眶和下颌的局部体积可从侧向读出，口腔保持真正开口。
		_bulb(st,Vector3(w*0.32,h*0.425,z*0.75),Vector3(w*0.13,h*0.070,d*0.27))
		_bulb(st,Vector3(w*0.23,h*0.48,z),Vector3(w*0.055,h*0.044,d*0.13))
		_bulb(st,Vector3(w*0.245,h*0.475,z+side*d*0.035),Vector3(w*0.025,h*0.020,d*0.12))
		var brow := PackedVector3Array([Vector3(w*0.12,h*0.48,z),Vector3(w*0.20,h*0.535,z),
			Vector3(w*0.29,h*0.53,z),Vector3(w*0.34,h*0.48,z)])
		_rounded_sweep(st,brow,PackedFloat32Array([h*0.009,h*0.022,h*0.019,h*0.003]),7,0.7)
		var horn := PackedVector3Array([Vector3(w*0.12,h*0.49,z),Vector3(w*0.10,h*0.59,z*1.2),
			Vector3(w*0.01,h*0.65,z*1.22),Vector3(-w*0.035,h*0.71,z)])
		_rounded_sweep(st,horn,PackedFloat32Array([h*0.032,h*0.022,h*0.013,h*0.001]),8,0.70)
		var jaw := PackedVector3Array([Vector3(w*0.08,h*0.18,z),Vector3(w*0.20,h*0.12,z),
			Vector3(w*0.34,h*0.15,z),Vector3(w*0.43,h*0.20,z*0.75)])
		_rounded_sweep(st,jaw,PackedFloat32Array([h*0.023,h*0.027,h*0.021,h*0.003]),7,0.85)
		if relief<=0.001:
			continue
		# 卷尾的单一连续涡线和疏密有别的躯干线，避免每处都塞同密度鳞片。
		var spiral := PackedVector3Array()
		var sizes := PackedFloat32Array()
		for i in 36:
			var t := i/35.0
			var angle := -PI*0.45+t*TAU*(0.85+0.20*curl)
			var radius := (0.16-0.135*t)*h
			spiral.append(Vector3((-0.035+(curl-1.0)*0.13)*w+cos(angle)*radius,
				0.82*h+sin(angle)*radius,z+side*d*0.024))
			sizes.append(h*(0.017-0.010*t)*relief)
		sweep(st,spiral,sizes,7,0.6)
		for i in 5:
			var line := PackedVector3Array([Vector3((-0.31+0.025*i)*w,(0.19+0.035*i)*h,z),
				Vector3((-0.24+0.025*i)*w,(0.30+0.030*i)*h,z),
				Vector3((-0.09+0.015*i)*w,(0.35+0.025*i)*h,z),
				Vector3((0.02+0.018*i)*w,(0.31+0.025*i)*h,z)])
			_rounded_sweep(st,line,PackedFloat32Array([h*0.003*relief,h*0.009*relief,
				h*0.012*relief,h*0.002*relief]),6,0.65)
		for i in 3:
			var y := h*(0.12+i*0.065)
			var center := Vector3(-w*(0.31-i*0.03),y,z)
			_scroll(st,center,h*0.04,1.0,-PI*0.2,0.78,h*0.006*relief)
	return _ornament_data(st,w,h)


static func _soft_outline(outline: PackedVector2Array, passes: int) -> PackedVector2Array:
	var result := outline
	for pass_index in passes:
		var next := PackedVector2Array()
		for i in result.size():
			var a := result[i]
			var b := result[(i+1)%result.size()]
			next.append(a.lerp(b,0.18))
			next.append(a.lerp(b,0.82))
		result = next
	return result


static func _rounded_sweep(st: SurfaceTool, path: PackedVector3Array, radii: PackedFloat32Array,
		sides: int, squash := 1.0) -> void:
	var points := PackedVector3Array()
	var sizes := PackedFloat32Array()
	for i in range(path.size()-1):
		for j in 5:
			var t := j/5.0
			points.append(path[i].cubic_interpolate(path[i+1],path[maxi(0,i-1)],
				path[mini(path.size()-1,i+2)],t))
			sizes.append(lerpf(radii[i],radii[i+1],t))
	points.append(path[-1])
	sizes.append(radii[-1])
	sweep(st,points,sizes,sides,squash)


static func _bulb(st: SurfaceTool, center: Vector3, extent: Vector3) -> void:
	for row in 8:
		var lat0 := -PI*0.5+PI*row/8.0
		var lat1 := -PI*0.5+PI*(row+1)/8.0
		for col in 12:
			var a := TAU*col/12.0
			var b := TAU*(col+1)/12.0
			var dirs := [Vector3(cos(lat0)*cos(a),sin(lat0),cos(lat0)*sin(a)),
				Vector3(cos(lat0)*cos(b),sin(lat0),cos(lat0)*sin(b)),
				Vector3(cos(lat1)*cos(b),sin(lat1),cos(lat1)*sin(b)),
				Vector3(cos(lat1)*cos(a),sin(lat1),cos(lat1)*sin(a))]
			if row>0:
				Kit._add_tri(st,center+dirs[0]*extent,center+dirs[1]*extent,center+dirs[2]*extent,
					(dirs[0]/extent).normalized(),(dirs[1]/extent).normalized(),(dirs[2]/extent).normalized())
			if row<7:
				Kit._add_tri(st,center+dirs[0]*extent,center+dirs[2]*extent,center+dirs[3]*extent,
					(dirs[0]/extent).normalized(),(dirs[2]/extent).normalized(),(dirs[3]/extent).normalized())


static func _ornament_data(st: SurfaceTool, w: float, h: float) -> Data:
	var data := Data.new(st)
	var vertices: PackedVector3Array = data.arrays[Mesh.ARRAY_VERTEX]
	var uv := PackedVector2Array()
	for p in vertices:
		uv.append(Vector2(p.x/maxf(w,0.001)+0.5,1.0-p.y/maxf(h,0.001)))
	data.arrays[Mesh.ARRAY_TEX_UV] = uv
	return data


static func post_base(radius: float, h: float) -> Data:
	var st := begin()
	Kit._add_box(st,Vector3(radius*1.94,h*0.22,radius*1.94),Vector3.UP*h*0.11)
	Kit._add_box(st,Vector3(radius*1.80,h*0.11,radius*1.80),Vector3.UP*h*0.25)
	var profile := PackedVector2Array()
	for p in [[0,0.30],[0.82,0.30],[0.88,0.36],[0.72,0.42],[0.66,0.49],[0.78,0.55],[0.86,0.64],[0.87,0.73],[0.83,0.81],[0.72,0.87],[0.70,0.92],[0.76,0.94],[0.76,1.0],[0,1.0]]:
		profile.append(Vector2(radius*p[0],h*p[1]))
	lathe(st,profile,32)
	return Data.new(st)


static func railing(width: float, h: float, style := 0) -> Data:
	var st := begin()
	if style == 1:
		Kit._add_box(st,Vector3(width,0.10,0.18),Vector3.UP*h*0.96)
		Kit._add_box(st,Vector3(width,0.08,0.14),Vector3.UP*h*0.63)
		Kit._add_box(st,Vector3(width,h*0.32,0.10),Vector3.UP*h*0.27)
		Kit._add_box(st,Vector3(width,0.09,0.17),Vector3.UP*h*0.09)
		for x in [-0.30,0.30]:
			Kit._add_box(st,Vector3(0.07,h*0.53,0.09),Vector3(x*width,h*0.67,0))
		return Data.new(st)
	Kit._add_box(st,Vector3(width,0.070,0.094),Vector3.UP*h*0.96)
	Kit._add_box(st,Vector3(width,0.045,0.058),Vector3.UP*h*0.70)
	Kit._add_box(st,Vector3(width,0.061,0.075),Vector3.UP*h*0.12)
	var count := maxi(2,roundi(width/0.15))
	for i in count:
		var x := ((i+0.5)/count-0.5)*width
		Kit._add_box(st,Vector3(0.029,h*0.82,0.037),Vector3(x,h*0.54,0))
	return Data.new(st)


static func knocker(r: float) -> Data:
	var st := begin()
	var outline := PackedVector2Array()
	for i in 16:
		var a := TAU*i/16
		var rr := r*(0.88 if i%2 else 1.15)
		outline.append(Vector2(cos(a),sin(a))*rr)
	panel(st,outline,r*0.32)
	var ring := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 25:
		var a := TAU*i/24
		ring.append(Vector3(cos(a)*r,sin(a)*r-r*0.84,r*0.46))
		radii.append(r*0.15)
	sweep(st,ring,radii,8)
	return Data.new(st)


static func pendant(height: float) -> Data:
	var st := begin()
	var outline := PackedVector2Array()
	for p in [[-0.06,0],[0.06,0],[0.05,-0.22],[0.21,-0.33],[0.10,-0.40],[0.19,-0.54],[0.10,-0.55],[0.08,-0.75],[0,-1],[-0.08,-0.75],[-0.10,-0.55],[-0.19,-0.54],[-0.10,-0.40],[-0.21,-0.33],[-0.05,-0.22]]:
		outline.append(Vector2(p[0],p[1])*height)
	panel(st,outline,height*0.11)
	for side in [-1,1]:
		_scroll(st,Vector3(side*height*0.06,-height*0.48,height*0.06),height*0.08,side,0.0,0.9,height*0.02)
	return Data.new(st)
