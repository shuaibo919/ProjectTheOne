extends RefCounted
## 建筑描述文件（JSON）加载。位置可用 [x,y,z]，加载后统一成 Vector3。

static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "descriptor not found: %s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "cannot open descriptor: %s" % path}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"error": "descriptor is not a JSON object: %s" % path}

	var modules: Array = []
	for entry in parsed.get("modules", []):
		if typeof(entry) != TYPE_DICTIONARY:
			return {"error": "module entry is not an object"}
		modules.append(_normalize(entry))

	return {
		"name": String(parsed.get("name", "Building")),
		"generator_version": int(parsed.get("generator_version", 1)),
		"modules": modules,
		"error": "",
	}


static func _normalize(entry: Dictionary) -> Dictionary:
	var out := entry.duplicate(true)
	var position: Variant = entry.get("position", [0.0, 0.0, 0.0])
	if position is Array and position.size() >= 3:
		out["position"] = Vector3(float(position[0]), float(position[1]), float(position[2]))
	elif position is Vector3:
		out["position"] = position
	else:
		out["position"] = Vector3.ZERO
	out["rotation_y"] = float(entry.get("rotation_y", 0.0))
	return out
