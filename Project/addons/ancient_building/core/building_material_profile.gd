class_name AncientBuildingMaterialProfile
extends Resource
## 共享材质配置：同一 ModuleKey + material_set + surface 的实例共用一个 profile。
## profile_id 是内容哈希，运行时批次用它分组；material 是实际共享的 Material 资源。

@export var profile_id := ""
@export var module_id := ""
@export var material_set := "M_Default"
@export var surface: Dictionary = {}
@export var material: Material


func validate() -> Array[String]:
	var errors: Array[String] = []
	if profile_id.is_empty():
		errors.append("profile_id is empty")
	if module_id.is_empty():
		errors.append("module_id is empty")
	if material == null:
		errors.append("material is null for %s" % profile_id)
	return errors
