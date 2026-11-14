extends RefCounted
## M6 预览构建器：descriptor -> 场景节点 + 自动取景。
## 不依赖编辑器 API，headless 测试与 Editor Dock 共用同一份逻辑。

const Descriptor := preload("res://addons/ancient_building/core/descriptor.gd")
const Planner := preload("res://addons/ancient_building/core/layout_planner.gd")
const Assembler := preload("res://addons/ancient_building/core/assembler.gd")
const CacheScript := preload("res://addons/ancient_building/core/mesh_cache.gd")
const Registry := preload("res://addons/ancient_building/core/module_registry.gd")


## 构建一份预览。返回 { root, plan, cache, stats, errors, layout_hash, build_ms }。
static func build(descriptor: Dictionary, prior_cache = null) -> Dictionary:
	var started := Time.get_ticks_msec()
	var plan := Planner.from_descriptor(descriptor)
	var cache = prior_cache if prior_cache != null else CacheScript.new("", Registry.generator_version())
	if not plan.get("errors", []).is_empty():
		return {"root":null,"plan":plan,"cache":cache,"stats":{},"errors":plan.errors,
			"layout_hash":"","build_ms":Time.get_ticks_msec()-started}
	var root := Assembler.build(plan, cache)
	if prior_cache != null:
		cache.retain_plan(plan.instances)
	var elapsed := Time.get_ticks_msec() - started
	return {
		"root": root,
		"plan": plan,
		"cache": cache,
		"stats": Assembler.stats(plan),
		"errors": plan.get("errors", []),
		"layout_hash": plan.get("layout_hash", ""),
		"build_ms": elapsed,
	}


static func build_file(path: String) -> Dictionary:
	var descriptor := Descriptor.load_file(path)
	if not String(descriptor.get("error", "")).is_empty():
		return {
			"root": null,
			"errors": [String(descriptor["error"])],
			"build_ms": 0,
			"descriptor": descriptor,
		}
	var result := build(descriptor)
	result["descriptor"] = descriptor
	return result


## 只为原生 PCG 实墙建立遮挡体；门窗、外部替换与整栋包围盒不参与。
## 独立于建筑根节点，避免预览用遮挡体被烘焙进游戏场景。
static func wall_occluders(root: Node3D, plan: Dictionary) -> Node3D:
	var group := Node3D.new()
	group.name = "PreviewOccluders"
	var allowed: Dictionary = {}
	for entry in plan.get("instances", []):
		if entry.module_id == "W01" and String(entry.get("mesh_path", "")).is_empty():
			allowed[String(entry.key)] = true
	for child in root.get_children():
		if not child is MeshInstance3D or not child.visible or not child.mesh is BoxMesh:
			continue
		if not allowed.has(String(child.get_meta("ab_key", ""))):
			continue
		var box: AABB = child.mesh.get_aabb()
		var shape := BoxOccluder3D.new()
		shape.size = box.size * 0.98
		var node := OccluderInstance3D.new()
		node.name = "Wall_%03d" % group.get_child_count()
		node.occluder = shape
		node.transform = child.transform * Transform3D(Basis.IDENTITY, box.get_center())
		group.add_child(node)
	return group


## 组装后的包围盒（世界/局部同一坐标系：Assembler 的子节点都是根的直接子级）。
static func bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child in root.get_children():
		if child is MeshInstance3D and child.visible and child.mesh != null:
			var child_box: AABB = child.transform * child.mesh.get_aabb()
			if first:
				box = child_box
				first = false
			else:
				box = box.merge(child_box)
	if first:
		box = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))
	return box


## 把相机拉到能完整看到建筑的位置，返回包围盒。
static func frame_camera(camera: Camera3D, root: Node3D, direction := Vector3(1.0, 0.72, 1.2)) -> AABB:
	var box := bounds(root)
	var center := box.get_center()
	var radius := maxf(0.5, box.size.length() * 0.5)
	var dir := direction.normalized()
	var distance := radius / tan(deg_to_rad(camera.fov) * 0.5) * 1.35
	camera.position = center + dir * distance
	camera.look_at_from_position(camera.position, center + Vector3(0.0, box.size.y * 0.06, 0.0), Vector3.UP)
	camera.near = 0.05
	camera.far = maxf(100.0, distance * 4.0)
	return box
