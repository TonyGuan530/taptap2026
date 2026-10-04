extends Node3D
## demo-02 3D 上板素材驱动：L1 弹簧越墙 → L2 错位砸板 → L3 羽毛跨峡谷（与 b 套件同款解法）
## 运行：godot --path game --write-movie <绝对路径>/f.png --fixed-fps 30 res://tests/movie_demo02_3d.tscn

var game: Node3D
var phase := 0          # 0=L1 1=L2 2=L3 3=L4(羽毛路线) 4=L5(零输入)
var sub := 0            # 阶段内步骤
var hold := 0           # 过关停留帧数（30fps × 1.2s）
var released := false


func _ready() -> void:
	game = load("res://demo02_3d.tscn").instantiate()
	add_child(game)


func _physics_process(_delta: float) -> void:
	if game == null or phase >= 5:
		return
	if game.goal_reached:
		hold += 1
		if hold > 36:   # 停 1.2s 展示过关再切下一关
			hold = 0
			phase += 1
			sub = 0          # 下一关从装载步骤重新走
			game.goal_reached = false
			Input.action_release("p_fwd")   # 换关必须松净按键，否则漂移会被顶回
			Input.action_release("p_left")
			released = false
			if phase >= 5:
				get_tree().quit()
		return
	match phase:
		0: _drive_l1()
		1: _drive_l2()
		2: _drive_l3()
		3: _drive_l4()
		4: _drive_l5()


func _drive_l1() -> void:
	if sub == 0:
		game._load_level(0)
		game.switch_tag(2)
		game.yaw = -PI / 2
		Input.action_press("p_fwd")
		sub = 1
	# 按住 W 直到 goal


func _drive_l2() -> void:
	if game.ball == null:
		return
	if sub == 0:
		game._load_level(1)
		game.switch_tag(0)
		game.yaw = 0.0   # 复位朝向：L1 遗留的 -PI/2 会把 p_left 推向 -Z 后墙
		sub = 1
	elif sub == 1 and game.ball.linear_velocity.y > 9.0:
		Input.action_press("p_left")
		sub = 2
	elif sub == 2 and game.ball.position.x <= -9.4:
		Input.action_release("p_left")
		sub = 3
	elif sub == 3 and game.ball.linear_velocity.y > -2.0 and game.ball.linear_velocity.y < 2.0:
		game.switch_tag(1)   # 顶点转石头砸板
		sub = 4


func _drive_l3() -> void:
	if game.ball == null:
		return
	if sub == 0:
		game._load_level(2)
		game.switch_tag(2)
		game.ball.global_position = Vector3(-4.5, 0.6, 0)
		game.ball.linear_velocity = Vector3.ZERO
		sub = 1
	elif sub == 1 and game.ball.linear_velocity.y > 9.0:
		sub = 2
	elif sub == 2 and game.ball.linear_velocity.y > -2.0 and game.ball.linear_velocity.y < 2.0:
		game.switch_tag(0)
		game.yaw = -PI / 2
		Input.action_press("p_fwd")
		sub = 3
	elif sub == 3:
		if game.ball.position.x >= 9.5 and not released:
			released = true
			Input.action_release("p_fwd")
		if game.ball.linear_velocity.y < -1.0 and not game.flap_used:
			game.try_flap()


func _drive_l4() -> void:
	if game.ball == null:
		return
	if sub == 0:
		game._load_level(3)
		game.switch_tag(2)
		sub = 1
	elif sub == 1 and game.ball.linear_velocity.y > 9.0:
		sub = 2
	elif sub == 2 and game.ball.linear_velocity.y > -2.0 and game.ball.linear_velocity.y < 2.0:
		game.switch_tag(0)   # 顶点转羽毛
		game.yaw = -PI / 2
		Input.action_press("p_fwd")
		sub = 3
	elif sub == 3:
		if game.ball.position.x >= 8.6 and not released:
			released = true
			Input.action_release("p_fwd")   # 到台上方即松，垂直落在高台上
		if game.ball.position.y < 4.5 and game.ball.linear_velocity.y < -1.5 and not game.flap_used:
			game.try_flap()


func _drive_l5() -> void:
	if game.ball == null:
		return
	if sub == 0:
		game._load_level(4)
		game.switch_tag(2)   # 皮球零输入：踩弹簧后交给弹簧链
		sub = 1
