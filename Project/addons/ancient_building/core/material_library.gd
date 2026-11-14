extends RefCounted
## Surface families share a shader and metric detail across editable and batched instances.
const Surface := preload("res://addons/ancient_building/resources/aged_surface.gdshader")
static var _cache: Dictionary = {}
const LIBRARY_PATH := "res://Generated/AncientBuilding/Materials/DA_SurfaceLibrary.json"
static var _families: Dictionary = {}
static var _textures: Dictionary = {}
static var _loaded := false


static func options(raw: Dictionary = {}) -> Dictionary:
	var values := {"enabled":true,"normal_strength":0.8,"texture_scale":1.0,
		"age":0.3,"variation":0.22,"dust":0.15,"mapping":0,"seed":0}
	values.enabled = bool(raw.get("enabled",true))
	for field in ["normal_strength","texture_scale","age","variation","dust"]:
		var value: Variant = raw.get(field,values[field])
		if value is float or value is int:
			values[field] = clampf(float(value),0.25 if field=="texture_scale" else 0.0,
				4.0 if field=="texture_scale" else (2.0 if field=="normal_strength" else 1.0))
	values.mapping = 1 if int(raw.get("mapping",0))==1 else 0
	values.seed = clampi(int(raw.get("seed",0)),0,65535)
	values.family = String(raw.get("family",""))
	return values


static func reload_library() -> void:
	_cache.clear()
	_textures.clear()
	_families.clear()
	_loaded = false
	_load_library()


static func _load_library() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(LIBRARY_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIBRARY_PATH))
		if parsed is Dictionary and parsed.get("families") is Dictionary:
			_families = parsed.families


static func has_textures() -> bool:
	_load_library()
	return not _families.is_empty()


static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
	return _textures[path]


static func _bind_family(mat: ShaderMaterial, family: String, ending := false) -> bool:
	var record: Dictionary = _families.get(family,{})
	if record.is_empty():
		return false
	var names := ["end_color_map","end_normal_map","end_orm_map"] if ending else ["base_color_map","normal_map","orm_map"]
	var channels := ["base_color","normal","orm"]
	for i in channels.size():
		var texture := _texture(String(record.get(channels[i],"")))
		if texture == null:
			return false
		mat.set_shader_parameter(names[i],texture)
	var meters: Array = record.get("tile_size_m",[1.0,1.0])
	mat.set_shader_parameter("end_size_m" if ending else "tile_size_m",Vector2(maxf(0.001,meters[0]),maxf(0.001,meters[1])))
	var ref: Variant = record.get("reference_color_srgb","#808080")
	var reference := Color.from_string(ref,Color.GRAY) if ref is String else Color(ref[0],ref[1],ref[2],1)
	mat.set_shader_parameter("end_reference" if ending else "texture_reference",reference)
	return true


static func for_module(id: String, finish := "M_Default", raw: Dictionary = {}) -> Material:
	_load_library()
	var settings := options(raw)
	var kind := 0
	var axis := 0
	var pattern := 0
	var color := Color("#624631") if finish != "M_RedLacquer" else Color("#813b2b")
	if id in ["F01","O02","O01","O06","O07"]:
		axis = 1
	if id in ["F10","F11","F12","F13"]:
		axis = 2
	if id in ["B01","W02"]:
		kind = 1
		color = Color("#807c71") if id == "B01" else Color("#686463")
	elif id in ["B09","B10"]:
		color = Color("#483129")
	elif id == "O04":
		kind = 6
		color = Color("#96713f")
	elif id.begins_with("B") or id == "O05":
		kind = 5
		color = Color("#908d7d")
	elif id in ["W01","O08"]:
		kind = 3
		color = Color("#c2b8a4")
	elif id == "D03":
		kind = 4
		color = Color("#bf3119")
	elif id == "R19":
		kind = 9
		color = Color("#ad9569")
	elif id.begins_with("R") and id not in ["R01","R15"]:
		kind = 2
		color = Color("#4b5354") if id in ["R02","R03"] else Color("#5e625e")
	elif id in ["O02","W06","O11","R01"]:
		color = Color("#563c2b") if finish != "M_RedLacquer" else Color("#703426")
	if finish == "M_Earth":
		kind = 7
		color = Color("#a68c63")
	elif finish == "M_Plaster":
		kind = 3
		color = Color("#c2b8a4")
	elif finish == "M_Paper":
		kind = 3
		color = Color("#afa99a")
	elif finish == "M_Stone":
		kind = 5
		color = Color("#989487")
	elif finish == "M_Bronze":
		kind = 6
		color = Color("#8d7648")
	elif finish == "M_GlazedGreen":
		kind = 2
		color = Color("#3d6556")
	elif finish == "M_Thatch":
		kind = 8
		color = Color("#887b54")
		axis = 2
	elif finish in ["M_ReedMat", "M_BasketMat", "M_TwillMat"]:
		kind = 9
		pattern = ["M_ReedMat", "M_BasketMat", "M_TwillMat"].find(finish)
		color = Color("#ad9569")
	elif finish in ["M_TimberLines", "M_TimberDiamond"]:
		kind = 0
		pattern = 1 if finish == "M_TimberLines" else 2
		color = Color("#624631")
	elif finish in ["M_Planks", "M_Log", "M_Timber"]:
		kind = 0
		color = Color("#66503a")
		axis = 1 if finish == "M_Planks" else 0
		if id == "R19":
			axis = 2
	elif finish == "M_StreetTimber":
		kind = 0
		color = Color("#5b5145")
		if id=="W01":
			axis = 1
		if id == "R19":
			axis = 2
	elif finish == "M_StreetTile":
		kind = 2
		# Ridge and field tiles belong to one warm-grey ceramic family.
		color = Color("#4b4b44")
	elif finish == "M_StreetPlaster":
		kind = 3
		color = Color("#ada38d")
	elif finish == "M_StreetStone":
		kind = 1 if id in ["B01","W02"] else 5
		color = Color("#898476")
	elif finish == "M_StreetReed":
		kind = 9
		pattern = 0
		color = Color("#90866a")
	var quiet := finish in ["M_StreetTimber","M_StreetTile","M_StreetPlaster","M_StreetStone","M_StreetReed"]
	var glazed := finish in ["M_GlazedSlate","M_GlazedGreen"] and kind==2
	var lacquered := finish=="M_RedLacquer" and kind==0
	var key := "%s_%s_%s_%s_%s_%s_%s_%s" % [kind,axis,color.to_html(false),glazed,lacquered,pattern,quiet,JSON.stringify(settings)]
	if not _cache.has(key):
		if _cache.size()>256:
			_cache.clear()
		var mat := ShaderMaterial.new()
		mat.shader = Surface
		mat.set_shader_parameter("surface_kind",kind)
		mat.set_shader_parameter("grain_axis",axis)
		mat.set_shader_parameter("surface_pattern",pattern)
		mat.set_shader_parameter("quiet_surface",quiet)
		mat.set_shader_parameter("glazed",glazed)
		mat.set_shader_parameter("lacquered",lacquered)
		mat.set_shader_parameter("pigment",color)
		var family: String = {0:"Wood",1:"Stone",2:"Tile",3:"Plaster",5:"Stone",7:"Earth",8:"Thatch",9:"Reed"}.get(kind,"")
		if not settings.family.is_empty():
			family = settings.family
		var available := _bind_family(mat,family)
		if kind==0:
			available = _bind_family(mat,"WoodEnd",true) and available
		mat.set_shader_parameter("pbr_enabled",available and settings.enabled)
		mat.set_shader_parameter("normal_strength",settings.normal_strength)
		mat.set_shader_parameter("texture_scale",settings.texture_scale)
		mat.set_shader_parameter("surface_age",settings.age)
		mat.set_shader_parameter("surface_variation",settings.variation)
		mat.set_shader_parameter("surface_dust",settings.dust)
		mat.set_shader_parameter("mapping_mode",settings.mapping)
		mat.set_shader_parameter("material_seed",float(settings.seed))
		_cache[key] = mat
	return _cache[key]


static func piece_seed(module_id: String, placement: Transform3D) -> float:
	# Building-local coordinates, never the scene's global position or node RID.
	var p := placement.origin
	var identity := "%s:%.4f:%.4f:%.4f" % [module_id,p.x,p.y,p.z]
	return float(identity.sha256_text().substr(0,6).hex_to_int())/16777215.0
