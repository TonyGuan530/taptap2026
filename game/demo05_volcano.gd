extends Control
## 重生之我是恐龙·火山生存（demo-05 v2）
## 现代人意识穿越成恐龙：火山爆发前探索规划、分散储备资源；
## 灾后风向/降雨决定火山灰、泥流、燃烧、污染的连锁变化；最后选择撤离路线。
## v2（ChatGPT 监督评审 ITERATE 三建议）：
##   1. 区域收益×风险——特产倍率让「平均分散」产生机会成本
##   2. 灾后一次应急行动（抢运/侦察/轻装）——灾害结算在行动之后，重构方案能改写结局
##   3. 不完全天气预报——高地哨兵可确认情报，信息→判断→风险承担
## 对应 Miro 玩法块 demo-05。纯代码实现、无外部资源。

const VIEW := Vector2(960, 540)
const FONT: FontFile = preload("res://fonts/NotoSansSC.ttf")

const PHASE1_TIME := 28.0
const ADJUST_TIME := 15.0

## 地块：名称/位置/风险/特产（每次存入的产出与灾害结果，存 1 次 = 基础食1水1 + 特产）
const TILES := [
	{id = "highland", name = "高地", x = 90, y = 130, risk = "东风灰·减半", has = "哨兵准·行军-1", cap = 6},
	{id = "valley", name = "河谷", x = 390, y = 130, risk = "暴雨泥流·全吞", has = "存1次=食1水2"},
	{id = "forest", name = "森林", x = 690, y = 130, risk = "暴雨燃烧·损75%", has = "存1次=食2水1"},
	{id = "cave", name = "洞穴", x = 240, y = 300, risk = "全灾害免疫", has = "撤离额外耗食1水1", cap = 10},
	{id = "wetland", name = "湿地", x = 540, y = 300, risk = "暴雨·水污染减半", has = "存1次25%+1食1水"},
]
## 撤离路线（need 会被高地 -1 / 轻装 -2 修正）；v4 压力曲线（sweep combo0，2026-10-03）
const ROUTES := [
	{name = "北线·翻山", risk = "耗体力大，但远离灰区", need = 12},
	{name = "东线·沿河", risk = "快，但可能遇泥流改道", need = 14},
	{name = "南线·密林", risk = "食物多，慢，易迷路", need = 16},
]
## 灾后应急行动（仅一次）
const ADJUST_CARDS := [
	{id = "relocate", name = "抢运储备", desc = "点选后再点一个地块：其储备转入洞穴（洒落25%）"},
	{id = "scout", name = "侦察路线", desc = "耗储备食1水1：路线随机风险全部确定化"},
	{id = "abandon", name = "轻装奔袭", desc = "耗储备食1水1：全部路线需求-2"},
	{id = "skip", name = "按兵不动", desc = "不做应急，按原计划硬扛"},
]

var phase := "prepare"        # prepare / announce / adjust / resolve / decide / end
var timer := PHASE1_TIME
var adjust_timer := ADJUST_TIME
var gather := 0
var stored := {}              # tileId -> {food, water}
var supply := {food = 3, water = 3}
var pending_wind := ""        # 真实风向（准备期已注定）
var pending_rain := false
var forecast_wind := ""       # 萨满预报（可能说反）
var forecast_rain := false
var wind := ""
var rain := false
var emergency := ""           # 已用应急行动 id，""=未用
var relocating := false       # 抢运模式：等待点选地块
var scouted := false
var route_bonus := 0          # 撤离需求修正：高地 -1 / 轻装 -2
var events := []              # 末日故事事件链
var route_chosen := -1
var margin := 0               # v6 A'：撤离余量 = 行军消耗后剩余物资（结算评分用）
var result := ""
var pulse := 0.0
var hovered := -1
var toast := ""
var toast_age := 99.0

var status_label: Label
var forecast_label: Label
var hint_label: Label
var end_panel: Panel
var end_body: Label


func _ready() -> void:
	for t in TILES:
		stored[t.id] = {food = 0, water = 0}
	_roll_forecast()
	_build_ui()
	# 采集计时：每 4 秒 +1 采集点
	var timer_node := Timer.new()
	timer_node.wait_time = 4.0
	timer_node.timeout.connect(_gather_tick)
	add_child(timer_node)
	timer_node.start()
	queue_redraw()


func _roll_forecast() -> void:
	pending_wind = "east" if randf() < 0.5 else "west"
	pending_rain = randf() < 0.6
	# 预报 75% 说真话；高地有储备时 UI 直接显示真值（哨兵确认）
	forecast_wind = pending_wind if randf() < 0.75 else ("west" if pending_wind == "east" else "east")
	forecast_rain = pending_rain if randf() < 0.75 else (not pending_rain)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "重生之我是恐龙 · 火山生存（demo-05）"
	title.position = Vector2(16, 8)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("ffd54f"))
	ui.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(16, 38)
	status_label.size = Vector2(920, 26)
	status_label.add_theme_font_size_override("font_size", 14)
	ui.add_child(status_label)
	forecast_label = Label.new()
	forecast_label.position = Vector2(16, 62)
	forecast_label.size = Vector2(920, 24)
	forecast_label.add_theme_font_size_override("font_size", 13)
	forecast_label.add_theme_color_override("font_color", Color("ce93d8"))
	ui.add_child(forecast_label)
	hint_label = Label.new()
	hint_label.position = Vector2(16, VIEW.y - 30)
	hint_label.size = Vector2(600, 26)
	hint_label.add_theme_font_size_override("font_size", 14)
	ui.add_child(hint_label)
	# 结算面板
	end_panel = Panel.new()
	end_panel.name = "EndPanel"
	end_panel.position = Vector2(130, 60)
	end_panel.size = Vector2(700, 420)
	end_panel.visible = false
	ui.add_child(end_panel)
	var et := Label.new()
	et.text = "🌋 末日故事"
	et.position = Vector2(20, 12)
	et.add_theme_font_size_override("font_size", 20)
	et.add_theme_color_override("font_color", Color("ffd54f"))
	end_panel.add_child(et)
	end_body = Label.new()
	end_body.name = "Body"
	end_body.position = Vector2(20, 50)
	end_body.size = Vector2(660, 300)
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_body.add_theme_font_size_override("font_size", 13)
	end_panel.add_child(end_body)
	var again := Button.new()
	again.text = "再来一次"
	again.position = Vector2(20, 368)
	again.size = Vector2(150, 36)
	again.pressed.connect(_restart)
	end_panel.add_child(again)


func _set_status(t: String) -> void:
	if status_label:
		status_label.text = t


func _set_hint(t: String) -> void:
	if hint_label:
		hint_label.text = t


func _toast(t: String) -> void:
	toast = t
	toast_age = 0.0


func _log_ev(t: String) -> void:
	events.append(t)


func _tile_total(id: String) -> int:
	return int(stored[id].food) + int(stored[id].water)


func _forecast_text() -> String:
	var wind_side := "西侧·高地河谷" if forecast_wind == "east" else "东侧·森林湿地"
	var rain_pct := "七成" if forecast_rain else "三成"
	return "萨满预言：火山灰将罩住%s · 降雨概率约%s" % [wind_side, rain_pct]


func _restart() -> void:
	phase = "prepare"
	timer = PHASE1_TIME
	adjust_timer = ADJUST_TIME
	gather = 0
	supply = {food = 3, water = 3}
	emergency = ""
	relocating = false
	scouted = false
	route_bonus = 0
	events = []
	route_chosen = -1
	for t in TILES:
		stored[t.id] = {food = 0, water = 0}
	_roll_forecast()
	end_panel.visible = false
	queue_redraw()


# ---------------- 交互 ----------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		if phase == "prepare":
			for i in TILES.size():
				var t: Dictionary = TILES[i]
				if Rect2(t.x, t.y, 160, 96).has_point(pos):
					_on_tile_click(i)
					return
		elif phase == "adjust" and emergency == "":
			for i in ADJUST_CARDS.size():
				if Rect2(60 + i * 215, 310, 200, 120).has_point(pos):
					_use_emergency(ADJUST_CARDS[i].id)
					return
			if relocating:
				for i in TILES.size():
					var t: Dictionary = TILES[i]
					if Rect2(t.x, t.y, 160, 96).has_point(pos):
						_do_relocate(i)
						return
		elif phase == "decide" and route_chosen == -1:
			for i in ROUTES.size():
				if Rect2(60 + i * 290, 300, 270, 120).has_point(pos):
					_choose_route(i)
					return


func _on_tile_click(i: int) -> void:
	var t: Dictionary = TILES[i]
	if gather <= 0:
		_toast("没有可存放的采集点（每 4 秒 +1）")
		return
	gather -= 1
	var f := 1
	var w := 1
	var bonus := ""
	match t.id:
		"valley":
			w = 2
		"forest":
			f = 2
		"wetland":
			if randf() < 0.25:
				f += 1
				w += 1
				bonus = "（发现小动物群 +1食1水！）"
	stored[t.id].food += f
	stored[t.id].water += w
	_toast("存入「%s」：食%d 水%d%s" % [t.name, f, w, bonus])


# ---------------- 主循环 ----------------

func _process(delta: float) -> void:
	pulse += delta * 4.0
	toast_age += delta
	if phase == "prepare":
		timer -= delta
		var sentinel: bool = _tile_total("highland") > 0
		forecast_label.text = _forecast_text() + ("　✅ 高地哨兵确认：情报准确" if sentinel else "　（把储备存到高地可确认情报）")
		_set_status("【准备期】剩余 %d 秒 · 采集点 %d（点击地块存放，各地块特产不同）· 已存 %d 份" % [int(timer), gather, _all_stored()])
		_set_hint("押特产（河谷水×2/森林食×2）有灾变风险；洞穴免灾但撤离要交税——别再无脑平分了！")
		if timer <= 0.0:
			_announce_disaster()
	elif phase == "announce":
		forecast_label.text = ""
		_set_status("【灾变】火山爆发！风向：%s%s——灾害即将落地，准备应变！" % [("东风，灰罩西侧" if wind == "east" else "西风，灰罩东侧"), ("，暴雨如注" if rain else "，天干物燥")])
		_set_hint("萨满的预言应验了吗？")
	elif phase == "adjust":
		adjust_timer -= delta
		_set_status("【灾后应变】剩余 %d 秒 · 应急行动仅一次%s" % [int(maxf(0.0, adjust_timer)), ("（已决定：" + _emergency_name() + "）") if emergency != "" else ""])
		_set_hint("世界已经变了——原计划还成立吗？抢运/侦察/轻装，或按兵不动。" if relocating == false else "抢运模式：点击一个地块，把它的储备转入洞穴")
		if adjust_timer <= 0.0 and emergency == "":
			emergency = "skip"
			_log_ev("族群在轰鸣声里犹豫不决，宝贵的时间白白流走——只能按原计划硬扛。")
			_end_adjust()
	elif phase == "resolve":
		_set_status("【灾害结算】连锁灾难正在发生……")
		_set_hint("看看布局付出了什么代价。")
	elif phase == "decide":
		_set_status("【撤离】选择路线带领族群离开灾区")
		_set_hint("需求%d已被修正（高地-1/轻装-2）。路线随机风险：侦察过就不再是赌博。" % (4 + route_bonus) if route_bonus != 0 else "各路线有随机风险，侦察过就不再是赌博。")
	queue_redraw()


func _emergency_name() -> String:
	for c in ADJUST_CARDS:
		if c.id == emergency:
			return c.name
	return emergency


func _gather_tick() -> void:
	if phase == "prepare":
		gather += 1


func _all_stored() -> int:
	var n := 0
	for k in stored:
		n += int(stored[k].food)
	return n


# ---------------- 灾变与应变 ----------------

func _announce_disaster() -> void:
	phase = "announce"
	wind = pending_wind
	rain = pending_rain
	_log_ev("火山在午后爆发，蘑菇云遮住了太阳。当晚刮起了%s。" % ("东风" if wind == "east" else "西风"))
	if rain:
		_log_ev("深夜开始下暴雨，河水浑浊上涨。")
	else:
		_log_ev("空气干燥得可怕，火星随风飘散。")
	var t := get_tree().create_timer(2.5)
	t.timeout.connect(_enter_adjust)


func _enter_adjust() -> void:
	phase = "adjust"
	adjust_timer = ADJUST_TIME
	queue_redraw()


func _use_emergency(action: String) -> void:
	if phase != "adjust" or emergency != "":
		return
	if action == "relocate":
		relocating = true
		_toast("抢运模式：点击一个地块，把储备转入洞穴（洒落25%）")
		return
	if action == "scout":
		if not _pay_storage(1, 1):
			_toast("储备不足（需食1水1）")
			return
		scouted = true
		emergency = "scout"
		_log_ev("族群派斥候冒死探路，把每条路线的凶险摸得一清二楚——接下来的行军不再是赌博。")
	elif action == "abandon":
		if not _pay_storage(1, 1):
			_toast("储备不足（需食1水1）")
			return
		route_bonus -= 2
		emergency = "abandon"
		_log_ev("族群扔下沉重的行囊轻装奔袭，所有路线的行军需求降低了。")
	elif action == "skip":
		emergency = "skip"
		_log_ev("族群按兵不动，按原计划硬扛灾变。")
	_end_adjust()


func _do_relocate(i: int) -> void:
	var t: Dictionary = TILES[i]
	if t.id == "cave":
		_toast("洞穴本身就是目的地，不用抢运")
		return
	var s: Dictionary = stored[t.id]
	if _tile_total(t.id) <= 0:
		_toast("「%s」没有储备可抢运" % t.name)
		return
	var f2: int = int(s.food * 3 / 4.0)
	var w2: int = int(s.water * 3 / 4.0)
	stored.cave.food += f2
	stored.cave.water += w2
	stored[t.id] = {food = 0, water = 0}
	emergency = "relocate"
	relocating = false
	_log_ev("大地轰鸣，族群冒死把「%s」的储备抢运进洞穴，路上洒落了四分之一。" % t.name)
	_end_adjust()


func _pay_storage(f: int, w: int) -> bool:
	# 从存量最多的地块扣
	var best := ""
	var best_n := -1
	for k in stored:
		if _tile_total(k) > best_n:
			best_n = _tile_total(k)
			best = k
	if best == "" or int(stored[best].food) < f or int(stored[best].water) < w:
		return false
	stored[best].food -= f
	stored[best].water -= w
	return true


func _end_adjust() -> void:
	phase = "resolve"
	_resolve_disaster()
	var t := get_tree().create_timer(2.5)
	t.timeout.connect(_enter_decide)


func _resolve_disaster() -> void:
	# 预报对照
	var wind_ok := forecast_wind == wind
	var rain_ok := forecast_rain == rain
	if wind_ok and rain_ok:
		_log_ev("萨满的预言应验了——族群早有准备。")
	elif not wind_ok and not rain_ok:
		_log_ev("萨满的预言全错了！风向和降雨都与预想相反，准备期押错了方向。")
	else:
		_log_ev("萨满的预言只对了一半——%s与预想相反。" % ("风向" if not wind_ok else "降雨"))
	# 下风侧灰覆盖，储备减半（洞穴免疫）
	var downwind_ids: Array = ["forest", "wetland"] if wind == "west" else ["highland", "valley"]
	_log_ev("火山灰顺风覆盖了%s和%s，那里的储备损失了一半。" % [_tile_name(downwind_ids[0]), _tile_name(downwind_ids[1])])
	for id in downwind_ids:
		stored[id].food = int(stored[id].food / 2.0)
		stored[id].water = int(stored[id].water / 2.0)
	if rain:
		_log_ev("河谷暴发泥流，河谷的储备被吞掉一半。")
		stored.valley.food = int(stored.valley.food / 2.0)
		stored.valley.water = int(stored.valley.water / 2.0)
		_log_ev("湿地的水被灰烬污染，短期无法饮用。")
		stored.wetland.water = int(stored.wetland.water / 2.0)
		_log_ev("森林被雷火点燃，储备大半化为灰烬，只抢回四分之一。")
		stored.forest.food = int(stored.forest.food / 4.0)
		stored.forest.water = int(stored.forest.water / 4.0)
	else:
		_log_ev("森林侥幸未燃，食物安然无恙——押注森林的族群赌赢了。")


func _tile_name(id: String) -> String:
	for t in TILES:
		if t.id == id:
			return t.name
	return id


func _enter_decide() -> void:
	phase = "decide"
	var f := 0
	var w := 0
	for k in stored:
		f += int(stored[k].food)
		w += int(stored[k].water)
	supply.food = mini(3 + f, 12)
	supply.water = mini(3 + w, 12)
	if _tile_total("cave") > 0:
		supply.food = maxi(0, supply.food - 1)
		supply.water = maxi(0, supply.water - 1)
		_log_ev("从洞穴搬出储备要翻越洞口，额外耗掉了 1 食 1 水。")
	if _tile_total("highland") > 0:
		route_bonus -= 1
		_log_ev("高地哨兵看得远，为全族找到了更好走的路线（需求-1）。")
	_log_ev("族群收拾行囊：带上 %d 份食物、%d 份水，准备撤离。" % [supply.food, supply.water])


func _route_need(i: int) -> int:
	return maxi(1, ROUTES[i].need + route_bonus)


func _choose_route(i: int) -> void:
	route_chosen = i
	var r: Dictionary = ROUTES[i]
	var need: int = _route_need(i)
	_log_ev("族群选择了%s：%s" % [r.name, r.risk])
	# v6 A' 结算顺序修正：先路线随机事件 → 再算最终物资 → 判 need → 算余量 → 评分
	if i == 1 and not scouted and randf() < 0.5:
		supply.water = maxi(0, supply.water - 1)
		_log_ev("东线果然遇到泥流改道，多耗了 1 份水。")
	elif i == 1 and scouted:
		_log_ev("斥候早标好了绕开泥流的高处小径，东线畅通无阻。")
	if i == 2:
		if scouted or randf() < 0.5:
			supply.food += 1
			_log_ev("南线一路觅食顺利，多出 1 份食物。")
		else:
			_log_ev("南线密林里绕了远路，什么也没找到。")
	var total: int = supply.food + supply.water
	# v6 A' 判定顺序：先按消耗前总量判生死/质量 → 再把 need 份真正消耗掉（影响余量与结算画面）
	if total < need:
		margin = 0
		result = "lose"
		_log_ev("物资在半途耗尽……族群的足迹消失在灰烬里。")
	else:
		margin = total - need
		var consumed: int = need
		var f_use: int = mini(supply.food, int(ceil(consumed / 2.0)))
		var w_use: int = mini(supply.water, consumed - f_use)
		f_use += mini(supply.food - f_use, consumed - f_use - w_use)
		supply.food -= f_use
		supply.water -= w_use
		_log_ev("行军消耗了 %d 份物资（食 %d 水 %d），抵达时还剩 %d 份。" % [consumed, f_use, w_use, margin])
		if supply.food >= 1 and supply.water >= 1:
			result = "win"
			_log_ev("第 %d 天，族群抵达一片没有被灰烬覆盖的新生态区。火山的故事结束了，生存的故事才刚刚开始。" % (5 + i))
		else:
			result = "partial"
			_log_ev("族群踉踉跄跄抵达新生态区，但食物或水见底——活下来了，代价惨重。")
	_show_end()


func _show_end() -> void:
	phase = "end"
	end_panel.visible = true
	var verdict := "完美撤离" if result == "win" else ("惨胜" if result == "partial" else "灭亡")
	end_body.text = ""
	for e in events:
		end_body.text += "· " + e + "\n"
	end_body.text += "\n—— 结算：%s · 撤离余量 %d · 剩余食物 %d 水 %d · 评分 %d ——" % [verdict, margin, supply.food, supply.water, _score()]


func _score() -> int:
	# v6 A'：撤离余量计分——基础分 + clamp(余量,0,8)×2；刚凑够=70，富余≥8=86
	# result 可能为 ""（测试/异常路径下未选路线），.get 兜底按灭亡计
	var base: int = {"win": 70, "partial": 45, "lose": 10}.get(result, 10)
	return base + clampi(margin, 0, 8) * 2


# ---------------- 绘制 ----------------

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color("1a1520"))
	# 火山
	var vx := 780.0
	var vcol := Color("4a3b45") if phase == "prepare" else Color("d84315")
	draw_polygon(PackedVector2Array([Vector2(vx - 90, 120), Vector2(vx + 90, 120), Vector2(vx, 30)]), PackedColorArray([vcol]))
	if phase != "prepare":
		var glow := 0.5 + 0.3 * sin(pulse)
		draw_circle(Vector2(vx, 40), 16, Color(1.0, 0.6, 0.2, glow))
		draw_string(FONT, Vector2(vx - 40, 22), "火山爆发！", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffab91"))
	# 地块
	var settled: bool = phase == "resolve" or phase == "decide" or phase == "end"
	for i in TILES.size():
		var t: Dictionary = TILES[i]
		var r := Rect2(t.x, t.y, 160, 96)
		var burnt: bool = settled and rain and t.id == "forest"
		var ashy: bool = settled and ((wind == "west" and (t.id == "forest" or t.id == "wetland")) or (wind == "east" and (t.id == "highland" or t.id == "valley")))
		var moving: bool = relocating and t.id != "cave"
		draw_rect(r, Color("5d4037") if burnt else (Color("6b6b70") if ashy else Color("39415a")))
		draw_rect(r, Color("ffd54f") if (hovered == i or moving) else Color("1c2030"), false, 3 if (hovered == i or moving) else 2)
		draw_string(FONT, r.position + Vector2(10, 22), t.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e8ecf4"))
		draw_string(FONT, r.position + Vector2(10, 44), "风险:%s" % t.risk, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffb74d") if phase == "prepare" else Color("8b94a7"))
		var s: Dictionary = stored[t.id]
		draw_string(FONT, r.position + Vector2(10, 66), "储备 食%d 水%d" % [s.food, s.water], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("4fc3f7"))
		draw_string(FONT, r.position + Vector2(10, 86), t.has, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8b94a7"))
	# 应急行动卡片
	if phase == "adjust":
		var prompt := "⚠ 灾后应变——仅此一次机会（%d 秒后按兵不动）：" % int(maxf(0.0, adjust_timer))
		if relocating:
			prompt = "抢运模式：点击一个地块，其储备转入洞穴（已锁定本次应急）"
		draw_string(FONT, Vector2(60, 295), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ff8a65"))
		for i in ADJUST_CARDS.size():
			var c: Dictionary = ADJUST_CARDS[i]
			var cr := Rect2(60 + i * 215, 310, 200, 120)
			var used: bool = emergency != ""
			var picked: bool = relocating and c.id == "relocate"
			draw_rect(cr, Color("5a3a2a") if picked else (Color("2b2b33") if used else Color("3b2b4d")))
			draw_rect(cr, Color("ff8a65") if picked else Color("9575cd"), false, 2)
			draw_string(FONT, cr.position + Vector2(12, 30), c.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e8ecf4") if not used else Color("6b7280"))
			_wrap_text(c.desc, cr.position + Vector2(12, 56), 176, 12, Color("c6cddc") if not used else Color("565e6e"))
	# 撤离路线卡片
	if phase == "decide":
		draw_string(FONT, Vector2(60, 285), "选择撤离路线（点击卡片）：", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffd54f"))
		for i in ROUTES.size():
			var rt: Dictionary = ROUTES[i]
			var rr := Rect2(60 + i * 290, 300, 270, 120)
			draw_rect(rr, Color("2b3b4d"))
			draw_rect(rr, Color("4fc3f7"), false, 2)
			draw_string(FONT, rr.position + Vector2(14, 30), rt.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("4fc3f7"))
			draw_string(FONT, rr.position + Vector2(14, 58), rt.risk, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c6cddc"))
			draw_string(FONT, rr.position + Vector2(14, 84), "至少需要 %d 份物资%s" % [_route_need(i), ("（已修正）" if _route_need(i) != rt.need else "")], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffb74d"))
	# 随身物资
	draw_string(FONT, Vector2(640, VIEW.y - 30), "随身: 食%d 水%d" % [supply.food, supply.water], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("4fc3f7"))
	# toast
	if toast_age < 2.5:
		var a: float = clamp(2.5 - toast_age, 0.0, 1.0)
		draw_string(FONT, Vector2(16, VIEW.y - 60), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, a))


func _wrap_text(text: String, pos: Vector2, width: float, size: int, col: Color) -> void:
	# 简易逐字折行（中文为主），每行按像素宽度截断
	var line := ""
	var y := pos.y
	for ch in text:
		line += ch
		if FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			line = line.substr(0, line.length() - 1)
			draw_string(FONT, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			y += size + 4
			line = ch
	draw_string(FONT, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
