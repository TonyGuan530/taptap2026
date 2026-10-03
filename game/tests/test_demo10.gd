extends SceneTree
## demo-10 修改小说（编辑即玩法）流程验证（headless，纯逻辑无需真实时间等待）
## 用例1 词槽替换：choose 改变 stats（科幻词 +1）与 flags；同槽反悔会回滚旧效果
## 用例2 候选状态化：第 2 章呼应槽的候选列表随第 1 章旗标（侦探/记者）不同
## 用例3 提交过章：第 1 章全部替换后 submit → chapter_pass=true → 进入第 2 章
## 用例4 目标判定：第 3 章基调不足 submit → 退稿停在本章；补足后过
## 用例5 矛盾检测：小镇线写出空间站场景 → contradictions+1 且对应基调被扣
## 用例6 陷阱选项：第 4 章 trap 候选双倍效果 + 强设旗标 + 抗议；抗议带入终章无法过审
## 用例7 结局拼装：科幻线/温情线两次跑到第 5 章，state_text() 正文与结局均不同
## 用例8 全流程：5 章依次达标 → state=final（出版结算）
## 用例9 退稿重改：第 4 章退稿后 reset → 词槽清空、旗标/基调回滚到本章快照
## 用例10 章节内容完整：CHAPTERS 共 5 章、词槽 3/3/4/4/5、占位符与候选齐全
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


func _run() -> void:
	await process_frame
	_log("demo-10 修改小说 headless 测试开始")

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

	# --- 用例4 目标判定：第 3 章基调不足 → 退稿；补足 → 过 ---
	var s4: Control = await _new_scene()
	s4.choose(0, 1)   # 记者（无基调）
	s4.choose(1, 0)   # 小镇（无基调）
	s4.choose(2, 3)   # 模糊照片（无基调）
	s4.submit_chapter()
	s4.choose(0, 2)   # 调阅日志 科幻+1
	s4.choose(1, 0)   # 针线盒 温情+1
	s4.choose(2, 0)   # 呼应槽 撤稿 悬疑+1
	s4.submit_chapter()
	_check(s4.chapter_idx == 2, "用例4a 平淡线推进到第 3 章")
	var mx0: int = maxi(maxi(int(s4.stats.sci), int(s4.stats.warm)), int(s4.stats.susp))
	_check(mx0 <= 1, "用例4b 进入第 3 章时最高基调仅 %d（< 2）" % mx0)
	for si in 4:
		s4.choose(si, 2)   # 全选平淡化/负向候选（含地点冲突的舷梯，科幻净 0）
	s4.submit_chapter()
	_check(not s4.chapter_pass and s4.chapter_idx == 2 and s4.state == "play",
		"用例4c 基调不足交稿：退稿（chapter_pass=false 停在第 3 章）")
	s4.choose(0, 0)   # 改科幻向：深空计划 +1
	s4.choose(1, 0)   # 伪造坐标 +1
	s4.submit_chapter()
	_check(s4.chapter_idx == 3, "用例4d 补足基调后交稿：过章进入第 4 章")
	await _drop(s4)

	# --- 用例5 矛盾检测 + 用例6 陷阱选项 ---
	var s6: Control = await _new_scene()
	s6.choose(0, 1)   # 记者
	s6.choose(1, 0)   # 雾山小镇（地点=小镇）
	s6.choose(2, 1)   # 家书 温情+1
	s6.submit_chapter()
	s6.choose(0, 0)   # 卷宗 悬疑+1
	s6.choose(1, 1)   # 黄铜钥匙 悬疑+1
	s6.choose(2, 0)   # 撤稿 悬疑+1
	s6.submit_chapter()
	_check(s6.chapter_idx == 2, "用例5a 小镇线推进到第 3 章")
	s6.choose(0, 1)   # 想回家 温情+1
	s6.choose(1, 2)   # 刻字磨平 悬疑-1
	s6.choose(2, 0)   # 别相信 悬疑+1
	var sci_before: int = int(s6.stats.sci)
	var contra_before: int = int(s6.contradictions)
	s6.choose(3, 2)   # 登上舷梯（科幻+1，但地点=小镇 → 冲突扣 1）
	_check(int(s6.contradictions) == contra_before + 1, "用例5b 地点冲突：读者抗议 contradictions+1")
	var ap5: Dictionary = s6.slots[3].applied
	_check(int(ap5.pen_delta) == -1 and int(s6.stats.sci) == sci_before,
		"用例5c 抗议扣对应基调：科幻 +1 被 -1 抵消（净 0）")
	s6.submit_chapter()
	_check(s6.chapter_idx == 3, "用例5d 第 3 章最高基调达标（温情/悬疑 ≥2）：过章")
	var warm_b: int = int(s6.stats.warm)
	var sci_b: int = int(s6.stats.sci)
	s6.choose(2, 0)   # 陷阱改稿：科幻+2 温情-1 强设旗标
	var ap6: Dictionary = s6.slots[2].applied
	_check(bool(s6.slots[2].options[0].get("trap", false)) and not bool(s6.slots[2].options[2].get("trap", false)),
		"用例6a 第 4 章陷阱候选已标记（克制项非陷阱）")
	_check(int(s6.stats.sci) == sci_b + 2 and int(s6.stats.warm) == warm_b - 1,
		"用例6b 陷阱双倍效果：科幻 +2、温情 -1（越改越偏）")
	_check(str(s6.flags.get("forced", "")) == "强行科幻", "用例6c 陷阱强设旗标 forced=强行科幻")
	_check(int(s6.contradictions) == contra_before + 2 and int(ap6.contra) == 1,
		"用例6d 陷阱记一次「越改越偏」抗议（累计 %d）" % int(s6.contradictions))
	s6.choose(0, 0)   # 匿名卷宗
	s6.choose(1, 1)   # 等我回家 温情+1
	s6.choose(3, 0)   # 我知道他还活着
	s6.submit_chapter()
	_check(s6.chapter_idx == 4, "用例6e 第 4 章双基调达标：过章进入第 5 章")
	for k in 5:
		s6.choose(k, 0)
	s6.submit_chapter()
	_check(not s6.chapter_pass and s6.chapter_idx == 4 and s6.state == "play",
		"用例6f 陷阱代价带入终章：主基调达标但抗议 >0 → 无法过审（退稿）")
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
	s9.choose(0, 0)   # 卷宗 悬疑+1（case=旧卷宗）
	s9.choose(1, 1)   # 钥匙 悬疑+1
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
		"用例9g 重改后旗标/基调正确（伏笔保持旧卷宗、温情 2）")
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

	_log("==== 汇总：%d PASS / %d FAIL ====" % [passes, fails])
	quit(1 if fails > 0 else 0)
