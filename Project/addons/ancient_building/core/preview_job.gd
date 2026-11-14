extends RefCounted
## 一个后台任务只消费不可变快照；不触碰 Mesh、材质、场景树或编辑器控件。
const Planner := preload("res://addons/ancient_building/core/layout_planner.gd")
const Meshes := preload("res://addons/ancient_building/core/module_mesh.gd")
const Registry := preload("res://addons/ancient_building/core/module_registry.gd")

var revision := 0
var _thread := Thread.new()
var _mutex := Mutex.new()
var _cancelled := false


func start(version: int, descriptor: Dictionary, known: Dictionary, prior_session: Dictionary) -> Error:
	revision = version
	Registry.count() # 目录在主线程预热；工作线程只读。
	return _thread.start(_compute.bind(descriptor.duplicate(true), known, prior_session.duplicate()), Thread.PRIORITY_LOW)


func cancel() -> void:
	_mutex.lock()
	_cancelled = true
	_mutex.unlock()


func cancelled() -> bool:
	_mutex.lock()
	var value := _cancelled
	_mutex.unlock()
	return value


func running() -> bool:
	return _thread.is_alive()


func take_result() -> Dictionary:
	if not _thread.is_started():
		return {"errors":["预览线程未启动"]}
	var value: Variant = _thread.wait_to_finish()
	return value if value is Dictionary else {"errors":["预览后台计算未返回有效结果"]}


func shutdown() -> void:
	cancel()
	if _thread.is_started():
		_thread.wait_to_finish()


func _compute(snapshot: Dictionary, known: Dictionary, session: Dictionary) -> Dictionary:
	var started := Time.get_ticks_msec()
	var plan := Planner.from_descriptor(snapshot, session, false)
	if cancelled():
		return {"cancelled":true}
	if not plan.errors.is_empty():
		return {"errors":plan.errors, "plan":plan}
	var layout_ms := Time.get_ticks_msec() - started
	var data := {}
	for entry in plan.instances:
		if cancelled():
			return {"cancelled":true}
		if not String(entry.get("mesh_path", "")).is_empty() or known.has(entry.key) or data.has(entry.key):
			continue
		var mesh_data := Meshes.build_data(entry.module_id, entry.params, entry.get("dims", {}))
		if mesh_data == null or mesh_data.get_surface_count() == 0:
			return {"errors":["无法生成部件 %s" % entry.module_id]}
		data[entry.key] = mesh_data
	return {"errors":[], "plan":plan, "data":data, "descriptor":snapshot, "session":session,
		"layout_ms":layout_ms, "worker_ms":Time.get_ticks_msec() - started}
