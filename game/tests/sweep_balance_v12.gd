extends SceneTree
## v12 平衡性扫描（工具，非 CI 断言）：3 模式 × 4 策略 × 5 种子，全量跑整局。
## 产出 markdown 行（供 reports/balance-sweep-v12.md 汇总）。
## 运行：godot --headless --path game -s res://tests/sweep_balance_v12.gd

const Sim := preload("res://demo03_3d/kingdom_simulation.gd")
const TICK: float = 1.0 / 60.0
const MODES: Array[String] = ["classic", "storm", "hard"]
const SEEDS: Array[int] = [1, 7, 13, 42, 99]
const STRATS: Array[String] = ["idle", "conservative", "standard", "aggressive", "reservoir"]


func act(s: Object, strat: String) -> void:
	if strat == "idle":
		return
	if strat == "conservative":
		if s.elapsed > 4.0 and s.towers[0] == 0 and s.water >= s.build_cost():
			s.try_build(0)
		return
	if strat == "reservoir":
		# v10 评估：12s 起优先建蓄水池（60💧），随后走标准阶梯
		if s.elapsed > 12.0 and s.reservoir == 0 and s.water >= s.RESERVOIR_COST:
			s.try_build_reservoir()
			return
	# standard 与 aggressive 共用门控阶梯；aggressive 追加投资与指挥
	if s.elapsed > 3.5 and s.towers[0] == 0 and s.water >= s.build_cost():
		s.try_build(0)
	elif s.elapsed > 12.0 and s.towers[1] == 0 and s.water >= s.build_cost():
		s.try_build(1)
	elif s.elapsed > 21.0 and s.villagers.size() > 0 and s.villagers[0].level == 0 and s.water >= s.NPC_UP_COST:
		s.try_promote(s.villagers[0].id)
	elif s.elapsed > 24.0 and s.towers[0] == 1 and s.water >= s.upgrade_cost():
		s.try_upgrade(0)
	elif s.elapsed > 40.0 and s.towers[2] == 0 and s.water >= s.build_cost():
		s.try_build(2)
	if strat == "aggressive":
		if s.elapsed > 30.0 and s.towers[1] == 1 and s.water >= s.upgrade_cost():
			s.try_upgrade(1)
		elif s.elapsed > 36.0 and s.villagers.size() > 1 and s.villagers[1].level == 0 and s.water >= s.NPC_UP_COST:
			s.try_promote(s.villagers[1].id)
		if s.try_command():
			pass


func _initialize() -> void:
	_run()


func _run() -> void:
	print("| 模式 | 策略 | 胜率 | 平均用时 | 终温均值 | 备注 |")
	print("| --- | --- | --- | --- | --- | --- |")
	for mode: String in MODES:
		for strat: String in STRATS:
			var wins := 0
			var times: float = 0.0
			var heats: float = 0.0
			var cmd_used := 0
			var res_used := 0
			for seed_v: int in SEEDS:
				var s = Sim.new()
				s.setup_round(mode, seed_v)
				while s.round_state == "play" and s.elapsed < 70.0:
					s.tick(TICK)
					act(s, strat)
				if s.round_state == "win":
					wins += 1
					times += s.elapsed
				else:
					times += s.elapsed
				heats += s.heat
				for rec: Dictionary in s.spend_log:
					if rec.kind == "command":
						cmd_used += 1
					elif rec.kind == "reservoir":
						res_used += 1
			var n := SEEDS.size()
			var avg_t := times / float(n)
			print("| %s | %s | %d/%d | %.1fs | %.1f | 指挥%d次·池%d次 |" % [
				mode, strat, wins, n, avg_t, heats / float(n), cmd_used, res_used])
	quit(0)
