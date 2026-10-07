extends RefCounted
## DEMO9 3D 纵向核心（阶段 A 受限轨迹桥梁，契约 game/demo09_3d/RULES_CONTRACT.md §5）
## 逐行复刻旧 2D game/demo09_racer.gd 的 _drive_step（:689-830）与 do_launch 物理初始化（:520-563），
## 单位保持旧 px（10px=1m 映射由三维表现层做）。与旧版的差异只有两处，均为解耦而非改规则：
## 1) 输入不查 Input，由调用方每步传 thr（1=油门 / -1=刹车倒车 / 0）；
## 2) 结算不再触碰 UI/解锁/布局存档（那是 RunController 的职责），核心只置状态并记录原因。
## 悬挂、驱动（最后两条分摊）、阻力、积分、四角防穿地、翻车（1.5s 累计/2dt 衰减、先于终点）、
## 托底边沿、幽灵采样、遥测六指标的运算顺序与旧版一致，供逐帧对照测试。

const GRAV := 900.0             # px/s^2（=90 m/s²，不许改 9.8）
const SUSP_LEN := 20.0
const SPRING_K := 60.0
const SUSP_DAMP := 9.0
const MAX_COMP := 14.0
const MAX_SUSP_ACC := 2600.0
const DRIVE_ACC := 850.0
const BRAKE_ACC := 420.0
const DRAG_K := 0.002
const ROLL_FRIC := 30.0
const ANG_DAMP := 4.0
const OMEGA_MAX := 5.0
const DRIVE_TORQUE_KEEP := 0.15
const ROOF_LIMIT := 1.5
const AIR_ASSIST := 3.0
const FALL_DEPTH_PX := 30.0     # 坠沟①：质心跌破沟沿甲板 3m（10px=1m）
const AIR_ASSIST_MIN_SPD := 80.0
const SPEED_MAX := 900.0
const START_X := 120.0
const BASE_GROUND_Y := 430.0
const PX_PER_M := 10.0

const GarageModel := preload("res://demo09_3d/garage_model.gd")

var model: RefCounted
var level_idx := 0
var body_kind := 1
var ph1 := 0.0
var ph2 := 0.0
var ph3 := 0.0

var wheels: Array = []          # 运行态 {id, xr, r, lx, ly, pc, spin, wx, wy}
var car_pos := Vector2(START_X, BASE_GROUND_Y - 40.0)
var car_angle := 0.0
var omega := 0.0
var vel := Vector2.ZERO
var flight_time := 0.0
var max_speed := 0.0            # 米/秒
var max_pitch := 0.0
var airtime_s := 0.0
var bottom_out := 0
var grounded_frames := 0
var drive_frames := 0
var roof_time := 0.0
var scroll_x := 0.0             # 2D 视图遗留字段，仅为对照保留；3D 相机不读它
var ghost_n := 0
var cur_ghost_pts: Array = []   # 当前局轨迹采样（旧版每 6 物理帧，仅作对照；3D 回放层另行按时间对齐）
var was_bottom := false
var state := "drive"            # drive / settle
var settle_reason := ""
var last_pass := false
## 沟壑像素区间（r3d-3 L10 起，由 grid_gaps 网格对齐后 ×10；空=无沟，行为与旧版位级一致）
var gap_px: Array = []
## 限高架（r3d-3 L11 起）：{gx 横杆 x 像素, bar 横杆世界 y 像素, clear 净空米}；空=无杆
var gate_px: Array = []
## 最近一次撞杆的净空（米，结算文案用）
var last_gate_clear := 0.0
## 名义车高（像素）：beam_y+SUSP_LEN+最大轮径+半车高。技术检查口径（与行驶姿态/悬挂
## 压缩无关）——实时车顶随扭矩抬头摆动 ±0.1m，1 档轮径分界（0.2m）会被噪声吃掉；
## 名义口径下 1px 级分界完全确定。launch() 计算，0=未就绪（不判杆）。
var nominal_top_px := 0.0
## 限速检测线（r3d-3 L12 起）：{gx 线 x 像素, vmin 过线最低速度像素/秒}；空=无检测线
var speed_gates_px: Array = []
var prev_x := 0.0                # 上一帧质心 x（跨线检测）
## 最近一次限速不达标的线速要求与实际车速（像素/秒，结算文案用）
var last_speed_vmin := 0.0
var last_speed_val := 0.0
## 分段检查点（r3d-3 L13 起）：{gx 线 x 像素, tmax 累计时限秒}；空=无检查点
var checkpoints_px: Array = []
## 已通过检查点的分段记录 [{gx 像素, t 通过时刻秒}]（结算文案用）
var checkpoint_splits: Array = []
## 最近一次超时的检查点（{gx, tmax, t}，结算文案用）
var last_late := {}
## 加速带（r3d-3 L14 起）：{gx 带 x 像素, dv 提速量像素/秒}；空=无加速带
var boost_px: Array = []


func setup(model_ref: RefCounted, p_level: int, p_body: int) -> void:
	model = model_ref
	level_idx = p_level
	body_kind = p_body
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + level_idx * 77   # 与旧版 :385 相同种子与取数顺序，保证相位一致
	ph1 = rng.randf() * TAU
	ph2 = rng.randf() * TAU
	ph3 = rng.randf() * TAU
	gap_px = []
	for gr in model.grid_gaps(model.level()):
		gap_px.append(Vector2(float(gr.z0) * 10.0, float(gr.z1) * 10.0))
	gate_px = []
	last_gate_clear = 0.0
	for gt in model.level().get("gates", []):
		var gx_px: float = float(gt.gx) * 10.0
		gate_px.append({gx = gx_px, bar = ground_y(gx_px) - float(gt.clear) * 10.0, clear = float(gt.clear)})
	speed_gates_px = []
	last_speed_vmin = 0.0
	last_speed_val = 0.0
	prev_x = 0.0
	for sg in model.level().get("speed_gates", []):
		speed_gates_px.append({gx = float(sg.gx) * 10.0, vmin = float(sg.vmin) * 10.0})
	checkpoints_px = []
	checkpoint_splits = []
	last_late = {}
	for cp in model.level().get("checkpoints", []):
		checkpoints_px.append({gx = float(cp.gx) * 10.0, tmax = float(cp.tmax)})
	boost_px = []
	for b in model.level().get("boosts", []):
		boost_px.append({gx = float(b.gx) * 10.0, dv = float(b.dv) * 10.0})
	cur_ghost_pts = []
	was_bottom = false
	state = "drive"
	settle_reason = ""
	last_pass = false


## 地形高度（旧版 :347 同式）：三层正弦叠加 × 起步 ramp + 显式跳台特征
## 跳台（r3d-3 L9 起）：raised-cosine 局部凸台 {z0 起点, h 峰高, w 全宽}，地面抬升 h·½(1−cos)，
## 不参与起步 ramp 混合（刻意特征，高度精确兑现）；无 ramps 字段的关卡 bump=0，位级不变。
func ground_y(x: float) -> float:
	var L: Dictionary = model.level()
	var ramp: float = clampf((x - 60.0) / 520.0, 0.0, 1.0)
	var h: float = float(L.a1) * sin(x * TAU / float(L.w1) + ph1) \
		+ float(L.a2) * sin(x * TAU / float(L.w2) + ph2) \
		+ float(L.a3) * sin(x * TAU / float(L.w3) + ph3)
	var bump: float = 0.0
	for rp in L.get("ramps", []):
		# ramps 参数为米（策划口径），ground_y 全程像素（10px=1m）
		var dx: float = x - float(rp.z0) * 10.0
		var w: float = float(rp.w) * 10.0
		if dx >= 0.0 and dx <= w:
			bump += float(rp.h) * 10.0 * 0.5 * (1.0 - cos(TAU * dx / w))
	return BASE_GROUND_Y - h * ramp + bump


## 质心/轮心投影是否在沟壑开洞区间（像素；gap_px 空 = 恒 false，与旧版行为一致）
func _in_gap(x: float) -> bool:
	for gr in gap_px:
		if x >= gr.x and x <= gr.y:
			return true
	return false


## 坠沟①垂直坠落：车体（质心 ± 半长）与沟交叠且质心跌破沟沿甲板（两缘 ground_y 取小）3m。
## 窗口与角点钳制跳过窗口（_bridging）完全一致——两规则必须无缝覆盖，否则存在
## "既不判坠也不钳制"的坠落漏区（车会坠出窗口以 flip 结算）。
## 甲板取沟沿而非沟下解析地面——沟下地面随正弦起伏，不可作基准。
func _gap_depth_fall(cx: float, cy: float, half_len: float) -> bool:
	for gr in gap_px:
		if cx >= float(gr.x) - half_len and cx <= float(gr.y) + half_len:
			var deck: float = minf(ground_y(float(gr.x)), ground_y(float(gr.y)))
			if cy - deck > FALL_DEPTH_PX:
				return true
	return false


## 桥接：车体与沟 x 区间交叠（质心 ∈ [g0-半长, g1+半长]）——沟区腾空，角点钳制跳过
func _bridging(cx: float, half_len: float) -> bool:
	for gr in gap_px:
		if cx >= float(gr.x) - half_len and cx <= float(gr.y) + half_len:
			return true
	return false


## 下一个未通过的检查点（HUD 倒计时用）：{gx, tmax}；全部通过或无检查点返回空字典
func next_checkpoint() -> Dictionary:
	for cp in checkpoints_px:
		if car_pos.x < float(cp.gx):
			return cp
	return {}


## 发车初始化（逐行对照旧 do_launch :527-549 的物理部分；布局须先经 GarageModel 校验）
func launch() -> void:
	var B: Dictionary = model.body()
	var beam_y: float = float(B.beam_y)
	var n: int = model.wheels.size()
	var comp0: float = GRAV / (float(n) * SPRING_K)   # 静止压缩量（每轮平摊重力）
	wheels = []
	for w in model.wheels:
		wheels.append({
			id = int(w.id), xr = float(w.xr), r = float(w.r),
			lateral = float(w.get("lateral", 0.0)),   # D1：侧向位置随运行态携带（B1 物理与视图用）
			lx = (0.5 - float(w.xr)) * float(B.len),   # xr=0（车头）在局部 +x
			ly = beam_y, pc = comp0, spin = 0.0, wx = 0.0, wy = 0.0,
		})
	var r0 := float(wheels[0].r)
	car_pos = Vector2(START_X, ground_y(START_X) - beam_y - SUSP_LEN - r0 + comp0)
	# 名义车高（限高架判定口径）：最高轮径决定的车顶名义高度（像素）
	var r_max: float = r0
	for w in wheels:
		r_max = maxf(r_max, float(w.r))
	nominal_top_px = beam_y + SUSP_LEN + r_max + float(B.h) * 0.5
	car_angle = 0.0
	omega = 0.0
	vel = Vector2.ZERO
	flight_time = 0.0
	max_speed = 0.0
	max_pitch = 0.0
	airtime_s = 0.0
	bottom_out = 0
	grounded_frames = 0
	drive_frames = 0
	roof_time = 0.0
	scroll_x = 0.0
	ghost_n = 0
	cur_ghost_pts = []
	was_bottom = false
	state = "drive"
	settle_reason = ""
	last_pass = false


func _settle(reason: String) -> void:
	state = "settle"
	settle_reason = reason
	last_pass = reason == "finish"


## 一个物理步。thr：1=油门 / -1=刹车倒车 / 0。返回 ""=继续驾驶，否则本次结算原因。
func step(dt: float, thr: float) -> String:
	if state != "drive":
		return settle_reason
	flight_time += dt
	prev_x = car_pos.x
	var B: Dictionary = model.body()
	var blen: float = float(B.len)
	var bh: float = float(B.h)

	# 悬挂：每个轮胎对地面做竖直探测，弹簧+阻尼，力作用在锚点（产生力+扭矩）
	# 沟壑（L10）：轮心投影在开洞区间内 → 无地面支撑（腾空坠落）
	var acc := Vector2(0.0, GRAV)
	var torque := 0.0
	var grounded := 0
	for w in wheels:
		var ly: float = float(w.ly)
		var r: float = float(w.r)
		var aw := car_pos + Vector2(float(w.lx), ly).rotated(car_angle)
		var gy := ground_y(aw.x)
		var comp: float = (aw.y + SUSP_LEN + r) - gy
		if comp > 0.0 and not _in_gap(aw.x):
			grounded += 1
			comp = minf(comp, MAX_COMP)
			var comp_vel: float = clampf((comp - float(w.pc)) / dt, -2000.0, 2000.0)
			w.pc = comp
			var f: float = SPRING_K * comp + SUSP_DAMP * comp_vel
			f = clampf(f, 0.0, MAX_SUSP_ACC)   # 轮子只能推不能拉
			acc.y -= f
			var rvec := aw - car_pos
			torque += rvec.x * (-f)            # 竖直力对质心的扭矩
			w.wx = aw.x
			w.wy = minf(aw.y + SUSP_LEN, gy - r)
		else:
			w.pc = 0.0
			w.wx = aw.x
			w.wy = aw.y + SUSP_LEN

	# 驱动/刹车：驱动轮 = 最后两个轮胎，力沿地面切向（扭矩只保留一小部分，防满油门后翻）
	var n := wheels.size()
	if thr != 0.0 and grounded > 0:
		var drive0: int = maxi(0, n - 2)
		var dcount := 0
		for k in range(drive0, n):
			var wk: Dictionary = wheels[k]
			if float(wk.pc) > 0.0:
				dcount += 1
		if dcount > 0:
			var mag: float = (DRIVE_ACC if thr > 0.0 else -BRAKE_ACC) / float(dcount)
			for k in range(drive0, n):
				var wd: Dictionary = wheels[k]
				if float(wd.pc) <= 0.0:
					continue
				var wx2: float = float(wd.wx)
				var slope: float = (ground_y(wx2 + 2.0) - ground_y(wx2 - 2.0)) / 4.0
				var fv := Vector2(1.0, slope).normalized() * mag
				acc += fv
				var reff := Vector2(float(wd.lx), float(wd.ly)).rotated(car_angle) * DRIVE_TORQUE_KEEP
				torque += reff.x * fv.y - reff.y * fv.x

	# 风阻（速度平方律）+ 滚动阻力
	var spd := vel.length()
	if spd > 0.01:
		acc += -vel / spd * (DRAG_K * float(B.drag) * spd * spd)
	if grounded > 0 and absf(vel.x) > 4.0:
		acc.x -= signf(vel.x) * ROLL_FRIC

	# 遥测采集：max_pitch / airtime / bottom_out / 接地率
	drive_frames += 1
	max_pitch = maxf(max_pitch, absf(car_angle))
	if grounded > 0:
		grounded_frames += 1
	else:
		airtime_s += dt
	var bo_now := false
	for w in wheels:
		if float(w.pc) >= MAX_COMP - 0.5:
			bo_now = true
			break
	if bo_now and not was_bottom:
		bottom_out += 1
	was_bottom = bo_now
	ghost_n += 1
	if ghost_n % 6 == 0:
		cur_ghost_pts.append(car_pos)

	# 手写积分（无物理引擎）：线速度 + 角速度
	vel += acc * dt
	if vel.length() > SPEED_MAX:
		vel = vel.normalized() * SPEED_MAX
	var inertia: float = blen * blen / 12.0
	omega += torque / inertia * dt
	omega -= omega * ANG_DAMP * dt
	omega = clampf(omega, -OMEGA_MAX, OMEGA_MAX)
	if grounded == 0 and vel.length() > AIR_ASSIST_MIN_SPD:
		var vd := wrapf(vel.angle() - car_angle, -PI, PI)
		if absf(vd) < 1.75:   # 车头大致朝前才辅助；朝天/翻滚状态不救（保留翻车）
			omega += vd * AIR_ASSIST * dt
	car_pos += vel * dt
	car_angle = wrapf(car_angle + omega * dt, -PI, PI)

	# 加速带（L14）：前向跨带瞬间沿当前方向提速 dv，封顶 SPEED_MAX（r3d-3 首个增益机制）
	for b in boost_px:
		if prev_x < float(b.gx) and car_pos.x >= float(b.gx):
			var b_spd: float = vel.length()
			if b_spd > 1.0:
				vel = vel.normalized() * minf(b_spd + float(b.dv), SPEED_MAX)

	# 坠沟①垂直坠落（L10，先于角点钳制）：车体仍与沟交叠且质心跌破沟沿甲板 3m
	if _gap_depth_fall(car_pos.x, car_pos.y, blen * 0.5):
		_settle("fall")
		return settle_reason

	# 限高架（L11，先于终点检查）：名义车高（beam_y+SUSP+max_r+hh，技术检查口径，
	# 与行驶姿态无关）超过净空 → 撞杆判负；质心进入杆窗口（±半长）即查
	if nominal_top_px > 0.0:
		for gt in gate_px:
			if absf(car_pos.x - float(gt.gx)) <= blen * 0.5 and float(gt.clear) * 10.0 < nominal_top_px:
				last_gate_clear = float(gt.clear)
				_settle("gate")
				return settle_reason

	# 限速检测线（L12，先于终点检查）：本帧质心前向跨线且车速低于线速 → 检测不通过
	for sg in speed_gates_px:
		if prev_x < float(sg.gx) and car_pos.x >= float(sg.gx):
			var cross_spd: float = vel.length()
			if cross_spd < float(sg.vmin):
				last_speed_vmin = float(sg.vmin)
				last_speed_val = cross_spd
				_settle("speed")
				return settle_reason

	# 分段检查点（L13，先于终点检查）：前向跨线时比赛用时超过累计时限 → 超时判负，
	# 否则记入分段（慢段可由快段补偿——与限速门的瞬时判定互补）
	for cp in checkpoints_px:
		if prev_x < float(cp.gx) and car_pos.x >= float(cp.gx):
			if flight_time > float(cp.tmax):
				last_late = {gx = float(cp.gx), tmax = float(cp.tmax), t = flight_time}
				_settle("late")
				return settle_reason
			checkpoint_splits.append({gx = float(cp.gx), t = flight_time})

	# 车身四角防穿地 + 车顶触地计时（持续 1.5 秒 → 翻车；先于终点检查）
	# 桥接中（车体与沟 x 区间交叠）角点钳制整体跳过：沟区=腾空，钳制只会把坠沟车
	# "捞"上远侧路面（沟下解析地面连续）；失败飞越由坠沟①深度规则判负
	var hl: float = blen * 0.5
	var hh: float = bh * 0.5
	var bridging: bool = _bridging(car_pos.x, hl)
	var corners := [Vector2(-hl, -hh), Vector2(hl, -hh), Vector2(-hl, hh), Vector2(hl, hh)]
	var roof_hit := false
	for cv in corners:
		var wp: Vector2 = car_pos + cv.rotated(car_angle)
		if bridging or _in_gap(wp.x):
			continue   # 沟壑上空无地面：不钳制、不计车顶触地
		var pen: float = wp.y - ground_y(wp.x)
		if pen > -3.0 and cv.y < 0.0:
			roof_hit = true
		if pen > 0.0:
			car_pos.y -= pen
			if cv.y < 0.0:
				vel.y = -absf(vel.y) * 0.08   # 车顶蹭地：减速
				vel.x *= 0.94
			else:
				vel.y = minf(vel.y, 0.0) * -0.12
	if roof_hit:
		roof_time += dt
	else:
		roof_time = maxf(0.0, roof_time - dt * 2.0)
	if roof_time >= ROOF_LIMIT:
		_settle("flip")
		return settle_reason

	# 轮子自转（纯表现）
	for w in wheels:
		if float(w.pc) > 0.0:
			w.spin = float(w.spin) + vel.x / maxf(float(w.r), 1.0) * dt

	scroll_x = maxf(0.0, car_pos.x - 380.0)
	max_speed = maxf(max_speed, vel.length() / PX_PER_M)
	if car_pos.x >= START_X + float(model.level().target_m) * PX_PER_M:
		_settle("finish")
	return settle_reason
