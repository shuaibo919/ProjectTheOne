extends RefCounted
const Data := preload("res://addons/ancient_building/core/mesh_data.gd")
## 稳定的局部缺口与凹损；作用于实际顶点，保护木作两端承托区。
const Kit := preload("res://addons/ancient_building/core/mesh_kit.gd")
const TARGETS := ["B01", "B02", "B04", "B05", "B12", "F01", "F02", "F04", "F05",
	"F08", "F09", "F10", "F11", "F12", "F13", "F14", "W01", "W02", "W06",
	"O02", "O05", "O11", "R01", "R03", "R04", "R05", "R06", "R07", "R08", "R11", "R12"]


static func family(id: String) -> String:
	if id.begins_with("B") or id == "W02":
		return "stone"
	if id == "W01":
		return "wall"
	if id.begins_with("R") and id != "R01":
		return "roof"
	return "wood"


static func sample(seed_value: int, channel: int) -> float:
	var value := (seed_value * 1103515245 + channel * 12345 + 1013904223) & 0x7fffffff
	value = ((value >> 11) ^ value) * 48271 & 0x7fffffff
	return float(value) / 2147483648.0


static func apply(mesh: Data, id: String, params: Dictionary) -> Data:
	var amount := float(params.get("damage", 0)) / 10000.0
	var density := float(params.get("damage_density", 5000)) / 10000.0
	if amount <= 0.0 or density <= 0.0 or id not in TARGETS:
		return mesh
	var box := mesh.get_aabb()
	var settings := {"amount":amount, "density":density,
		"depth":float(params.get("damage_depth", 40)) * 0.001,
		"seed":int(params.get("damage_seed", 0)), "family":family(id), "axis":0}
	if id == "F01" or id == "O02":
		settings.axis = 1
	elif id in ["F10", "F11", "F12", "F13", "R03", "R01"]:
		settings.axis = 2
	if id == "W01" and int(params.get("wall_kind", 0)) >= 2:
		settings.family = "wood"
		settings.axis = 1 if int(params.wall_kind) == 2 else 0
	if id == "R05" and int(params.get("neck_length",0))>0:
		settings.cap_back = -float(params.radius)*0.001*0.24
		settings.neck_rear = settings.cap_back-float(params.neck_length)*0.001
	settings.chips = []
	settings.regions = []
	settings.cache = {}
	for i in 4:
		if sample(settings.seed, i * 11 + 1) <= density:
			var center := Vector3(sample(settings.seed, i * 11 + 2),
				sample(settings.seed, i * 11 + 3), sample(settings.seed, i * 11 + 4))
			center[(i + int(settings.seed)) % 3] = 0.0 if i % 2 == 0 else 1.0
			settings.chips.append(center)
			var extent := Vector3.ONE * (0.30 if settings.family == "wall" else 0.24)
			if settings.family == "wood":
				extent[int(settings.axis)] = 0.48
			extent *= box.size.max(Vector3.ONE*0.001)
			settings.regions.append(AABB(box.position+center*box.size-extent,extent*2.0))
	if settings.chips.is_empty():
		return mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var semantics: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, count, 3):
			var ids: Array = [i, i + 1, i + 2]
			if not indices.is_empty():
				ids = [indices[i], indices[i + 1], indices[i + 2]]
			var n := normals[ids[0]] if normals.size() == vertices.size() else Vector3.UP
			var nb := normals[ids[1]] if normals.size() == vertices.size() else n
			var nc := normals[ids[2]] if normals.size() == vertices.size() else n
			st.set_meta("ab_grain_axis", roundi(semantics[ids[0]].x)-1 if semantics.size()==vertices.size() and absf(semantics[ids[0]].y-7.0)<0.01 else -1)
			_triangle(st, vertices[ids[0]], vertices[ids[1]], vertices[ids[2]], n, nb, nc, box, settings, 0,
				uvs[ids[0]] if not uvs.is_empty() else Vector2.ZERO,
				uvs[ids[1]] if not uvs.is_empty() else Vector2.ZERO,
				uvs[ids[2]] if not uvs.is_empty() else Vector2.ZERO)
	return Data.new(st)


static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, nb: Vector3, nc: Vector3,
		box: AABB, settings: Dictionary, level: int, uva: Vector2, uvb: Vector2, uvc: Vector2) -> void:
	var region := AABB(a,Vector3.ZERO).expand(b).expand(c).grow(0.0001)
	var affected := false
	for chip in settings.regions:
		if region.intersects(chip):
			affected = true
			break
	if not affected:
		Kit._add_tri(st,a,b,c,normal,nb,nc,uva,uvb,uvc)
		return
	if level < 2 and maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a))) > 0.20:
		var ab := (a + b) * 0.5
		var bc := (b + c) * 0.5
		var ca := (c + a) * 0.5
		var nab := (normal+nb).normalized()
		var nbc := (nb+nc).normalized()
		var nca := (nc+normal).normalized()
		var uvab := (uva+uvb)*0.5
		var uvbc := (uvb+uvc)*0.5
		var uvca := (uvc+uva)*0.5
		_triangle(st, a, ab, ca, normal, nab, nca, box, settings, level + 1,uva,uvab,uvca)
		_triangle(st, ab, b, bc, nab, nb, nbc, box, settings, level + 1,uvab,uvb,uvbc)
		_triangle(st, ca, bc, c, nca, nbc, nc, box, settings, level + 1,uvca,uvbc,uvc)
		_triangle(st, ab, bc, ca, nab, nbc, nca, box, settings, level + 1,uvab,uvbc,uvca)
		return
	var prior_face := (b-a).cross(c-a).normalized()
	if prior_face.dot(normal) < 0:
		prior_face = -prior_face
	a = _deform(a, box, settings)
	b = _deform(b, box, settings)
	c = _deform(c, box, settings)
	var face := (b - a).cross(c - a).normalized()
	if face.dot(normal) < 0:
		face = -face
	if face.length_squared() > 0.1:
		# 保留车旋柱/瓦片/柱础的平滑法线，局部形变只叠加面方向变化。
		var change := face-prior_face
		Kit._add_tri(st, a, b, c, (normal+change).normalized(), (nb+change).normalized(), (nc+change).normalized(),uva,uvb,uvc)


static func _deform(p: Vector3, box: AABB, settings: Dictionary) -> Vector3:
	if settings.cache.has(p):
		return settings.cache[p]
	var size := box.size.max(Vector3.ONE * 0.001)
	var q := (p - box.position) / size
	var axis := int(settings.axis)
	var wood: bool = settings.family == "wood"
	var protection := 1.0
	if wood:
		protection = smoothstep(0.015, 0.09, minf(q[axis], 1.0 - q[axis]))
	var bite := 0.0
	for center in settings.chips:
		var stretch := Vector3.ONE * (0.30 if settings.family == "wall" else 0.24)
		if wood:
			stretch[axis] = 0.48
		var distance: float = ((q - center) / stretch).length()
		bite = maxf(bite, pow(maxf(0.0, 1.0 - distance), 1.2))
	var inward := box.get_center() - p
	if wood:
		inward[axis] = 0.0
	var depth := minf(float(settings.depth), minf(size.x, minf(size.y, size.z)) * 0.35)
	var result := p + inward.normalized() * depth * float(settings.amount) * bite * protection
	if settings.has("cap_back"):
		if p.z>=float(settings.cap_back)-0.000001:
			# The disk may chip, but must not deform backwards through the drip.
			result.z = maxf(result.z,float(settings.cap_back))
		else:
			# Preserve the mating edge of the back neck at the roof tile's toe.
			result = p.lerp(result,smoothstep(float(settings.neck_rear),float(settings.neck_rear)+0.01,p.z))
	settings.cache[p] = result
	return result
