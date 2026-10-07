extends RigidBody3D
## DEMO9 3D 真三维车体（阶段 B1-2，契约 game/demo09_3d/RULES_CONTRACT.md §11 D9 / §12）
## RigidBody3D + 每轮 ray-cast 悬挂（沿车体 -Y，排除本车，只撞道路层 1）。
## 单位：米制等价值（契约 §5）——重力 90 m/s²、悬挂自然长 2.0m、最大压缩 1.4m、
## 弹簧 60 1/s²、阻尼 9 1/s、单轮支撑上限 260 m/s²、总驱动 85 / 刹车 42 m/s²、
## 扭矩保留 0.15、风阻 0.02×drag×v²、滚阻 3 m/s²、极速 90 m/s、侧向抓地 60 m/s²（D5 初值）。
## 重力实现：gravity_scale=0，由本脚本施加 mass×90——数值与"引擎重力 90"等价且确定（不改项目设置）。
## 步骤顺序对齐旧 _drive_step：先全部悬挂探测得接地状态，再驱动（最后两条、接地者分摊）→ 阻力 → 极速。
## 阶段 B1-2 范围：直线物理。转向与横滚辅助属 B1-3；不做自动辅助（D3）。

const GarageModel := preload("res://demo09_3d/garage_model.gd")

const GRAVITY_M := 90.0
const SUSP_LEN_M := 2.0
const MAX_COMP_M := 1.4
const SPRING_K := 60.0
const SUSP_DAMP := 9.0
const MAX_SUSP_ACC := 260.0
const DRIVE_ACC_M := 85.0
const BRAKE_ACC_M := 42.0
const DRIVE_TORQUE_KEEP := 0.15
const ROLL_FRIC_M := 3.0
const DRAG_K := 0.02
const SPEED_MAX_M := 90.0
const LATERAL_GRIP := 60.0
const LATERAL_GRIP_GAIN := 20.0   # 轮胎侧偏刚度近似：力 = GAIN × 轮位侧滑速度（上限 LATERAL_GRIP）
const WHEELBASE_M := 5.32        # 前后轴距（对称 4 轮 xr 0.15/0.85 在 7.6m 车身上的轴距）
const MASS := 800.0

# 横滚辅助（D12，r3d-3）：仅 <4 轮且接地时施加绕前向轴的抗横滚扭矩。
# 依据：世界竖直悬挂+重心 5.1m 下，三轮横滚刚度 207kN·m/rad < 重力倾覆斜率 369kN·m/rad（实测必翻）；
# 旧 2D 无横滚物理故三轮可行——辅助使非 4 轮布局恢复可行，强度公开，4 轮布局完全不受影响。
const ROLL_ASSIST_STIFF := 260.0
const ROLL_ASSIST_DAMP := 40.0
# B3-2① 抗横滚杆（r3d-3）：左右配对轮压缩差 × GAIN → 差动力（压缩多方减力、伸张方加力）。
# 物理真实的抗横滚杆：抵抗横滚而不影响共模压缩（ride height）。
# 对称 4 轮（lat ±1.2，2 对）：额外横滚刚度 = 2×GAIN×lat²×mass ≈ 230kN·m/rad（补足缺口）。
const ANTI_ROLL_GAIN := 80.0   # N/m per kg of comp diff（调参公开）

# 转向规则（契约 D8，B1-3 定）：接地偏航上限 = min(2.2, 0.12×速度) rad/s（静止不可转向），
# 向目标 3.5 rad/s² 趋近；松手 5 rad/s² 回正；空中不转向；倒车时 A 仍为左（街机约定）。
const STEER_ACCEL := 3.5
const STEER_RETURN := 5.0

var drive_input := 0.0        # 场景层注入：1 油门 / -1 刹车倒车 / 0（B1-3 接 action 层）
var steer_input := 0.0        # -1 左(A) / 0 / +1 右(D)
var steer_angle := 0.0        # 前轮当前转角（rad，+ 为左）
var tick_count := 0           # 诊断：_physics_process 实际执行次数
var roof_time := 0.0          # 车顶触地累计（D10：≥1.5s 判翻，离地 2×dt 衰减）
var roof_touching := false    # 本步车顶是否贴地（诊断/测试用）
var roll_assist_enabled := true   # D12/r3d-3：<4 轮默认开启（B3-2② 实测 L1 颠簸路 2 轮中线必翻，辅助为必需）
var rolled_over := false      # 翻车判定已触发（场景层消费结算；翻车优先于冲线）
var hh_m := 1.7               # 车体半高（setup 按车身赋值）
var hl_m := 3.8               # 车体半长
var hw_m := 1.7               # 车体半宽（3.4m 占位宽）
var grounded_wheels := 0      # 遥测：本步接地轮数
var nan_flag := false         # NaN 看门狗（测试断言用）
var drag_factor := 1.0        # 车身风阻系数（setup 时从 BODIES 取）
var _anchors: Array = []      # {node: Node3D, radius_m: float, prev_comp: float, comp: float, contact: Vector3, normal: Vector3}

## 从 GarageModel 构建：布局已统一校验（含 lateral）。style 走 comic_style 统一入口。
func setup(model: RefCounted, style: Resource) -> void:
	var B: Dictionary = model.body()
	var blen_m: float = float(B.len) / 10.0
	var bh_m: float = float(B.h) / 10.0
	hl_m = blen_m * 0.5
	hh_m = bh_m * 0.5
	hw_m = 1.7
	drag_factor = float(B.drag)
	mass = MASS
	gravity_scale = 0.0
	continuous_cd = true
	can_sleep = false   # 测试需连续模拟；挂起会造成"静止"假象
	# D14 记录：宽横向布局在颠簸路上横滚不稳（刚度 138k < 重力斜率 369kN·m/rad）。
	# COM 下移方案（-3.5/-5.0）实测副作用大已回退；首选方案改挂 B3-2：
	# 抗横滚杆（按左右悬挂压缩差施加差动力，物理真实）。质心维持默认（箱体几何中心）。

	var col := CollisionShape3D.new()
	col.name = "BodyShape"
	var box := BoxShape3D.new()
	box.size = Vector3(3.4, bh_m, blen_m)
	col.shape = box
	add_child(col)

	var chassis := MeshInstance3D.new()
	chassis.name = "Chassis"
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(3.4, bh_m, blen_m)
	chassis.mesh = box_mesh
	chassis.material_override = style.body_material(Color("d9534f"))
	add_child(chassis)

	_anchors.clear()
	for w in model.wheels:
		var anchor := Node3D.new()
		anchor.name = "Anchor%d" % _anchors.size()
		# 旧局部 lx=(0.5-xr)*len（+x 车头）→ 3D z=-lx；lateral（D1）→ x
		anchor.position = Vector3(float(w.get("lateral", 0.0)), -bh_m * 0.5, -(0.5 - float(w.xr)) * blen_m)
		add_child(anchor)
		_anchors.append({node = anchor, radius_m = float(w.r) / 10.0, lx_m = (0.5 - float(w.xr)) * blen_m, lat_m = float(w.get("lateral", 0.0)), prev_comp = 0.0, comp = 0.0, contact = Vector3.ZERO, normal = Vector3.UP, pair_idx = -1})
	# B3-2① 抗横滚杆配对：同 lx_m（±0.05 容差）且 lat_m 异号的左右轮互为配对
	for i in range(_anchors.size()):
		if _anchors[i].pair_idx != -1:
			continue
		for j in range(i + 1, _anchors.size()):
			if absf(float(_anchors[i].lx_m) - float(_anchors[j].lx_m)) < 0.05 \
					and _anchors[i].lat_m * _anchors[j].lat_m < 0.0:
				_anchors[i].pair_idx = j
				_anchors[j].pair_idx = i
				break


func _physics_process(dt: float) -> void:
	tick_count += 1
	if nan_flag:
		return
	var space := get_world_3d().direct_space_state
	var up := global_transform.basis.y
	var fwd := -global_transform.basis.z
	var lat_ax := global_transform.basis.x

	apply_force(Vector3(0, -GRAVITY_M * mass, 0))   # gravity_scale=0 → 手动 90 m/s²

	# 第一遍：悬挂探测（接地状态 + 弹簧力）。
	# 射线与弹簧力都沿【世界竖直】方向——忠实旧 2D 语义（压缩来自沿世界竖直方向的地面探测，
	# 支撑力为竖直力；契约 §2）。沿车体 -Y 会在驱动抬头后探测 miss（实测车头抬 12° 全轮悬空）。
	var grounded := 0
	for a in _anchors:
		var origin: Vector3 = (a.node as Node3D).global_position
		var ray_len: float = SUSP_LEN_M + float(a.radius_m)
		var q := PhysicsRayQueryParameters3D.create(origin, origin + Vector3(0, -ray_len, 0))
		q.exclude = [get_rid()]
		q.collision_mask = 1
		var hit: Dictionary = space.intersect_ray(q)
		a.comp = 0.0
		a.normal = Vector3.UP
		a.contact = Vector3.ZERO
		if hit.has("position"):
			var d: float = origin.distance_to(hit.position)
			a.comp = clampf(ray_len - d, 0.0, MAX_COMP_M)
			a.contact = hit.position
			a.normal = hit.normal
		if float(a.comp) > 0.0:
			grounded += 1
			var comp_vel: float = clampf((float(a.comp) - float(a.prev_comp)) / dt, -200.0, 200.0)
			var f_acc: float = clampf(SPRING_K * float(a.comp) + SUSP_DAMP * comp_vel, 0.0, MAX_SUSP_ACC)
			apply_force(Vector3(0, f_acc * mass, 0), origin - global_position)
		a.prev_comp = a.comp
	grounded_wheels = grounded

	# B3-2① 抗横滚杆（D12/r3d-3）：对左右配对轮，按悬挂压缩差施加差动力。
	# 物理真实：压缩多的一侧减力、压缩少的一侧加力——抵抗横滚而不改变共模（ride height）。
	# 仅对称配对轮生效；中线布局无左右对 → 无抗横滚杆（该布局需其他方案）。
	for i in range(_anchors.size()):
		var pi: int = int(_anchors[i].pair_idx)
		if pi < 0 or pi <= i:
			continue
		var ai: Dictionary = _anchors[i]
		var aj: Dictionary = _anchors[pi]
		if float(ai.comp) > 0.0 and float(aj.comp) > 0.0:
			var comp_diff: float = float(ai.comp) - float(aj.comp)
			var arb_f: float = ANTI_ROLL_GAIN * comp_diff * mass
			var origin_i: Vector3 = (ai.node as Node3D).global_position
			var origin_j: Vector3 = (aj.node as Node3D).global_position
			# 抗横滚杆：压缩多方加力（抵抗压缩）、伸张方减力——增加横滚刚度
			apply_force(Vector3(0, arb_f, 0), origin_i - global_position)
			apply_force(Vector3(0, -arb_f, 0), origin_j - global_position)

	# 第二遍：驱动（最后两条、接地者分摊总加速，总力不随轮数翻倍——旧 :736-756 语义）
	var n := _anchors.size()
	var drive_idx: Array = []
	for k in range(maxi(0, n - 2), n):
		drive_idx.append(k)
	var dcount := 0
	for k in drive_idx:
		if float(_anchors[k].comp) > 0.0:
			dcount += 1
	if drive_input != 0.0 and dcount > 0:
		var mag: float = (DRIVE_ACC_M if drive_input > 0.0 else -BRAKE_ACC_M) / float(dcount)
		for k in drive_idx:
			var a: Dictionary = _anchors[k]
			if float(a.comp) <= 0.0:
				continue
			var tang: Vector3 = (fwd - Vector3.UP * fwd.dot(Vector3.UP)).normalized()
			# 旧 2D 语义：扭矩只取驱动力【竖直分量】的 15%（:752-753，平地≈0）——即驱动力
			# 实际作用于质心，平地不产生抬头扭矩。此处施加在质心；斜坡效应由悬挂几何自然产生。
			apply_force(tang * mag * mass)

	# 转向角（D8）：前轮最大转角受抓地限制 δ ≤ atan(0.85×GRIP×轴距 / v²)（向心加速度 ≤85% 抓地），
	# 低速封顶 0.6 rad（≈34°）；以 STEER_ACCEL 趋近目标、松手 STEER_RETURN 回正。
	# 空中也持续回正（真实方向盘语义）。
	var spd_m := linear_velocity.length()
	var max_steer: float = minf(0.6, atan(0.85 * LATERAL_GRIP * WHEELBASE_M / maxf(spd_m * spd_m, 1.0)))
	var steer_target := steer_input * max_steer
	var steer_rate := STEER_ACCEL if absf(steer_target) > absf(steer_angle) else STEER_RETURN
	steer_angle = move_toward(steer_angle, steer_target, steer_rate * dt)

	# 侧向抓地（D5）：按各轮位局部速度（含旋转分量 ω×r）在【轮子滚动方向】上的侧滑衰减，
	# 上限 LATERAL_GRIP（轮胎侧偏刚度近似，增益 GAIN）。前轮（lx>0，车头侧）按 steer_angle 偏转
	# 滚动方向——转向力由前轮滑移产生、后轮滑移提供自回正，"松手回正"由几何自然涌现。
	for a in _anchors:
		if float(a.comp) > 0.0:
			var origin: Vector3 = (a.node as Node3D).global_position
			var r_vec: Vector3 = origin - global_position
			var wheel_vel: Vector3 = linear_velocity + angular_velocity.cross(r_vec)
			var wheel_dir := fwd
			if float(a.lx_m) > 0.0 and absf(steer_angle) > 0.0001:
				wheel_dir = fwd.rotated(up, steer_angle)
			var roll_v: float = wheel_vel.dot(wheel_dir)
			var lat_vec: Vector3 = wheel_vel - wheel_dir * roll_v
			var lat_mag: float = lat_vec.length()
			if lat_mag > 0.01:
				apply_force(-lat_vec.normalized() * clampf(lat_mag * LATERAL_GRIP_GAIN, 0.0, LATERAL_GRIP) * mass, origin - global_position)

	# 风阻（速度平方律 × 车身系数）+ 滚阻（任一轮接地、前向速度 > 0.4 m/s）
	if spd_m > 0.001:
		apply_force(-linear_velocity.normalized() * DRAG_K * drag_factor * spd_m * spd_m * mass)
	if grounded > 0 and absf(linear_velocity.dot(fwd)) > 0.4:
		apply_force(-linear_velocity.normalized() * ROLL_FRIC_M * mass)

	# 极速
	if linear_velocity.length() > SPEED_MAX_M:
		linear_velocity = linear_velocity.normalized() * SPEED_MAX_M

	# 横滚辅助（D12/r3d-3）：仅 <4 轮且接地。横滚角取侧向量 y 分量（小角正弦，右倾为负），
	# 抗横滚扭矩 = (STIFF×roll + DAMP×roll_rate) × mass，绕前向轴（右倾 → 负扭矩 → 左回正）。
	if roll_assist_enabled and _anchors.size() < 4 and grounded > 0:
		var roll_sin: float = lat_ax.y
		var roll_rate: float = angular_velocity.dot(fwd)
		apply_torque(fwd * ((ROLL_ASSIST_STIFF * roll_sin + ROLL_ASSIST_DAMP * roll_rate) * mass))

	# 翻车检测（D10）：车顶面 4 角（局部 +Y 面，即背离车轮一侧）距地 ≤0.3m（旧 3px 等价）
	# 视为触地；累计 ≥1.5s 判翻，离地按 2×dt 衰减。语义与阶段 A 完全一致，仅检测几何 3D 化。
	var roof_hit := false
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var corner: Vector3 = global_position + global_transform.basis * Vector3(hw_m * cx, hh_m, hl_m * cz)
			var rq := PhysicsRayQueryParameters3D.create(corner, corner + Vector3(0, -0.5, 0))
			rq.exclude = [get_rid()]
			rq.collision_mask = 1
			var rh: Dictionary = space.intersect_ray(rq)
			if rh.has("position") and corner.distance_to(rh.position) <= 0.3:
				roof_hit = true
	roof_touching = roof_hit
	if roof_hit:
		roof_time += dt
	else:
		roof_time = maxf(0.0, roof_time - dt * 2.0)
	if roof_time >= 1.5 and not rolled_over:
		rolled_over = true

	# NaN 看门狗
	if not is_finite(global_position.x) or not is_finite(global_position.y) or not is_finite(linear_velocity.length()):
		nan_flag = true
		freeze = true
