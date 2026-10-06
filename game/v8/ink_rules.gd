extends RefCounted
## Geometry/material rules. No shape names, inventory mutation or random puzzle answers.
const Contour := preload("res://tonight06/doodle_geometry.gd")
const WORDS := ["Elastic","Sticky","Sharp","Magnetic","Float","Heavy"]
const NAMES := {"Elastic":"弹性","Sticky":"黏性","Sharp":"锋利","Magnetic":"磁性","Float":"漂浮","Heavy":"沉重"}
const COLORS := {"Elastic":Color("e7a969"),"Sticky":Color("bd87d0"),"Sharp":Color("a2d9be"),"Magnetic":Color("7cbddc"),"Float":Color("68dcca"),"Heavy":Color("b09d80")}
const HINTS := {"Elastic":"线条伸长 50%；够到木桩便能把自己拉过河。","Sticky":"开放笔画触到画页／钥匙就抓住；线太短会够不到。","Sharp":"笔画真正碰到藤蔓才切断；也能抽击污墨。","Magnetic":"笔画附近 0.9 米吸住铁钥匙／安全拉杆。","Float":"封闭轮廓浮在水面，轮廓决定能踩的范围。","Heavy":"封闭造物按面积提供重量，压机关、撬藤根或挡弹。"}

static func stroke(raw: PackedVector2Array, closed: bool) -> Dictionary:
	if closed:
		var result := Contour.from_stroke(raw,0.00625,0.16)
		if not result.is_empty(): result.kind = "closed"
		return result
	if raw.size() < 2 or raw.size() > 256: return {}
	var points := PackedVector2Array()
	var length := 0.0
	for point: Vector2 in raw:
		if not point.is_finite() or point.length() > 10000: return {}
		var local := (point-raw[0])*0.012
		if points.is_empty() or local.distance_to(points[-1]) > 0.015:
			if not points.is_empty(): length += local.distance_to(points[-1])
			points.append(local)
	if points.size() < 2 or length < 0.25 or length > 9.0 or points[-1].length() < 0.1: return {}
	return {"kind":"open","points":points,"length":length,"reach":points[-1].length(),"cost":clampi(8+ceili(length*3.0),10,38)}

static func world_path(tool: Dictionary, origin: Vector2, aim: Vector2, word: String) -> PackedVector2Array:
	var result := PackedVector2Array()
	if tool.get("kind","") != "open": return result
	var points: PackedVector2Array = tool.points
	var heading := aim.normalized() if aim.length() > 0.01 else Vector2.RIGHT
	var angle := heading.angle()-points[-1].angle()
	var scale_value := 1.5 if word == "Elastic" else 1.0
	for point: Vector2 in points: result.append(origin+point.rotated(angle)*scale_value)
	return result

static func path_distance(path: PackedVector2Array, point: Vector2) -> float:
	var nearest := INF
	for i in range(1,path.size()):
		nearest = minf(nearest,Geometry2D.get_closest_point_to_segment(point,path[i-1],path[i]).distance_to(point))
	return nearest

static func solid_contains(tool: Dictionary, center: Vector2, angle: float, point: Vector2, tolerance := 0.0) -> bool:
	if tool.get("kind","") != "closed": return false
	# Godot positive Y maps XZ clockwise, the opposite sign of Vector2 rotation.
	var local := (point-center).rotated(angle)
	var polygon: PackedVector2Array = tool.polygon
	if Geometry2D.is_point_in_polygon(local,polygon): return true
	if tolerance > 0:
		for i in polygon.size():
			if Geometry2D.get_closest_point_to_segment(local,polygon[i],polygon[(i+1)%polygon.size()]).distance_to(local) < tolerance: return true
	return false

static func remote_contact(tool: Dictionary, origin: Vector2, aim: Vector2, word: String, object: Vector2) -> bool:
	if word not in ["Sticky","Magnetic"] or tool.get("kind","") != "open": return false
	return path_distance(world_path(tool,origin,aim,word),object) <= (0.9 if word == "Magnetic" else 0.42)

static func weight_contact(tool: Dictionary, center: Vector2, angle: float, word: String, plate: Vector2) -> bool:
	return word == "Heavy" and tool.get("area",0.0) >= 0.3 and solid_contains(tool,center,angle,plate,0.06)

static func rope_contact(tool: Dictionary, origin: Vector2, aim: Vector2, word: String, anchor: Vector2) -> bool:
	if word not in ["Elastic","Sticky"] or tool.get("kind","") != "open": return false
	var path := world_path(tool,origin,aim,word)
	return path_distance(path,anchor) < 0.48 and origin.distance_to(anchor) >= 2.0

static func vine_contact(tool: Dictionary, origin: Vector2, aim: Vector2, word: String, vines: Vector2) -> bool:
	return word == "Sharp" and tool.get("kind","") == "open" and path_distance(world_path(tool,origin,aim,word),vines) < 0.55

static func shield_intercepts(tool: Dictionary, center: Vector2, angle: float, from: Vector2, to: Vector2) -> bool:
	if tool.get("kind","") != "closed": return false
	if solid_contains(tool,center,angle,from) or solid_contains(tool,center,angle,to): return true
	var polygon: PackedVector2Array = tool.polygon
	for i in polygon.size():
		if Geometry2D.segment_intersects_segment(from,to,center+polygon[i].rotated(-angle),center+polygon[(i+1)%polygon.size()].rotated(-angle)) != null: return true
	return false

static func seed_manifest(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var first := [["Sticky","Magnetic"][rng.randi_range(0,1)],["Elastic","Float"][rng.randi_range(0,1)],["Sharp","Heavy"][rng.randi_range(0,1)]]
	var remaining: Array = WORDS.duplicate()
	for word in first: remaining.erase(word)
	for i in range(remaining.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var temp: String = remaining[i]
		remaining[i] = remaining[j]
		remaining[j] = temp
	return first+remaining
