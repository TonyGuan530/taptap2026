extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", message)

func ladder(height := 250.0, skew := 0.0) -> Array:
	return [PackedVector2Array([Vector2(80,290),Vector2(80+skew,290-height)]),PackedVector2Array([Vector2(145,290),Vector2(145+skew,290-height)]),PackedVector2Array([Vector2(80+skew*0.3,290-height*0.3),Vector2(145+skew*0.3,290-height*0.3)]),PackedVector2Array([Vector2(80+skew*0.7,290-height*0.7),Vector2(145+skew*0.7,290-height*0.7)])]

func _run() -> void:
	check(ResourceLoader.exists("res://v10/sketch_rules.gd"),"V10 pure geometry module exists")
	if failures:
		print("INK_V10_GEOMETRY_CHECKS=%d FAILURES=%d" % [checks,failures]); quit(1); return
	var rules = load("res://v10/sketch_rules.gd")
	check(rules != null and rules.can_instantiate(),"geometry script parses")
	if failures: quit(1); return
	var long: Dictionary = rules.analyze(ladder(),"ladder")
	check(long.ok,"two actual rails joined by two rungs are climbable")
	check(is_equal_approx(long.length,3.5) and is_equal_approx(long.width,0.91),"pixels map to real dimensions without normalizing length")
	check(long.segments.size() == 4,"pen-up produces four real segments and no connectors")
	var short: Dictionary = rules.analyze(ladder(90),"ladder")
	check(short.ok and short.length < long.length and short.cost < long.cost,"short ladder keeps shorter length and lower ink use")
	check(rules.analyze(ladder(60),"ladder").ok,"short ladder can have rungs wider than its rail height")
	var elastic: Dictionary = rules.analyze(ladder(),"ladder","Elastic")
	check(elastic.ok and is_equal_approx(elastic.length,long.length*1.4),"Elastic scales actual geometry by exactly 1.4")
	check(is_equal_approx(elastic.segments[0][0].distance_to(elastic.segments[0][1]),long.segments[0][0].distance_to(long.segments[0][1])*1.4),"Elastic scales actual retained segments")
	check(rules.analyze(ladder(250,32),"ladder").ok,"skewed connected ladder preserves nonstandard drawing")
	var unequal := ladder()
	unequal[1] = PackedVector2Array([Vector2(145,290),Vector2(145,120)])
	check(is_equal_approx(rules.analyze(unequal,"ladder").length,2.38),"unequal rails limit climbing height to their actual shared extent")
	var broken := ladder()
	broken[2] = PackedVector2Array([Vector2(98,215),Vector2(128,215)])
	broken[3] = PackedVector2Array([Vector2(98,115),Vector2(128,115)])
	check(not rules.analyze(broken,"ladder").ok,"rungs that do not reach either rail are rejected")
	check(not rules.analyze([ladder()[0],ladder()[1]],"ladder").ok,"unconnected rails cannot become a ladder")
	var board := [PackedVector2Array([Vector2(30,50),Vector2(290,50),Vector2(280,130),Vector2(30,130),Vector2(30,50)])]
	var surface: Dictionary = rules.analyze(board,"board")
	check(surface.ok and surface.polygon.size() == 4,"closed hand-drawn board creates its real polygon")
	check(surface.length > 3.5 and surface.width > 1.0,"long board has real bridge/ramp dimensions")
	var decorated := board.duplicate(true)
	decorated.append(PackedVector2Array([Vector2(360,90),Vector2(490,90)]))
	var decorated_surface: Dictionary = rules.analyze(decorated,"board")
	check(decorated_surface.ok and is_equal_approx(decorated_surface.length,surface.length),"open decorative stroke cannot extend the walkable polygon dimensions")
	check(decorated_surface.segments.size() == 5,"decorated board retains extra original ink without a false connector")
	check(not rules.analyze([PackedVector2Array([Vector2(30,30),Vector2(290,130),Vector2(30,130),Vector2(290,30),Vector2(30,30)])],"board").ok,"self-intersecting board gives a correctable failure")
	check(not rules.analyze([PackedVector2Array([Vector2(30,30),Vector2(290,30),Vector2(290,130)])],"board").ok,"open board cannot receive a filled collision")
	check(not rules.analyze(ladder(),"ladder","Sharp").ok,"black geometry accepts one supported property only")
	var many: Array = []
	for i in 25: many.append(ladder()[0])
	check(not rules.analyze(many,"ladder").ok,"25th stroke is rejected rather than silently changing artwork")
	var huge := PackedVector2Array()
	for i in 257: huge.append(Vector2(i,20))
	check(not rules.analyze([huge],"board").ok,"257th point is rejected by pure analysis")
	check(not rules.analyze([PackedVector2Array([Vector2(NAN,0),Vector2(1,2)])],"ladder").ok,"nonfinite input cannot generate physics geometry")
	print("INK_V10_GEOMETRY_CHECKS=%d FAILURES=%d" % [checks,failures]); quit(1 if failures else 0)
