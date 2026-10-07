extends RefCounted
## Rigid paper panels: split a flat stack at the crease, rotate one side about
## the hinge. Panels preserve their lengths/area. No replacement airplane mesh.
const EPS := 0.000001
var faces: Array = []
var history: Array = []
var width := 0.21
var length_m := 0.30

func _init() -> void:
	reset()

func reset(ratio: float = 0.7) -> void:
	width = length_m * ratio
	faces = [PackedVector3Array([Vector3(-width/2,0,-length_m/2), Vector3(width/2,0,-length_m/2), Vector3(width/2,0,length_m/2), Vector3(-width/2,0,length_m/2)])]
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
	var moving_area := 0.0
	var still_area := 0.0
	for face in faces:
		for side in [false,true]:
			var part := _clip(face,origin,normal,side)
			var area := polygon_area(part)
			if area > EPS:
				parts.append(part)
				moves.append(side)
				if side: moving_area += area
				else: still_area += area
	if moving_area < EPS or still_area < EPS: return false
	history.append({"before":faces.duplicate(true),"parts":parts,"moves":moves,"origin":origin,"axis":axis,"angle":angle})
	faces = posed_faces(1.0)
	return true

func undo() -> bool:
	if history.is_empty(): return false
	faces = history.pop_back().before
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
				surface.set_color(Color("fff6da") if fi%2 else Color("ffffff"))
				surface.add_vertex(point)
	return surface.commit()

func aerodynamic_panels() -> Array:
	# Top-view quadrature selects the outer surface of each stack, so overlapping
	# layers add mass but do not incorrectly multiply the aerodynamic wing area.
	var xmin := INF
	var xmax := -INF
	var zmin := INF
	var zmax := -INF
	var polygons: Array = []
	for face in faces:
		var projected := PackedVector2Array()
		for p in face:
			xmin=minf(xmin,p.x); xmax=maxf(xmax,p.x)
			zmin=minf(zmin,p.z); zmax=maxf(zmax,p.z)
			projected.append(Vector2(p.x,p.z))
		polygons.append(projected)
	var dx := (xmax-xmin)/24.0
	var dz := (zmax-zmin)/32.0
	var sums: Dictionary = {}
	for ix in 24:
		for iz in 32:
			var p := Vector2(xmin+(ix+0.5)*dx,zmin+(iz+0.5)*dz)
			var top := -1
			var top_y := -INF
			for fi in faces.size():
				if not Geometry2D.is_point_in_polygon(p,polygons[fi]): continue
				var face: PackedVector3Array = faces[fi]
				var n := polygon_normal(face)
				if absf(n.y)<0.001: continue
				var y := face[0].y-(n.x*(p.x-face[0].x)+n.z*(p.y-face[0].z))/n.y
				if y>top_y: top=fi; top_y=y
			if top<0: continue
			if not sums.has(top): sums[top]={"area":0.0,"center":Vector3.ZERO}
			sums[top].area += dx*dz
			sums[top].center += Vector3(p.x,top_y,p.y)*dx*dz
	var panels: Array = []
	for fi in sums:
		var face: PackedVector3Array = faces[fi]
		var n := polygon_normal(face)
		if n.y<0: n=-n
		panels.append({"area":float(sums[fi].area)/maxf(n.y,0.1),"center":sums[fi].center/float(sums[fi].area),"normal":n})
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
