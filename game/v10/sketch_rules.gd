extends RefCounted
## Pure, bounded metric geometry. Each segment belongs to one original stroke.
const METRES_PER_PIXEL := 0.014
const MAX_STROKES := 24
const MAX_POINTS := 256
const CONTACT_TOLERANCE := 0.16

static func analyze(strokes: Array, kind: String, property: String = "None") -> Dictionary:
	var result := {"ok":false,"reason":"先画下你的笔迹。","kind":kind,"property":property,"length":0.0,"width":0.0,"cost":0.0,"segments":[],"polygon":PackedVector2Array(),"strokes":[],"dimensions":Vector2.ZERO}
	var allowed := ["None","Elastic","Sharp"] if kind == "blade" else ["None","Sticky","Elastic"]
	if property not in allowed:
		result.reason = "黄墨支持无词条、弹性或锋利，每件作品只选一个。" if kind == "blade" else "黑墨支持无词条、黏性或弹性，每件作品只选一个。"; return result
	if kind not in ["ladder","board","blade"]:
		result.reason = "选择梯架、板面或墨刃，让笔迹知道怎样使用。"; return result
	if strokes.is_empty(): return result
	if strokes.size() > MAX_STROKES:
		result.reason = "画纸最多保留 24 笔，请撤销一笔后再画。"; return result
	var clean: Array = []
	var minimum := Vector2(INF,INF)
	var maximum := Vector2(-INF,-INF)
	for source in strokes:
		if not (source is PackedVector2Array or source is Array) or source.size() > MAX_POINTS:
			result.reason = "每笔最多 256 个点，请保留较简洁的笔迹。"; return result
		var points := PackedVector2Array()
		for value in source:
			if not value is Vector2 or not value.is_finite():
				result.reason = "笔迹包含无效坐标，请撤销这一笔。"; return result
			minimum = minimum.min(value); maximum = maximum.max(value)
			if points.is_empty() or points[-1].distance_to(value) > 0.1: points.append(value)
		if points.size() > 1: clean.append(points)
	if clean.is_empty(): return result
	var axis := Vector2.RIGHT
	if kind == "ladder":
		var longest := 0.0
		for stroke in clean:
			var span: float = stroke[0].distance_to(stroke[-1])
			# A wide short ladder still has upright rails: its wider rungs are not its height.
			var score := span*(2.0 if absf(stroke[-1].y-stroke[0].y) > absf(stroke[-1].x-stroke[0].x) else 1.0)
			if score > longest:
				longest = score; axis = (stroke[-1]-stroke[0]).normalized()
		if absf(axis.y) > absf(axis.x):
			if axis.y > 0: axis = -axis
		elif axis.x < 0: axis = -axis
	elif kind == "blade":
		axis = Vector2.UP if maximum.y-minimum.y >= maximum.x-minimum.x else Vector2.RIGHT
	else:
		# Decorations outside a contour must not decide the solid board's main axis.
		var contour_low := minimum
		var contour_high := maximum
		var contour_area := 0.0
		for stroke in clean:
			if stroke.size() < 4 or stroke[0].distance_to(stroke[-1]) > 0.22/METRES_PER_PIXEL: continue
			var area := absf(_signed_area(stroke))
			if area > contour_area:
				contour_area = area
				contour_low = Vector2(INF,INF); contour_high = Vector2(-INF,-INF)
				for point in stroke:
					contour_low = contour_low.min(point); contour_high = contour_high.max(point)
		axis = Vector2.RIGHT if contour_high.x-contour_low.x >= contour_high.y-contour_low.y else Vector2.UP
	var side := Vector2(-axis.y,axis.x)
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for stroke in clean:
		for point in stroke:
			var projected := Vector2(point.dot(side),point.dot(axis))
			low = low.min(projected); high = high.max(projected)
	var multiplier := METRES_PER_PIXEL*(1.4 if property == "Elastic" else 1.0)
	var centre := (low.x+high.x)*0.5
	var local: Array = []
	var ink_length := 0.0
	for stroke in clean:
		var mapped := PackedVector2Array()
		for point in stroke: mapped.append(Vector2(point.dot(side)-centre,point.dot(axis)-low.y)*multiplier)
		local.append(mapped)
		for i in range(mapped.size()-1):
			result.segments.append([mapped[i],mapped[i+1]])
			ink_length += mapped[i].distance_to(mapped[i+1])
	result.strokes = local
	result.length = (high.y-low.y)*multiplier
	result.width = (high.x-low.x)*multiplier
	result.dimensions = Vector2(result.width,result.length)
	result.cost = snappedf(maxf(3.0,ink_length*5.0),0.1)
	if result.length < 0.35 or (kind != "blade" and result.width < 0.18):
		result.reason = "笔迹太小：长至少 0.35 米、宽至少 0.18 米。"; return result
	if kind == "ladder": return _ladder(result,local)
	if kind == "blade":
		result.ok = true
		result.reason = "每一笔都成为手中墨刃；左键挥砍，真实接触才会命中。"
		return result
	return _board(result,local)

static func _ladder(result: Dictionary, strokes: Array) -> Dictionary:
	var rails: Array = []
	for i in strokes.size():
		var points: PackedVector2Array = strokes[i]
		var span := points[-1]-points[0]
		if absf(span.y) >= result.length*0.64 and absf(span.y) > absf(span.x)*1.5:
			rails.append({"index":i,"points":points,"x":(points[0].x+points[-1].x)*0.5,"span":absf(span.y)})
	if rails.size() < 2:
		result.reason = "梯架需要两根较长的边梁；你的笔迹仍保留。"; return result
	var pair: Array = []
	var best := 0.0
	for a in range(rails.size()):
		for b in range(a+1,rails.size()):
			var separation: float = absf(rails[a].x-rails[b].x)
			if separation >= 0.18 and separation > best:
				best = separation; pair = [rails[a],rails[b]]
	if pair.is_empty():
		result.reason = "两根边梁靠得太近，请给脚留一点宽度。"; return result
	var rungs := 0
	for i in strokes.size():
		if i == pair[0].index or i == pair[1].index: continue
		var points: PackedVector2Array = strokes[i]
		var first := false
		var second := false
		for p in points:
			first = first or _distance_to_stroke(p,pair[0].points) <= CONTACT_TOLERANCE
			second = second or _distance_to_stroke(p,pair[1].points) <= CONTACT_TOLERANCE
		if first and second: rungs += 1
	if rungs < 2:
		result.reason = "至少两根横档要接触两侧边梁；靠近一点也可以。"; return result
	var bottom := -INF
	var top := INF
	for rail in pair:
		var low := INF
		var high := -INF
		for point in rail.points:
			low = minf(low,point.y); high = maxf(high,point.y)
		bottom = maxf(bottom,low); top = minf(top,high)
	if top-bottom < 0.35:
		result.reason = "两侧边梁没有足够的共同高度，请把它们接齐一点。"; return result
	_rebase(result,Vector2((pair[0].x+pair[1].x)*0.5,bottom))
	result.length = top-bottom
	result.width = best
	result.dimensions = Vector2(result.width,result.length)
	result.rails = [result.strokes[pair[0].index],result.strokes[pair[1].index]]
	result.rungs = rungs
	result.ok = true
	result.reason = "两侧边梁已连接，梯架沿你的实际笔迹搭起。"
	return result

static func _distance_to_stroke(point: Vector2, stroke: PackedVector2Array) -> float:
	var shortest := INF
	for i in range(stroke.size()-1):
		shortest = minf(shortest,Geometry2D.get_closest_point_to_segment(point,stroke[i],stroke[i+1]).distance_to(point))
	return shortest

static func _board(result: Dictionary, strokes: Array) -> Dictionary:
	var polygon := PackedVector2Array()
	var area := 0.0
	for stroke in strokes:
		if stroke.size() < 4 or stroke[0].distance_to(stroke[-1]) > 0.22: continue
		var candidate: PackedVector2Array = stroke.duplicate()
		candidate.remove_at(candidate.size()-1)
		var candidate_area := absf(_signed_area(candidate))
		if candidate_area > area:
			area = candidate_area; polygon = candidate
	if polygon.is_empty():
		result.reason = "板面需要一个闭合轮廓；请把这笔起点和终点接上。"; return result
	for i in polygon.size():
		for j in range(i+1,polygon.size()):
			if j == i+1 or (i == 0 and j == polygon.size()-1): continue
			if Geometry2D.segment_intersects_segment(polygon[i],polygon[(i+1)%polygon.size()],polygon[j],polygon[(j+1)%polygon.size()]) != null:
				result.reason = "轮廓交叉了，板面暂时无法承载；撤销这笔即可修改。"; return result
	if area < 0.14 or Geometry2D.triangulate_polygon(polygon).is_empty():
		result.reason = "板面没有足够的封闭面积；请把轮廓画宽一点。"; return result
	result.polygon = polygon
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for point in polygon:
		low = low.min(point); high = high.max(point)
	_rebase(result,Vector2((low.x+high.x)*0.5,low.y))
	result.length = high.y-low.y
	result.width = high.x-low.x
	result.dimensions = Vector2(result.width,result.length)
	result.area = area
	result.cost = snappedf(result.cost+area*7.0,0.1)
	result.ok = true
	result.reason = "真实轮廓会成为可走的板面，倾斜摆放就是坡道。"
	return result

static func _rebase(result: Dictionary, offset: Vector2) -> void:
	for i in result.segments.size():
		result.segments[i] = [result.segments[i][0]-offset,result.segments[i][1]-offset]
	for i in result.strokes.size():
		var stroke: PackedVector2Array = result.strokes[i]
		for j in stroke.size(): stroke[j] -= offset
		result.strokes[i] = stroke
	var polygon: PackedVector2Array = result.polygon
	for i in polygon.size(): polygon[i] -= offset
	result.polygon = polygon

static func _signed_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in points.size(): area += points[i].cross(points[(i+1)%points.size()])
	return area*0.5
