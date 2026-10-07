extends Node3D
## DEMO10 3D 阶段 A：InteractionController——视线中心射线检查。
## 指南第 4 节：中心射线、明确距离、只打交互层；遮挡墙自然阻断（射线打到墙就停）。
## 空间查询放 _physics_process 轮询缓存，不在鼠标事件里直接访问物理空间。
## HUD 只显示「检查对象标题」，绝不显示基调/派生义/可圆回提示（盲测安全由 WorldBridge 保证）。

signal target_changed(id: String)   # ""=当前无目标

const RANGE := 2.8
const INTERACT_MASK := 4            # 交互层（Area3D）

var cam: Camera3D
var _hit_id := ""
var _hit_collider: Node3D = null


func setup(camera: Camera3D) -> void:
	cam = camera


func current_target() -> String:
	return _hit_id


## 当前命中的交互体（梯架等需要读取附加 meta 的对象用）
func current_collider() -> Node3D:
	return _hit_collider


func _physics_process(_delta: float) -> void:
	if cam == null:
		return
	var id := ""
	var collider: Node3D = null
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, INTERACT_MASK)
	query.collide_with_areas = true    # 检查对象是 Area3D；默认 false 会全部漏检
	query.collide_with_bodies = false  # 墙体只负责遮挡：打墙=无目标（打到墙就到不了更远的 Area）
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		var node = hit.get("collider")
		if node != null and node.has_meta("inspect_id"):
			id = str(node.get_meta("inspect_id"))
			collider = node
	if id != _hit_id:
		_hit_id = id
		_hit_collider = collider
		target_changed.emit(id)
