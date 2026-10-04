extends Node3D
## 第三人称相机架：yaw/pitch 与角色朝向分离；SpringArm3D 防遮挡并排除玩家本体。
## 鼠标捕获观察不自动移动角色；Esc 切换捕获/释放。

const SENSITIVITY := 0.0025
const PITCH_MIN := -1.1
const PITCH_MAX := -0.15
const ARM_LENGTH := 4.5

var excluded_body: PhysicsBody3D   # root 在 add_child 前设置
var captured := true
var _yaw := 0.0   # D 键=+X
var _pitch := -0.35

var arm: SpringArm3D
var cam: Camera3D

func _ready() -> void:
	arm = SpringArm3D.new()
	arm.spring_length = ARM_LENGTH
	if excluded_body:
		arm.add_excluded_object(excluded_body.get_rid())
	add_child(arm)
	cam = Camera3D.new()
	cam.position = Vector3(0, 0, 0)
	arm.add_child(cam)
	cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	apply_rotation()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		captured = not captured
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
		return
	if not captured:
		return
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * SENSITIVITY, PITCH_MIN, PITCH_MAX)
		apply_rotation()

func apply_rotation() -> void:
	rotation = Vector3(0, _yaw, 0)
	arm.rotation = Vector3(_pitch, 0, 0)
