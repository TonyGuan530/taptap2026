extends CharacterBody3D
## DEMO10 3D 阶段 A：第一人称探索者。WASD 移动、鼠标环视、E/Tab/Esc 只发原始事件——
## 模式仲裁（手稿开着时冻结移动与观察）由根脚本统一决定，这里不自作主张。
## 灰版约束：无战斗、无冲刺、无跳跃；速度与视角参数以灰模标定为准。

signal interact_requested
signal manuscript_toggle_requested
signal esc_requested
signal view_changed(pos: Vector3, yaw: float)

const SPEED := 3.2
const ACCEL := 11.0
const GRAVITY := 9.8
const MOUSE_SENS := 0.0024
const PITCH_LIMIT := 1.35   # 弧度，约 77°

var input_enabled := true    # 手稿/结算打开时为 false：冻结移动、观察与交互
var mouse_captured := false
var capture_enabled := true  # 测试/离屏管线置 false：逻辑状态照常流转，但绝不碰真实系统光标
var yaw := 0.0
var pitch := 0.0
var _skip_next_motion := false   # 捕获瞬间会收到一次大幅 motion（光标聚中），丢弃防甩视角

var cam: Camera3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0, 0.85, 0)
	add_child(shape)
	cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0, 1.6, 0)
	cam.fov = 70.0
	cam.current = true
	add_child(cam)
	floor_snap_length = 0.4


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and mouse_captured:
		if _skip_next_motion:
			_skip_next_motion = false
			return
		var mm := event as InputEventMouseMotion
		yaw = wrapf(yaw - mm.relative.x * MOUSE_SENS, -PI, PI)
		pitch = clampf(pitch - mm.relative.y * MOUSE_SENS, -PITCH_LIMIT, PITCH_LIMIT)
		rotation.y = yaw
		cam.rotation.x = pitch
		view_changed.emit(global_position, yaw)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if not mouse_captured:
			_capture_mouse()
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := event as InputEventKey
		match k.physical_keycode:
			KEY_E:
				interact_requested.emit()
			KEY_TAB:
				manuscript_toggle_requested.emit()
			KEY_ESCAPE:
				esc_requested.emit()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	var dir := Vector3.ZERO
	if input_enabled:
		var f := 0.0
		var s := 0.0
		if Input.is_physical_key_pressed(KEY_W):
			f += 1.0
		if Input.is_physical_key_pressed(KEY_S):
			f -= 1.0
		if Input.is_physical_key_pressed(KEY_A):
			s -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			s += 1.0
		if f != 0.0 or s != 0.0:
			var fwd := -transform.basis.z
			var right := transform.basis.x
			dir = (fwd * f + right * s).normalized()
	var target := dir * SPEED
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
	move_and_slide()


func _capture_mouse() -> void:
	mouse_captured = true
	if not capture_enabled:
		return   # 离屏测试管线：不调用 DisplayServer，真实光标分毫不动
	_skip_next_motion = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func release_mouse() -> void:
	mouse_captured = false
	if not capture_enabled:
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


## 从安全锚点迁移：清速度、保朝向（指南第 5 节：尽量保留地标与朝向）
func teleport_to(pos: Vector3, keep_yaw := true) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	if not keep_yaw:
		yaw = 0.0
		rotation.y = 0.0
		pitch = 0.0
		cam.rotation.x = 0.0
