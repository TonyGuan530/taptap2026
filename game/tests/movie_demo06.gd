extends Node2D
## demo-06 上板素材驱动：30fps 跑一局五关通关剧本——
## L1 Fire 烧栅栏 → L2 浮板登高台 → L3 浮板桥 → L4 浮板翻越高墙 → L5 双沟群岛（直跳+单板）。
## 帧序列供 ffmpeg 合成 reviews/videos/demo-06.mp4；L3 桥上定格存 reviews/shots/demo-06.png。
## 运行：godot --path game --write-movie <仓库绝对路径>/.movie06/f.png --fixed-fps 30 --quit-after 1750 res://tests/movie_demo06.tscn
## 跳跃参数（与 demo06_inkwords.gd 一致）：跳高 84.5 / 满速水平射程 156；L2 台阶每级抬升 ≤40，头部净空 ≥12px。

var game: Node2D
var f := 0
var cur_lv := -1
var lv_f := 0
var win_wait := 0
var last_x := -1.0
var shot_saved := false
var dbg: FileAccess


func _dbg() -> void:
	if dbg and cur_lv >= 1:
		dbg.store_string("f=%d lv=%d lv_f=%d state=%s px=%.0f py=%.0f floor=%s D=%s\n" % [f, cur_lv, lv_f,
			str(game.state), game.player.position.x, game.player.position.y,
			str(game.on_floor), str(game.keys.get(KEY_D, false))])
		if f % 300 == 0:
			dbg.flush()


func _ready() -> void:
	dbg = FileAccess.open("user://movie06_log.txt", FileAccess.WRITE)
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
		# 切关清键：上一关剧本残留的 D/SPACE 会让角色开门就跑（L2 曾因此跳过起跳窗）
		game.keys[KEY_D] = false
		game.keys[KEY_SPACE] = false
	lv_f += 1
	# 通关后停留 100 帧（胜利面板入镜）再进下一关；驱动绕过按钮，需手动释放面板——
	# 旧面板 visible=false 但不释放，下一关再赢会重名，find_child 只找到旧的（踩过）
	if game.state == "win":
		win_wait += 1
		if win_wait == 100 and game.level_idx < 4:
			for wp in game.get_tree().root.find_children("WinPanel", "Panel", true, false):
				wp.queue_free()
			game._load_level(game.level_idx + 1)
		return
	win_wait = 0
	_dbg()
	match cur_lv:
		0: _level1()
		1: _level2()
		2: _level3()
		3: _level4()
		4: _level5()


## L1：Fire 圆球点燃栅栏，走向 GOAL
func _level1() -> void:
	if lv_f == 30:
		game._on_shape(0)
		game._on_word(2)
		game._try_place(Vector2(485, 300))
	elif lv_f > 150:
		game.keys[KEY_D] = true


## L2：单块 Float 长板两级跳登上高台（板顶 390；地面 470→板 80 抬升，板→高台 310 亦 80；
## 跳弧逐点验算：两处起跳均在剐蹭余量内，落点 695/786 分别在板面 [635,765] 与台面 [760,1000]）
func _level2() -> void:
	if lv_f == 30:
		game._on_shape(1)
		game._on_word(1)
		game._try_place(Vector2(700, 401))
	elif lv_f > 90:
		var px: float = game.player.position.x
		var py: float = game.player.position.y
		game.keys[KEY_D] = true
		if game.on_floor:
			# 窗口按 30fps/8px每帧 步进校验过：首帧起跳的弧线在板缘/台缘均有净空
			if px > 545 and px < 558 and py > 420:          # 地面 → 浮板（顶 390，抬升 80）
				_jump()
			elif px > 680 and px < 700 and py > 330 and py < 400:   # 浮板 → 高台（顶 310，抬升 80）
				_jump()


## L3：两块 Float 长板悬空桥。玩家出生点(70)正对预置长板落点(65..215)——会被砸进地形，
## 故 lv_f==5 先把玩家挪到 x=305（三件落物间隙），板1 也右移到 420 并重算跳跃窗。
func _level3() -> void:
	if lv_f == 5:
		print("L3 TELEPORT at lv_f=", lv_f, " player=", game.player)
		game.player.position = Vector2(305, 330)
		game.player.velocity = Vector2.ZERO
	if lv_f == 30:
		game._on_shape(1)
		game._on_word(1)
		game._try_place(Vector2(420, 350))
	elif lv_f == 90:
		game._try_place(Vector2(615, 350))
	elif lv_f > 120:
		var px: float = game.player.position.x
		var py: float = game.player.position.y
		game.keys[KEY_D] = true
		# L3 桥上定格（板1 上、GOAL 前）——给 Miro 一张 v5 最新画面
		if not shot_saved and game.on_floor and px > 360 and px < 480 and py < 350:
			shot_saved = true
			var img := get_viewport().get_texture().get_image()
			var out: String = ProjectSettings.globalize_path("res://") + "../reviews/shots/demo-06.png"
			img.save_png(out)
			print("SHOT_SAVED: ", out, " lv_f=", lv_f)
		if game.on_floor:
			var want := false
			if px > 300.0 and px < 318.0 and py > 370.0:
				want = true        # 左台起跳上板1（跳点距板缘≥36px，弧线净空 4~16px）
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


## L4：一块 Float 长板（顶 390）走上墙头（顶 380，抬升 10 小跳）——与 test T8 同参数
func _level4() -> void:
	if lv_f == 30:
		game._on_shape(1)
		game._on_word(1)
		game._try_place(Vector2(420, 401))
	elif lv_f > 90:
		var px: float = game.player.position.x
		var py: float = game.player.position.y
		game.keys[KEY_D] = true
		if game.on_floor:
			var want := false
			if px > 262.0 and px < 274.0 and py > 420.0:
				want = true        # 地面 → 浮板（顶 390）
			elif px > 455.0 and px < 485.0 and py < 400.0:
				want = true        # 浮板 → 越墙（墙顶 380 低于板顶 390，抬升 10）
			if want:
				_jump()
			else:
				game.keys[KEY_SPACE] = false


## L5：单块 Float 长板跨沟2（沟1 140 直跳、沟2 200 架板）——与 test T10 同参数
func _level5() -> void:
	if lv_f == 30:
		game._on_shape(1)
		game._on_word(1)
		game._try_place(Vector2(665, 391))
	elif lv_f > 90:
		var px: float = game.player.position.x
		var py: float = game.player.position.y
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
