extends SceneTree
## L3 主 Gate 影片驱动（重标定版）：双 Float 板桥（80 墨）三段跳跃跨 4.8m 断层 → GOAL。
## 运行：godot --path game --write-movie <绝对路径>/.movie06l3/f.png --fixed-fps 60 --quit-after 540 -s res://tests/movie_demo06_tree_l3.gd

var game: Node3D
var t := 0
var jump_latch := false
var won := false
var won_at := -1


func _initialize() -> void:
	_run()


func _run() -> void:
	game = load("res://demo06_3d.tscn").instantiate()
	root.add_child(game)
	game.scripted = true
	for i in 60:
		await physics_frame
	game.place_blueprint(1, 1, Vector3(3.95, 1.46, 0))
	game.place_blueprint(1, 1, Vector3(6.55, 1.46, 0))
	var ev := InputEventKey.new()
	ev.keycode = KEY_D
	ev.pressed = true
	Input.parse_input_event(ev)
	while t < 540:
		await physics_frame
		t += 1
		var p: CharacterBody3D = game.player
		var px: float = p.position.x
		var py: float = p.position.y
		var on_floor: bool = p.is_on_floor()
		if on_floor and px > 2.3 and px < 2.75 and py > 1.0 and py < 2.0:
			jump_latch = true
		if on_floor and px > 4.35 and px < 4.6 and py > 1.8 and py < 2.4:
			jump_latch = true
		if on_floor and px > 6.5 and px < 7.15 and py > 1.8 and py < 2.4:
			jump_latch = true
		game.auto_dir = Vector3(1, 0, 0)
		game.auto_jump = on_floor and jump_latch
		if not on_floor:
			jump_latch = false
		if px > 9.4 and not won:
			won = true
			won_at = t
			print("L3MOVIE_WIN at t=", t)
	if won:
		print("L3MOVIE: PASS (win_at=", won_at, ")")
	else:
		print("L3MOVIE: FAIL")
	quit(0 if won else 1)
