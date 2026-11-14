@tool
extends EditorPlugin
## AncientBuilding 编辑器插件入口：注册右侧 dock。

const DockScript := preload("res://addons/ancient_building/editor/dock.gd")

var _dock: Control


func _enter_tree() -> void:
	_dock = DockScript.new()
	_dock.name = "AncientBuilding"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
