extends RefCounted
## 网格缓存：内存 + 磁盘（M4）。
## 磁盘路径：<disk_root>/v<generator_version>/<key>.res；版本变化即换目录，不做就地升级。

const ModuleMesh := preload("res://addons/ancient_building/core/module_mesh.gd")
const DEFAULT_DISK_ROOT := "res://Generated/AncientBuilding"

var disk_root := ""
var generator_version := 1

var _meshes: Dictionary = {}
var _build_count := 0
var _disk_hits := 0
var recent_limit := 256
var recent_bytes_limit := 128 * 1024 * 1024
var _used: Dictionary = {}
var _sizes: Dictionary = {}
var _clock := 0


func _init(p_disk_root: String = "", p_generator_version: int = 1) -> void:
	disk_root = p_disk_root
	generator_version = p_generator_version


func get_mesh(key: String, module_id: String, params: Dictionary, dims: Dictionary = {}) -> Mesh:
	if _meshes.has(key):
		_touch(key)
		return _meshes[key]

	if not disk_root.is_empty():
		var path := _disk_path(key)
		if ResourceLoader.exists(path):
			var loaded: Resource = ResourceLoader.load(path)
			if loaded is Mesh:
				_meshes[key] = loaded
				_disk_hits += 1
				_touch(key)
				return loaded

	var mesh := put_data(key, ModuleMesh.build_data(module_id, params, dims))
	if not disk_root.is_empty():
		_store(key, mesh)
	return mesh


func _touch(key: String) -> void:
	_clock += 1
	_used[key] = _clock


func has_mesh(key: String) -> bool:
	return _meshes.has(key)


func peek(key: String) -> Mesh:
	_touch(key)
	return _meshes.get(key)


func known_keys() -> Dictionary:
	var result := {}
	for key in _meshes:
		result[key] = true
	return result


func put_data(key: String, data) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = data.to_mesh()
		_sizes[key] = data.byte_size()
		_build_count += 1
	_touch(key)
	return _meshes[key]


func unique_count() -> int:
	return _meshes.size()


func build_count() -> int:
	return _build_count


func disk_hits() -> int:
	return _disk_hits


func clear() -> void:
	_meshes.clear()
	_build_count = 0
	_disk_hits = 0
	_used.clear()
	_sizes.clear()


func _disk_dir() -> String:
	return "%s/v%d" % [disk_root, generator_version]


func _disk_path(key: String) -> String:
	return "%s/%s.res" % [_disk_dir(), key]


func _store(key: String, mesh: Mesh) -> void:
	var dir := _disk_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var error := ResourceSaver.save(mesh, _disk_path(key))
	if error != OK:
		push_warning("AncientBuilding: failed to cache mesh %s (%s)" % [key, error_string(error)])


func retain_plan(instances: Array) -> void:
	var active := {}
	for instance in instances:
		active[instance.key] = true
	var recent: Array = []
	var bytes := 0
	for key in _meshes.keys():
		if not active.has(key):
			recent.append(key)
			bytes += int(_sizes.get(key, 0))
	recent.sort_custom(func(a, b): return int(_used.get(a, 0)) < int(_used.get(b, 0)))
	var count := recent.size()
	for key in recent:
		if count <= recent_limit and bytes <= recent_bytes_limit:
			break
		bytes -= int(_sizes.get(key, 0))
		count -= 1
		_meshes.erase(key)
		_used.erase(key)
		_sizes.erase(key)
