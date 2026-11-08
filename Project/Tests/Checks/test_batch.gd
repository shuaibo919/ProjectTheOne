extends SceneTree
## M4 验收：MultiMesh 转换/还原、磁盘缓存命中、往返布局哈希一致。
## 运行：godot --headless --path Project --script res://Tests/Checks/test_batch.gd

const Planner := preload("res://addons/ancient_building/core/layout_planner.gd")
const CacheScript := preload("res://addons/ancient_building/core/mesh_cache.gd")
const Assembler := preload("res://addons/ancient_building/core/assembler.gd")
const Batcher := preload("res://addons/ancient_building/core/scene_batcher.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_convert_revert()
	_test_disk_cache()

	if _failures == 0:
		print("PASS: multimesh batch and disk cache (%d checks)" % _checks)
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


func _building() -> Array:
	return [
		{"id": "W01", "width": 2.4, "params": {"thickness": 0.2, "height": 2.6}, "position": Vector3(0, 0, 0)},
		{"id": "F01", "params": {"radius": 0.12, "height": 3.0, "sides": 12}, "position": Vector3(-0.5, 0, 0)},
		{"id": "F01", "params": {"radius": 0.12, "height": 3.0, "sides": 12}, "position": Vector3(0.5, 0, 0)},
		{"id": "F11", "width": 3.0, "params": {"radius": 0.06, "length": 1.2, "sides": 8}, "position": Vector3(0, 3, 0)},
		{"id": "R11", "params": {"height": 0.6, "width": 0.3, "depth": 0.25}, "position": Vector3(0, 4, 0)},
	]


func _test_convert_revert() -> void:
	var plan := Planner.plan(_building())
	var cache := CacheScript.new()
	var root := Assembler.build(plan, cache)
	_check(root.get_child_count() == 18, "starts with 18 individual instances")

	var result := Batcher.convert(root)
	_check(int(result["groups"]) == 4, "convert collapses 18 instances into 4 groups")
	_check(int(result["instances"]) == 18, "convert keeps all 18 instances")
	_check(root.get_child_count() == 4, "converted root has 4 MultiMesh nodes")

	var multimesh_nodes := 0
	var instance_sum := 0
	for child in root.get_children():
		if child is MultiMeshInstance3D:
			multimesh_nodes += 1
			instance_sum += child.multimesh.instance_count
	_check(multimesh_nodes == 4, "all converted children are MultiMeshInstance3D")
	_check(instance_sum == 18, "MultiMesh instance counts sum to 18")
	_check(String(root.get_meta("ab_state", {}).get("mode", "")) == "multimesh", "root state records multimesh mode")

	Batcher.revert(root, plan, cache)
	_check(root.get_child_count() == 18, "revert restores 18 individual instances")
	_check(String(root.get_meta("ab_state", {}).get("mode", "")) == "individual", "revert restores individual mode")

	var plan_again := Planner.plan(_building())
	_check(plan["layout_hash"] == plan_again["layout_hash"], "layout hash survives convert/revert")
	root.free()


func _test_disk_cache() -> void:
	var dir := "user://ab_cache_test_%d" % Time.get_ticks_msec()
	var key := "ab1_0123456789abcdef"

	var first := CacheScript.new(dir, 1)
	var mesh := first.get_mesh(key, "W01", {"thickness": 200, "height": 2600}, {})
	_check(mesh != null and first.build_count() == 1, "first cache builds the mesh")

	var second := CacheScript.new(dir, 1)
	var loaded := second.get_mesh(key, "W01", {"thickness": 200, "height": 2600}, {})
	_check(loaded != null, "second cache loads a mesh from disk")
	_check(second.build_count() == 0 and second.disk_hits() == 1, "disk hit avoids rebuilding")
	_check(loaded.get_class() == "BoxMesh", "loaded resource keeps its type")
