extends RefCounted
## DEMO9 3D 车库数据模型（rule_version r3d-1，规则契约见同目录 RULES_CONTRACT.md）
## 纯逻辑无场景依赖，供 3D 车库 UI、RunController 与测试共同调用。
## 对照旧 2D game/demo09_racer.gd（保留不改）。与旧版的唯一行为差异是缺口修补（契约 §9-1）：
## 预算 Σπr² 不再只在 add_wheel 检查，而是新增/调半径/恢复布局/发车全路径统一验证；
## 超预算的变更被拒绝且保留原数据，并给出明确原因。其余约束语义与旧版逐条一致。

const RULE_VERSION := "r3d-3"
const WHEEL_MAX := 4
const R_MIN := 12.0
const R_MAX := 30.0
const PX_PER_M := 10.0
const LATERAL_MAX := 1.4   # 契约 §11 D1（B0 修订版）：侧向硬边界 ±1.4m，越界拒绝；UI 三档 ±1.2/0

## 车身预设：len/h/beam_y/drag 与旧版 :45-49 完全一致
const BODIES := [
	{name = "宽扁车身", desc = "重心低 · 稳 · 风阻大", len = 90.0, h = 26.0, beam_y = 9.0, drag = 1.35},
	{name = "标准车身", desc = "均衡之选", len = 76.0, h = 34.0, beam_y = 13.0, drag = 1.0},
	{name = "高窄车身", desc = "重心高 · 易颠 · 风阻小", len = 64.0, h = 44.0, beam_y = 18.0, drag = 0.75},
]

## 关卡表与旧版 :53-70 一致（地面配色属 2D 表现，不随模型迁移；地形三层正弦供 3D 道路同源生成）
const LEVELS := [
	{name = "第 1 关 · 郊外直道", short = "郊外直道", target_m = 800.0,
		a1 = 9.0, w1 = 300.0, a2 = 4.0, w2 = 110.0, a3 = 7.0, w3 = 900.0,
		min_wheels = 2, rear_min = 0, max_r = 0.0,
		tip = "平缓路面：至少 2 个轮胎、半径不限"},
	{name = "第 2 关 · 丘陵起伏", short = "丘陵起伏", target_m = 1000.0,
		a1 = 20.0, w1 = 320.0, a2 = 7.0, w2 = 130.0, a3 = 14.0, w3 = 900.0,
		min_wheels = 2, rear_min = 2, max_r = 0.0,
		tip = "丘陵路面：至少 2 个轮胎，且后半段（x>0.5）至少 2 个"},
	{name = "第 3 关 · 山地陡坡", short = "山地陡坡", target_m = 1200.0,
		a1 = 28.0, w1 = 380.0, a2 = 11.0, w2 = 160.0, a3 = 20.0, w3 = 900.0,
		min_wheels = 2, rear_min = 2, max_r = 20.0,
		tip = "山地陡坡：两个后轮 + 轮胎半径上限 20"},
	{name = "第 4 关 · 诊断测试场", short = "诊断测试场", target_m = 450.0,
		a1 = 17.0, w1 = 170.0, a2 = 9.0, w2 = 48.0, a3 = 3.0, w3 = 900.0,
		min_wheels = 2, rear_min = 0, max_r = 0.0, budget = 4300.0,
		tip = "诊断测试场：轮胎总面积预算 4300（Σπr²），大轮与多轮不可兼得"},
	{name = "第 5 关 · 连续陡坡", short = "连续陡坡", target_m = 600.0,
		a1 = 12.0, w1 = 200.0, a2 = 18.0, w2 = 140.0, a3 = 24.0, w3 = 600.0,
		min_wheels = 2, rear_min = 2, max_r = 0.0,
		tip = "连续陡坡：爬坡需后轮抓地与足够速度，坡度大时滑回"},
	{name = "第 6 关 · 预算爬坡", short = "预算爬坡", target_m = 500.0,
		a1 = 14.0, w1 = 180.0, a2 = 20.0, w2 = 120.0, a3 = 16.0, w3 = 500.0,
		min_wheels = 2, rear_min = 2, max_r = 0.0, budget = 2500.0,
		tip = "预算爬坡：预算紧缩 2500 + 陡坡地形——小轮爬坡费劲、大轮超预算，取舍考验"},
	{name = "第 7 关 · 悬挂极限", short = "悬挂极限", target_m = 400.0,
		a1 = 20.0, w1 = 60.0, a2 = 15.0, w2 = 80.0, a3 = 5.0, w3 = 800.0,
		min_wheels = 2, rear_min = 2, max_r = 0.0, budget = 3000.0,
		tip = "悬挂极限：高频搓板路持续逼近悬挂行程上限——轮径选择决定托底频率"},
	{name = "第 8 关 · 峡谷穿越", short = "峡谷穿越", target_m = 500.0,
		a1 = 25.0, w1 = 150.0, a2 = 8.0, w2 = 60.0, a3 = 3.0, w3 = 1000.0,
		min_wheels = 2, rear_min = 2, max_r = 0.0, budget = 2000.0,
		tip = "峡谷穿越：紧预算 2000 + 深谷地形——轮子越小预算越松但爬坡越费劲"},
	{name = "第 9 关 · 跳跃台", short = "跳跃台", target_m = 600.0,
		a1 = 2.0, w1 = 500.0, a2 = 1.0, w2 = 200.0, a3 = 2.0, w3 = 900.0,
		min_wheels = 2, rear_min = 2, max_r = 0.0, budget = 3200.0,
		ramps = [{z0 = 150.0, h = 6.0, w = 48.0},
			{z0 = 320.0, h = 8.0, w = 64.0},
			{z0 = 470.0, h = 5.0, w = 40.0}],
		tip = "跳跃台：近乎平坦的基线 + 三座刻意跳台（峰值 6/8/5m）——腾空与落地姿态决定成败，大轮缓冲落地"},
	{name = "第 10 关 · 断崖沟壑", short = "断崖沟壑", target_m = 550.0,
		a1 = 2.0, w1 = 500.0, a2 = 1.0, w2 = 200.0, a3 = 2.0, w3 = 900.0,
		min_wheels = 2, rear_min = 2, max_r = 0.0, budget = 3000.0,
		ramps = [{z0 = 280.0, h = 6.0, w = 48.0}, {z0 = 440.0, h = 6.0, w = 64.0}],
		gaps = [{z0 = 306.0, len = 10.0}, {z0 = 474.0, len = 12.0}],
		tip = "断崖沟壑：道路真开洞，且沟只能在跳台 crest 起跳飞越（平地沟不可跨）——速度不足坠沟判负"},
	{name = "第 11 关 · 限高架", short = "限高架", target_m = 450.0,
		a1 = 2.0, w1 = 500.0, a2 = 1.0, w2 = 200.0, a3 = 2.0, w3 = 900.0,
		min_wheels = 2, rear_min = 2, max_r = 0.0, budget = 2600.0,
		gates = [{gx = 350.0, clear = 6.7}],
		tip = "限高架：横杆净空 6.7m（名义车高=车架+悬挂+最大轮径，技术检查口径）——r18+ 大轮组合撞杆判负"},
	{name = "第 12 关 · 限速检测", short = "限速检测", target_m = 500.0,
		a1 = 8.0, w1 = 400.0, a2 = 4.0, w2 = 150.0, a3 = 3.0, w3 = 900.0,
		min_wheels = 2, rear_min = 2, max_r = 0.0,
		speed_gates = [{gx = 260.0, vmin = 45.0}, {gx = 430.0, vmin = 55.0}],
		tip = "限速检测：两道检测线要求过线车速达标——爬坡掉速后需全力冲刺补速，宽扁车身风阻大更易掉速"},
	{name = "第 13 关 · 分段计时", short = "分段计时", target_m = 600.0,
		a1 = 10.0, w1 = 350.0, a2 = 5.0, w2 = 140.0, a3 = 4.0, w3 = 900.0,
		min_wheels = 2, rear_min = 2, max_r = 0.0,
		checkpoints = [{gx = 220.0, tmax = 5.4}, {gx = 420.0, tmax = 10.6}, {gx = 560.0, tmax = 14.0}],
		tip = "分段计时：三处检查点有累计时限（发车起算），超时判负——慢段可由快段补偿，但整体节奏不能拖"},
	{name = "第 14 关 · 加速带", short = "加速带", target_m = 500.0,
		a1 = 2.0, w1 = 500.0, a2 = 1.0, w2 = 200.0, a3 = 2.0, w3 = 900.0,
		min_wheels = 2, rear_min = 2, max_r = 0.0, budget = 3200.0,
		speed_gates = [{gx = 260.0, vmin = 72.0}, {gx = 430.0, vmin = 80.0}],
		boosts = [{gx = 257.0, dv = 15.0}, {gx = 427.0, dv = 20.0}],
		tip = "加速带：检测线车速超过极速（65）——只有贴线吃下加速板（+15/+20）才过得了线；阻力会吃掉提前加速"},
]

## 沟壑网格对齐：road_builder 段长 SEG_M=2m 的整数倍上开洞（可视网格与 lane_core 判定
## 共用本函数输出，严格同源）。gaps 参数为米（绝对里程口径，与 ramps z0 同基准）。
const GAP_GRID_M := 2.0


static func grid_gaps(level: Dictionary) -> Array:
	var out: Array = []
	for g in level.get("gaps", []):
		var g0: float = floorf(float(g.z0) / GAP_GRID_M) * GAP_GRID_M
		var g1: float = ceilf((float(g.z0) + float(g.len)) / GAP_GRID_M) * GAP_GRID_M
		out.append({z0 = g0, z1 = g1})
	return out


var level_idx := 0
var body_kind := 1
## 轮胎条目：{id, xr, r, lateral}。一个条目 = 一只实际轮胎（契约 §2），id 单调递增不复用，
## lateral 为侧向位置（米，D1；旧布局缺省 0=中线）。驱动轮兼容语义仍是“数组最后两条”（driver_indices）。
var wheels: Array = []
var _next_id := 1


func geometry_seed(i: int) -> int:
	return 900 + i * 77   # 与旧版 :385 一致：三层正弦相位种子


## 切换关卡约束（不改动已有布局；流程性的清场/预填由上层 RunController 组合 restore_layout 完成）
func set_level(i: int) -> bool:
	if i < 0 or i >= LEVELS.size():
		return false
	level_idx = i
	return true


func level() -> Dictionary:
	return LEVELS[level_idx]


func level_budget() -> float:
	return float(LEVELS[level_idx].get("budget", 0.0))


func body() -> Dictionary:
	return BODIES[body_kind]


func area_sum(ws: Array = []) -> float:
	var s := 0.0
	for w in (ws if not ws.is_empty() else wheels):
		s += PI * float(w.r) * float(w.r)
	return s


## 驱动轮兼容语义：数组最后 min(2, n) 条（旧版 :736 drive0=maxi(0,n-2)），与接地状态无关
func driver_indices() -> Array:
	var n := wheels.size()
	if n == 0:
		return []
	var out: Array = []
	for k in range(maxi(0, n - 2), n):
		out.append(k)
	return out


func rear_count(ws: Array = []) -> int:
	var n := 0
	for w in (ws if not ws.is_empty() else wheels):
		if float(w.xr) > 0.5:
			n += 1
	return n


## UI 指标（旧版 :469 com_offset）：轮胎按 r² 加权的平均 xr − 0.5；正=偏后，负=偏前。
## 不写回质量/质心（契约 §2）。
func com_offset(ws: Array = []) -> float:
	var acc := 0.0
	var wsum := 0.0
	for w in (ws if not ws.is_empty() else wheels):
		var r: float = float(w.r)
		acc += r * r * float(w.xr)
		wsum += r * r
	if wsum <= 0.0:
		return 0.0
	return acc / wsum - 0.5


## ── 统一校验（缺口修补核心）：所有会改变布局或放行的路径都经过这里 ──

## 布局合法性（不含数量下限——下限属发车门槛）。返回 "" 合规，否则中文原因。
## 校验顺序与旧 add_wheel 一致：数量 → xr ∈ [0,1]（clamp 到 0.03–0.97）→ 半径 clamp+关卡上限
## → lateral ∈ [-1.4,1.4]（D1，缺省 0 兼容旧布局）→ 预算。
func validate_layout(ws: Array) -> String:
	if ws.size() > WHEEL_MAX:
		return "轮胎数量已达上限（%d）" % WHEEL_MAX
	for w in ws:
		var xr: float = float(w.xr)
		if xr < 0.0 or xr > 1.0:
			return "x_ratio 越界（0..1）"
		if absf(float(w.get("lateral", 0.0))) > LATERAL_MAX:
			return "lateral 越界（±%.1f m）" % LATERAL_MAX
	var cap: float = float(LEVELS[level_idx].max_r)
	for w in ws:
		if cap > 0.0 and clampf(float(w.r), R_MIN, R_MAX) > cap:
			return "轮胎超限：本关半径上限 %d" % int(cap)
	var budget := level_budget()
	if budget > 0.0:
		var s := area_sum(ws)
		if s > budget:
			return "超出轮胎总面积预算：Σπr²=%.0f > %d" % [s, int(budget)]
	return ""


## 发车门槛（旧版 can_launch/launch_block_reason :490-518 + 预算补查）。返回 {ok, reason}
func can_launch() -> Dictionary:
	var L: Dictionary = LEVELS[level_idx]
	if wheels.size() < int(L.min_wheels):
		return {ok = false, reason = "轮胎不足：本关至少 %d 个" % int(L.min_wheels)}
	if rear_count() < int(L.rear_min):
		return {ok = false, reason = "后轮不足：后半段至少 %d 个" % int(L.rear_min)}
	var err := validate_layout(wheels)   # 含 max_r 与预算（旧版漏查处，契约 §9-1）
	if err != "":
		return {ok = false, reason = err}
	return {ok = true, reason = ""}


## ── 变更入口（全部走 validate；失败不改动数据） ──

## 放轮胎：语义同旧 add_wheel :434——xr∈[0,1] 否则拒绝，接受后夹到 [0.03,0.97]；
## lateral（D1）∈[-1.4,1.4] 越界拒绝，缺省 0=中线；半径先夹全局 [12,30] 再查关卡上限；
## 预算超限拒绝。返回 {ok, reason, index}
func add_wheel(x_ratio: float, radius: float, lateral: float = 0.0) -> Dictionary:
	if wheels.size() >= WHEEL_MAX:
		return {ok = false, reason = "轮胎数量已达上限（%d）" % WHEEL_MAX, index = -1}
	if x_ratio < 0.0 or x_ratio > 1.0:
		return {ok = false, reason = "x_ratio 越界（0..1）", index = -1}
	if absf(lateral) > LATERAL_MAX:
		return {ok = false, reason = "lateral 越界（±%.1f m）" % LATERAL_MAX, index = -1}
	var r := clampf(radius, R_MIN, R_MAX)
	var cap: float = float(LEVELS[level_idx].max_r)
	if cap > 0.0 and r > cap:
		return {ok = false, reason = "轮胎超限：本关半径上限 %d" % int(cap), index = -1}
	var budget := level_budget()
	if budget > 0.0 and area_sum() + PI * r * r > budget:
		return {ok = false, reason = "超出轮胎总面积预算：Σπr²=%.0f > %d" % [area_sum() + PI * r * r, int(budget)], index = -1}
	var entry := {id = _next_id, xr = clampf(x_ratio, 0.03, 0.97), r = r, lateral = clampf(lateral, -LATERAL_MAX, LATERAL_MAX)}
	_next_id += 1
	wheels.append(entry)
	return {ok = true, reason = "", index = wheels.size() - 1}


## 调半径（对照旧 _adjust_radius :626 的滚轮语义）：半径按 clamp 收敛（超关卡上限自动夹回，
## 与旧版一致不拒绝）；但预算是硬约束——放大会导致超预算时拒绝并保留原半径（缺口修补）。
func set_radius(idx: int, radius: float) -> Dictionary:
	if idx < 0 or idx >= wheels.size():
		return {ok = false, reason = "无此轮胎", index = idx}
	var cap: float = float(LEVELS[level_idx].max_r)
	var hi := R_MAX if cap <= 0.0 else minf(R_MAX, cap)
	var nr := clampf(radius, R_MIN, hi)
	var budget := level_budget()
	if budget > 0.0:
		var test: Array = wheels.duplicate(true)
		test[idx].r = nr
		var s := area_sum(test)
		if s > budget:
			return {ok = false, reason = "超出轮胎总面积预算：Σπr²=%.0f > %d（已保留原半径）" % [s, int(budget)], index = idx}
	wheels[idx].r = nr
	return {ok = true, reason = "", index = idx}


func remove_wheel(idx: int) -> Dictionary:
	if idx < 0 or idx >= wheels.size():
		return {ok = false, reason = "无此轮胎", index = idx}
	wheels.remove_at(idx)
	return {ok = true, reason = "", index = -1}


func clear_wheels() -> void:
	wheels.clear()


## 恢复历史布局（对照旧 start_level restore :389-393）：先整体验证再替换，
## lateral 缺省 0 兼容旧布局记录；任何条目非法或超预算都整体拒绝且不改现有布局
## （旧版不校验直接复制，属缺口修补）。
func restore_layout(layout: Array) -> Dictionary:
	var ws: Array = []
	for w in layout:
		if not w.has("xr") or not w.has("r"):
			return {ok = false, reason = "恢复布局格式非法"}
		ws.append({id = 0, xr = float(w.xr), r = float(w.r), lateral = float(w.get("lateral", 0.0))})
	var err := validate_layout(ws)
	if err != "":
		return {ok = false, reason = "恢复布局校验失败：" + err}
	wheels.clear()
	for w in ws:
		wheels.append({id = _next_id, xr = clampf(float(w.xr), 0.03, 0.97), r = float(w.r), lateral = clampf(float(w.lateral), -LATERAL_MAX, LATERAL_MAX)})
		_next_id += 1
	return {ok = true, reason = "", index = -1}
