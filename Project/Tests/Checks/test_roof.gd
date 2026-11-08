extends SceneTree
## M3 验收：屋顶模块的 P/R 分工、尺寸进入哈希的规则、屋面网格包围盒。
## 运行：godot --headless --path Project --script res://Tests/Checks/test_roof.gd

const Planner := preload("res://addons/ancient_building/core/layout_planner.gd")
const CacheScript := preload("res://addons/ancient_building/core/mesh_cache.gd")
const Assembler := preload("res://addons/ancient_building/core/assembler.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_roof_plan()
	_test_width_response()
	_test_roof_meshes()
	_test_assembly()

	if _failures == 0:
		print("PASS: roof modules (%d checks)" % _checks)
		quit(0)
	else:
		printerr("FAIL: %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("ok   %s" % label)
	else:
		_failures += 1
		printerr("FAIL %s" % label)


func _approx(a: float, b: float, tolerance := 0.01) -> bool:
	return absf(a - b) <= tolerance


func _roof(width: float) -> Array:
	return [
		{"id": "R01", "width": width, "params": {"depth": 6.0, "rise": 1.5, "overhang": 0.4}, "position": Vector3(0, 3, 0)},
		{"id": "R03", "width": width, "params": {"radius": 0.08, "length": 3.0, "sides": 8}, "position": Vector3(0, 3.6, 1.5)},
		{"id": "R06", "width": width, "params": {"height": 0.35, "thickness": 0.3, "overhang": 0.4}, "position": Vector3(0, 4.5, 0)},
		{"id": "R07", "width": width, "params": {"run": 1.8, "rise": 1.2, "thickness": 0.22}, "position": Vector3(3, 3.5, 1.0)},
		{"id": "R11", "params": {"height": 0.6, "width": 0.3, "depth": 0.25}, "position": Vector3(3.2, 4.6, 0)},
		{"id": "R12", "params": {"height": 0.4, "width": 0.2, "depth": 0.18}, "position": Vector3(3.0, 3.8, 1.2)},
	]


func _keys_by_module(plan: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for instance in plan["instances"]:
		out[String(instance["module_id"])] = String(instance["key"])
	return out


func _test_roof_plan() -> void:
	var plan := Planner.plan(_roof(6.0))
	_check(plan["errors"].is_empty(), "roof plan has no errors (%s)" % str(plan["errors"]))
	_check(plan["instances"].size() == 25, "roof plan expands to 25 instances (got %d)" % plan["instances"].size())

	var counts := {}
	for instance in plan["instances"]:
		var id := String(instance["module_id"])
		counts[id] = int(counts.get(id, 0)) + 1
	_check(int(counts.get("R03", 0)) == 20, "6 m tile field holds 20 courses")
	_check(int(counts.get("R01", 0)) == 1, "roof surface is a single parametric module")

	var keys := _keys_by_module(plan)
	_check(keys.size() == 6, "six distinct roof modules produce six keys")


func _test_width_response() -> void:
	var narrow := Planner.plan(_roof(6.0))
	var wide := Planner.plan(_roof(7.2))
	var narrow_keys := _keys_by_module(narrow)
	var wide_keys := _keys_by_module(wide)

	_check(narrow_keys["R01"] != wide_keys["R01"], "P roof surface key changes with width")
	_check(narrow_keys["R06"] != wide_keys["R06"], "P main ridge key changes with width")
	_check(narrow_keys["R07"] != wide_keys["R07"], "P hip ridge key changes with width")
	_check(narrow_keys["R03"] == wide_keys["R03"], "R tile course key survives width change")
	_check(narrow_keys["R11"] == wide_keys["R11"], "A finial key survives width change")
	_check(int(_count_module(wide, "R03")) == 24, "7.2 m tile field holds 24 courses")


func _count_module(plan: Dictionary, module_id: String) -> int:
	var count := 0
	for instance in plan["instances"]:
		if String(instance["module_id"]) == module_id:
			count += 1
	return count


func _test_roof_meshes() -> void:
	var plan := Planner.plan(_roof(6.0))
	var cache := CacheScript.new()
	for instance in plan["instances"]:
		cache.get_mesh(instance["key"], instance["module_id"], instance["params"], instance.get("dims", {}))

	_check(cache.unique_count() == 6, "cache holds one mesh per roof key (got %d)" % cache.unique_count())

	var keys := _keys_by_module(plan)
	var surface: Mesh = cache.get_mesh(keys["R01"], "R01", {}, {"width": 6000})
	var surface_size := surface.get_aabb().size
	_check(_approx(surface_size.x, 6.8), "roof surface spans width + 2*overhang (got %.2f)" % surface_size.x)
	_check(_approx(surface_size.y, 1.5), "roof surface height equals rise (got %.2f)" % surface_size.y)

	var ridge: Mesh = cache.get_mesh(keys["R06"], "R06", {}, {"width": 6000})
	_check(_approx(ridge.get_aabb().size.x, 6.8), "main ridge spans width + 2*overhang")

	var course: Mesh = cache.get_mesh(keys["R03"], "R03", {}, {})
	_check(_approx(course.get_aabb().size.z, 3.0), "tile course length runs along Z")


func _test_assembly() -> void:
	var plan := Planner.plan(_roof(6.0))
	var cache := CacheScript.new()
	var root := Assembler.build(plan, cache)
	_check(root.get_child_count() == 25, "assembler builds 25 roof nodes")
	_check(cache.unique_count() == 6, "25 roof nodes share 6 meshes")
	root.free()
