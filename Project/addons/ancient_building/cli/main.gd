extends SceneTree
## AncientBuilding CLI（headless）。
## 用法示例：
##   ... -- list-modules
##   ... -- describe F01
##   ... -- build --file res://addons/ancient_building/resources/presets/DA_House_A.json
##   ... -- bake --file <json> --out res://Generated/AncientBuilding/Samples/DA_House_A.tscn
##   ... -- convert --scene <tscn>
##   ... -- revert --scene <tscn>
##   ... -- inspect --scene <tscn>

const Registry := preload("res://addons/ancient_building/core/module_registry.gd")
const Descriptor := preload("res://addons/ancient_building/core/descriptor.gd")
const Planner := preload("res://addons/ancient_building/core/layout_planner.gd")
const CacheScript := preload("res://addons/ancient_building/core/mesh_cache.gd")
const Assembler := preload("res://addons/ancient_building/core/assembler.gd")
const Batcher := preload("res://addons/ancient_building/core/scene_batcher.gd")

const CACHE_ROOT := "res://Generated/AncientBuilding"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		_print_usage()
		quit(0)
		return
	var command := String(args[0])
	var options := _parse_options(args)

	match command:
		"list-modules":
			_cmd_list_modules()
		"describe":
			_cmd_describe(options)
		"build", "stats":
			_cmd_build(options)
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
			quit(0)
		_:
			printerr("AncientBuilding CLI: unknown command '%s'" % command)
			_print_usage()
			quit(2)


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
	quit(0 if errors.is_empty() else 1)


func _cmd_describe(options: Dictionary) -> void:
	var module_id := String(options.get("id", ""))
	if module_id.is_empty():
		printerr("usage: describe --id <module_id>")
		quit(2)
		return
	var meta := Registry.get_module(module_id)
	if meta.is_empty():
		printerr("unknown module: %s" % module_id)
		quit(1)
		return
	_emit(meta)
	quit(0)


func _cmd_build(options: Dictionary) -> void:
	var path := String(options.get("file", ""))
	var descriptor := Descriptor.load_file(path)
	if not String(descriptor.get("error", "")).is_empty():
		_fail(String(descriptor["error"]))
		return

	var plan := Planner.plan(descriptor["modules"])
	var stats := Assembler.stats(plan)
	_emit({
		"name": descriptor["name"],
		"layout_hash": plan["layout_hash"],
		"instances": stats["instances"],
		"unique_meshes": stats["unique_meshes"],
		"modules": stats["modules"],
		"errors": plan["errors"],
	})
	quit(0 if plan["errors"].is_empty() else 1)


func _cmd_bake(options: Dictionary) -> void:
	var path := String(options.get("file", ""))
	var descriptor := Descriptor.load_file(path)
	if not String(descriptor.get("error", "")).is_empty():
		_fail(String(descriptor["error"]))
		return
	if descriptor["modules"].is_empty():
		_fail("descriptor has no modules")
		return

	var plan := Planner.plan(descriptor["modules"])
	if not plan["errors"].is_empty():
		_emit({"errors": plan["errors"]})
		quit(1)
		return

	var cache := CacheScript.new("%s/Meshes" % CACHE_ROOT, Registry.generator_version())
	var root := Assembler.build(plan, cache)
	root.name = String(descriptor["name"])
	root.set_meta("ab_descriptor", descriptor)
	root.set_meta("ab_layout_hash", plan["layout_hash"])

	var out_path := String(options.get("out", "%s/Samples/%s.tscn" % [CACHE_ROOT, descriptor["name"]]))
	_ensure_dir(out_path.get_base_dir())
	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
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
	quit(0)


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
	quit(0)


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

	var plan := Planner.plan(descriptor["modules"])
	var cache := CacheScript.new("%s/Meshes" % CACHE_ROOT, Registry.generator_version())
	Batcher.revert(root, plan, cache)
	var save_error := _save(root, scene_path)
	root.free()
	if save_error != OK:
		_fail("save failed: %s" % error_string(save_error))
		return
	var stats := Assembler.stats(plan)
	_emit({"scene": scene_path, "mode": "individual", "instances": stats["instances"]})
	quit(0)


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
	quit(0)


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


func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)


func _layer_counts() -> Dictionary:
	var out: Dictionary = {}
	for layer in Registry.VALID_LAYERS:
		out[layer] = Registry.modules_in_layer(layer).size()
	return out


func _fail(message: String) -> void:
	printerr("AncientBuilding CLI: %s" % message)
	_emit({"error": message})
	quit(1)


func _emit(payload: Variant) -> void:
	print(JSON.stringify(payload, "  "))


func _print_usage() -> void:
	print("AncientBuilding CLI")
	print("  list-modules")
	print("  describe --id <module_id>")
	print("  build --file <descriptor.json>")
	print("  bake --file <descriptor.json> [--out <scene.tscn>]")
	print("  convert --scene <scene.tscn>")
	print("  revert --scene <scene.tscn>")
	print("  inspect --scene <scene.tscn>")
	print("  help")
