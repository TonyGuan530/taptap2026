extends SceneTree
## L1 栅栏与沟 影片驱动（阶段 B 首发片段）：Fire 球燃毁木栅栏 → 直行 GOAL。
## 运行：godot --path game --write-movie <绝对路径>/.movie06l1/f.png --fixed-fps 60 --quit-after 540 -s res://tests/movie_demo06_tree_l1.gd

var game: Node3D
var t := 0
var jump_latch := false
var won := false
var won_at := -1


func _initialize() -> void:
	_run()


func _run() -> void:
	game = load("res://demo06_3d.tscn").instantiate()
	game.level_idx = 0
	root.add_child(game)
	game.scripted = true
	for i in 60:
		await physics_frame
	game.place_blueprint(0, 2, Vector3(4.05, 1.5, 0))  # ball+fire
	while t < 540:
		await physics_frame
		t += 1
		var p: CharacterBody3D = game.player
		var px: float = p.position.x
		var py: float = p.position.y
		var on_floor: bool = p.is_on_floor()
		var burned: bool = not is_instance_valid(game.props_root.get_node_or_null("Fence"))
		if burned and on_floor and px > 4.0 and px < 4.8 and py < 2.0:
			jump_latch = true
		game.auto_dir = Vector3(1, 0, 0)
		game.auto_jump = on_floor and jump_latch
		if not on_floor:
			jump_latch = false
		if px > 6.4 and not won:
			won = true
			won_at = t
			print("L1MOVIE_WIN at t=", t)
	if won:
		print("L1MOVIE: PASS (win_at=", won_at, ")")
	else:
		print("L1MOVIE: FAIL")
	quit(0 if won else 1)
