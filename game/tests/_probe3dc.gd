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
	# 与测量完全一致的序列
	player.position = Vector3(5.0, 1.3, 0)
	player.velocity = Vector3.ZERO
	for i in 120:
		if player.is_on_floor():
			break
		await physics_frame
	print("settled: pos=", player.position, " on_floor=", player.is_on_floor())
	player.keys[KEY_SPACE] = true
	for i in 60:
		await physics_frame
		if i % 10 == 0:
			print("t", i, " pos=", player.position, " vel=", player.velocity, " keys_sp=", player.keys.get(KEY_SPACE, false), " on_floor=", player.is_on_floor(), " jumps=", player.jumps_used)
	player.keys[KEY_SPACE] = false
	await physics_frame
	print("final pos=", player.position)
	quit(0)
