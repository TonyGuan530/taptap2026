extends Node2D
## demo-05 HD-2D v2 上板素材驱动：三设施建造/幽灵/需求/昼夜/入睡（Movie Maker 离线渲染）
## 运行：godot --path game --write-movie <out.avi> --fixed-fps 30 res://tests/movie_demo05_hd2d.tscn
## 注：Movie 模式用 parse_input_event 发键（直写 Input.action 不稳定，v9 实录验证）。

var game: Node3D
var f := 0
var release_queue: Array = []   # [frame, keycode]

func _ready() -> void:
	game = load("res://demo05_hd2d/demo05_hd2d.tscn").instantiate()
	add_child(game)

func _key(code: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code as Key
	ev.pressed = down
	Input.parse_input_event(ev)

func _tap(code: int) -> void:
	_key(code, true)
	release_queue.append([f + 2, code])

func _physics_process(_delta: float) -> void:
	if game == null:
		return
	f += 1
	for i in range(release_queue.size() - 1, -1, -1):
		if f >= release_queue[i][0]:
			_key(release_queue[i][1], false)
			release_queue.remove_at(i)
	match f:
		60:
			game.inventory.wood = 4
			_key(KEY_D, true)              # 向右走
		150:
			_key(KEY_D, false)
		170:
			_tap(KEY_B)                    # 进建造（幽灵出现）
		200:
			_tap(KEY_E)                    # 放下储备堆
		210:
			game.inventory.wood = 3
			_key(KEY_S, true)              # 向下走
		270:
			_key(KEY_S, false)
		285:
			_tap(KEY_B)
		305:
			_tap(KEY_2)                    # 选集水器
		325:
			_tap(KEY_E)
		335:
			game.inventory.wood = 6
			_key(KEY_A, true)              # 向左走
		395:
			_key(KEY_A, false)
		405:
			_tap(KEY_B)
		425:
			_tap(KEY_3)                    # 选枝叶窝
		445:
			_tap(KEY_E)
		460:
			_tap(KEY_B)                    # 再返建造：拍幽灵
		510:
			_tap(KEY_ESCAPE)               # Esc 取消
		520:
			game.day_time = game.DAY_LEN + 2.0   # 入夜（灰界尚在远处）
			game.thirst = 15.0
			game.hunger = 20.0
			game.hp = 60.0
		530:
			game.dino.position = Vector3(13, 0.1, -1)   # 停在东坡侧，等灰潮压境
		560:
			game.day_time = game.DAY_LEN + game.NIGHT_LEN * 0.45   # 灰潮推进至西界≈8，覆盖恐龙
		640:
			game.dino.position = Vector3(0, 0.1, 4)     # 撤到西半场
			game.day_time = game.DAY_LEN + game.NIGHT_LEN - 1.2   # 黎明将至，灰潮退去
		780:
			get_tree().quit()
