extends RefCounted
## 模块网格构建。参数已量化（毫米），这里换算成米。
## 约定：宽度轴 = X（S 策略由实例缩放，R 策略按 unit 复制）。

const MeshKit := preload("res://addons/ancient_building/core/mesh_kit.gd")


static func build(module_id: String, params: Dictionary, dims: Dictionary = {}) -> Mesh:
	match module_id:
		"B01":
			return MeshKit.box(Vector3(1.0, _meters(params, "height"), _meters(params, "depth")))
		"W01":
			return MeshKit.box(Vector3(1.0, _meters(params, "height"), _meters(params, "thickness")))
		"F01":
			return MeshKit.cylinder_y(_meters(params, "radius"), _meters(params, "height"), int(params.get("sides", 12)))
		"F11", "R03":
			return MeshKit.cylinder_z(_meters(params, "radius"), _meters(params, "length"), int(params.get("sides", 8)))
		"R11", "R12":
			return MeshKit.box(Vector3(_meters(params, "width"), _meters(params, "height"), _meters(params, "depth")))
		"R01":
			var width := _dims_width(dims) + _meters(params, "overhang") * 2.0
			var depth := _meters(params, "depth") + _meters(params, "overhang") * 2.0
			return MeshKit.gable_roof(width, depth, _meters(params, "rise"))
		"R02":
			return MeshKit.box(Vector3(1.0, _meters(params, "thickness"), _meters(params, "length")))
		"R06":
			var ridge_width := _dims_width(dims) + _meters(params, "overhang") * 2.0
			return MeshKit.box(Vector3(ridge_width, _meters(params, "height"), _meters(params, "thickness")))
		"R07":
			var run := _meters(params, "run")
			var rise := _meters(params, "rise")
			var slope_length := sqrt(run * run + rise * rise)
			var thickness := _meters(params, "thickness")
			return MeshKit.box(Vector3(thickness, thickness * 1.5, slope_length))
		_:
			push_warning("AncientBuilding: no mesh builder for %s; using a unit box" % module_id)
			return MeshKit.box(Vector3.ONE)


static func _meters(params: Dictionary, key: String) -> float:
	return float(params.get(key, 0)) / 1000.0


static func _dims_width(dims: Dictionary) -> float:
	return float(dims.get("width", 6000)) / 1000.0
