extends SceneTree
## demo-12 角色·村庄特质沙盒 流程与涌现验证（headless）
## 用例1 特质分配：assign_trait 正常成功；重复特质/槽位越界/村民越界/非法特质均拒绝
## 用例2 情境结算：draw_situation 返回情境名，reactions=村民数且每条含 choice 与三项增量
## 用例3 特质映射：火灾之夜中勇敢与胆小的选择不同
## 用例4 数值反馈：匹配特质声望正增长落账，冲突特质压力正增长落账
## 用例5 重分配：setup 拒绝/重复拒绝/非法拒绝/改成功/每轮限额；改特质后下一张反应改变
## 用例6 五轮流程：5 次 draw_situation → round_idx=5、state=end、评级 A/B/C；第 6 次抽空
## 用例7 化学反应：勇敢+好奇 触发探险家特殊反应（区别于普通勇敢）
## 用例8 压力爆发：双冲突源局中老周压力满触发爆发标记与事件记录，且暴风雪走失
## 用例9 村庄评级：高声望组合→A，低声望冲突组合→C
## 用例10 全流程：3 村民 2 特质 → 5 情境 → 评级有效，数值界内，3 对关系有记录
## 用例11 关系涌现：双热络同场关系+，热络遇疏离关系-
## 用例12 常量表：特质池 ≥8、情境卡 ≥5，8 特质 x 5 情境全映射且每卡带化学反应位
## 运行：godot --headless --path game -s res://tests/test_demo12.gd

const BASE_SEED := 1212

var log_lines: Array = []
var passes := 0
var fails := 0


func _init() -> void:
	_run()


func _log(t: String) -> void:
	print(t)
	log_lines.append(t)
	var f := FileAccess.open("user://test12log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()


func _check(cond: bool, tag: String) -> void:
	if cond:
		passes += 1
		_log("PASS " + tag)
	else:
		fails += 1
		_log("FAIL " + tag)


func _new_scene() -> Control:
	seed(BASE_SEED)
	var s: Control = load("res://demo12_chars.tscn").instantiate()
	root.add_child(s)
	await process_frame
	return s


## 快速开局：按特质表给三名村民各分配 2 特质
func _setup(s: Control, t0: Array, t1: Array, t2: Array) -> void:
	s.start_game()
	s.assign_trait(0, 0, t0[0])
	s.assign_trait(0, 1, t0[1])
	s.assign_trait(1, 0, t1[0])
	s.assign_trait(1, 1, t1[1])
	s.assign_trait(2, 0, t2[0])
	s.assign_trait(2, 1, t2[1])


func _run() -> void:
	await process_frame
	_log("demo-12 角色·村庄特质沙盒 headless 测试开始")
	var s: Control = await _new_scene()

	# --- 用例1 特质分配合法性 ---
	s.start_game()
	var a1: bool = s.assign_trait(0, 0, "勇敢")
	var a2: bool = s.assign_trait(0, 1, "勇敢")       # 与槽位 0 重复
	var a3: bool = s.assign_trait(0, 2, "贪婪")       # 槽位越界
	var a4: bool = s.assign_trait(3, 0, "贪婪")       # 村民越界
	var a5: bool = s.assign_trait(0, 1, "乱写的特质") # 非法特质
	var a6: bool = s.assign_trait(0, 1, "好奇")
	_check(a1 and not a2 and not a3 and not a4 and not a5 and a6,
		"用例1 特质分配：正常成功；重复特质/槽位越界/村民越界/非法特质均拒绝")

	# --- 用例2 情境结算结构 ---
	_setup(s, ["勇敢", "好奇"], ["慷慨", "温和"], ["保守", "慷慨"])
	var nm2: String = s.draw_situation()
	var ok2: bool = nm2 != "" and s.current_situation.name == nm2 \
		and s.reactions.size() == 3 and s.village_rating() == ""
	for r in s.reactions:
		ok2 = ok2 and r.choice != "" and r.has("tone_delta") and r.has("rep_delta") and r.has("stress_delta")
	_check(ok2, "用例2 情境结算：draw_situation 返回「%s」，reactions=3 且每条含 choice/三项增量" % nm2)

	# --- 用例3 特质→反应映射（第 3 张卡·火灾之夜） ---
	_setup(s, ["勇敢", "保守"], ["胆小", "慷慨"], ["温和", "好奇"])
	for k in 3:
		s.draw_situation()
	var r3a: Dictionary = s.reactions[0]
	var r3b: Dictionary = s.reactions[1]
	_check(s.current_situation.name == "火灾之夜" and r3a.choice != r3b.choice and r3a.choice == "冲进火场救人",
		"用例3 特质映射：火灾之夜中勇敢「%s」与胆小「%s」选择不同" % [r3a.choice, r3b.choice])

	# --- 用例4 声望/压力变化 ---
	_setup(s, ["慷慨", "勇敢"], ["暴躁", "胆小"], ["好奇", "保守"])
	s.draw_situation()
	var r4a: Dictionary = s.reactions[0]
	var r4b: Dictionary = s.reactions[1]
	var v4a: Dictionary = s.villagers[0]
	var v4b: Dictionary = s.villagers[1]
	_check(int(r4a.rep_delta) > 0 and int(v4a.reputation) == 50 + int(r4a.rep_delta)
		and int(r4b.stress_delta) > 0 and int(v4b.stress) == 10 + int(r4b.stress_delta),
		"用例4 数值反馈：慷慨招待声望 +%d 落账 %d；暴躁冲突压力 +%d 落账 %d" % [r4a.rep_delta, v4a.reputation, r4b.stress_delta, v4b.stress])

	# --- 用例5 重分配 ---
	_setup(s, ["贪婪", "保守"], ["慷慨", "温和"], ["勇敢", "好奇"])
	var pre5: bool = s.redistribute(0, 0, "慷慨")      # setup 阶段不允许
	s.draw_situation()
	var badDup5: bool = s.redistribute(0, 0, "保守")   # 与槽位 1 重复
	var badWord5: bool = s.redistribute(0, 0, "乱写的特质")
	var ok5: bool = s.redistribute(0, 0, "慷慨")       # 贪婪 → 慷慨
	var twice5: bool = s.redistribute(0, 1, "勇敢")    # 本轮额度已用完
	s.draw_situation()
	var ch5: String = s.reactions[0].choice
	_check(not pre5 and not badDup5 and not badWord5 and ok5 and not twice5 and ch5 == "提议全村按户平分",
		"用例5 重分配：setup 拒绝/重复拒绝/非法拒绝/改成功/限额拒绝；贪婪改慷慨后宝藏反应变「%s」" % ch5)

	# --- 用例6 五轮流程与评级 ---
	_setup(s, ["勇敢", "好奇"], ["慷慨", "温和"], ["保守", "慷慨"])
	var names6 := []
	for k in 5:
		names6.append(s.draw_situation())
	var ok6: bool = names6.size() == 5
	for n6 in names6:
		ok6 = ok6 and n6 != ""
	var rat6: String = s.village_rating()
	_check(ok6 and s.round_idx == 5 and s.state == "end" and (rat6 == "A" or rat6 == "B" or rat6 == "C"),
		"用例6 五轮流程：5 卡翻完 round_idx=5、state=end、评级 %s" % rat6)
	var empty6: bool = s.draw_situation() == "" and s.round_idx == 5
	_check(empty6, "用例6b 卡池抽尽：第 6 次 draw_situation 返回空串且轮数不再前进")

	# --- 用例7 特质化学反应 ---
	_setup(s, ["勇敢", "好奇"], ["勇敢", "保守"], ["温和", "慷慨"])
	s.draw_situation()
	var ch7a: String = s.reactions[0].choice
	var ch7b: String = s.reactions[1].choice
	_check(ch7a == "拉着陌生人聊外面的地图" and ch7b == "上前拦住陌生人质问来意" and ch7a != ch7b,
		"用例7 化学反应：勇敢+好奇 触发探险家特殊反应，区别于普通勇敢")

	# --- 用例8 压力爆发（双冲突源局） ---
	_setup(s, ["贪婪", "暴躁"], ["贪婪", "暴躁"], ["暴躁", "胆小"])
	for k in 5:
		s.draw_situation()
	var v8: Dictionary = s.villagers[2]
	var any8 := false
	var log8 := false
	for v in s.villagers:
		if v.burst:
			any8 = true
	for e in s.events:
		if e.contains("爆发"):
			log8 = true
	_check(any8 and v8.burst and int(v8.stress) <= 60 and log8 and v8.left,
		"用例8 压力爆发：老周压力满触发爆发（事件留痕、压力回落至 %d），且暴风雪中走失" % int(v8.stress))

	# --- 用例9 村庄评级两端 ---
	_setup(s, ["勇敢", "好奇"], ["慷慨", "温和"], ["保守", "慷慨"])
	for k in 5:
		s.draw_situation()
	var hi9: String = s.village_rating()
	_setup(s, ["贪婪", "暴躁"], ["贪婪", "胆小"], ["暴躁", "胆小"])
	for k in 5:
		s.draw_situation()
	var lo9: String = s.village_rating()
	_check(hi9 == "A" and lo9 == "C", "用例9 村庄评级：高声望组合评 %s，低声望冲突组合评 %s" % [hi9, lo9])

	# --- 用例10 全流程数据完整性 ---
	_setup(s, ["温和", "好奇"], ["保守", "勇敢"], ["慷慨", "胆小"])
	var ok10 := true
	for k in 5:
		ok10 = ok10 and s.draw_situation() != ""
	ok10 = ok10 and (s.village_rating() in ["A", "B", "C"])
	for v in s.villagers:
		ok10 = ok10 and v.traits.size() == 2 and int(v.reputation) >= 0 and int(v.reputation) <= 100 \
			and int(v.stress) >= 0 and int(v.stress) <= 100
	ok10 = ok10 and s.relations.size() == 3
	_check(ok10, "用例10 全流程：3 村民 2 特质 → 5 情境 → 评级有效；数值界内；3 对关系有记录")

	# --- 用例11 关系涌现 ---
	_setup(s, ["慷慨", "温和"], ["慷慨", "温和"], ["暴躁", "贪婪"])
	s.draw_situation()
	var rel01: int = int(s.relations["0-1"])
	var rel02: int = int(s.relations["0-2"])
	_check(rel01 > 0 and rel02 < 0, "用例11 关系涌现：双热络同场关系 %+d，热络遇疏离关系 %+d" % [rel01, rel02])

	# --- 用例12 常量表完整性 ---
	var ok12: bool = s.TRAITS.size() >= 8 and s.SITUATIONS.size() >= 5
	for sit in s.SITUATIONS:
		ok12 = ok12 and sit.reactions.size() == 8 and sit.chem.size() >= 1
		for t in s.TRAITS:
			var cell: Dictionary = sit.reactions.get(t.id, {})
			ok12 = ok12 and cell.has("choice") and cell.has("tone") and cell.has("rep") and cell.has("stress")
	_check(ok12, "用例12 常量表：特质池 %d 种、情境卡 %d 张，8 特质 x 5 情境全映射且每卡带化学反应位" % [s.TRAITS.size(), s.SITUATIONS.size()])

	_log("==== 汇总：%d PASS / %d FAIL ====" % [passes, fails])
	quit(1 if fails > 0 else 0)
