extends SceneTree
## L6 登天梯 影片驱动（阶段 B 第 2 批片段）：双 Float 板链式攀登 → GOAL。
## 运行：godot --path game --write-movie <绝对路径>/.movie06l6/f.png --fixed-fps 60 --quit-after 540 -s res://tests/movie_demo06_tree_l6.gd

var game: Node3D
var t := 0
var jump_latch := false
var won := false


func _initialize() -> void:
	_run()


func _run() -> void:
	game = load("res://demo06_3d.tscn").instantiate()
	game.level_idx = 5
	root.add_child(game)
	game.scripted = true
	for i in 60:
		await physics_frame
	game.place_blueprint(1, 1, Vector3(3.4, 1.89, 0))
	game.place_blueprint(1, 1, Vector3(7.65, 2.85, 0))
	while t < 540:
		await physics_frame
		t += 1
		var p: CharacterBody3D = game.player
		var px: float = p.position.x
		var py: float = p.position.y
		var on_floor: bool = p.is_on_floor()
		if on_floor and px > 1.75 and px < 2.2 and py > 1.0 and py < 2.0:
			jump_latch = true
		if on_floor and px > 3.85 and px < 4.03 and py > 2.3 and py < 2.7:
			jump_latch = true
		if on_floor and px > 6.3 and px < 6.85 and py > 2.8 and py < 3.3:
			jump_latch = true
		if on_floor and px > 7.8 and px < 8.25 and py > 3.15 and py < 3.55:
			jump_latch = true
		game.auto_dir = Vector3(1, 0, 0)
		game.auto_jump = on_floor and jump_latch
		if not on_floor:
			jump_latch = false
		if px > 8.9 and not won:
			won = true
			print("L6MOVIE_WIN at t=", t)
	if won:
		print("L6MOVIE: PASS")
	else:
		print("L6MOVIE: FAIL")
	quit(0 if won else 1)
