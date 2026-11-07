extends RefCounted
## AncientBuilding 模块目录。
## 唯一数据源是 resources/module_catalog.json；本类只做加载、校验与查询，不持有几何。

const CATALOG_PATH := "res://addons/ancient_building/resources/module_catalog.json"
const VALID_POLICIES := ["S", "R", "A", "P"]
const VALID_LAYERS := ["Base", "Frame", "Wall", "Opening", "Roof", "Ornament"]

static var _modules: Dictionary = {}
static var _order: Array = []
static var _loaded := false
static var _generator_version := 0
static var _errors: Array = []


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		_errors.append("catalog not found: %s" % CATALOG_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_errors.append("catalog is not a JSON object")
		return

	_generator_version = int(parsed.get("generator_version", 0))
	for entry in parsed.get("modules", []):
		if typeof(entry) != TYPE_DICTIONARY:
			_errors.append("catalog entry is not an object")
			continue
		var id := String(entry.get("id", ""))
		if id.is_empty():
			_errors.append("catalog entry without id")
			continue
		if _modules.has(id):
			_errors.append("duplicate module id: %s" % id)
			continue
		var policy := String(entry.get("policy", ""))
		if policy not in VALID_POLICIES:
			_errors.append("module %s has invalid policy: %s" % [id, policy])
			continue
		var layer := String(entry.get("layer", ""))
		if layer not in VALID_LAYERS:
			_errors.append("module %s has invalid layer: %s" % [id, layer])
			continue
		_modules[id] = entry
		_order.append(id)


static func count() -> int:
	_ensure_loaded()
	return _modules.size()


static func generator_version() -> int:
	_ensure_loaded()
	return _generator_version


static func all_ids() -> Array:
	_ensure_loaded()
	return _order.duplicate()


static func all_modules() -> Array:
	_ensure_loaded()
	var out: Array = []
	for id in _order:
		out.append(_modules[id])
	return out


static func has_module(module_id: String) -> bool:
	_ensure_loaded()
	return _modules.has(module_id)


static func get_module(module_id: String) -> Dictionary:
	_ensure_loaded()
	if not _modules.has(module_id):
		return {}
	return _modules[module_id]


static func modules_in_layer(layer: String) -> Array:
	_ensure_loaded()
	var out: Array = []
	for id in _order:
		if String(_modules[id].get("layer", "")) == layer:
			out.append(_modules[id])
	return out


static func errors() -> Array:
	_ensure_loaded()
	return _errors.duplicate()
