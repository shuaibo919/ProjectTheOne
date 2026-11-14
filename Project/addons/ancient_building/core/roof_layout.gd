extends RefCounted
## Solve roof patches once; all dependent pieces consume those eave and ridge stations.
const Geometry := preload("res://addons/ancient_building/core/roof_geometry.gd")
const Plan := preload("res://addons/ancient_building/core/plan_geometry.gd")


static func part(out: Array, id: String, pos: Vector3, params: Dictionary, width := -1.0, yaw := 0.0, pitch := 0.0) -> void:
	var row := {"id": id, "position": pos, "params": params}
	if width > 0.0:
		row.width = width
	if yaw != 0.0:
		row.rotation_y = yaw
	if pitch != 0.0:
		row.rotation_x = pitch
	out.append(row)


## Position is the tile toe at the barrel's centre height, before outward offset.
static func cap(out: Array, pos: Vector3, pitch: float, pattern: int, yaw := 0.0) -> void:
	var radius := snappedf(pitch*0.265,0.001)
	var outward := Basis(Vector3.UP,deg_to_rad(yaw))*Vector3.BACK
	part(out,"R05",pos+outward*(Geometry.CAP_BACK+radius*0.24),
		{"radius":radius,"pattern":pattern,"neck_length":Geometry.CAP_BACK,"neck_radius":pitch*0.205},-1,yaw)


static func build(out: Array, w: float, d: float, y: float, form: String, rise: float, tier: int, detail: Dictionary = {}) -> void:
	var curve := float(detail.get("roof_curve",0.52))
	var thatch: bool = detail.get("roof_covering","tile") == "thatch"
	var ridge_height := 0.28 if thatch else float(detail.get("ridge_height",0.28))
	var ridge_width := 0.29 if thatch else float(detail.get("ridge_width",0.29))
	var ridge_profile := 0 if thatch else int(detail.get("ridge_profile",0))
	var ridge_lift := 0.0 if thatch else float(detail.get("ridge_end_lift",0.0))
	var verge := 0.19 if thatch else float(detail.get("verge_width",0.19))
	var verge_height := minf(verge*0.9,maxf(0.035,ridge_height-0.06))
	var ornate: bool = tier >= 5 and detail.get("roof_covering", "tile") != "thatch"
	var ridge_w := w
	var gable_run := d*0.5
	var gable_rise := rise
	var gable_y := y
	if form in ["hip", "gable_hip"]:
		var pitch := float(detail.get("tile_pitch",0.285))
		var band := d*0.5 if form == "hip" else roundf(d*0.27/pitch)*pitch
		var split := band / (d*0.5)
		var band_rise := rise if form == "hip" else Geometry.height_at(split,2,rise,0,curve)
		var band_detail := detail.duplicate()
		if form == "gable_hip":
			band_detail.roof_curve = curve*split/(1.0-curve+curve*split)
		var lift := float(detail.get("corner_lift",0.47 if ornate else 0.29))
		skirt(out,w,d,y,band,band_rise,lift,ornate,"R07" if form=="hip" else "R08",band_detail)
		ridge_w -= 2.0*band
		gable_run -= band
		gable_rise -= band_rise
		gable_y += band_rise
		if form == "gable_hip":
			curve = curve*pow(1.0-split,2)*rise/gable_rise
	var upper_detail := detail.duplicate()
	upper_detail.roof_curve = curve
	if gable_run > 0.001:
		var gable_inset := float(detail.get("gable_inset",0.08 if form == "flush" else 0.32))
		var gable_thickness := 0.19
		# W06 is centred on the wall line and has a 190 mm section. The
		# projecting gable roof strip must not carry whole exposed eave rafters.
		# Keep their full sections inside the wall; front/back toes stay put.
		upper_detail.gable_rafter_half_span = ridge_w*0.5-gable_inset-gable_thickness*0.5-float(detail.get("gable_rafter_setback",0.02))
		for sign_z in [-1.0,1.0]:
			var yaw := 0.0 if sign_z > 0 else 180.0
			_face(out,ridge_w,gable_run,0,gable_rise,0,Vector3(0,gable_y,sign_z*gable_run),yaw,form != "gable_hip",upper_detail)
		for side in [-1.0,1.0]:
			var inset := gable_inset
			if form=="overhang" and int(detail.get("eave_style",0))==0:
				part(out,"R15",Vector3(side*(ridge_w*0.5-0.11),gable_y+gable_rise-0.13,0),{"height":0.63},-1,side*90)
			part(out,"W06",Vector3(side*(ridge_w*0.5-inset),gable_y-0.06,0),{"rise":gable_rise,"curve":curve,"thickness":gable_thickness},gable_run*2.0,side*90.0)
			if int(detail.get("gable_finish",0)) == 1:
				out.back().material_set = "M_Plaster"
			var edge := Vector3(side*(ridge_w*0.5-0.065),gable_y+0.065,gable_run)
			part(out,"R07",edge,{"run":gable_run,"rise":gable_rise,"curve":curve,"thickness":verge,"height":verge_height,"foot_width":maxf(0.19,verge),"profile":mini(ridge_profile,2),"paired":1},gable_run)

	var top := y+rise
	part(out,"R06",Vector3(0,top+0.035,0),{"height":ridge_height,"thickness":ridge_width,"overhang":0,
		"joint_spacing":0.0 if thatch else float(detail.get("ridge_joint_spacing",0.40)),"covering":int(thatch),"profile":ridge_profile,"end_lift":ridge_lift,"foot_width":maxf(0.29,ridge_width)},ridge_w)
	var ornament := int(detail.get("ridge_ornament",0))
	if ornate and tier >= 7 and ornament == 0 or ornament in [2,3] and detail.get("roof_covering","tile") != "thatch":
		for side in [-1,1]:
			part(out,"R11",Vector3(side*(ridge_w*0.5-0.34),top+ridge_height-0.06+ridge_lift*pow(maxf(0,1.0-0.68/maxf(ridge_w,0.68)),6.0),0),{"width":0.85*float(detail.get("ornament_scale",1.0)),"height":0.95*float(detail.get("ornament_scale",1.0)),"depth":0.24,"style":int(ornament==3)},-1,180.0 if side<0 else 0.0)


static func skirt(out: Array, w: float, d: float, y: float, run: float, rise: float, lift: float, ornate: bool, seam_id := "R08", detail: Dictionary = {}) -> void:
	var curve := float(detail.get("roof_curve",0.52))
	var thatch: bool = detail.get("roof_covering","tile") == "thatch"
	var verge := 0.19 if thatch else float(detail.get("verge_width",0.19))
	var main_height := 0.28 if thatch else float(detail.get("ridge_height",0.28))
	var seam_height := minf(verge*(0.216/0.19),maxf(0.035,main_height-0.06))
	var profile := 0 if thatch else mini(int(detail.get("ridge_profile",0)),2)
	for i in 4:
		var yaw := i*90.0
		var span := w if i%2 == 0 else d
		var half_depth := d*0.5 if i%2 == 0 else w*0.5
		var basis := Basis(Vector3.UP,deg_to_rad(yaw))
		var org := Vector3.UP*y + basis*Vector3.BACK*half_depth
		if i != 0 or not detail.get("entry_cut",false):
			_face(out,span,run,run,rise,lift,org,yaw,true,detail)
		# Each corner belongs to exactly one outgoing face.
		var corner := org+basis*Vector3(span*0.5,0.04,0)
		part(out,seam_id,corner,{"run":run,"rise":rise,"inset":run,"lift":lift,"curve":curve,"thickness":verge*(0.24/0.19),
			"height":seam_height,"foot_width":0.24,"profile":profile},run,yaw)
		if ornate:
			for t in [0.15,0.30]:
				var anchor := corner+basis*Vector3(-run*t,Geometry.height_at(t,run*t,rise,lift,curve)+seam_height*(0.19/0.216),-run*t)
				part(out,"R12",anchor,{"width":0.32,"height":0.28,"depth":0.14},-1,yaw-45.0)


static func _face(out: Array, span: float, run: float, inset: float, rise: float, lift: float, org: Vector3, yaw: float, eaves: bool, detail: Dictionary = {}) -> void:
	var basis := Basis(Vector3.UP,deg_to_rad(yaw))
	var curve := float(detail.get("roof_curve",0.52))
	part(out,"R01",org,{"patch":1,"depth":run,"rise":rise,"inset":inset,"lift":lift,"curve":curve,"overhang":0},span,yaw)
	var thatch: bool = detail.get("roof_covering", "tile") == "thatch"
	if thatch:
		part(out,"R01",org,{"patch":1,"depth":run,"rise":rise,"inset":inset,"lift":lift,
			"overhang":0,"covering":1,"curve":curve, "straw_depth":detail.get("thatch_thickness",0.24),
			"bundle":detail.get("thatch_bundle",0.16),"ragged":detail.get("thatch_raggedness",0.6),"straw_seed":detail.get("seed",0)},span,yaw)
	if thatch and int(detail.get("thatch_rods",1)) == 1:
		for t in [0.18,0.52,0.86]:
			var pt := org+basis*Vector3(0,Geometry.height_at(t,span*0.5,rise,lift,curve)+float(detail.get("thatch_thickness",0.24))+0.045,-run*t)
			part(out,"F05",pt,{"radius":0.035,"sides":10},span-2*inset*t,yaw)
	var pitch := float(detail.get("tile_pitch",0.285))
	var tile_pattern := int(detail.get("tile_pattern",0))
	var plain_eave := int(detail.get("eave_style",0))==1
	var count := ceili(span/pitch)
	var reach := maxf(1.35 if lift>0 else 0.0,inset)+pitch
	if not thatch:
		for i in count:
			var x := pitch*(i+0.5-count*0.5)
			var left := span*0.5+x
			var right := span*0.5-x
			var pos := org+basis*Vector3.RIGHT*x
			var params := {"pitch":pitch,"length":run,"rise":rise,"lift":lift,"curve":curve,"inset":inset,"left":minf(left,reach),"right":minf(right,reach),"radius":pitch*0.205,"pattern":tile_pattern}
			part(out,"R03",pos,params,-1,yaw)
			if eaves and tile_pattern==0 and minf(left,right) >= pitch*0.265+Geometry.CORNER_CLEARANCE:
				var y := Geometry.height_at(0,minf(left,right),rise,lift,curve)
				cap(out,pos+basis*Vector3.UP*(y+Geometry.CAP_BASE),pitch,int(detail.get("cap_pattern",0)),yaw)
			if eaves and tile_pattern==0 and i+1 < count and minf(left+pitch*0.5,right-pitch*0.5) >= pitch*0.46+Geometry.CORNER_CLEARANCE:
				var end_y := Geometry.height_at(0,minf(left+pitch*0.5,right-pitch*0.5),rise,lift,curve)
				part(out,"R04",pos+basis*Vector3(pitch*0.5,end_y+0.04,0.038),{"width":pitch*0.92,"pattern":int(plain_eave)},-1,yaw)
	if not eaves:
		return
	# Eave and flying rafters have independent spacing from the tile courses.
	var boards := ceili(span/0.54)
	for j in boards:
		var x0 := (float(j)/boards-0.5)*span
		var x1 := (float(j+1)/boards-0.5)*span
		var center := (x0+x1)*0.5
		var points := PackedVector3Array()
		for station in 5:
			for z in [Geometry.FASCIA_FRONT,Geometry.FASCIA_FRONT-Geometry.FASCIA_DEPTH]:
				# Vertical cut planes at straight joints; a shared diagonal cut at
				# hip corners. No rotated boxes or overlapping length extensions.
				var left: float = x0+0.0025 if j>0 else x0-z if inset>0 else x0
				var right: float = x1-0.0025 if j<boards-1 else x1+z if inset>0 else x1
				var x := lerpf(left,right,station/4.0)
				var height := Geometry.height_at(0,span*0.5-absf(x),rise,lift,curve)-Geometry.FASCIA_TOP_RECESS
				points.append(Vector3(x-center,height,z))
		part(out,"F14",org+basis*Vector3.RIGHT*center,{"length":x1-x0,"height":0.095},-1,yaw)
		out.back().geometry = {"kind":"fascia","points":Plan.encode(points)}
	var n := maxi(2,roundi(span/float(detail.get("rafter_spacing",0.32))))
	var rafter_radius := float(detail.get("rafter_radius",0.068))
	var fly_width := clampf(rafter_radius*1.35,0.05,0.094) if plain_eave else 0.094
	var fly_height := clampf(rafter_radius*1.15,0.04,0.082) if plain_eave else 0.082
	# A smaller section keeps its bearing face, rather than floating between
	# the old section centres. Preserve the established positions by default.
	var rafter_y := -0.137-rafter_radius if plain_eave else -0.205
	var fly_y := -0.152+fly_height*0.5 if plain_eave else -0.111
	var gable_limit := -1.0
	if detail.has("gable_rafter_half_span"):
		gable_limit = maxf(0.01,float(detail.gable_rafter_half_span)-maxf(rafter_radius,fly_width*0.5))
		n = maxi(2,ceili(gable_limit*2.0/float(detail.get("rafter_spacing",0.32)))+1)
	for i in n:
		var x := (i+0.5)*span/n-span*0.5
		if gable_limit >= 0.0:
			x = lerpf(-gable_limit,gable_limit,float(i)/(n-1))
		var dist := span*0.5-absf(x)
		var t_end := minf(1.0,1.32/run)
		if inset > 0:
			t_end = minf(t_end,dist/inset)
		var toe := Vector3(x,Geometry.height_at(0,dist,rise,lift,curve),0)
		var head := Vector3(x,Geometry.height_at(t_end,dist,rise,lift,curve),-t_end*run)
		var length := head.distance_to(toe)
		var angle := rad_to_deg(atan2(head.y-toe.y,toe.z-head.z))
		var middle := (head+toe)*0.5
		part(out,"F11",org+basis*(middle+Vector3(0,rafter_y,-0.22)),
			{"radius":rafter_radius,"length":length,"sides":14},-1,yaw,angle)
		var fly_len := minf(length,0.76)
		var fly_mid := toe+toe.direction_to(head)*fly_len*0.5+Vector3(0,fly_y,0.057)
		part(out,"F12",org+basis*fly_mid,{"length":fly_len,"width":fly_width,"height":fly_height},-1,yaw,angle)
