extends SceneTree
## 六关全通关影片驱动（SceneTree 逐 tick 版）——与 test_demo06_l3.gd 完全同构（await physics_frame），
## 消除 Node2D._physics_process 驱动的评估时机差异；配合 --write-movie --fixed-fps 60 离线渲染。
## 运行：godot --path game --write-movie <绝对路径>/.movie06/f.png --fixed-fps 60 --quit-after 3000 -s res://tests/movie_demo06_tree.gd

var game: Node2D
var cur_lv := -1
var lv_f := 0
var win_wait := 0
var shot_saved := false
var lx := -1.0


func _initialize() -> void:
	_run()


func _run() -> void:
	game = load("res://demo06_inkwords.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 70000:
		await physics_frame
		if game.level_idx != cur_lv:
			cur_lv = game.level_idx
			lv_f = 0
			game.keys[KEY_D] = false
			game.keys[KEY_SPACE] = false
		lv_f += 1
		if game.state == "win":
			win_wait += 1
			if win_wait == 100 and game.level_idx < 5:
				for wp in get_root().find_children("WinPanel", "Panel", true, false):
					wp.queue_free()
				game._load_level(game.level_idx + 1)
			continue
		win_wait = 0
		_drive()
		lx = px_of()
	_l6_cleanup()


func _l6_cleanup() -> void:
	print("MOVIE_TREE_DONE shot=", shot_saved)


func px_of() -> float:
	return game.player.position.x


func _jump() -> void:
	game.keys[KEY_SPACE] = true


func _drive() -> void:
	var px: float = game.player.position.x
	var py: float = game.player.position.y
	match cur_lv:
		0: _level1(px, py)
		1: _level2(px, py)
		2: _level3(px, py)
		3: _level4(px, py)
		4: _level5(px, py)
		5: _level6(px, py)


func _level1(px: float, py: float) -> void:
	if lv_f == 30:
		game._on_shape(0)
		game._on_word(2)
		game._try_place(Vector2(485, 300))
	elif lv_f > 150:
		game.keys[KEY_D] = true


func _level2(px: float, py: float) -> void:
	if lv_f == 30:
		game._on_shape(1)
		game._on_word(1)
		game._try_place(Vector2(700, 401))
	elif lv_f > 90:
		game.keys[KEY_D] = true
		if game.on_floor:
			var want := false
			if px > 545 and px < 558 and py > 420:
				want = true        # 地面 → 浮板（顶 390）
			elif px > 680 and px < 700 and py > 330 and py < 400:
				want = true        # 浮板 → 高台（顶 310）
			if want:
				_jump()
			else:
				game.keys[KEY_SPACE] = false


func _level3(px: float, py: float) -> void:
	if lv_f == 5:
		game.player.position = Vector2(305, 330)
		game.player.velocity = Vector2.ZERO
	if lv_f == 30:
		game._on_shape(1)
		game._on_word(1)
		game._try_place(Vector2(420, 350))
	elif lv_f == 90:
		game._try_place(Vector2(615, 350))
	elif lv_f > 120:
		game.keys[KEY_D] = true
		if not shot_saved and game.on_floor and px > 360 and px < 480 and py < 350:
			shot_saved = true
			var img: Image = root.get_texture().get_image()
			var out: String = ProjectSettings.globalize_path("res://") + "../reviews/shots/demo-06.png"
			img.save_png(out)
		if game.on_floor:
			var want := false
			if px > 262.0 and px < 274.0 and py > 420.0:
				want = true        # 左岛缘直跳沟1
			elif px > 408.0 and px < 460.0 and py < 350.0:
				want = true        # 板1 → 板2
			elif px > 625.0 and px < 665.0 and py < 350.0:
				want = true        # 板2 → 右台/GOAL
			elif absf(px - lx) < 2.0:
				want = true        # 被预置方块挡住 → 跳越
			if want:
				_jump()
			else:
				game.keys[KEY_SPACE] = false


func _level4(px: float, py: float) -> void:
	if lv_f == 30:
		game._on_shape(1)
		game._on_word(1)
		game._try_place(Vector2(420, 401))
	elif lv_f > 90:
		game.keys[KEY_D] = true
		if game.on_floor:
			var want := false
			if px > 262.0 and px < 274.0 and py > 420.0:
				want = true        # 地面 → 浮板（顶 390）
			elif px > 455.0 and px < 485.0 and py < 400.0:
				want = true        # 浮板 → 越墙（顶 380）
			if want:
				_jump()
			else:
				game.keys[KEY_SPACE] = false


func _level5(px: float, py: float) -> void:
	if lv_f == 30:
		game._on_shape(1)
		game._on_word(1)
		game._try_place(Vector2(665, 391))
	elif lv_f > 90:
		game.keys[KEY_D] = true
		if game.on_floor:
			var want := false
			if px > 270.0 and px < 280.0 and py > 370.0:
				want = true        # 左岛缘直跳沟1（落中岛）
			elif px > 548.0 and px < 560.0 and py > 370.0:
				want = true        # 中岛缘起跳上板（顶 380）
			if want:
				_jump()
			else:
				game.keys[KEY_SPACE] = false


func _level6(px: float, py: float) -> void:
	if lv_f == 30:
		game._on_shape(1)
		game._on_word(1)
		game._try_place(Vector2(220, 401))
	elif lv_f == 90:
		game._try_place(Vector2(535, 346))
	elif lv_f > 120:
		game.keys[KEY_D] = true
		if game.on_floor:
			var want := false
			if px > 56.0 and px < 72.0 and py > 420.0:
				want = true        # 地面 → P1（顶 390）
			elif px > 240.0 and px < 275.0 and py > 350.0 and py < 400.0:
				want = true        # P1 → 塔1（顶 330）
			elif px > 500.0 and px < 530.0 and py > 310.0 and py < 345.0:
				want = true        # P2 → 塔2（顶 285）
			if want:
				_jump()
			else:
				game.keys[KEY_SPACE] = false
