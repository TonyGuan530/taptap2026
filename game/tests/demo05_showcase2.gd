extends SceneTree
## demo-05 v2 实时生存演示（视频新鲜度指令）
## 步骤调度使用【游戏内时钟】（day_time + 天数×90），免疫 Movie Maker 渲染漂移
## 挂钟仅作 failsafe（150s）
var scene: Control
var si := 0
var walk_target := Vector2.ZERO

var steps := [
	{gt = 2.0, kind = "goto", pos = Vector2(220, 160)},
	{gt = 3.5, kind = "act_berry"},
	{gt = 5.5, kind = "act_berry"},
	{gt = 7.5, kind = "act_berry"},
	{gt = 9.5, kind = "goto", pos = Vector2(450, 410)},
	{gt = 11.0, kind = "act_pond"},
	{gt = 13.0, kind = "act_pond"},
	{gt = 15.0, kind = "goto", pos = Vector2(710, 270)},
	{gt = 16.5, kind = "act_tree"},
	{gt = 18.5, kind = "act_tree"},
	{gt = 20.5, kind = "act_tree"},
	{gt = 22.5, kind = "goto", pos = Vector2(790, 390)},
	{gt = 24.5, kind = "act_tree"},
	{gt = 26.5, kind = "act_tree"},
	{gt = 28.5, kind = "act_tree"},
	{gt = 30.0, kind = "goto", pos = Vector2(330, 240)},
	{gt = 32.0, kind = "build"},
	{gt = 36.0, kind = "goto", pos = Vector2(380, 260)},
	{gt = 91.5, kind = "quit"},
]

func _init() -> void:
	_run()

func _game_time() -> float:
	return scene.day_time + (scene.day_num - 1) * 90.0

func _idx(id: String) -> int:
	for i in scene.TILES.size():
		if scene.TILES[i].id == id:
			return i
	return 0

func _try_interact(kind: String) -> bool:
	scene._update_interact()
	var k: String = scene.interact_target.get("kind", "")
	if k == kind:
		scene._do_interact()
		return true
	return false

func _tick(delta: float) -> void:
	if si >= steps.size():
		return
	var s: Dictionary = steps[si]
	var gt: float = _game_time()
	if gt < s.gt:
		return
	if s.kind == "goto":
		walk_target = s.pos
		var to: Vector2 = walk_target - scene.player_pos
		if to.length() > 6.0:
			scene.player_pos += to.normalized() * 230.0 * delta
			scene.player_moving = true
		else:
			si += 1
	elif s.kind == "quit":
		quit()
		si += 1
	else:
		var ok := false
		match s.kind:
			"act_berry":
				ok = _try_interact("berry")
			"act_pond":
				ok = _try_interact("pond")
			"act_tree":
				ok = _try_interact("tree")
			"build":
				if scene.branches >= 5 and scene.player_pos.distance_to(scene.campfire_pos) < 90.0 and not scene.campfire_built:
					scene._do_interact()
				ok = scene.campfire_built
		if ok:
			si += 1

func _run() -> void:
	await process_frame
	scene = load("res://demo05_volcano.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var wall0 := Time.get_ticks_msec()
	while true:
		await physics_frame
		var now := Time.get_ticks_msec()
		var delta: float = (now - wall0) / 1000.0
		_tick(delta)
		if scene.phase == "dead" or delta > 150.0:
			break
	quit()
