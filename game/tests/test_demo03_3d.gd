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

	print("==== 3D 迁移阶段 A 测试：checks=%d failures=%d ====" % [checks, failures])
	quit(1 if failures > 0 else 0)
