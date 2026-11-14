@tool
extends VBoxContainer
## 俯视线段编辑；拖动结束才通知生成器，撤销保存整个轻量描述。
signal changed(plan: Dictionary)

var plan: Dictionary = {"nodes":[], "segments":[]}
var selected_node := -1
var selected_segment := -1
var drawing := false
var snap := 0.5
var angle_snap := true
var inherited_construction := "frame"
var inherited_covering := "tile"
var center := Vector2.ZERO
var zoom := 18.0
var _undo: Array = []
var _redo: Array = []
var _canvas: Control
var _properties: VBoxContainer
var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_snapshot: Dictionary = {}


class PlanCanvas extends Control:
	var controller: VBoxContainer

	func _draw() -> void:
		draw_style_box(get_theme_stylebox("panel", "Tree"), Rect2(Vector2.ZERO, size))
		var step: float = maxf(1.0, controller.snap) * controller.zoom
		var origin: Vector2 = size * 0.5 - controller.center * controller.zoom
		for x in range(floori(-origin.x / step), ceili((size.x - origin.x) / step)):
			draw_line(Vector2(origin.x + x * step, 0), Vector2(origin.x + x * step, size.y), Color(0.3,0.34,0.4,0.22))
		for y in range(floori(-origin.y / step), ceili((size.y - origin.y) / step)):
			draw_line(Vector2(0, origin.y + y * step), Vector2(size.x, origin.y + y * step), Color(0.3,0.34,0.4,0.22))
		var font := ThemeDB.fallback_font
		for i in controller.plan.segments.size():
			var segment: Dictionary = controller.plan.segments[i]
			var a: Vector2 = controller.screen(controller.node_position(segment.a))
			var b: Vector2 = controller.screen(controller.node_position(segment.b))
			var color := Color("68b7bb") if i != controller.selected_segment else Color("efbe68")
			draw_line(a, b, Color(color, 0.18), float(segment.get("width",4.0)) * controller.zoom, true)
			draw_line(a, b, color, 2.0, true)
			draw_string(font, (a + b) * 0.5 + Vector2(3,-6), "%s · %d层" % [segment.id,segment.get("storeys",1)],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
		for i in controller.plan.nodes.size():
			var node: Dictionary = controller.plan.nodes[i]
			var p: Vector2 = controller.screen(Vector2(node.position[0], node.position[1]))
			draw_circle(p, 6, Color("ffd991") if i == controller.selected_node else Color("c6d4de"))
			draw_string(font, p + Vector2(8,14), node.id, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d6dde2"))

	func _gui_input(event: InputEvent) -> void:
		controller.handle_input(event)


static func default_plan() -> Dictionary:
	return {"nodes":[{"id":"N1","position":[-9.0,0.0]}, {"id":"N2","position":[-3.0,0.0]},
		{"id":"N3","position":[3.0,0.0]}, {"id":"N4","position":[9.0,-4.0]}],
		"segments":[{"id":"S1","a":"N1","b":"N2","width":4.0,"storeys":1,"floor_height":3.0},
		{"id":"S2","a":"N2","b":"N3","width":4.0,"storeys":2,"floor_height":3.0},
		{"id":"S3","a":"N3","b":"N4","width":4.0,"storeys":1,"floor_height":3.0}]}


func _ready() -> void:
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	var mode := OptionButton.new()
	mode.add_item("选择 / 拖动")
	mode.add_item("连续绘制")
	mode.item_selected.connect(func(index: int) -> void: drawing = index == 1)
	toolbar.add_child(mode)
	for entry in [["撤销", undo], ["重做", redo], ["删除", delete_selected]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		toolbar.add_child(button)
	var note := Label.new()
	note.text = "绘制：点击空白建点，点击已有点连接；右键结束。滚轮缩放，中键平移。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	var options := HBoxContainer.new()
	add_child(options)
	var snap_label := Label.new()
	snap_label.text = "网格 (m)"
	options.add_child(snap_label)
	var snap_value := SpinBox.new()
	snap_value.min_value = 0.1
	snap_value.max_value = 2.0
	snap_value.step = 0.1
	snap_value.value = snap
	snap_value.value_changed.connect(func(value: float) -> void: snap = value)
	options.add_child(snap_value)
	var angle := CheckBox.new()
	angle.text = "45° 吸附"
	angle.button_pressed = true
	angle.toggled.connect(func(value: bool) -> void: angle_snap = value)
	options.add_child(angle)
	_canvas = PlanCanvas.new()
	_canvas.controller = self
	_canvas.custom_minimum_size = Vector2(300,260)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.focus_mode = Control.FOCUS_ALL
	add_child(_canvas)
	_properties = VBoxContainer.new()
	add_child(_properties)
	_refresh_properties()


func set_plan(value: Dictionary) -> void:
	plan = value.duplicate(true)
	selected_node = -1
	selected_segment = 0 if not plan.get("segments", []).is_empty() else -1
	if _canvas != null:
		if not plan.nodes.is_empty():
			var bounds := Rect2(node_position(plan.nodes[0].id), Vector2.ZERO)
			for node in plan.nodes:
				bounds = bounds.expand(node_position(node.id))
			center = bounds.get_center()
			zoom = clampf(minf(250.0 / maxf(bounds.size.x, 1.0), 200.0 / maxf(bounds.size.y, 1.0)), 4, 30)
		_refresh_properties()
		_canvas.queue_redraw()


func node_position(id: String) -> Vector2:
	for node in plan.nodes:
		if node.id == id:
			return Vector2(node.position[0], node.position[1])
	return Vector2.ZERO


func screen(point: Vector2) -> Vector2:
	return (point - center) * zoom + _canvas.size * 0.5


func world(point: Vector2) -> Vector2:
	return (point - _canvas.size * 0.5) / zoom + center


func _snapshot() -> void:
	_undo.append(plan.duplicate(true))
	if _undo.size() > 64:
		_undo.pop_front()
	_redo.clear()


func _notify() -> void:
	_refresh_properties()
	_canvas.queue_redraw()
	changed.emit(plan.duplicate(true))


func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(plan.duplicate(true))
	plan = _undo.pop_back()
	selected_node = -1
	selected_segment = -1
	_notify()


func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(plan.duplicate(true))
	plan = _redo.pop_back()
	selected_node = -1
	selected_segment = -1
	_notify()


func _next_id(prefix: String, entries: Array) -> String:
	var index := 1
	while true:
		var found := false
		for entry in entries:
			if entry.id == prefix + str(index):
				found = true
		if not found:
			return prefix + str(index)
		index += 1
	return ""


func draw_point(position: Vector2, target := -1) -> void:
	_snapshot()
	var previous := selected_node
	if target < 0:
		position = position.snapped(Vector2.ONE * snap)
		if previous >= 0 and angle_snap:
			var origin := node_position(plan.nodes[previous].id)
			var delta := position - origin
			var angle := snappedf(delta.angle(), PI * 0.25)
			position = origin + Vector2.from_angle(angle) * snappedf(delta.length(), snap)
		plan.nodes.append({"id":_next_id("N",plan.nodes), "position":[position.x,position.y]})
		target = plan.nodes.size() - 1
	if previous >= 0 and previous != target:
		var a: String = plan.nodes[previous].id
		var b: String = plan.nodes[target].id
		var exists := false
		for segment in plan.segments:
			exists = exists or (segment.a == a and segment.b == b) or (segment.a == b and segment.b == a)
		if not exists:
			plan.segments.append({"id":_next_id("S",plan.segments), "a":a,"b":b,
				"width":4.0,"storeys":1,"floor_height":3.0})
	selected_node = target
	selected_segment = -1
	_notify()


func delete_selected() -> void:
	if selected_node < 0 and selected_segment < 0:
		return
	_snapshot()
	if selected_node >= 0:
		var id: String = plan.nodes[selected_node].id
		plan.nodes.remove_at(selected_node)
		plan.segments = plan.segments.filter(func(s: Dictionary) -> bool: return s.a != id and s.b != id)
	else:
		plan.segments.remove_at(selected_segment)
	selected_node = -1
	selected_segment = -1
	_notify()


func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			zoom = clampf(zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 4, 80)
			_canvas.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			selected_node = -1
			_canvas.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_canvas.grab_focus()
				var hit := -1
				for i in plan.nodes.size():
					if screen(node_position(plan.nodes[i].id)).distance_to(event.position) < 10:
						hit = i
				if drawing:
					draw_point(world(event.position), hit)
				else:
					selected_node = hit
					selected_segment = -1
					_dragging = hit >= 0
					_drag_start = event.position
					_drag_snapshot = plan.duplicate(true)
					if hit < 0:
						for i in plan.segments.size():
							var s: Dictionary = plan.segments[i]
							var near := Geometry2D.get_closest_point_to_segment(event.position,
								screen(node_position(s.a)),screen(node_position(s.b)))
							if near.distance_to(event.position) < 12:
								selected_segment = i
					_refresh_properties()
					_canvas.queue_redraw()
			elif _dragging:
				_dragging = false
				if event.position.distance_to(_drag_start) > 2:
					_undo.append(_drag_snapshot)
					_redo.clear()
					_notify()
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			center -= event.relative / zoom
			_canvas.queue_redraw()
		elif _dragging and selected_node >= 0:
			var point := world(event.position).snapped(Vector2.ONE * snap)
			plan.nodes[selected_node].position = [point.x,point.y]
			_canvas.queue_redraw()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_DELETE:
			delete_selected()
		elif event.ctrl_pressed and event.keycode == KEY_Z:
			undo()
		elif event.ctrl_pressed and event.keycode == KEY_Y:
			redo()
	_canvas.accept_event()


func _refresh_properties() -> void:
	if _properties == null:
		return
	for child in _properties.get_children():
		_properties.remove_child(child)
		child.queue_free()
	var title := Label.new()
	_properties.add_child(title)
	if selected_node >= 0 and selected_node < plan.nodes.size():
		title.text = "节点 " + plan.nodes[selected_node].id
		for axis in 2:
			_number("X (m)" if axis == 0 else "Z (m)", plan.nodes[selected_node].position[axis], -250,250,0.1,
				func(value: float) -> void:
					_snapshot()
					plan.nodes[selected_node].position[axis] = value
					changed.emit(plan.duplicate(true))
					_canvas.queue_redraw())
	elif selected_segment >= 0 and selected_segment < plan.segments.size():
		var segment: Dictionary = plan.segments[selected_segment]
		title.text = "线段 %s · %s → %s" % [segment.id,segment.a,segment.b]
		for field in ["width","storeys","floor_height"]:
			_number({"width":"宽度 (m)","storeys":"层数","floor_height":"每层高度 (m)"}[field],
				segment.get(field,{"width":4.0,"storeys":1,"floor_height":3.0}[field]),
				1 if field=="storeys" else (2 if field=="width" else 2.4),
				8 if field=="storeys" else (10 if field=="width" else 4.5),1 if field=="storeys" else 0.1,
				func(value: float) -> void: _set_segment(field,int(value) if field=="storeys" else value))
		for field in ["construction","roof_covering","roof_form"]:
			var choices: Array = {"construction":["frame","earth","timber","log"],
				"roof_covering":["tile","thatch"],"roof_form":["overhang","hip"]}[field]
			var option := OptionButton.new()
			for choice in choices:
				option.add_item({"frame":"木框架灰墙","earth":"土混木","timber":"木板围护","log":"垒木围护",
					"tile":"瓦顶","thatch":"茅草顶","overhang":"悬山","hip":"庑殿"}[choice])
			var fallback := inherited_construction if field == "construction" else (inherited_covering if field == "roof_covering" else "overhang")
			option.select(maxi(0,choices.find(segment.get(field,fallback))))
			option.item_selected.connect(func(index: int) -> void: _set_segment(field,choices[index]))
			_properties.add_child(option)
		var open := CheckBox.new()
		open.text = "敞侧连廊（保留柱梁）"
		open.button_pressed = segment.get("open_sides",false)
		open.toggled.connect(func(value: bool) -> void: _set_segment("open_sides",value))
		_properties.add_child(open)
	else:
		title.text = "选择节点或线段以编辑"


func _set_segment(field: String, value: Variant) -> void:
	_snapshot()
	plan.segments[selected_segment][field] = value
	_canvas.queue_redraw()
	changed.emit(plan.duplicate(true))


func _number(label_text: String, value: float, low: float, high: float, step: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	_properties.add_child(row)
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	var input := SpinBox.new()
	input.min_value = low
	input.max_value = high
	input.step = step
	input.value = value
	input.value_changed.connect(callback)
	row.add_child(input)
