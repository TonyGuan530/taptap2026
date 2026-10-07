extends SceneTree
## DEMO10 3D 阶段 A：3D 入口场景冒烟验证（headless，自动驱动核心——与真实输入证据分开记录）。
## 运行：godot --headless --path game -s res://tests/test_demo10_3d_scene.gd
## 验证：节点装配、初始小镇变体、状态→WorldSpec→场景事务（小镇↔空间站真实重建、
## 旧变体立即释放、稳定 ID 不重复）、道具外观随词槽刷新、卡墙安全迁移、
## 手稿模式冻结探索、WorldSpec 确定性。
## 真实鼠标/WASD/E/Tab/Esc 的通路与截图证据需要编辑器会话（Godot MCP Pro），另行记录。

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


func _boot() -> Node3D:
	var s: Node3D = load("res://demo10_3d.tscn").instantiate()
	root.add_child(s)
	for i in 4:
		await physics_frame
	return s


func _drop(s: Node3D) -> void:
	s.queue_free()
	await physics_frame
	await physics_frame


func _variant_children(w: Node3D) -> int:
	return w.get_node("VariantRoot").get_child_count()


func _ins_count(w: Node3D, id: String) -> int:
	var n := 0
	for c in w.get_node("VariantRoot").get_children():
		if str(c.name) == "INS_" + id:
			n += 1
	return n


func _run() -> void:
	await process_frame
	_log("DEMO10 3D 场景冒烟开始")

	var s: Node3D = await _boot()
	_check(s.get_node_or_null("Explorer") != null and s.get_node_or_null("ChapterWorld") != null
		and s.get_node_or_null("ManuscriptUI") != null and s.get_node_or_null("WorldBridge") != null
		and s.get_node_or_null("Hud") != null and s.get_node_or_null("InteractionController") != null,
		"烟1a 六大部件装配齐全")
	var w: Node3D = s.get_node("ChapterWorld")
	var ex: CharacterBody3D = s.get_node("Explorer")
	_check(w.current_variant == "town", "烟1b 初始变体=小镇（地点未定稿的默认样貌）")
	_check(_variant_children(w) > 10, "烟1c 小镇几何已建（含墙体/信箱/室内）")
	_check(_ins_count(w, "mail_slot") == 1 and _ins_count(w, "door_front") == 1
		and _ins_count(w, "prop_item") == 1 and _ins_count(w, "desk_letter") == 1
		and _ins_count(w, "window_look") == 1, "烟1d 五个检查点各一个（稳定 ID）")
	_check(s.world.inspect_texts.get("mail_slot", {}).get("title", "") == "老屋的信箱",
		"烟1e 检查文本已随 spec 写入（未定稿默认小镇文案）")
	_check(s.explorer.input_enabled == true and not s.manuscript_open, "烟1f 初始为探索模式")

	# --- 事务：把地点改成空间站 → 世界必须真实重建 ---
	s.core.choose(0, 2)   # 宇航员
	s.core.choose(1, 2)   # 空间站
	await physics_frame
	_check(w.current_variant == "station", "烟2a 改词后变体=空间站（真实重建）")
	_check(w.get_node_or_null("VariantRoot/Corr_W") != null
		and w.get_node_or_null("VariantRoot/MailboxBox") == null,
		"烟2b 旧小镇对象已移除、走廊对象已就位（无残留混搭）")
	_check(_ins_count(w, "mail_slot") == 1, "烟2c 换变体后检查点仍唯一（无重复监听对象）")
	_check(s.world.inspect_texts.get("mail_slot", {}).get("title", "") == "居住舱收件槽",
		"烟2d 空间站检查文本同步刷新")
	_check(w.is_position_safe(ex.global_position), "烟2e 变体切换后玩家位置安全（未卡墙/未坠落）")

	# --- 同槽反悔：空间站→小镇，世界跟随回滚 ---
	s.core.choose(1, 0)   # 改回小镇
	await physics_frame
	_check(w.current_variant == "town" and w.get_node_or_null("VariantRoot/MailboxBox") != null
		and w.get_node_or_null("VariantRoot/Corr_W") == null, "烟3a 同槽反悔：旧变体同步撤回（走廊消失、信箱回来）")
	_check(w.is_position_safe(ex.global_position), "烟3b 回退后玩家仍安全")

	# --- 道具词槽：外观与检查文本跟随 ---
	s.core.choose(2, 2)   # 星图
	await physics_frame
	_check(w.get_node_or_null("VariantRoot/PropVisual") != null, "烟4a 道具外观对象存在")
	_check(s.world.inspect_texts.get("prop_item", {}).get("title", "") == "加密的星图"
		and str(s.world.inspect_texts.get("prop_item", {}).get("text", "")).contains("坐标"),
		"烟4b 星图检查文本正确")
	s.core.choose(2, 1)   # 换家书
	await physics_frame
	_check(s.world.inspect_texts.get("prop_item", {}).get("title", "") == "泛黄的家书", "烟4c 同槽换道具文本跟随")

	# --- 身份观察：侦探看同一道具多一行观察 ---
	s.core.choose(0, 0)   # 改侦探
	await physics_frame
	_check(str(s.world.inspect_texts.get("prop_item", {}).get("text", "")).contains("镊子"),
		"烟5a 侦探身份派生观察进入检查文本")

	# --- 安全迁移：把玩家塞进北墙里 → 事务应迁移到安全锚点 ---
	ex.global_position = Vector3(0, 0.2, -12.0)   # 北墙内部
	s.core.choose(1, 2)   # 再切空间站触发事务
	await physics_frame
	_check(w.is_position_safe(ex.global_position), "烟6a 卡墙玩家被迁移到安全锚点")
	_check(absf(ex.velocity.x) < 0.01 and absf(ex.velocity.z) < 0.01 and ex.velocity.y > -20.0,
		"烟6b 迁移后水平速度清零（垂直为正常重力）")

	# --- 手稿模式仲裁 ---
	s._set_manuscript(true)
	_check(s.manuscript_open and not s.explorer.input_enabled and s.get_node("ManuscriptUI").root_panel.visible,
		"烟7a 手稿打开：探索冻结、界面可见")
	s._set_manuscript(false)
	_check(not s.manuscript_open and s.explorer.input_enabled, "烟7b 手稿关闭：探索恢复")

	# --- 连续快速 A/B 不累积对象（基线取同变体：跑两轮循环，两轮结束的对象数必须一致） ---
	for i in 3:
		s.core.choose(1, 2)
		await physics_frame
		s.core.choose(1, 0)
		await physics_frame
	var base_children := _variant_children(w)
	for i in 3:
		s.core.choose(1, 2)
		await physics_frame
		s.core.choose(1, 0)
		await physics_frame
	_check(w.current_variant == "town", "烟8a 连续切换停在最后一次选择（无旧异步覆盖）")
	_check(_variant_children(w) == base_children, "烟8b 变体对象数不随切换累积（A→B→A 无重复门/旧证物）")
	_check(_ins_count(w, "door_front") == 1 and _ins_count(w, "prop_item") == 1, "烟8c 检查点仍各一个")

	# --- WorldSpec 确定性：相同状态与命令顺序 → 相同 spec（除版本号） ---
	var c1 = load("res://demo10_3d/story_core.gd").new()
	var b1 = load("res://demo10_3d/world_bridge.gd").new()
	b1.bind(c1)
	var c2 = load("res://demo10_3d/story_core.gd").new()
	var b2 = load("res://demo10_3d/world_bridge.gd").new()
	b2.bind(c2)
	c1.choose(0, 1); c2.choose(0, 1)
	c1.choose(1, 2); c2.choose(1, 2)
	c1.choose(2, 2); c2.choose(2, 2)
	var s1: Dictionary = b1.build_spec()
	var s2: Dictionary = b2.build_spec()
	s1.version = 0
	s2.version = 0
	s1.command_seq = 0
	s2.command_seq = 0
	_check(var_to_str(s1) == var_to_str(s2), "烟9a 相同命令序列产生相同 WorldSpec（除版本号）")

	# --- 校验器拒绝坏 spec ---
	var bad: Dictionary = b1.build_spec()
	bad.inspectables = []
	_check(b1.validate_spec(bad) == false, "烟9b 缺检查对象的 spec 未通过验证")

	# --- 段10：3d-shared 套件应用（统一材质 + 模型库物件） ---
	var ground_mi: MeshInstance3D = s.get_node("ChapterWorld/Ground")
	_check(ground_mi.material_override is ShaderMaterial, "烟10a 世界物体统一 comic 材质（ShaderMaterial）")
	_check(w.get_node_or_null("VariantRoot/KitCrate1") != null and w.get_node_or_null("VariantRoot/KitTree1") != null
		and w.get_node_or_null("VariantRoot/KitBush2") != null, "烟10b 套件物件在小镇变体生成（crate/tree/bush）")
	_check(str(w.get_node("VariantRoot/KitCrate1").get_meta("model_id")) == "crate", "烟10c 套件节点带 model_id 元数据")

	# --- 段12：基调环境音（程序生成，世界声音读基调） ---
	var amb: AudioStreamPlayer = s.get_node_or_null("Ambient")
	_check(amb != null and amb.playing and amb.stream.get_length() > 1.0, "烟12a 程序生成环境音在播（无缝循环垫音）")
	var v0: float = amb.volume_db
	var p0: float = amb.pitch_scale
	s.core.choose(0, 2)   # 侦探→宇航员：susp 转 sci，主基调变化
	await physics_frame
	_check(amb.volume_db != v0 and absf(amb.pitch_scale - 0.85) < 0.01,
		"烟12b 基调读声音：sci 档位（音量 %s→%s、音高 %.2f）" % [str(v0), str(amb.volume_db), amb.pitch_scale])
	_check(absf(p0 - 1.0) < 0.01, "烟12c 原状态=warm 档（温情1/悬疑1 → 主基调温情，音高 1.0）")

	# --- 段13：HUD 检查反馈（准星随目标、检查卡淡入） ---
	var hudn: CanvasLayer = s.get_node("Hud")
	hudn.show_target("桌上的信")
	_check(hudn.crosshair.size.x > 4.0, "烟13a 有目标准星放大")
	hudn.show_target("")
	_check(hudn.crosshair.size.x <= 4.5, "烟13b 无目标准星还原")
	hudn.show_inspect("测试物件", "测试文本")
	_check(hudn.inspect_panel.visible and hudn.inspect_panel.modulate.a < 1.0, "烟13c 检查卡淡入启动")
	for i in 25:
		await process_frame
	_check(hudn.inspect_panel.modulate.a > 0.9, "烟13d 检查卡淡入完成")

	await _drop(s)
	_log("==========================================")
	_log("PASS %d / FAIL %d" % [passes, fails])
	if fails > 0:
		quit(1)
	else:
		quit(0)
