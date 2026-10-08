extends Control
## 角色（demo-12 v1）：村庄特质沙盒 —— 特质 × 情境 = 涌现社会动态
## 核心循环：给 3 名村民分配特质（8 选 2，不可重复）→ 按序翻 5 张情境卡 →
## 村民按特质自动选择反应位 → 结算声望/压力/村民关系 → 每轮间隙可重分配 1 处特质。
## 特质化学反应：勇敢+好奇=探险家 / 贪婪+暴躁=冲突源 / 慷慨+温和=暖心人 / 胆小+保守=风向标。
## 终局：平均声望 × 暴风雪存活率 → 村庄评级 A/B/C。

const VIEW := Vector2(960, 540)
const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")

## 特质池（8 种）：id 即界面名，color 用于标签与按钮着色，desc 供悬停提示
const TRAITS := [
	{id = "勇敢", color = "e57373", desc = "直面危险，关键时刻冲在最前"},
	{id = "胆小", color = "90a4ae", desc = "先保住自己，危险来时脚步最快"},
	{id = "贪婪", color = "ba68c8", desc = "好东西总想先攥进自己手里"},
	{id = "慷慨", color = "ffb74d", desc = "有好事总想着全村人"},
	{id = "好奇", color = "4fc3f7", desc = "对新鲜事物挪不动脚"},
	{id = "保守", color = "a1887f", desc = "按老规矩办事，稳字当头"},
	{id = "暴躁", color = "ff8a65", desc = "火气一点就着，嗓门大过道理"},
	{id = "温和", color = "aed581", desc = "说话轻，心肠软，肯兜底"},
]

## 特质化学反应：同一村民 2 特质成对时，情境中触发特殊反应位
const CHEM := [
	{id = "explorer", pair = ["勇敢", "好奇"], title = "探险家", desc = "勇敢遇上好奇，眼里只剩没走过的路"},
	{id = "spark", pair = ["贪婪", "暴躁"], title = "冲突源", desc = "贪婪碰上暴躁，一点火星就能烧起来"},
	{id = "hearth", pair = ["慷慨", "温和"], title = "暖心人", desc = "慷慨加上温和，全村炉火都朝向他"},
	{id = "watcher", pair = ["胆小", "保守"], title = "风向标", desc = "胆小加上保守，永远最先嗅到危险"},
]

## 村民名册（3 人开局，特质由玩家分配）
const VILLAGERS := [
	{name = "石头", color = "e5b567"},
	{name = "阿禾", color = "8bc34a"},
	{name = "老周", color = "64b5f6"},
]

## 情境卡（5 张按序翻开）。reactions：8 特质 → 反应位映射；
## 反应位字段：choice 选择文案 / tone 场上基调(warm 热络·neutral 中性·cold 疏离，决定关系) /
## rep 声望增量 / stress 压力增量 / risk 暴风雪存活风险（仅末卡生效，1=走失）。
## chem：化学反应的特殊反应位，broadcast=波及其他村民的压力增量（负值安抚）。
const SITUATIONS := [
	{
		name = "陌生人进村",
		desc = "黄昏时分，一个风尘仆仆的陌生人敲响了村口的锣。他说只是讨口水喝，但没人知道他袋子里装着什么。",
		reactions = {
			"勇敢": {choice = "上前拦住陌生人质问来意", tone = "neutral", rep = 8, stress = -2},
			"胆小": {choice = "躲进屋里闩死了门", tone = "cold", rep = -2, stress = 8},
			"贪婪": {choice = "上下打量陌生人值多少钱", tone = "neutral", rep = 2, stress = 2},
			"慷慨": {choice = "端出热汤请陌生人坐下", tone = "warm", rep = 8, stress = -4},
			"好奇": {choice = "围着陌生人问外面的事", tone = "warm", rep = 6, stress = -2},
			"保守": {choice = "关门闭户只在窗后观望", tone = "cold", rep = 3, stress = 1},
			"暴躁": {choice = "吼着让陌生人赶紧滚", tone = "cold", rep = -4, stress = 6},
			"温和": {choice = "轻声劝大家别吓着客人", tone = "warm", rep = 5, stress = -3},
		},
		chem = {
			explorer = {choice = "拉着陌生人聊外面的地图", tone = "warm", rep = 12, stress = -4, broadcast = 0},
		},
	},
	{
		name = "发现宝藏",
		desc = "河边沙洲上，孩子们挖出一口锈迹斑斑的铁箱。撬开的瞬间，金币的光晃了全村人的眼。",
		reactions = {
			"勇敢": {choice = "自告奋勇守在铁箱旁", tone = "neutral", rep = 6, stress = 2},
			"胆小": {choice = "怕是赃物，躲得远远的", tone = "cold", rep = 0, stress = 4},
			"贪婪": {choice = "抢先把钱袋揣进怀里", tone = "cold", rep = -6, stress = 2},
			"慷慨": {choice = "提议全村按户平分", tone = "warm", rep = 10, stress = -4},
			"好奇": {choice = "研究铁箱的来历和花纹", tone = "neutral", rep = 5, stress = -2},
			"保守": {choice = "坚持上报村长公断", tone = "neutral", rep = 7, stress = -2},
			"暴躁": {choice = "嚷嚷着先到先得", tone = "cold", rep = -5, stress = 6},
			"温和": {choice = "劝大家别为钱财伤了和气", tone = "warm", rep = 6, stress = -3},
		},
		chem = {
			spark = {choice = "煽动众人哄抢铁箱", tone = "cold", rep = -8, stress = 2, broadcast = 8},
			watcher = {choice = "夜里把铁箱悄悄埋回沙里", tone = "neutral", rep = 3, stress = -2, broadcast = 0},
		},
	},
	{
		name = "火灾之夜",
		desc = "后半夜，谷仓方向烧红了半边天。火借风势，眼看要舔到相邻的民居。",
		reactions = {
			"勇敢": {choice = "冲进火场救人", tone = "warm", rep = 12, stress = 6},
			"胆小": {choice = "逃到村外空地瑟瑟发抖", tone = "cold", rep = -4, stress = 10},
			"贪婪": {choice = "顺走邻家没抢出的粮袋", tone = "cold", rep = -8, stress = 2},
			"慷慨": {choice = "把自家的粮和水全搬出来", tone = "warm", rep = 9, stress = 2},
			"好奇": {choice = "站在场边看火势蔓延", tone = "neutral", rep = 0, stress = 6},
			"保守": {choice = "死守自家门窗不让火星进", tone = "cold", rep = -2, stress = 4},
			"暴躁": {choice = "在人群里指骂谁救得慢", tone = "cold", rep = -4, stress = 8},
			"温和": {choice = "把烧伤的人抬去溪边照料", tone = "warm", rep = 10, stress = 2},
		},
		chem = {
			explorer = {choice = "从火场深处抢出村里的粮种", tone = "warm", rep = 12, stress = 8, broadcast = 0},
			hearth = {choice = "在火场外支起粥棚安置灾户", tone = "warm", rep = 12, stress = -4, broadcast = -6},
		},
	},
	{
		name = "粮食短缺",
		desc = "秋收比往年少了一半，粮囤见了底。北风一天紧过一天，村里的炊烟越来越稀。",
		reactions = {
			"勇敢": {choice = "带队翻山去邻村换粮", tone = "warm", rep = 9, stress = 4},
			"胆小": {choice = "缩在家里省着吃", tone = "cold", rep = -2, stress = 8},
			"贪婪": {choice = "夜里偷偷往地窖囤粮", tone = "cold", rep = -8, stress = 2},
			"慷慨": {choice = "开仓把存粮分给各家", tone = "warm", rep = 11, stress = -2},
			"好奇": {choice = "进山试吃野果找新食源", tone = "neutral", rep = 6, stress = 3},
			"保守": {choice = "按人头立下配给规矩", tone = "neutral", rep = 8, stress = 2},
			"暴躁": {choice = "为半袋米和人吵翻了天", tone = "cold", rep = -6, stress = 10},
			"温和": {choice = "把自己的口粮匀给孤老", tone = "warm", rep = 9, stress = -3},
		},
		chem = {
			spark = {choice = "带头冲进粮仓哄抢", tone = "cold", rep = -8, stress = 2, broadcast = 8},
			hearth = {choice = "支起全村的大锅粥棚", tone = "warm", rep = 13, stress = -4, broadcast = -6},
		},
	},
	{
		name = "暴风雪来临",
		desc = "入冬第一场暴风雪比预测的更凶，雪片横着飞。全村人必须在入夜前找到过冬的活法。",
		reactions = {
			"勇敢": {choice = "踏雪为全村探出求生路", tone = "warm", rep = 10, stress = 8, risk = 0},
			"胆小": {choice = "裹紧棉衣守在地窖口", tone = "cold", rep = 2, stress = 10, risk = 0},
			"贪婪": {choice = "守着自家粮仓不肯开门", tone = "cold", rep = -8, stress = 4, risk = 1},
			"慷慨": {choice = "把存货全搬去公用暖房", tone = "warm", rep = 12, stress = 2, risk = 0},
			"好奇": {choice = "观察雪势找出雪隙小道", tone = "neutral", rep = 7, stress = 4, risk = 0},
			"保守": {choice = "早早封存好了过冬粮", tone = "neutral", rep = 9, stress = 2, risk = 0},
			"暴躁": {choice = "雪夜出门寻衅迷了路", tone = "cold", rep = -6, stress = 12, risk = 1},
			"温和": {choice = "挨家敲门扶老弱进暖房", tone = "warm", rep = 11, stress = 2, risk = 0},
		},
		chem = {
			explorer = {choice = "带小队顶风穿越雪线探路", tone = "warm", rep = 12, stress = 6, risk = 0, broadcast = 0},
			hearth = {choice = "拆了自家房梁给暖房生火", tone = "warm", rep = 13, stress = 4, risk = 0, broadcast = -6},
			spark = {choice = "抢占暖房最暖的角落", tone = "cold", rep = -10, stress = 2, risk = 0, broadcast = 8},
			watcher = {choice = "最早发出暴风雪预警", tone = "neutral", rep = 10, stress = -2, risk = 0, broadcast = 0},
		},
	},
]

const RATING_NAMES := {"A": "同心村", "B": "平常村", "C": "散沙村"}
const REP0 := 50     # 初始声望
const STRESS0 := 10  # 初始压力

# —— 运行状态 ——
var state := "setup"           # setup 分配 / story 故事进行 / end 结算
var villagers := []            # {name, traits:[String,String], reputation, stress, burst, left}
var round_idx := 0             # 已翻开的情境卡数
var current_situation := {}    # 最近一张情境卡
var reactions := []            # 最近一次结算 {villager, choice, tone, tone_delta, rep_delta, stress_delta, ...}
var relations := {}            # "i-j" → int 村民关系值
var events := []               # 事件流水
var redo_used := 0             # 本轮已用重分配次数（每轮 1 次）
var selected := -1             # 选中的村民
var selected_slot := 0         # 选中的特质槽

# —— UI 引用 ——
var status_label: Label
var sit_title: Label
var sit_desc: Label
var react_label: Label
var events_label: Label
var trait_buttons := []
var villager_buttons := []
var btn_action: Button
var end_panel: Panel
var end_title: Label
var end_body: Label


func _ready() -> void:
	_build_ui()
	start_game()
	queue_redraw()


# ===================== 公开 API（供测试与 UI） =====================

func start_game() -> void:
	villagers = []
	for i in VILLAGERS.size():
		villagers.append({
			name = VILLAGERS[i].name,
			traits = ["", ""],
			reputation = REP0,
			stress = STRESS0,
			burst = false,
			left = false,
		})
	round_idx = 0
	current_situation = {}
	reactions = []
	relations = {"0-1": 0, "0-2": 0, "1-2": 0}
	events = []
	redo_used = 0
	selected = -1
	selected_slot = 0
	state = "setup"
	end_panel.visible = false
	_refresh_ui()
	queue_redraw()


## 开局分配：仅 setup 阶段可用；同一村民两槽不可重复同特质
func assign_trait(villager_idx: int, slot: int, trait_id: String) -> bool:
	if state != "setup":
		return false
	return _set_trait(villager_idx, slot, trait_id)


## 重新分配：仅 story 阶段（翻卡后）可用，每轮限 1 次
func redistribute(villager_idx: int, slot: int, new_trait: String) -> bool:
	if state != "story" or redo_used >= 1:
		return false
	var ok := _set_trait(villager_idx, slot, new_trait)
	if ok:
		redo_used += 1
		events.append("重新分配：%s 的特质改为「%s」。" % [villagers[villager_idx].name, new_trait])
		_refresh_ui()
		queue_redraw()
	return ok


## 翻开下一张情境卡并自动结算全部村民反应，返回情境名（卡池翻尽返回空串）
func draw_situation() -> String:
	if round_idx >= SITUATIONS.size():
		return ""
	var sit: Dictionary = SITUATIONS[round_idx]
	current_situation = sit
	state = "story"
	redo_used = 0
	reactions = []
	# 1) 每个村民按特质（或化学反应）自动选择反应位
	for i in villagers.size():
		var v: Dictionary = villagers[i]
		var act: Dictionary = _resolve(v, sit)
		reactions.append({
			villager = v.name,
			villager_idx = i,
			choice = act.choice,
			tone = act.tone,
			tone_delta = _tone_mark(act.tone),
			rep_delta = int(act.rep),
			stress_delta = int(act.stress),
			risk = int(act.risk),
			broadcast = int(act.broadcast),
			chem = act.chem,
		})
	# 2) 落账声望/压力
	for r in reactions:
		var v2: Dictionary = villagers[int(r.villager_idx)]
		v2.reputation = clampi(int(v2.reputation) + int(r.rep_delta), 0, 100)
		v2.stress = clampi(int(v2.stress) + int(r.stress_delta), 0, 100)
	# 3) 化学反应波及：冲突源给他人加压，暖心人安抚他人
	for r in reactions:
		var bc := int(r.broadcast)
		if bc == 0:
			continue
		for j in villagers.size():
			if j != int(r.villager_idx):
				var vo: Dictionary = villagers[j]
				vo.stress = clampi(int(vo.stress) + bc, 0, 100)
	# 4) 关系涌现：同场基调相容 → 关系+，冲突 → 关系-
	for a in villagers.size():
		for b in range(a + 1, villagers.size()):
			var key := "%d-%d" % [a, b]
			var d := _compat(reactions[a].tone, reactions[b].tone)
			relations[key] = clampi(int(relations.get(key, 0)) + d, -100, 100)
	# 5) 末卡暴风雪：risk=1 者走失（存活率）
	if round_idx == SITUATIONS.size() - 1:
		for r in reactions:
			var vl: Dictionary = villagers[int(r.villager_idx)]
			if int(r.risk) == 1:
				vl.left = true
				events.append("%s 在暴风雪夜里走失了，再没回来。" % vl.name)
			else:
				events.append("%s 平安熬过了暴风雪。" % vl.name)
	# 6) 压力爆发：压力满格者失态，声望受损并波及他人
	for i in villagers.size():
		var vb: Dictionary = villagers[i]
		if int(vb.stress) >= 100 and not vb.burst:
			vb.burst = true
			vb.reputation = clampi(int(vb.reputation) - 10, 0, 100)
			vb.stress = 55
			events.append("%s 压力爆发，在晒谷场失态大吼，声望受损。" % vb.name)
			for j in villagers.size():
				if j != i:
					var vo2: Dictionary = villagers[j]
					vo2.stress = clampi(int(vo2.stress) + 5, 0, 100)
	round_idx += 1
	if round_idx >= SITUATIONS.size():
		state = "end"
		_show_end()
	_refresh_ui()
	queue_redraw()
	return sit.name


## 村庄评级：平均声望 × 暴风雪存活率 → A / B / C（未翻完返回空串）
func village_rating() -> String:
	if round_idx < SITUATIONS.size():
		return ""
	var total := 0
	var left_n := 0
	for v in villagers:
		total += int(v.reputation)
		if v.left:
			left_n += 1
	var avg := float(total) / float(villagers.size())
	var alive := float(villagers.size() - left_n) / float(villagers.size())
	var score := avg * alive
	if score >= 40.0:
		return "A"
	if score < 20.0:
		return "C"
	return "B"


# ===================== 结算内核 =====================

func _set_trait(villager_idx: int, slot: int, trait_id: String) -> bool:
	if villager_idx < 0 or villager_idx >= villagers.size():
		return false
	if slot != 0 and slot != 1:
		return false
	var valid := false
	for t in TRAITS:
		if t.id == trait_id:
			valid = true
			break
	if not valid:
		return false
	var v: Dictionary = villagers[villager_idx]
	var other := 1 - slot
	if v.traits[other] == trait_id:
		return false
	v.traits[slot] = trait_id
	return true


## 反应位解析优先级：化学反应特殊位 > 槽位 0 特质 > 槽位 1 特质 > 观望兜底
func _resolve(v: Dictionary, sit: Dictionary) -> Dictionary:
	var chem_id := _chem_of(v)
	if chem_id != "" and sit.chem.has(chem_id):
		var c: Dictionary = sit.chem[chem_id]
		return {
			choice = c.choice,
			tone = c.tone,
			rep = int(c.rep),
			stress = int(c.stress),
			risk = int(c.get("risk", 0)),
			broadcast = int(c.get("broadcast", 0)),
			chem = chem_id,
		}
	var traits: Array = v.traits
	for t in traits:
		if sit.reactions.has(t):
			var r: Dictionary = sit.reactions[t]
			return {
				choice = r.choice,
				tone = r.tone,
				rep = int(r.rep),
				stress = int(r.stress),
				risk = int(r.get("risk", 0)),
				broadcast = 0,
				chem = "",
			}
	return {choice = "静静观望", tone = "neutral", rep = 0, stress = 2, risk = 0, broadcast = 0, chem = ""}


func _chem_of(v: Dictionary) -> String:
	var traits: Array = v.traits
	if traits.size() < 2:
		return ""
	for ch in CHEM:
		var p: Array = ch.pair
		if (p[0] == traits[0] and p[1] == traits[1]) or (p[1] == traits[0] and p[0] == traits[1]):
			return ch.id
	return ""


func _chem_title(chem_id: String) -> String:
	for ch in CHEM:
		if ch.id == chem_id:
			return ch.title
	return ""


## 基调相容度：warm/warm=+3，warm/neutral 与 neutral/neutral=+1，cold/cold=-2，
## warm/cold=-3，neutral/cold=-2
func _compat(ta: String, tb: String) -> int:
	if ta == "warm" and tb == "warm":
		return 3
	if ta == "cold" and tb == "cold":
		return -2
	if (ta == "warm" and tb == "cold") or (ta == "cold" and tb == "warm"):
		return -3
	if ta == "cold" or tb == "cold":
		return -2
	return 1


func _tone_mark(t: String) -> int:
	if t == "warm":
		return 1
	if t == "cold":
		return -1
	return 0


func _trait_color(t: String) -> Color:
	for tr in TRAITS:
		if tr.id == t:
			return Color(tr.color)
	return Color("8b94a7")


func _trait_name(t: String) -> String:
	return t if t != "" else "未定"


func _relations_text() -> String:
	var parts := ""
	for key in ["0-1", "0-2", "1-2"]:
		var bits: PackedStringArray = key.split("-")
		parts += "%s-%s %+d · " % [villagers[int(bits[0])].name, villagers[int(bits[1])].name, int(relations.get(key, 0))]
	return parts.trim_suffix(" · ")


# ===================== UI =====================

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "角色 · 村庄特质沙盒（demo-12 v1）"
	title.position = Vector2(16, 8)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("e5e9f0"))
	ui.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(16, 36)
	status_label.size = Vector2(930, 24)
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color("9aa3b5"))
	ui.add_child(status_label)
	# 村民卡点击层（卡面由 _draw 程序绘制）
	for i in VILLAGERS.size():
		var vb := Button.new()
		vb.name = "VillagerBtn%d" % i
		vb.flat = true
		vb.position = Vector2(16, 64 + i * 118)
		vb.size = Vector2(548, 110)
		vb.pressed.connect(_on_villager.bind(i))
		ui.add_child(vb)
		villager_buttons.append(vb)
	# 右侧情境面板
	var panel := Panel.new()
	panel.name = "SitPanel"
	panel.position = Vector2(588, 64)
	panel.size = Vector2(360, 396)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	sb.border_color = Color(0.35, 0.33, 0.42)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	ui.add_child(panel)
	sit_title = Label.new()
	sit_title.name = "SitTitle"
	sit_title.position = Vector2(14, 10)
	sit_title.size = Vector2(332, 24)
	sit_title.add_theme_font_size_override("font_size", 17)
	sit_title.add_theme_color_override("font_color", Color("ffd54f"))
	panel.add_child(sit_title)
	sit_desc = Label.new()
	sit_desc.name = "SitDesc"
	sit_desc.position = Vector2(14, 40)
	sit_desc.size = Vector2(332, 92)
	sit_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sit_desc.add_theme_font_size_override("font_size", 13)
	sit_desc.add_theme_color_override("font_color", Color("c5cddc"))
	panel.add_child(sit_desc)
	react_label = Label.new()
	react_label.name = "ReactLabel"
	react_label.position = Vector2(14, 138)
	react_label.size = Vector2(332, 248)
	react_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	react_label.add_theme_font_size_override("font_size", 12)
	react_label.add_theme_color_override("font_color", Color("d7dee8"))
	panel.add_child(react_label)
	# 左下事件流水
	events_label = Label.new()
	events_label.name = "EventsLabel"
	events_label.position = Vector2(16, 414)
	events_label.size = Vector2(548, 56)
	events_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	events_label.add_theme_font_size_override("font_size", 12)
	events_label.add_theme_color_override("font_color", Color("9aa3b5"))
	ui.add_child(events_label)
	# 底部特质池 + 行动按钮
	for i in TRAITS.size():
		var tb := Button.new()
		tb.name = "TraitBtn%d" % i
		tb.text = TRAITS[i].id
		tb.position = Vector2(16 + i * 89, 484)
		tb.size = Vector2(84, 44)
		var tcol := Color(TRAITS[i].color)
		for cname in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			tb.add_theme_color_override(cname, tcol)
		tb.add_theme_color_override("font_disabled_color", Color(tcol, 0.35))
		tb.pressed.connect(_on_trait.bind(i))
		tb.mouse_entered.connect(_on_trait_hover.bind(i))
		tb.mouse_exited.connect(_refresh_ui)
		ui.add_child(tb)
		trait_buttons.append(tb)
	btn_action = Button.new()
	btn_action.name = "ActionBtn"
	btn_action.text = "翻开第一张情境卡"
	btn_action.position = Vector2(736, 484)
	btn_action.size = Vector2(208, 44)
	btn_action.pressed.connect(_on_action)
	ui.add_child(btn_action)
	# 结算面板
	end_panel = Panel.new()
	end_panel.name = "EndPanel"
	end_panel.position = Vector2(230, 84)
	end_panel.size = Vector2(500, 368)
	var eb := StyleBoxFlat.new()
	eb.bg_color = Color(0.09, 0.09, 0.13, 0.97)
	eb.border_color = Color(0.55, 0.45, 0.25)
	eb.set_border_width_all(2)
	eb.set_corner_radius_all(10)
	end_panel.add_theme_stylebox_override("panel", eb)
	end_panel.visible = false
	ui.add_child(end_panel)
	end_title = Label.new()
	end_title.name = "EndTitle"
	end_title.position = Vector2(22, 14)
	end_title.add_theme_font_size_override("font_size", 24)
	end_title.add_theme_color_override("font_color", Color("ffd54f"))
	end_panel.add_child(end_title)
	end_body = Label.new()
	end_body.name = "EndBody"
	end_body.position = Vector2(22, 52)
	end_body.size = Vector2(456, 252)
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_body.add_theme_font_size_override("font_size", 13)
	end_body.add_theme_color_override("font_color", Color("d7dee8"))
	end_panel.add_child(end_body)
	var rb := Button.new()
	rb.name = "RestartBtn"
	rb.text = "再来一局"
	rb.position = Vector2(22, 314)
	rb.size = Vector2(150, 38)
	rb.pressed.connect(_on_restart)
	end_panel.add_child(rb)


func _refresh_ui() -> void:
	if state == "setup":
		status_label.text = "开局：点村民卡选中（再点一次切换特质槽），再点下方特质分配——每村 2 个不同特质"
	elif state == "story":
		status_label.text = "第 %d/5 张卡已结算 · 重分配额度剩 %d 次：选中村民与槽位后点特质，适应下一张卡" % [round_idx, 1 - redo_used]
	else:
		status_label.text = "五张情境卡翻完，村庄这一季落幕——结算面板见评级"
	btn_action.disabled = state == "end"
	if state == "setup":
		btn_action.text = "翻开第一张情境卡"
	elif state == "story":
		btn_action.text = "翻开下一张情境卡"
	else:
		btn_action.text = "本季已结束"
	for b in trait_buttons:
		b.disabled = state == "end"
	if current_situation.is_empty():
		sit_title.text = "情境卡待翻开"
		sit_desc.text = "村民会按各自特质自动选择反应：特质与情境相投则声望上升，卷入冲突则压力上升。"
		react_label.text = ""
		events_label.text = ""
	else:
		sit_title.text = "第 %d 张 · %s" % [round_idx, current_situation.name]
		sit_desc.text = current_situation.desc
		var lines := ""
		for r in reactions:
			lines += "%s：%s\n    望%+d 压%+d 基调%+d\n" % [r.villager, r.choice, r.rep_delta, r.stress_delta, r.tone_delta]
		lines += "（基调：+ 热络助关系，- 疏离损关系）\n"
		lines += "村民关系：%s" % _relations_text()
		react_label.text = lines
		var ev := ""
		var start_i: int = maxi(0, events.size() - 2)
		for k in range(start_i, events.size()):
			ev += events[k] + "\n"
		events_label.text = ev


func _show_end() -> void:
	var rating := village_rating()
	var rname: String = RATING_NAMES.get(rating, "")
	end_title.text = "村庄评级 %s · %s" % [rating, rname]
	var col := Color("cfd8dc")
	if rating == "A":
		col = Color("ffd54f")
	elif rating == "C":
		col = Color("e57373")
	end_title.add_theme_color_override("font_color", col)
	var left_n := 0
	for v in villagers:
		if v.left:
			left_n += 1
	var body := "评级依据：平均声望 × 暴风雪存活率（走失 %d 人）。\n" % left_n
	for i in villagers.size():
		var v: Dictionary = villagers[i]
		var chem := _chem_of(v)
		var chem_txt := ""
		if chem != "":
			chem_txt = " 「%s」" % _chem_title(chem)
		var marks := ""
		if v.burst:
			marks += " 曾压力爆发"
		if v.left:
			marks += " 已走失"
		body += "%s 特质[%s|%s]%s 望 %d 压 %d%s\n" % [
			v.name, _trait_name(v.traits[0]), _trait_name(v.traits[1]), chem_txt, v.reputation, v.stress, marks]
	body += "\n—— 事件回放 ——\n"
	var start_i: int = maxi(0, events.size() - 5)
	for k in range(start_i, events.size()):
		body += "· " + events[k] + "\n"
	end_body.text = body
	end_panel.visible = true


func _on_villager(i: int) -> void:
	if state == "end":
		return
	if selected == i:
		selected_slot = 1 - selected_slot
	else:
		selected = i
		selected_slot = 0
	_refresh_ui()
	queue_redraw()


func _on_trait(i: int) -> void:
	if state == "end" or selected < 0:
		return
	var tname: String = TRAITS[i].id
	if state == "setup":
		assign_trait(selected, selected_slot, tname)
	else:
		redistribute(selected, selected_slot, tname)
	_refresh_ui()
	queue_redraw()


func _on_trait_hover(i: int) -> void:
	status_label.text = "特质「%s」：%s" % [TRAITS[i].id, TRAITS[i].desc]


func _on_action() -> void:
	if state == "end":
		return
	draw_situation()


func _on_restart() -> void:
	start_game()


# ===================== 程序绘制 =====================

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color("2b2a33"))
	draw_rect(Rect2(0, 40, 576, 500), Color("31323b"))
	draw_rect(Rect2(576, 40, 384, 500), Color("35323c"))
	for i in villagers.size():
		_draw_villager_card(i)
	draw_rect(Rect2(8, 476, 944, 60), Color("2f2f38"))


func _draw_villager_card(i: int) -> void:
	var pos := Vector2(16, 64 + i * 118)
	var sz := Vector2(548, 110)
	var v: Dictionary = villagers[i]
	var sel: bool = i == selected
	draw_rect(Rect2(pos, sz), Color("46516e") if sel else Color("3d4250"))
	draw_rect(Rect2(pos, sz), Color(VILLAGERS[i].color), false, 2.0)
	# 名字 + 化学称号
	draw_string(FONT, pos + Vector2(14, 26), v.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(VILLAGERS[i].color))
	var chem := _chem_of(v)
	if chem != "":
		draw_string(FONT, pos + Vector2(84, 26), "「%s」%s" % [_chem_title(chem), _chem_desc(chem)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffd54f"))
	else:
		draw_string(FONT, pos + Vector2(84, 26), "（特质未成化学反应）", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("6f7787"))
	# 两个特质槽标签
	for k in 2:
		var tpos := pos + Vector2(14 + k * 150, 38)
		var tname: String = v.traits[k]
		var tag_col := Color("262a33")
		var txt_col := Color("8b94a7")
		var label := "槽位%d 空（点击选）" % (k + 1)
		if tname != "":
			var tcol := _trait_color(tname)
			tag_col = tcol.darkened(0.6)
			txt_col = tcol
			label = "槽位%d %s" % [k + 1, tname]
		if sel and selected_slot == k:
			draw_rect(Rect2(tpos - Vector2(3, 3), Vector2(144, 28)), Color("ffd54f"), false, 2.0)
		draw_rect(Rect2(tpos, Vector2(138, 22)), tag_col)
		draw_string(FONT, tpos + Vector2(6, 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, txt_col)
	# 声望/压力条
	var rep: int = v.reputation
	var stress: int = v.stress
	draw_string(FONT, pos + Vector2(14, 84), "望", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("9ccc65"))
	draw_rect(Rect2(pos + Vector2(40, 74), Vector2(300, 12)), Color("22242c"))
	draw_rect(Rect2(pos + Vector2(40, 74), Vector2(300.0 * rep / 100.0, 12)), Color("7cb342"))
	draw_string(FONT, pos + Vector2(348, 84), "%d" % rep, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c5cddc"))
	draw_string(FONT, pos + Vector2(14, 104), "压", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ef9a9a"))
	draw_rect(Rect2(pos + Vector2(40, 94), Vector2(300, 12)), Color("22242c"))
	draw_rect(Rect2(pos + Vector2(40, 94), Vector2(300.0 * stress / 100.0, 12)), Color("e57373"))
	draw_string(FONT, pos + Vector2(348, 104), "%d" % stress, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c5cddc"))
	# 爆发/走失标记 + 与另外两人的关系值
	var marks := ""
	if v.burst:
		marks += "爆发 "
	if v.left:
		marks += "走失"
	if marks != "":
		draw_string(FONT, pos + Vector2(388, 26), marks, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ff8a65"))
	draw_string(FONT, pos + Vector2(388, 50), "关系", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("6f7787"))
	var ry := 68.0
	for key in ["0-1", "0-2", "1-2"]:
		var bits: PackedStringArray = key.split("-")
		if int(bits[0]) != i and int(bits[1]) != i:
			continue
		var other: int = int(bits[0]) if int(bits[0]) != i else int(bits[1])
		var rv: int = int(relations.get(key, 0))
		draw_string(FONT, pos + Vector2(388, ry), "%s %+d" % [villagers[other].name, rv], HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color("9ccc65") if rv >= 0 else Color("e57373"))
		ry += 16.0


func _chem_desc(chem_id: String) -> String:
	for ch in CHEM:
		if ch.id == chem_id:
			return ch.desc
	return ""
