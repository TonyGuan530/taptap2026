extends SceneTree
const Core := preload("res://demo08_3d/flight_core.gd")
const Paper := preload("res://demo08_3d/paper_geometry.gd")
const Flight := preload("res://demo08_3d/paper_flight.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures += 1

func fly(core, angle: float, power: float) -> void:
	var paper = Paper.new()
	paper.reset(float(core.LEVELS[core.level_idx].ratio))
	for fold in paper.dart_recipe(): paper.fold(fold.a,fold.b,float(fold.angle))
	core.finish_folds()
	core.do_throw(angle,power)
	core.physical_flight = Flight.new()
	core.physical_flight.launch(paper,angle,power)
	for frame in 900:
		core.step(1.0/60.0)
		if core.state == "settle": break

func _initialize() -> void:
	var core = Core.new()
	check(core.LEVELS.size()==5,"exactly five numbered challenges")
	core.start_level(0)
	for i in 5:
		check(core.level_idx==i and core.state=="fold","progression reaches level %d" % (i+1))
		fly(core,12,1)
		print("COURSE level=%d passed=%s distance=%.2fm target=%.1fm time=%.2fs lateral=%.2fm" % [i+1,core.last_pass,core.flight_distance,core.LEVELS[i].target_m,core.flight_time,core.lateral/60.0])
		check(core.last_pass,"physical route clears level %d" % (i+1))
		var go: String = core.settle_continue()
		check(go==("final" if i==4 else "fold"),"continue follows five-level course")
	check(core.state=="final","level five leads to completion screen")
	core.start_level(1)
	fly(core,40,1)
	check(not core.last_pass,"high angle fails demanding distance instead of auto-pass")
	check(core.settle_continue()=="retry" and core.level_idx==1,"failure retries the same level")
	core.start_level(0)
	fly(core,12,0.2)
	check(not core.last_pass,"weak throw cannot automatically pass")
	print("COURSE_RESULT failures=%d" % failures)
	quit(0 if failures==0 else 1)
