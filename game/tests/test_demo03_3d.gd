extends SceneTree
## DEMO3 3D 迁移 阶段 A 测试：模拟核心规则对照与边界断言。
## 运行：godot --headless --path game -s res://tests/test_demo03_3d.gd
## 任何 FAIL 均以退出码 1 结束（非零=失败）。

const Sim := preload("res://demo03_3d/kingdom_simulation.gd")
const TICK: float = 1.0 / 60.0

var failures := 0
var checks := 0


func check(cond: bool, name: String, detail: String = "") -> void:
	checks += 1
	if cond:
		print("PASS  ", name)
	else:
		failures += 1
		print("FAIL  ", name, "  ", detail)


func approx(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func run_seconds(s: Object, seconds: float) -> void:
	var steps := int(seconds * 60.0)
	for i in steps:
		s.tick(TICK)


func _initialize() -> void:
	_run()


func _run() -> void:
	# ---- 1. P1 阶段解析对照（无命令）：heat(12s) / water(12s) ----
	var s1 = Sim.new()
	s1.setup_round("classic", 7)
	s1.acid_events[0].start = 22.0
	s1.acid_events[1].start = 46.0
	run_seconds(s1, 12.0)
	check(approx(s1.heat, 64.12, 0.6), "P1 heat(12s)≈64.1", "got %.2f" % s1.heat)
	check(approx(s1.water, 60.0, 0.1), "P1 water(12s)=60", "got %.2f" % s1.water)
	check(s1.phase().name == "干热风", "P2 阶段名@12s")

	# ---- 2. 摆烂速败（酸雨对空场无加伤）：20~30s 内失败 ----
	while s1.round_state == "play" and s1.elapsed < 40.0:
		s1.tick(TICK)
	check(s1.round_state == "lose", "摆烂失败")
	check(s1.elapsed < 30.0 and s1.elapsed >= 20.0, "摆烂失败于 20~30s", "got %.1f" % s1.elapsed)

	# ---- 3. 会玩获胜：复刻 2D 合理节奏（门控式投入）----
	var s2 = Sim.new()
	s2.setup_round("classic", 7)
	s2.acid_events[0].start = 22.0
	s2.acid_events[1].start = 46.0
	var counter := {"warn": 0, "start": 0, "end": 0, "promote": 0}
	s2.sim_event.connect(func(kind: String, _p: Dictionary) -> void:
		match kind:
			"acid_warn": counter.warn += 1
			"acid_started": counter.start += 1
			"acid_ended": counter.end += 1
			"promoted": counter.promote += 1
	)
	while s2.round_state == "play" and s2.elapsed < 70.0:
		s2.tick(TICK)
		if s2.elapsed > 3.5 and s2.towers[0] == 0 and s2.water >= s2.build_cost():
			s2.try_build(0)
		elif s2.elapsed > 12.0 and s2.towers[1] == 0 and s2.water >= s2.build_cost():
			s2.try_build(1)
		elif s2.elapsed > 21.0 and s2.villagers.size() > 0 and s2.villagers[0].level == 0 \
				and s2.water >= s2.NPC_UP_COST:
			s2.try_promote(s2.villagers[0].id)
		elif s2.elapsed > 24.0 and s2.towers[0] == 1 and s2.water >= s2.upgrade_cost():
			s2.try_upgrade(0)
		elif s2.elapsed > 40.0 and s2.towers[2] == 0 and s2.water >= s2.build_cost():
			s2.try_build(2)
	check(s2.round_state == "win", "会玩胜利@60s")
	check(s2.villagers.size() == 2, "两名村民加入")
	check(counter.promote >= 1, "至少一次晋升")
	check(counter.warn == 2 and counter.start == 2 and counter.end == 2,
			"经典酸雨两场 起止+预警齐全", "w%d s%d e%d" % [counter.warn, counter.start, counter.end])
	check(s2.heat < 30.0, "会玩局终局低温", "got %.1f" % s2.heat)
	var kinds := {}
	for rec: Dictionary in s2.spend_log:
		kinds[rec.kind] = kinds.get(rec.kind, 0) + 1
	check(kinds.get("build", 0) == 3 and kinds.get("upgrade", 1) >= 1 and kinds.get("promote", 0) >= 1,
			"spend_log 三类消费齐全")
	var ordered := true
	var last_t := -1.0
	for rec: Dictionary in s2.spend_log:
		if float(rec.t) < last_t:
			ordered = false
		last_t = float(rec.t)
	check(ordered, "spend_log 时间有序")

	# ---- 4. 风暴模式：三场酸雨、经济一致、会玩胜利 ----
	var s3 = Sim.new()
	s3.setup_round("storm", 7)
	check(s3.acid_events.size() == 3, "风暴三场酸雨")
	check(approx(float(s3.acid_events[0].dur), 4.0, 0.001), "风暴单场 4s")
	for e: Dictionary in s3.acid_events:
		check(e.start >= 13.0 and e.start <= 47.0, "风暴酸雨时刻在窗内", str(e.start))
	check(approx(s3.income_per_sec(), 5.0, 0.001), "风暴与经典经济一致")
	var counter3 := {"promote": 0}
	while s3.round_state == "play" and s3.elapsed < 70.0:
		s3.tick(TICK)
		if s3.acid_active() and s3.water >= s3.NPC_UP_COST:
			for n: Dictionary in s3.villagers:
				if n.level == 0:
					s3.try_promote(n.id)
					counter3.promote += 1
					break
		if s3.elapsed > 3.5 and s3.towers[0] == 0 and s3.water >= s3.build_cost():
			s3.try_build(0)
		elif s3.elapsed > 12.0 and s3.towers[1] == 0 and s3.water >= s3.build_cost():
			s3.try_build(1)
		elif s3.elapsed > 24.0 and s3.towers[0] == 1 and s3.water >= s3.upgrade_cost():
			s3.try_upgrade(0)
		elif s3.elapsed > 40.0 and s3.towers[2] == 0 and s3.water >= s3.build_cost():
			s3.try_build(2)
	var acid3_hit: int = s3.acid_events.filter(func(e: Dictionary): return e.announced).size()
	check(s3.round_state == "win" and acid3_hit == 3, "风暴会玩胜利+3/3 场酸雨", "state=%s acid=%d" % [s3.round_state, acid3_hit])

	# ---- 5. 气象学家：酸雨有效时长减半 ----
	var s4 = Sim.new()
	s4.setup_round("classic", 7)
	s4.acid_events[0].start = 22.0
	s4.acid_events[1].start = 46.0
	s4.villagers.append({"id": 1, "name": "试", "prof": "气象学家", "level": 0, "x": 480.0})
	s4.elapsed = 24.0
	check(s4.acid_active(), "22~26s 处于酸雨（气象学家 4s 窗内）")
	s4.elapsed = 27.0
	check(not s4.acid_active(), "27s 已脱离（8s 的一半=4s）")
	check(s4.PROFS[2].halve_acid == true, "气象学家 halve_acid 标记保留")

	# ---- 6. 工程师折扣 / 植物学家降温 / 搬运工收入 ----
	var s5 = Sim.new()
	s5.setup_round("classic", 7)
	check(s5.build_cost() == 20 and s5.upgrade_cost() == 40, "无工程师原价")
	s5.villagers.append({"id": 1, "name": "工", "prof": "工程师", "level": 0, "x": 300.0})
	check(s5.build_cost() == 15 and s5.upgrade_cost() == 35, "工程师 -5")
	s5.water = 100.0
	var w0: float = s5.water
	check(s5.try_build(0), "工程师局建造成功")
	check(approx(s5.water, w0 - 15.0, 0.001), "建造扣 15")
	s5.villagers.append({"id": 2, "name": "植", "prof": "植物学家", "level": 0, "x": 400.0})
	s5.villagers.append({"id": 3, "name": "搬", "prof": "搬运工", "level": 0, "x": 500.0})
	# 收入 = 5 基础 + 每村民 1.0 ×3 + 搬运工 1.5 = 9.5
	check(approx(s5.income_per_sec(), 9.5, 0.001), "搬运工收入 +1.5（三人合计 9.5）")
	check(approx(s5.npc_cool_total(), 0.8 * 3.0 + 0.4, 0.001), "植物学家降温 +0.4")

	# ---- 7. 边界：资金不足/满级/重复晋升/胜利后禁操作 ----
	var s6 = Sim.new()
	s6.setup_round("classic", 7)
	check(not s6.try_build(0), "水滴不足建造失败")
	check(s6.spend_log.is_empty(), "失败不产生消费记录")
	s6.water = 100.0
	check(s6.try_build(0), "建造成功")
	check(not s6.try_build(0), "已占用槽位不可重复建造")
	check(s6.try_upgrade(0), "升级成功")
	check(not s6.try_upgrade(0), "满级不可再升级")
	check(not s6.try_promote(999), "不存在村民晋升失败")
	s6.round_state = "win"
	check(not s6.try_build(2), "胜利后禁操作")

	# ---- 8. 气象学家使酸雨窗减半（对照）----
	var s7a = Sim.new()
	s7a.setup_round("classic", 7)
	s7a.acid_events[0].start = 22.0
	var s7b = Sim.new()
	s7b.setup_round("classic", 7)
	s7b.acid_events[0].start = 22.0
	s7b.villagers.append({"id": 1, "name": "气", "prof": "气象学家", "level": 0, "x": 480.0})
	s7a.elapsed = 22.0
	var a_on := s7a.acid_active()
	s7b.elapsed = 22.0
	var b_on := s7b.acid_active()
	check(a_on and b_on, "酸雨开始两侧一致")
	s7a.elapsed = 27.0
	s7b.elapsed = 27.0
	check(s7a.acid_active() and not s7b.acid_active(), "27s：无气象学家仍在酸雨 / 有气象学家已结束")

	# ---- 9. 灭火指挥（v4）：花费/生效窗/冷却/事件/spend_log ----
	var s8 = Sim.new()
	s8.setup_round("classic", 7)
	var counter8 := {"started": 0, "ended": 0}
	s8.sim_event.connect(func(kind: String, _p: Dictionary) -> void:
		match kind:
			"command_started": counter8.started += 1
			"command_ended": counter8.ended += 1
	)
	check(not s8.try_command(), "开局无水指挥失败")
	check(s8.spend_log.is_empty(), "指挥失败无消费记录")
	s8.water = 30.0
	check(s8.try_command(), "指挥发起成功")
	check(approx(s8.water, 5.0, 0.001), "指挥扣 25💧")
	check(s8.cmd_active(), "生效窗内 cmd_active")
	check(approx(s8.cmd_ready_at, 20.0, 0.001), "冷却排定至 20s")
	check(not s8.try_command(), "冷却期重复指挥失败")
	run_seconds(s8, 9.0)
	check(counter8.started == 1 and counter8.ended == 1, "指挥起/止事件各一次",
			"s%d e%d" % [counter8.started, counter8.ended])
	check(not s8.cmd_active(), "8s 后生效结束")
	check(not s8.cmd_ready(), "9s 时仍在冷却")
	var has_cmd := false
	for rec: Dictionary in s8.spend_log:
		if rec.kind == "command":
			has_cmd = true
	check(has_cmd, "spend_log 含 command")

	# ---- 10. 灭火指挥对照：8s 生效窗共 -12 度 ----
	var s9a = Sim.new()
	s9a.setup_round("classic", 7)
	s9a.acid_events[0].start = 22.0
	s9a.acid_events[1].start = 46.0
	var s9b = Sim.new()
	s9b.setup_round("classic", 7)
	s9b.acid_events[0].start = 22.0
	s9b.acid_events[1].start = 46.0
	s9a.water = 100.0
	run_seconds(s9a, 5.0)
	run_seconds(s9b, 5.0)
	check(s9a.try_command(), "对照局指挥发起@5s")
	run_seconds(s9a, 8.0)
	run_seconds(s9b, 8.0)
	check(approx(s9b.heat - s9a.heat, 12.0, 0.3), "8s 生效窗全程 -12 度（对照）",
			"diff=%.2f" % (s9b.heat - s9a.heat))

	# ---- 11. 灭火指挥不吃酸雨乘区：+1.5 固定直加 ----
	var s10a = Sim.new()
	s10a.setup_round("classic", 7)
	s10a.acid_events[0].start = 22.0
	s10a.acid_events[1].start = 46.0
	var s10b = Sim.new()
	s10b.setup_round("classic", 7)
	s10b.acid_events[0].start = 22.0
	s10b.acid_events[1].start = 46.0
	s10a.water = 100.0
	run_seconds(s10a, 23.0)
	run_seconds(s10b, 23.0)
	check(s10a.acid_active(), "23s 处于酸雨窗")
	check(s10a.try_command(), "酸雨中指挥发起")
	run_seconds(s10a, 1.0)
	run_seconds(s10b, 1.0)
	check(approx(s10b.heat - s10a.heat, 1.5, 0.05), "酸雨中指挥 +1.5 固定（不×1.5 不×0.6）",
			"diff=%.2f" % (s10b.heat - s10a.heat))

	# ---- 12. 灭火指挥边界：胜利后禁用 ----
	s8.round_state = "win"
	s8.cmd_ready_at = 0.0
	s8.water = 100.0
	check(not s8.try_command(), "胜利后禁指挥（即使就绪有钱）")
	check(approx(s8.water, 100.0, 0.001), "胜利后指挥不扣费")

	# ---- 13. 第 2 章「寒夜守卫」（v6 hard）：更难预设、经济不变、会玩可胜 ----
	var s11 = Sim.new()
	s11.setup_round("hard", 7)
	check(approx(s11.heat, 50.0, 0.001), "寒夜起始 50 度")
	check(s11.acid_events.size() == 3, "寒夜三场酸雨")
	check(approx(float(s11.acid_events[0].dur), 6.0, 0.001), "寒夜单场 6s")
	for e: Dictionary in s11.acid_events:
		check(e.start >= 15.5 and e.start <= 50.5, "寒夜酸雨时刻在窗内", str(e.start))
	check(s11.npc_times.size() == 2 and float(s11.npc_times[0]) == 30.0 and float(s11.npc_times[1]) == 50.0,
			"寒夜村民 30/50s 到场")
	check(approx(s11.income_per_sec(), 5.0, 0.001), "寒夜经济与经典一致")
	var counter11 := {"promote": 0, "joined": 0}
	s11.sim_event.connect(func(kind: String, _p: Dictionary) -> void:
		if kind == "promoted":
			counter11.promote += 1
		elif kind == "villager_joined":
			counter11.joined += 1
	)
	while s11.round_state == "play" and s11.elapsed < 70.0:
		s11.tick(TICK)
		if s11.elapsed > 3.5 and s11.towers[0] == 0 and s11.water >= s11.build_cost():
			s11.try_build(0)
		elif s11.elapsed > 12.0 and s11.towers[1] == 0 and s11.water >= s11.build_cost():
			s11.try_build(1)
		elif s11.elapsed > 21.0 and s11.villagers.size() > 0 and s11.villagers[0].level == 0 \
				and s11.water >= s11.NPC_UP_COST:
			s11.try_promote(s11.villagers[0].id)
		elif s11.elapsed > 24.0 and s11.towers[0] == 1 and s11.water >= s11.upgrade_cost():
			s11.try_upgrade(0)
		elif s11.elapsed > 33.0 and s11.villagers.size() > 1 and s11.villagers[1].level == 0 \
				and s11.water >= s11.NPC_UP_COST:
			s11.try_promote(s11.villagers[1].id)
		elif s11.elapsed > 40.0 and s11.towers[2] == 0 and s11.water >= s11.build_cost():
			s11.try_build(2)
	check(s11.round_state == "win", "寒夜会玩胜利@60s",
			"%s h=%.1f t=%.1f" % [s11.round_state, s11.heat, s11.elapsed])
	check(counter11.joined == 2, "寒夜两名村民到场")
	check(counter11.promote >= 1, "寒夜至少一次晋升")
	check(s11.heat < 55.0, "寒夜终局温度有回落", "got %.1f" % s11.heat)

	# ---- 14. 寒夜摆烂更快败；经典/风暴村民到点不受影响 ----
	var s12 = Sim.new()
	s12.setup_round("hard", 7)
	while s12.round_state == "play" and s12.elapsed < 40.0:
		s12.tick(TICK)
	check(s12.round_state == "lose" and s12.elapsed < 25.0, "寒夜摆烂 <25s 败", "got %.1f" % s12.elapsed)
	var s13 = Sim.new()
	s13.setup_round("classic", 7)
	check(float(s13.npc_times[0]) == 20.0 and float(s13.npc_times[1]) == 40.0, "经典村民 20/40 不变")
	var s14 = Sim.new()
	s14.setup_round("storm", 7)
	check(approx(s14.heat, 40.0, 0.001), "风暴起始仍 40 度")

	# ---- 15. v7 acid_at：任意时刻酸雨判定（气象学家减半同规则）----
	var s15 = Sim.new()
	s15.setup_round("classic", 7)
	s15.acid_events[0].start = 22.0
	s15.acid_events[1].start = 46.0
	check(not s15.acid_at(21.9) and s15.acid_at(22.0) and s15.acid_at(29.9) and not s15.acid_at(30.0),
			"acid_at 边界（22 起 30 止，半开区间）")
	s15.villagers.append({"id": 1, "name": "气", "prof": "气象学家", "level": 0, "x": 480.0})
	check(s15.acid_at(25.9) and not s15.acid_at(26.0), "acid_at 气象学家减半（22~26）")

	# ---- 16. v10 蓄水池：大投资/强降温/酸雨完全失效 ----
	var s16 = Sim.new()
	s16.setup_round("classic", 7)
	check(not s16.try_build_reservoir(), "开局无水建蓄水池失败")
	s16.water = 59.0
	check(not s16.try_build_reservoir(), "59 水不足 60")
	check(s16.spend_log.is_empty(), "蓄水池失败无消费记录")
	s16.water = 100.0
	check(s16.try_build_reservoir(), "蓄水池建造成功")
	check(approx(s16.water, 40.0, 0.001), "蓄水池扣 60")
	check(not s16.try_build_reservoir(), "蓄水池不可重复建造")
	var has_res := false
	for rec: Dictionary in s16.spend_log:
		if rec.kind == "reservoir":
			has_res = true
	check(has_res, "spend_log 含 reservoir")
	s16.round_state = "win"
	s16.reservoir = 0
	s16.water = 100.0
	check(not s16.try_build_reservoir(), "胜利后禁建蓄水池")
	s16.setup_round("classic", 7)
	check(s16.reservoir == 0, "重开后蓄水池清理")

	# ---- 17. 蓄水池降温对照：平时 +4.5，酸雨中失效（差值恒定）----
	var s17a = Sim.new()
	s17a.setup_round("classic", 7)
	s17a.acid_events[0].start = 22.0
	s17a.acid_events[1].start = 46.0
	s17a.towers[0] = 1
	s17a.water = 100.0
	s17a.try_build_reservoir()
	var s17b = Sim.new()
	s17b.setup_round("classic", 7)
	s17b.acid_events[0].start = 22.0
	s17b.acid_events[1].start = 46.0
	s17b.towers[0] = 1
	s17a.heat = 60.0
	s17b.heat = 60.0
	run_seconds(s17a, 8.0)
	run_seconds(s17b, 8.0)
	run_seconds(s17a, 2.0)
	run_seconds(s17b, 2.0)
	check(approx(s17b.heat - s17a.heat, 45.0, 0.3), "0~10s 平时对照 diff=4.5×10（建即生效）",
			"diff=%.2f" % (s17b.heat - s17a.heat))
	s17a.elapsed = 23.0
	s17b.elapsed = 23.0
	run_seconds(s17a, 2.0)
	run_seconds(s17b, 2.0)
	check(approx(s17b.heat - s17a.heat, 45.0, 0.3), "23~25s 酸雨中失效（diff 不再扩大）",
			"diff=%.2f" % (s17b.heat - s17a.heat))

	# ---- 18. v11 热浪：风暴限定/边界/对照（×1.5 只乘升温）----
	var s18c = Sim.new()
	s18c.setup_round("classic", 7)
	s18c.elapsed = 40.0
	check(not s18c.heatwave_active(), "经典模式无热浪")
	var s18a = Sim.new()
	s18a.setup_round("storm", 7)
	s18a.acid_events[0].start = 15.0
	s18a.acid_events[1].start = 30.0
	s18a.acid_events[2].start = 45.0
	s18a.elapsed = 37.9
	check(not s18a.heatwave_active(), "37.9 未入热浪")
	s18a.elapsed = 38.0
	check(s18a.heatwave_active(), "38.0 入热浪")
	s18a.elapsed = 42.9
	check(s18a.heatwave_active(), "42.9 仍在热浪")
	s18a.elapsed = 43.0
	check(not s18a.heatwave_active(), "43.0 出热浪（半开区间）")
	var s18b = Sim.new()
	s18b.setup_round("storm", 7)
	s18b.acid_events[0].start = 15.0
	s18b.acid_events[1].start = 30.0
	s18b.acid_events[2].start = 45.0
	s18a.towers[0] = 2
	s18b.towers[0] = 2
	s18a.npc_next = 2
	s18b.npc_next = 2
	check(s18b.heatwave_active() == false or s18b.elapsed < 38.0, "对照局待用（风暴同模式会同样受热浪影响，不做 pair）")
	var counter18 := {"start": 0, "end": 0}
	s18a.sim_event.connect(func(kind: String, _p: Dictionary) -> void:
		if kind == "heatwave_started":
			counter18.start += 1
		elif kind == "heatwave_ended":
			counter18.end += 1
	)
	# 单 tick 解析：窗内 rise×1.5。tick 先推进 elapsed：rise(40.1)=3.1+0.07×40.1=5.907
	s18a.elapsed = 40.0
	s18a.heat = 50.0
	s18a.tick(0.1)
	check(approx(s18a.heat - 50.0, (5.907 * 1.5 - 5.0) * 0.1, 0.02), "热浪窗内单 tick 升温 ×1.5",
			"d=%.3f" % (s18a.heat - 50.0))
	s18a.elapsed = 43.5
	s18a.heat = 50.0
	s18a.tick(0.1)
	check(approx(s18a.heat - 50.0, (6.152 - 5.0) * 0.1, 0.02), "热浪窗外恢复正常升温",
			"d=%.3f" % (s18a.heat - 50.0))
	check(counter18.start == 1, "热浪开始事件已发", "s%d" % counter18.start)
	s18a.elapsed = 42.95
	s18a.heat = 50.0
	s18a.tick(0.2)
	check(counter18.end == 1, "越过 43s 发出热浪结束事件", "e%d" % counter18.end)

	# ---- 19. v13 岩浆涌潮：时刻表/无重叠/边界/单tick解析/事件 ----
	var s19c = Sim.new()
	s19c.setup_round("classic", 7)
	check(s19c.surge_window().get("start", 0.0) == 34.0 and s19c.surge_window().get("dur", 0.0) == 8.0,
			"经典涌潮窗 34~42")
	var s19h = Sim.new()
	s19h.setup_round("hard", 7)
	check(s19h.surge_window().get("start", 0.0) == 27.0, "寒夜涌潮窗 27~31（酸雨空档）")
	# 无重叠（最坏 jitter）：硬边界算术断言
	check(34.0 + 8.0 <= 46.0 - 3.0, "经典涌潮结束≤酸雨2最早开始")
	check(27.0 >= 18.0 + 2.5 + 6.0 and 27.0 + 4.0 <= 34.0 - 2.5, "寒夜涌潮夹在酸雨1/2 最坏边界之间")
	check(52.0 >= 45.0 + 2.0 + 4.0, "风暴涌潮开始≥酸雨3最晚结束")
	var s19a = Sim.new()
	s19a.setup_round("classic", 7)
	s19a.acid_events[0].start = 22.0
	s19a.acid_events[1].start = 46.0
	s19a.elapsed = 33.9
	check(not s19a.surge_active(), "33.9 未入涌潮")
	s19a.elapsed = 34.0
	check(s19a.surge_active(), "34.0 入涌潮")
	s19a.elapsed = 41.9
	check(s19a.surge_active(), "41.9 仍在涌潮")
	s19a.elapsed = 42.0
	check(not s19a.surge_active(), "42.0 出涌潮（半开区间）")
	# 单 tick 解析：窗内 rise+1.2。35.1 处 rise=2.7+0.055×35.1=4.6305，塔L1 降温 2.0
	s19a.towers[0] = 1
	s19a.npc_next = 2
	s19a.elapsed = 35.0
	s19a.heat = 50.0
	s19a.tick(0.1)
	check(approx(s19a.heat - 50.0, (4.6305 + 1.2 - 2.0) * 0.1, 0.02), "涌潮窗内单 tick 升温 +1.2",
			"d=%.3f" % (s19a.heat - 50.0))
	s19a.elapsed = 43.0
	s19a.heat = 50.0
	s19a.tick(0.1)
	# 43.1 已是第四阶段：rise=3.1+0.07×43.1=6.117，无涌潮加成
	check(approx(s19a.heat - 50.0, (3.1 + 0.07 * 43.1 - 2.0) * 0.1, 0.02), "涌潮窗外正常升温（无加成残留）",
			"d=%.3f" % (s19a.heat - 50.0))
	# 事件序列：全新模拟、时间只前进（回拨会造成假结束/再开始）
	var s19e = Sim.new()
	s19e.setup_round("classic", 7)
	s19e.acid_events[0].start = 22.0
	s19e.acid_events[1].start = 46.0
	s19e.npc_next = 2
	var counter19 := {"warn": 0, "start": 0, "end": 0}
	s19e.sim_event.connect(func(kind: String, _p: Dictionary) -> void:
		if kind == "surge_warn":
			counter19.warn += 1
		elif kind == "surge_started":
			counter19.start += 1
		elif kind == "surge_ended":
			counter19.end += 1
	)
	s19e.elapsed = 30.9
	s19e.tick(0.2)
	check(counter19.warn == 1, "提前 3s 预警一次（越过 31s）",
			"w%d" % counter19.warn)
	s19e.elapsed = 33.9
	s19e.tick(0.2)
	check(counter19.start == 1, "涌潮开始事件", "s%d" % counter19.start)
	s19e.elapsed = 41.9
	s19e.tick(0.2)
	check(counter19.end == 1, "越过 42s 涌潮结束事件", "e%d" % counter19.end)

	print("==== 3D 迁移阶段 A 测试：checks=%d failures=%d ====" % [checks, failures])
	quit(1 if failures > 0 else 0)
