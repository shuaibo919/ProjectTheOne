extends RefCounted
## 模块身份：把 (策略, 模块 id, 已量化参数, 材质集, LOD) 变成稳定 key。
## S / R 策略不含尺寸；A 策略尺寸在 params 里；P 策略的 resolved_dims 进入 payload。

const Registry = preload("res://addons/ancient_building/core/module_registry.gd")


static func make(module_id: String, params: Dictionary, material_set: String, lod: int, resolved_dims: Variant = null, mesh_path := "") -> String:
	var meta := Registry.get_module(module_id)
	if meta.is_empty():
		push_error("AncientBuilding: unknown module id: %s" % module_id)
		return ""

	var policy := String(meta.get("policy", ""))
	var payload := {
		"generator_version": Registry.generator_version(),
		"module_id": module_id,
		"policy": policy,
		"params": params,
		"material_set": material_set,
		"lod": lod,
	}
	if not mesh_path.is_empty():
		payload["mesh_path"] = mesh_path
	if policy == "P" or (resolved_dims is Dictionary and resolved_dims.has("geometry")):
		payload["dims"] = resolved_dims if resolved_dims != null else {}

	return ModuleKey.make_key(payload)
