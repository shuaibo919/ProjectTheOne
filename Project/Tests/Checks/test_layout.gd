extends SceneTree
## M2 验收：宽度求解器、布局解算、网格缓存与装配、参数校验。
## 运行：godot --headless --path Project --script res://Tests/Checks/test_layout.gd

const Solver := preload("res://addons/ancient_building/core/width_solver.gd")
const Planner := preload("res://addons/ancient_building/core/layout_planner.gd")
const Params := preload("res://addons/ancient_building/core/module_params.gd")
const CacheScript := preload("res://addons/ancient_building/core/mesh_cache.gd")
const Assembler := preload("res://addons/ancient_building/core/assembler.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_solver()
	_test_params()
	_test_planner()
	_test_cache_and_assembler()

	if _failures == 0:
		print("PASS: layout solver and assembler (%d checks)" % _checks)
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


func _approx(a: float, b: float, tolerance := 0.0001) -> bool:
	return absf(a - b) <= tolerance


func _test_solver() -> void:
	var single := Solver.solve("W01", 1.1)
	_check(single.get("mode") == "single" and int(single.get("count", 0)) == 1 and _approx(float(single.get("scale", 0.0)), 1.1),
			"S within MaxStretch uses one scaled instance")

	var repeat := Solver.solve("W01", 2.4)
	_check(repeat.get("mode") == "repeat" and int(repeat.get("count", 0)) == 2 and _approx(float(repeat.get("scale", 0.0)), 1.2) and _approx(float(repeat.get("pitch", 0.0)), 1.2),
			"S beyond MaxStretch repeats n=ceil(W/(unit*max)) with s<=max")

	var wide := Solver.solve("W01", 9.0)
	_check(int(wide.get("count", 0)) == 8 and _approx(float(wide.get("scale", 0.0)), 1.125),
			"9 m wall splits into 8 copies at 1.125x")

	var rafters := Solver.solve("F11", 3.0)
	_check(int(rafters.get("count", 0)) == 13 and _approx(float(rafters.get("scale", 1.0)), 1.0),
			"R module repeats with scale 1 and even pitch")

	var anchor := Solver.solve("R11", 3.0)
	_check(int(anchor.get("count", 0)) == 1 and anchor.get("mode") == "single",
			"A module never repeats or scales")

	var parametric := Solver.solve("R01", 3.2)
	_check(parametric.get("mode") == "parametric" and int(parametric.get("dims", {}).get("width", 0)) == 3200,
			"P module carries quantized dims")

	var unknown := Solver.solve("ZZZ", 1.0)
	_check(unknown.has("error"), "unknown module reports an error")


func _test_params() -> void:
	var defaults := Params.defaults("W01")
	_check(int(defaults.get("thickness", 0)) == 200 and int(defaults.get("height", 0)) == 2600,
			"W01 defaults quantize to millimetres")

	_check(Params.validate("W01", {"thickness": 200, "height": 2600}).is_empty(),
			"valid params pass validation")

	var missing := Params.validate("W01", {"thickness": 200})
	_check(not missing.is_empty(), "missing param is reported")

	var too_tall := Params.validate("W01", {"thickness": 200, "height": 20000})
	_check(not too_tall.is_empty(), "out-of-range param is reported")


func _building(width: float) -> Array:
	return [
		{"id": "W01", "width": width, "params": {"thickness": 0.2, "height": 2.6}, "position": Vector3(0, 0, 0)},
		{"id": "F01", "params": {"radius": 0.12, "height": 3.0, "sides": 12}, "position": Vector3(-0.5, 0, 0)},
		{"id": "F01", "params": {"radius": 0.12, "height": 3.0, "sides": 12}, "position": Vector3(0.5, 0, 0)},
		{"id": "F11", "width": 3.0, "params": {"radius": 0.06, "length": 1.2, "sides": 8}, "position": Vector3(0, 3, 0)},
		{"id": "R11", "params": {"height": 0.6, "width": 0.3, "depth": 0.25}, "position": Vector3(0, 4, 0)},
	]


func _test_planner() -> void:
	var plan := Planner.plan(_building(2.4))
	_check(plan["errors"].is_empty(), "plan has no errors (%s)" % str(plan["errors"]))
	_check(plan["instances"].size() == 18, "plan expands to 18 instances (got %d)" % plan["instances"].size())

	var counts := {}
	for instance in plan["instances"]:
		var id := String(instance["module_id"])
		counts[id] = int(counts.get(id, 0)) + 1
	_check(int(counts.get("W01", 0)) == 2, "wall contributes 2 instances")
	_check(int(counts.get("F01", 0)) == 2, "two columns contribute 2 instances")
	_check(int(counts.get("F11", 0)) == 13, "rafters contribute 13 instances")
	_check(int(counts.get("R11", 0)) == 1, "finial contributes 1 instance")

	var keys := {}
	for instance in plan["instances"]:
		keys[instance["key"]] = true
	_check(keys.size() == 4, "18 instances collapse to 4 unique keys (got %d)" % keys.size())

	var wall_positions: Array = []
	for instance in plan["instances"]:
		if String(instance["module_id"]) == "W01":
			var xf: Transform3D = instance["transform"]
			wall_positions.append(xf.origin.x)
			_check(_approx(xf.basis.get_scale().x, 1.2), "wall copy scale is 1.2")
	wall_positions.sort()
	_check(_approx(wall_positions[0], -0.6) and _approx(wall_positions[1], 0.6),
			"wall copies are centred on the placement origin")

	var plan_again := Planner.plan(_building(2.4))
	_check(plan["layout_hash"] == plan_again["layout_hash"], "same descriptor produces the same layout hash")

	var narrow := Planner.plan(_building(1.1))
	_check(narrow["instances"].size() == 17, "1.1 m wall is a single instance (17 total)")
	_check(narrow["layout_hash"] != plan["layout_hash"], "different width changes the layout hash")

	var wall_key_wide := ""
	var wall_key_narrow := ""
	for instance in plan["instances"]:
		if String(instance["module_id"]) == "W01":
			wall_key_wide = instance["key"]
	for instance in narrow["instances"]:
		if String(instance["module_id"]) == "W01":
			wall_key_narrow = instance["key"]
	_check(wall_key_wide == wall_key_narrow, "S wall key ignores width (flyweight across widths)")


func _test_cache_and_assembler() -> void:
	var plan := Planner.plan(_building(2.4))
	var cache := CacheScript.new()
	var root := Assembler.build(plan, cache)

	_check(cache.unique_count() == 4, "cache holds 4 meshes (got %d)" % cache.unique_count())
	_check(cache.build_count() == 4, "each key builds exactly once (got %d)" % cache.build_count())
	_check(root.get_child_count() == 18, "assembler creates one node per instance")

	var wall_meshes: Array = []
	for child in root.get_children():
		if String(child.name).begins_with("W01"):
			wall_meshes.append(child.mesh)
	_check(wall_meshes.size() == 2 and wall_meshes[0] == wall_meshes[1],
			"wall copies share the same Mesh resource")

	var stats := Assembler.stats(plan)
	_check(int(stats.get("instances", 0)) == 18 and int(stats.get("unique_meshes", 0)) == 4,
			"stats reports 18 instances / 4 meshes")

	root.free()
