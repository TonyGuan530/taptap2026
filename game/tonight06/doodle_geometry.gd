extends RefCounted
## Converts one simple freehand outline into a centered, horizontal 3D solid.
## Invalid contours return {}; callers can keep the drawing and show a hint.
## No class_name: the demo can load this helper before editor import completes.

const MAX_POINTS := 256
const MAX_RAW_POINTS := 4096
const MAX_EXTENT := 3.2
const MIN_EXTENT := 0.1
const MIN_AREA := 0.005
const EPSILON := 0.000001

static func from_stroke(points: PackedVector2Array, meters_per_pixel: float = 0.00625, thickness: float = 0.22) -> Dictionary:
	if points.size() < 3 or points.size() > MAX_RAW_POINTS:
		return {}
	if not is_finite(meters_per_pixel) or meters_per_pixel <= 0.0 or meters_per_pixel > 1.0:
		return {}
	if not is_finite(thickness) or thickness < 0.01 or thickness > 1.0:
		return {}
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point: Vector2 in points:
		if not point.is_finite() or absf(point.x) > 1000000.0 or absf(point.y) > 1000000.0:
			return {}
		low = low.min(point)
		high = high.max(point)
	var footprint := (high - low) * meters_per_pixel
	if not footprint.is_finite() or footprint.x < MIN_EXTENT or footprint.y < MIN_EXTENT:
		return {}
	# Vector2 uses float32: an exact 512px * 0.00625m becomes 3.2000000477.
	# Keep the authored limit while tolerating numerical conversion noise.
	if footprint.x > MAX_EXTENT + EPSILON or footprint.y > MAX_EXTENT + EPSILON:
		return {}
	var center := (low + high) * 0.5
	var polygon := PackedVector2Array()
	for point: Vector2 in points:
		var local := (point - center) * meters_per_pixel
		if polygon.is_empty() or local.distance_squared_to(polygon[-1]) > EPSILON * EPSILON:
			polygon.append(local)
	if polygon.size() > 1 and polygon[0].distance_squared_to(polygon[-1]) <= EPSILON * EPSILON:
		polygon.remove_at(polygon.size() - 1)
	_remove_collinear_samples(polygon)
	if polygon.size() < 3 or polygon.size() > MAX_POINTS or not _is_simple(polygon):
		return {}
	var signed_area := _signed_area(polygon)
	var area := absf(signed_area)
	if not is_finite(area) or area < MIN_AREA:
		return {}
	# Positive 2D area makes clockwise top faces when XY is mapped to XZ.
	if signed_area < 0.0:
		polygon.reverse()
	var triangles := Geometry2D.triangulate_polygon(polygon)
	if triangles.size() != (polygon.size() - 2) * 3:
		return {}
	var triangulated_area := 0.0
	for i in range(0, triangles.size(), 3):
		var a := polygon[triangles[i]]
		var b := polygon[triangles[i + 1]]
		var c := polygon[triangles[i + 2]]
		var twice_area := (b - a).cross(c - a)
		if twice_area <= EPSILON:
			return {}
		triangulated_area += twice_area * 0.5
	if absf(triangulated_area - area) > maxf(EPSILON * 10.0, area * 0.0001):
		return {}
	var pieces := Geometry2D.decompose_polygon_in_convex(polygon)
	if pieces.is_empty():
		return {}
	var shapes: Array[ConvexPolygonShape3D] = []
	var collision_area := 0.0
	var half_height := thickness * 0.5
	for piece: PackedVector2Array in pieces:
		if piece.size() < 3:
			return {}
		collision_area += absf(_signed_area(piece))
		var vertices := PackedVector3Array()
		for point: Vector2 in piece:
			vertices.append(Vector3(point.x, -half_height, point.y))
			vertices.append(Vector3(point.x, half_height, point.y))
		var shape := ConvexPolygonShape3D.new()
		shape.points = vertices
		shape.margin = 0.002
		shapes.append(shape)
	if absf(collision_area - area) > maxf(EPSILON * 10.0, area * 0.0001):
		return {}
	var size := Vector3(footprint.x, thickness, footprint.y)
	var mesh := _extrude_mesh(polygon, triangles, size)
	if mesh == null:
		return {}
	var perimeter := 0.0
	for i in polygon.size():
		perimeter += polygon[i].distance_to(polygon[(i + 1) % polygon.size()])
	return {
		"polygon": polygon,
		"mesh": mesh,
		"shapes": shapes,
		"size": size,
		"area": area,
		"cost": clampi(int(ceil(area * 8.0 + perimeter * 2.0)), 15, 65),
	}

static func _remove_collinear_samples(polygon: PackedVector2Array) -> void:
	var changed := true
	while changed and polygon.size() > 3:
		changed = false
		for i in polygon.size():
			var previous := polygon[(i - 1 + polygon.size()) % polygon.size()]
			var current := polygon[i]
			var next := polygon[(i + 1) % polygon.size()]
			var before := current - previous
			var after := next - current
			if absf(before.cross(after)) <= EPSILON and before.dot(after) >= 0.0:
				polygon.remove_at(i)
				changed = true
				break

static func _is_simple(polygon: PackedVector2Array) -> bool:
	var count := polygon.size()
	for i in count:
		var a := polygon[i]
		var b := polygon[(i + 1) % count]
		var c := polygon[(i + 2) % count]
		if a.distance_squared_to(b) <= EPSILON * EPSILON:
			return false
		# Adjacent segments may meet, but may not double back over each other.
		if absf((b - a).cross(c - b)) <= EPSILON and (b - a).dot(c - b) < 0.0:
			return false
		for j in range(i + 1, count):
			if j == i + 1 or (i == 0 and j == count - 1):
				continue
			if _segments_intersect(a, b, polygon[j], polygon[(j + 1) % count]):
				return false
	return true

static func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab_c := (b - a).cross(c - a)
	var ab_d := (b - a).cross(d - a)
	var cd_a := (d - c).cross(a - c)
	var cd_b := (d - c).cross(b - c)
	if ((ab_c > EPSILON and ab_d < -EPSILON) or (ab_c < -EPSILON and ab_d > EPSILON)) and ((cd_a > EPSILON and cd_b < -EPSILON) or (cd_a < -EPSILON and cd_b > EPSILON)):
		return true
	if absf(ab_c) <= EPSILON and _on_segment(a, b, c):
		return true
	if absf(ab_d) <= EPSILON and _on_segment(a, b, d):
		return true
	if absf(cd_a) <= EPSILON and _on_segment(c, d, a):
		return true
	if absf(cd_b) <= EPSILON and _on_segment(c, d, b):
		return true
	return false

static func _on_segment(a: Vector2, b: Vector2, point: Vector2) -> bool:
	return point.x >= minf(a.x, b.x) - EPSILON and point.x <= maxf(a.x, b.x) + EPSILON and point.y >= minf(a.y, b.y) - EPSILON and point.y <= maxf(a.y, b.y) + EPSILON

static func _signed_area(polygon: PackedVector2Array) -> float:
	var total := 0.0
	for i in polygon.size():
		total += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return total * 0.5

static func _extrude_mesh(polygon: PackedVector2Array, triangles: PackedInt32Array, size: Vector3) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_height := size.y * 0.5
	for i in range(0, triangles.size(), 3):
		var a := polygon[triangles[i]]
		var b := polygon[triangles[i + 1]]
		var c := polygon[triangles[i + 2]]
		_add_triangle(surface, Vector3(a.x, half_height, a.y), Vector3(b.x, half_height, b.y), Vector3(c.x, half_height, c.y), Vector3.UP, size)
		_add_triangle(surface, Vector3(a.x, -half_height, a.y), Vector3(c.x, -half_height, c.y), Vector3(b.x, -half_height, b.y), Vector3.DOWN, size)
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var edge := b - a
		var normal := Vector3(edge.y, 0.0, -edge.x).normalized()
		var bottom_a := Vector3(a.x, -half_height, a.y)
		var bottom_b := Vector3(b.x, -half_height, b.y)
		var top_a := Vector3(a.x, half_height, a.y)
		var top_b := Vector3(b.x, half_height, b.y)
		_add_triangle(surface, bottom_a, bottom_b, top_b, normal, size)
		_add_triangle(surface, bottom_a, top_b, top_a, normal, size)
	return surface.commit()

static func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, size: Vector3) -> void:
	for vertex: Vector3 in [a, b, c]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(vertex.x / size.x + 0.5, vertex.z / size.z + 0.5))
		surface.add_vertex(vertex)
