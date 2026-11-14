extends SceneTree
## AncientBuilding CLI（headless）。
## 语义：validate 只校验；build 构建到内存不保存；stats 输出实例/网格/三角面；
## bake 构建并保存；params 生成参数参考；convert/revert/inspect 处理已烘焙场景。
## 退出码：0 成功；1 描述/参数校验失败；2 构建/保存/用法错误。

const Registry := preload("res://addons/ancient_building/core/module_registry.gd")
const Descriptor := preload("res://addons/ancient_building/core/descriptor.gd")
const Planner := preload("res://addons/ancient_building/core/layout_planner.gd")
const CacheScript := preload("res://addons/ancient_building/core/mesh_cache.gd")
const Assembler := preload("res://addons/ancient_building/core/assembler.gd")
const Batcher := preload("res://addons/ancient_building/core/scene_batcher.gd")
const Variation := preload("res://addons/ancient_building/core/building_variation.gd")
const ModuleMesh := preload("res://addons/ancient_building/core/module_mesh.gd")

const CACHE_ROOT := "res://Generated/AncientBuilding"
const EXIT_OK := 0
const EXIT_VALIDATION := 1
const EXIT_FAILURE := 2


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		_print_usage()
		quit(EXIT_OK)
		return
	var command := String(args[0])
	var options := _parse_options(args)

	match command:
		"list-modules":
			_cmd_list_modules()
		"describe":
			_cmd_describe(options)
		"validate":
			_cmd_validate(options)
		"build":
			_cmd_build(options)
		"stats":
			_cmd_stats(options)
		"params":
			_cmd_params(options)
		"bake":
			_cmd_bake(options)
		"convert":
			_cmd_convert(options)
		"revert":
			_cmd_revert(options)
		"inspect":
			_cmd_inspect(options)
		"help", "--help", "-h":
			_print_usage()
			quit(EXIT_OK)
		_:
			printerr("AncientBuilding CLI: unknown command '%s'" % command)
			_print_usage()
			quit(EXIT_FAILURE)


func _parse_options(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var index := 1
	while index < args.size():
		var token := String(args[index])
		if token.begins_with("--"):
			var key := token.substr(2)
			if index + 1 < args.size() and not String(args[index + 1]).begins_with("--"):
				out[key] = String(args[index + 1])
				index += 2
			else:
				out[key] = true
				index += 1
		else:
			index += 1
	return out


func _cmd_list_modules() -> void:
	var modules: Array = Registry.all_modules()
	var errors: Array = Registry.errors()
	_emit({
		"generator_version": Registry.generator_version(),
		"count": modules.size(),
		"layers": _layer_counts(),
		"errors": errors,
		"modules": modules,
	})
	quit(EXIT_OK if errors.is_empty() else EXIT_VALIDATION)


func _cmd_describe(options: Dictionary) -> void:
	var module_id := String(options.get("id", ""))
	if module_id.is_empty():
		printerr("usage: describe --id <module_id>")
		quit(EXIT_FAILURE)
		return
	var meta := Registry.get_module(module_id)
	if meta.is_empty():
		printerr("unknown module: %s" % module_id)
		quit(EXIT_VALIDATION)
		return
	_emit(meta)
	quit(EXIT_OK)


func _cmd_validate(options: Dictionary) -> void:
	var descriptor := _read_descriptor(options)
	if descriptor.is_empty():
		return
	var plan := Planner.from_descriptor(descriptor)
	if not plan.errors.is_empty():
		_emit({"valid": false, "name": String(descriptor.get("name", "")), "errors": plan["errors"]})
		quit(EXIT_VALIDATION)
		return
	var stats := Assembler.stats(plan)
	_emit({
		"valid": true,
		"name": String(descriptor.get("name", "")),
		"generator_version": Registry.generator_version(),
		"layout_hash": plan["layout_hash"],
		"instances": stats["instances"],
		"unique_meshes": stats["unique_meshes"],
		"modules": stats["modules"],
	})
	quit(EXIT_OK)


func _cmd_build(options: Dictionary) -> void:
	var descriptor := _read_descriptor(options)
	if descriptor.is_empty():
		return
	var plan := Planner.from_descriptor(descriptor)
	if not plan.errors.is_empty():
		_emit({"valid": false, "name": String(descriptor.get("name", "")), "errors": plan["errors"]})
		quit(EXIT_VALIDATION)
		return
	var cache := CacheScript.new("%s/Meshes" % CACHE_ROOT, Registry.generator_version())
	var root := Assembler.build(plan, cache)
	var stats := Assembler.stats(plan)
	var triangles := _count_triangles(plan, cache)
	root.free()
	_emit({
		"name": String(descriptor.get("name", "")),
		"generator_version": Registry.generator_version(),
		"layout_hash": plan["layout_hash"],
		"instances": stats["instances"],
		"unique_meshes": stats["unique_meshes"],
		"modules": stats["modules"],
		"triangles": triangles,
		"errors": [],
	})
	quit(EXIT_OK)


func _cmd_stats(options: Dictionary) -> void:
	var descriptor := _read_descriptor(options)
	if descriptor.is_empty():
		return
	var plan := Planner.from_descriptor(descriptor)
	if not plan.errors.is_empty():
		_emit({"valid": false, "name": String(descriptor.get("name", "")), "errors": plan["errors"]})
		quit(EXIT_VALIDATION)
		return
	# 不写磁盘，只统计；三角面按唯一 key 计算。
	var cache := CacheScript.new("", Registry.generator_version())
	var stats := Assembler.stats(plan)
	var triangles := _count_triangles(plan, cache)
	var unique := int(stats["unique_meshes"])
	var instances := int(stats["instances"])
	_emit({
		"name": String(descriptor.get("name", "")),
		"generator_version": Registry.generator_version(),
		"layout_hash": plan["layout_hash"],
		"instances": instances,
		"unique_meshes": unique,
		"de_duplication": 1.0 - float(unique) / maxf(1.0, float(instances)),
		"triangles": triangles,
		"by_policy": _policy_counts(plan),
		"modules": stats["modules"],
	})
	quit(EXIT_OK)


func _cmd_params(options: Dictionary) -> void:
	var payload := _param_payload()
	var format := String(options.get("format", "md")).to_lower()
	if format not in ["md", "json"]:
		_fail("params --format must be md or json")
		return
	var out_path := String(options.get("out", ""))
	var text := JSON.stringify(payload, "  ") if format == "json" else _param_markdown(payload)
	if out_path.is_empty():
		if format == "json":
			_emit(payload)
		else:
			print(text)
		quit(EXIT_OK)
		return
	if not _write_text(out_path, text):
		return
	_emit({"path": out_path, "format": format, "bytes": text.to_utf8_buffer().size()})
	quit(EXIT_OK)


func _cmd_bake(options: Dictionary) -> void:
	var descriptor := _read_descriptor(options)
	if descriptor.is_empty():
		return
	if descriptor["modules"].is_empty() and descriptor.get("building", {}).is_empty():
		_fail("descriptor has no modules", EXIT_VALIDATION)
		return

	var plan := Planner.from_descriptor(descriptor)
	if not plan.errors.is_empty():
		_emit({"valid": false, "name": String(descriptor.get("name", "")), "errors": plan["errors"]})
		quit(EXIT_VALIDATION)
		return

	var cache := CacheScript.new("%s/Meshes" % CACHE_ROOT, Registry.generator_version())
	var root := Assembler.build(plan, cache)
	root.name = String(descriptor["name"])
	root.set_meta("ab_descriptor", descriptor)
	root.set_meta("ab_layout_hash", plan["layout_hash"])

	var out_path := String(options.get("out", "%s/Samples/%s.tscn" % [CACHE_ROOT, descriptor["name"]]))
	if not _ensure_dir(out_path.get_base_dir()):
		root.free()
		return
	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		root.free()
		_fail("pack failed: %s" % error_string(pack_error))
		return
	var save_error := ResourceSaver.save(packed, out_path)
	root.free()
	if save_error != OK:
		_fail("save failed: %s" % error_string(save_error))
		return

	var stats := Assembler.stats(plan)
	_emit({
		"scene": out_path,
		"instances": stats["instances"],
		"unique_meshes": stats["unique_meshes"],
		"layout_hash": plan["layout_hash"],
	})
	quit(EXIT_OK)


func _cmd_convert(options: Dictionary) -> void:
	var scene_path := String(options.get("scene", ""))
	var root := _instantiate(scene_path)
	if root == null:
		return
	var result := Batcher.convert(root)
	var save_error := _save(root, scene_path)
	root.free()
	if save_error != OK:
		_fail("save failed: %s" % error_string(save_error))
		return
	_emit({"scene": scene_path, "mode": "multimesh", "groups": result["groups"], "instances": result["instances"]})
	quit(EXIT_OK)


func _cmd_revert(options: Dictionary) -> void:
	var scene_path := String(options.get("scene", ""))
	var root := _instantiate(scene_path)
	if root == null:
		return
	var descriptor: Variant = root.get_meta("ab_descriptor", null)
	if typeof(descriptor) != TYPE_DICTIONARY:
		root.free()
		_fail("scene has no ab_descriptor metadata; cannot revert")
		return

	var plan := Planner.from_descriptor(descriptor)
	if not plan.errors.is_empty():
		root.free()
		_emit({"valid": false, "scene": scene_path, "errors": plan.errors})
		quit(EXIT_VALIDATION)
		return
	var cache := CacheScript.new("%s/Meshes" % CACHE_ROOT, Registry.generator_version())
	Batcher.revert(root, plan, cache)
	root.set_meta("ab_layout_hash", plan.layout_hash)
	var save_error := _save(root, scene_path)
	root.free()
	if save_error != OK:
		_fail("save failed: %s" % error_string(save_error))
		return
	var stats := Assembler.stats(plan)
	_emit({"scene": scene_path, "mode": "individual", "instances": stats["instances"]})
	quit(EXIT_OK)


func _cmd_inspect(options: Dictionary) -> void:
	var scene_path := String(options.get("scene", ""))
	var root := _instantiate(scene_path)
	if root == null:
		return
	var counts: Dictionary = {}
	for child in root.get_children():
		var type_name := child.get_class()
		counts[type_name] = int(counts.get(type_name, 0)) + 1
	_emit({
		"scene": scene_path,
		"children": root.get_child_count(),
		"types": counts,
		"state": root.get_meta("ab_state", {}),
		"layout_hash": root.get_meta("ab_layout_hash", ""),
	})
	root.free()
	quit(EXIT_OK)


func _read_descriptor(options: Dictionary) -> Dictionary:
	var path := String(options.get("file", ""))
	if path.is_empty():
		_fail("missing --file <descriptor.json>")
		return {}
	var descriptor := Descriptor.load_file(path)
	if not String(descriptor.get("error", "")).is_empty():
		_fail(String(descriptor["error"]), EXIT_VALIDATION)
		return {}
	return descriptor


func _instantiate(scene_path: String) -> Node3D:
	if scene_path.is_empty():
		_fail("missing --scene <path>")
		return null
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		_fail("scene not found: %s" % scene_path)
		return null
	var packed: PackedScene = ResourceLoader.load(scene_path, "PackedScene")
	var root := packed.instantiate() as Node3D
	if root == null:
		_fail("scene root is not Node3D: %s" % scene_path)
	return root


func _save(root: Node, scene_path: String) -> Error:
	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		return pack_error
	return ResourceSaver.save(packed, scene_path)


func _ensure_dir(path: String) -> bool:
	var abs_path := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(abs_path):
		return true
	var error := DirAccess.make_dir_recursive_absolute(abs_path)
	if error != OK:
		_fail("cannot create directory: %s (%s)" % [path, error_string(error)])
		return false
	return true


func _write_text(path: String, text: String) -> bool:
	var target := path
	if not target.begins_with("res://") and not target.begins_with("user://"):
		target = ProjectSettings.globalize_path(target)
	if not _ensure_dir(target.get_base_dir()):
		return false
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		_fail("cannot write: %s" % target)
		return false
	file.store_string(text)
	file.close()
	return true


func _count_triangles(plan: Dictionary, cache) -> int:
	var seen := {}
	var total := 0
	for instance in plan.get("instances", []):
		var key := String(instance.key)
		if seen.has(key):
			continue
		seen[key] = true
		var mesh: Mesh = cache.get_mesh(key, String(instance.module_id), instance.params, instance.get("dims", {}))
		if mesh == null:
			continue
		total += int(mesh.get_faces().size() / 3)
	return total


func _policy_counts(plan: Dictionary) -> Dictionary:
	var out := {}
	for instance in plan.get("instances", []):
		var meta := Registry.get_module(String(instance.module_id))
		var policy := String(meta.get("policy", "?"))
		out[policy] = int(out.get(policy, 0)) + 1
	return out


func _layer_counts() -> Dictionary:
	var out := {}
	for layer in Registry.VALID_LAYERS:
		out[layer] = Registry.modules_in_layer(layer).size()
	return out


func _param_payload() -> Dictionary:
	var house: Dictionary = Variation.defaults({"usage": "house"})
	var hall: Dictionary = Variation.defaults({"usage": "hall"})
	var fields: Array = []
	for key in Variation.FIELDS:
		var field: Dictionary = Variation.FIELDS[key]
		fields.append({
			"key": key,
			"label": String(field.get("label", key)),
			"choices": field.get("choices", []),
			"min": field.get("min", null),
			"max": field.get("max", null),
			"step": field.get("step", null),
			"spread": field.get("spread", 0.0),
			"fixed_default": bool(field.get("fixed_default", false)),
			"modes": field.get("modes", []),
			"hint": String(field.get("hint", "")),
			"default_house": house.get(key, null),
			"default_hall": hall.get(key, null),
		})
	var modules: Array = []
	for layer in Registry.VALID_LAYERS:
		for meta in Registry.modules_in_layer(layer):
			var id := String(meta.get("id", ""))
			modules.append({
				"id": id,
				"name": String(meta.get("name", "")),
				"layer": String(meta.get("layer", "")),
				"policy": String(meta.get("policy", "")),
				"unit": meta.get("unit", null),
				"max_stretch": meta.get("max_stretch", null),
				"repeat_unit": meta.get("repeat_unit", null),
				"dims_in_key": bool(meta.get("dims_in_key", false)),
				"implemented": ModuleMesh.supports(id),
				"params": meta.get("params", {}),
			})
	return {
		"generator_version": Registry.generator_version(),
		"module_count": Registry.all_modules().size(),
		"implemented_count": modules.filter(func(m): return bool(m.implemented)).size(),
		"fields": fields,
		"modules": modules,
	}


func _param_markdown(payload: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("# AncientBuilding 参数参考（自动生成）")
	lines.append("")
	lines.append("> 由 `AncientBuilding CLI params` 生成，不要手工编辑；改 schema 后重跑生成命令。")
	lines.append("> 生成器 v%s；模块 %d 项，程序网格 %d 项。" % [
		str(payload.generator_version), int(payload.module_count), int(payload.implemented_count)])
	lines.append("> 默认列：民居（house）；殿阁/门楼（hall）的差异见对应列。")
	lines.append("")
	lines.append("## 生成命令")
	lines.append("")
	lines.append("```bash")
	lines.append("bash Tools/AncientBuilding/generate_param_reference.sh")
	lines.append("```")
	lines.append("")
	lines.append("## 建筑与部件参数")
	lines.append("")
	lines.append("| 参数 | 标签 | 取值 | 默认（民居） | 默认（殿阁） | 种子幅度 | 固定默认 | 适用模式 | 说明 |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for field in payload.fields:
		lines.append(_md_row([
			String(field.key), String(field.label), _param_value_text(field),
			_param_default_text(field, field.default_house),
			_param_default_text(field, field.default_hall),
			_fmt(field.spread),
			"是" if bool(field.fixed_default) else "否",
			" / ".join(field.modes) if not field.modes.is_empty() else "全部",
			String(field.hint) if not String(field.hint).is_empty() else "—",
		]))
	lines.append("")
	lines.append("## 模块参数")
	lines.append("")
	lines.append("模块参数写入 `modules[].params`；`unit`/`max_stretch`/`repeat_unit` 用于 S/R/P 求解。")
	lines.append("")
	for layer in Registry.VALID_LAYERS:
		var rows: Array = payload.modules.filter(func(m): return String(m.layer) == layer)
		if rows.is_empty():
			continue
		lines.append("### " + layer)
		lines.append("")
		lines.append("| ID | 模块 | 策略 | 实现 | unit | max_stretch | repeat_unit | 参数（类型/默认/范围） |")
		lines.append("| --- | --- | --- | --- | ---: | ---: | ---: | --- |")
		for module in rows:
			lines.append(_md_row([
				String(module.id), String(module.name), String(module.policy),
				"是" if bool(module.implemented) else "占位",
				_fmt(module.unit), _fmt(module.max_stretch), _fmt(module.repeat_unit),
				_module_params_text(module.params),
			]))
		lines.append("")
	lines.append("## 备注")
	lines.append("")
	lines.append("- `S`/`R`/`A`/`P` 策略与尺寸身份见 008 §4.3；")
	lines.append("- 选择型字段的默认值是索引，生成器按 `choices` 取标签；")
	lines.append("- 种子只改变非固定项，固定值优先（008 §5.9）；")
	lines.append("- 未实现模块仍可手动摆放，但会退化为 unit box，面板显示“占位”。")
	lines.append("")
	return "\n".join(lines)


func _param_value_text(field: Dictionary) -> String:
	if not field.choices.is_empty():
		return "枚举：" + " / ".join(field.choices)
	if field.min == null or field.max == null:
		return "—"
	return "%s–%s（步长 %s）" % [_fmt(field.min), _fmt(field.max), _fmt(field.step)]


func _param_default_text(field: Dictionary, value: Variant) -> String:
	if value == null:
		return "—"
	if not field.choices.is_empty():
		var index := int(value)
		if index >= 0 and index < field.choices.size():
			return String(field.choices[index])
		return str(value)
	return _fmt(value)


func _module_params_text(params: Dictionary) -> String:
	if params.is_empty():
		return "—"
	var parts: Array = []
	for key in params:
		var param: Dictionary = params[key]
		parts.append("%s：%s，默认 %s，范围 %s–%s" % [
			String(key), String(param.get("type", "")), _fmt(param.get("default")),
			_fmt(param.get("min")), _fmt(param.get("max"))])
	return "；".join(parts)


func _fmt(value: Variant) -> String:
	if value == null:
		return "—"
	if typeof(value) == TYPE_FLOAT:
		if is_equal_approx(float(value), roundf(float(value))):
			return str(int(roundf(float(value))))
		return String.num(value, 4)
	return str(value)


func _md_row(cells: Array) -> String:
	var parts: Array = []
	for cell in cells:
		parts.append(_md_text(String(cell)))
	return "| " + " | ".join(parts) + " |"


func _md_text(text: String) -> String:
	return text.replace("|", "\\|").replace("\n", " ")


func _fail(message: String, code := EXIT_FAILURE) -> void:
	printerr("AncientBuilding CLI: %s" % message)
	_emit({"error": message})
	quit(code)


func _emit(payload: Variant) -> void:
	print(JSON.stringify(payload, "  "))


func _print_usage() -> void:
	print("AncientBuilding CLI")
	print("  list-modules")
	print("  describe --id <module_id>")
	print("  validate --file <descriptor.json>   校验描述与布局，不构建")
	print("  build --file <descriptor.json>      构建到内存，不保存场景")
	print("  stats --file <descriptor.json>      实例/唯一网格/三角面/策略统计")
	print("  params [--format md|json] [--out <path>]  生成参数参考")
	print("  bake --file <descriptor.json> [--out <scene.tscn>]")
	print("  convert --scene <scene.tscn>")
	print("  revert --scene <scene.tscn>")
	print("  inspect --scene <scene.tscn>")
	print("  help")
	print("退出码：0 成功；1 描述/参数校验失败；2 构建/保存/用法错误")
