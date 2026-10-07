extends SceneTree
const Paper := preload("res://demo08_3d/paper_geometry.gd")
const Flight := preload("res://demo08_3d/paper_flight.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures += 1

func _initialize() -> void:
	var paper = Paper.new()
	var original_area: float = paper.material_area()
	check(paper.begin_face_fold(0,Vector3(0,0,-0.15),Vector3(0,0,0.15)),"crease can begin without snapping flat")
	check(paper.set_last_angle(PI/3),"drag sets a partial angle")
	check(not paper.is_flat(),"released 60-degree fold stays three-dimensional")
	check(absf(paper.material_area()-original_area)<0.000001,"drag preserves material area")
	var tilted := -1
	for i in paper.faces.size():
		if absf(paper.polygon_normal(paper.faces[i]).y)<0.9: tilted=i
	check(tilted>=0,"tilted panel remains selectable")
	var face: PackedVector3Array = paper.faces[tilted]
	var edge_mid_a: Vector3 = face[0].lerp(face[1],0.5)
	var edge_mid_b: Vector3 = face[2].lerp(face[3],0.5)
	check(paper.begin_face_fold(tilted,edge_mid_a,edge_mid_b),"another crease works on the tilted panel")
	check(paper.set_last_angle(-PI/4),"second crease can fold in the opposite direction")
	check(absf(paper.material_area()-original_area)<0.000001,"multiple nonplanar folds preserve material")
	check(paper.undo() and not paper.is_flat(),"undo restores the earlier standing fold")
	check(paper.set_last_angle(PI/2),"existing last crease can be dragged again")
	var vertical_surfaces := false
	for panel in paper.aerodynamic_panels():
		if absf(panel.normal.y)<0.01 and float(panel.area)>0.005: vertical_surfaces=true
	check(vertical_surfaces,"upright paper contributes aerodynamic area")
	var body = Flight.new()
	body.launch(paper,12,1)
	for frame in 120: body.step(1.0/60.0)
	check(body.position.is_finite() and body.velocity.is_finite(),"nonplanar folded paper can physically fly")
	check(paper.undo() and paper.is_flat() and paper.faces.size()==1,"full undo returns one uncut sheet")
	var probe = Paper.new()
	probe.begin_face_fold(0,Vector3(0,0,-0.15),Vector3(0,0,0.15))
	var previous_bank := 0.0
	var max_bank_step := 0.0
	for degrees in range(40,66):
		probe.set_last_angle(deg_to_rad(degrees))
		var launch_probe = Flight.new()
		launch_probe.launch(probe,0,1)
		var bank: float = atan2(launch_probe.orientation.x.y,launch_probe.orientation.x.x)
		if degrees>40: max_bank_step=maxf(max_bank_step,absf(rad_to_deg(bank-previous_bank)))
		previous_bank=bank
	check(max_bank_step<5.0,"small fold-angle changes cannot suddenly bank launch across sampling axes or fin threshold")
	print("DRAG_FOLD_RESULT failures=%d" % failures)
	quit(0 if failures==0 else 1)
