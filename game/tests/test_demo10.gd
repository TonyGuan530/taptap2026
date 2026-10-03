extends SceneTree
## demo-10 修改小说（编辑即玩法）v2 实验版流程验证（headless，纯逻辑无需真实时间等待）
## 用例1 词槽替换：choose 改变 stats（科幻词 +1）与 flags；同槽反悔会回滚旧效果
## 用例2 候选状态化：第 2 章呼应槽的候选列表随第 1 章旗标（侦探/记者）不同
## 用例3 提交过章：第 1 章全部替换后 submit → chapter_pass=true → 进入第 2 章
## 用例4 目标判定：第 3 章基调不足 submit → 退稿停在本章；补足后过
##   （v2 语义修正：矛盾不再扣基调，压基调改用「脚印」候选而非舷梯冲突项）
## 用例5 矛盾两段式（v2）：地点冲突 → 记入 anomalies、抗议不增加、不立即扣基调
## 用例6 陷阱选项：第 4 章 trap 候选双倍效果 + 强设旗标 + 抗议；
##   陷阱抗议与未圆回 anomaly 转化的抗议一起带入终章无法过审（v2 断言修正）
## 用例7 结局拼装：科幻线/温情线两次跑到第 5 章，state_text() 正文与结局均不同
## 用例8 全流程：5 章依次达标 → state=final（出版结算）
## 用例9 退稿重改：第 4 章退稿后 reset → 词槽清空、旗标/基调回滚到本章快照
## 用例10 章节内容完整：CHAPTERS 共 5 章、词槽 3/3/4/4/5、占位符与候选齐全
## 用例11 派生词槽（v2）：同候选不同身份 → 不同 evidence 旗标与基调；候选 UI 显示派生含义
## 用例12 anomaly 记录（v2）：矛盾挂账、抗议不增；同槽反悔可撤销/重挂
## 用例13 圆回链（v2）：第 3 章舷梯矛盾 → 第 4 章 explain 候选圆回 → payoff/奖基调/结算「伏笔回收」/结局引用 evidence
## 用例14 未圆回转抗议（v2）：带 anomaly 进第 5 章交稿 → 转抗议、出版失败；reset 快照还原 anomalies
## 用例15 盲测模式（v2）：默认开——基调三档文字+氛围句、无精确数字；set_blind(false) 恢复精确显示
## v3 实验版（监督者复评授权：同一 anomaly 双解释）：
## 用例16 双解释互斥：第 4 章同槽 A/B 两把钥匙——选 A 后换 B，secret 由 colony_ship 翻转为
##   mine_door、A 的科幻与圆回对称回退、anomaly 仍只消费一次（payoff 不重复计）
## 用例17 B 线直选圆回：矿井门解释同样圆回 anomaly（payoff+1、悬疑+1）、resolution_type=mine_door
## 用例18 结局分化：A/B 两线第 5 章结局文本不同（secret 段落差异：登船闸 vs 停工真相）
## 用例19 遥测：anomaly_created/resolved/chapters_to_resolution 数值正确；
##   未圆回场景 unresolved_at_publish=1 且结局不含 secret 段（维持现状+抗议退稿）
## 运行：godot --headless --path game -s res://tests/test_demo10.gd

var passes := 0
var fails := 0


func _init() -> void:
	_run()


func _log(t: String) -> void:
	print(t)


func _check(cond: bool, tag: String) -> void:
	if cond:
		passes += 1
		_log("PASS " + tag)
	else:
		fails += 1
		_log("FAIL " + tag)


func _new_scene() -> Control:
	var s: Control = load("res://demo10_novel.tscn").instantiate()
	root.add_child(s)
	await physics_frame
	await physics_frame
	return s


func _drop(s: Control) -> void:
	s.queue_free()
	await physics_frame


## 按「每章候选下标表」推一条故事线：每章选满全部词槽后交稿，到 final 或表尾为止
func _play_line(s: Control, picks: Array) -> void:
	for ci in picks.size():
		var row: Array = picks[ci]
		for si in row.size():
			s.choose(si, row[si])
		s.submit_chapter()
		if s.state == "final":
			break


## v3 前置：小镇记者线推到第 4 章并携带未圆回 anomaly（第 3 章舷梯气闸，place 键）
## 到达时状态：sci=2 warm=2 susp=1、anomalies×1、payoff=0、抗议=0
func _reach_ch4_anomaly(s: Control) -> void:
	s.choose(0, 1)   # 记者
	s.choose(1, 0)   # 小镇
	s.choose(2, 3)   # 模糊照片（prop=旧照片）
	s.submit_chapter()
	s.choose(0, 2)   # 调阅日志 科幻+1
	s.choose(1, 0)   # 黄铜钥匙（记者派生 温情+1）
	s.choose(2, 0)   # 撤稿 悬疑+1
	s.submit_chapter()
	s.choose(0, 1)   # 想回家 温情+1→2
	s.choose(1, 2)   # 磨平 悬疑-1→0
	s.choose(2, 0)   # 别相信 悬疑+1→1
	s.choose(3, 2)   # 舷梯 科幻+1→2，挂 anomaly
	s.submit_chapter()


func _run() -> void:
	await process_frame
	_log("demo-10 修改小说 v2 headless 测试开始")

	# --- 用例1 词槽替换：stats 与 flags 联动 + 反悔回滚 ---
	var s1: Control = await _new_scene()
	_check(s1.state == "play" and s1.chapter_idx == 0, "用例1a 初始：state=play 且停在第 1 章")
	_check(int(s1.stats.sci) == 0 and int(s1.stats.warm) == 0 and int(s1.stats.susp) == 0,
		"用例1b 初始三基调全 0")
	_check(s1.flags.is_empty(), "用例1c 初始无旗标")
	s1.choose(0, 0)   # 侦探：悬疑+1 + 旗标
	s1.choose(1, 2)   # 空间站：科幻+1 + 旗标
	_check(int(s1.stats.susp) == 1 and int(s1.stats.sci) == 1 and int(s1.stats.warm) == 0,
		"用例1d choose 后：悬疑+1、科幻+1、温情不变")
	_check(str(s1.flags.get("role", "")) == "侦探" and str(s1.flags.get("place", "")) == "空间站",
		"用例1e choose 后旗标：身份=侦探、地点=空间站")
	s1.choose(0, 1)   # 同槽反悔改记者
	_check(int(s1.stats.susp) == 0 and str(s1.flags.get("role", "")) == "记者",
		"用例1f 同槽反悔：旧效果回滚（悬疑归 0、身份变记者）")
	_check(str(s1.slots[2].original) == "一张照片", "用例1g 词槽保留原文 original=一张照片")
	await _drop(s1)

	# --- 用例2 候选状态化：呼应槽随第 1 章旗标变化 ---
	var sA: Control = await _new_scene()
	sA.choose(0, 0)   # 侦探
	sA.choose(1, 0)
	sA.choose(2, 3)
	sA.submit_chapter()
	_check(sA.chapter_idx == 1, "用例2a 侦探线交稿进入第 2 章")
	var optsA: Array = sA.slots[2].options
	var ta := []
	for o in optsA:
		var ta_w: String = str(o.text)
		ta.append(ta_w)
	var sB: Control = await _new_scene()
	sB.choose(0, 1)   # 记者
	sB.choose(1, 0)
	sB.choose(2, 3)
	sB.submit_chapter()
	var optsB: Array = sB.slots[2].options
	var tb := []
	for o in optsB:
		var tb_w: String = str(o.text)
		tb.append(tb_w)
	_check(str(ta) != str(tb), "用例2b 呼应槽候选列表随第 1 章旗标不同（侦探线 vs 记者线）")
	_check(str(optsA[1].effects.flag_case) == "旧卷宗" and str(optsB[1].effects.flag_case) == "被撤的报道",
		"用例2c 侦探/记者线各带身份向伏笔旗标（旧卷宗 / 被撤的报道）")
	await _drop(sA)
	await _drop(sB)

	# --- 用例3 提交过章 ---
	var s3: Control = await _new_scene()
	for i in 3:
		s3.choose(i, 2)   # 宇航员 / 空间站 / 星图
	s3.submit_chapter()
	_check(s3.chapter_idx == 1 and s3.state == "play",
		"用例3a 第 1 章合法替换后交稿：chapter_pass=true 且进入第 2 章")
	_check(int(s3.stats.sci) == 3, "用例3b 科幻向选择累积：科幻 +3（封顶）")
	await _drop(s3)

	# --- 用例4 目标判定：第 3 章基调不足 → 退稿；补足 → 过（v2：矛盾不扣分，压基调改用脚印候选） ---
	var s4: Control = await _new_scene()
	s4.choose(0, 1)   # 记者（无基调）
	s4.choose(1, 0)   # 小镇（无基调）
	s4.choose(2, 3)   # 模糊照片（无基调）
	s4.submit_chapter()
	s4.choose(0, 2)   # 调阅日志 科幻+1
	s4.choose(1, 0)   # 黄铜钥匙（记者派生：温情+1，evidence=上锁抽屉的钥匙）
	s4.choose(2, 0)   # 呼应槽 撤稿 悬疑+1
	s4.submit_chapter()
	_check(s4.chapter_idx == 2, "用例4a 平淡线推进到第 3 章")
	var mx0: int = maxi(maxi(int(s4.stats.sci), int(s4.stats.warm)), int(s4.stats.susp))
	_check(mx0 <= 1, "用例4b 进入第 3 章时最高基调仅 %d（< 2）" % mx0)
	s4.choose(0, 2)   # 受潮 无基调
	s4.choose(1, 2)   # 磨平 悬疑-1
	s4.choose(2, 2)   # 寻常告别 悬疑-1
	s4.choose(3, 1)   # 脚印 悬疑+1（v2 不用舷梯冲突项压基调：矛盾不再扣分，会推高科幻）
	s4.submit_chapter()
	_check(not s4.chapter_pass and s4.chapter_idx == 2 and s4.state == "play",
		"用例4c 基调不足交稿：退稿（chapter_pass=false 停在第 3 章）")
	_check(s4.anomalies.is_empty(), "用例4c2 未写矛盾候选：无待圆回 anomaly")
	s4.choose(0, 0)   # 改科幻向：深空计划 +1
	s4.choose(1, 0)   # 伪造坐标 +1
	s4.submit_chapter()
	_check(s4.chapter_idx == 3, "用例4d 补足基调后交稿：过章进入第 4 章")
	await _drop(s4)

	# --- 用例5 矛盾两段式（v2）+ 用例6 陷阱选项 ---
	var s6: Control = await _new_scene()
	s6.choose(0, 1)   # 记者
	s6.choose(1, 0)   # 雾山小镇（地点=小镇）
	s6.choose(2, 1)   # 家书 温情+1
	s6.submit_chapter()
	s6.choose(0, 0)   # 卷宗 悬疑+1
	s6.choose(1, 1)   # 泛黄旧照片（记者派生：温情+1，evidence=证据）
	s6.choose(2, 0)   # 撤稿 悬疑+1
	s6.submit_chapter()
	_check(s6.chapter_idx == 2, "用例5a 小镇线推进到第 3 章")
	s6.choose(0, 1)   # 想回家 温情+1
	s6.choose(1, 2)   # 刻字磨平 悬疑-1
	s6.choose(2, 0)   # 别相信 悬疑+1
	var sci_before: int = int(s6.stats.sci)
	var contra_before: int = int(s6.contradictions)
	s6.choose(3, 2)   # 登上舷梯（科幻+1；地点=小镇 → 冲突 → v2 记 anomaly 不扣分）
	_check(int(s6.anomalies.size()) == 1 and int(s6.contradictions) == contra_before,
		"用例5b v2 矛盾两段式：anomalies+1 且抗议不增加")
	var an5: Dictionary = s6.anomalies[0]
	_check(str(an5.flag) == "place" and str(an5.wrote) == "空间站" and int(an5.at_chapter) == 3,
		"用例5b2 anomaly 内容：flag=place wrote=空间站 at_chapter=3")
	var ap5: Dictionary = s6.slots[3].applied
	_check(int(s6.stats.sci) == sci_before + 1 and str(ap5.pen_key) == "" and ap5.anomaly != null,
		"用例5c v2 矛盾不扣基调：科幻 +1 保留、无惩罚、槽上挂 anomaly")
	s6.submit_chapter()
	_check(s6.chapter_idx == 3, "用例5d 第 3 章最高基调达标：过章（anomaly 随行带入后文）")
	var warm_b: int = int(s6.stats.warm)
	var sci_b: int = int(s6.stats.sci)
	s6.choose(2, 0)   # 陷阱改稿：科幻+2 温情-1 强设旗标
	var ap6: Dictionary = s6.slots[2].applied
	_check(bool(s6.slots[2].options[0].get("trap", false)) and not bool(s6.slots[2].options[2].get("trap", false)),
		"用例6a 第 4 章陷阱候选已标记（克制项非陷阱）")
	_check(int(s6.stats.sci) == sci_b + 2 and int(s6.stats.warm) == warm_b - 1,
		"用例6b 陷阱双倍效果：科幻 +2、温情 -1（越改越偏）")
	_check(str(s6.flags.get("forced", "")) == "强行科幻", "用例6c 陷阱强设旗标 forced=强行科幻")
	_check(int(s6.contradictions) == contra_before + 1 and int(ap6.contra) == 1,
		"用例6d v2 仅陷阱记抗议（v1 的矛盾抗议已改为 anomaly；累计 %d）" % int(s6.contradictions))
	s6.choose(0, 0)   # 匿名卷宗
	s6.choose(1, 1)   # 等我回家 温情+1
	s6.choose(3, 0)   # 我知道他还活着
	s6.submit_chapter()
	_check(s6.chapter_idx == 4, "用例6e 第 4 章双基调达标：过章进入第 5 章")
	for k in 5:
		s6.choose(k, 0)
	s6.submit_chapter()
	_check(not s6.chapter_pass and s6.chapter_idx == 4 and s6.state == "play"
		and int(s6.contradictions) == contra_before + 2,
		"用例6f 终章结算：陷阱抗议 + 未圆回 anomaly 转抗议（共 %d）→ 无法过审（退稿）" % int(s6.contradictions))
	await _drop(s6)

	# --- 用例7 结局拼装 + 用例8 全流程出版 ---
	var LINE_SCI := [[2, 2, 2], [2, 2, 1], [0, 0, 0, 2], [2, 2, 2, 2]]
	var LINE_WARM := [[1, 1, 1], [1, 0, 1], [1, 1, 1, 0], [1, 1, 2, 1]]
	var sG: Control = await _new_scene()
	_play_line(sG, LINE_SCI)
	_check(sG.chapter_idx == 4 and sG.state == "play", "用例7a 科幻线推进到第 5 章（四章均达标）")
	sG.choose(0, 0)
	sG.choose(1, 0)
	sG.choose(2, 0)
	sG.choose(3, 0)
	sG.choose(4, 0)
	var txtG: String = sG.state_text()
	sG.submit_chapter()
	var endG: String = sG.state_text()
	_check(sG.state == "final" and sG.chapter_idx == 4, "用例8a 科幻线五章依次达标 → state=final（出版结算）")
	var sH: Control = await _new_scene()
	_play_line(sH, LINE_WARM)
	sH.choose(0, 1)
	sH.choose(1, 1)
	sH.choose(2, 1)
	sH.choose(3, 1)
	sH.choose(4, 1)
	var txtH: String = sH.state_text()
	sH.submit_chapter()
	var endH: String = sH.state_text()
	_check(sH.state == "final" and sH.chapter_pass, "用例8b 温情线五章依次达标 → state=final")
	_check(txtG != txtH, "用例7b 两线第 5 章正文不同（涌现可感知）")
	_check(endG.contains("《回声》") and endH.contains("《归途》") and endG != endH,
		"用例7c 结局按最高基调拼装不同终稿模板（回声 / 归途）")
	_check(endG.contains("宇航员") and endG.contains("星图") and endH.contains("记者") and endH.contains("信件"),
		"用例7d 结局插值旗标：身份与关键道具进入终稿")
	await _drop(sG)
	await _drop(sH)

	# --- 用例9 退稿重改：回滚到本章快照 ---
	var s9: Control = await _new_scene()
	s9.choose(0, 1)   # 记者
	s9.choose(1, 0)   # 雾山
	s9.choose(2, 3)   # 模糊照片（无基调，prop=旧照片）
	s9.submit_chapter()
	s9.choose(0, 0)   # 卷宗 悬疑+1
	s9.choose(1, 2)   # 未寄出手稿（v2 派生词槽：记者 → 悬疑+1，evidence=被撤稿的报道底稿）
	s9.choose(2, 0)   # 撤稿 悬疑+1
	s9.submit_chapter()
	s9.choose(0, 2)   # 受潮 无基调
	s9.choose(1, 2)   # 磨平 悬疑-1
	s9.choose(2, 2)   # 寻常告别 悬疑-1
	s9.choose(3, 1)   # 脚印 悬疑+1
	s9.submit_chapter()
	_check(s9.chapter_idx == 3, "用例9a 借平淡化控制基调，进入第 4 章")
	s9.choose(0, 0)   # 匿名卷宗（会改写伏笔旗标，供回滚验证）
	s9.choose(1, 0)   # 真相 悬疑+1
	s9.choose(2, 2)   # 克制 悬疑+1（避开陷阱，否则引抗议且科幻+2）
	s9.choose(3, 0)   # 还活着 悬疑+1
	s9.submit_chapter()
	_check(not s9.chapter_pass and s9.chapter_idx == 3, "用例9b 第 4 章双基调不达：退稿停在本章")
	s9.reset_chapter()
	_check(int(s9.stats.sci) == 0 and int(s9.stats.warm) == 0 and int(s9.stats.susp) == 2,
		"用例9c 重置后基调回滚快照（0/0/2）")
	_check(str(s9.flags.get("case", "")) == "", "用例9d 重置后旗标回滚（ch4 匿名卷宗撤销，case 回到章首空值）")
	_check(int(s9.contradictions) == 0, "用例9e 重置后抗议数回滚（0）")
	var all_clear := true
	for sl in s9.slots:
		if int(sl.chosen) != -1:
			all_clear = false
	_check(all_clear, "用例9f 重置后全部词槽恢复未选状态")
	s9.choose(0, 1)   # 温粥 温情+1
	s9.choose(1, 2)   # 更远的地方 科幻+1
	s9.choose(2, 2)   # 克制 悬疑+1
	s9.choose(3, 1)   # 回家吃热饭 温情+1
	_check(int(s9.stats.warm) == 2 and int(s9.stats.sci) == 1,
		"用例9g 重改后旗标/基调正确（温情 2、科幻 1）")
	s9.submit_chapter()
	_check(s9.chapter_idx == 4 and s9.state == "play", "用例9h 退稿后重改达标：过章进入第 5 章")
	await _drop(s9)

	# --- 用例10 章节内容完整 ---
	var s10: Control = await _new_scene()
	_check(s10.CHAPTERS.size() == 5, "用例10a CHAPTERS 共 5 章")
	var counts := []
	for ch in s10.CHAPTERS:
		var n: int = ch.slots.size()
		counts.append(n)
	var expect := [3, 3, 4, 4, 5]
	var ok_n: bool = counts.size() == expect.size()
	for i in mini(counts.size(), expect.size()):
		if int(counts[i]) != int(expect[i]):
			ok_n = false
	_check(ok_n, "用例10b 各章词槽数 3/3/4/4/5（实际 %s）" % str(counts))
	var ok_opts := true
	var ok_body := true
	var ok_echo := false   # 第 2 章必须存在一个状态化呼应槽
	for ch in s10.CHAPTERS:
		var body: String = str(ch.body)
		for i in ch.slots.size():
			var sd: Dictionary = ch.slots[i]
			if str(sd.get("dyn", "")) == "echo":
				ok_echo = true   # 呼应槽候选在开局按旗标解析，原始定义为空属预期
			elif sd.options.size() < 2:
				ok_opts = false
			if not body.contains("{%d}" % i):
				ok_body = false
	_check(ok_opts, "用例10c 每个词槽至少 2 个候选（呼应槽除外，运行时解析）")
	_check(ok_body, "用例10d 每章正文含全部词槽占位符")
	_check(ok_echo, "用例10f 第 2 章含状态化呼应槽（dyn=echo）")
	_check(not s10.state_text().is_empty(), "用例10e state_text() 输出非空正文")
	await _drop(s10)

	# --- 用例11 派生词槽（v2 变化 1）：同候选不同身份 → 不同 evidence 与基调；UI 标注派生义 ---
	var s11: Control = await _new_scene()
	s11.choose(0, 1)   # 记者（无基调）
	s11.choose(1, 0)   # 小镇
	s11.choose(2, 3)   # 模糊照片（无基调）
	s11.submit_chapter()
	_check(s11.chapter_idx == 1, "用例11a 记者线进入第 2 章")
	s11._open_popup(1)
	var ann_ok := false
	for c in s11.popup_box.get_children():
		if c is Button:
			var btxt: String = str(c.text)
			if btxt.contains("旧照片") and btxt.contains("记者视角：证据"):
				ann_ok = true
	s11._close_popup()
	_check(ann_ok, "用例11b 候选 UI 显示派生含义（泛黄的旧照片（记者视角：证据））")
	s11.choose(1, 1)   # 泛黄的旧照片 → 按身份派生
	_check(str(s11.flags.get("evidence", "")) == "证据" and int(s11.stats.warm) == 1,
		"用例11c 记者+照片 → evidence=证据 且 温情 +1")
	await _drop(s11)

	var s11b: Control = await _new_scene()
	s11b.choose(0, 0)   # 侦探（悬疑+1）
	s11b.choose(1, 0)
	s11b.choose(2, 3)
	s11b.submit_chapter()
	s11b.choose(1, 1)   # 同一候选「泛黄的旧照片」
	_check(str(s11b.flags.get("evidence", "")) == "案件线索" and int(s11b.stats.susp) == 2,
		"用例11d 侦探+照片 → evidence=案件线索 且 悬疑 +1（侦探基础 1 + 派生 1）")
	await _drop(s11b)

	var s11c: Control = await _new_scene()
	s11c.choose(0, 2)   # 宇航员（科幻+1）
	s11c.choose(1, 2)   # 空间站（科幻+1）
	s11c.choose(2, 3)   # 模糊照片（无基调，控制科幻 <3 给派生留空间）
	s11c.submit_chapter()
	s11c.choose(1, 1)
	_check(str(s11c.flags.get("evidence", "")) == "地球记忆" and int(s11c.stats.sci) == 3,
		"用例11e 宇航员+照片 → evidence=地球记忆 且 科幻 +1（基础 2 + 派生 1）")
	await _drop(s11c)

	# --- 用例12 anomaly 记录（v2 变化 2 前半）：矛盾挂账、抗议不增；同槽反悔撤销/重挂 ---
	var s12: Control = await _new_scene()
	s12.choose(0, 1)   # 记者
	s12.choose(1, 0)   # 小镇
	s12.choose(2, 3)   # 模糊照片
	s12.submit_chapter()
	s12.choose(0, 2)   # 调阅日志 科幻+1
	s12.choose(1, 0)   # 黄铜钥匙（记者派生：温情+1）
	s12.choose(2, 0)   # 撤稿 悬疑+1
	s12.submit_chapter()
	_check(s12.chapter_idx == 2, "用例12a 小镇线进入第 3 章")
	s12.choose(0, 1)   # 想回家 温情+1
	s12.choose(1, 2)   # 磨平 悬疑-1
	s12.choose(2, 0)   # 别相信 悬疑+1
	s12.choose(3, 2)   # 舷梯气闸（科幻+1；小镇线 → 冲突挂 anomaly）
	_check(int(s12.anomalies.size()) == 1 and int(s12.contradictions) == 0,
		"用例12b 矛盾挂账：anomalies=1、抗议仍为 0")
	var a12: Dictionary = s12.anomalies[0]
	_check(str(a12.flag) == "place" and str(a12.wrote) == "空间站" and int(a12.at_chapter) == 3 and str(a12.tone) == "sci",
		"用例12c anomaly 内容完整（place / 空间站 / 第 3 章 / 科幻）")
	s12.choose(3, 0)   # 同槽反悔：改回老屋门 → anomaly 撤销、舷梯的科幻回滚
	_check(s12.anomalies.is_empty() and int(s12.stats.sci) == 1,
		"用例12d 同槽反悔：anomaly 撤销、舷梯的科幻 +1 一并回滚（剩第 2 章的 1）")
	s12.choose(3, 2)   # 再选回舷梯 → anomaly 重新挂上
	_check(int(s12.anomalies.size()) == 1 and int(s12.stats.sci) == 2,
		"用例12e 重新选回：anomaly 重挂、科幻回到 2（第 2 章 1 + 舷梯 1）")
	s12.submit_chapter()
	_check(s12.chapter_idx == 3, "用例12f 第 3 章基调达标过章（温情 2 ≥ 2），anomaly 随行带入第 4 章")
	await _drop(s12)

	# --- 用例13 圆回链（v2 变化 2 后半）：第 3 章舷梯矛盾 → 第 4 章 explain 候选圆回 ---
	var s13: Control = await _new_scene()
	s13.choose(0, 1)
	s13.choose(1, 0)
	s13.choose(2, 3)
	s13.submit_chapter()
	s13.choose(0, 2)   # 调阅日志 科幻+1
	s13.choose(1, 0)   # 黄铜钥匙（记者派生：evidence=上锁抽屉的钥匙，温情+1）
	s13.choose(2, 0)   # 撤稿 悬疑+1
	s13.submit_chapter()
	s13.choose(0, 1)   # 温情+1 → 2
	s13.choose(1, 2)   # 悬疑-1 → 0
	s13.choose(2, 0)   # 悬疑+1 → 1
	s13.choose(3, 2)   # 舷梯：科幻+1 → 2，挂 anomaly
	s13.submit_chapter()
	_check(s13.chapter_idx == 3 and int(s13.anomalies.size()) == 1,
		"用例13a 带着 anomaly 进入第 4 章")
	var has_explain := false
	for o in s13.slots[0].options:
		if str(o.get("explain", "")) == "place":
			has_explain = true
	_check(has_explain, "用例13b 第 4 章存在 explain=place 的圆回候选（伪装的殖民飞船）")
	var sci13: int = int(s13.stats.sci)
	s13.choose(0, 3)   # 「后山的气闸原来属于伪装的殖民飞船」→ 自动圆回
	_check(s13.anomalies.is_empty() and int(s13.foreshadow_payoff) == 1 and int(s13.stats.sci) == sci13 + 1,
		"用例13c 圆回到账：anomaly 清空、伏笔回收 ×1、对应基调（科幻）+1")
	s13.choose(1, 0)   # 真相 悬疑+1
	s13.choose(2, 2)   # 克制 悬疑+1
	s13.choose(3, 0)   # 还活着 悬疑+1
	s13.submit_chapter()
	_check(s13.chapter_idx == 4, "用例13d 第 4 章双基调达标：过章进入第 5 章")
	for k in 5:
		s13.choose(k, 0)
	_check(not s13.end_panel.visible, "用例13e 未交稿前结算面板不显示")
	s13.submit_chapter()
	_check(s13.state == "final" and s13.chapter_pass, "用例13f 无抗议且无未圆回矛盾：过审出版")
	_check(str(s13.end_body.text).contains("伏笔回收 ×1"), "用例13g 结算面板显示「伏笔回收 ×1」")
	_check(s13.state_text().contains("上锁抽屉的钥匙"),
		"用例13h 结局模板引用派生旗标 evidence（第 2 章钥匙的记者派生义）")
	await _drop(s13)

	# --- 用例14 未圆回转抗议（v2）：带 anomaly 进第 5 章交稿 → 转抗议、出版失败；reset 快照还原 anomalies ---
	var s14: Control = await _new_scene()
	s14.choose(0, 1)
	s14.choose(1, 0)
	s14.choose(2, 3)
	s14.submit_chapter()
	s14.choose(0, 2)
	s14.choose(1, 0)
	s14.choose(2, 0)
	s14.submit_chapter()
	s14.choose(0, 1)   # 温情+1 → 2
	s14.choose(1, 2)   # 悬疑-1 → 0
	s14.choose(2, 0)   # 悬疑+1 → 1
	s14.choose(3, 2)   # 舷梯：科幻+1、挂 anomaly（不走圆回）
	s14.submit_chapter()
	s14.choose(0, 0)   # 匿名卷宗 悬疑+1
	s14.choose(1, 0)   # 真相 悬疑+1
	s14.choose(2, 2)   # 克制 悬疑+1
	s14.choose(3, 0)   # 还活着 悬疑+1
	s14.submit_chapter()
	_check(s14.chapter_idx == 4 and int(s14.anomalies.size()) == 1 and int(s14.contradictions) == 0,
		"用例14a 带着未圆回 anomaly、零抗议进入第 5 章")
	for k in 5:
		s14.choose(k, 0)
	s14.submit_chapter()
	_check(not s14.chapter_pass and s14.state == "play" and int(s14.contradictions) == 1
		and s14.anomalies.is_empty(),
		"用例14b 第 5 章交稿：未圆回 anomaly 转为 1 抗议 → 出版失败")
	s14.reset_chapter()
	_check(int(s14.contradictions) == 0 and int(s14.anomalies.size()) == 1 and int(s14.foreshadow_payoff) == 0,
		"用例14c reset 快照还原：抗议归 0、anomaly 挂回（快照含 anomalies）、回收数归 0")
	for k in 5:
		s14.choose(k, 0)
	s14.submit_chapter()
	_check(not s14.chapter_pass and int(s14.contradictions) == 1,
		"用例14d 再次交稿：anomaly 再次转抗议，仍无法过审")
	await _drop(s14)

	# --- 用例15 盲测模式（v2 变化 3）：默认开，三档文字 + 氛围句；set_blind(false) 恢复精确显示 ---
	var s15: Control = await _new_scene()
	_check(bool(s15.blind_mode), "用例15a 默认盲测模式开启")
	var tiers_ok := true
	var no_digit := true
	for tl in s15.tone_labels:
		var tt: String = str((tl as Label).text)
		if not (tt.contains("低") or tt.contains("中") or tt.contains("高")):
			tiers_ok = false
		for dgt in ["0", "1", "2", "3", "+", "-"]:
			if tt.contains(dgt):
				no_digit = false
	_check(tiers_ok, "用例15b 盲测下基调标签为 低/中/高 三档文字")
	_check(no_digit, "用例15c 盲测下基调标签不含精确数字/正负号")
	_check(str(s15.flags_label.text).contains("基调氛围"), "用例15d 氛围句上屏（基调氛围：…）")
	s15.choose(0, 2)   # 宇航员 科幻+1
	s15.choose(1, 2)   # 空间站 科幻+1
	s15.choose(2, 2)   # 星图 科幻+1
	var t_sci: String = str((s15.tone_labels[0] as Label).text)
	_check(t_sci.contains("高"), "用例15e 科幻拉满后显示「高」档（%s）" % t_sci)
	_check(str(s15.flags_label.text).contains("引擎的低鸣"), "用例15f 高科幻氛围句（纸页间回响起引擎的低鸣）")
	s15.set_blind(false)
	var t_sci2: String = str((s15.tone_labels[0] as Label).text)
	_check(t_sci2.contains("+3"), "用例15g set_blind(false) 恢复精确显示（科幻 +3）")
	_check(int(s15.stats.sci) == 3 and int(s15.stats.warm) == 0 and int(s15.stats.susp) == 0,
		"用例15h 盲测只改显示层：内部数值照常（3/0/0）")
	s15.set_blind(true)
	var t_sci3: String = str((s15.tone_labels[0] as Label).text)
	_check(t_sci3.contains("高") and not t_sci3.contains("+"), "用例15i 重新开启盲测：回到三档文字")
	await _drop(s15)

	# --- 用例16 双解释互斥（v3 核心）：同一「气闸」anomaly 的两把钥匙，同槽二选一 ---
	var s16: Control = await _new_scene()
	_reach_ch4_anomaly(s16)
	_check(s16.chapter_idx == 3 and int(s16.anomalies.size()) == 1,
		"用例16a 前置：带 place 键 anomaly 进入第 4 章")
	var explain_n := 0
	var secrets := {}
	for o in s16.slots[0].options:
		if str(o.get("explain", "")) == "place":
			explain_n += 1
			var fx: Dictionary = o.get("effects", {})
			secrets[str(fx.get("flag_secret", ""))] = true
	_check(explain_n == 2 and secrets.has("colony_ship") and secrets.has("mine_door"),
		"用例16b 第 4 章 slot0 存在 A/B 两个解释候选（secret=colony_ship / mine_door）")
	var sci16: int = int(s16.stats.sci)
	var susp16: int = int(s16.stats.susp)
	s16.choose(0, 3)   # A 线：伪装的殖民飞船
	_check(str(s16.flags.get("secret", "")) == "colony_ship" and s16.anomalies.is_empty()
		and int(s16.foreshadow_payoff) == 1,
		"用例16c 选 A：secret=colony_ship、anomaly 圆回、伏笔回收 ×1")
	_check(str(s16.telemetry.resolution_type) == "colony_ship",
		"用例16d 选 A：遥测 resolution_type=colony_ship")
	s16.choose(0, 4)   # 同槽反悔换 B 线：矿井旧防爆隔离门
	_check(str(s16.flags.get("secret", "")) == "mine_door",
		"用例16e 同槽换 B：secret 翻转为 mine_door（互斥，无残留双旗标）")
	_check(int(s16.stats.sci) == sci16 + 1 and int(s16.stats.susp) == susp16 + 1,
		"用例16f 同槽换 B：A 的科幻效果回滚（回 2）、B 悬疑 +1（候选），圆回奖励 +1 仍按 anomaly 的科幻基调落位")
	_check(s16.anomalies.is_empty() and int(s16.foreshadow_payoff) == 1,
		"用例16g 同槽换 B：anomaly 仍只消费一次（回收不重复计、矛盾不复活）")
	_check(str(s16.telemetry.resolution_type) == "mine_door" and int(s16.telemetry.anomaly_resolved) == 1,
		"用例16h 遥测：换 B 后 resolution_type=mine_door、resolved 计数对称回退后仍为 1")
	s16.choose(1, 0)
	s16.choose(2, 2)
	s16.choose(3, 0)
	s16.submit_chapter()
	_check(s16.chapter_idx == 4, "用例16i B 线解释同样满足第 4 章双基调目标：过章进入第 5 章")
	await _drop(s16)

	# --- 用例17 B 线直选圆回（v3）：矿井门解释是另一把合法钥匙 ---
	var s17: Control = await _new_scene()
	_reach_ch4_anomaly(s17)
	var sci17: int = int(s17.stats.sci)
	var susp17: int = int(s17.stats.susp)
	s17.choose(0, 4)   # 不经过 A，直接选 B
	_check(s17.anomalies.is_empty() and int(s17.foreshadow_payoff) == 1
		and int(s17.stats.susp) == susp17 + 1 and int(s17.stats.sci) == sci17 + 1,
		"用例17a B 线直选圆回：anomaly 清空、伏笔回收 ×1、悬疑 +1（候选），圆回奖励 +1 按 anomaly 的科幻基调")
	_check(str(s17.telemetry.resolution_type) == "mine_door" and int(s17.telemetry.chapters_to_resolution) == 1,
		"用例17b 遥测：resolution_type=mine_door、chapters_to_resolution=1（第 3 章挂账 → 第 4 章圆回）")
	_check(int(s17.telemetry.anomaly_created) == 1 and int(s17.telemetry.anomaly_resolved) == 1,
		"用例17c 遥测：anomaly_created=1、anomaly_resolved=1")
	await _drop(s17)

	# --- 用例18 结局分化（v3）：同一 anomaly、两种解释 → 第 5 章结局走向不同 ---
	var s18a: Control = await _new_scene()
	_reach_ch4_anomaly(s18a)
	s18a.choose(0, 3)   # A 飞船说
	s18a.choose(1, 0)
	s18a.choose(2, 2)
	s18a.choose(3, 0)
	s18a.submit_chapter()
	_check(s18a.chapter_idx == 4, "用例18a A 线过第 4 章（双基调达标）")
	for k in 5:
		s18a.choose(k, 0)
	s18a.submit_chapter()
	_check(s18a.state == "final", "用例18b A 线过审出版")
	var s18b: Control = await _new_scene()
	_reach_ch4_anomaly(s18b)
	s18b.choose(0, 4)   # B 矿井说——除了解释选择外全部与 A 线相同
	s18b.choose(1, 0)
	s18b.choose(2, 2)
	s18b.choose(3, 0)
	s18b.submit_chapter()
	_check(s18b.chapter_idx == 4, "用例18c B 线过第 4 章（双基调达标）")
	for k in 5:
		s18b.choose(k, 0)
	s18b.submit_chapter()
	_check(s18b.state == "final", "用例18d B 线过审出版")
	var endA: String = s18a.state_text()
	var endB: String = s18b.state_text()
	_check(endA.contains("登船闸") and not endA.contains("停工真相"),
		"用例18e A 线结局含飞船说 secret 段（登船闸…第一批登船），无矿井说段")
	_check(endB.contains("停工真相") and not endB.contains("登船闸"),
		"用例18f B 线结局含矿井说 secret 段（防爆隔离门…封存…停工真相），无飞船说段")
	_check(endA != endB, "用例18g 同一 anomaly 的两种合法解释：第 5 章结局文本完全不同")

	# --- 用例19 架构遥测（v3）：数值正确性 + 结算面板摘要 + 未圆回场景 ---
	# （19a/19b 依附 s18a 实例，须在其释放前断言）
	var tA: Dictionary = s18a.telemetry
	_check(int(tA.anomaly_created) == 1 and int(tA.anomaly_resolved) == 1
		and str(tA.resolution_type) == "colony_ship" and int(tA.chapters_to_resolution) == 1
		and int(tA.unresolved_at_publish) == 0,
		"用例19a 遥测（已出版 A 线）：created/resolved=1/1、type=colony_ship、距离 1、未圆回 0")
	var eb: String = str(s18a.end_body.text)
	_check(eb.contains("anomaly_created=1") and eb.contains("anomaly_resolved=1")
		and eb.contains("resolution_type=colony_ship") and eb.contains("chapters_to_resolution=1")
		and eb.contains("unresolved_at_publish=0"),
		"用例19b 结算面板含遥测摘要一行（五字段全量上屏）")
	await _drop(s18a)
	await _drop(s18b)

	var s19: Control = await _new_scene()
	_reach_ch4_anomaly(s19)
	s19.choose(0, 0)   # 匿名卷宗——不走任何解释，anomaly 保持未圆回
	s19.choose(1, 0)
	s19.choose(2, 2)
	s19.choose(3, 0)
	s19.submit_chapter()
	_check(s19.chapter_idx == 4, "用例19c 未圆回线照常过第 4 章（anomaly 随行）")
	for k in 5:
		s19.choose(k, 0)
	s19.submit_chapter()
	_check(not s19.chapter_pass and s19.state == "play" and int(s19.contradictions) == 1,
		"用例19d 未圆回交稿：anomaly 转 1 抗议 → 退稿（无 secret 段、结局维持现状）")
	var tU: Dictionary = s19.telemetry
	_check(int(tU.anomaly_created) == 1 and int(tU.anomaly_resolved) == 0
		and str(tU.resolution_type) == "" and int(tU.chapters_to_resolution) == -1
		and int(tU.unresolved_at_publish) == 1,
		"用例19e 遥测（未圆回）：created=1、resolved=0、type=无、距离 -1、unresolved_at_publish=1")
	var et: String = s19._ending_text()
	_check(not et.contains("登船闸") and not et.contains("停工真相"),
		"用例19f 无 secret 旗标：结局不插值任何 secret 段落（维持 v2 模板现状）")
	await _drop(s19)

	_log("==== 汇总：%d PASS / %d FAIL ====" % [passes, fails])
	quit(1 if fails > 0 else 0)
