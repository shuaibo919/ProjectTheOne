extends RefCounted
## 模块参数：schema 来自 module_catalog.json；运行时一律量化为整数（见 quantize.gd）。

const Registry := preload("res://addons/ancient_building/core/module_registry.gd")
const Quantize := preload("res://addons/ancient_building/core/quantize.gd")


static func schema(module_id: String) -> Dictionary:
	return Registry.get_module(module_id).get("params", {})


static func defaults(module_id: String) -> Dictionary:
	return quantize(module_id, schema_defaults_raw(module_id))


static func schema_defaults_raw(module_id: String) -> Dictionary:
	var raw: Dictionary = {}
	var sch := schema(module_id)
	for key in sch:
		raw[key] = float(sch[key].get("default", 0.0))
	return raw


static func quantize(module_id: String, raw: Dictionary) -> Dictionary:
	var sch := schema(module_id)
	var out: Dictionary = {}
	for key in raw:
		if not sch.has(key):
			push_error("AncientBuilding: module %s has no param '%s'" % [module_id, key])
			continue
		out[key] = _to_int(String(sch[key]["type"]), float(raw[key]))
	return out


static func validate(module_id: String, params: Dictionary) -> Array:
	var errors: Array = []
	var sch := schema(module_id)
	for key in sch:
		if not params.has(key):
			errors.append("missing param: %s" % key)
			continue
		var spec: Dictionary = sch[key]
		var value: int = int(params[key])
		if spec.has("min") and value < _to_int(String(spec["type"]), float(spec["min"])):
			errors.append("param '%s' below min" % key)
		if spec.has("max") and value > _to_int(String(spec["type"]), float(spec["max"])):
			errors.append("param '%s' above max" % key)
	return errors


static func _to_int(type: String, value: float) -> int:
	match type:
		"length":
			return Quantize.length(value)
		"angle":
			return Quantize.angle_degrees(value)
		"ratio":
			return Quantize.ratio(value)
		"int":
			return roundi(value)
		_:
			push_error("AncientBuilding: unsupported param type '%s'" % type)
			return 0
