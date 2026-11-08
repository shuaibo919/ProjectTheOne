extends SceneTree
## 扩展冒烟：确认两个独立 GDExtension 都已加载并注册各自的类。
## 运行：
##   Tools/Build/test-extension.sh
##   godot --headless --path Project --script res://Tests/smoke_extension.gd

const REQUIRED_CLASSES := ["TheOneNode", "ModuleKey", "AncientBuildingModule"]


func _initialize() -> void:
	for required in REQUIRED_CLASSES:
		if not ClassDB.class_exists(required):
			printerr("SMOKE_FAIL: %s is not registered (extension missing?)" % required)
			quit(1)
			return

	var node: Object = ClassDB.instantiate("TheOneNode")
	var info: Object = ClassDB.instantiate("AncientBuildingModule")
	if node == null or info == null:
		printerr("SMOKE_FAIL: could not instantiate extension classes")
		quit(1)
		return

	print("SMOKE_OK: core=%s / ancient_building=%s" % [node.call("get_build_info"), info.call("get_version")])
	node.free()
	info = null  # RefCounted：不要 free()，置空让引用计数回收
	quit(0)
