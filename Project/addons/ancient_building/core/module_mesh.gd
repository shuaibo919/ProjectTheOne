extends RefCounted
const Data := preload("res://addons/ancient_building/core/mesh_data.gd")
## 模块网格构建。参数已量化（毫米），这里换算成米。
## 约定：宽度轴 = X（S 策略由实例缩放，R 策略按 unit 复制）。

const MeshKit := preload("res://addons/ancient_building/core/mesh_kit.gd")

const Joinery := preload("res://addons/ancient_building/core/joinery.gd")
const Ornament := preload("res://addons/ancient_building/core/ornament_geometry.gd")
const Awning := preload("res://addons/ancient_building/core/awning_geometry.gd")
const Roof := preload("res://addons/ancient_building/core/roof_geometry.gd")
const ShellGeometry := preload("res://addons/ancient_building/core/shell_geometry.gd")
const Damage := preload("res://addons/ancient_building/core/mesh_damage.gd")

## 已有真实网格的模块。其余目录项会走 unit box 兜底，M7 的三个样例必须全部命中这里。
const SUPPORTED := [
	"B01", "W01", "F01", "F11", "R03", "R11", "R12", "R01", "R02", "R06", "R07",
	"O01", "O02", "O05", "O06", "O07", "O08",
	"W03", "F02", "F05", "F07", "F13",
	"B04", "B05", "D01", "B02", "B12", "F04", "F08", "F09", "F10", "F12",
	"R08", "R15", "B09", "B10", "F14", "O04", "W02", "W06", "R04", "R05", "D03", "O11", "R09", "R14", "R19",
]


static func supports(module_id: String) -> bool:
	return module_id in SUPPORTED


static func build(module_id: String, params: Dictionary, dims: Dictionary = {}) -> Mesh:
	return build_data(module_id, params, dims).to_mesh()


static func build_data(module_id: String, params: Dictionary, dims: Dictionary = {}) -> Data:
	var mesh: Data
	if dims.has("geometry"):
		mesh = ShellGeometry.build(dims.geometry, params)
	else:
		mesh = _build_clean(module_id, params, dims)
	return Damage.apply(mesh, module_id, params)


static func _build_clean(module_id: String, params: Dictionary, dims: Dictionary) -> Data:
	match module_id:
		"B01":
			return MeshKit.box(Vector3(1.0, _meters(params, "height"), _meters(params, "depth")))
		"W01":
			return MeshKit.box(Vector3(1.0, _meters(params, "height"), _meters(params, "thickness")))
		"F01":
			return Joinery.column(_meters(params,"radius"),_meters(params,"height"),int(params.sides),
				float(params.get("taper",900))/10000.0,float(params.get("entasis",150))/10000.0)
		"F11":
			return MeshKit.cylinder_z(_meters(params, "radius"), _meters(params, "length"), int(params.get("sides", 8)))
		"R11", "R12":
			if int(params.get("style", 0)) == 1:
				return Joinery.chiwei(_meters(params,"width"),_meters(params,"height"),_meters(params,"depth"),
					float(params.get("relief",6000))/10000.0,float(params.get("curl",10000))/10000.0)
			return Joinery.beast(_meters(params,"width"),_meters(params,"height"),_meters(params,"depth"),
				float(params.get("relief",6000))/10000.0,float(params.get("curl",10000))/10000.0)
		"R01":
			var width := _dims_width(dims) + _meters(params, "overhang") * 2.0
			var depth := _meters(params, "depth") + _meters(params, "overhang") * 2.0
			if int(params.get("covering", 0)) == 1:
				return ShellGeometry.thatch_patch(width, params)
			if int(params.patch) == 1:
				return Roof.boarding(width,depth,_meters(params,"inset"),_meters(params,"rise"),_meters(params,"lift"),float(params.get("curve",5200))/10000.0)
			return MeshKit.gable_roof(width, depth, _meters(params, "rise"))
		"R02":
			return MeshKit.box(Vector3(1.0, _meters(params, "thickness"), _meters(params, "length")))
		"R06":
			var ridge_width := _dims_width(dims) + _meters(params, "overhang") * 2.0
			if int(params.get("covering", 0)) == 1:
				return MeshKit.cylinder_x(_meters(params,"thickness") * 0.5, ridge_width, 16)
			return Roof.ridge(PackedVector3Array([Vector3.LEFT*ridge_width*0.5,Vector3.RIGHT*ridge_width*0.5]),_meters(params,"thickness"),_meters(params,"height"),float(params.get("joint_spacing",400))*0.001,true,
				int(params.get("profile",0)),float(params.get("end_lift",0))*0.001,float(params.get("foot_width",0))*0.001)
		"R19":
			return Awning.build(_dims_width(dims),params)
		"R09":
			var half := _dims_width(dims) * 0.5
			return ShellGeometry.build({"kind":"gutter", "points":[[-roundi(half * 1000),0,0],
				[roundi(half * 1000),0,0]]}, params)
		"R14":
			if int(params.get("style",0)) == 1:
				return Joinery.pagoda_finial(_meters(params,"radius"),_meters(params,"height"))
			return Joinery.turned([[0,0],[0.9,0],[1,0.15],[0.65,0.28],[0.9,0.48],
				[0.8,0.7],[0.25,0.9],[0,1]], _meters(params,"radius"), _meters(params,"height"), 24)
		"R07", "R08":
			var run := _meters(params, "run")
			var rise := _meters(params, "rise")
			var inset := _meters(params,"inset")
			var points := PackedVector3Array()
			for i in 17:
				var t := i/16.0
				points.append(Vector3(-inset*t,Roof.height_at(t,inset*t,rise,_meters(params,"lift"),float(params.get("curve",5200))/10000.0),-run*t))
			if int(params.paired) == 1:
				for i in range(15,-1,-1):
					var p := points[i]
					points.append(Vector3(p.x,p.y,-run*2.0-p.z))
			var thick := _meters(params,"thickness")
			var ridge_height := float(params.get("height",0))*0.001
			return Roof.ridge(points,thick,ridge_height if ridge_height>0 else thick*0.9,0.4,false,
				int(params.get("profile",0)),0.0,float(params.get("foot_width",0))*0.001)
		"R03":
			var course := Roof.course(params)
			if int(params.rise) == 0:
				# Free-standing legacy courses are centred on the placement.
				course.translate(Vector3.BACK * _meters(params,"length") * 0.5)
			return course
		"R15":
			return Joinery.pendant(_meters(params,"height"))
		"R04":
			return Roof.plain_drip(_meters(params,"width")) if int(params.get("pattern",0))==1 else Joinery.drip(_meters(params,"width"))
		"R05":
			return Joinery.eave_cap(_meters(params,"radius"),int(params.get("pattern",0)),
				float(params.get("neck_length",0))*0.001,float(params.get("neck_radius",0))*0.001)
		"B12":
			if int(params.get("style",0)) == 1:
				return Joinery.turned([[0,0],[0.96,0],[1,0.10],[1,0.28],[0.94,0.58],[0.77,0.87],[0.64,1],[0,1]],_meters(params,"radius"),_meters(params,"height"),32)
			if int(params.get("style",0)) == 2:
				return Joinery.turned([[0,0],[1,0],[1,0.85],[0.85,1],[0,1]],_meters(params,"radius"),_meters(params,"height"),8)
			return Joinery.post_base(_meters(params,"radius"),_meters(params,"height"))
		"B09":
			if int(params.get("style",0)) == 1:
				return Joinery.stone_post(_meters(params,"height"))
			return Joinery.turned([[0,0],[1,0],[1,0.08],[0.72,0.11],[0.60,0.82],[0.82,0.86],[0.91,0.91],[0.77,0.97],[0,1]],0.082,_meters(params,"height"),12)
		"B10":
			return Joinery.railing(_meters(params,"width"),_meters(params,"height"),int(params.get("style",0)))
		"F14":
			return MeshKit.box(Vector3(_meters(params,"length"),_meters(params,"height"),0.084))
		"O04":
			return Joinery.knocker(_meters(params,"radius"))
		"B02":
			return MeshKit.box(Vector3(0.595,_meters(params,"height"),0.24))
		"W02":
			return MeshKit.box(Vector3(1,_meters(params,"height"),0.25))
		"W06":
			return Roof.gable(_dims_width(dims),_meters(params,"rise"),_meters(params,"thickness"),float(params.get("curve",5200))/10000.0)
		"F08":
			return Joinery.block(_meters(params,"width"),_meters(params,"slot"),_meters(params,"bevel"))
		"F09":
			return Joinery.arm(_meters(params,"width"),_meters(params,"height"),_meters(params,"depth"),
				_meters(params,"bevel"),int(params.get("fork",0))==1,int(params.get("fork_angle",90)))
		"F10":
			return Ornament.ang(_meters(params,"length"),_meters(params,"bevel"))
		"F12":
			return MeshKit.box(Vector3(float(params.get("width",94))*0.001,float(params.get("height",82))*0.001,_meters(params,"length")))
		"D03":
			return Joinery.lantern(_meters(params,"height"))
		"O11":
			return Joinery.hanging(_dims_width(dims),_meters(params,"height"),int(params.get("pattern",0)))

		# 门窗装修
		"O08":
			return MeshKit.box(Vector3(1.0,_meters(params,"height"),0.008))
		"O01":
			return MeshKit.frame(
				_meters(params, "width"), _meters(params, "height"),
				_meters(params, "frame"), _meters(params, "depth"), false)
		"O06":
			return MeshKit.frame(
				_meters(params, "width"), _meters(params, "height"),
				_meters(params, "frame"), _meters(params, "depth"), true)
		"O02":
			return Joinery.leaf(_meters(params,"width"),_meters(params,"height"),_meters(params,"thickness"),
				int(params.get("pattern",0)),int(params.get("bars",5)),float(params.get("bar",21))/1000.0,int(params.get("window",0)) == 1)
		"O05":
			return MeshKit.box(Vector3(1.0, _meters(params, "height"), _meters(params, "depth")))
		"O07":
			return MeshKit.lattice(0.12, _meters(params, "height"), _meters(params, "bar"), _meters(params, "depth"))

		# 墙身 / 柱框补充
		"W03":
			return MeshKit.box(Vector3(1.0, _meters(params, "height"), _meters(params, "depth")))
		"F02":
			return Ornament.beam(1.0,_meters(params,"height"),_meters(params,"depth"),false,_meters(params,"bevel"))
		"F04":
			return Ornament.beam(_dims_width(dims),_meters(params,"height"),_meters(params,"depth"),true,_meters(params,"bevel"))
		"F05":
			return MeshKit.cylinder_x(_meters(params, "radius"), 1.0, int(params.get("sides", 8)))
		"F07":
			return MeshKit.bracket(0.5, _meters(params, "height"), _meters(params, "depth"))
		"F13":
			return MeshKit.box(Vector3(1.0, _meters(params, "thickness"), _meters(params, "length")))

		# 台基 / 装饰
		"B04":
			return MeshKit.stairs(
				_dims_width(dims), _meters(params, "height"),
				_meters(params, "depth"), int(params.get("steps", 3)))
		"B05":
			return MeshKit.box(Vector3(0.3, _meters(params, "height"), _meters(params, "depth")))
		"D01":
			return MeshKit.plaque(
				_meters(params, "width"), _meters(params, "height"),
				_meters(params, "depth"), _meters(params, "frame"))

		_:
			push_warning("AncientBuilding: no mesh builder for %s; using a unit box" % module_id)
			return MeshKit.box(Vector3.ONE)


static func _meters(params: Dictionary, key: String) -> float:
	return float(params.get(key, 0)) / 1000.0


static func _dims_width(dims: Dictionary) -> float:
	return float(dims.get("width", 6000)) / 1000.0
