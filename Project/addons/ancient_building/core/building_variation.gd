extends RefCounted
## 配方参数与确定性变体。随机化只改变整栋一致的尺度/纹样，不扰动结构接点。

const FIELDS := {
	"junction_height_tolerance": {"label":"接头高差容差 (m)","min":0.005,"max":0.15,"step":0.005,"spread":0.0,"modes":["compound"],"hint":"檐口与正脊均在此容差内时统一到共同标高。明显高差应保留为高低连接。"},
	"junction_clearance": {"label":"接头结构净距 (m)","min":0.03,"max":0.25,"step":0.01,"spread":0.0,"modes":["compound"],"hint":"高低连接时为柱梁外缘和低屋顶保留净距；增大可能要求更长的低段。"},
	"junction_gutter_width": {"label":"出水沟宽 (0=自动)","min":0.0,"max":0.6,"step":0.01,"spread":0.0,"modes":["compound"],"hint":"0 按瓦垄间距自动确定。手动值至少 0.12 m 且不小于瓦垄间距的 55%。"},
	"awning_style": {"label":"临街棚架","choices":["关闭","席棚","木板棚","开敞骨架"],"fixed_default":true,"modes":["rect"]},
	"awning_projection": {"label":"棚面出挑 (m)","min":0.6,"max":2.8,"step":0.05,"spread":0.12,"modes":["rect"]},
	"awning_height": {"label":"棚后缘离台高 (m)","min":1.9,"max":3.3,"step":0.05,"spread":0.05,"modes":["rect"]},
	"awning_drop": {"label":"棚前缘降高 (m)","min":0.1,"max":0.6,"step":0.01,"spread":0.12,"modes":["rect"]},
	"awning_sag": {"label":"席面下垂 (m)","min":0.0,"max":0.2,"step":0.01,"spread":0.25,"modes":["rect"]},
	"awning_edge": {"label":"席面自由挑边 (m)","min":0.0,"max":0.18,"step":0.01,"spread":0.10,"modes":["rect"]},
	"awning_bays": {"label":"棚覆盖开间 (0=全部)","min":0,"max":9,"step":1,"spread":0.0,"modes":["rect"]},
	"awning_support": {"label":"棚架承托","choices":["落地立杆","墙侧斜撑"],"fixed_default":true,"modes":["rect"]},
	"awning_pattern": {"label":"席面纹路","choices":["顺排苇席","经纬编织","斜编席"],"modes":["rect"]},
	"upper_porch_depth": {"label":"楼上退墙 (m)","min":0.0,"max":1.8,"step":0.05,"spread":0.0,"modes":["rect"]},
	"beam_pattern": {"label":"梁枋线饰","choices":["素木","细线饰","几何菱带"],"fixed_default":true},
	"bracket_style": {"label":"檐下承托","choices":["层叠铺作","简支梁枋"],"fixed_default":true,"modes":["rect"]},
	"bracket_projection": {"label":"铺作出跳 (m)","min":0.24,"max":0.60,"step":0.01,"spread":0.10,"modes":["rect","tower"]},
	"bracket_density": {"label":"补间铺作","choices":["仅柱头与转角","开间增加一攒"],"fixed_default":true,"modes":["rect"]},
	"joinery_bevel": {"label":"木件倒角 (m)","min":0.0,"max":0.012,"step":0.001,"spread":0.0},
	"column_entasis": {"label":"柱身梭度","min":0.0,"max":0.06,"step":0.005,"spread":0.0},
	"column_taper": {"label":"柱头收分","min":0.0,"max":0.14,"step":0.005,"spread":0.0},
	"column_base": {"label":"柱础轮廓","choices":["阶叠柱础","覆盆柱础","素石墩"],"fixed_default":true,"modes":["rect","tower"]},
	"column_base_height": {"label":"首层柱础高 (m)","min":0.08,"max":0.40,"step":0.01,"spread":0.0,"modes":["rect"]},
	"platform_margin": {"label":"台沿外扩 (m)","min":0.20,"max":0.85,"step":0.01,"spread":0.0,"modes":["rect"]},
	"surface_palette": {"label":"材作配色","choices":["原材作","街屋柔和材作"],"fixed_default":true,"modes":["rect"]},
	"eave_style": {"label":"檐口做法","choices":["装饰檐口","素檐口"],"fixed_default":true,"modes":["rect"]},

	"porch_depth": {"label":"前廊退墙 (m)","min":0.0,"max":1.8,"step":0.05,"spread":0.0,"modes":["rect"]},
	"facade_style": {"label":"前脸围护","choices":["传统格扇","窗墙与中门","满开间落地格扇","敞铺门面"],"fixed_default":true,"modes":["rect"]},
	"shop_opening": {"label":"铺面板扇开启","min":0.0,"max":1.0,"step":0.05,"spread":0.0,"modes":["rect"]},
	"counter_height": {"label":"铺窗柜台高 (m)","min":0.6,"max":1.1,"step":0.01,"spread":0.0,"modes":["rect"]},
	"side_windows": {"label":"侧墙开窗","choices":["封墙","格窗"],"fixed_default":true,"modes":["rect"]},
	"gable_finish": {"label":"山墙封护","choices":["木板","灰泥"],"fixed_default":true,"modes":["rect"]},
	"gable_rafter_setback": {"label":"山墙椽列内退 (m)","min":0.0,"max":0.30,"step":0.01,"spread":0.0,"modes":["rect"],"hint":"檐椽和飞椽收在封闭山墙内侧的额外净距；0 仍避免构件穿墙。正背檐头保持。"},
	"window_backing": {"label":"格心背衬","choices":["通透","纸绢"],"fixed_default":true,"modes":["rect","tower"]},
	"railing_style": {"label":"栏杆样式","choices":["关闭","木栏","石栏"],"fixed_default":true,"modes":["rect","tower"]},
	"railing_height": {"label":"栏杆高度 (m)","min":0.55,"max":1.15,"step":0.01,"spread":0.08,"modes":["rect","tower"]},
	"balcony_depth": {"label":"塔挑台宽 (m)","min":0.0,"max":1.2,"step":0.05,"spread":0.0,"modes":["tower"]},
	"bracket_spacing": {"label":"塔补间铺作间距 (m)","min":0.65,"max":2.0,"step":0.05,"spread":0.08,"modes":["tower"]},
	"finial_height": {"label":"塔刹高度 (m)","min":0.4,"max":3.5,"step":0.05,"spread":0.1,"modes":["tower"]},
	"ridge_profile": {"label":"脊身样式","choices":["圆盖素脊","薄压脊","高身灰脊","连弧花脊"],"fixed_default":true,"modes":["rect"]},
	"ridge_ornament": {"label":"脊端装饰","choices":["随等级","素脊","兽饰","扇形鸱尾"],"fixed_default":true,"modes":["rect"]},
	"ridge_height": {"label":"正脊高度 (m)","min":0.10,"max":0.60,"step":0.01,"spread":0.10,"modes":["rect"]},
	"ridge_width": {"label":"正脊宽度 (m)","min":0.14,"max":0.46,"step":0.01,"spread":0.08,"modes":["rect"]},
	"ridge_end_lift": {"label":"脊端生起 (m)","min":0.0,"max":0.35,"step":0.01,"spread":0.10,"modes":["rect"]},
	"verge_width": {"label":"垂戗脊宽 (m)","min":0.10,"max":0.32,"step":0.01,"spread":0.10,"modes":["rect"]},
	"ridge_joint_spacing": {"label":"正脊分节间距 (m)","min":0.0,"max":0.80,"step":0.02,"spread":0.10,"modes":["rect"]},
	"ornament_scale": {"label":"脊端尺度","min":0.5,"max":1.5,"step":0.05,"spread":0.1,"modes":["rect"]},
	"ornament_relief": {"label":"脊饰浮雕强度","min":0.0,"max":1.0,"step":0.05,"spread":0.0,"modes":["rect"]},
	"ornament_curl": {"label":"脊饰卷尾程度","min":0.65,"max":1.25,"step":0.05,"spread":0.08,"modes":["rect"]},
	"roof_palette": {"label":"瓦作表面","choices":["灰陶瓦","青绿釉瓦","灰釉瓦"],"fixed_default":true},
	"platform_paving": {"label":"独立石板铺地","choices":["关闭","开启"],"fixed_default":true,"modes":["rect","tower"]},
	"paving_size": {"label":"石板边长 (m)","min":0.4,"max":1.2,"step":0.05,"spread":0.1,"modes":["rect","tower"]},
	"entry_roof": {"label":"中央抱厦屋顶","choices":["关闭","开启"],"fixed_default":true,"modes":["rect"]},
	"entry_projection": {"label":"抱厦出挑 (m)","min":0.3,"max":1.4,"step":0.05,"spread":0.0,"modes":["rect"]},
	"entry_rise": {"label":"抱厦举高 (m)","min":0.35,"max":1.1,"step":0.05,"spread":0.0,"modes":["rect"]},
	"roof_curve": {"label":"屋面凹曲程度","min":0.0,"max":0.85,"step":0.05,"spread":0.1,"modes":["rect","tower"]},
	"thatch_thickness": {"label":"茅束厚度 (m)","min":0.12,"max":0.45,"step":0.01,"spread":0.15,"modes":["rect"]},
	"thatch_bundle": {"label":"茅束宽度 (m)","min":0.08,"max":0.3,"step":0.01,"spread":0.12,"modes":["rect"]},
	"thatch_raggedness": {"label":"草梢参差","min":0.0,"max":1.0,"step":0.05,"spread":0.2,"modes":["rect"]},
	"thatch_rods": {"label":"压草杆","choices":["关闭","开启"],"fixed_default":true,"modes":["rect"]},

	"damage": {"label":"几何破损强度", "min":0.0, "max":1.0, "step":0.05, "spread":0.0},
	"damage_wood": {"label":"木件破损倍率", "min":0.0, "max":1.0, "step":0.05, "spread":0.0},
	"damage_wall": {"label":"墙体破损倍率", "min":0.0, "max":1.0, "step":0.05, "spread":0.0},
	"damage_roof": {"label":"瓦件破损倍率", "min":0.0, "max":1.0, "step":0.05, "spread":0.0},
	"damage_stone": {"label":"石作破损倍率", "min":0.0, "max":1.0, "step":0.05, "spread":0.0},
	"damage_depth": {"label":"缺口深度 (m)", "min":0.005, "max":0.15, "step":0.005, "spread":0.0},
	"damage_density": {"label":"受损密度", "min":0.0, "max":1.0, "step":0.05, "spread":0.0},
	"wall_thickness": {"label":"围护厚度 (m)", "min":0.12, "max":0.6, "step":0.01, "spread":0.0},
	"board_width": {"label":"墙板宽度 (m)", "min":0.10, "max":0.4, "step":0.01, "spread":0.1},
	"log_diameter": {"label":"垒木层高 (m)", "min":0.12, "max":0.4, "step":0.01, "spread":0.1},
	"base_height": {"label":"台基高度 (m)", "min":0.12, "max":1.2, "step":0.01, "spread":0.16},
	"floor_height": {"label":"柱层高度 (m)", "min":2.7, "max":3.9, "step":0.01, "spread":0.10},
	"column_radius": {"label":"主柱半径 (m)", "min":0.10, "max":0.25, "step":0.005, "spread":0.13},
	"eave_depth": {"label":"檐口挑出 (m)", "min":0.45, "max":1.2, "step":0.01, "spread":0.18},
	"roof_rise_ratio": {"label":"屋顶高深比", "min":0.20, "max":0.40, "step":0.01, "spread":0.14},
	"corner_lift": {"label":"翼角抬升 (m)", "min":0.0, "max":0.60, "step":0.01, "spread":0.20},
	"tile_pattern": {"label":"铺瓦纹路","choices":["筒板瓦","错缝板瓦","鳞叠板瓦"],"fixed_default":true,"modes":["rect"]},
	"tile_pitch": {"label":"瓦垄间距 (m)", "min":0.22, "max":0.38, "step":0.005, "spread":0.14},
	"rafter_spacing": {"label":"檐椽间距 (m)", "min":0.24, "max":0.45, "step":0.01, "spread":0.16},
	"rafter_radius": {"label":"檐椽半径 (m)", "min":0.045, "max":0.09, "step":0.001, "spread":0.12},
	"lattice_style": {"label":"格心样式", "choices":["传统格心","疏横格心","菱形格心","方格格心"]},
	"lattice_bars": {"label":"格心竖棂数", "min":3, "max":9, "step":1, "spread":0.35},
	"lattice_bar": {"label":"棂条宽度 (m)", "min":0.012, "max":0.035, "step":0.001, "spread":0.20},
	"hanging_style": {"label":"挂落样式", "choices":["卷草挂落","菱格挂落","素牙挂落"]},
	"hanging_height": {"label":"挂落高度 (m)", "min":0.20, "max":0.48, "step":0.01, "spread":0.18},
	"cap_pattern": {"label":"瓦当纹样", "choices":["卷纹","花瓣","素环"]},
	"lanterns": {"label":"灯笼", "choices":["关闭","开启"], "fixed_default":true},
	"hangings": {"label":"挂落", "choices":["关闭","开启"], "fixed_default":true},
}


static func defaults(spec: Dictionary) -> Dictionary:
	var ornate: bool = spec.get("usage", "house") in ["hall", "gate"]
	var decorated: bool = ornate or spec.get("usage", "house") == "shop"
	return {
		"junction_height_tolerance":0.03,"junction_clearance":0.08,"junction_gutter_width":0.0,
		"awning_style":0,"awning_projection":1.3,"awning_height":2.5,"awning_drop":0.25,
		"awning_sag":0.06,"awning_bays":0,"awning_support":0,"awning_pattern":0,
		"awning_edge":0.0,"column_base_height":0.34,"platform_margin":0.62,
		"surface_palette":0,"eave_style":0,"shop_opening":1.0,"counter_height":0.84,
		"ridge_profile":0,"ridge_end_lift":0.0,"verge_width":0.19,"tile_pattern":0,"beam_pattern":0,
		"upper_porch_depth":0.92,"bracket_style":0,"column_base":0,
		"bracket_projection":0.36,"bracket_density":int(ornate),"joinery_bevel":0.004,
		"column_entasis":0.015,"column_taper":0.09,"ornament_relief":0.6,"ornament_curl":1.0,
		"porch_depth":0.84,
		"facade_style":0,
		"side_windows":0,
		"gable_finish":0,
		"gable_rafter_setback":0.02,
		"window_backing":0,
		"railing_style":0,
		"railing_height":0.88,
		"balcony_depth":0.65,
		"bracket_spacing":1.2,
		"finial_height":1.8,
		"ridge_ornament":0,
		"ridge_height":0.28,
		"ridge_width":0.29,
		"ridge_joint_spacing":0.40,
		"ornament_scale":1.0,
		"roof_palette":0,
		"platform_paving":0,
		"paving_size":0.75,
		"entry_roof":0,
		"entry_projection":0.8,
		"entry_rise":0.65,
		"roof_curve":0.52,
		"thatch_thickness":0.24,
		"thatch_bundle":0.16,
		"thatch_raggedness":0.6,
		"thatch_rods":1,
		"damage":0.0, "damage_wood":1.0, "damage_wall":1.0, "damage_roof":1.0, "damage_stone":1.0,
		"damage_depth":0.06, "damage_density":0.7, "wall_thickness":0.32, "board_width":0.18, "log_diameter":0.22,
		"base_height":0.72 if ornate else 0.45, "floor_height":3.6 if ornate else 3.05,
		"column_radius":0.19 if ornate else 0.145, "eave_depth":0.86 if ornate else 0.67,
		"roof_rise_ratio":0.33 if ornate else 0.29, "corner_lift":0.47,
		"tile_pitch":0.285, "rafter_spacing":0.32, "rafter_radius":0.068,
		"lattice_style":0, "lattice_bars":5, "lattice_bar":0.021,
		"hanging_style":0, "hanging_height":0.36, "cap_pattern":0,
		"lanterns":int(decorated), "hangings":int(decorated),
	}


static func resolve(spec: Dictionary) -> Dictionary:
	var detail: Variant = spec.get("details", {})
	var variation: Variant = spec.get("variation", {})
	if not detail is Dictionary or not variation is Dictionary:
		return {"error":"details 与 variation 必须是对象"}
	for key in variation:
		if key not in ["seed", "amount"]:
			return {"error":"未知变体参数: %s" % key}
	var seed_value: Variant = variation.get("seed", 0)
	var amount_value: Variant = variation.get("amount", 0.0)
	if not _number(seed_value) or not _number(amount_value):
		return {"error":"seed 和 amount 必须是有限数值"}
	if seed_value < 0 or seed_value > 2147483646 or float(seed_value) != floorf(float(seed_value)):
		return {"error":"seed 必须是 0–2147483646 的整数"}
	if amount_value < 0 or amount_value > 1:
		return {"error":"变体强度 amount 必须在 0–1 之间"}
	var result := defaults(spec)
	var amount := float(amount_value)
	for key in FIELDS:
		var field: Dictionary = FIELDS[key]
		var roll := _sample(int(seed_value), key)
		if field.has("choices"):
			if amount > 0 and not field.get("fixed_default", false) and roll < amount:
				result[key] = 1 + int(_sample(int(seed_value), key + ":choice") * (field.choices.size() - 1)) % (field.choices.size() - 1)
		elif amount > 0:
			# 七档微调，避免每个种子形成无限连续的构件尺寸。
			var offset := (floorf(roll * 7.0) - 3.0) / 3.0
			var value := float(result[key]) * (1.0 + offset * float(field.spread) * amount)
			result[key] = snappedf(clampf(value, field.min, field.max), field.step)
	for key in detail:
		if not FIELDS.has(key):
			return {"error":"未知部件参数: %s" % key}
		var value: Variant = detail[key]
		var field: Dictionary = FIELDS[key]
		if not _number(value):
			return {"error":"%s 必须是有限数值" % key}
		var lo := 0.0 if field.has("choices") else float(field.min)
		var hi := float(field.choices.size() - 1) if field.has("choices") else float(field.max)
		if value < lo or value > hi:
			return {"error":"%s 必须在 %.3f–%.3f 之间" % [key, lo, hi]}
		if (field.has("choices") or field.step == 1) and float(value) != floorf(float(value)):
			return {"error":"%s 必须是整数" % key}
		result[key] = value
	return {"values":result, "error":""}


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _sample(seed_value: int, channel: String) -> float:
	var value := seed_value
	for code in channel.to_utf8_buffer():
		value = (value * 33 + int(code)) & 0x7fffffff
	value = (value * 1103515245 + 12345) & 0x7fffffff
	return float(value) / 2147483648.0
