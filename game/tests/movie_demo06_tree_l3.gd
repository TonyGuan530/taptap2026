extends SceneTree
## L3 灰模验证房 影片驱动（阶段 A 场景应用验收）：蓝图架 Float 板跨沟 → 两段跳跃到 GOAL。
## 运行：godot --path game --write-movie <绝对路径>/.movie06l3/f.png --fixed-fps 60 --quit-after 2400 -s res://tests/movie_demo06_tree_l3.gd
## 尺度：左台顶 y1.2（x[-1.5,2.9]）/ 沟宽 2.7m / 板中心 (4.2,1.46)（x[3.55,4.85] 顶 1.57）/
## 右台顶 y1.2（x[5.6,9.6]）/ GOAL x8.2。
## v2 修复：站在板上玩家中心 y≈2.07——旧驱动 py>2.0 误判空中（不加速）且第二跳窗 py<1.9 永不触发。
## 空中判定改用 is_on_floor；跳窗按 py 区间分台（台面 1.7 / 板面 2.07）。
## 跳跃预算：速2.4 跳5.2 重力16 → 平跳距离 ≈1.56m；左缘 2.9→板、板缘 4.85→右台 5.6 均可达。

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
	# 解法 A（指南 §9）：Float 长板跨沟（一次性放置 40 墨）
	game.place_blueprint(1, 1, Vector3(4.2, 1.46, 0))
	# 行进：按住 D（先注入按下事件）
	var ev := InputEventKey.new()
	ev.keycode = KEY_D
	ev.pressed = true
	Input.parse_input_event(ev)
	while t < 2400:
		await physics_frame
		t += 1
		var p: CharacterBody3D = game.player
		var px: float = p.position.x
		var py: float = p.position.y
		var on_floor: bool = p.is_on_floor()
		# 锁存式跳跃：窗内保持按下直到离地（对 tick 对齐不敏感）
		# 窗1 左台（中心 y≈1.7）：x 2.3~2.75；窗2 板上（中心 y≈2.07）：x 4.3~4.9
		if on_floor and px > 2.3 and px < 2.75 and py > 1.0 and py < 2.0:
			jump_latch = true
		if on_floor and px > 4.3 and px < 4.9 and py > 1.8 and py < 2.4:
			jump_latch = true
		# 行进方向恒定（模拟按住 D 不放——真实玩家空中保持输入，跳跃才有水平抛物线）
		game.auto_dir = Vector3(1, 0, 0)
		game.auto_jump = on_floor and jump_latch
		if not on_floor:
			jump_latch = false
		if px > 7.0 and not won:
			won = true
			won_at = t
			print("WALKTHROUGH_WIN at t=", t, " px=", px)
	if won:
		print("WALKTHROUGH: PASS (win_at=", won_at, ")")
	else:
		print("WALKTHROUGH: FAIL (no goal) px=", game.player.position.x, " py=", game.player.position.y)
	quit(0 if won else 1)
