extends Node3D
## DEMO10 3D 阶段 A：入口根。职责：
## 1) 持有纯规则核心 story_core（无三维依赖）；2) 模式仲裁（手稿开→冻结探索、释放鼠标）；
## 3) 一次编辑的事务次序（指南第 5 节）：命令进核心 → build_spec → validate → apply_spec
##    （旧变体立即释放、稳定 ID、碰撞同步）→ 玩家安全检查（非法则迁移到最近安全锚点，
##    清空速度，保朝向）→ 版本事件；4) 终局结算面板与重开。
## WorldBridge 失败时保留旧版本并提示「本次场景更新未完成」，不允许正文与碰撞不一致。

var core: RefCounted
var bridge: Node
var world: Node3D
var explorer: CharacterBody3D
var interactor: Node3D
var ui: CanvasLayer
var hud: CanvasLayer
var ambient: AudioStreamPlayer   # 程序生成环境垫音（基调读声音；纯氛围，无资产依赖）
var current_spec: Dictionary = {}   # 最近一次验证通过的 WorldSpec（梯架等通行点查锚点用）
var end_panel: Panel
var end_title: Label
var end_body: Label
var manuscript_open := false


func _ready() -> void:
	core = load("res://demo10_3d/story_core.gd").new()
	# 启动日志：供无头导出物验证（headless --main-pack 启动后 grep 此行）
	print("[demo10-3d] root ready | chapter=%d" % int(core.chapter_idx))
	bridge = load("res://demo10_3d/world_bridge.gd").new()
	bridge.name = "WorldBridge"
	add_child(bridge)
	bridge.bind(core)
	bridge.marks_completed.connect(_apply_world)   # 机制关卡 12：集齐刻痕 → 正规事务重建
	world = load("res://demo10_3d/chapter_world.gd").new()
	world.name = "ChapterWorld"
	add_child(world)
	explorer = load("res://demo10_3d/explorer.gd").new()
	explorer.name = "Explorer"
	explorer.position = Vector3(0, 0.2, 14)
	add_child(explorer)
	interactor = load("res://demo10_3d/interaction_controller.gd").new()
	interactor.name = "InteractionController"
	add_child(interactor)
	interactor.setup(explorer.cam)
	ui = load("res://demo10_3d/manuscript_ui.gd").new()
	ui.name = "ManuscriptUI"
	add_child(ui)
	ui.bind(core)
	hud = load("res://demo10_3d/hud.gd").new()
	hud.name = "Hud"
	add_child(hud)
	_build_end_panel()
	_build_ambient()
	# 信号接线
	core.toast.connect(func(t: String) -> void: hud.show_toast(t))
	world.memory_recalled.connect(func(t: String) -> void: hud.show_toast("「" + t + "」"))
	core.chapter_card.connect(func(t: String) -> void: hud.show_card(t))
	core.state_changed.connect(_on_state_changed)
	explorer.interact_requested.connect(_on_interact)
	explorer.manuscript_toggle_requested.connect(func() -> void: _set_manuscript(not manuscript_open))
	explorer.esc_requested.connect(_on_esc)
	explorer.view_changed.connect(func(_p, _y) -> void: pass)
	interactor.target_changed.connect(_on_target_changed)
	ui.pick_requested.connect(_on_pick)
	ui.submit_requested.connect(_on_submit)
	ui.reset_requested.connect(func() -> void:
		core.reset_chapter())
	ui.close_requested.connect(func() -> void: _set_manuscript(false))
	# 初始事务：先取相机（explorer._ready 已建好），再建世界
	interactor.setup(explorer.cam)
	_apply_world()


# ---------------- 模式仲裁 ----------------

func _set_manuscript(open: bool) -> void:
	if open == manuscript_open:
		return
	if open and str(core.state) == "final":
		return
	manuscript_open = open
	explorer.input_enabled = not open
	if open:
		explorer.release_mouse()
		ui.open()
	else:
		ui.close()
		explorer._capture_mouse()


func _on_esc() -> void:
	if manuscript_open:
		_set_manuscript(false)
	elif explorer.mouse_captured:
		explorer.release_mouse()


# ---------------- 事务：状态 → WorldSpec → 场景 ----------------

func _on_state_changed(_cmd: int) -> void:
	if str(core.state) == "final":
		_show_end()
		return
	_apply_world()
	if manuscript_open:
		ui.refresh()


func _apply_world() -> void:
	var spec: Dictionary = bridge.build_spec()
	if not bridge.validate_spec(spec):
		hud.show_toast("本次场景更新未完成——保留上一个已验证的世界版本")
		return
	current_spec = spec
	var res: Dictionary = world.apply_spec(spec)
	if not bool(res.ok):
		hud.show_toast("本次场景更新未完成——保留上一个已验证的世界版本")
		return
	world.refresh_prop_visual(str(core.flags.get("prop", "")))
	# 机制关卡 4：证物间存在时，藏格开格随道具联动
	if str(core.flags.get("evidence", "")) != "":
		world.refresh_evidence_stash(str(core.flags.get("prop", "")))
	# 基调氛围：世界灯光与声音读基调（纯氛围，无数值不改判定；盲测安全）
	var dom: String = bridge.dominant_tone()
	var max_tone: int = maxi(maxi(int(core.stats.sci), int(core.stats.warm)), int(core.stats.susp))
	world.set_tone_mood(dom, float(absi(max_tone)) / 3.0)
	match dom:
		"sci":
			ambient.volume_db = -16.0
			ambient.pitch_scale = 0.85
		"warm":
			ambient.volume_db = -18.0
			ambient.pitch_scale = 1.0
		"susp":
			ambient.volume_db = -13.0
			ambient.pitch_scale = 0.7
		_:
			ambient.volume_db = -20.0
			ambient.pitch_scale = 1.0
	# 解释被撤回（secret 清空）而玩家还站在围栏后的舱室里 → 迁回后院（围栏重新封死会困住玩家）
	if str(spec.get("secret", "")) == "" and explorer.global_position.z < -19.0:
		for a in spec.anchors:
			if str(a.id) == "back_zone":
				explorer.teleport_to(a.pos, true)
				break
	_ensure_player_safe(spec)


func _ensure_player_safe(spec: Dictionary) -> void:
	if world.is_position_safe(explorer.global_position):
		return
	var anchor: Dictionary = world.find_safe_anchor(spec.anchors)
	if anchor.is_empty():
		return
	explorer.teleport_to(anchor.pos, true)


# ---------------- 交互与命令 ----------------

func _on_target_changed(id: String) -> void:
	if id == "":
		hud.show_target("")
		return
	var texts: Dictionary = world.inspect_texts.get(id, {})
	hud.show_target(str(texts.get("title", "")))


func _on_interact() -> void:
	if manuscript_open or str(core.state) == "final":
		return
	var collider: Node3D = interactor.current_collider()
	if collider != null and collider.has_meta("ladder_to"):
		_ladder_travel(str(collider.get_meta("ladder_to")))
		return
	if collider != null and collider.name == "INS_telescope":
		# 机制关卡 20：望远镜校准互动——E 循环三档指向，文本与镜筒姿态随档位变化
		var aim: int = world.telescope_cycle()
		hud.show_inspect("单筒望远镜", bridge.telescope_text(aim))
		return
	if collider != null and collider.name == "INS_wind_chime":
		# 机制关卡 21：屋脊风铃——E 循环三档风，文本随主基调分化（纯氛围，盲测安全）
		# 机制关卡 31：布片在绳上且风起 → 铃声文本追加布片一句（全局风联动）
		var lvl: int = world.wind_cycle()
		world.wind_apply_level()
		hud.show_inspect("屋脊的风铃", bridge.wind_chime_text(lvl, bridge.dominant_tone(), world.line_hung))
		return
	if collider != null and collider.name == "INS_well_winch":
		# 机制关卡 22：井口的辘轳——E 摇三段拉桶，桶中旧物随主基调（捞上来看到的事实，盲测安全）
		var st: int = world.winch_crank()
		hud.show_inspect("井口的辘轳", bridge.winch_text(st, bridge.dominant_tone()))
		return
	if collider != null and collider.name == "INS_bucket":
		# 机制关卡 27：辘轳×水缸联动——首按 E 倒水（有缸倒缸/无缸待着）
		# 机制关卡 32：此后 E 把旧物收起来（跨章账本；匣文本按来历追加一段）
		var btext: String
		if world.bucket_emptied:
			if world.relic_take():
				var phrase: String = "一枚生锈的钥匙，柄上刻着一道短痕"
				match bridge.dominant_tone():
					"sci":
						phrase = "一枚黄铜齿轮，齿口还很利"
					"warm":
						phrase = "一系着红绳的小铃铛，绳结打得整整齐齐"
				bridge.relic_store(phrase)
				btext = "你把桶底那件旧物擦干，收起来了——屋子替你记着。"
			else:
				btext = "桶底空了，木桶安安静静待在一边。"
		else:
			world.bucket_emptied = true
			var poured: int = world.bucket_pour()
			if poured == 1:
				bridge.cistern_filled = true
			btext = bridge.bucket_pour_text(poured)
		hud.show_inspect("木桶", btext)
		return
	if collider != null and collider.name == "INS_mail_slot":
		# 机制关卡 29：信箱回执——E 把写了近况的字条投进信箱（一次性；第 5 章文本追加回信段）
		var mailed: bool = bridge.mail_send()
		var mbase: String = str(world.inspect_texts.get("mail_slot", {}).get("text", ""))
		hud.show_inspect("信箱", mbase + ("\n你把写了近况的字条投进投递口——深处黑得看不见底，像一条通向很远的走廊。" if mailed else "\n投递口深处的字条还在。"))
		return
	if collider != null and collider.name == "INS_clothes_line":
		# 机制关卡 23：后院的晾衣绳——E 挂上/收回所选道具（已选事实的空间化，盲测安全）
		# 机制关卡 30：挂/收同步 bridge 跨章账本（挂上记账、收下清账；下一章布片变干）
		var hung: bool = world.line_toggle()
		if hung:
			bridge.line_hung_prop = str(core.flags.get("prop", ""))
			bridge.line_hung_chapter = int(core.chapter_idx)
		else:
			bridge.line_hung_prop = ""
		hud.show_inspect("后院的晾衣绳", bridge.clothes_text(hung, str(core.flags.get("prop", ""))))
		return
	if collider != null and collider.name == "INS_ending_spot":
		# 机制关卡 33：终稿前的清点——落点检查文本含跨章账本回声（见 _ending_spot），E 追加仪式行
		# （state=final 时 _on_interact 顶部已拦截，出版结算不受任何影响）
		var etext: String = str(world.inspect_texts.get("ending_spot", {}).get("text", ""))
		hud.show_inspect("终稿落点", etext + "\n你把手稿摊开，从头到尾又读了一遍——有些句子，念出来和写在纸上不一样。")
		return
	if collider != null and collider.name == "INS_desk_drawer":
		# 机制关卡 35：桌子的抽屉——首按 E 拉开（跨章开态，spec 重建拉出抽屉盒），内容随所选道具
		# 机制关卡 46：锁纹对位——已开且有证物 → 再按 E 把那张纸对折收进证物匣夹层（跨章账本）
		var ev46: String = str(core.flags.get("evidence", ""))
		var dtext: String = str(world.inspect_texts.get("desk_drawer", {}).get("text", ""))
		if not bridge.drawer_opened:
			bridge.drawer_opened = true
			_apply_world()
			dtext = str(world.inspect_texts.get("desk_drawer", {}).get("text", ""))
			hud.show_inspect("桌子的抽屉", dtext + "\n你拉开了抽屉。")
			return
		if not bridge.drawer_matched and ev46 != "":
			bridge.drawer_match(ev46)
			_apply_world()
			dtext = str(world.inspect_texts.get("desk_drawer", {}).get("text", ""))
			hud.show_inspect("桌子的抽屉", dtext + "\n你把那张纸对折，收进了证物匣的夹层。")
			return
		if bridge.drawer_matched:
			hud.show_inspect("桌子的抽屉", "抽屉里已经空了——该收的都收在了该在的地方。")
			return
		hud.show_inspect("桌子的抽屉", dtext + "\n抽屉就保持在拉开的样子。")
		return
	if collider != null and collider.name == "INS_well_wish_spot":
		# 机制关卡 36：井里的回应——E 投一枚硬币（一次性；水面硬币经 spec 跨章常驻）
		var wtext: String
		if bridge.well_wish():
			_apply_world()
			wtext = bridge.well_wish_text(bridge.dominant_tone())
		else:
			wtext = "水里已经有一枚了。"
		hud.show_inspect("井沿的圆痕", wtext)
		return
	if collider != null and collider.name == "INS_attic_stash":
		# 机制关卡 38：木箱的第二层——首按 E 掀盖（跨章开态，spec g 维驱动盖板立起），文本递进
		var atext: String = str(world.inspect_texts.get("attic_stash", {}).get("text", ""))
		if not bridge.stash_opened:
			bridge.stash_opened = true
			_apply_world()
			atext = str(world.inspect_texts.get("attic_stash", {}).get("text", ""))
			hud.show_inspect("阁楼的木箱", atext + "
你掀开了箱盖。")
			return
		hud.show_inspect("阁楼的木箱", atext + "
箱盖就保持在掀开的样子。")
		return
	if collider != null and collider.name == "INS_door_front":
		# 机制关卡 71：E 木门——回应 65 的叩门（激活态首敲=「像在听」，本章一次；原门句保留）
		var base_door: String = str(world.inspect_texts.get("door_front", {}).get("text", ""))
		var back_text: String = bridge.door_knock_back_text(world.knock_active, world.knock_answered)
		if world.knock_active and not world.knock_answered:
			world.knock_answered = true
		hud.show_inspect("老屋的木门" if world.current_variant == "town" else "舱门",
			base_door + " " + back_text)
		return
	if collider != null and collider.name == "INS_letter_draft":
		# 机制关卡 69：E 回信——循环三档语气（可逆改写，账本记最终档）
		var stage69: int = bridge.letter_cycle()
		_apply_world()
		hud.show_inspect("窗台的回信", bridge.letter_text(stage69))
		return
	if collider != null and collider.name == "INS_music_box":
		# 机制关卡 68：E 八音盒——演奏中=进行句；否则上发条（曲终/首次重播，瞬态可重复）
		var played68: bool = world.musicbox_wind()
		hud.show_inspect("八音盒", bridge.musicbox_text(played68, world.music_done, bridge.dominant_tone()))
		return
	if collider != null and collider.name == "INS_soft_board":
		# 机制关卡 67：E 软木板——有证物首按描摹钉板（账本跨章），再按幂等
		if not bridge.evidence_pinned:
			bridge.board_pin()
			if bridge.evidence_pinned:
				_apply_world()
		var btext: String = str(world.inspect_texts.get("soft_board", {}).get("text", ""))
		hud.show_inspect("墙上的软木板", btext)
		return
	if collider != null and collider.name == "INS_floor_board":
		# 机制关卡 66：E 松动的地板——首按掀开（一次性账本跨章），再按幂等
		if not bridge.floorboard_open:
			bridge.floorboard_lift()
			_apply_world()
		var fbtext: String = str(world.inspect_texts.get("floor_board", {}).get("text", ""))
		hud.show_inspect("会响的地板", fbtext)
		return
	if collider != null and collider.name == "INS_crate_stack":
		# 机制关卡 62：墙角的木箱堆——首按推开顶层箱（一次性账本跨章），再按幂等
		if not bridge.crate_slid:
			bridge.crate_slide()
			_apply_world()
		var ctext: String = str(world.inspect_texts.get("crate_stack", {}).get("text", ""))
		hud.show_inspect("墙角的木箱堆", ctext)
		return
	if collider != null and collider.name == "INS_fireplace_ash":
		# 机制关卡 60：壁炉点火/熄火（瞬态重建复位；点火→火光+烟囱同步冒暖白烟）
		var lit60: bool = world.fireplace_toggle()
		var fb60: String = bridge.fireplace_state_text(lit60, bridge.dominant_tone())
		if world.hearth_vigil:
			fb60 += "（" + bridge.vigil_text() + "）"
		hud.show_inspect("壁炉", fb60)
		return
	if collider != null and collider.name == "INS_radio":
		# 机制关卡 43：旧收音机——E 开/关（杂音内容随主基调三分化，纯氛围盲测安全）
		var ron: bool = world.radio_toggle()
		hud.show_inspect("旧收音机", bridge.radio_text(ron, bridge.dominant_tone()))
		return
	if collider != null and collider.name == "INS_station_plant":
		# 机制关卡 45：收件槽的绿植——E 浇水一次性（账本跨章；文本随温情档与浇水态）
		var first45: bool = bridge.plant_water()
		var ptext: String = str(world.inspect_texts.get("station_plant", {}).get("text", ""))
		if first45:
			ptext += "
你用喝剩的水浇了浇它。"
		hud.show_inspect("收件槽的绿植", ptext)
		return
	if collider != null and collider.name == "INS_station_broadcast":
		# 机制关卡 47：应急广播——E 开/关（播放内容随双解释分化，纯氛围盲测安全）
		var bon: bool = world.broadcast_toggle()
		var btext: String = bridge.broadcast_text(str(core.flags.get("secret", ""))) if bon else "你关掉了广播——走廊里只剩下通风的声音。"
		hud.show_inspect("应急广播", btext)
		return
	if collider != null and collider.name == "INS_yard_cat":
		# 机制关卡 39：后院的猫——E 摸猫（账本跨章；反应文本随主基调三分化）
		var first: bool = bridge.cat_pet()
		var ctext: String = bridge.cat_text(bridge.dominant_tone())
		if not first:
			ctext += "
猫抬了下眼，又把下巴搁回了爪子上。"
		hud.show_inspect("后院的猫", ctext)
		return
	if collider != null and collider.name == "INS_chair":
		# 机制关卡 40：桌边的椅子——E 坐下/站起（姿态切换；坐过入终稿清点）
		var ctext: String
		var sat: bool = world.chair_sit(explorer)
		if sat:
			bridge.chair_sitted = true
			ctext = ("你和衣坐下，守着炉火——今晚不睡了。" if world.hearth_vigil
				else "你在桌边的椅子上坐下来——信就在手边。")
		else:
			world.chair_stand(explorer)
			ctext = "你从椅子上站起来。"
		hud.show_inspect("桌边的椅子", ctext)
		return
	if collider != null and collider.name == "INS_porthole_star" and world.frost_present:
		# 机制关卡 44：舷窗的霜——E 擦霜一次性（跨章保持；擦净后此检查点回归星的通用检查）
		bridge.porthole_wiped = true
		_apply_world()
		hud.show_inspect("舷窗", bridge.frost_wipe_text())
		return
	if collider != null and collider.name == "INS_wall_picture":
		# 机制关卡 52：墙上的挂画——首按 E 摆正（一次性；跨章开态），再按幂等
		if not bridge.picture_straight:
			bridge.straighten_picture()
			_apply_world()
			var cv52: MeshInstance3D = world.get_node_or_null("VariantRoot/PictureCanvas")
			if cv52 != null:
				cv52.rotation.x = 0.0
			var wpt: String = str(world.inspect_texts.get("wall_picture", {}).get("text", ""))
			hud.show_inspect("墙上的挂画", wpt + "\n你把挂画摆正了。")
			return
		hud.show_inspect("墙上的挂画", "挂画已经正了。")
		return
	if collider != null and collider.name == "INS_light_switch":
		# 机制关卡 37：灯的开关——E 熄灯/开灯（表现层瞬态，重建复位亮灯）
		var off: bool = world.light_toggle()
		hud.show_inspect("墙上的开关", bridge.light_text(off))
		return
	var id: String = interactor.current_target()
	if id == "":
		return
	var texts: Dictionary = world.inspect_texts.get(id, {})
	hud.show_inspect(str(texts.get("title", "")), interact_text(id))


## 机制关卡 5：检查文本 + 初见观察（首次检查追加一行，之后回归常规文本；表现层已读记忆）
func interact_text(id: String) -> String:
	var texts: Dictionary = world.inspect_texts.get(id, {})
	var t := str(texts.get("text", ""))
	if not bridge.inspected_once.has(id):
		var extra: String = bridge.first_look(id)
		if extra != "":
			t += "\n" + extra
		bridge.inspected_once[id] = true
		bridge.mark_inspected(id)   # 机制关卡 12：刻痕检查记入收集账本（集齐时 bump 走正规事务）
		# 机制关卡 13：字条系首读记入（note2/note3 投影随读随变，root 重走事务）
		if id == "echo_note" or id == "note2" or id == "note3" or id == "note4" or id == "note5":
			if bridge.mark_note_read(id):
				_apply_world()
	return t


## 检修梯通行（机制关卡 3）：E 命中梯架垫 → 沿锚点表传送上/下
func _ladder_travel(anchor_id: String) -> void:
	for a in (current_spec.get("anchors", []) as Array):
		if str(a.id) == anchor_id:
			explorer.teleport_to(a.pos, true)
			hud.show_toast("你顺着检修梯爬了上去。" if anchor_id == "roof_top" else "你顺着检修梯下了地面。")
			return


func _on_pick(slot: int, opt: int) -> void:
	core.choose(slot, opt)


func _on_submit() -> void:
	# 交稿前不要求探索进度：探索是新增表现层，不替代词槽门槛（指南第 1、3 节）
	core.submit_chapter()


# ---------------- 终局 ----------------

## 程序生成 2 秒无缝循环环境垫音（零资产依赖；频率取 0.5Hz 整数倍，2 秒整周期循环无接缝）
func _build_ambient() -> void:
	ambient = AudioStreamPlayer.new()
	ambient.name = "Ambient"
	var rate := 11025
	var n := int(rate * 2.0)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var v := 0.30 * sin(TAU * 110.0 * t) + 0.22 * sin(TAU * 220.0 * t) + 0.18 * sin(TAU * 55.0 * t)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	wav.data = data
	ambient.stream = wav
	ambient.volume_db = -20.0
	ambient.autoplay = true
	add_child(ambient)
	ambient.play()


func _build_end_panel() -> void:
	end_panel = Panel.new()
	end_panel.name = "EndPanel"
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.1, 0.14, 0.98)
	st.set_corner_radius_all(14)
	st.border_color = Color("7fd88f")
	st.set_border_width_all(2)
	end_panel.add_theme_stylebox_override("panel", st)
	end_panel.position = Vector2(150, 48)
	end_panel.size = Vector2(660, 444)
	end_panel.visible = false
	add_child(end_panel)
	end_title = Label.new()
	end_title.position = Vector2(24, 14)
	end_title.add_theme_font_size_override("font_size", 22)
	end_title.add_theme_color_override("font_color", Color("7fd88f"))
	end_panel.add_child(end_title)
	end_body = Label.new()
	end_body.position = Vector2(24, 56)
	end_body.size = Vector2(612, 320)
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_body.add_theme_font_size_override("font_size", 14)
	end_body.add_theme_color_override("font_color", Color("e8e4d8"))
	end_panel.add_child(end_body)
	var again := Button.new()
	again.text = "重新改一部"
	again.position = Vector2(24, 386)
	again.size = Vector2(150, 40)
	again.pressed.connect(_restart)
	end_panel.add_child(again)


func _show_end() -> void:
	_set_manuscript(false)
	explorer.input_enabled = false
	explorer.release_mouse()
	var et := str(core._ending_text())
	end_title.text = et.substr(0, et.find("：")) + " · 过审出版"
	var pay_line := ""
	if int(core.foreshadow_payoff) > 0:
		pay_line = "\n伏笔回收 ×%d —— 看似写岔的地方都圆了回来" % int(core.foreshadow_payoff)
	var rtype := str(core.telemetry.resolution_type)
	var tele_line := "\n遥测：anomaly_created=%d · anomaly_resolved=%d · resolution_type=%s · chapters_to_resolution=%d · unresolved_at_publish=%d" % [
		int(core.telemetry.anomaly_created), int(core.telemetry.anomaly_resolved),
		rtype if rtype != "" else "无", int(core.telemetry.chapters_to_resolution), int(core.telemetry.unresolved_at_publish)]
	end_body.text = "%s\n\n基调：科幻 %+d · 温情 %+d · 悬疑 %+d\n读者抗议 %d 次 · 旗标 %d 条%s%s\n—— 前四章的每一次改词，共同拼出了这个结局。" % [
		et, int(core.stats.sci), int(core.stats.warm), int(core.stats.susp),
		int(core.contradictions), (core.flags as Dictionary).size(), pay_line, tele_line]
	end_panel.visible = true


func _restart() -> void:
	end_panel.visible = false
	core.stats = {sci = 0, warm = 0, susp = 0}
	core.flags = {}
	core.contradictions = 0
	core.anomalies = []
	core.foreshadow_payoff = 0
	core.anomaly_seq = 0
	core.telemetry = {anomaly_created = 0, anomaly_resolved = 0, resolution_type = "", chapters_to_resolution = -1, unresolved_at_publish = 0}
	core.chapter_pass = false
	core.state = "play"
	explorer.input_enabled = true
	core.start_chapter(0)
