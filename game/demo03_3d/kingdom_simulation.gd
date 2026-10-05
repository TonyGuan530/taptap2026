class_name KingdomSimulation
extends RefCounted
## DEMO3 3D 迁移：经营模拟核心（规则与表现分离）。
## 逐项保留 2D demo03_kingdom.gd 的规则与更新次序：
## elapsed → 阶段/天气 → 降温 → 温度 → 收入 → 村民 → 胜负。
## 表现层通过 sim_event 信号与只读状态驱动，不得写回经济。

signal sim_event(kind: String, payload: Dictionary)

const GAME_TIME := 60.0
const START_HEAT := 40.0
const LOSE_HEAT := 100.0
const MAX_HEAT := 130.0
const BASE_INCOME := 5.0
const BUILD_COST := 20
const UPGRADE_COST := 40
const COOL_L1 := 2.0
const COOL_L2 := 5.0
const NPC_COOL := 0.8
const NPC_INCOME := 1.0
const NPC_TIMES: Array[float] = [20.0, 40.0]
const NPC_UP_COST := 30
const NPC_UP_COOL := 0.7
const NPC_X_MIN := 200.0
const NPC_X_MAX := 760.0
const ENGINEER_DISCOUNT := 5
const BOTANIST_COOL := 0.4
const PORTER_INCOME := 1.5
const METEOROLOGIST_HALVE := true
const ACID_WARN := 3.0
const ACID_TOWER_MULT := 0.6
const ACID_NPC_MULT := 1.5
const ACID_TIMES: Array[float] = [22.0, 46.0]
const ACID_JITTER := 3.0
const ACID_DUR := 8.0
const STORM_TIMES: Array[float] = [15.0, 30.0, 45.0]
const STORM_JITTER := 2.0
const STORM_DUR := 4.0
## v11 风暴限定天气「热浪」：38~43s 升温 ×1.5（只乘升温，不动降温乘区；
## 窗口取在第三场酸雨 45±2 之前，永不重叠）
const HEATWAVE_START := 38.0
const HEATWAVE_DUR := 5.0
const HEATWAVE_MULT := 1.5
## v13 岩浆涌潮（FB-102：岩浆主题回归+玩法扩展）：岩浆向村庄推进 + 窗口内升温加成。
## 时刻表按模式错开酸雨窗（classic 34~42 在 30~46 空档；storm 52~58 在 45±2+4 之后；hard 40~46 在 34+6 与 48±2.5 之间）；
## jitter=0 完全可测。加成只乘升温，不动降温乘区。回应"会玩局终局零压力"（balance-sweep 发现 2）。
const SURGE_RISE := 1.2
const SURGE_WARN := 3.0
const SURGE_SCHEDULE: Array[Dictionary] = [
	{"mode": "classic", "start": 34.0, "dur": 8.0},
	{"mode": "storm", "start": 52.0, "dur": 6.0},
	{"mode": "hard", "start": 27.0, "dur": 4.0},
]
## v6 第 2 章「寒夜守卫」（hard）：起始 50 度、三场 6s 酸雨、村民 30/50s 才来。
## 经济/建造/晋升/曲线与经典完全一致——难在资源更紧、人手更晚。
const HARD_START_HEAT := 50.0
const HARD_ACID_TIMES: Array[float] = [18.0, 34.0, 48.0]
const HARD_ACID_JITTER := 2.5
const HARD_ACID_DUR := 6.0
const HARD_NPC_TIMES: Array[float] = [30.0, 50.0]
## v4 灭火指挥：花水滴发起 8s 全队应急降温，冷却 20s。
## 刻意不吃酸雨乘区（塔 ×0.6 / 村民 ×1.5 都不影响它）——酸雨里的可靠工具，
## 与"水滴拿去建设还是留着急救"构成资源竞争决策。
const CMD_COST := 25
const CMD_DUR := 8.0
const CMD_CD := 20.0
const CMD_COOL := 1.5
## v10 蓄水池：60 水滴大投资，4.5/s 强降温；酸雨期间完全失效（蒸发）。
## 与水塔（酸雨 ×0.6）形成风险对比：便宜皮实 vs 贵而怕酸，丰富开局投资决策。
const RESERVOIR_COST := 60
const RESERVOIR_COOL := 4.5
## 五阶段升温曲线（t 为本局总 elapsed）
const PHASES: Array[Dictionary] = [
	{"until": 12.0, "base": 1.8, "slope": 0.035, "name": "初火", "col": "aed581"},
	{"until": 25.0, "base": 2.2, "slope": 0.045, "name": "干热风", "col": "ffd54f"},
	{"until": 38.0, "base": 2.7, "slope": 0.055, "name": "裂地脉动", "col": "ffb74d"},
	{"until": 50.0, "base": 3.1, "slope": 0.07, "name": "岩浆涌潮", "col": "ff8a65"},
	{"until": 999.0, "base": 3.5, "slope": 0.09, "name": "灭亡倒计时", "col": "ef5350"},
]
const PROFS: Array[Dictionary] = [
	{"name": "工程师", "discount": 5, "cool_bonus": 0.0, "income_bonus": 0.0},
	{"name": "植物学家", "discount": 0, "cool_bonus": 0.4, "income_bonus": 0.0},
	{"name": "气象学家", "discount": 0, "cool_bonus": 0.0, "income_bonus": 0.0, "halve_acid": true},
	{"name": "搬运工", "discount": 0, "cool_bonus": 0.0, "income_bonus": 1.5},
]
const NPC_NAMES: Array[String] = ["阿岩", "小露", "阿灰", "石头婶", "水生"]

var rng := RandomNumberGenerator.new()
var mode := "classic"
var round_state := "menu"   # menu / play / win / lose
var heat := START_HEAT
var npc_times: Array[float] = NPC_TIMES   # 本局村民到点（hard 章节改用 HARD_NPC_TIMES）
var water := 0.0
var elapsed := 0.0
var towers: Array[int] = [0, 0, 0]
var reservoir := 0   # v10 蓄水池 0/1
var villagers: Array[Dictionary] = []   # {id, name, prof, level, x}
var npc_next := 0
var acid_events: Array[Dictionary] = [] # {start, dur, announced, warned}
var acid_was_on := false
var heatwave_was_on := false
var surge_was_on := false
var surge_warned := false
var spend_log: Array[Dictionary] = []   # {t, kind, amount}
var villager_seq := 0
var cmd_until := -1.0   # 灭火指挥生效窗截止（sim elapsed）
var cmd_ready_at := 0.0 # 冷却结束时刻
var cmd_was_on := false


func setup_round(p_mode: String, seed_value: int = -1) -> void:
	mode = p_mode
	round_state = "play"
	heat = HARD_START_HEAT if p_mode == "hard" else START_HEAT
	npc_times = HARD_NPC_TIMES if p_mode == "hard" else NPC_TIMES
	water = 0.0
	elapsed = 0.0
	towers = [0, 0, 0]
	reservoir = 0
	villagers = []
	npc_next = 0
	spend_log = []
	acid_was_on = false
	villager_seq = 0
	cmd_until = -1.0
	cmd_ready_at = 0.0
	cmd_was_on = false
	heatwave_was_on = false
	surge_was_on = false
	surge_warned = false
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var times: Array = ACID_TIMES
	var jitter: float = ACID_JITTER
	var dur: float = ACID_DUR
	if mode == "storm":
		times = STORM_TIMES
		jitter = STORM_JITTER
		dur = STORM_DUR
	elif mode == "hard":
		times = HARD_ACID_TIMES
		jitter = HARD_ACID_JITTER
		dur = HARD_ACID_DUR
	acid_events = []
	for at: float in times:
		acid_events.append({
			"start": at + rng.randf_range(-jitter, jitter),
			"dur": dur,
			"announced": false,
			"warned": false,
		})


func prof_info(prof_name: String) -> Dictionary:
	for p: Dictionary in PROFS:
		if p.name == prof_name:
			return p
	return {}


func has_prof(prof_name: String) -> bool:
	for n: Dictionary in villagers:
		if n.prof == prof_name:
			return true
	return false


## 气象学家在场时酸雨有效时长减半（动态判定）
func acid_active() -> bool:
	return acid_at(elapsed)


## 任意时刻是否处于酸雨（结算遥测/复盘用；与 acid_active 同规则）
func acid_at(t: float) -> bool:
	for e: Dictionary in acid_events:
		var dur_eff: float = float(e.dur) * (0.5 if has_prof("气象学家") else 1.0)
		if t >= float(e.start) and t < float(e.start) + dur_eff:
			return true
	return false


## v11 热浪：仅风暴模式，38~43s（半开区间）
func heatwave_active() -> bool:
	return mode == "storm" and elapsed >= HEATWAVE_START and elapsed < HEATWAVE_START + HEATWAVE_DUR


## v13 岩浆涌潮：本模式排定的 [start,dur]（无则不在）
func surge_window() -> Dictionary:
	for w: Dictionary in SURGE_SCHEDULE:
		if w.mode == mode:
			return w
	return {}


func surge_active() -> bool:
	var w := surge_window()
	return not w.is_empty() and elapsed >= float(w.start) and elapsed < float(w.start) + float(w.dur)


func build_cost() -> int:
	return BUILD_COST - (ENGINEER_DISCOUNT if has_prof("工程师") else 0)


func upgrade_cost() -> int:
	return UPGRADE_COST - (ENGINEER_DISCOUNT if has_prof("工程师") else 0)


func phase() -> Dictionary:
	for p: Dictionary in PHASES:
		if elapsed < float(p.until):
			return p
	return PHASES[PHASES.size() - 1]


func npc_cool_total() -> float:
	var total := 0.0
	for n: Dictionary in villagers:
		total += NPC_COOL + float(prof_info(n.prof).cool_bonus) + float(n.level) * NPC_UP_COOL
	return total


func income_per_sec() -> float:
	var income := BASE_INCOME
	for n: Dictionary in villagers:
		income += NPC_INCOME + float(prof_info(n.prof).income_bonus)
	return income


## 资金不足/状态不对/目标非法 → false 且不产生消费记录
func try_build(slot: int) -> bool:
	if round_state != "play" or slot < 0 or slot >= towers.size() or towers[slot] != 0:
		return false
	var c := build_cost()
	if water < float(c):
		return false
	water -= float(c)
	towers[slot] = 1
	spend_log.append({"t": elapsed, "kind": "build", "amount": c, "target": slot})
	sim_event.emit("built", {"slot": slot, "level": 1})
	return true


func try_upgrade(slot: int) -> bool:
	if round_state != "play" or slot < 0 or slot >= towers.size() or towers[slot] != 1:
		return false
	var c := upgrade_cost()
	if water < float(c):
		return false
	water -= float(c)
	towers[slot] = 2
	spend_log.append({"t": elapsed, "kind": "upgrade", "amount": c, "target": slot})
	sim_event.emit("upgraded", {"slot": slot, "level": 2})
	return true


func try_promote(villager_id: int) -> bool:
	if round_state != "play":
		return false
	for n: Dictionary in villagers:
		if n.id == villager_id:
			if n.level >= 1 or water < float(NPC_UP_COST):
				return false
			water -= float(NPC_UP_COST)
			n.level = 1
			spend_log.append({"t": elapsed, "kind": "promote", "amount": NPC_UP_COST, "target": villager_id})
			sim_event.emit("promoted", {"id": villager_id})
			return true
	return false


func cmd_active() -> bool:
	return elapsed < cmd_until


func cmd_ready() -> bool:
	return elapsed >= cmd_ready_at


## 灭火指挥（v4）：紧急把 25 水滴换成 8 秒全队 +1.5/s 降温。
## 与建造/升级共享水滴池；非 play/冷却中/水不足 → false 且无消费记录。
func try_command() -> bool:
	if round_state != "play":
		return false
	if not cmd_ready() or water < float(CMD_COST):
		return false
	water -= float(CMD_COST)
	cmd_until = elapsed + CMD_DUR
	cmd_ready_at = elapsed + CMD_CD
	spend_log.append({"t": elapsed, "kind": "command", "amount": CMD_COST, "target": -1})
	sim_event.emit("command_started", {"until": cmd_until})
	return true


## 蓄水池（v10）：一次性大投资，酸雨时完全失效；非 play/已建/水不足 → false 且无消费记录
func try_build_reservoir() -> bool:
	if round_state != "play" or reservoir != 0:
		return false
	if water < float(RESERVOIR_COST):
		return false
	water -= float(RESERVOIR_COST)
	reservoir = 1
	spend_log.append({"t": elapsed, "kind": "reservoir", "amount": RESERVOIR_COST, "target": -2})
	sim_event.emit("reservoir_built", {})
	return true


## 逐帧推进：次序与 2D 一致（elapsed → 阶段/天气 → 降温 → 温度 → 收入 → 村民 → 胜负）
func tick(delta: float) -> void:
	if round_state != "play":
		return
	elapsed += delta
	var ph := phase()
	var rise: float = float(ph.base) + float(ph.slope) * elapsed
	var hw_on := heatwave_active()
	if hw_on and not heatwave_was_on:
		sim_event.emit("heatwave_started", {"until": elapsed + HEATWAVE_DUR})
	elif not hw_on and heatwave_was_on:
		sim_event.emit("heatwave_ended", {"at": elapsed})
	heatwave_was_on = hw_on
	if hw_on:
		rise *= HEATWAVE_MULT
	# v13 涌潮：预警（提前 3s 一次）→ 窗口内 rise 直加 SURGE_RISE；结束回落
	var sw := surge_window()
	var surge_on := not sw.is_empty() and elapsed >= float(sw.start) and elapsed < float(sw.start) + float(sw.dur)
	if not surge_warned and not sw.is_empty() and elapsed >= float(sw.start) - SURGE_WARN and elapsed < float(sw.start):
		surge_warned = true
		sim_event.emit("surge_warn", {"start": float(sw.start)})
	if surge_on and not surge_was_on:
		sim_event.emit("surge_started", {"until": elapsed + float(sw.dur)})
	elif not surge_on and surge_was_on:
		sim_event.emit("surge_ended", {"at": elapsed})
	surge_was_on = surge_on
	if surge_on:
		rise += SURGE_RISE
	var acid_now := acid_active()
	for e: Dictionary in acid_events:
		if not e.warned and elapsed >= float(e.start) - ACID_WARN and elapsed < float(e.start):
			e.warned = true
			sim_event.emit("acid_warn", {"start": float(e.start)})
		if not e.announced and elapsed >= float(e.start):
			e.announced = true
			sim_event.emit("acid_started", {"start": float(e.start)})
			break
	if acid_was_on and not acid_now:
		sim_event.emit("acid_ended", {"at": elapsed})
	acid_was_on = acid_now
	var cmd_on := cmd_active()
	if cmd_was_on and not cmd_on:
		sim_event.emit("command_ended", {"at": elapsed})
	cmd_was_on = cmd_on
	var tower_cool := 0.0
	for t: int in towers:
		tower_cool += COOL_L1 if t == 1 else (COOL_L2 if t == 2 else 0.0)
	var npc_cool := npc_cool_total()
	# 灭火指挥 +1.5 固定直加，不进酸雨乘区（酸雨中的可靠工具是它的定位）
	var cmd_bonus := CMD_COOL if cmd_on else 0.0
	# 蓄水池 4.5 平时直加；酸雨期间完全失效（不是乘 0.6，是 0）
	var res_cool := RESERVOIR_COOL if reservoir == 1 and not acid_now else 0.0
	var cool: float = tower_cool * (ACID_TOWER_MULT if acid_now else 1.0) \
			+ npc_cool * (ACID_NPC_MULT if acid_now else 1.0) + cmd_bonus + res_cool
	heat = clampf(heat + (rise - cool) * delta, 0.0, MAX_HEAT)
	water += income_per_sec() * delta
	if npc_next < npc_times.size() and elapsed >= float(npc_times[npc_next]):
		var prof: Dictionary = PROFS[rng.randi_range(0, PROFS.size() - 1)]
		villager_seq += 1
		villagers.append({
			"id": villager_seq,
			"name": NPC_NAMES[npc_next % NPC_NAMES.size()],
			"prof": prof.name,
			"level": 0,
			"x": rng.randf_range(NPC_X_MIN, NPC_X_MAX),
		})
		sim_event.emit("villager_joined", {"id": villager_seq, "prof": prof.name})
		npc_next += 1
	if heat >= LOSE_HEAT:
		round_state = "lose"
		sim_event.emit("round_ended", {"win": false, "heat": heat, "elapsed": elapsed})
	elif elapsed >= GAME_TIME:
		round_state = "win"
		sim_event.emit("round_ended", {"win": true, "heat": heat, "elapsed": elapsed})
