extends SceneTree
## L8 引球入瓮 影片驱动（内容新增片段）：Heavy 球放台缘滚落入瓮 → 踩球过沟 → GOAL。
## 运行：godot --path game --write-movie <绝对路径>/.movie06l8/f.png --fixed-fps 60 --quit-after 540 -s res://tests/movie_demo06_tree_l8.gd

var game: Node3D
var t := 0
var jump_latch := false
var won := false


func _initialize() -> void:
	_run()


func _run() -> void:
	game = load("res://demo06_3d.tscn").instantiate()
	game.level_idx = 7
	root.add_child(game)
	game.scripted = true
	for i in 60:
		await physics_frame
	game.place_blueprint(0, 0, Vector3(3.05, 1.55, 0))
	while t < 540:
		await physics_frame
		t += 1
		var p: CharacterBody3D = game.player
		var px: float = p.position.x
		var py: float = p.position.y
		var on_floor: bool = p.is_on_floor()
		if on_floor and px > 2.45 and px < 2.7 and py > 1.0 and py < 2.0:
			jump_latch = true
		if on_floor and px > 4.0 and px < 4.6 and py > 1.5 and py < 2.1:
			jump_latch = true
		game.auto_dir = Vector3(1, 0, 0)
		game.auto_jump = on_floor and jump_latch
		if not on_floor:
			jump_latch = false
		if px > 7.0 and not won:
			won = true
			print("L8MOVIE_WIN at t=", t)
	if won:
		print("L8MOVIE: PASS")
	else:
		print("L8MOVIE: FAIL")
	quit(0 if won else 1)
