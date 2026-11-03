extends SceneTree
## 构建冒烟测试：确认 GDExtension 已加载且 TheOneNode 已注册。
## 运行：
##   Engine/bin/godot.windows.editor.x86_64.console.exe --headless --path Project --script res://Tests/smoke_extension.gd

func _initialize() -> void:
	if not ClassDB.class_exists("TheOneNode"):
		printerr("SMOKE_FAIL: TheOneNode is not registered (GDExtension not loaded?)")
		quit(1)
		return
	var node: Object = ClassDB.instantiate("TheOneNode")
	if node == null:
		printerr("SMOKE_FAIL: TheOneNode could not be instantiated")
		quit(1)
		return
	print("SMOKE_OK: ", node.call("get_build_info"))
	node.free()
	quit(0)