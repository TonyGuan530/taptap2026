extends RefCounted
## Rigid paper panels: split a flat stack at the crease, rotate one side about
## the hinge. Panels preserve their lengths/area. No replacement airplane mesh.
const EPS := 0.000001
var faces: Array = []
var material_faces: Array = []
var history: Array = []
var width := 0.21
var length_m := 0.30

func _init() -> void:
	reset()

func reset(ratio: float = 0.7) -> void:
	width = length_m * ratio
	faces = [PackedVector3Array([Vector3(-width/2,0,-length_m/2), Vector3(width/2,0,-length_m/2), Vector3(width/2,0,length_m/2), Vector3(-width/2,0,length_m/2)])]
	material_faces = [PackedVector2Array([Vector2(-width/2,-length_m/2),Vector2(width/2,-length_m/2),Vector2(width/2,length_m/2),Vector2(-width/2,length_m/2)])]
	history.clear()

func is_flat() -> bool:
	for face in faces:
		for point in face:
			if absf(point.y) > EPS: return false
	return true

func _clip(poly: PackedVector3Array, origin: Vector3, normal: Vector3, positive: bool) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in poly.size():
		var a: Vector3 = poly[i]
		var b: Vector3 = poly[(i+1)%poly.size()]
		var da := (a-origin).dot(normal)
		var db := (b-origin).dot(normal)
		var ina := da >= -EPS if positive else da <= EPS
		var inb := db >= -EPS if positive else db <= EPS
		if ina: out.append(a)
		if ina != inb and absf(da-db) > EPS:
			out.append(a.lerp(b,da/(da-db)))
	var clean := PackedVector3Array()
	for point in out:
		if clean.is_empty() or clean[-1].distance_squared_to(point)>EPS*EPS:
			clean.append(point)
	if clean.size()>1 and clean[0].distance_squared_to(clean[-1])<EPS*EPS:
		clean.remove_at(clean.size()-1)
	return clean

func fold(a: Vector2, b: Vector2, angle: float = PI) -> bool:
	if not is_flat() or a.distance_to(b) < 0.01: return false
	var origin := Vector3(a.x,0,a.y)
	var axis := Vector3(b.x-a.x,0,b.y-a.y).normalized()
	var normal := axis.cross(Vector3.UP)
	var parts: Array = []
	var moves: Array = []
	var patterns: Array = []
	var moving_area := 0.0
	var still_area := 0.0
	for fi in faces.size():
		var face: PackedVector3Array = faces[fi]
		for side in [false,true]:
			var clipped := _clip_pair(face,material_faces[fi],origin,normal,side)
			var part: PackedVector3Array = clipped.poly
			var area := polygon_area(part)
			if area > EPS:
				parts.append(part)
				patterns.append(clipped.material)
				moves.append(side)
				if side: moving_area += area
				else: still_area += area
	if moving_area < EPS or still_area < EPS: return false
	history.append({"before":faces.duplicate(true),"before_material":material_faces.duplicate(true),"patterns":patterns,"parts":parts,"moves":moves,"origin":origin,"axis":axis,"angle":angle,"normal":Vector3.UP})
	faces = posed_faces(1.0)
	material_faces = patterns
	return true

func _clip_pair(poly: PackedVector3Array, material: PackedVector2Array, origin: Vector3, normal: Vector3, positive: bool) -> Dictionary:
	var out := PackedVector3Array()
	var uv := PackedVector2Array()
	for i in poly.size():
		var j: int = (i+1)%poly.size()
		var da: float = (poly[i]-origin).dot(normal)
		var db: float = (poly[j]-origin).dot(normal)
		var ina: bool = da >= -EPS if positive else da <= EPS
		var inb: bool = db >= -EPS if positive else db <= EPS
		if ina:
			out.append(poly[i]); uv.append(material[i])
		if ina != inb and absf(da-db)>EPS:
			var t: float = da/(da-db)
			out.append(poly[i].lerp(poly[j],t)); uv.append(material[i].lerp(material[j],t))
	var clean := PackedVector3Array()
	var clean_uv := PackedVector2Array()
	for i in out.size():
		if clean.is_empty() or clean[-1].distance_squared_to(out[i])>EPS*EPS:
			clean.append(out[i]); clean_uv.append(uv[i])
	if clean.size()>1 and clean[0].distance_squared_to(clean[-1])<EPS*EPS:
		clean.remove_at(clean.size()-1); clean_uv.remove_at(clean_uv.size()-1)
	return {"poly":clean,"material":clean_uv}

static func _share_edge(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	# Material coordinates distinguish attached paper from merely overlapping layers.
	for i in a.size():
		var edge: Vector2 = a[(i+1)%a.size()]-a[i]
		var length: float = edge.length()
		if length<EPS: continue
		var direction: Vector2 = edge/length
		for j in b.size():
			var p: Vector2 = b[j]-a[i]
			var q: Vector2 = b[(j+1)%b.size()]-a[i]
			if absf(direction.cross(p))>EPS or absf(direction.cross(q))>EPS: continue
			var overlap: float = minf(length,maxf(p.dot(direction),q.dot(direction)))-maxf(0,minf(p.dot(direction),q.dot(direction)))
			if overlap>EPS: return true
	return false

func begin_face_fold(face_idx: int, a: Vector3, b: Vector3) -> bool:
	if face_idx<0 or face_idx>=faces.size() or a.distance_to(b)<0.01: return false
	var face: PackedVector3Array = faces[face_idx]
	var face_normal := polygon_normal(face)
	if face_normal.is_zero_approx() or absf((a-face[0]).dot(face_normal))>EPS*10 or absf((b-face[0]).dot(face_normal))>EPS*10: return false
	var axis: Vector3 = (b-a).normalized()
	var split_normal := axis.cross(face_normal).normalized()
	var still := _clip_pair(face,material_faces[face_idx],a,split_normal,false)
	var moving := _clip_pair(face,material_faces[face_idx],a,split_normal,true)
	if polygon_area(still.poly)<EPS or polygon_area(moving.poly)<EPS: return false
	var parts: Array = faces.duplicate(true)
	var patterns: Array = material_faces.duplicate(true)
	parts.remove_at(face_idx); patterns.remove_at(face_idx)
	parts.append(still.poly); patterns.append(still.material)
	parts.append(moving.poly); patterns.append(moving.material)
	var fixed_idx: int = parts.size()-2
	var flap_idx: int = parts.size()-1
	var moves: Array = []
	moves.resize(parts.size()); moves.fill(false)
	var queue: Array = [flap_idx]
	moves[flap_idx] = true
	while not queue.is_empty():
		var current: int = int(queue.pop_front())
		for next in parts.size():
			if next==current or moves[next] or not _share_edge(patterns[current],patterns[next]): continue
			if current==flap_idx and next==fixed_idx: continue
			# A closed crease loop cannot move rigidly: refuse instead of tearing paper.
			if next==fixed_idx: return false
			moves[next]=true; queue.append(next)
	var segment := PackedVector3Array()
	var low := INF
	var high := -INF
	for p in still.poly:
		if absf((p-a).dot(split_normal))<EPS*10:
			low=minf(low,(p-a).dot(axis)); high=maxf(high,(p-a).dot(axis))
	segment.append(a+axis*low); segment.append(a+axis*high)
	history.append({"before":faces.duplicate(true),"before_material":material_faces.duplicate(true),"patterns":patterns,"parts":parts,"moves":moves,"origin":a,"axis":axis,"angle":0.0,"normal":face_normal,"segment":segment})
	faces=parts
	material_faces=patterns
	return true

func set_last_angle(angle: float) -> bool:
	if history.is_empty() or not is_finite(angle): return false
	history.back().angle=clampf(angle,-PI,PI)
	faces=posed_faces(1.0)
	return true

func undo() -> bool:
	if history.is_empty(): return false
	var action: Dictionary = history.pop_back()
	faces = action.before
	material_faces = action.before_material
	return true

func posed_faces(progress: float) -> Array:
	if history.is_empty(): return faces
	var action: Dictionary = history.back()
	var rotation := Basis(action.axis,float(action.angle)*progress)
	var out: Array = []
	for i in action.parts.size():
		var poly := PackedVector3Array()
		for point in action.parts[i]:
			poly.append(action.origin + rotation*(point-action.origin) if action.moves[i] else point)
		out.append(poly)
	return out

static func polygon_area(poly: PackedVector3Array) -> float:
	var area := 0.0
	for i in range(1,poly.size()-1):
		area += (poly[i]-poly[0]).cross(poly[i+1]-poly[0]).length()*0.5
	return area

static func polygon_normal(poly: PackedVector3Array) -> Vector3:
	for i in range(1,poly.size()-1):
		var normal := (poly[i]-poly[0]).cross(poly[i+1]-poly[0])
		if normal.length_squared()>EPS*EPS: return normal.normalized()
	return Vector3.ZERO

func material_area() -> float:
	var area := 0.0
	for face in faces: area += polygon_area(face)
	return area

func mass_center() -> Vector3:
	var sum := Vector3.ZERO
	var total := 0.0
	for poly in faces:
		for i in range(1,poly.size()-1):
			var area: float = (poly[i]-poly[0]).cross(poly[i+1]-poly[0]).length()*0.5
			sum += (poly[0]+poly[i]+poly[i+1])/3.0*area
			total += area
	return sum/maxf(total,EPS)

func make_mesh(progress: float = 1.0) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var posed := posed_faces(progress)
	for fi in posed.size():
		var poly: PackedVector3Array = posed[fi]
		for i in range(1,poly.size()-1):
			var normal := (poly[i]-poly[0]).cross(poly[i+1]-poly[0]).normalized()
			for point in [poly[0],poly[i],poly[i+1]]:
				surface.set_normal(normal)
				var active: bool = not history.is_empty() and bool(history.back().moves[fi])
				surface.set_color(Color("ffe49a") if active else Color("fffdf4"))
				surface.add_vertex(point)
	return surface.commit()

func aerodynamic_panels() -> Array:
	# Sample outer surfaces along each face's dominant normal. Upright fins keep
	# aerodynamic area; overlapping layers still do not multiply lift or drag.
	var groups: Array = [[],[],[]]
	for fi in faces.size():
		var n := polygon_normal(faces[fi]).abs()
		var axis := 1
		if n.x>n.y and n.x>=n.z: axis=0
		elif n.z>n.y and n.z>n.x: axis=2
		groups[axis].append(fi)
	var dimensions: Array = [[2,1],[0,2],[0,1]]
	var panels: Array = []
	for axis in 3:
		if groups[axis].is_empty(): continue
		var u: int = dimensions[axis][0]
		var v: int = dimensions[axis][1]
		var lo := Vector2(INF,INF)
		var hi := Vector2(-INF,-INF)
		var polygons: Dictionary = {}
		for fi in groups[axis]:
			var projected := PackedVector2Array()
			for p in faces[fi]:
				var point := Vector2(p[u],p[v])
				lo=lo.min(point); hi=hi.max(point)
				projected.append(point)
			polygons[fi]=projected
		var dx: float = (hi.x-lo.x)/24.0
		var dy: float = (hi.y-lo.y)/32.0
		if dx*dy<EPS*EPS: continue
		var sums: Dictionary = {}
		for ix in 24:
			for iy in 32:
				var point := Vector2(lo.x+(ix+0.5)*dx,lo.y+(iy+0.5)*dy)
				var top := -1
				var depth := -INF
				for fi in groups[axis]:
					if not Geometry2D.is_point_in_polygon(point,polygons[fi]): continue
					var face: PackedVector3Array = faces[fi]
					var normal := polygon_normal(face)
					if absf(normal[axis])<EPS: continue
					var current: float = face[0][axis]-(normal[u]*(point.x-face[0][u])+normal[v]*(point.y-face[0][v]))/normal[axis]
					if current>depth: top=fi; depth=current
				if top<0: continue
				if not sums.has(top): sums[top]={"area":0.0,"center":Vector3.ZERO}
				var p := Vector3.ZERO
				p[u]=point.x; p[v]=point.y; p[axis]=depth
				sums[top].area += dx*dy
				sums[top].center += p*dx*dy
		for fi in sums:
			var normal := polygon_normal(faces[fi])
			if normal.y < -EPS or (absf(normal.y)<=EPS and normal[axis]<0): normal=-normal
			panels.append({"area":float(sums[fi].area)/absf(normal[axis]),"center":sums[fi].center/float(sums[fi].area),"normal":normal})
	return panels

func dart_recipe() -> Array:
	var front := -length_m/2
	var corner_z := front+width*0.5
	return [
		{"a":Vector2(0,front),"b":Vector2(-width/2,corner_z),"angle":PI},
		{"a":Vector2(width/2,corner_z),"b":Vector2(0,front),"angle":PI},
		{"a":Vector2(0,front),"b":Vector2(-width/2,front+width*1.25),"angle":PI},
		{"a":Vector2(width/2,front+width*1.25),"b":Vector2(0,front),"angle":PI},
		{"a":Vector2(0,front),"b":Vector2(0,length_m/2),"angle":deg_to_rad(14.0)},
	]
