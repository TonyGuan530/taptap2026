extends Node3D
## DEMO9 3D 车辆视图（契约 §1 受限轨迹桥梁）：只读 LaneCore 状态做映射，不参与物理。
## 布局语义铁律：一个 wheel 条目 = 一只实际轮胎，视图也只画一只、置于车体中线；
## 侧向位置（左右轮距）是阶段 B 决策（契约 §11），阶段 A 不得自动镜像成左右两只。

const LaneCore := preload("res://demo09_3d/lane_core.gd")
const PX_PER_M := 10.0

## 阶段 A 占位车宽（米）。2D 无宽度概念，正式车宽待阶段 B 定（契约 §11）
const CAR_WIDTH_M := 3.4

var _wheel_pivots: Array = []   # Node3D，每帧按悬挂压缩更新 y
var _wheel_meshes: Array = []   # MeshInstance3D，按 spin 更新自转


## body_dict: model.body()；wheels_runtime: core.wheels（含 lx/ly/r）；style: comic_style Resource
func setup(body_dict: Dictionary, wheels_runtime: Array, style: Resource) -> void:
	var blen: float = float(body_dict.len) / PX_PER_M
	var bh: float = float(body_dict.h) / PX_PER_M
	name = "CarView"

	var chassis := MeshInstance3D.new()
	chassis.name = "Chassis"
	var box := BoxMesh.new()
	box.size = Vector3(CAR_WIDTH_M, bh, blen)
	chassis.mesh = box
	chassis.material_override = style.body_material(Color("d9534f"))
	# 旧 2D 车身四角 = car_pos ± (len/2, h/2)：盒心即车心（局部原点），不偏移
	chassis.position.y = 0.0
	add_child(chassis)

	var cabin := MeshInstance3D.new()
	cabin.name = "Cabin"
	var cabin_box := BoxMesh.new()
	cabin_box.size = Vector3(CAR_WIDTH_M * 0.72, bh * 0.55, blen * 0.42)
	cabin.mesh = cabin_box
	cabin.material_override = style.body_material(Color("4a90d9"))
	cabin.position = Vector3(0.0, bh * 0.78, blen * 0.06)
	add_child(cabin)

	for w in wheels_runtime:
		var pivot := Node3D.new()
		pivot.name = "WheelPivot%d" % _wheel_pivots.size()
		var cyl := CylinderMesh.new()
		cyl.height = 0.6
		cyl.top_radius = float(w.r) / PX_PER_M
		cyl.bottom_radius = float(w.r) / PX_PER_M
		var mesh_node := MeshInstance3D.new()
		mesh_node.name = "Wheel"
		mesh_node.mesh = cyl
		mesh_node.material_override = style.body_material(Color("242934"))
		pivot.add_child(mesh_node)
		add_child(pivot)
		_wheel_pivots.append(pivot)
		_wheel_meshes.append(mesh_node)
		_update_wheel_local(pivot, float(w.lx), float(w.ly), float(w.pc), float(w.get("lateral", 0.0)))


## 每物理帧调用：按 core 状态刷新位置/姿态/悬挂/自转（只读，不写回）
func apply_state(core) -> void:
	var pos: Vector2 = core.car_pos
	position = Vector3(0.0, (LaneCore.BASE_GROUND_Y - pos.y) / PX_PER_M, -(pos.x - LaneCore.START_X) / PX_PER_M)
	# 旧 car_angle 正=车头向下；3D 车头 -Z，绕 +X 正旋转让 -Z 抬头 → 取负
	rotation.x = -float(core.car_angle)
	var i := 0
	for w in core.wheels:
		if i >= _wheel_pivots.size():
			break
		_update_wheel_local(_wheel_pivots[i], float(w.lx), float(w.ly), float(w.pc), float(w.get("lateral", 0.0)))
		# 自转：绕轮轴（Y）转 spin，再摆倒使轴沿侧向 X
		_wheel_meshes[i].basis = Basis(Vector3(0, 0, 1), PI / 2.0) * Basis(Vector3(0, 1, 0), float(w.spin))
		i += 1


func _update_wheel_local(pivot: Node3D, lx_px: float, ly_px: float, pc_px: float, lateral_m: float = 0.0) -> void:
	# 旧局部：锚点 (lx, ly=beam_y 正=向下)，轮心 = 锚点 + (悬挂自然长 - 压缩)
	# 3D 局部：x=lateral 米（D1，阶段 A 缺省 0=中线），y 向上取负，z=-lx（+x 车头 → -Z 机头）
	var wheel_y := -(ly_px + LaneCore.SUSP_LEN - pc_px) / PX_PER_M
	pivot.position = Vector3(lateral_m, wheel_y, -lx_px / PX_PER_M)
