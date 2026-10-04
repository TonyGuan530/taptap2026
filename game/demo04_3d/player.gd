extends CharacterBody3D
## 第三人称玩家控制器——保留 2D DNA 语义：
## 跳跃边沿触发；每次滞空至多 max_jumps 跳；长按不吞二段跳；
## 无荧光暗区水平速度×0.45；重力恒定。
## 输入：事件驱动 keys 字典（headless -s 下 parse_input_event 可靠分发，沿用 2D 验证模式）。

const GRAVITY := 15.0

var ability_state: Node
var in_dark_zone: bool = false
var input_enabled: bool = true

var keys := {}                # keycode -> pressed
var jump_held := false
var jumps_used := 0

signal fused
signal jump_performed(jump_type: String)   # "first" / "double"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode:
		keys[event.keycode] = event.pressed

func _physics_process(delta: float) -> void:
	if ability_state == null:
		return
	var on_floor := is_on_floor()
	if on_floor and velocity.y <= 0.0:
		jumps_used = 0  # 落地重置（对齐 2D：每次滞空独立计数；跳帧 vy 已正、不受影响）
	var jump_down: bool = input_enabled and keys.get(KEY_SPACE, false)
	var jump_pressed := jump_down and not jump_held
	jump_held = jump_down

	var input_vec := Vector2.ZERO
	if input_enabled:
		if keys.get(KEY_W, false) or keys.get(KEY_UP, false):
			input_vec.y -= 1.0
		if keys.get(KEY_S, false) or keys.get(KEY_DOWN, false):
			input_vec.y += 1.0
		if keys.get(KEY_A, false):
			input_vec.x -= 1.0
		if keys.get(KEY_D, false):
			input_vec.x += 1.0
		if keys.get(KEY_LEFT, false):
			input_vec.x -= 1.0
		if keys.get(KEY_RIGHT, false):
			input_vec.x += 1.0
	input_vec = input_vec.normalized()

	var cam := get_viewport().get_camera_3d()
	var cam_yaw: float = cam.global_transform.basis.get_euler().y if cam else 0.0
	var dir := (Vector3(input_vec.x, 0, input_vec.y)).rotated(Vector3.UP, cam_yaw)

	var speed: float = ability_state.horizontal_speed(in_dark_zone)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	# 跳跃：边沿触发；每次滞空至多 max_jumps；长按不吞二段跳
	if jump_pressed and on_floor:
		velocity.y = ability_state.jump_velocity_first()
		jumps_used = 1
		jump_performed.emit("first")
	elif jump_pressed and not on_floor and jumps_used >= 1 and jumps_used < ability_state.max_jumps():
		velocity.y = ability_state.jump_velocity_double()
		jumps_used += 1
		jump_performed.emit("double")

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5

	move_and_slide()

	# E 边沿 → 融合请求
	var e_down: bool = input_enabled and keys.get(KEY_E, false)
	if e_down and not get_meta("e_held", false):
		set_meta("e_held", true)
		fused.emit()
	elif not e_down:
		set_meta("e_held", false)
