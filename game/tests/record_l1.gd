extends SceneTree
## DEMO4 3D 阶段 A 录制驱动：真实输入事件（parse_input_event）走完 L1 全流程。
## 运行：godot --path game --write-movie <帧目录>/f.png --fixed-fps 60 res://tests/record_l1.tscn
## 产出：真实 WASD/Space/E 输入驱动的 L1 通关录像帧（Movie Maker 离线渲染）。

var scene_root: Node3D
var player: CharacterBody3D
var ability: Node
var phase := "start"          # start → fuse_highjump → jump_wall → cross_gap1 → dark_fuse_glow → cross_dark → goal
var ticks := 0

func _init() -> void:
	_run()

func _key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)

func _run() -> void:
	var packed: PackedScene = load("res://demo04_3d.tscn")
	scene_root = packed.instantiate()
	root.add_child(scene_root)
	await physics_frame
	await physics_frame
	player = scene_root.get_node("Player")
	ability = scene_root.get_node("AbilityState")
	# 真实输入：W 前进（按住）
	_key(KEY_W, true)
	var fuse_tap := 0
	var jump_tap := 0
	while ticks < 5400:   # 90 秒 game time @60fps
		await physics_frame
		ticks += 1
		# 真实输入：W 保持；跳跃 = Space 点按（on_floor 周期）；融合 = E 点按（近距周期）
		if player.is_on_floor():
			jump_tap += 1
			if jump_tap % 45 == 0:
				_key(KEY_SPACE, true)
			elif jump_tap % 45 == 3:
				_key(KEY_SPACE, false)
		if player.position.distance_to(Vector3(6.2, 0.9, 0)) < 1.4 and not ability.has_dna("highjump"):
			fuse_tap += 1
			if fuse_tap % 20 == 0:
				_key(KEY_E, true)
			elif fuse_tap % 20 == 3:
				_key(KEY_E, false)
		if player.position.distance_to(Vector3(15.0, 0.9, 0)) < 1.4 and not ability.has_dna("double"):
			fuse_tap += 1
			if fuse_tap % 20 == 0:
				_key(KEY_E, true)
			elif fuse_tap % 20 == 3:
				_key(KEY_E, false)
		if player.position.distance_to(Vector3(23.8, 0.9, 0)) < 1.4 and not ability.has_dna("glow"):
			fuse_tap += 1
			if fuse_tap % 20 == 0:
				_key(KEY_E, true)
			elif fuse_tap % 20 == 3:
				_key(KEY_E, false)
		if scene_root.won:
			_key(KEY_W, false)
			print("L1 COMPLETE at tick ", ticks, " — 真实输入全流程通关")
			break
	print("recording driver end: won=", scene_root.won)
	quit(0)
