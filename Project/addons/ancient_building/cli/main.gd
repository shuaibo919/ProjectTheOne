extends SceneTree
## AncientBuilding CLI（headless 宿主）。
## 用法：
##   godot --headless --path Project --script res://addons/ancient_building/cli/main.gd -- list-modules
##   godot --headless --path Project --script res://addons/ancient_building/cli/main.gd -- describe F01

const Registry = preload("res://addons/ancient_building/core/module_registry.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var command := "help" if args.is_empty() else String(args[0])
	match command:
		"list-modules":
			_cmd_list_modules()
		"describe":
			_cmd_describe(args)
		"help", "--help", "-h":
			_print_usage()
			quit(0)
		_:
			printerr("AncientBuilding CLI: unknown command '%s'" % command)
			_print_usage()
			quit(2)


func _cmd_list_modules() -> void:
	var modules: Array = Registry.all_modules()
	var errors: Array = Registry.errors()
	var payload := {
		"generator_version": Registry.generator_version(),
		"count": modules.size(),
		"layers": _layer_counts(),
		"errors": errors,
		"modules": modules,
	}
	_emit(payload)
	quit(0 if errors.is_empty() else 1)


func _cmd_describe(args: PackedStringArray) -> void:
	if args.size() < 2:
		printerr("usage: describe <module_id>")
		quit(2)
		return
	var meta := Registry.get_module(String(args[1]))
	if meta.is_empty():
		printerr("unknown module: %s" % args[1])
		quit(1)
		return
	_emit(meta)
	quit(0)


func _layer_counts() -> Dictionary:
	var out: Dictionary = {}
	for layer in Registry.VALID_LAYERS:
		out[layer] = Registry.modules_in_layer(layer).size()
	return out


func _emit(payload: Variant) -> void:
	print(JSON.stringify(payload, "  "))


func _print_usage() -> void:
	print("AncientBuilding CLI")
	print("  list-modules          列出全部模块（JSON）")
	print("  describe <module_id>  输出单个模块定义")
	print("  help                  显示本帮助")
