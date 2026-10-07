extends RefCounted
## DEMO10 3D 版纯规则核心（阶段 A）。从 demo10_novel.gd 逐语义移植，不引用任何三维节点、
## 相机或 UI；场景与界面只通过信号和公开状态读取它。禁止在这里加第二套分数或改规则。
##
## 与旧版 demo10_novel.gd 的关系（指南第 2 节）：
## - 保留五章词槽 3/3/4/4/5、三基调 clamp -3..+3、身份派生、章首快照、异常延后转抗议、
##   第 4 章飞船/矿井双解释、出版条件、盲测模式，全部语义与旧版一致。
## - 已知边界（先复现现状、不悄悄修正，修正需单独授权）：
##   ① choose() 里候选 effects 与圆回奖励写同一个 applied.delta[tone]，后者覆盖前者——
##      同基调且中途触顶/回滚时会有残留（详见 tests/test_demo10_3d.gd 边界段）。
##   ② 章首快照 snap 不含 telemetry，reset_chapter() 不还原遥测五字段。
## - 旧 UI 的 _toast/_show_card 改为信号 toast(text) / chapter_card(text)，文案不变。

signal toast(text: String)
signal chapter_card(text: String)
signal state_changed(command_id: int)

## 旗标显示名（未列出的键原样显示）
const FLAG_NAMES := {role = "身份", place = "地点", prop = "关键道具", case = "伏笔", note = "细节", forced = "强设", evidence = "实证", secret = "秘密"}

## v3 双解释的解读方向标注（候选浮层用）——同一 anomaly 的两把合法钥匙
const SECRET_LABELS := {colony_ship = "飞船说", mine_door = "矿井说"}

## 三条基调的显示定义：键 / 名 / 色（数据供 UI 使用，不参与规则）
const TONE_DEFS := [
	{key = "sci", label = "科幻", col = Color("7fd4ff")},
	{key = "warm", label = "温情", col = Color("ffb3a7")},
	{key = "susp", label = "悬疑", col = Color("cfa8ff")},
]

## 第 2 章呼应槽：候选列表随第 1 章旗标（身份）变化——状态化候选的演示
const ECHO_OPTIONS := [
	{role = "侦探", options = [
		{text = "井绳上有新的磨痕", effects = {susp = 1}},
		{text = "我要重查三年前的卷宗编号", effects = {susp = 1, flag_case = "旧卷宗"}},
	]},
	{role = "记者", options = [
		{text = "有人在悄悄撤下当年的报道", effects = {susp = 1}},
		{text = "那篇报道当年被紧急撤稿", effects = {susp = 1, flag_case = "被撤的报道"}},
	]},
	{role = "宇航员", options = [
		{text = "舱外的温度读数在说谎", effects = {sci = 1}},
		{text = "导航日志被人改写过", effects = {sci = 1, flag_case = "被改的日志"}},
	]},
	{role = "", options = [
		{text = "有人在暗处盯着我", effects = {susp = 1}},
	]},
]

## 五章内容表：与 demo10_novel.gd 的 CHAPTERS 逐字一致（唯一规则数据源的分身；
## 对照测试断言两者文本与结构相同，改动任何一处都会被测试抓出）
const CHAPTERS := [
	{
		name = "第 1 章 · 开头", goal = {kind = "any"},
		tip = "教学：任选候选改完全部词槽即可交稿",
		body = "我叫{0}，回来是因为那封信。三年前我离开{1}，从此再没回去过。直到上个月，我的信箱里出现了{2}——背面写着一行字：他还活着。",
		slots = [
			{original = "林晚", options = [
				{text = "林晚，一个侦探", effects = {susp = 1, flag_role = "侦探"}},
				{text = "林晚，一个记者", effects = {flag_role = "记者"}},
				{text = "林晚，一个宇航员", effects = {sci = 1, flag_role = "宇航员"}},
			]},
			{original = "老家", options = [
				{text = "多雨的南方小镇", effects = {flag_place = "小镇"}},
				{text = "外婆家所在的海边小镇", effects = {warm = 1, flag_place = "小镇"}},
				{text = "环月的「烛龙」空间站", effects = {sci = 1, flag_place = "空间站"}},
			]},
			{original = "一张照片", options = [
				{text = "井边的合影", effects = {susp = 1, flag_prop = "古井"}},
				{text = "泛黄的家书", effects = {warm = 1, flag_prop = "信件"}},
				{text = "加密的星图", effects = {sci = 1, flag_prop = "星图"}},
				{text = "一张模糊的旧照片", effects = {flag_prop = "旧照片"}},
			]},
		],
	},
	{
		name = "第 2 章 · 发展", goal = {kind = "any"},
		tip = "改完即可交稿——注意呼应槽的候选随前文旗标变化",
		body = "回到老家后的第一晚，{0}。台灯下，我翻出了一样蒙尘的{1}。窗外人影一闪，我确信——{2}。",
		slots = [
			{original = "我彻夜未眠", options = [
				{text = "我重读了三年前的案件卷宗", effects = {susp = 1}},
				{text = "我去看了儿时的老友", effects = {warm = 1}},
				{text = "我申请调阅空间站的旧日志", effects = {sci = 1}},
			]},
			{original = "旧物", options = [
				{text = "黄铜钥匙", derive = {flag = "evidence", table = {记者 = "上锁抽屉的钥匙", 侦探 = "储物间暗门的钥匙", 宇航员 = "休眠舱的应急钥匙"}, tone_by_role = {记者 = "warm", 侦探 = "susp", 宇航员 = "sci"}}},
				{text = "泛黄的旧照片", derive = {flag = "evidence", table = {记者 = "证据", 侦探 = "案件线索", 宇航员 = "地球记忆"}, tone_by_role = {记者 = "warm", 侦探 = "susp", 宇航员 = "sci"}}},
				{text = "未寄出的手稿", derive = {flag = "evidence", table = {记者 = "被撤稿的报道底稿", 侦探 = "死者最后的手记", 宇航员 = "手写的航行日志"}, tone_by_role = {记者 = "susp", 侦探 = "susp", 宇航员 = "sci"}}},
			]},
			{original = "有人在跟着我", dyn = "echo", options = []},
		],
	},
	{
		name = "第 3 章 · 转折", goal = {kind = "tone_max", min = 2},
		tip = "交稿时最高基调要冲到 +2（平淡化改写会掉基调）",
		body = "档案室最深处，我找到三份互相矛盾的记录。第一份说，{0}。第二份说，{1}。最底下压着一张字条，只有一句：{2}。我合上卷宗，起身——{3}。",
		slots = [
			{original = "记录已经残缺", options = [
				{text = "「他自愿参加了深空计划」", effects = {sci = 1}},
				{text = "「他只是累了，想回家」", effects = {warm = 1}},
				{text = "「纸页受潮，字迹难辨」", effects = {}},
			]},
			{original = "说法各有出入", options = [
				{text = "「星图上的坐标是伪造的」", effects = {sci = 1}},
				{text = "「字条是妹妹代笔的」", effects = {warm = 1, flag_note = "代笔的字条"}},
				{text = "「井栏的刻字早已磨平」", effects = {susp = -1}},
			]},
			{original = "「小心回来的人」", options = [
				{text = "「别相信回来的那个人」", effects = {susp = 1}},
				{text = "「回家吃饭吧，汤要凉了」", effects = {warm = 1}},
				{text = "「只是一场寻常告别，何必声张」", effects = {susp = -1}},
			]},
			{original = "我快步离开", options = [
				{text = "我推开老屋的门，闻到饭菜的香气", effects = {warm = 1}},
				{text = "我在档案架后发现第二串脚印", effects = {susp = 1}},
				{text = "我登上舷梯，穿过气闸舱门", effects = {sci = 1}, conflict = {flag = "place", value = "空间站", tone = "sci"}},
				{text = "我沿着气闸通道走向控制台", effects = {sci = 1}, conflict = {flag = "place", value = "空间站", tone = "sci"}},
			]},
		],
	},
	{
		name = "第 4 章 · 危机", goal = {kind = "dual", at = 1, count = 2, flag = "prop"},
		tip = "两条基调 ≥ +1 且关键道具旗标仍在；小心「越改越偏」的改稿",
		body = "雨下了一整夜。天亮时，{0}。我把所有纸页摊在桌上，终于看清：{1}。要么现在收手，{2}。深夜，我拨通了那个号码：{3}。",
		slots = [
			{original = "门口多了一样东西", options = [
				{text = "门缝里被塞进一份匿名卷宗", effects = {susp = 1, flag_case = "匿名卷宗"}},
				{text = "老屋桌上留着一碗还温着的粥", effects = {warm = 1}},
				{text = "空间站的应答器突然恢复信号", effects = {sci = 1}},
				{text = "后山的「气闸」原来属于一艘伪装的殖民飞船", effects = {sci = 1, flag_secret = "colony_ship"}, explain = "place"},
				{text = "所谓「气闸」，其实是矿井旧防爆隔离门", effects = {susp = 1, flag_secret = "mine_door"}, explain = "place"},
			]},
			{original = "所有线索都指向同一个方向", options = [
				{text = "所有线索都指向同一个真相", effects = {susp = 1}},
				{text = "他一直在等我回家", effects = {warm = 1}},
				{text = "信号来自比月亮更远的地方", effects = {sci = 1}},
			]},
			{original = "还是继续写下去", options = [
				{text = "（改稿）干脆写成「外星来客」的爆点", effects = {sci = 2, warm = -1, flag_forced = "强行科幻"}, trap = true},
				{text = "（改稿）干脆改成「治愈归乡」的催泪收尾", effects = {warm = 2, sci = -1, flag_forced = "强行温情"}, trap = true},
				{text = "保持克制，只写下我能证实的事", effects = {susp = 1}},
			]},
			{original = "「我知道他还活着」", options = [
				{text = "「我知道他还活着」", effects = {susp = 1}},
				{text = "「我想回家吃一顿热饭」", effects = {warm = 1}},
				{text = "「请求一次深空搜救」", effects = {sci = 1}},
			]},
		],
	},
	{
		name = "第 5 章 · 结局", goal = {kind = "publish", min = 2},
		tip = "主基调 ≥ +2 且无读者抗议 → 过审出版",
		body = "回信来的那天，{0}。我在手稿的最后一页写下：{1}。合上稿纸时，{2}。多年后有人问起那个故事的结局，我说：{3}。只有我自己知道，{4}。",
		slots = [
			{original = "门口多了一个包裹", options = [
				{text = "信箱里躺着一枚陌生的空间站徽章", effects = {sci = 1}},
				{text = "妹妹提着保温桶站在门口", effects = {warm = 1}},
				{text = "井台边系着一条崭新的红布", effects = {susp = 1}},
			]},
			{original = "「故事写完了」", options = [
				{text = "「他随星尘去了更远的地方」", effects = {sci = 1}},
				{text = "「他回家了」", effects = {warm = 1}},
				{text = "「真相仍在井底」", effects = {susp = 1}},
			]},
			{original = "我长长舒了一口气", options = [
				{text = "我把手稿寄往深空通讯中心", effects = {sci = 1}},
				{text = "我在饭桌上把它读给全家听", effects = {warm = 1}},
				{text = "我把它锁进抽屉最底层", effects = {susp = 1}},
			]},
			{original = "「每个故事都有它的归宿」", options = [
				{text = "「故事没有结局，只有下一次发射」", effects = {sci = 1}},
				{text = "「最好的结局，是有人等你吃饭」", effects = {warm = 1}},
				{text = "「每个句号都是新的省略号」", effects = {susp = 1}},
			]},
			{original = "有些等待还没有结束", options = [
				{text = "星图的最后一段坐标仍未点亮", effects = {sci = 1}},
				{text = "那封信的落款只有两个字：勿念", effects = {warm = 1}},
				{text = "古井的第三块砖，昨夜又松动了", effects = {susp = 1}},
			]},
		],
	},
]

## 空的改动记录（回滚用）：字段与旧版 EMPTY_APPLIED 一致
const EMPTY_APPLIED := {delta = {}, flag_old = {}, contra = 0, pen_key = "", pen_delta = 0, anomaly = null, payoff = null}

var stats := {sci = 0, warm = 0, susp = 0}
var flags := {}
var contradictions := 0
var anomalies := []
var foreshadow_payoff := 0
var anomaly_seq := 0
var telemetry := {anomaly_created = 0, anomaly_resolved = 0, resolution_type = "", chapters_to_resolution = -1, unresolved_at_publish = 0}
var blind_mode := true
var chapter_idx := 0
var slots := []
var snap := {}
var chapter_pass := false
var state := "play"            # play / final
var command_seq := 0           # 每次状态变化 +1，WorldBridge 用它做版本保护


func _init() -> void:
	start_chapter(0)


# ---------------- 公开玩法 API（与旧版同名同语义） ----------------

## 进入第 i 章：重建词槽（解析状态化候选）、拍本章快照
func start_chapter(i: int) -> void:
	if i < 0 or i >= CHAPTERS.size():
		return
	chapter_idx = i
	var ch: Dictionary = CHAPTERS[i]
	slots = []
	for sd in ch.slots:
		var sdef: Dictionary = sd
		var sl := {
			original = str(sdef.original),
			options = _resolve_options(sdef),
			chosen = -1,
			applied = EMPTY_APPLIED.duplicate(true),
		}
		slots.append(sl)
	snap = {stats = stats.duplicate(), flags = flags.duplicate(), contradictions = contradictions,
		anomalies = anomalies.duplicate(true), payoff = foreshadow_payoff}
	chapter_pass = false
	chapter_card.emit(str(ch.name))
	_bump()


## 改写词槽：换选会先回滚该槽上一次的改动，再施加新候选（语义与旧版 choose 逐行一致）
func choose(slot_idx: int, opt_idx: int) -> void:
	if state != "play":
		return
	if slot_idx < 0 or slot_idx >= slots.size():
		return
	var opts: Array = slots[slot_idx].options
	if opt_idx < 0 or opt_idx >= opts.size():
		return
	if int(slots[slot_idx].chosen) == opt_idx:
		return
	_unapply_slot(slot_idx)
	var opt: Dictionary = opts[opt_idx]
	slots[slot_idx].chosen = opt_idx
	var applied := EMPTY_APPLIED.duplicate(true)
	var fx: Dictionary = opt.get("effects", {})
	for k in fx:
		var key: String = str(k)
		if key == "sci" or key == "warm" or key == "susp":
			var amount: int = int(fx[k])
			var old: int = int(stats[key])
			stats[key] = clampi(old + amount, -3, 3)
			applied.delta[key] = stats[key] - old
		elif key.begins_with("flag_"):
			var fname: String = key.substr(5)
			applied.flag_old[fname] = flags.get(fname)
			flags[fname] = str(fx[k])
	# v2 变化 1 上下文派生：同一候选按当前身份派生旗标值与基调
	var dv = opt.get("derive")
	if dv != null:
		var role: String = str(flags.get("role", ""))
		var dtable: Dictionary = dv.table
		if dtable.has(role):
			var dflag: String = str(dv.flag)
			applied.flag_old[dflag] = flags.get(dflag)
			flags[dflag] = str(dtable[role])
			var dtk: String = str((dv.tone_by_role as Dictionary).get(role, ""))
			if dtk != "":
				var dold: int = int(stats[dtk])
				stats[dtk] = clampi(dold + 1, -3, 3)
				applied.delta[dtk] = int(stats[dtk]) - dold
	# v2 变化 2 矛盾两段式：冲突先记为待圆回矛盾，不立即抗议/扣分
	var conflict = opt.get("conflict")
	if conflict != null:
		var cf: Dictionary = conflict
		var cflag: String = str(cf.flag)
		if flags.has(cflag) and str(flags[cflag]) != str(cf.value):
			anomaly_seq += 1
			var ano := {
				id = anomaly_seq, flag = cflag, wrote = str(cf.value),
				tone = str(cf.tone), at_chapter = chapter_idx + 1,
				ch_name = str(CHAPTERS[chapter_idx].name),
			}
			anomalies.append(ano)
			applied.anomaly = ano
			telemetry.anomaly_created = int(telemetry.anomaly_created) + 1
			toast.emit("读者皱眉：这里写岔了？（%s=%s 与前文矛盾，暂记一笔）" % [_flag_disp(cflag), str(cf.value)])
	# v2 变化 2 圆回机会：候选带 explain=旗标键 → 自动圆回同键的未决矛盾
	var ex_key: String = str(opt.get("explain", ""))
	if ex_key != "":
		var hit := -1
		for ai in anomalies.size():
			if str(anomalies[ai].flag) == ex_key:
				hit = ai
				break
		if hit >= 0:
			var ano2: Dictionary = anomalies[hit]
			anomalies.remove_at(hit)
			foreshadow_payoff += 1
			var ptk: String = str(ano2.tone)
			if ptk != "":
				var pold: int = int(stats[ptk])
				stats[ptk] = clampi(pold + 1, -3, 3)
				applied.delta[ptk] = int(stats[ptk]) - pold
			applied.payoff = {id = int(ano2.id), tone = ptk, restore = ano2.duplicate(true)}
			telemetry.anomaly_resolved = int(telemetry.anomaly_resolved) + 1
			if applied.flag_old.has("secret"):
				telemetry.resolution_type = str(flags.get("secret", ""))
			telemetry.chapters_to_resolution = int(chapter_idx + 1) - int(ano2.at_chapter)
			toast.emit("原来这里是伏笔！矛盾圆回来了（伏笔回收 ×%d%s）" % [foreshadow_payoff, _tone_note(ptk)])
	# 陷阱改稿：高收益但记抗议
	if bool(opt.get("trap", false)):
		applied.contra += 1
		contradictions += 1
		toast.emit("读者来信抗议：越改越偏了（本章抗议 +1）")
	slots[slot_idx].applied = applied
	_bump()


## 交稿：全部词槽改完才受理；目标达标过章（末章过审出版），否则退稿停在本章
func submit_chapter() -> void:
	if state != "play":
		return
	if not _all_chosen():
		chapter_pass = false
		toast.emit("还有词槽没改完——把每个高亮词都定下来再交稿")
		_bump()
		return
	var settle_note := ""
	if chapter_idx >= CHAPTERS.size() - 1:
		telemetry.unresolved_at_publish = anomalies.size()
		if not anomalies.is_empty():
			var n: int = anomalies.size()
			contradictions += n
			anomalies.clear()
			settle_note = "未圆回矛盾 ×%d 转为抗议；" % n
	if _goal_ok():
		chapter_pass = true
		if chapter_idx >= CHAPTERS.size() - 1:
			state = "final"
			toast.emit("过审出版！")
		else:
			start_chapter(chapter_idx + 1)
			toast.emit("交稿通过，进入下一章")
	else:
		chapter_pass = false
		toast.emit("退稿重改：" + settle_note + str(CHAPTERS[chapter_idx].tip))
	_bump()


## 退稿后重置本章：回滚到本章开始时的快照，词槽全部恢复可重改
## （已知边界：telemetry 五字段不在快照内、不被还原——与旧版一致，见文件头注释①②）
func reset_chapter() -> void:
	if state != "play":
		return
	var ss: Dictionary = snap.stats
	stats = {sci = int(ss.sci), warm = int(ss.warm), susp = int(ss.susp)}
	flags = (snap.flags as Dictionary).duplicate()
	contradictions = int(snap.contradictions)
	anomalies = (snap.anomalies as Array).duplicate(true)
	foreshadow_payoff = int(snap.payoff)
	for i in slots.size():
		slots[i].chosen = -1
		slots[i].applied = EMPTY_APPLIED.duplicate(true)
	chapter_pass = false
	toast.emit("已重置本章：旗标与基调回到章首快照")
	_bump()


## 当前章渲染后的完整正文（终章额外拼上按状态生成的结局段）
func state_text() -> String:
	var ch: Dictionary = CHAPTERS[chapter_idx]
	var t: String = _render_plain(str(ch.body))
	if state == "final":
		t += "\n\n" + _ending_text()
	return t


func set_blind(m: bool) -> void:
	blind_mode = m
	_bump()


# ---------------- 状态与规则（与旧版逐行一致） ----------------

func _resolve_options(sdef: Dictionary) -> Array:
	if str(sdef.get("dyn", "")) != "echo":
		return sdef.options
	var role: String = str(flags.get("role", ""))
	for e in ECHO_OPTIONS:
		if str(e.role) == role:
			return e.options
	return ECHO_OPTIONS[ECHO_OPTIONS.size() - 1].options


func _unapply_slot(i: int) -> void:
	var sl: Dictionary = slots[i]
	if int(sl.chosen) < 0:
		return
	var ap: Dictionary = sl.applied
	var d: Dictionary = ap.delta
	for k in d:
		var dk: String = str(k)
		stats[dk] = clampi(int(stats[dk]) - int(d[k]), -3, 3)
	var fo: Dictionary = ap.flag_old
	for k in fo:
		if fo[k] == null:
			flags.erase(str(k))
		else:
			flags[str(k)] = fo[k]
	if int(ap.contra) > 0:
		contradictions = maxi(0, contradictions - int(ap.contra))
	var pk: String = str(ap.pen_key)
	if pk != "":
		stats[pk] = clampi(int(stats[pk]) - int(ap.pen_delta), -3, 3)
	if ap.anomaly != null:
		var aid: int = int(ap.anomaly.id)
		for ai in anomalies.size():
			if int(anomalies[ai].id) == aid:
				anomalies.remove_at(ai)
				break
		telemetry.anomaly_created = maxi(0, int(telemetry.anomaly_created) - 1)
	if ap.payoff != null:
		foreshadow_payoff = maxi(0, foreshadow_payoff - 1)
		anomalies.append((ap.payoff.restore as Dictionary).duplicate(true))
		telemetry.anomaly_resolved = maxi(0, int(telemetry.anomaly_resolved) - 1)
		telemetry.resolution_type = ""
		telemetry.chapters_to_resolution = -1
	sl.chosen = -1
	sl.applied = EMPTY_APPLIED.duplicate(true)


func _all_chosen() -> bool:
	for sl in slots:
		if int(sl.chosen) < 0:
			return false
	return true


func _max_tone() -> int:
	return maxi(maxi(int(stats.sci), int(stats.warm)), int(stats.susp))


func _goal_ok() -> bool:
	var g: Dictionary = CHAPTERS[chapter_idx].goal
	match str(g.kind):
		"any":
			return _all_chosen()
		"tone_max":
			return _max_tone() >= int(g.min)
		"dual":
			var need: int = int(g.at)
			var n := 0
			if int(stats.sci) >= need:
				n += 1
			if int(stats.warm) >= need:
				n += 1
			if int(stats.susp) >= need:
				n += 1
			return n >= int(g.count) and flags.has(str(g.flag))
		"publish":
			return _max_tone() >= int(g.min) and contradictions == 0
	return false


func _render_plain(body: String) -> String:
	var out := body
	for i in slots.size():
		var sl: Dictionary = slots[i]
		var word: String = str(sl.original)
		var ci: int = int(sl.chosen)
		if ci >= 0:
			var opt: Dictionary = sl.options[ci]
			word = str(opt.text)
		out = out.replace("{%d}" % i, word)
	return out


func _ending_text() -> String:
	var role: String = str(flags.get("role", "旅人"))
	var place: String = str(flags.get("place", "小镇"))
	var prop: String = str(flags.get("prop", "旧物"))
	var evid: String = str(flags.get("evidence", "旧物"))
	var dom := "sci"
	if int(stats.warm) > int(stats.sci) and int(stats.warm) >= int(stats.susp):
		dom = "warm"
	elif int(stats.susp) > int(stats.sci) and int(stats.susp) > int(stats.warm):
		dom = "susp"
	var secret_seg := ""
	match str(flags.get("secret", "")):
		"colony_ship":
			secret_seg = "而后山那道「气闸」终于露出真容——那是一艘伪装成废弃矿场的殖民飞船的登船闸，他没有失踪，他是第一批登船的人。"
		"mine_door":
			secret_seg = "而后山那道「气闸」从未通向星空——它只是矿井时代的防爆隔离门，门后封存着他当年亲手写下的停工真相。"
	match dom:
		"sci":
			return "《回声》终稿：%s带着%s登上离开%s的飞船。舷窗外，%s映着舱内最后一点灯光——那是来自过去的问候，也是写给未来的信。%s" % [role, prop, place, evid, secret_seg]
		"warm":
			return "《归途》终稿：%s回到%s，把%s和%s一起收进老屋的抽屉。灶上的汤还温着，灯为晚归的人亮着——原来最好的结局，是回来吃饭。%s" % [role, place, prop, evid, secret_seg]
		_:
			return "《井底的字条》终稿：多年以后，有人在%s的%s旁发现了新的字条，旁边还压着%s，落款只有一行小字：故事才刚刚开始。%s" % [place, prop, evid, secret_seg]


func _tone_name(key: String) -> String:
	for t in TONE_DEFS:
		if str(t.key) == key:
			return str(t.label)
	return key


func _flag_disp(key: String) -> String:
	return str(FLAG_NAMES.get(key, key))


func _tone_note(tk: String) -> String:
	if tk == "":
		return ""
	return "，%s +1" % _tone_name(tk)


## v2 盲测：基调值 → 低/中/高 三档（与目标门槛 ≥2 对齐）
func tone_tier(v: int) -> String:
	if v <= -1:
		return "低"
	if v >= 2:
		return "高"
	return "中"


## v2 盲测：按当前最高基调给一句氛围反馈
func ambience_text() -> String:
	var sv := int(stats.sci)
	var wv := int(stats.warm)
	var pv := int(stats.susp)
	if sv == 0 and wv == 0 and pv == 0:
		return "墨迹未干，基调尚平"
	var dom := "sci"
	var mv := sv
	if wv > mv:
		dom = "warm"
		mv = wv
	if pv > mv:
		dom = "susp"
		mv = pv
	match dom:
		"sci":
			return "纸页间回响起引擎的低鸣，故事正在离开地面" if mv >= 2 else "笔尖带一点金属的凉意"
		"warm":
			return "字里行间都是灶上热汤的香气" if mv >= 2 else "纸上有一点旧日的暖意"
		_:
			return "故事逐渐显得冰冷而陌生" if mv >= 2 else "某个影子在句子里一闪而过"


func _bump() -> void:
	command_seq += 1
	state_changed.emit(command_seq)
