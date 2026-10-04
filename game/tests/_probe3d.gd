extends SceneTree
## 输入探针（用完即删）
var scene_root: Node
var player: CharacterBody3D

func _init() -> void:
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://demo04_3d.tscn")
	scene_root = packed.instantiate()
	root.add_child(scene_root)
	await physics_frame
	await physics_frame
	player = scene_root.get_node("Player")
	print("player script=", player.get_script() != null, " in_tree=", player.is_inside_tree())
	var ev := InputEventKey.new()
	ev.keycode = KEY_D
	ev.physical_keycode = KEY_D
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	await physics_frame
	await physics_frame
	print("keys after D down: ", player.keys)
	print("is_key_pressed(D)=", Input.is_key_pressed(KEY_D))
	print("px=", player.position.x, " (应>1 若移动)")
	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_D
	ev2.physical_keycode = KEY_D
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await physics_frame
	print("keys after release: ", player.keys)
	quit(0)
