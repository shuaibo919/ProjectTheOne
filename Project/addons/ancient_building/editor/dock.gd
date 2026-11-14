@tool
extends Control
## AncientBuilding 编辑器 Dock（M6）。
## 左：71 模块目录 / 当前建筑摆放；右：SubViewport 预览 + 参数编辑。
## 所有构建逻辑走 core/，Dock 只负责收集参数和展示。

const Descriptor := preload("res://addons/ancient_building/core/descriptor.gd")
const Registry := preload("res://addons/ancient_building/core/module_registry.gd")
const Params := preload("res://addons/ancient_building/core/module_params.gd")
const Assembler := preload("res://addons/ancient_building/core/assembler.gd")
const Materials := preload("res://addons/ancient_building/core/material_library.gd")
const Batcher := preload("res://addons/ancient_building/core/scene_batcher.gd")
const AssemblyBaker := preload("res://addons/ancient_building/core/assembly_baker.gd")
const Preview := preload("res://addons/ancient_building/core/preview_builder.gd")
const ModuleMesh := preload("res://addons/ancient_building/core/module_mesh.gd")
const Variation := preload("res://addons/ancient_building/core/building_variation.gd")

const Job := preload("res://addons/ancient_building/core/preview_job.gd")
const Cache := preload("res://addons/ancient_building/core/mesh_cache.gd")

const PlanEditor := preload("res://addons/ancient_building/editor/plan_editor.gd")

const PRESET_DIR := "res://addons/ancient_building/resources/presets"
const SAMPLE_DIR := "res://Generated/AncientBuilding/Samples"

var _plan_editor: VBoxContainer
var _recipe_box: VBoxContainer
var _orbit_target := Vector3.ZERO
var _orbit_distance := 1.0
var _orbit := Vector2(0.48,0.31)
var _preset_select: OptionButton
var _catalog_tree: Tree
var _placement_tree: Tree
var _param_box: VBoxContainer
var _status: Label
var _stats_label: Label
var _bake_path: LineEdit
var _add_button: Button
var _remove_button: Button
var _viewport: SubViewport
var _camera: Camera3D
var _debounce: Timer

var _descriptor: Dictionary = {}
var _preset_file := ""
var _selected_placement := -1
var _catalog_id := ""
var _preview_root: Node3D
var _plan: Dictionary = {}
var _cache: Variant = null
var _last_build_ms := 0
var _syncing := false
var _recipe_controls: Dictionary = {}
var _detail_controls: Dictionary = {}
var _recipe_message := ""
var _occlusion_toggle: CheckBox
var _occluder_root: Node3D
var _revision := 0
var _published_revision := -1
var _job: RefCounted
var _job_due := false
var _session := {}
var _stage := {}
var _retired: Array[Node] = []
var _pending_action := ""
var _request_started := 0
var _worker_ms := 0
var _last_reused := 0
var _last_new_meshes := 0
var _main_slice_peak_ms := 0.0
var _finishing := false
var _variation_controls := {}
const MAIN_BUDGET_USEC := 3000


func _ready() -> void:
	_build_ui()
	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = 0.12
	add_child(_debounce)
	_debounce.timeout.connect(_begin_requested_preview)
	_rebuild_catalog_tree()
	call_deferred("_reload_presets")
	print("[AncientBuilding] dock ready")


# ── UI ────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	_preset_select = OptionButton.new()
	_preset_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_select.tooltip_text = "加载 resources/presets 下的建筑描述"
	_preset_select.item_selected.connect(_on_preset_selected)
	top.add_child(_preset_select)
	var reload := Button.new()
	reload.text = "重载"
	reload.tooltip_text = "重新从磁盘加载当前预设"
	reload.pressed.connect(_reload_current_preset)
	top.add_child(reload)
	var save := Button.new()
	save.text = "保存预设"
	save.tooltip_text = "把当前摆放写回 presets/<name>.json"
	save.pressed.connect(_save_preset)
	top.add_child(save)

	var actions := HBoxContainer.new()
	root.add_child(actions)
	actions.add_child(_make_button("构建预览", _rebuild_preview))
	actions.add_child(_make_button("烘焙场景", _bake_scene))
	actions.add_child(_make_button("烘焙装配体", _bake_assembly))
	actions.add_child(_make_button("Convert", _convert_preview))
	actions.add_child(_make_button("Revert", _rebuild_preview))
	actions.add_child(_make_button("Stats", _update_stats))
	_occlusion_toggle = CheckBox.new()
	_occlusion_toggle.text = "实墙遮挡剔除（预览）"
	_occlusion_toggle.tooltip_text = "只使用实墙遮挡体，保持门洞和格心可见；MultiMesh 按整组剔除。"
	_occlusion_toggle.toggled.connect(_toggle_occlusion)
	root.add_child(_occlusion_toggle)

	_bake_path = LineEdit.new()
	_bake_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bake_path.text = SAMPLE_DIR + "/DA_House_A.tscn"
	root.add_child(_bake_path)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(270.0, 0.0)
	split.add_child(tabs)

	var catalog_page := VBoxContainer.new()
	tabs.add_child(catalog_page)
	catalog_page.name = "模块目录"
	_catalog_tree = Tree.new()
	_catalog_tree.hide_root = true
	_catalog_tree.custom_minimum_size = Vector2(250.0, 220.0)
	_catalog_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_catalog_tree.item_selected.connect(_on_catalog_selected)
	catalog_page.add_child(_catalog_tree)
	_add_button = _make_button("添加到建筑", _add_catalog_module)
	_add_button.disabled = true
	catalog_page.add_child(_add_button)

	var recipe_page := ScrollContainer.new()
	tabs.add_child(recipe_page)
	recipe_page.name = "建筑形制"
	_recipe_box = VBoxContainer.new()
	_recipe_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_page.add_child(_recipe_box)

	var placement_page := VBoxContainer.new()
	tabs.add_child(placement_page)
	placement_page.name = "当前建筑"
	_placement_tree = Tree.new()
	_placement_tree.hide_root = true
	_placement_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_placement_tree.item_selected.connect(_on_placement_selected)
	placement_page.add_child(_placement_tree)
	_remove_button = _make_button("删除选中模块", _delete_selected_placement)
	placement_page.add_child(_remove_button)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(380.0, 240.0)
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(preview_panel)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.gui_input.connect(_preview_input)
	container.tooltip_text = "左键拖动环绕，滚轮缩放，Shift 拖动平移"
	preview_panel.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800, 520)
	# Millimetre-scale relief needs coverage AA at normal viewing distances.
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.own_world_3d = true
	_viewport.world_3d = World3D.new()
	container.add_child(_viewport)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#637b92")
	sky_material.sky_horizon_color = Color("#b9b9ad")
	sky_material.ground_bottom_color = Color("#37312a")
	sky_material.ground_horizon_color = Color("#a29a88")
	var reflection_sky := Sky.new()
	reflection_sky.sky_material = sky_material
	env.sky = reflection_sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.075, 0.085, 0.105)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.45, 0.50)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 0.32
	env.ssao_intensity = 1.15
	environment.environment = env
	_viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.current = true
	_viewport.add_child(_camera)

	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_stats_label)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 180.0)
	right.add_child(scroll)
	_param_box = VBoxContainer.new()
	_param_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_param_box)


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button


# ── 预设 ──────────────────────────────────────────────────────────────────

func _reload_presets() -> void:
	if _preset_select == null:
		return
	var current := _preset_file
	_preset_select.clear()
	var files := DirAccess.get_files_at(PRESET_DIR)
	var names := PackedStringArray()
	for file in files:
		if file.ends_with(".json"):
			names.append(file)
	names.sort()
	var select_index := 0
	var has_preferred := false
	for name in names:
		var path := PRESET_DIR + "/" + name
		_preset_select.add_item(name.get_basename())
		var item_index := _preset_select.item_count - 1
		_preset_select.set_item_metadata(item_index, path)
		if path == current:
			select_index = item_index
		elif current.is_empty() and not has_preferred and name.get_basename() == "DA_House_A":
			select_index = item_index
			has_preferred = true
	if _preset_select.item_count == 0:
		_set_status("presets 目录没有 JSON")
		return
	_preset_select.select(select_index)
	_load_preset(_preset_select.get_item_metadata(select_index))


func _on_preset_selected(index: int) -> void:
	var path: Variant = _preset_select.get_item_metadata(index)
	if typeof(path) == TYPE_STRING:
		_load_preset(String(path))


func _reload_current_preset() -> void:
	if _preset_file != "":
		_load_preset(_preset_file)


func _load_preset(path: String) -> void:
	var descriptor := Descriptor.load_file(path)
	if not String(descriptor.get("error", "")).is_empty():
		_set_status("加载失败: " + String(descriptor["error"]))
		return
	_descriptor = descriptor
	_recipe_message = ""
	_pending_action = ""
	_preset_file = path
	_refresh_recipe_controls()
	_orbit_distance = 0.0
	_selected_placement = -1
	_bake_path.text = "%s/%s.tscn" % [SAMPLE_DIR, String(descriptor.get("name", "Building"))]
	_rebuild_placement_tree()
	_select_first_placement()
	# 加载预设时立即出图；参数编辑仍走 120 ms 防抖。
	_rebuild_preview()


func _save_preset() -> void:
	if _descriptor.is_empty():
		return
	var modules: Array = []
	for entry in _descriptor.get("modules", []):
		var out: Dictionary = entry.duplicate(true)
		var position: Vector3 = entry.get("position", Vector3.ZERO)
		out["position"] = [position.x, position.y, position.z]
		if entry.has("width"):
			out["width"] = float(entry["width"])
		if entry.has("rotation_y"):
			out["rotation_y"] = float(entry["rotation_y"])
		modules.append(out)
	var payload := {
		"name": String(_descriptor.get("name", "Building")),
		"generator_version": Registry.generator_version(),
		"modules": modules,
	}
	for field in ["building","mesh_overrides"]:
		if not _descriptor.get(field,{}).is_empty():
			payload[field] = _descriptor[field]
	var path := _preset_file
	if not path.begins_with(PRESET_DIR):
		path = "%s/%s.json" % [PRESET_DIR, String(payload["name"])]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_set_status("保存失败: " + path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	_preset_file = path
	_set_status("已保存: " + path)


# ── 树 ────────────────────────────────────────────────────────────────────

func _rebuild_catalog_tree() -> void:
	_catalog_tree.clear()
	var root := _catalog_tree.create_item()
	for layer in Registry.VALID_LAYERS:
		var modules := Registry.modules_in_layer(layer)
		if modules.is_empty():
			continue
		var layer_item := root.create_child()
		layer_item.set_text(0, "%s (%d)" % [layer, modules.size()])
		layer_item.set_selectable(0, false)
		for module in modules:
			var item := layer_item.create_child()
			var suffix := "" if ModuleMesh.supports(String(module["id"])) else "  (unit box)"
			item.set_text(0, "%s  %s  [%s]%s" % [module["id"], module["name"], module["policy"], suffix])
			item.set_metadata(0, { "kind": "catalog", "id": String(module["id"]) })


func _rebuild_placement_tree() -> void:
	_placement_tree.clear()
	var root := _placement_tree.create_item()
	var modules: Array = _descriptor.get("modules", [])
	for index in modules.size():
		var entry: Dictionary = modules[index]
		var id := String(entry.get("id", "?"))
		var meta := Registry.get_module(id)
		var width := float(entry.get("width", meta.get("unit", 1.0)))
		var item := root.create_child()
		item.set_text(0, "#%d  %s %s  [%s]  w=%.2f" % [
			index, id, String(meta.get("name", "?")), String(meta.get("policy", "?")), width])
		item.set_metadata(0, { "kind": "placement", "index": index })


func _select_first_placement() -> void:
	var modules: Array = _descriptor.get("modules", [])
	if modules.is_empty():
		_clear_param_box()
		return
	var root := _placement_tree.get_root()
	if root != null and root.get_child_count() > 0:
		var item := root.get_child(0)
		item.select(0)
		_on_placement_selected()


func _on_catalog_selected() -> void:
	var item := _catalog_tree.get_selected()
	if item == null:
		_add_button.disabled = true
		return
	var meta: Variant = item.get_metadata(0)
	if typeof(meta) != TYPE_DICTIONARY or String(meta.get("kind", "")) != "catalog":
		_add_button.disabled = true
		return
	_catalog_id = String(meta["id"])
	_add_button.disabled = false
	_show_catalog_module(_catalog_id)


func _on_placement_selected() -> void:
	var item := _placement_tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if typeof(meta) == TYPE_DICTIONARY and String(meta.get("kind", "")) == "placement":
		_show_placement(int(meta["index"]))


# ── 参数面板 ──────────────────────────────────────────────────────────────

func _clear_param_box() -> void:
	for child in _param_box.get_children():
		child.queue_free()


func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_param_box.add_child(label)


func _show_catalog_module(module_id: String) -> void:
	_clear_param_box()
	var meta := Registry.get_module(module_id)
	_add_label("%s · %s" % [module_id, String(meta.get("name", "?"))])
	_add_label("层 %s · 策略 %s · 单元 %.2f m · MaxStretch %.2f" % [
		String(meta.get("layer", "?")), String(meta.get("policy", "?")),
		float(meta.get("unit", 1.0)), float(meta.get("max_stretch", 1.0))])
	if not ModuleMesh.supports(module_id):
		_add_label("注意：该模块还没有真实网格，预览/烘焙会使用 unit box 兜底。")
	var source := LineEdit.new()
	source.placeholder_text = "res://…/部件.res（留空使用程序网格）"
	source.text = String(_descriptor.get("mesh_overrides",{}).get(module_id,""))
	_param_box.add_child(source)
	var apply_source := Button.new()
	apply_source.text = "应用此构件的 Mesh"
	_param_box.add_child(apply_source)
	apply_source.pressed.connect(func() -> void:
		var path := source.text.strip_edges()
		if not path.is_empty() and not (ResourceLoader.exists(path) and load(path) is Mesh):
			_set_status("%s 需要可加载的 Mesh：%s" % [module_id,path])
			return
		var overrides: Dictionary = _descriptor.get("mesh_overrides",{})
		if path.is_empty():
			overrides.erase(module_id)
		else:
			overrides[module_id] = path
		_descriptor["mesh_overrides"] = overrides
		_schedule_preview())
	var schema := Params.schema(module_id)
	if schema.is_empty():
		_add_label("该模块暂无参数 schema（unit box 兜底）。")
		return
	for key in schema:
		var spec: Dictionary = schema[key]
		_add_label("%s: 默认 %.3f · 范围 %.3f ~ %.3f" % [
			key, float(spec.get("default", 0.0)),
			float(spec.get("min", 0.0)), float(spec.get("max", 0.0))])


func _show_placement(index: int) -> void:
	var modules: Array = _descriptor.get("modules", [])
	if index < 0 or index >= modules.size():
		return
	_selected_placement = index
	var entry: Dictionary = modules[index]
	var module_id := String(entry["id"])
	var meta := Registry.get_module(module_id)
	_clear_param_box()
	_add_label("%s · %s" % [module_id, String(meta.get("name", "?"))])
	_add_label("策略 %s · 层 %s" % [String(meta.get("policy", "?")), String(meta.get("layer", "?"))])

	if String(meta.get("policy", "")) != "A":
		_add_width_editor(entry, meta)
	_add_position_editor(entry)

	var schema := Params.schema(module_id)
	if entry.get("params", null) == null:
		entry["params"] = {}
	for key in schema:
		_add_param_editor(entry, key, schema[key])


func _add_width_editor(entry: Dictionary, meta: Dictionary) -> void:
	var width := float(entry.get("width", meta.get("unit", 1.0)))
	var row := HBoxContainer.new()
	_param_box.add_child(row)
	var label := Label.new()
	label.text = "宽度 (m)"
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.2
	slider.max_value = 20.0
	slider.step = 0.05
	slider.value = width
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var spin := SpinBox.new()
	spin.min_value = 0.2
	spin.max_value = 20.0
	spin.step = 0.05
	spin.value = width
	row.add_child(spin)
	slider.value_changed.connect(func(value: float) -> void:
		if _syncing:
			return
		_syncing = true
		spin.value = value
		_syncing = false
		entry["width"] = value
		_schedule_preview())
	spin.value_changed.connect(func(value: float) -> void:
		if _syncing:
			return
		_syncing = true
		slider.value = value
		_syncing = false
		entry["width"] = value
		_schedule_preview())


func _add_position_editor(entry: Dictionary) -> void:
	var position: Vector3 = entry.get("position", Vector3.ZERO)
	var values := [position.x, position.y, position.z]
	var row := HBoxContainer.new()
	_param_box.add_child(row)
	for axis in 3:
		row.add_child(_make_axis_spin(entry, axis, values[axis]))
	var rotation := SpinBox.new()
	rotation.min_value = -180.0
	rotation.max_value = 180.0
	rotation.step = 1.0
	rotation.value = float(entry.get("rotation_y", 0.0))
	rotation.suffix = "°"
	row.add_child(rotation)
	rotation.value_changed.connect(func(value: float) -> void:
		entry["rotation_y"] = value
		_schedule_preview())


func _make_axis_spin(entry: Dictionary, axis: int, value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = -50.0
	spin.max_value = 50.0
	spin.step = 0.05
	spin.value = value
	spin.prefix = ["X ", "Y ", "Z "][axis]
	spin.value_changed.connect(func(new_value: float) -> void:
		var current: Vector3 = entry.get("position", Vector3.ZERO)
		match axis:
			0:
				current.x = new_value
			1:
				current.y = new_value
			_:
				current.z = new_value
		entry["position"] = current
		_schedule_preview())
	return spin


func _add_param_editor(entry: Dictionary, key: String, spec: Dictionary) -> void:
	var params: Dictionary = entry["params"]
	var value := float(params.get(key, spec.get("default", 0.0)))
	var row := HBoxContainer.new()
	_param_box.add_child(row)
	var label := Label.new()
	label.text = {"damage":"几何破损", "damage_depth":"缺口深度 (m)", "damage_density":"受损密度", "damage_seed":"破损变体 (0–7)", "wall_kind":"围护 (0灰墙/1土/2板/3垒木)"}.get(key,key)
	label.custom_minimum_size = Vector2(92.0, 0.0)
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = float(spec.get("min", 0.0))
	spin.max_value = float(spec.get("max", 1000.0))
	spin.step = 1.0 if String(spec.get("type", "length")) == "int" else 0.01
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	spin.value_changed.connect(func(new_value: float) -> void:
		params[key] = new_value
		_schedule_preview())


# ── 预览 / 操作 ───────────────────────────────────────────────────────────

func _schedule_preview() -> void:
	_revision += 1
	if _job != null:
		_job.cancel()
	_discard_stage()
	_finishing = false
	if _debounce != null:
		_debounce.start()
	_set_status("参数已修改，等待本次操作结束…")


func _rebuild_preview() -> void:
	if _descriptor.is_empty():
		return
	_schedule_preview()
	_debounce.stop()
	_begin_requested_preview()


func _begin_requested_preview() -> void:
	_job_due = true


func is_preview_busy() -> bool:
	return _job != null or _job_due or not _stage.is_empty() or not _retired.is_empty() or _finishing or not _debounce.is_stopped()


func _editing_active() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_DOWN) or (_plan_editor != null and _plan_editor._dragging)


func _exit_tree() -> void:
	if _job != null:
		_job.shutdown()
		_job = null


func _process(_delta: float) -> void:
	if _debounce == null:
		return
	var started := Time.get_ticks_usec()
	var deadline := started + MAIN_BUDGET_USEC
	while not _retired.is_empty() and Time.get_ticks_usec() < deadline:
		var node := _retired.pop_back() as Node
		if is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.free()
	if _job != null and not _job.running():
		var version: int = _job.revision
		var result: Dictionary = _job.take_result()
		_job = null
		if version == _revision and not result.get("cancelled", false):
			if not result.get("errors", []).is_empty():
				_fail_preview(result.errors)
			else:
				_prepare_stage(result)
	if _job_due and _job == null and _stage.is_empty() and _debounce.is_stopped() and not _editing_active():
		if not ClassDB.class_exists("ModuleKey"):
			return
		if _cache == null:
			_cache = Cache.new("", Registry.generator_version())
		_job = Job.new()
		_request_started = Time.get_ticks_msec()
		_main_slice_peak_ms = 0.0
		var error: Error = _job.start(_revision, _descriptor, _cache.known_keys(), _session)
		_job_due = false
		if error != OK:
			_job = null
			_fail_preview(["无法启动预览线程: " + error_string(error)])
		else:
			_set_status("后台计算中；可继续编辑或旋转旧预览…")
	if not _stage.is_empty() and not _editing_active():
		_apply_stage(deadline)
	if _finishing and _retired.is_empty():
		_finishing = false
		_update_stats()
		if not _recipe_message.is_empty():
			_set_status(_recipe_message)
			_recipe_message = ""
		var action := _pending_action
		_pending_action = ""
		if action == "bake":
			_bake_scene()
		elif action == "assembly":
			_bake_assembly()
		elif action == "convert":
			_convert_preview()
	_main_slice_peak_ms = maxf(_main_slice_peak_ms, (Time.get_ticks_usec() - started) / 1000.0)


func _prepare_stage(result: Dictionary) -> void:
	if _preview_root == null:
		_preview_root = Node3D.new()
		_preview_root.name = "AncientBuilding"
		_viewport.add_child(_preview_root)
	var available := {}
	var old: Array = []
	for node in _preview_root.get_children():
		if node in _retired:
			continue
		old.append(node)
		if node is MeshInstance3D and node.has_meta("ab_instance_id"):
			var key := String(node.get_meta("ab_instance_id")) + ":" + String(node.get_meta("ab_key", ""))
			if not available.has(key):
				available[key] = []
			available[key].append(node)
	var external: Array = []
	for entry in result.plan.instances:
		var path := String(entry.get("mesh_path", ""))
		if not path.is_empty() and path not in external:
			external.append(path)
	_stage = {"result":result, "keys":result.data.keys(), "mesh_index":0, "instance_index":0,
		"external":external, "external_index":0, "loaded":{}, "available":available,
		"old":old, "keep":{}, "created":[], "reused":0}
	_set_status("几何就绪，分帧提交预览…")


func _apply_stage(deadline: int) -> void:
	var result: Dictionary = _stage.result
	while _stage.mesh_index < _stage.keys.size() and Time.get_ticks_usec() < deadline:
		var key: String = _stage.keys[_stage.mesh_index]
		_cache.put_data(key, result.data[key])
		result.data.erase(key)
		_stage.mesh_index += 1
	if _stage.mesh_index < _stage.keys.size():
		return
	while _stage.external_index < _stage.external.size() and Time.get_ticks_usec() < deadline:
		var path: String = _stage.external[_stage.external_index]
		var resource: Resource = load(path) if ResourceLoader.exists(path) else null
		if not resource is Mesh:
			_fail_preview(["外部资源不是可加载的 Mesh: " + path])
			return
		_stage.loaded[path] = resource
		_stage.external_index += 1
	if _stage.external_index < _stage.external.size():
		return
	var entries: Array = result.plan.instances
	while _stage.instance_index < entries.size() and Time.get_ticks_usec() < deadline:
		var index: int = _stage.instance_index
		var entry: Dictionary = entries[index]
		var identity := Assembler.identity(entry) + ":" + String(entry.key)
		var candidates: Array = _stage.available.get(identity, [])
		if not candidates.is_empty():
			var node: Node = candidates.pop_back()
			_stage.keep[node.get_instance_id()] = true
			_stage.reused += 1
		else:
			var node := Assembler.create_instance(entry, _cache, index, _stage.loaded.get(entry.get("mesh_path", "")))
			node.visible = false
			_preview_root.add_child(node)
			node.owner = _preview_root
			_stage.created.append(node)
		_stage.instance_index += 1
	if _stage.instance_index < entries.size() or Time.get_ticks_usec() >= deadline:
		return
	# 提交屏障：准备期间旧画面保持完整，只有最新版本才切换。
	for node in _stage.old:
		if not _stage.keep.has(node.get_instance_id()):
			node.visible = false
			_retired.append(node)
	for node in _stage.created:
		node.visible = true
	_plan = result.plan
	_session = result.session
	_worker_ms = result.worker_ms
	_last_new_meshes = _stage.keys.size()
	_last_reused = _stage.reused
	_last_build_ms = Time.get_ticks_msec() - _request_started
	_published_revision = _revision
	_preview_root.set_meta("ab_descriptor", result.descriptor)
	# 后台几何计算期间也可修改材质；提交时使用最新表面设置。
	_refresh_surface_materials(false)
	_preview_root.set_meta("ab_layout_hash", _plan.layout_hash)
	_preview_root.set_meta("ab_state", {"mode":"individual", "instances":entries.size()})
	if _orbit_distance <= 0.0:
		var box := Preview.bounds(_preview_root)
		_orbit_target = box.get_center()
		_orbit_distance = box.size.length() * 1.5
	_update_camera()
	_cache.retain_plan(entries)
	_stage = {}
	_refresh_occluders()
	_finishing = true


func _discard_stage() -> void:
	if not _stage.is_empty():
		for node in _stage.created:
			_retired.append(node)
		_stage = {}


func _fail_preview(errors: Array) -> void:
	_discard_stage()
	_plan = {"errors":errors}
	_pending_action = ""
	_set_status("构建失败（保留上次有效预览，当前不可烘焙）: " + str(errors))


func _ready_for_action(action: String) -> bool:
	if is_preview_busy() or (_published_revision != _revision and _plan.get("errors", []).is_empty()):
		_pending_action = action
		if not _debounce.is_stopped():
			_debounce.stop()
			_begin_requested_preview()
		elif not is_preview_busy():
			_begin_requested_preview()
		_set_status("操作已排队，等待最新有效预览…")
		return false
	if not _plan.get("errors", []).is_empty():
		_set_status(str(_plan.errors))
		return false
	return _preview_root != null and _published_revision == _revision


func _update_stats() -> void:
	if _plan.is_empty() or not _plan.get("errors", []).is_empty():
		return
	var stats := Assembler.stats(_plan)
	var instances := int(stats.get("instances", 0))
	var unique := int(stats.get("unique_meshes", 0))
	var dedup := 0.0 if instances == 0 else 100.0 * (1.0 - float(unique) / float(instances))
	_stats_label.text = "实例 %d · 网格 %d · 去重 %.1f%% · 重建 %d ms · hash %s" % [
		instances, unique, dedup, _last_build_ms, String(_plan.get("layout_hash", ""))]
	if _preview_root != null:
		var state: Dictionary = _preview_root.get_meta("ab_state", {})
		var mode := "MultiMesh 整组" if state.get("mode", "") == "multimesh" else "独立 MeshInstance"
		var occluders := _occluder_root.get_child_count() if _occluder_root != null else 0
		_stats_label.text += "\n%s · 渲染节点 %d · 实墙遮挡体 %d（非 draw call 统计）" % [
			mode, _preview_root.get_child_count(), occluders]
	_stats_label.text += "\n后台 %d ms · 复用节点 %d · 新网格 %d · 主线程单帧峰值 %.1f ms" % [_worker_ms, _last_reused, _last_new_meshes, _main_slice_peak_ms]
	print("[AncientBuilding] preview ready instances=%d unique=%d ms=%d" % [instances, unique, _last_build_ms])
	_set_status("预览已更新")


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func _bake_scene() -> void:
	if not _ready_for_action("bake"):
		return
	DirAccess.make_dir_recursive_absolute(SAMPLE_DIR)
	var path := _bake_path.text.strip_edges()
	if path.is_empty():
		path = "%s/%s.tscn" % [SAMPLE_DIR, String(_descriptor.get("name", "Building"))]
	_preview_root.set_meta("ab_descriptor", _descriptor.duplicate(true))
	_preview_root.set_meta("ab_layout_hash", String(_plan.get("layout_hash", "")))
	var packed := PackedScene.new()
	var pack_error := packed.pack(_preview_root)
	if pack_error != OK:
		_set_status("pack 失败: " + error_string(pack_error))
		return
	var save_error := ResourceSaver.save(packed, path)
	if save_error != OK:
		_set_status("保存失败: " + error_string(save_error))
		return
	_set_status("已烘焙: " + path)


func _bake_assembly() -> void:
	if not _ready_for_action("assembly"):
		return
	var result := AssemblyBaker.bake(_descriptor.duplicate(true), {"source_path": _preset_file})
	if result.has("error"):
		_set_status("装配体失败: " + String(result["error"]))
		return
	_set_status("已烘焙装配体: %s（%d 实例 / %d Mesh）" % [
		String(result.get("assembly", "")),
		int(result.get("instances", 0)),
		int(result.get("unique_meshes", 0)),
	])


func _convert_preview() -> void:
	if not _ready_for_action("convert"):
		return
	var result := Batcher.convert(_preview_root)
	_update_stats()
	_set_status("已转换: %d 组 / %d 实例" % [int(result["groups"]), int(result["instances"])])


func _toggle_occlusion(enabled: bool) -> void:
	_viewport.use_occlusion_culling = enabled
	# Convert 后保留已有实墙代理；首次开启则由描述恢复后建立。
	if enabled and _preview_root != null and _preview_root.get_meta("ab_state", {}).get("mode", "") == "multimesh":
		_rebuild_preview()
		_convert_preview()
	else:
		_refresh_occluders()
	_update_stats()


func _refresh_occluders() -> void:
	if _occluder_root != null:
		_viewport.remove_child(_occluder_root)
		_occluder_root.queue_free()
		_occluder_root = null
	if _occlusion_toggle.button_pressed and _preview_root != null and _plan.get("errors", []).is_empty():
		_occluder_root = Preview.wall_occluders(_preview_root, _plan)
		_viewport.add_child(_occluder_root)


func _add_catalog_module() -> void:
	if _catalog_id == "":
		return
	var meta := Registry.get_module(_catalog_id)
	if meta.is_empty():
		return
	var entry := {
		"id": _catalog_id,
		"params": Params.schema_defaults_raw(_catalog_id),
		"position": Vector3.ZERO,
	}
	if String(meta.get("policy", "")) != "A":
		entry["width"] = float(meta.get("unit", 1.0))
	if not _descriptor.has("modules"):
		_descriptor["modules"] = []
	_descriptor["modules"].append(entry)
	_rebuild_placement_tree()
	var index: int = _descriptor["modules"].size() - 1
	var root := _placement_tree.get_root()
	if root != null and index < root.get_child_count():
		root.get_child(index).select(0)
		_show_placement(index)
	_schedule_preview()


func _delete_selected_placement() -> void:
	if _selected_placement < 0:
		return
	var modules: Array = _descriptor.get("modules", [])
	if _selected_placement >= modules.size():
		return
	modules.remove_at(_selected_placement)
	_selected_placement = -1
	_rebuild_placement_tree()
	_select_first_placement()
	_schedule_preview()


func _update_camera() -> void:
	var direction := Vector3(sin(_orbit.x)*cos(_orbit.y),sin(_orbit.y),cos(_orbit.x)*cos(_orbit.y))
	_camera.look_at_from_position(_orbit_target+direction*_orbit_distance,_orbit_target)
	_camera.near = 0.035
	_camera.far = maxf(120.0,_orbit_distance*3.0)


func _preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_orbit_distance = maxf(0.30,_orbit_distance*0.83)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit_distance = minf(120.0,_orbit_distance/0.83)
		else:
			return
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if event.shift_pressed:
			_orbit_target += (_camera.basis.y*event.relative.y-_camera.basis.x*event.relative.x)*_orbit_distance*0.0018
		else:
			_orbit.x -= event.relative.x*0.009
			_orbit.y = clampf(_orbit.y+event.relative.y*0.009,-1.38,1.46)
	else:
		return
	_update_camera()
	accept_event()


func _refresh_recipe_controls() -> void:
	for child in _recipe_box.get_children():
		_recipe_box.remove_child(child)
		child.queue_free()
	_plan_editor = null
	_recipe_controls.clear()
	_detail_controls.clear()
	_variation_controls.clear()
	var recipe: Dictionary = _descriptor.get("building",{})
	if recipe.is_empty():
		return
	var mode := String(recipe.get("mode", "rect"))
	var hint := Label.new()
	hint.text = "矩形 / 多边形塔 / 线段连体共用预览与烘焙。上层柱脚落在木楼面。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recipe_box.add_child(hint)
	var fields: Array = ["mode"]
	if mode == "rect":
		fields.append_array(["usage","bays","bay_width","depth","storeys","setback","roof_form"])
	elif mode == "tower":
		fields.append_array(["sides","radius","storeys","setback"])
	if mode != "compound":
		fields.append_array(["construction","roof_covering","material_set"])
	var labels := {"mode":"生成方式","usage":"用途","bays":"开间数","bay_width":"每间面阔 (m)",
		"depth":"进深 (m)","storeys":"层数","roof_form":"屋顶","material_set":"木作涂装",
		"sides":"基础边数","radius":"底层外接半径 (m)","setback":"逐层收进 (m)",
		"construction":"构造样式","roof_covering":"屋面覆盖"}
	var defaults := {"mode":"rect","construction":"frame","roof_covering":"tile","sides":6,"radius":4.5,
		"setback":0.53 if int(recipe.get("storeys",1))==2 else 0.15}
	for field in fields:
		var row := HBoxContainer.new()
		_recipe_box.add_child(row)
		var label := Label.new()
		label.text = labels[field]
		row.add_child(label)
		var choices: Array = {"mode":["rect","tower","compound"],"usage":["house","shop","gate","hall"],
			"bays":[1,3,5,7],"storeys":[1,2,3,4,5,6,7,8],"sides":[4,5,6,7,8],
			"roof_form":["flush","overhang","hip","gable_hip"],"construction":["frame","earth","timber","log"],
			"roof_covering":["tile","thatch"],"material_set":["M_AgedTimber","M_RedLacquer"]}.get(field,[])
		if choices.is_empty():
			var limits: Array = {"bay_width":[2.0,3.6,0.05],"depth":[3.0,7.0,0.05],
				"radius":[2.0,10.0,0.1],"setback":[0.0,0.6,0.01]}[field]
			var spin := SpinBox.new()
			spin.min_value = limits[0]
			spin.max_value = limits[1]
			spin.step = limits[2]
			spin.value = recipe.get(field,defaults.get(field,spin.min_value))
			row.add_child(spin)
			_recipe_controls[field] = spin
			spin.value_changed.connect(func(value: float) -> void: _on_recipe_changed(field,value))
		else:
			var option := OptionButton.new()
			var names := {"rect":"矩形建筑","tower":"多边形塔","compound":"线段连体", "frame":"木框架灰墙",
				"earth":"土混木","timber":"纯木板围护","log":"垒木围护","tile":"瓦顶","thatch":"茅草顶",
				"flush":"硬山","overhang":"悬山","hip":"庑殿","gable_hip":"歇山","house":"民居",
				"shop":"商铺","gate":"门楼","hall":"殿阁","M_AgedTimber":"旧木","M_RedLacquer":"朱漆"}
			for value in choices:
				option.add_item(str(names.get(value,value)))
			option.select(maxi(0,choices.find(recipe.get(field,defaults.get(field,choices[0])))))
			row.add_child(option)
			_recipe_controls[field] = option
			option.item_selected.connect(func(index: int) -> void: _on_recipe_changed(field,choices[index]))
	if mode == "compound":
		var connection_hint := Label.new()
		connection_hint.text = "同高接坡分为内谷沟与外转角脊；高低连接保留独立屋顶，并为梁柱留净距。空间不足时请加长线段或增大高差。"
		connection_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_recipe_box.add_child(connection_hint)
		_plan_editor = PlanEditor.new()
		_plan_editor.inherited_construction = String(recipe.get("construction", "frame"))
		_plan_editor.inherited_covering = String(recipe.get("roof_covering", "tile"))
		_recipe_box.add_child(_plan_editor)
		_plan_editor.set_plan(recipe.get("plan",PlanEditor.default_plan()))
		_plan_editor.changed.connect(func(plan: Dictionary) -> void:
			_descriptor.building.plan = plan
			_schedule_preview())
	_build_surface_controls(recipe)
	_build_variation_controls(recipe)


func _build_surface_controls(recipe: Dictionary) -> void:
	var title := Label.new()
	title.text = "材质与表面（即时刷新）"
	_recipe_box.add_child(title)
	var settings := Materials.options(recipe.get("surface",{}))
	var enabled := CheckBox.new()
	enabled.text = "使用 PBR 纹理" if Materials.has_textures() else "使用 PBR 纹理（未烘焙，当前为程序回退）"
	enabled.button_pressed = settings.enabled
	_recipe_box.add_child(enabled)
	enabled.toggled.connect(func(value: bool) -> void: _set_surface("enabled",value))
	for entry in [["normal_strength","法线强度",0.0,2.0,0.05],
		["texture_scale","纹理密度",0.25,4.0,0.05],["age","老化",0.0,1.0,0.05],
		["variation","逐件色差",0.0,1.0,0.05],["dust","积灰",0.0,1.0,0.05],["seed","表面种子",0,65535,1]]:
		var row := HBoxContainer.new()
		_recipe_box.add_child(row)
		var label := Label.new()
		label.text = entry[1]
		label.custom_minimum_size.x = 150
		row.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = entry[2]
		spin.max_value = entry[3]
		spin.step = entry[4]
		spin.value = settings[entry[0]]
		row.add_child(spin)
		spin.value_changed.connect(func(value: float) -> void: _set_surface(entry[0],value))
	_recipe_box.add_child(_make_button("重载已烘焙纹理",func() -> void:
		Materials.reload_library()
		_refresh_surface_materials()))


func _set_surface(field: String, value: Variant) -> void:
	var settings: Dictionary = _descriptor.building.get("surface",{})
	settings[field] = value
	_descriptor.building.surface = settings
	_refresh_surface_materials()


func _refresh_surface_materials(show_status := true) -> void:
	if _preview_root == null:
		return
	var settings: Dictionary = _descriptor.get("building",{}).get("surface",{})
	for entry in _plan.get("instances",[]):
		var combined: Dictionary = settings.duplicate(true)
		combined.merge(entry.get("surface_override",{}),true)
		entry.surface = combined
	for child in _preview_root.get_children():
		if child is GeometryInstance3D and child.has_meta("ab_finish"):
			var combined: Dictionary = settings.duplicate(true)
			combined.merge(child.get_meta("ab_surface_override",{}),true)
			child.material_override = Materials.for_module(String(child.get_meta("ab_module")),
				String(child.get_meta("ab_finish")),combined)
	_preview_root.set_meta("ab_descriptor",_descriptor.duplicate(true))
	if show_status:
		_set_status("材质已刷新，几何保持不变。" if Materials.has_textures() else "程序材质回退：请先运行材质烘焙工具并导入纹理。")


func _on_recipe_changed(field: String, value: Variant) -> void:
	var recipe: Dictionary = _descriptor.building
	if field == "storeys" and not recipe.has("setback") and _recipe_controls.has("setback"):
		recipe.setback = _recipe_controls.setback.value
	recipe[field] = value
	if field == "mode":
		if value == "compound" and not recipe.has("plan"):
			recipe.plan = PlanEditor.default_plan()
		elif value == "tower":
			recipe.sides = recipe.get("sides",6)
			recipe.radius = recipe.get("radius",4.5)
			recipe.setback = 0.25
			recipe.storeys = 4
			if recipe.get("construction","frame") == "frame":
				recipe.construction = "timber"
	if field in ["roof_form", "storeys", "mode"]:
		var profile: Dictionary = recipe.get("style_profile", {}).duplicate(true)
		profile["building_tier"] = 0
		recipe["style_profile"] = profile
	if field == "mode":
		call_deferred("_refresh_recipe_controls")
	else:
		_sync_variation_controls()
	_schedule_preview()


func _build_variation_controls(recipe: Dictionary) -> void:
	var title := Label.new()
	title.text = "比例与部件变体"
	_recipe_box.add_child(title)
	var note := Label.new()
	note.text = "未固定项随种子变化；修改数值会自动固定。强度 0 使用原始比例与样式。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recipe_box.add_child(note)
	var variation: Dictionary = recipe.get("variation", {})
	for field in ["seed", "amount"]:
		var row := HBoxContainer.new()
		_recipe_box.add_child(row)
		var label := Label.new()
		label.text = "随机种子" if field=="seed" else "变体强度"
		row.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 2147483646 if field=="seed" else 1.0
		spin.step = 1 if field=="seed" else 0.05
		spin.value = variation.get(field,0)
		_variation_controls[field] = spin
		row.add_child(spin)
		spin.value_changed.connect(func(value: float) -> void:
			var settings: Dictionary = recipe.get("variation", {})
			settings[field] = int(value) if field=="seed" else value
			recipe["variation"] = settings
			_sync_variation_controls()
			_schedule_preview())
	var actions := HBoxContainer.new()
	_recipe_box.add_child(actions)
	actions.add_child(_make_button("下一个种子变体", _next_variation))
	actions.add_child(_make_button("恢复原始默认", _reset_variation))
	var resolved := Variation.resolve(recipe)
	if not String(resolved.get("error", "")).is_empty():
		var error := Label.new()
		error.text = String(resolved.error)
		_recipe_box.add_child(error)
		return
	for key in Variation.FIELDS:
		if Variation.FIELDS[key].has("modes") and String(recipe.get("mode", "rect")) not in Variation.FIELDS[key].modes:
			continue
		if String(recipe.get("mode", "rect")) != "rect" and key in ["hanging_style", "hanging_height", "lanterns", "hangings"]:
			continue
		if String(recipe.get("mode", "rect")) == "compound" and key in ["corner_lift","rafter_spacing","rafter_radius","cap_pattern"]:
			continue
		if String(recipe.get("mode", "rect")) == "compound" and key == "floor_height":
			continue # 层高在各线段的属性面板独立编辑。
		var field: Dictionary = Variation.FIELDS[key]
		var row := HBoxContainer.new()
		_recipe_box.add_child(row)
		var label := Label.new()
		label.text = field.label
		label.tooltip_text = String(field.get("hint", ""))
		label.custom_minimum_size.x = 150
		row.add_child(label)
		var lock := CheckBox.new()
		lock.text = "固定"
		lock.button_pressed = recipe.get("details", {}).has(key)
		var control: Control
		if field.has("choices"):
			var select := OptionButton.new()
			for choice in field.choices:
				select.add_item(choice)
			select.select(int(resolved.values[key]))
			select.item_selected.connect(func(index: int) -> void: _set_detail(key,index))
			control = select
		else:
			var spin := SpinBox.new()
			spin.min_value = field.min
			spin.max_value = field.max
			spin.step = field.step
			spin.value = resolved.values[key]
			spin.value_changed.connect(func(value: float) -> void: _set_detail(key,value))
			control = spin
		row.add_child(control)
		control.tooltip_text = String(field.get("hint", ""))
		row.add_child(lock)
		_detail_controls[key] = {"value":control,"lock":lock}
		lock.toggled.connect(func(checked: bool) -> void:
			if checked:
				_set_detail(key,control.selected if control is OptionButton else control.value)
			else:
				var fixed_values: Dictionary = recipe.get("details", {})
				fixed_values.erase(key)
				recipe["details"] = fixed_values
				_sync_variation_controls()
				_schedule_preview())
	_update_detail_availability(resolved.values)


func _set_detail(key: String, value: Variant) -> void:
	var recipe: Dictionary = _descriptor.building
	var fixed_values: Dictionary = recipe.get("details", {})
	fixed_values[key] = value
	recipe["details"] = fixed_values
	if _detail_controls.has(key):
		_detail_controls[key].lock.set_pressed_no_signal(true)
	_sync_variation_controls()
	_schedule_preview()


func _next_variation() -> void:
	var recipe: Dictionary = _descriptor.building
	var variation: Dictionary = recipe.get("variation", {})
	variation["seed"] = (int(variation.get("seed",0)) + 1) % 2147483647
	if float(variation.get("amount",0)) <= 0:
		variation["amount"] = 0.65
	recipe["variation"] = variation
	_sync_variation_controls()
	_schedule_preview()


func _reset_variation() -> void:
	_descriptor.building.erase("details")
	_descriptor.building.erase("variation")
	_sync_variation_controls()
	_schedule_preview()


func _sync_variation_controls() -> void:
	var recipe: Dictionary = _descriptor.get("building", {})
	var resolved := Variation.resolve(recipe)
	if not String(resolved.get("error", "")).is_empty():
		return
	for key in _variation_controls:
		var spin: SpinBox = _variation_controls[key]
		var value := float(recipe.get("variation", {}).get(key, 0))
		if not is_equal_approx(spin.value, value):
			spin.set_value_no_signal(value)
	for key in _detail_controls:
		var item: Dictionary = _detail_controls[key]
		var control: Control = item.value
		if control is OptionButton:
			control.select(int(resolved.values[key]))
		elif not is_equal_approx(control.value, float(resolved.values[key])):
			control.set_value_no_signal(float(resolved.values[key]))
		item.lock.set_pressed_no_signal(recipe.get("details", {}).has(key))
	_update_detail_availability(resolved.values)


func _update_detail_availability(values: Dictionary) -> void:
	var recipe: Dictionary = _descriptor.get("building",{})
	var mode := String(recipe.get("mode","rect"))
	var thatch: bool = recipe.get("roof_covering","tile") == "thatch"
	for key in _detail_controls:
		var reason := ""
		if key.begins_with("awning_") and key != "awning_style" and int(values.awning_style)==0:
			reason = "先开启临街棚架。"
		elif key in ["awning_sag","awning_pattern","awning_edge"] and int(values.awning_style)!=1:
			reason = "仅席棚生效。"
		elif key in ["shop_opening","counter_height"] and int(values.facade_style)!=3:
			reason = "前脸围护选择敞铺门面后生效。"
		elif key=="tile_pattern" and int(values.entry_roof)==1:
			reason = "抱厦裁切目前只支持筒板瓦；关闭抱厦后可切换。"
		elif key.begins_with("thatch_") and not thatch:
			reason = "仅茅草屋面生效。"
		elif key in ["roof_palette","ridge_ornament","ridge_height","ridge_width","ridge_joint_spacing","ridge_profile","ridge_end_lift","verge_width","tile_pattern","ornament_scale","cap_pattern"] and thatch:
			reason = "仅瓦屋面生效。"
		elif key in ["entry_roof","entry_projection","entry_rise"] and (int(recipe.get("storeys",1)) < 2 or thatch):
			reason = "抱厦需要两层及以上的瓦顶建筑。"
		elif key in ["entry_projection","entry_rise"] and int(values.entry_roof) == 0:
			reason = "先开启中央抱厦。"
		elif key == "upper_porch_depth" and int(recipe.get("storeys",1)) < 2:
			reason = "仅楼上层生效。"
		elif key == "side_windows" and int(values.facade_style) == 0:
			reason = "先选择窗墙与中门或满开间落地格扇。"
		elif key == "gable_rafter_setback" and String(recipe.get("roof_form","overhang")) not in ["flush","overhang"]:
			reason = "仅封闭山墙的悬山/硬山椽列生效；四坡裙檐保持原布局。"
		elif key == "window_backing" and mode == "rect" and int(values.facade_style) == 0:
			reason = "纸绢背衬适用于新窗墙/落地格扇配方。"
		elif key == "paving_size" and int(values.platform_paving) == 0:
			reason = "先开启独立石板铺地。"
		elif key == "railing_height" and int(values.railing_style) == 0:
			reason = "先选择木栏或石栏。"
		var control: Control = _detail_controls[key].value
		# 错误描述的抱厦开关仍可关闭，避免禁用控件导致无法修复。
		var enabled: bool = reason.is_empty() or (key == "entry_roof" and int(values.entry_roof) == 1)
		control.tooltip_text = reason if not reason.is_empty() else String(Variation.FIELDS[key].get("hint",""))
		if control is OptionButton:
			control.disabled = not enabled
		else:
			control.editable = enabled
		_detail_controls[key].lock.disabled = not enabled
