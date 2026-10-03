extends Node2D
## demo-06 上板素材驱动：30fps 跑一局三关通关剧本——
## L1 Fire 圆球烧栅栏 → L2 三块 Float 长板阶梯登高台 → L3 两块 Float 长板桥跨断层。
## 帧序列供 ffmpeg 合成 reviews/videos/demo-06.mp4；L3 桥上定格存 reviews/shots/demo-06.png。
## 运行：godot --path game --write-movie <仓库绝对路径>/.movie06/f.png --fixed-fps 30 --quit-after 1050 res://tests/movie_demo06.tscn
## 跳跃参数（与 demo06_inkwords.gd 一致）：跳高 84.5 / 满速水平射程 156；L2 台阶每级抬升 ≤40，头部净空 ≥12px。

var game: Node2D
var f := 0
var cur_lv := -1
var lv_f := 0
var win_wait := 0
var last_x := -1.0
var shot_saved := false


func _ready() -> void:
	var ps: PackedScene = load("res://demo06_inkwords.tscn")
	game = ps.instantiate()
	add_child(game)


func _jump() -> void:
	game.keys[KEY_SPACE] = true


func _process(_delta: float) -> void:
	if game == null:
		return
	f += 1
	if game.level_idx != cur_lv:
		cur_lv = game.level_idx
		lv_f = 0
		last_x = -1.0
	lv_f += 1
	# 通关后停留 100 帧（胜利面板入镜）再进下一关
	if game.state == "win":
		win_wait += 1
		if win_wait == 100 and game.level_idx < 2:
			game._load_level(game.level_idx + 1)
		return
	win_wait = 0
	match cur_lv:
		0: _level1()
		1: _level2()
		2: _level3()


## L1：Fire 圆球点燃栅栏，走向 GOAL
func _level1() -> void:
	if lv_f == 30:
		game._on_shape(0)
		game._on_word(2)
		game._try_place(Vector2(485, 300))
	elif lv_f > 150:
		game.keys[KEY_D] = true


## L2：三块 Float 长板阶梯（顶面 425/385/340）登上高台（顶 310）
func _level2() -> void:
	if lv_f == 30:
		game._on_shape(1)
		game._on_word(1)
		game._try_place(Vector2(520, 436))
	elif lv_f == 90:
		game._try_place(Vector2(610, 396))
	elif lv_f == 150:
		game._try_place(Vector2(700, 351))
	elif lv_f > 180:
		var px: float = game.player.position.x
		var py: float = game.player.position.y
		game.keys[KEY_D] = true
		if game.on_floor:
			if px > 460 and py > 420:        # 地面 → 板1（顶 425）
				_jump()
			elif px > 555 and py > 375 and py < 420:   # 板1 → 板2（顶 385）
				_jump()
			elif px > 645 and py > 330 and py < 375:   # 板2 → 板3（顶 340）
				_jump()
			elif px > 730 and py < 330:                # 板3 → 高台（顶 310）
				_jump()


## L3：两块 Float 长板悬空桥（与 test_demo06_l3 T5 同参数，已实证可通关）
func _level3() -> void:
	if lv_f == 30:
		game._on_shape(1)
		game._on_word(1)
		game._try_place(Vector2(400, 350))
	elif lv_f == 90:
		game._try_place(Vector2(615, 350))
	elif lv_f > 120:
		var px: float = game.player.position.x
		var py: float = game.player.position.y
		game.keys[KEY_D] = true
		# L3 桥上定格（板2 上、GOAL 前）——给 Miro 一张 v5 最新画面
		if not shot_saved and game.on_floor and px > 430 and px < 570 and py < 350:
			shot_saved = true
			var img := get_viewport().get_texture().get_image()
			var out: String = ProjectSettings.globalize_path("res://") + "../reviews/shots/demo-06.png"
			img.save_png(out)
			print("SHOT_SAVED: ", out, " lv_f=", lv_f)
		if game.on_floor:
			var want := false
			if px > 285.0 and px < 320.0 and py > 370.0:
				want = true        # 左台缘起跳上板1
			elif px > 408.0 and px < 460.0 and py < 350.0:
				want = true        # 板1 起跳上板2
			elif px > 625.0 and px < 665.0 and py < 350.0:
				want = true        # 板2 起跳上右台/GOAL
			elif absf(px - last_x) < 2.0:
				want = true        # 被预置方块挡住 → 跳越（统一物理，不判解法）
			if want:
				_jump()
			else:
				game.keys[KEY_SPACE] = false
	last_x = game.player.position.x if game.player != null else -1.0
