extends RefCounted
## Bay grid and vertical datums in metres. All output is ordinary catalogue placements.
const Facade := preload("res://addons/ancient_building/core/facade_layout.gd")
const Terrace := preload("res://addons/ancient_building/core/terrace_layout.gd")
const Awning := preload("res://addons/ancient_building/core/awning_layout.gd")
const Plan := preload("res://addons/ancient_building/core/plan_geometry.gd")
const Geometry := preload("res://addons/ancient_building/core/roof_geometry.gd")
const Roof := preload("res://addons/ancient_building/core/roof_layout.gd")
const Variation := preload("res://addons/ancient_building/core/building_variation.gd")
const Shell := preload("res://addons/ancient_building/core/building_shell.gd")
const Tower := preload("res://addons/ancient_building/core/tower_recipe.gd")
const Compound := preload("res://addons/ancient_building/core/compound_recipe.gd")

const FORMS := ["flush","overhang","hip","gable_hip"]
const USES := ["house","shop","gate","hall"]


static func assemble(spec: Dictionary, session: Dictionary = {}) -> Dictionary:
	var mode := String(spec.get("mode", "rect"))
	var construction := String(spec.get("construction", "frame"))
	var covering := String(spec.get("roof_covering", "tile"))
	if mode not in ["rect", "tower", "compound"] or construction not in ["frame", "earth", "timber", "log"]:
		return {"error":"unsupported building mode or construction"}
	if covering not in ["tile", "thatch"]:
		return {"error":"roof_covering must be tile or thatch"}
	var variation := Variation.resolve(spec)
	if not String(variation.get("error", "")).is_empty():
		return {"error":variation.error}
	var detail: Dictionary = variation.values
	detail.roof_covering = covering
	detail.seed = int(spec.get("variation",{}).get("seed",0))
	if mode != "rect":
		var result := Tower.assemble(spec, detail) if mode == "tower" else Compound.assemble(spec, detail, session)
		if not result.has("error"):
			_component_details(result.placements,detail)
			Shell.finish(result.placements, spec, detail)
		return result
	var use := String(spec.get("usage","house"))
	var form := String(spec.get("roof_form","overhang"))
	if use not in USES or form not in FORMS:
		return {"error":"unsupported usage/roof_form: %s/%s" % [use,form]}
	var bays := int(spec.get("bays",3))
	var bay := float(spec.get("bay_width",2.7))
	var depth := float(spec.get("depth",4.6))
	var floors := int(spec.get("storeys",1))
	if int(detail.entry_roof) == 1 and (floors < 2 or covering != "tile"):
		return {"error":"中央抱厦需要至少两层的瓦顶建筑；请关闭抱厦，或选择两层及以上、瓦屋面"}
	if int(detail.entry_roof)==1 and int(detail.get("tile_pattern",0))!=0:
		return {"error":"抱厦裁切目前仅支持筒板瓦；请将铺瓦纹路设为筒板瓦，或关闭中央抱厦"}
	if bays not in [1,3,5,7] or bay < 2 or bay > 3.6 or depth < 3 or depth > 7 or floors < 1 or floors > 8:
		return {"error":"expected 1/3/5/7 bays, 2–3.6 m per bay, depth 3–7 m and 1–8 storeys"}
	var setback := float(spec.get("setback", 0.53 if floors == 2 else 0.15))
	if not is_finite(setback) or setback < 0 or setback > 0.6 or depth - 2.0 * setback * (floors - 1) < 1.8:
		return {"error":"层间收进过大：顶层进深至少需要 1.8 m；请减小收进或层数"}
	var w := bays*bay
	if form in ["hip","gable_hip"] and w <= depth+0.5:
		return {"error":"当前庑殿/歇山要求总面阔 > 进深 + 0.5 m；请增加开间数/面阔，或减小进深"}
	var profile: Variant = spec.get("style_profile", {})
	if not profile is Dictionary:
		return {"error":"style_profile must be an object"}
	var tier := int({"flush":3,"overhang":4,"gable_hip":5,"hip":6}[form])
	if floors >= 2 and tier >= 5:
		tier += 2
	if int(profile.get("building_tier",0)) not in [0,tier]:
		return {"error":"%s with %d storey(s) requires building_tier %d" % [form,floors,tier]}
	var out: Array = []
	var base := float(detail.base_height)
	var ornate := use in ["hall","gate"]
	var floor_h := float(detail.floor_height)
	var radius := float(detail.column_radius)
	var margin := float(detail.platform_margin)
	var platform_width := w+2.0*(margin+0.05)
	var platform_depth := depth+2.0*margin+float(detail.entry_projection)*int(detail.entry_roof)*2.0
	Roof.part(out,"B01",Vector3.UP*base*0.5,{"height":base,"depth":platform_depth},platform_width)
	for side in [-1,1]:
		var edge_height := minf(0.18,base)
		Roof.part(out,"B02",Vector3(0,base-edge_height*0.5,side*platform_depth*0.5),{"height":edge_height},platform_width+0.02)
		Roof.part(out,"B02",Vector3(side*platform_width*0.5,base-edge_height*0.5,0),{"height":edge_height},platform_depth,90.0)
	var nsteps := maxi(1,roundi(base/0.15))
	var steps_depth := nsteps*0.30
	Roof.part(out,"B04",Vector3(0,0,platform_depth*0.5+steps_depth*0.5),{"height":base,"depth":steps_depth,"steps":nsteps},bay*0.86)
	if use == "gate":
		Roof.part(out,"B04",Vector3(0,0,-platform_depth*0.5-steps_depth*0.5),{"height":base,"depth":steps_depth,"steps":nsteps},bay*0.86,180.0)
	var platform := PackedVector2Array([Vector2(-platform_width*0.5,-platform_depth*0.5),Vector2(platform_width*0.5,-platform_depth*0.5),Vector2(platform_width*0.5,platform_depth*0.5),Vector2(-platform_width*0.5,platform_depth*0.5)])
	if int(detail.platform_paving) == 1:
		Terrace.paving(out,platform,base+0.015,float(detail.paving_size))
	if int(detail.railing_style) > 0:
		for i in 4:
			if i == 2 or (use == "gate" and i == 0):
				var z := platform[i].y
				Terrace.rail(out,Vector2(-platform_width*0.5+0.12,z),Vector2(-bay*0.46,z),base,detail)
				Terrace.rail(out,Vector2(bay*0.46,z),Vector2(platform_width*0.5-0.12,z),base,detail)
			else:
				Terrace.rail(out,platform[i],platform[(i+1)%4],base,detail)
	var level := base
	var story_w := w
	var story_d := depth
	for floor_index in floors:
		var column_h := floor_h if floor_index == 0 else floor_h*0.81
		var beam_y := level+column_h
		var deck_y := beam_y+(0.09+Terrace.bracket_height()+0.159 if int(detail.bracket_style)==0 else 0.28)
		var front_wall := story_d*0.5 - float(detail.porch_depth if floor_index==0 else detail.upper_porch_depth)
		var enclosed_depth := story_d*0.5+front_wall
		var attic_h := deck_y-beam_y+0.10
		for z in [front_wall,-story_d*0.5]:
			Roof.part(out,"F02",Vector3(0,beam_y+attic_h*0.5,z),{"height":attic_h,"depth":0.20},story_w)
		for side in [-1,1]:
			Roof.part(out,"F02",Vector3(side*story_w*0.5,beam_y+attic_h*0.5,(front_wall-story_d*0.5)*0.5),{"height":attic_h,"depth":0.20},enclosed_depth,90)
		Roof.part(out,"F13",Vector3(0,deck_y+0.17,(front_wall-story_d*0.5)*0.5),{"thickness":0.07,"length":enclosed_depth},story_w)
		if floor_index>0 and int(detail.facade_style) == 0:
			_gallery(out,bays,story_w,story_d,level)
		_walls(out,use,bays,story_w,story_d,level,column_h,floor_index,detail,construction)
		for i in range(bays+1):
			var x := story_w*(float(i)/bays-0.5)
			for side in [-1.0,1.0]:
				var z: float = side*story_d*0.5
				# 石柱础只落在首层台基；上层柱脚直接落在木楼板完成面。
				var foot := float(detail.column_base_height) if floor_index==0 else 0.0
				if floor_index == 0:
					Roof.part(out,"B12",Vector3(x,level,z),{"radius":radius*1.68,"height":foot})
				Roof.part(out,"F01",Vector3(x,level+foot+(column_h-foot)*0.5,z),{"radius":radius,"height":column_h-foot,"sides":28})
				if int(detail.bracket_style) == 0:
					var role := 2 if i==0 or i==bays else 0
					var hand: float = (1.0 if i==bays else -1.0)*side
					_bracket(out,Vector3(x,beam_y+0.09,z),0.0 if side>0 else 180.0,ornate,detail,role,hand)
				else:
					Roof.part(out,"F08",Vector3(x,beam_y,z),{"width":0.28})
			Roof.part(out,"F04",Vector3(x,beam_y-0.12,0),{"height":0.24,"depth":0.22},story_d,90.0)
		for side in [-1.0,1.0]:
			var z: float = side*story_d*0.5
			Roof.part(out,"F02",Vector3(0,beam_y,z),{"height":0.24,"depth":0.26},story_w+0.42)
			Roof.part(out,"F05",Vector3(0,deck_y-0.04,z+side*0.32),{"radius":0.119,"sides":14},story_w+0.64)
		for i in bays:
			var x := story_w*((i+0.5)/bays-0.5)
			if int(detail.bracket_style)==0 and int(detail.bracket_density)==1:
				for side in [-1.0,1.0]:
					_bracket(out,Vector3(x,beam_y+0.09,side*story_d*0.5),
						0.0 if side>0 else 180.0,ornate,detail,1)
			if int(detail.hangings) == 1:
				Roof.part(out,"O11",Vector3(x,beam_y-0.13,story_d*0.5),
					{"height":detail.hanging_height,"pattern":detail.hanging_style},story_w/bays-radius*1.6)
			if floor_index==0 and int(detail.lanterns)==1 and (i!=floori(bays*0.5) or bays==1):
				Roof.part(out,"D03",Vector3(x,beam_y-0.70,story_d*0.5+0.19),{"height":0.65})
		if floor_index == 0 and use != "house" and int(detail.facade_style)!=3:
			Roof.part(out,"D01",Vector3(0,beam_y-0.22,story_d*0.5+0.14),{"width":1.62 if use=="hall" else 1.18,"height":0.34,"depth":0.08,"frame":0.045})
		var eave := float(detail.eave_depth)
		var roof_width := story_w+2.0*(0.13 if form=="flush" else eave)
		var roof_depth := story_d+2.0*eave
		if floor_index+1 < floors:
			var skirt_lift := float(detail.corner_lift) * (0.29 / 0.47)
			var waist_detail := detail.duplicate()
			waist_detail.entry_cut = floor_index == 0 and int(detail.entry_roof) == 1 and covering == "tile"
			Roof.skirt(out,story_w+2.0*eave,roof_depth,deck_y,eave+setback,0.66,skirt_lift,tier>=7 and covering != "thatch","R08",waist_detail)
			if waist_detail.entry_cut:
				_entry_roof(out,story_w+2.0*eave,roof_depth,deck_y,eave+setback,0.66,skirt_lift,bay,detail)
			story_w -= 2.0*setback
			story_d -= 2.0*setback
			# Clear the complete covering with the underside of the upper floor.
			var cover_top := 0.135+float(detail.tile_pitch)*0.205
			if covering == "thatch":
				cover_top = float(detail.thatch_thickness)*0.80+0.06
			level = deck_y+maxf(0.76,0.66+cover_top+0.17+0.025)
			Roof.part(out,"F13",Vector3(0,level-0.085,0),{"thickness":0.17,"length":story_d+0.42},story_w+0.42)
		else:
			var top_detail := detail.duplicate()
			top_detail.gable_inset = eave if form == "overhang" else 0.08
			Roof.build(out,roof_width,roof_depth,deck_y,form,roof_depth*float(detail.roof_rise_ratio),tier,top_detail)
	var finish := String(spec.get("material_set","M_AgedTimber"))
	if finish not in ["M_AgedTimber","M_RedLacquer","M_Default"]:
		return {"error":"unknown building material_set: "+finish}
	for row in out:
		if not row.has("material_set"):
			row.material_set = finish
		if construction != "frame" and row.id == "W01" and not row.has("geometry"):
			row.params.wall_kind = {"earth":1, "timber":2, "log":3}[construction]
			row.params.thickness = detail.log_diameter if construction == "log" else detail.wall_thickness
			row.params.board_width = detail.board_width
			row.params.log_diameter = detail.log_diameter
			row.material_set = {"earth":"M_Earth", "timber":"M_Planks", "log":"M_Log"}[construction]
		if construction in ["timber", "log"] and row.id in ["W02", "O05"]:
			row.material_set = "M_Timber"
		if covering == "thatch" and (row.id in ["R06", "R07", "R08"] or int(row.params.get("covering", 0)) == 1):
			row.material_set = "M_Thatch"
	Awning.build(out,w,depth,base,bays,detail,int(detail.seed))
	_component_details(out,detail)
	Shell.finish(out, spec, detail)
	return {"placements":out}


static func _entry_roof(out: Array, w: float, d: float, y: float, run: float, rise: float,
		lift: float, bay: float, detail: Dictionary) -> void:
	var faces: Array = []
	var curve := float(detail.roof_curve)
	var columns := maxi(4,ceili(w/1.3))
	# 腰檐和抱厦全部进入同一可见上包络；不叠放两张完整屋面。
	for row in 8:
		var t0 := row/8.0
		var t1 := (row+1)/8.0
		for col in columns:
			var u := col*2.0/columns-1.0
			var v := (col+1)*2.0/columns-1.0
			var origin := Vector3(0,y,d*0.5)
			var a := origin+Geometry._face_point(u,t0,w*0.5,run,run,rise,lift,curve)
			var b := origin+Geometry._face_point(v,t0,w*0.5,run,run,rise,lift,curve)
			var c := origin+Geometry._face_point(v,t1,w*0.5,run,run,rise,lift,curve)
			var e := origin+Geometry._face_point(u,t1,w*0.5,run,run,rise,lift,curve)
			_add_face(faces,a,b,c,e,0,Vector2.LEFT,detail)
	var half := bay*0.58
	var front := d*0.5+float(detail.entry_projection)
	var back := d*0.5-run
	var entry_rise := float(detail.entry_rise)
	for side in [-1.0,1.0]:
		for row in 8:
			var t0 := row/8.0
			var t1 := (row+1)/8.0
			var x0: float = side*half*(1.0-t0)
			var x1: float = side*half*(1.0-t1)
			var y0 := y+Geometry.height_at(t0,2,entry_rise,0,curve)
			var y1 := y+Geometry.height_at(t1,2,entry_rise,0,curve)
			_add_face(faces,Vector3(x0,y0,front),Vector3(x0,y0,back),Vector3(x1,y1,back),
				Vector3(x1,y1,front),1,Vector2(0,side),detail)
	Shell.emit_roofs(out,faces)
	Shell.join_seams(out,faces)
	Shell.exposed_line(out,"R06",Vector3(0,y+entry_rise+0.06,front),Vector3(0,y+entry_rise+0.06,back),faces,
		"ridge",{"breadth":250,"height":210,"joint_spacing":roundi(float(detail.get("ridge_joint_spacing",0.40))*1000.0)})
	Roof.part(out,"W06",Vector3(0,y-0.025,front-0.16),{"rise":entry_rise,"thickness":0.12,"curve":curve},half*2)
	Roof.part(out,"R07",Vector3(-half,y+0.05,front),{"run":half,"rise":entry_rise,"paired":1,"curve":curve,"thickness":0.19},half,-90)
	Roof.part(out,"F02",Vector3(0,y-0.13,front-0.19),{"height":0.22,"depth":0.22},half*2)
	var posts_z := front-float(detail.eave_depth)-0.12
	for side in [-1,1]:
		var x: float = side*(half-0.28)
		Shell.post(out,Vector2(x,posts_z),float(detail.base_height),y-0.55,float(detail.column_radius)*0.85,true)
		Terrace.bracket(out,Vector3(x,y-0.55,posts_z),0)
		var pitch := float(detail.tile_pitch)
		var margin := pitch*0.265+Geometry.CORNER_CLEARANCE
		# Only the exposed projecting eave owns caps; the buried return under
		# the waist roof has no second row of visible circular end faces.
		for i in range(ceili((d*0.5+margin)/pitch-0.5),floori((front-margin)/pitch-0.5)+1):
			var z := (i+0.5)*pitch
			var lap := (1.0-clampf((fposmod(-half,0.32)+0.018)/0.32,0,1))*0.022
			Roof.cap(out,Vector3(side*half,y+0.035+Geometry.CAP_BASE+lap,z),pitch,int(detail.cap_pattern),side*90)
	var pitch := float(detail.tile_pitch)
	var margin := pitch*0.265+Geometry.CORNER_CLEARANCE
	for side in [-1,1]:
		for i in range(ceili((half+margin)/pitch-0.5),floori((w*0.5-margin)/pitch-0.5)+1):
			var x: float = side*(i+0.5)*pitch
			var edge_y := y+Geometry.height_at(0,w*0.5-absf(x),rise,lift,curve)
			var lap := (1.0-clampf((fposmod(-d*0.5,0.32)+0.018)/0.32,0,1))*0.022
			Roof.cap(out,Vector3(x,edge_y+0.035+Geometry.CAP_BASE+lap,d*0.5),pitch,int(detail.cap_pattern))



static func _add_face(faces: Array,a: Vector3,b: Vector3,c: Vector3,d: Vector3,owner: int,direction: Vector2,detail: Dictionary) -> void:
	var poly := Plan.clean(PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z),Vector2(d.x,d.z)]))
	if not poly.is_empty():
		faces.append(Shell.face(poly,Plan.plane(a,b,c),owner,direction,"tile",float(detail.tile_pitch)))


static func _bracket(out: Array, foot: Vector3, yaw: float, ornate: bool,
		detail: Dictionary, role := 0, corner_hand := 1.0) -> void:
	Terrace.bracket(out,foot,yaw,float(detail.bracket_projection),role,ornate,corner_hand)


static func _component_details(out: Array, detail: Dictionary) -> void:
	for row in out:
		if not row.has("params"):
			row.params = {}
		if row.id in ["F02","F04","F08","F09","F10"]:
			row.params.bevel = float(detail.joinery_bevel)
		elif row.id=="F01":
			row.params.entasis = float(detail.column_entasis)
			row.params.taper = float(detail.column_taper)
		elif row.id in ["R11","R12"]:
			row.params.relief = float(detail.ornament_relief)
			row.params.curl = float(detail.ornament_curl)


static func _walls(out: Array, use: String, bays: int, w: float, d: float, base: float, h: float, floor_index: int, detail: Dictionary, construction: String) -> void:
	var bay := w/bays
	if int(detail.facade_style) > 0:
		var front_z := d*0.5-float(detail.porch_depth if floor_index==0 else detail.upper_porch_depth)
		var front_style := int(detail.facade_style) if floor_index == 0 else 1
		Facade.elevation(out,Vector2(w*0.5,front_z),Vector2(-w*0.5,front_z),base,h,bays,front_style,construction,detail,floor_index==0)
		Facade.elevation(out,Vector2(-w*0.5,-d*0.5),Vector2(w*0.5,-d*0.5),base,h,bays,0,construction,detail)
		var side_bays := maxi(1,roundi((front_z+d*0.5)/2.0))
		Facade.elevation(out,Vector2(w*0.5,-d*0.5),Vector2(w*0.5,front_z),base,h,side_bays,int(detail.side_windows),construction,detail)
		Facade.elevation(out,Vector2(-w*0.5,front_z),Vector2(-w*0.5,-d*0.5),base,h,side_bays,int(detail.side_windows),construction,detail)
		return
	var front := d*0.5 - float(detail.porch_depth if floor_index==0 else detail.upper_porch_depth)
	var back := -d*0.5
	for side in [-1.0,1.0]:
		var x: float = w*0.5*side
		Roof.part(out,"W01",Vector3(x,base+h*0.5,(front+back)*0.5),{"height":h,"thickness":0.19},front-back,90)
		Roof.part(out,"W02",Vector3(x,base+0.22,(front+back)*0.5),{"height":0.44},front-back,90)
	for i in bays:
		var x := (i+0.5)*bay-w*0.5
		var central := i == floori(bays*0.5)
		var pass_through := use=="gate" and central and floor_index==0
		if not pass_through:
			Roof.part(out,"W01",Vector3(x,base+h*0.5,back),{"height":h,"thickness":0.19},bay)
		var frame_height := h*0.81
		Roof.part(out,"F02",Vector3(x,base+frame_height+(h-frame_height)*0.5,front),{"height":h-frame_height,"depth":0.21},bay)
		if pass_through or (central and use=="shop" and floor_index==0):
			Roof.part(out,"O01",Vector3(x,base+frame_height*0.5,front),{"width":bay-0.12,"height":frame_height,"depth":0.22,"frame":0.11})
			continue
		var is_door := central and floor_index==0
		var sill := 0.09 if is_door else frame_height*0.28
		if not is_door:
			Roof.part(out,"W02",Vector3(x,base+sill*0.5,front),{"height":sill},bay)
		var available := bay-0.13
		var leaves := maxi(2,roundi(available/0.58))
		var leaf_w := available/leaves
		for j in leaves:
			Roof.part(out,"O02",Vector3(x+(j+0.5-leaves*0.5)*leaf_w,base+(sill+frame_height)*0.5,front),
				{"width":leaf_w-0.008,"height":frame_height-sill,"thickness":0.062,
				"pattern":detail.lattice_style,"bars":detail.lattice_bars,"bar":detail.lattice_bar})
		if is_door:
			for side in [-1,1]:
				Roof.part(out,"O04",Vector3(x+side*leaf_w*0.19,base+frame_height*0.44,front+0.043),{"radius":0.060})
		Roof.part(out,"O05",Vector3(x,base+sill+0.025,front),{"height":0.07,"depth":0.23},bay)
		Roof.part(out,"F01",Vector3(x-bay*0.5+0.026,base+frame_height*0.5,front),{"height":frame_height,"radius":0.075,"sides":16})


static func _gallery(out: Array, bays: int, width: float, depth: float, y: float) -> void:
	var bay := width/bays
	for i in bays:
		var x := (i+0.5)*bay-width*0.5
		var length := bay-0.24
		var segments := ceili(length/0.88)
		for k in segments:
			var cx := x+((k+0.5)/segments-0.5)*length
			Roof.part(out,"B10",Vector3(cx,y,depth*0.5),{"width":length/segments,"height":0.72})
		Roof.part(out,"B09",Vector3(x,y,depth*0.5),{"height":0.82})
