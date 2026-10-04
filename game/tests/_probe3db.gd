extends SceneTree
var scene_root: Node3D
var player: CharacterBody3D
var ability: Node

func _init() -> void:
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://demo04_3d.tscn")
	scene_root = packed.instantiate()
	root.add_child(scene_root)
	await physics_frame
	await physics_frame
	player = scene_root.get_node("Player")
	ability = scene_root.get_node("AbilityState")
	# 等落地
	print("is_physics_processing=", player.is_physics_processing())
	player.set_physics_process(true)
	for i in 120:
		if player.is_on_floor():
			break
		await physics_frame
	print("settled: pos=", player.position, " on_floor=", player.is_on_floor())
	# 按 D
	var ev := InputEventKey.new()
	ev.keycode = KEY_D
	ev.physical_keycode = KEY_D
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 30:
		await physics_frame
		if i % 5 == 0:
			print("tick ", i, " pos=", player.position, " vel=", player.velocity, " keys_D=", player.keys.get(KEY_D, false))
	# SPACE 跳跃探针
	var ev3 := InputEventKey.new()
	ev3.keycode = KEY_SPACE
	ev3.physical_keycode = KEY_SPACE
	ev3.pressed = true
	Input.parse_input_event(ev3)
	for i in 40:
		await physics_frame
		if i % 5 == 0:
			print("SPACE tick ", i, " keys_sp=", player.keys.get(KEY_SPACE, false), " pos.y=", player.position.y, " vel.y=", player.velocity.y)
	var ev4 := InputEventKey.new()
	ev4.keycode = KEY_SPACE
	ev4.physical_keycode = KEY_SPACE
	ev4.pressed = false
	Input.parse_input_event(ev4)
	await physics_frame

	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_D
	ev2.physical_keycode = KEY_D
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await physics_frame
	print("final pos=", player.position)
	quit(0)
