extends SceneTree
const Paper := preload("res://demo08_3d/paper_geometry.gd")
const Flight := preload("res://demo08_3d/paper_flight.gd")
var failures := 0

func check(ok: bool, text: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+text)
	if not ok: failures += 1

func trajectory(paper, angle: float, fps: float = 60.0, wind := Vector3.ZERO, steering: float = 0.0, dive: bool = false) -> Dictionary:
	var body = Flight.new()
	body.launch(paper,angle,1.0)
	var time := 0.0
	var apex: float = body.position.y
	while body.position.y>0 and time<14:
		body.step(1.0/fps,wind,steering,dive)
		time += 1.0/fps
		apex=maxf(apex,body.position.y)
		if not body.position.is_finite(): break
	return {"distance":-body.position.z,"time":time,"apex":apex,"body":body}

func _initialize() -> void:
	var paper = Paper.new()
	var original_area: float = paper.material_area()
	check(not paper.fold(Vector2.ZERO,Vector2.ZERO),"reject zero-length crease")
	check(paper.fold(Vector2(0,-0.15),Vector2(0,0.15),PI/2),"crease splits and rotates paper")
	check(absf(paper.material_area()-original_area)<0.000001,"fold conserves paper area / mass")
	var height := 0.0
	for face in paper.faces:
		for point in face: height=maxf(height,absf(point.y))
	check(height>0.09,"fold produces 3D vertices, not scaled boxes")
	var action: Dictionary = paper.history.back()
	for i in paper.faces.size():
		for j in paper.faces[i].size():
			var k: int = (j+1)%paper.faces[i].size()
			check(absf(paper.faces[i][j].distance_to(paper.faces[i][k])-action.parts[i][j].distance_to(action.parts[i][k]))<0.000001,"hinge preserves panel edge length")
	check(paper.undo() and paper.faces.size()==1,"undo restores original sheet")
	for fold in paper.dart_recipe(): check(paper.fold(fold.a,fold.b,float(fold.angle)),"dart crease accepted")
	check(absf(paper.material_area()-original_area)<0.000001,"five folds preserve sheet area")
	var body = Flight.new()
	body.launch(paper,12,1)
	check(body.area<original_area*0.90 and body.area>0.005,"overlapping layers do not multiply lift area")
	check(absf(body.mass-original_area*0.08)<0.000001,"mass comes from original 80gsm paper")
	check(body.surface_force(Vector3.UP,Vector3.ZERO,0.01)==Vector3.ZERO,"zero airspeed produces no lift or drag")
	var force: Vector3 = body.surface_force(Vector3.UP,Vector3(0,0,-10),0.01)
	check(force.dot(Vector3(0,0,-10))<0,"drag opposes relative air velocity")
	check(body.lift_curve.sample_baked(15)>body.lift_curve.sample_baked(40),"open-source curve models stall")
	var dart_path := trajectory(paper,12)
	var flat = Paper.new()
	var flat_path := trajectory(flat,12)
	check(dart_path.body.position.is_finite() and dart_path.time<14,"finite flight reaches ground")
	check(absf(float(dart_path.distance)-float(flat_path.distance))>0.5,"folded geometry changes trajectory")
	var slow := trajectory(paper,12,30)
	var fast := trajectory(paper,12,120)
	check(absf(float(slow.distance)-float(fast.distance))<0.4,"30/120fps equivalent flight")
	var headwind := trajectory(paper,12,60,Vector3(0,0,3))
	check(absf(float(headwind.distance)-float(dart_path.distance))>0.2,"wind changes airspeed and forces")
	var left := trajectory(paper,12,60,Vector3.ZERO,-0.25)
	var right := trajectory(paper,12,60,Vector3.ZERO,0.25)
	check(right.body.position.x>left.body.position.x+0.5,"A/D roll moments change lateral trajectory in the expected direction")
	var diving := trajectory(paper,12,60,Vector3.ZERO,0.0,true)
	check(diving.apex<dart_path.apex and diving.time<dart_path.time,"S pitch moment lowers flight and reaches ground sooner")
	for angle in [8,12,20,30,40]:
		var route := trajectory(paper,angle)
		print("FLIGHT angle=%d distance=%.2f time=%.2f apex=%.2f" % [angle,route.distance,route.time,route.apex])
	for wind in [Vector3(0,0,2),Vector3(1.5,0,0),Vector3(0,0,-2)]:
		var route := trajectory(paper,12,60,wind)
		print("WIND %s distance=%.2f time=%.2f lateral=%.2f" % [wind,route.distance,route.time,route.body.position.x])
	print("PHYSICS_RESULT failures=%d dart=%.2fm flat=%.2fm" % [failures,dart_path.distance,flat_path.distance])
	quit(0 if failures==0 else 1)
