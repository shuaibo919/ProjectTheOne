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


func _init(p_disk_root: String = "", p_generator_version: int = 1) -> void:
	disk_root = p_disk_root
	generator_version = p_generator_version


func get_mesh(key: String, module_id: String, params: Dictionary, dims: Dictionary = {}) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]

	if not disk_root.is_empty():
		var path := _disk_path(key)
		if ResourceLoader.exists(path):
			var loaded: Resource = ResourceLoader.load(path)
			if loaded is Mesh:
				_meshes[key] = loaded
				_disk_hits += 1
				return loaded

	var mesh := ModuleMesh.build(module_id, params, dims)
	_meshes[key] = mesh
	_build_count += 1
	if not disk_root.is_empty():
		_store(key, mesh)
	return mesh


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
