extends RefCounted
## 量化规则（spec 008 §4.3）：先量化成整数，再进规范化哈希，避免浮点跨平台漂移。

const LENGTH_SCALE := 1000      ## 长度：0.001 m
const ANGLE_SCALE := 100        ## 角度：0.01°
const RATIO_SCALE := 10000      ## 比例/系数：1e-4


static func length(value: float) -> int:
	return roundi(value * LENGTH_SCALE)


static func angle_degrees(value: float) -> int:
	return roundi(value * ANGLE_SCALE)


static func ratio(value: float) -> int:
	return roundi(value * RATIO_SCALE)


## 把声明了类型的参数字典量化成整数；未知类型直接报错，避免静默截断。
static func params(raw: Dictionary, schema: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in raw:
		var type := String(schema.get(key, "raw"))
		var value: Variant = raw[key]
		match type:
			"length":
				out[key] = length(float(value))
			"angle":
				out[key] = angle_degrees(float(value))
			"ratio":
				out[key] = ratio(float(value))
			"int":
				out[key] = int(value)
			"bool":
				out[key] = bool(value)
			"string":
				out[key] = String(value)
			_:
				push_error("quantize: unsupported schema type '%s' for param '%s'" % [type, key])
	return out
