extends Node3D
## Retained line geometry at the painter's hand. Mesh and combat use identical metres.
const Art := preload("res://lowpoly/library.gd")
const STROKE_RADIUS := 0.035
const CONTACT_MARGIN := 0.005
const SWING_SECONDS := 0.36
const COOLDOWN_SECONDS := 0.68
var analysis: Dictionary = {}
var swing_time := 0.0
var cooldown := 0.0
var swinging := false
var hit_ids := {}
var swing_number := 0
var collision_segments: Array = []
var contact_queries: Array = []
var reach_radius := 0.0
var reach_query: PhysicsShapeQueryParameters3D

func configure(value: Dictionary) -> void:
	analysis = value.duplicate(true)
	position = Vector3(0.32,0.58,0.28)
	name = "OriginalStrokeBlade"
	_build_contact_geometry()
	for segment in analysis.segments:
		var a := Vector3(segment[0].x,0,segment[0].y)
		var b := Vector3(segment[1].x,0,segment[1].y)
		var line := Art.cylinder(self,STROKE_RADIUS,STROKE_RADIUS,a.distance_to(b),(a+b)*0.5,Color("eac04f"))
		line.basis = _segment_basis((b-a).normalized())
		line.set_meta("original_segment",[a,b])
	if analysis.property != "None":
		# Property badge is secondary; the main strokes always stay yellow.
		Art.box(self,Vector3(0.14,0.08,0.17),Vector3(0,0.025,0.13),Color("ee795f") if analysis.property == "Sharp" else Color("c990bd"))

func _build_contact_geometry() -> void:
	# Only union connected collinear runs within the SAME stroke. A retraced run
	# covers exactly its original line; bends and pen-up gaps are never bridged.
	for stroke in analysis.strokes:
		var origin: Vector2 = stroke[0]
		var axis: Vector2 = (stroke[1]-origin).normalized()
		var low := 0.0
		var high: float = origin.distance_to(stroke[1])
		for i in range(1,stroke.size()-1):
			var a: Vector2 = stroke[i]
			var b: Vector2 = stroke[i+1]
			if absf(axis.cross(a-origin)) <= 0.000001 and absf(axis.cross(b-origin)) <= 0.000001:
				low = minf(low,(b-origin).dot(axis)); high = maxf(high,(b-origin).dot(axis))
			else:
				collision_segments.append([origin+axis*low,origin+axis*high])
				origin = a; axis = (b-a).normalized(); low = 0; high = a.distance_to(b)
		collision_segments.append([origin+axis*low,origin+axis*high])
	for segment in collision_segments:
		var a := Vector3(segment[0].x,0,segment[0].y)
		var b := Vector3(segment[1].x,0,segment[1].y)
		var shape := CapsuleShape3D.new()
		shape.radius = STROKE_RADIUS; shape.height = a.distance_to(b)+STROKE_RADIUS*2
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape; query.collision_mask = 4; query.margin = CONTACT_MARGIN
		var padding := Vector3.ONE*(STROKE_RADIUS+query.margin+0.00001)
		contact_queries.append({"query":query,"local_frame":Transform3D(_segment_basis((b-a).normalized()),(a+b)*0.5),"a":a,"b":b,"bounds":AABB(a.min(b)-padding,a.max(b)-a.min(b)+padding*2)})
		reach_radius = maxf(reach_radius,maxf(a.length(),b.length())+STROKE_RADIUS)
	var sphere := SphereShape3D.new(); sphere.radius = reach_radius+CONTACT_MARGIN
	reach_query = PhysicsShapeQueryParameters3D.new(); reach_query.shape = sphere; reach_query.collision_mask = 4

func _nearby_targets() -> Array:
	# A sphere contains every retained segment at every swing angle. The broad
	# query only filters empty space; the original capsule query still decides hits.
	var parent_frame: Transform3D = get_parent().global_transform
	var parent_scale := parent_frame.basis.get_scale().abs()
	# Godot query margin is in world metres even when the geometry is scaled.
	reach_query.shape.radius = reach_radius*maxf(parent_scale.x,maxf(parent_scale.y,parent_scale.z))+CONTACT_MARGIN
	reach_query.transform = Transform3D(Basis.IDENTITY,parent_frame*position)
	var space := get_world_3d().direct_space_state
	var capacity := 16
	var contacts := space.intersect_shape(reach_query,capacity)
	while contacts.size() == capacity:
		capacity *= 2; contacts = space.intersect_shape(reach_query,capacity)
	var targets: Array = []
	for contact in contacts:
		var body: CollisionObject3D = contact.collider
		var id := body.get_instance_id()
		if hit_ids.has(id): continue
		var target := {"id":id,"shapes":[],"unbounded":false}
		for owner in body.get_shape_owners():
			if body.is_shape_owner_disabled(owner): continue
			for i in body.shape_owner_get_shape_count(owner):
				var bounds = _shape_bounds(body.shape_owner_get_shape(owner,i))
				if bounds == null: target.unbounded = true
				else: target.shapes.append({"bounds":bounds,"frame":body.global_transform*body.shape_owner_get_transform(owner)})
		targets.append(target)
	return targets

static func _shape_bounds(shape: Shape3D):
	if shape is BoxShape3D: return AABB(-shape.size*0.5,shape.size)
	if shape is CapsuleShape3D:
		var extent := Vector3(shape.radius,shape.height*0.5,shape.radius)
		return AABB(-extent,extent*2)
	if shape is SphereShape3D:
		var extent: Vector3 = Vector3.ONE*shape.radius
		return AABB(-extent,extent*2)
	# Unknown shapes bypass the coarse filter and retain exact Godot contact.
	return null

func _project_targets(targets: Array, frame: Transform3D) -> Array:
	var projected: Array = []
	var inverse := frame.affine_inverse()
	var unit_scale := frame.basis.get_scale().abs().is_equal_approx(Vector3.ONE)
	for target in targets:
		if hit_ids.has(target.id): continue
		# Local padding cannot represent an unscaled world margin under arbitrary
		# parent scale. That rare path retains the exact cached capsule query.
		var item := {"id":target.id,"bounds":[],"unbounded":target.unbounded or not unit_scale}
		if not item.unbounded:
			for shape in target.shapes: item.bounds.append(inverse*shape.frame*shape.bounds)
		projected.append(item)
	return projected

func _may_touch(bounds: AABB, targets: Array) -> bool:
	for target in targets:
		if hit_ids.has(target.id): continue
		if target.unbounded: return true
		for box in target.bounds:
			if bounds.intersects(box): return true
	return false

func begin_swing() -> bool:
	if cooldown > 0 or swinging: return false
	swinging = true; swing_time = 0; cooldown = COOLDOWN_SECONDS
	hit_ids.clear(); swing_number += 1; rotation.y = -0.85
	return true

func cancel_swing() -> void:
	swinging = false; swing_time = 0; rotation.y = 0

func step(delta: float) -> Array:
	cooldown = maxf(0,cooldown-delta)
	var hits: Array = []
	if not swinging: return hits
	var from := lerpf(-0.85,0.85,swing_time/SWING_SECONDS)
	swing_time = minf(SWING_SECONDS,swing_time+delta)
	var to := lerpf(-0.85,0.85,swing_time/SWING_SECONDS)
	# Angular substeps keep a narrow real stroke from tunnelling across a target.
	var count := maxi(1,int(ceil(absf(to-from)*maxf(1,analysis.length)/0.025)))
	var targets := _nearby_targets()
	for sample in range(count+1):
		if targets.is_empty(): break
		var angle := lerpf(from,to,float(sample)/count)
		var frame: Transform3D = get_parent().global_transform*Transform3D(Basis(Vector3.UP,angle),position)
		var bounds := _project_targets(targets,frame)
		if bounds.is_empty(): break
		for entry in contact_queries:
			if not _may_touch(entry.bounds,bounds): continue
			var a: Vector3 = frame*entry.a
			var b: Vector3 = frame*entry.b
			var query: PhysicsShapeQueryParameters3D = entry.query
			query.transform = frame*entry.local_frame
			for contact in get_world_3d().direct_space_state.intersect_shape(query,16):
				var body: Object = contact.collider
				var id := body.get_instance_id()
				if hit_ids.has(id): continue
				# A solid fold between hand and contact remains a real obstruction.
				var nearest := Geometry3D.get_closest_point_to_segment(body.global_position,a,b)
				var blocker := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(frame.origin,nearest,1))
				if not blocker.is_empty() and blocker.collider != body: continue
				hit_ids[id] = true; hits.append(body)
	rotation.y = to
	if swing_time >= SWING_SECONDS:
		swinging = false; rotation.y = 0
	return hits

func world_segments() -> Array:
	var result: Array = []
	for segment in analysis.get("segments",[]):
		result.append([global_transform*Vector3(segment[0].x,0,segment[0].y),global_transform*Vector3(segment[1].x,0,segment[1].y)])
	return result

static func _segment_basis(axis: Vector3) -> Basis:
	var reference := Vector3.RIGHT if absf(axis.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var side := reference.cross(axis).normalized()
	return Basis(side,axis,side.cross(axis).normalized())
