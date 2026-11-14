extends RefCounted
## 凸片裁切保留独立片段，避免带洞轮廓被当作实心三角化。
const EPS := 0.00001


static func area(poly: PackedVector2Array) -> float:
	var result := 0.0
	for i in poly.size():
		result += poly[i].cross(poly[(i + 1) % poly.size()])
	return result * 0.5


static func clean(poly: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in poly:
		if result.is_empty() or p.distance_to(result[-1]) > EPS:
			result.append(p)
	if result.size() > 1 and result[0].distance_to(result[-1]) < EPS:
		result.remove_at(result.size() - 1)
	if result.size() < 3 or absf(area(result)) < EPS:
		return PackedVector2Array()
	if area(result) < 0:
		result.reverse()
	return result


static func clip(poly: PackedVector2Array, normal: Vector2, offset: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	if poly.is_empty():
		return result
	# epsilon 是米制距离。裁切产生极短边后，未归一化的法向会放大容差，留下共面细条。
	var length := normal.length()
	if length < 0.0000001:
		return poly if offset >= 0.0 else result
	normal /= length
	offset /= length
	var a := poly[-1]
	var da := normal.dot(a) - offset
	for b in poly:
		var db := normal.dot(b) - offset
		if (da <= EPS) != (db <= EPS):
			result.append(a.lerp(b, clampf(da / (da - db), 0.0, 1.0)))
		if db <= EPS:
			result.append(b)
		a = b
		da = db
	return clean(result)


static func intersect(subject: PackedVector2Array, mask: PackedVector2Array) -> PackedVector2Array:
	var result := subject
	for i in mask.size():
		var a := mask[i]
		var edge := mask[(i + 1) % mask.size()] - a
		var n := Vector2(edge.y, -edge.x)
		result = clip(result, n, n.dot(a))
		if result.is_empty():
			break
	return result


static func subtract(subject: PackedVector2Array, mask: PackedVector2Array) -> Array:
	if intersect(subject, mask).is_empty():
		return [subject]
	var result: Array = []
	var remainder := subject
	for i in mask.size():
		var a := mask[i]
		var edge := mask[(i + 1) % mask.size()] - a
		var n := Vector2(edge.y, -edge.x)
		var outside := clip(remainder, -n, -n.dot(a))
		if not outside.is_empty():
			result.append(outside)
		remainder = clip(remainder, n, n.dot(a))
		if remainder.is_empty():
			break
	return result


static func inside(point: Vector2, poly: PackedVector2Array) -> bool:
	for i in poly.size():
		if (poly[(i + 1) % poly.size()] - poly[i]).cross(point - poly[i]) < -EPS:
			return false
	return poly.size() >= 3


static func bounds(poly: PackedVector2Array) -> Rect2:
	var result := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		result = result.expand(p)
	return result


static func breaks(a: Vector2, b: Vector2, polygons: Array) -> Array[float]:
	var result: Array[float] = [0.0, 1.0]
	var direction := b - a
	for poly in polygons:
		for i in poly.size():
			var c: Vector2 = poly[i]
			var d: Vector2 = poly[(i + 1) % poly.size()]
			var cross_value := direction.cross(d - c)
			if absf(cross_value) > EPS:
				var t := (c - a).cross(d - c) / cross_value
				var s := (c - a).cross(direction) / cross_value
				if t > EPS and t < 1.0 - EPS and s >= -EPS and s <= 1.0 + EPS:
					result.append(t)
			elif absf((c - a).cross(direction)) < EPS:
				for p in [c, d]:
					var t: float = (p - a).dot(direction) / direction.length_squared()
					if t > EPS and t < 1.0 - EPS:
						result.append(t)
	result.sort()
	var unique: Array[float] = []
	for t in result:
		if unique.is_empty() or t - unique[-1] > EPS:
			unique.append(t)
	return unique


static func height(plane: Vector3, point: Vector2) -> float:
	return plane.x * point.x + plane.y * point.y + plane.z


static func plane(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var normal := (b - a).cross(c - a)
	if absf(normal.y) < EPS:
		return Vector3(0, 0, a.y)
	return Vector3(-normal.x / normal.y, -normal.z / normal.y, normal.dot(a) / normal.y)


static func encode(points: PackedVector3Array) -> Array:
	var result: Array = []
	for p in points:
		result.append([roundi(p.x * 1000), roundi(p.y * 1000), roundi(p.z * 1000)])
	return result


static func decode(points: Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for p in points:
		result.append(Vector3(p[0], p[1], p[2]) * 0.001)
	return result
