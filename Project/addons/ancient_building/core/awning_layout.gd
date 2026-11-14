extends RefCounted
## A separate light shopfront structure, carried by poles or wall braces.
const Roof := preload("res://addons/ancient_building/core/roof_layout.gd")


static func build(out: Array, w: float, d: float, base_y: float, bay_count: int,
		detail: Dictionary, seed_value: int) -> void:
	var style := int(detail.get("awning_style",0))
	if style==0:
		return
	var requested := int(detail.get("awning_bays",0))
	var bays := bay_count if requested==0 else mini(requested,bay_count)
	var bay := w/bay_count
	var span := bays*bay
	var projection := float(detail.get("awning_projection",1.3))
	var drop := float(detail.get("awning_drop",0.25))
	var back_y := base_y+float(detail.get("awning_height",2.5))
	var back_z := d*0.5-0.06
	var front_z := back_z+projection
	var front_y := back_y-drop
	var pattern := int(detail.get("awning_pattern",0))
	var support := int(detail.get("awning_support",0))
	var edge := float(detail.get("awning_edge",0.0)) if style==1 else 0.0
	var light_mat := edge>0.0
	var sheet_thickness := 0.006 if light_mat else 0.012
	var cross_radius := 0.028 if light_mat else 0.035
	var cross_offset := sheet_thickness+cross_radius if light_mat else 0.045
	var pole_z := front_z if light_mat else front_z-0.04
	var front_of_platform := d*0.5+float(detail.get("platform_margin",0.62))+float(detail.get("entry_projection",0.8))*int(detail.get("entry_roof",0))
	var post_base := base_y if front_z<front_of_platform-0.04 else 0.0
	for i in bays:
		var x := (i+0.5)*bay-span*0.5
		if style in [1,2]:
			Roof.part(out,"R19",Vector3(x,back_y,back_z),{"depth":projection,"drop":drop,
				"sag":float(detail.get("awning_sag",0.06)) if style==1 else 0.0,
				"edge":edge,"covering":int(style==2),"pattern":pattern,"seed":(seed_value+i*131)%2147483647},bay-(0.004 if light_mat else 0.012))
			out.back().material_set = "M_Planks" if style==2 else ["M_ReedMat","M_BasketMat","M_TwillMat"][pattern]
	# Longitudinal edge poles carry each panel. Bay boundaries are shared, so
	# neighbouring sheets never each generate a duplicate pair of support poles.
	for i in range(bays+1):
		var x := i*bay-span*0.5
		if light_mat:
			var slope := drop/projection
			var side_offset := sheet_thickness+0.025*sqrt(1.0+slope*slope)
			_rod(out,Vector3(x,back_y+slope*0.04-side_offset,back_z-0.04),
				Vector3(x,front_y-slope*0.015-side_offset,front_z+0.015),0.025)
		else:
			_rod(out,Vector3(x,back_y-0.035,back_z-0.04),Vector3(x,front_y-0.035,front_z+0.035),0.025)
		if support==0:
			# Even requested bay counts would place a boundary at the door centre.
			# Keep that doorway clear; the front continuous beam crosses it.
			if absf(x)>bay*0.32:
				var height := front_y-cross_offset-post_base
				Roof.part(out,"F01",Vector3(x,post_base+height*0.5,pole_z),
					{"height":height,"radius":0.045 if light_mat else 0.05,"sides":10})
				out.back().material_set = "M_Timber"
		elif absf(x)>bay*0.32:
			_rod(out,Vector3(x,back_y-0.72,back_z),Vector3(x,front_y-0.065,front_z-0.12),0.035)
	if style==3:
		var rafters := maxi(2,ceili(span/0.38))
		for i in rafters:
			var x := (i+0.5)*span/rafters-span*0.5
			_rod(out,Vector3(x,back_y-0.035,back_z),Vector3(x,front_y-0.035,front_z),0.022)
	for position in [Vector3(0,back_y-cross_offset,back_z),Vector3(0,front_y-cross_offset,pole_z)]:
		Roof.part(out,"F05",position,{"radius":cross_radius,"sides":10},span+0.12)
		out.back().material_set = "M_Timber"
	if support==0:
		for side in [-1.0,1.0]:
			var x: float = side*span*0.5
			_rod(out,Vector3(x,front_y-0.48,pole_z),
				Vector3(x-side*0.38,front_y-cross_offset,pole_z),0.028)


static func _rod(out: Array, start: Vector3, end: Vector3, radius: float) -> void:
	var delta := end-start
	var horizontal := Vector2(delta.x,delta.z).length()
	Roof.part(out,"F11",(start+end)*0.5,{"length":delta.length(),"radius":radius,"sides":10},
		-1,rad_to_deg(atan2(delta.x,delta.z)),-rad_to_deg(atan2(delta.y,horizontal)))
	out.back().material_set = "M_Timber"
