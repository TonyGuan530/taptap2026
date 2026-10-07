extends SceneTree
## DEMO10 3D 阶段 B：第 2/3 章世界 + 小镇气闸实物 + 第 4 章双解释舱室（headless，核心直驱）。
## 运行：godot --headless --path game -s res://tests/test_demo10_3d_phaseb.gd
## 覆盖：第 2 章夜记随选择/派生证物；第 3 章后山通道打开（几何通路）、三记录/字条随词槽、
## 小镇线写入气闸 → 实物气闸门出现（未解释：围栏封死、文本不泄底）；空间站线同槽无异常（正常气闸）；
## 第 4 章 A/B 解释 → 同一舱室两种互斥内饰换装（旧内饰随事务清除）、门洞可走几何、
## 解释撤回 → 围栏重新封死 + 舱室内玩家被迁回后院；spec 验证器拒绝缺件。

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


func _has_ins(w: Node3D, id: String) -> bool:
	return w.get_node_or_null("VariantRoot/INS_" + id) != null


func _ins_text(w: Node3D, id: String) -> String:
	return str(w.inspect_texts.get(id, {}).get("text", ""))


## 玩家从头到尾的一条脊柱通路采样（几何安全 = 每个采样点不嵌墙不出界）
func _route_ok(w: Node3D, pts: Array) -> bool:
	for p in pts:
		if not w.is_position_safe(p):
			return false
	return true


## 记者小镇线推到第 3 章（带 evidence 旗标）
func _to_ch3_town(s: Node3D) -> void:
	s.core.choose(0, 1)   # 记者
	s.core.choose(1, 0)   # 小镇
	s.core.choose(2, 3)   # 旧照片
	s.core.submit_chapter()
	s.core.choose(0, 2)   # 调阅日志
	s.core.choose(1, 0)   # 黄铜钥匙（记者派生）
	s.core.choose(2, 0)   # 撤稿
	s.core.submit_chapter()


func _run() -> void:
	await process_frame
	_log("DEMO10 3D 阶段 B 测试开始")

	# --- 线1：小镇记者线 ---
	var s: Node3D = await _boot()
	var w: Node3D = s.get_node("ChapterWorld")
	var ex: CharacterBody3D = s.get_node("Explorer")
	_to_ch3_town(s)
	await physics_frame
	_check(int(s.core.chapter_idx) == 2, "B1a 抵达第 3 章")
	_check(_spec_back_open(s), "B1b 第 3 章后山通道打开（spec）")
	_check(w.get_node_or_null("VariantRoot/Wall_N_L") != null and w.get_node_or_null("VariantRoot/Wall_N") == null,
		"B1c 北墙开门（Wall_N 段化）")
	_check(_has_ins(w, "record_1") and _has_ins(w, "record_2") and _has_ins(w, "record_3") and _has_ins(w, "note_paper"),
		"B1d 三份记录与字条对象就位")
	_check(not _has_ins(w, "airlock_door"), "B1e 未写气闸前：气闸对象不存在（不预泄）")
	# 先改前三个词槽（记录/字条文本跟随），气闸槽留到 B2 再写
	s.core.choose(0, 0)   # 深空计划
	s.core.choose(1, 0)   # 星图伪造
	s.core.choose(2, 0)   # 别相信回来的那个人
	await physics_frame
	_check(str(_ins_text(w, "record_1")).contains("深空计划"), "B1f 记录一文本=第 3 章已选候选")
	_check(str(_ins_text(w, "note_paper")).contains("别相信"), "B1g 字条文本=已选候选")

	# 脊柱通路：出生点 → 门厅 → 室内 → 后门 → 后院 → 围栏前
	var route := [Vector3(0, 0.2, 12), Vector3(0, 0.2, 0), Vector3(0, 0.2, -3), Vector3(1.6, 0.2, -7),
		Vector3(1.6, 0.2, -9), Vector3(0, 0.2, -10.5), Vector3(0, 0.2, -12), Vector3(0, 0.2, -15.5), Vector3(0, 0.2, -18.5)]
	_check(_route_ok(w, route), "B1h 出生点→室内→后门→后院→围栏前 几何通路全通")

	# 小镇线写入气闸（slot3=舷梯）→ 实物气闸门出现，未解释不泄底
	s.core.choose(3, 2)
	await physics_frame
	_check((s.core.anomalies as Array).size() == 1 and s.core.contradictions == 0, "B2a 写入气闸：anomaly 挂账、无立即抗议")
	_check(_has_ins(w, "airlock_door"), "B2b 气闸实物门出现")
	var at := _ins_text(w, "airlock_door")
	_check(at.contains("解释不了") and at.contains("推不开"), "B2c 未解释文本：不泄底、不可进")
	_check(not w.is_position_safe(Vector3(0, 0.2, -20.0)), "B2d 围栏封死：门线点不可站立")

	# 第 4 章：A 解释 → 飞船舱室；换 B → 换装；撤回 → 封死+玩家迁回
	s.core.submit_chapter()
	await physics_frame
	_check(int(s.core.chapter_idx) == 3, "B3a 进入第 4 章")
	s.core.choose(0, 3)   # A colony_ship
	await physics_frame
	_check(str(s.core.flags.get("secret", "")) == "colony_ship", "B3b A 线 secret")
	_check(_has_ins(w, "ship_proof") and not _has_ins(w, "mine_proof"), "B3c 飞船内饰+证物（矿井侧不存在）")
	_check(w.is_position_safe(Vector3(0, 0.2, -20.0)) and w.is_position_safe(Vector3(0, 0.2, -23.0)),
		"B3d 门洞与舱内可站立（真实可走几何）")
	_check(_ins_text(w, "airlock_door").contains("登船闸"), "B3e 已解释后气闸文本=飞船说")
	s.core.choose(0, 4)   # A→B
	await physics_frame
	_check(_has_ins(w, "mine_proof") and not _has_ins(w, "ship_proof"), "B3f A→B 换装：矿井内饰替换飞船（旧证物清除）")
	ex.global_position = Vector3(0, 0.2, -23.0)   # 站进舱室再撤回解释
	s.core.choose(0, 0)   # B→普通候选：secret 清空
	await physics_frame
	_check(not s.core.flags.has("secret"), "B3g 撤回解释：secret 清空")
	_check(not _has_ins(w, "mine_proof") and w.get_node_or_null("VariantRoot/Cham_W") == null, "B3h 舱室随事务移除")
	_check(not w.is_position_safe(Vector3(0, 0.2, -20.0)), "B3i 围栏重新封死")
	_check(ex.global_position.z > -19.0, "B3j 舱室内玩家被迁回后院（未被困）")

	# --- 第 4→5 章（B 线解释进第 5 章）：舱室与终稿落点同场 ---
	s.core.choose(0, 4)   # 重新选 B
	s.core.choose(1, 0)
	s.core.choose(2, 2)
	s.core.choose(3, 0)
	s.core.submit_chapter()
	await physics_frame
	_check(int(s.core.chapter_idx) == 4, "B6a 进入第 5 章")
	_check(_has_ins(w, "mine_proof") and _has_ins(w, "secret_tail"), "B6b 矿井舱室保留+里间尾段在场")
	_check(str(_ins_text(w, "secret_tail")).contains("茶杯"), "B6c 尾段文本=矿井里间（有人刚离开）")
	_check(_has_ins(w, "ending_spot"), "B6d 终稿落点对象在场")
	var spot_pos: Vector3 = w.get_node("VariantRoot/INS_ending_spot").position
	_check(absf(spot_pos.x - 4.0) < 0.01 and absf(spot_pos.z - 8.0) < 0.01, "B6e 主基调=科幻 → 落点在街边投递台")
	_check(str(_ins_text(w, "ending_spot")).contains("《回声》"), "B6f 落点文本=终稿《回声》（现场与正文一致）")
	_check(not s.get_node("EndPanel").visible and str(s.core.state) == "play", "B6g 未交稿未出版")
	s.core.choose(0, 0)
	s.core.choose(1, 0)
	s.core.choose(2, 0)
	s.core.choose(3, 0)
	s.core.choose(4, 0)
	s.core.submit_chapter()
	await physics_frame
	_check(str(s.core.state) == "final" and s.get_node("EndPanel").visible, "B6h 第 5 章交稿 → 过审出版，结算面板出现")
	await _drop(s)

	# --- 线2：空间站宇航员线（气闸=正常设施，无异常） ---
	var s2: Node3D = await _boot()
	var w2: Node3D = s2.get_node("ChapterWorld")
	s2.core.choose(0, 2)   # 宇航员
	s2.core.choose(1, 2)   # 空间站
	s2.core.choose(2, 2)   # 星图
	s2.core.submit_chapter()
	s2.core.choose(0, 2)
	s2.core.choose(1, 2)   # 手稿（宇航员派生 sci）
	s2.core.choose(2, 0)
	s2.core.submit_chapter()
	s2.core.choose(0, 0)
	s2.core.choose(1, 0)
	s2.core.choose(2, 1)
	s2.core.choose(3, 3)   # 气闸通道：place=空间站 → 不冲突、无异常
	await physics_frame
	_check((s2.core.anomalies as Array).is_empty() and s2.core.contradictions == 0, "B4a 空间站线写气闸：不建异常")
	_check(_has_ins(w2, "airlock_door"), "B4b 空间站气闸=正常设施对象存在")
	_check(_ins_text(w2, "airlock_door").contains("正常"), "B4c 气闸文本=正常（无未解释暗示）")
	_check(not s2.core.flags.has("secret") and (s2.core.anomalies as Array).is_empty(), "B4d 无异常无秘密")
	# 第 2 章夜记：表现记忆回查（进行中章读实时）
	_check(str(_ins_text(w2, "night_record")).contains("日志终端"), "B4e 夜记文本=第 2 章实时选择")
	await _drop(s2)

	# --- 线3：历史章记录回查（交稿后 CHAPTERS 常量回查文本） ---
	var s3: Node3D = await _boot()
	var w3: Node3D = s3.get_node("ChapterWorld")
	_to_ch3_town(s3)
	await physics_frame
	_check(str(_ins_text(w3, "night_record")).contains("日志终端"),
		"B5a 第 3 章视角回看第 2 章夜记：表现记忆生效")
	var bad: Dictionary = s3.bridge.build_spec()
	var ids := []
	for ins in bad.inspectables:
		ids.append(str(ins.id))
	bad.inspectables = bad.inspectables.slice(1)
	_check(s3.bridge.validate_spec(bad) == false, "B5c 缺件 spec 被拒绝")
	await _drop(s3)

	# --- 线4：温情线到第 5 章（无解释）——落点=饭桌，无尾段，无解释舱室 ---
	var s4: Node3D = await _boot()
	var w4: Node3D = s4.get_node("ChapterWorld")
	s4.core.choose(0, 1)   # 记者
	s4.core.choose(1, 1)   # 海边小镇 warm+1
	s4.core.choose(2, 1)   # 家书 warm+1
	s4.core.submit_chapter()
	s4.core.choose(0, 1)   # 老友 warm+1
	s4.core.choose(1, 0)   # 黄铜钥匙（记者派生 warm+1）
	s4.core.choose(2, 1)   # 被撤的报道 susp+1
	s4.core.submit_chapter()
	s4.core.choose(0, 1)   # 想回家 warm
	s4.core.choose(1, 1)   # 代笔的字条 warm
	s4.core.choose(2, 1)   # 回家吃饭 warm
	s4.core.choose(3, 0)   # 推开老屋的门 warm（无冲突）
	s4.core.submit_chapter()
	s4.core.choose(0, 1)   # 粥 warm
	s4.core.choose(1, 1)   # 等我回家 warm
	s4.core.choose(2, 2)   # 保持克制 susp+1
	s4.core.choose(3, 1)   # 想回家吃一顿热饭 warm
	s4.core.submit_chapter()
	await physics_frame
	_check(int(s4.core.chapter_idx) == 4 and not s4.core.flags.has("secret"), "B7a 温情线进第 5 章（无解释）")
	_check(not _has_ins(w4, "secret_tail") and w4.get_node_or_null("VariantRoot/Cham_W") == null, "B7b 无解释：无尾段无舱室")
	_check(_has_ins(w4, "ending_spot"), "B7c 终稿落点在场")
	var spot4: Vector3 = w4.get_node("VariantRoot/INS_ending_spot").position
	_check(absf(spot4.x + 3.5) < 0.01 and absf(spot4.z + 6.5) < 0.01, "B7d 主基调=温情 → 落点=室内饭桌")
	_check(str(_ins_text(w4, "ending_spot")).contains("《归途》"), "B7e 落点文本=终稿《归途》")
	s4.core.choose(0, 1)
	s4.core.choose(1, 1)
	s4.core.choose(2, 1)
	s4.core.choose(3, 1)
	s4.core.choose(4, 1)
	s4.core.submit_chapter()
	await physics_frame
	_check(str(s4.core.state) == "final", "B7f 温情线过审出版")
	await _drop(s4)

	# --- 段11：基调氛围（世界灯光读基调；纯氛围无数值，盲测安全） ---
	var s5: Node3D = await _boot()
	var w5: Node3D = s5.get_node("ChapterWorld")
	var sun0: Color = w5._sun.light_color
	w5.set_tone_mood("sci", 1.0)
	var sun_sci: Color = w5._sun.light_color
	w5.set_tone_mood("warm", 1.0)
	var sun_warm: Color = w5._sun.light_color
	_check(not sun_sci.is_equal_approx(sun_warm) and not sun0.is_equal_approx(sun_sci),
		"段11a set_tone_mood：sci/warm/默认 灯光色互异")
	w5.set_tone_mood("", 0.0)
	_check(w5._sun.light_color.is_equal_approx(sun0), "段11b 中性氛围回到默认灯光")
	s5.core.choose(0, 0)   # 侦探 susp+1
	s5.core.choose(1, 0)   # 小镇
	s5.core.choose(2, 0)   # 古井 susp+1
	await physics_frame
	_check(str(s5.bridge.dominant_tone()) == "susp", "段11c 主基调判定=susp")
	_check(not w5._sun.light_color.is_equal_approx(sun0), "段11d 事务后根脚本自动应用基调氛围")
	await _drop(s5)

	# --- 段13：支线机制「证物联动暗室」——派生证物落定→东墙暗门开启；重置→重新封死 ---
	var s6: Node3D = await _boot()
	var w6: Node3D = s6.get_node("ChapterWorld")
	var ex6: CharacterBody3D = s6.get_node("Explorer")
	_check(not w6.is_position_safe(Vector3(6.0, 0.2, -6.0)), "段13a 证物未落定：东墙封死（暗门点位不可站）")
	_check(not _has_ins(w6, "evidence_box"), "段13b 证物匣不存在（不预泄）")
	s6.core.choose(0, 1)   # 记者
	s6.core.choose(1, 0)   # 小镇
	s6.core.choose(2, 3)   # 旧照片
	s6.core.submit_chapter()
	s6.core.choose(1, 0)   # 黄铜钥匙（记者派生 evidence=上锁抽屉的钥匙）
	await physics_frame
	_check(str(s6.core.flags.get("evidence", "")) == "上锁抽屉的钥匙", "段13c 证物派生落定")
	_check(w6.is_position_safe(Vector3(6.0, 0.2, -6.0)) and w6.is_position_safe(Vector3(8.0, 0.2, -6.5)),
		"段13d 暗门洞与证物间内部可站（真实可走几何）")
	_check(_has_ins(w6, "evidence_box"), "段13e 证物匣在场")
	_check(str(_ins_text(w6, "evidence_box")).contains("上锁抽屉的钥匙"), "段13f 证物匣文本引用所选证物")
	var route6 := [Vector3(0, 0.2, -6.0), Vector3(3.0, 0.2, -6.0), Vector3(6.0, 0.2, -6.0), Vector3(8.0, 0.2, -6.5)]
	_check(_route_ok(w6, route6), "段13g 室内→暗门→证物间 通路全通")
	s6.core.reset_chapter()
	await physics_frame
	_check(not s6.core.flags.has("evidence"), "段13h 重置本章：证物回滚")
	_check(not w6.is_position_safe(Vector3(6.0, 0.2, -6.0)) and not _has_ins(w6, "evidence_box"),
		"段13i 暗室重新封死、证物匣移除（WorldSpec 事务一致）")
	_check(w6.is_position_safe(ex6.global_position), "段13j 玩家位置安全（如曾入室则被迁移）")
	await _drop(s6)

	# --- 段14：机制关卡 2「井台进化」——悬疑基调驱动井口三档变化；悬疑终稿红布不重复建井 ---
	var s7: Node3D = await _boot()
	var w7: Node3D = s7.get_node("ChapterWorld")
	s7.core.choose(0, 1)   # 记者
	s7.core.choose(1, 0)   # 小镇
	s7.core.choose(2, 3)   # 旧照片
	s7.core.submit_chapter()
	s7.core.choose(0, 1)   # 老友 warm+1
	s7.core.choose(1, 0)   # 钥匙 warm+1
	s7.core.choose(2, 0)   # 撤稿 susp+1 → susp=1
	s7.core.submit_chapter()
	await physics_frame
	_check(int(s7.core.stats.susp) == 1 and w7.get_node_or_null("VariantRoot/Well_Base") != null
		and w7.get_node_or_null("VariantRoot/Well_Water") != null
		and w7.get_node_or_null("VariantRoot/Well_Mist") == null,
		"段14a 悬疑1：井台揭盖现暗水、无雾光")
	_check(not w7.is_position_safe(Vector3(-2.5, 0.35, -17.5)), "段14b 井台基座为实体障碍（碰撞原样）")
	s7.core.choose(2, 0)   # 别相信回来的那个人 susp+1 → susp=2
	await physics_frame
	_check(w7.get_node_or_null("VariantRoot/Well_Mist") != null
		and w7.get_node_or_null("VariantRoot/Well_Glow") != null, "段14c 悬疑2：井口雾光出现（事务重建）")
	s7.core.choose(1, 2)   # 井栏刻字磨平 susp-1 → susp=1
	await physics_frame
	_check(w7.get_node_or_null("VariantRoot/Well_Mist") == null
		and w7.get_node_or_null("VariantRoot/Well_Water") != null, "段14d 悬疑回落：雾光随事务撤除、暗水保留")
	# 推到第 5 章温情终稿：同一口井只添红布，不重复建井
	s7.core.choose(0, 1)   # 想回家 warm+1
	s7.core.choose(2, 1)   # 回家吃饭 warm+1
	s7.core.choose(3, 0)   # 推开老屋的门 warm+1
	s7.core.submit_chapter()
	s7.core.choose(0, 1)
	s7.core.choose(1, 1)
	s7.core.choose(2, 2)   # 保持克制（非陷阱）
	s7.core.choose(3, 1)
	s7.core.submit_chapter()
	await physics_frame
	_check(int(s7.core.chapter_idx) == 4 and str(s7.bridge.dominant_tone()) == "warm",
		"段14e 抵达第 5 章温情主基调")
	_check(w7.get_node_or_null("VariantRoot/EndSpotRedCloth") == null,
		"段14f 温情终稿：井台无红布（红布只属悬疑终稿）")
	await _drop(s7)

	# --- 段14 续：悬疑线终稿——红布落在已进化的井上（不重复建井） ---
	var s8: Node3D = await _boot()
	var w8: Node3D = s8.get_node("ChapterWorld")
	s8.core.choose(0, 1)
	s8.core.choose(1, 0)
	s8.core.choose(2, 3)
	s8.core.submit_chapter()
	s8.core.choose(0, 0)   # 卷宗 susp+1
	s8.core.choose(1, 2)   # 手稿（侦探派生 susp+1）
	s8.core.choose(2, 0)   # 撤稿 susp+1 → susp=3
	s8.core.submit_chapter()
	s8.core.choose(0, 2)   # 别相信 susp+1
	s8.core.choose(1, 0)   # 星图伪造 sci
	s8.core.choose(2, 0)   # 别相信 susp+1
	s8.core.choose(3, 1)   # 第二串脚印 susp+1
	s8.core.submit_chapter()
	await physics_frame
	_check(w8.get_node_or_null("VariantRoot/Well_Base") != null
		and w8.get_node_or_null("VariantRoot/Well_Mist") != null, "段14g 悬疑线后院井台=雾光档")
	s8.core.choose(0, 3)   # 门缝匿名卷宗 susp
	s8.core.choose(1, 0)   # 真相 susp
	s8.core.choose(2, 2)   # 克制 susp
	s8.core.choose(3, 0)   # 还活着 susp
	s8.core.submit_chapter()
	await physics_frame
	_check(int(s8.core.chapter_idx) == 4 and str(s8.bridge.dominant_tone()) == "susp", "段14h 悬疑主基调进第 5 章")
	_check(w8.get_node_or_null("VariantRoot/Well_Base") != null
		and w8.get_node_or_null("VariantRoot/EndSpotWell") == null
		and w8.get_node_or_null("VariantRoot/EndSpotRedCloth") != null,
		"段14i 悬疑终稿：红布落在既有井台上（EndSpotWell 未重复建造）")
	_check(_has_ins(w8, "ending_spot"), "段14j 终稿落点检查点在场")
	await _drop(s8)

	# --- 段15：机制关卡 3「屋顶检修梯」——E 交互上下 + 高度感知安全 ---
	var s9: Node3D = await _boot()
	var w9: Node3D = s9.get_node("ChapterWorld")
	var ex9: CharacterBody3D = s9.get_node("Explorer")
	var inter9: Node3D = s9.get_node("InteractionController")
	s9.core.choose(0, 1)
	s9.core.choose(1, 0)
	s9.core.choose(2, 3)
	s9.core.submit_chapter()
	s9.core.choose(0, 1)
	s9.core.choose(1, 0)
	s9.core.choose(2, 0)
	s9.core.submit_chapter()
	await physics_frame
	_check(_has_ins(w9, "ladder_base") and _has_ins(w9, "ladder_top") and _has_ins(w9, "roof_look"),
		"段15a 梯架垫与屋顶检查点在场（第 3 章+）")
	_check(w9.is_position_safe(Vector3(0, 3.95, -7.0)), "段15b 屋顶矮道=安全站位（高度感知）")
	_check(w9.is_position_safe(Vector3(0, 0.2, -7.5)), "段15c 室内地面站位仍安全（高度感知不误伤）")
	# 真实射线：站到梯基锚点，面朝梯架（梯基在北侧，forward=-z → yaw=0）→ 命中垫点 → E 传送登顶
	ex9.global_position = Vector3(-7.5, 0.2, -9.0)
	ex9.yaw = 0.0
	ex9.rotation.y = 0.0
	ex9.cam.rotation.x = 0.0
	for i in 4:
		await physics_frame
	var col: Node3D = inter9.current_collider()
	_check(col != null and str(col.get_meta("ladder_to")) == "roof_top", "段15d 视线命中梯基垫（ladder_to=roof_top）")
	s9._on_interact()
	await physics_frame
	_check(ex9.global_position.y > 3.5, "段15e E 交互登顶（y=%.2f）" % ex9.global_position.y)
	_check(w9.is_position_safe(ex9.global_position), "段15f 屋顶站位安全")
	# 屋顶看 roof_look
	ex9.yaw = -PI / 2
	ex9.rotation.y = -PI / 2
	ex9.cam.rotation.x = deg_to_rad(-23.0)
	for i in 4:
		await physics_frame
	_check(inter9.current_target() == "roof_look", "段15g 视线命中屋顶检查点")
	s9._on_interact()
	_check(s9.get_node("Hud").inspect_panel.visible, "段15h 屋顶检查卡弹出")
	# 梯顶垫 → 下地面
	ex9.global_position = Vector3(-5.4, 3.95, -7.0)
	ex9.yaw = deg_to_rad(37.0)
	ex9.rotation.y = ex9.yaw
	ex9.cam.rotation.x = deg_to_rad(-25.0)
	for i in 4:
		await physics_frame
	col = inter9.current_collider()
	_check(col != null and str(col.get_meta("ladder_to")) == "yard_ladder_base", "段15i 梯顶垫可命中（ladder_to=yard_ladder_base）")
	s9._on_interact()
	await physics_frame
	_check(ex9.global_position.y < 0.5 and w9.is_position_safe(ex9.global_position), "段15j E 交互下到后院地面")
	await _drop(s9)

	# --- 段16：机制关卡 4「证物匣藏格」——藏格开格与文本随道具联动 ---
	var sA: Node3D = await _boot()
	var wA: Node3D = sA.get_node("ChapterWorld")
	sA.core.choose(0, 1)
	sA.core.choose(1, 0)
	sA.core.choose(2, 2)   # 星图
	sA.core.submit_chapter()
	sA.core.choose(1, 0)   # 黄铜钥匙 → 证物间开
	await physics_frame
	_check(_has_ins(wA, "evidence_box"), "段16a 证物匣在场")
	_check(str(_ins_text(wA, "evidence_box")).contains("坐标"), "段16b 星图线文本=坐标藏格")
	_check(str(_ins_text(wA, "evidence_box")).contains("上锁抽屉的钥匙"), "段16c 文本仍引用所选证物")
	_check(wA.get_node_or_null("VariantRoot/EvStashGroup/EvStashOpen") != null, "段16d 开格节点在场")
	var openA: Vector3 = wA.get_node("VariantRoot/EvStashGroup/EvStashOpen").position
	_check(absf(openA.x - (8.45 + 2 * 0.24)) < 0.01, "段16e 星图 → 开格=第 3 格")
	await _drop(sA)

	var sB: Node3D = await _boot()
	var wB: Node3D = sB.get_node("ChapterWorld")
	sB.core.choose(0, 1)
	sB.core.choose(1, 0)
	sB.core.choose(2, 1)   # 家书
	sB.core.submit_chapter()
	sB.core.choose(1, 0)   # 黄铜钥匙 → 证物间开
	await physics_frame
	_check(str(_ins_text(wB, "evidence_box")).contains("信笺"), "段16f 家书线文本=信笺藏格")
	var openB: Vector3 = wB.get_node("VariantRoot/EvStashGroup/EvStashOpen").position
	_check(absf(openB.x - (8.45 + 1 * 0.24)) < 0.01, "段16g 家书 → 开格=第 2 格")
	_check(not (openA.is_equal_approx(openB)), "段16h 不同道具 → 开格位置不同（联动可见）")
	await _drop(sB)

	# --- 段17：机制关卡 5「初见观察」——首次检查追加观察行，重复检查回归常规 ---
	var sC: Node3D = await _boot()
	sC.core.choose(0, 1)
	sC.core.choose(1, 0)
	sC.core.choose(2, 3)
	var t1: String = sC.interact_text("desk_letter")
	var t2: String = sC.interact_text("desk_letter")
	_check(t1.contains("毛边") and t1.contains("第一次"), "段17a 首次检查含初见观察行")
	_check(t2.contains("落款") and not (t2.contains("第一次")), "段17b 重复检查回归常规文本")
	_check(sC.bridge.inspected_once.has("desk_letter"), "段17c 已读记忆生效")
	var t3: String = sC.interact_text("mail_slot")
	_check(t3.contains("邮戳") and sC.bridge.inspected_once.has("mail_slot"), "段17d 其他对象独立记首次")
	_check(t1.begins_with("信摊开着"), "段17e 常规文本在前、观察行在后（顺序稳定）")
	await _drop(sC)

	# --- 段18：机制关卡 6「灌木开花」——温情基调驱动植被三档变化 ---
	var sD: Node3D = await _boot()
	var wD: Node3D = sD.get_node("ChapterWorld")
	var flower_count := func() -> int:
		var n := 0
		for c in wD.get_node("VariantRoot").get_children():
			if str(c.name).begins_with("BushFlower"):
				n += 1
		return n
	_check(flower_count.call() == 0, "段18a 温情0：无花")
	sD.core.choose(0, 1)   # 记者
	sD.core.choose(1, 1)   # 海边小镇 warm+1 → tier1
	await physics_frame
	_check(flower_count.call() == 6, "段18b 温情1：两丛各 3 朵（6 花）")
	sD.core.choose(2, 1)   # 家书 warm+1 → tier2
	await physics_frame
	_check(flower_count.call() == 12 and wD.get_node_or_null("VariantRoot/BushGlow") != null, "段18c 温情2：两丛各 6 朵+微光")
	sD.core.choose(0, 0)   # 改侦探 susp+1（warm 仍 2）
	await physics_frame
	_check(flower_count.call() == 12, "段18d 基调变化不误伤花位（warm 未降）")
	await _drop(sD)

	# --- 段19：机制关卡 7「旧天线复苏」——科幻基调驱动屋顶旧物三档 ---
	var sE: Node3D = await _boot()
	var wE: Node3D = sE.get_node("ChapterWorld")
	_check(wE.get_node_or_null("VariantRoot/AntennaPole") != null and wE.get_node_or_null("VariantRoot/AntennaTip") == null, "段19a 科幻0：旧天线静默在场、无尖端光")
	sE.core.choose(0, 2)   # 宇航员 sci+1 → tier1
	await physics_frame
	_check(wE.get_node_or_null("VariantRoot/AntennaTip") != null and wE.get_node_or_null("VariantRoot/AntennaGlow") == null, "段19b 科幻1：尖端微光亮起、无光晕")
	sE.core.choose(2, 2)   # 星图 sci+1 → tier2
	await physics_frame
	_check(wE.get_node_or_null("VariantRoot/AntennaGlow") != null, "段19c 科幻2：蓝光晕出现（事务重建）")
	sE.core.choose(1, 0)   # 多雨的南方小镇（无基调，sci 仍 2）
	await physics_frame
	_check(wE.get_node_or_null("VariantRoot/AntennaGlow") != null, "段19d 其他词槽变化不误伤天线档位")
	await _drop(sE)

	# --- 段21：机制关卡 9「指向星图的频道」——天线×星图组合观察，prop 变化即回正 ---
	var sG: Node3D = await _boot()
	var wG: Node3D = sG.get_node("ChapterWorld")
	sG.core.choose(0, 2)   # 宇航员 sci+1
	sG.core.choose(1, 0)   # 小镇
	sG.core.choose(2, 2)   # 星图 sci+1 → sci2 × prop=星图 → 组合成立
	await physics_frame
	var armsG: Node3D = wG.get_node_or_null("VariantRoot/AntennaArms")
	_check(armsG != null and absf(armsG.rotation.z) > 0.4, "段21a 组合成立：天线横枝偏转校准")
	_check(_has_ins(wG, "antenna_note"), "段21b 天线指向检查点在场")
	_check(str(_ins_text(wG, "antenna_note")).contains("星图"), "段21c 检查文本绑定星图坐标")
	sG.core.choose(2, 1)   # 同槽改家书 → prop 变化 → 组合破
	await physics_frame
	armsG = wG.get_node_or_null("VariantRoot/AntennaArms")
	_check(armsG != null and absf(armsG.rotation.z) < 0.01 and not _has_ins(wG, "antenna_note"),
		"段21d prop 改家书：横枝回正、检查点随事务移除")
	sG.core.choose(2, 2)   # 改回星图 → 组合再成立
	await physics_frame
	armsG = wG.get_node_or_null("VariantRoot/AntennaArms")
	_check(armsG != null and absf(armsG.rotation.z) > 0.4 and _has_ins(wG, "antenna_note"),
		"段21e 改回星图：再次校准且检查点唯一恢复")
	await _drop(sG)

	# --- 段22：机制关卡 10「窗台的碗筷」——温情×证物组合观察，重置即撤 ---
	var sH: Node3D = await _boot()
	var wH: Node3D = sH.get_node("ChapterWorld")
	sH.core.choose(0, 1)   # 记者
	sH.core.choose(1, 1)   # 海边小镇 warm+1
	sH.core.choose(2, 3)   # 旧照片
	sH.core.submit_chapter()   # → 第 2 章：warm=1、证物未落定
	await physics_frame
	_check(not _has_ins(wH, "window_setting"), "段22a 仅温情：碗筷未出现（组合未成立）")
	sH.core.choose(1, 0)   # 黄铜钥匙 → 证物落定 → 组合成立
	await physics_frame
	_check(_has_ins(wH, "window_setting") and wH.get_node_or_null("VariantRoot/SettingBowl1") != null,
		"段22b 温情×证物同时成立：窗台碗筷在场")
	_check(str(_ins_text(wH, "window_setting")).contains("上锁抽屉的钥匙"), "段22c 碗筷文本引用所选证物")
	sH.core.reset_chapter()   # 重置本章 → 证物回滚 → 组合破
	await physics_frame
	_check(not _has_ins(wH, "window_setting") and wH.get_node_or_null("VariantRoot/SettingBowl1") == null,
		"段22d 重置本章：碗筷随事务撤除")
	sH.core.choose(1, 0)   # 重新落定证物 → 组合再成立
	await physics_frame
	var wc := 0
	for c in wH.get_node("VariantRoot").get_children():
		if str(c.name) == "INS_window_setting":
			wc += 1
	_check(wc == 1 and _has_ins(wH, "window_setting"), "段22e 组合再成立：碗筷恢复且唯一")
	await _drop(sH)

	# --- 段23：机制关卡 11「晚饭与井水」——碗筷×井台回光三条件深层组合 ---
	var sI: Node3D = await _boot()
	var wI: Node3D = sI.get_node("ChapterWorld")
	sI.core.choose(0, 1)   # 记者
	sI.core.choose(1, 1)   # 海边小镇 warm+1
	sI.core.choose(2, 3)   # 旧照片
	sI.core.submit_chapter()
	sI.core.choose(0, 2)   # 调阅日志
	sI.core.choose(1, 0)   # 黄铜钥匙 → 证物落定
	sI.core.choose(2, 0)   # 撤稿 susp+1 → 三条件齐（温情×证物×悬疑）
	sI.core.submit_chapter()
	await physics_frame
	_check(wI.get_node_or_null("VariantRoot/WaterBowl") != null, "段23a 三条件齐：窗台多出水碗")
	_check(str(_ins_text(wI, "window_setting")).contains("井水") and str(_ins_text(wI, "well_reflection")).contains("热气"),
		"段23b 两端文本互相呼应（窗台碗水/井沿热气）")
	sI.core.choose(1, 2)   # 井栏磨平 susp-1 → 深组合破（碗筷仍在，回光撤）
	await physics_frame
	_check(wI.get_node_or_null("VariantRoot/WaterBowl") == null, "段23c 悬疑回落：水碗随事务撤除")
	_check(str(_ins_text(wI, "window_setting")).contains("井水") == false, "段23d 窗台文本回归常规（组合文本不残留）")
	await _drop(sI)

	# --- 段24：机制关卡 12「三处刻痕」——跨对象收集谜题，集齐浮现回响字条 ---
	var sJ: Node3D = await _boot()
	var wJ: Node3D = sJ.get_node("ChapterWorld")
	sJ.core.choose(0, 1)   # 记者
	sJ.core.choose(1, 1)   # 海边小镇 warm+1
	sJ.core.choose(2, 3)   # 旧照片
	sJ.core.submit_chapter()
	sJ.core.choose(0, 2)   # 调阅日志 sci+1
	sJ.core.choose(1, 0)   # 黄铜钥匙 → 证物
	sJ.core.choose(2, 0)   # 撤稿 susp+1 → 三刻痕全部在场
	sJ.core.submit_chapter()   # 进第 3 章：后院井台在场
	await physics_frame
	_check(_has_ins(wJ, "well_mark") and _has_ins(wJ, "sill_mark") and _has_ins(wJ, "antenna_mark"),
		"段24a 三处刻痕全部在场（井沿/窗台/天线底座）")
	_check(not _has_ins(wJ, "echo_note"), "段24b 未集齐：回响字条不出现")
	sJ.interact_text("well_mark")
	sJ.interact_text("sill_mark")
	_check(not _has_ins(wJ, "echo_note"), "段24c 集齐 2/3：字条仍不出现")
	sJ.interact_text("antenna_mark")   # 第三处 → 集齐 → bridge bump → 正规事务重建
	await physics_frame
	await physics_frame
	_check(_has_ins(wJ, "echo_note"), "段24d 集齐 3/3：屋顶浮现回响字条")
	_check(str(_ins_text(wJ, "echo_note")).contains("他还活着"), "段24e 回响字条文本完整（落款呼应第一章）")
	sJ.interact_text("well_mark")   # 重复检查不重复计数
	await physics_frame
	var ec := 0
	for c in wJ.get_node("VariantRoot").get_children():
		if str(c.name) == "INS_echo_note":
			ec += 1
	_check(ec == 1, "段24f 重复检查不产生重复字条")
	await _drop(sJ)

	# --- 段25：机制关卡 13「回响字条系列」——已读驱动递进链（宇航员线凑齐 sci2） ---
	var sK: Node3D = await _boot()
	var wK: Node3D = sK.get_node("ChapterWorld")
	sK.core.choose(0, 2)   # 宇航员 sci+1
	sK.core.choose(1, 0)   # 小镇
	sK.core.choose(2, 2)   # 星图 sci+1 → sci2
	sK.core.submit_chapter()
	sK.core.choose(0, 1)   # 老友 warm+1
	sK.core.choose(1, 2)   # 手稿 → 证物
	sK.core.choose(2, 1)   # 导航日志 sci+1
	sK.core.submit_chapter()   # 第 3 章：warm1/sci3/证据落定
	sK.interact_text("well_mark")
	sK.interact_text("sill_mark")
	sK.interact_text("antenna_mark")
	await physics_frame
	_check(not _has_ins(wK, "note2"), "段25a 回响字条未读：字条二不出现")
	sK.interact_text("echo_note")   # 读回响字条 → 字条二浮现（证物间夹层）
	await physics_frame
	_check(_has_ins(wK, "note2"), "段25b 读回响字条：证物间浮现字条二")
	_check(str(_ins_text(wK, "note2")).contains("宝盖头"), "段25c 字条二文本=偏旁之二")
	_check(not _has_ins(wK, "note3"), "段25d 字条二未读：字条三不出现")
	sK.interact_text("note2")   # 读字条二 → 字条三浮现（科幻≥2）
	await physics_frame
	_check(_has_ins(wK, "note3") and str(_ins_text(wK, "note3")).contains("捺"), "段25e 读字条二：底座浮现字条三")
	sK.interact_text("note3")   # 读字条三 → 回响字条背面补终句
	await physics_frame
	_check(str(_ins_text(wK, "echo_note")).contains("回家"), "段25f 三张读齐：回响字条补终句（回家）")
	await _drop(sK)

	# --- 段27：机制关卡 15「回响字条 · 四」——观星台×字条三联动收束 ---
	var sM: Node3D = await _boot()
	var wM: Node3D = sM.get_node("ChapterWorld")
	sM.core.choose(0, 2)
	sM.core.choose(1, 0)
	sM.core.choose(2, 2)   # 星图 sci+1 → sci2
	sM.core.submit_chapter()
	sM.core.choose(0, 1)
	sM.core.choose(1, 2)   # 手稿 → 证物
	sM.core.choose(2, 1)   # 导航日志 sci+1
	sM.core.submit_chapter()   # 第 3 章：观星台在场（sci2×星图）
	sM.interact_text("well_mark")
	sM.interact_text("sill_mark")
	sM.interact_text("antenna_mark")
	sM.interact_text("echo_note")
	sM.interact_text("note2")
	await physics_frame
	_check(not _has_ins(wM, "note4"), "段27a 字条三未读：字条四不出现")
	sM.interact_text("note3")   # 读字条三 → 观星台×字条三 → 字条四浮现
	await physics_frame
	_check(_has_ins(wM, "note4") and str(_ins_text(wM, "note4")).contains("擦亮了"),
		"段27b 字条四浮现且文本=系列收束（都擦亮了）")
	sM.interact_text("note4")   # 读毕（read_notes 记入，无后续投影）
	await physics_frame
	var nc := 0
	for c in wM.get_node("VariantRoot").get_children():
		if str(c.name) == "INS_note4":
			nc += 1
	_check(nc == 1 and sM.bridge.read_notes.has("note4"), "段27c 字条四读毕记入且唯一")
	await _drop(sM)

	# --- 段28：机制关卡 16「望远镜的指向」——镜筒随双解释分化（colony 上仰 / mine 下俯） ---
	var sN: Node3D = await _boot()
	var wN: Node3D = sN.get_node("ChapterWorld")
	sN.core.choose(0, 2)
	sN.core.choose(1, 0)
	sN.core.choose(2, 2)   # 星图 sci2 → 观星台
	await physics_frame
	var tubeN: Node3D = wN.get_node_or_null("VariantRoot/TelescopeTube")
	_check(tubeN != null and absf(tubeN.rotation.x + 0.5) < 0.01, "段28a 无秘密：镜筒持平（默认姿态）")
	sN.core.submit_chapter()
	sN.core.choose(0, 1)
	sN.core.choose(1, 2)
	sN.core.choose(2, 1)
	sN.core.submit_chapter()   # 第 3 章
	sN.core.choose(0, 0)
	sN.core.choose(1, 0)
	sN.core.choose(2, 0)
	sN.core.choose(3, 0)
	sN.core.submit_chapter()   # 第 4 章
	sN.core.choose(0, 3)   # 殖民飞船 → secret=colony_ship
	await physics_frame
	tubeN = wN.get_node_or_null("VariantRoot/TelescopeTube")
	_check(tubeN != null and absf(tubeN.rotation.x + 0.55) < 0.01, "段28b colony：镜筒上仰指月")
	_check(str(_ins_text(wN, "telescope")).contains("环月轨道"), "段28c colony 文本=指月")
	sN.core.choose(0, 4)   # 改矿井 → secret=mine_door
	await physics_frame
	tubeN = wN.get_node_or_null("VariantRoot/TelescopeTube")
	_check(tubeN != null and absf(tubeN.rotation.x - 0.35) < 0.01, "段28d mine：镜筒下俯指矿井")
	_check(str(_ins_text(wN, "telescope")).contains("落在地上"), "段28e mine 文本=落在地上")
	await _drop(sN)

	# --- 段29：机制关卡 17「擦净镜片」——字条四读毕 → 霜膜消失、镜片微光、文本追加 ---
	var sO: Node3D = await _boot()
	var wO: Node3D = sO.get_node("ChapterWorld")
	sO.core.choose(0, 2)
	sO.core.choose(1, 0)
	sO.core.choose(2, 2)
	sO.core.submit_chapter()
	sO.core.choose(0, 1)
	sO.core.choose(1, 2)
	sO.core.choose(2, 1)
	sO.core.submit_chapter()
	sO.core.choose(0, 0)
	sO.core.choose(1, 0)
	sO.core.choose(2, 0)
	sO.core.choose(3, 0)
	sO.core.submit_chapter()
	sO.core.choose(0, 3)   # colony → 观星台+望远镜
	await physics_frame
	_check(wO.get_node_or_null("VariantRoot/LensFrost") != null, "段29a 未读字条四：镜片蒙霜")
	_check(wO.get_node_or_null("VariantRoot/LensSpark") == null, "段29b 未擦净：无微光")
	sO.interact_text("note4")   # 读字条四 → 霜被擦净
	await physics_frame
	_check(wO.get_node_or_null("VariantRoot/LensFrost") == null and wO.get_node_or_null("VariantRoot/LensSpark") != null,
		"段29c 读毕字条四：霜膜消失、镜片微光浮现")
	_check(str(_ins_text(wO, "telescope")).contains("擦净"), "段29d 望远镜文本追加擦净笔")
	await _drop(sO)

	# --- 段30：机制关卡 18「穿过气闸」——门开前不可达，门开后可达气闸室（文本随双解释分化） ---
	var sP: Node3D = await _boot()
	var wP: Node3D = sP.get_node("ChapterWorld")
	sP.core.choose(0, 1)
	sP.core.choose(1, 0)
	sP.core.choose(2, 3)
	sP.core.submit_chapter()
	sP.core.choose(0, 2)
	sP.core.choose(1, 2)
	sP.core.choose(2, 0)
	sP.core.submit_chapter()   # 第 3 章：秘密未落定
	await physics_frame
	_check(not _has_ins(wP, "airlock_room") and not wP.is_position_safe(Vector3(0, 0.2, -19.9)),
		"段30a 秘密未落定：无气闸室、门体不可过")
	sP.core.choose(0, 0)
	sP.core.choose(1, 0)
	sP.core.choose(2, 0)
	sP.core.choose(3, 2)   # 舷梯气闸 悬疑+1 → anomaly
	sP.core.submit_chapter()   # 第 4 章
	sP.core.choose(0, 3)   # 殖民飞船 → 气闸开
	await physics_frame
	_check(_has_ins(wP, "airlock_room") and wP.is_position_safe(Vector3(0, 0.2, -21.5)),
		"段30b colony：门开、气闸室可达")
	_check(str(_ins_text(wP, "airlock_room")).contains("月亮"), "段30c colony 文本=星图复写+月亮")
	sP.core.choose(0, 4)   # 改矿井
	await physics_frame
	_check(str(_ins_text(wP, "airlock_room")).contains("罗盘"), "段30d mine 文本=旧罗盘")
	sP.core.choose(0, 0)   # 换普通候选 → 秘密回落 → 门再锁
	await physics_frame
	_check(not _has_ins(wP, "airlock_room") and not wP.is_position_safe(Vector3(0, 0.2, -19.9)),
		"段30e 秘密回落：门再锁、气闸室撤除")
	await _drop(sP)

	# --- 段31：机制关卡 19「气闸室的井水」——温情×证物×悬疑×秘密四线在气闸室收束 ---
	var sQ: Node3D = await _boot()
	var wQ: Node3D = sQ.get_node("ChapterWorld")
	sQ.core.choose(0, 1)   # 记者
	sQ.core.choose(1, 1)   # 海边小镇 warm+1
	sQ.core.choose(2, 3)   # 旧照片
	sQ.core.submit_chapter()
	sQ.core.choose(0, 2)   # 调阅日志 sci+1
	sQ.core.choose(1, 2)   # 手稿 → 记者派生 warm+1 + 证物落定
	sQ.core.choose(2, 0)   # 悄悄撤下报道 susp+1
	sQ.core.submit_chapter()   # 第 3 章：warm2 susp1 证物落定
	sQ.core.choose(3, 2)   # 舷梯气闸 → anomaly + sci
	sQ.core.choose(0, 0)   # 深空计划 sci+1
	sQ.core.choose(1, 0)   # 星图伪造 sci+1
	sQ.core.choose(2, 0)   # 别相信回来的那个人 susp+1
	sQ.core.submit_chapter()   # 第 4 章（sci≥2 达标）：秘密未落定
	await physics_frame
	_check(not _has_ins(wQ, "airlock_water"), "段31a 秘密未落定：气闸室井水不出现")
	sQ.core.choose(0, 3)   # colony → 秘密落定 → 气闸室+井水四线齐
	await physics_frame
	_log("DBG: airlock_water_ins=%s bowl=%s warm=%d susp=%d ev=%s secret=%s" % [str(_has_ins(wQ, "airlock_water")), str(wQ.get_node_or_null("VariantRoot/AirWaterBowl") != null), int(sQ.core.stats.warm), int(sQ.core.stats.susp), str(sQ.core.flags.get("evidence", "")), str(sQ.core.flags.get("secret", ""))])
	_check(_has_ins(wQ, "airlock_water") and wQ.get_node_or_null("VariantRoot/AirWaterBowl") != null,
		"段31b 四线齐：气闸室角落浮现井水")
	_check(str(_ins_text(wQ, "airlock_water")).contains("温着"), "段31c 井水文本呼应窗台")
	_check(str(_ins_text(wQ, "well_reflection")).contains("气闸室"), "段31d 井面文本呼应气闸室")
	sQ.core.choose(0, 4)   # 改矿井 → secret 切换，井水 persists（secret 仍非空）
	await physics_frame
	_check(_has_ins(wQ, "airlock_water"), "段31e mine 线井水 persists")
	await _drop(sQ)

	# --- 段26：机制关卡 14「观星台」——天线×星图的空间化（屋顶东端可进入小板房） ---
	var sL: Node3D = await _boot()
	var wL: Node3D = sL.get_node("ChapterWorld")
	var exL: CharacterBody3D = sL.get_node("Explorer")
	sL.core.choose(0, 2)   # 宇航员 sci+1
	sL.core.choose(1, 0)   # 小镇
	sL.core.choose(2, 1)   # 家书 → prop≠星图 → 组合未成立
	await physics_frame
	_check(wL.get_node_or_null("VariantRoot/Hut_N") == null and not _has_ins(wL, "telescope"),
		"段26a prop≠星图：观星台不出现")
	sL.core.choose(2, 2)   # 同槽改星图 → sci2 × 星图 → 观星台立起
	await physics_frame
	_check(wL.get_node_or_null("VariantRoot/Hut_N") != null and _has_ins(wL, "telescope"),
		"段26b 星图×科幻2：观星台在场（围墙+望远镜）")
	var routeL := [Vector3(-5.4, 3.95, -7.0), Vector3(0, 3.95, -6.5), Vector3(3.0, 3.95, -5.35), Vector3(3.8, 3.95, -5.35), Vector3(4.6, 3.95, -5.4), Vector3(5.2, 3.95, -5.4)]
	_check(_route_ok(wL, routeL), "段26c 屋顶矮道东行→门洞→板房内部 通路全通")
	_check(str(_ins_text(wL, "telescope")).contains("星图"), "段26d 望远镜文本绑定星图坐标")
	# prop 改家书 → 观星台随事务撤除
	sL.core.choose(2, 1)
	await physics_frame
	_check(wL.get_node_or_null("VariantRoot/Hut_N") == null and not _has_ins(wL, "telescope"),
		"段26e prop 改家书：观星台随事务撤除")
	_check(wL.is_position_safe(Vector3(5.0, 3.95, -5.4)), "段26f 板房位置回归屋顶矮道（安全）")
	await _drop(sL)

	# --- 段20：机制关卡 8「井底的回应」——证物×悬疑组合观察，条件破即撤 ---
	var sF: Node3D = await _boot()
	var wF: Node3D = sF.get_node("ChapterWorld")
	sF.core.choose(0, 2)   # 宇航员
	sF.core.choose(1, 0)   # 小镇
	sF.core.choose(2, 2)   # 星图
	sF.core.submit_chapter()
	sF.core.choose(0, 1)   # 老友 warm+1
	sF.core.choose(1, 2)   # 手稿 → 宇航员派生 evidence=手写的航行日志（sci+1，susp 保持 0）
	sF.core.choose(2, 1)   # 导航日志被改写 sci+1
	sF.core.submit_chapter()
	await physics_frame
	_check(wF.get_node_or_null("VariantRoot/Well_Base") != null and not _has_ins(wF, "well_reflection") and wF.get_node_or_null("VariantRoot/Well_Water") == null,
		"段20a 仅证物悬疑0：井台盖板态、无回光（组合未成立）")
	sF.core.choose(2, 0)   # 别相信回来的那个人 susp+1 → 揭盖 + 组合成立
	await physics_frame
	_check(_has_ins(wF, "well_reflection") and wF.get_node_or_null("VariantRoot/Well_Glint") != null,
		"段20b 证物×悬疑同时成立：井面回光在场（发光小物+检查点）")
	_check(str(_ins_text(wF, "well_reflection")).contains("手写的航行日志"), "段20c 回光文本引用所选证物")
	sF.core.choose(1, 2)   # 井栏磨平 susp-1 → 揭盖条件破
	await physics_frame
	_check(not _has_ins(wF, "well_reflection") and wF.get_node_or_null("VariantRoot/Well_Glint") == null
		and wF.get_node_or_null("VariantRoot/Well_Water") == null, "段20d 悬疑回落：回光随事务撤除（井回盖板态）")
	sF.core.choose(3, 1)   # 第二串脚印 susp+1（换槽重立组合，同槽同选不重复生效）
	await physics_frame
	var rc := 0
	for c in wF.get_node("VariantRoot").get_children():
		if str(c.name) == "INS_well_reflection":
			rc += 1
	_check(rc == 1 and _has_ins(wF, "well_reflection"), "段20e 组合再成立：回光恢复且唯一（无重复对象）")
	await _drop(sF)

	# --- 段32：机制关卡 21「屋脊风铃」——三刻痕集齐显形，E 循环三档风（文本随主基调分化） ---
	var sR: Node3D = await _boot()
	var wR: Node3D = sR.get_node("ChapterWorld")
	sR.core.choose(0, 1)   # 记者
	sR.core.choose(1, 1)   # 海边小镇
	sR.core.choose(2, 3)   # 旧照片
	sR.core.submit_chapter()
	sR.core.choose(0, 2)   # 调阅日志 sci+1
	sR.core.choose(1, 0)   # 黄铜钥匙 → 证物
	sR.core.choose(2, 0)   # 撤稿 susp+1 → 三刻痕全部在场
	sR.core.submit_chapter()   # 第 3 章
	await physics_frame
	_check(_has_ins(wR, "well_mark") and _has_ins(wR, "sill_mark") and _has_ins(wR, "antenna_mark"),
		"段32a 三处刻痕全部在场")
	_check(not _has_ins(wR, "wind_chime") and wR.get_node_or_null("VariantRoot/ChimeGroup") == null,
		"段32b 未集齐：屋脊风铃不显形")
	sR.interact_text("well_mark")
	sR.interact_text("sill_mark")
	sR.interact_text("antenna_mark")   # 集齐 → bridge bump → 正规事务重建
	await physics_frame
	await physics_frame
	_check(_has_ins(wR, "wind_chime") and wR.get_node_or_null("VariantRoot/ChimeGroup") != null,
		"段32c 集齐 3/3：屋脊风铃显形（横杆+三管+检查点）")
	var gR: Node3D = wR.get_node("VariantRoot/ChimeGroup")
	var l0: int = wR.wind_cycle()
	_check(l0 == 1 and absf(gR.rotation.x + 0.12) < 0.001, "段32d 一档微风：摆幅 -0.12")
	var l1: int = wR.wind_cycle()
	_check(l1 == 2 and absf(gR.rotation.x + 0.24) < 0.001, "段32e 二档风起：摆幅 -0.24")
	var l2: int = wR.wind_cycle()
	_check(l2 == 0 and absf(gR.rotation.x) < 0.001 and absf(gR.rotation.z) < 0.001, "段32f 循环回静：摆幅归零")
	_check(sR.bridge.wind_chime_text(0, "sci").contains("金属的凉"), "段32g 科幻分化：铃声带金属的凉")
	_check(sR.bridge.wind_chime_text(1, "warm").contains("灶火的暖"), "段32h 温情分化：铃声裹灶火的暖")
	_check(sR.bridge.wind_chime_text(2, "susp").contains("没有回音"), "段32i 悬疑分化：铃声没有回音")
	await _drop(sR)

	# --- 段33：机制关卡 20「望远镜校准」——E 循环三档指向，确认句只在指对时出现（盲测不泄底） ---
	var sS: Node3D = await _boot()
	var wS: Node3D = sS.get_node("ChapterWorld")
	sS.core.choose(0, 2)
	sS.core.choose(1, 0)
	sS.core.choose(2, 2)   # 星图 sci2 → 观星台+望远镜在场
	await physics_frame
	_check(_has_ins(wS, "telescope"), "段33a 观星台望远镜在场")
	sS.core.submit_chapter()
	sS.core.choose(0, 1)
	sS.core.choose(1, 2)
	sS.core.choose(2, 1)
	sS.core.submit_chapter()   # 第 3 章
	sS.core.choose(0, 0)
	sS.core.choose(1, 0)
	sS.core.choose(2, 0)
	sS.core.choose(3, 0)
	sS.core.submit_chapter()   # 第 4 章
	sS.core.choose(0, 3)   # 殖民飞船 → secret=colony_ship
	await physics_frame
	var a1: int = wS.telescope_cycle()   # 0→1：月亮档
	_check(a1 == 1 and sS.bridge.telescope_text(1).contains("坐标应答了"), "段33b colony 档1 指月：确认句出现")
	_check(not sS.bridge.telescope_text(2).contains("坐标应答了"), "段33c colony 档2 指后山：没有等到应答")
	sS.core.choose(0, 4)   # 改矿井 → secret=mine_door
	await physics_frame
	wS.telescope_aim = 0
	var b1: int = wS.telescope_cycle()   # 0→1：月亮档
	var b2: int = wS.telescope_cycle()   # 1→2：后山档
	_check(b1 == 1 and b2 == 2 and sS.bridge.telescope_text(2).contains("就是这里"), "段33d mine 档2 指矿井：确认句出现")
	_check(not sS.bridge.telescope_text(1).contains("就是这里"), "段33e mine 档1 指月：没有等到应答")
	await _drop(sS)

	# --- 段34：机制关卡 22「井口的辘轳」——E 摇三段拉桶，桶中旧物随主基调（捞上来看到的事实） ---
	var sT: Node3D = await _boot()
	var wT: Node3D = sT.get_node("ChapterWorld")
	sT.core.choose(0, 1)   # 记者
	sT.core.choose(1, 1)   # 海边小镇
	sT.core.choose(2, 3)   # 旧照片
	sT.core.submit_chapter()
	sT.core.choose(0, 2)   # 调阅日志 sci+1
	sT.core.choose(1, 0)   # 黄铜钥匙 → 证物
	sT.core.choose(2, 0)   # 撤稿 susp+1 → 揭盖 + 辘轳立起
	sT.core.submit_chapter()   # 第 3 章
	await physics_frame
	_check(_has_ins(wT, "well_winch") and wT.get_node_or_null("VariantRoot/WinchPost") != null
		and wT.get_node_or_null("VariantRoot/WinchCrank") != null, "段34a 揭盖+第3章：井口辘轳在场（立柱+摇臂+检查点）")
	_check(wT.get_node_or_null("VariantRoot/BucketGroup") == null, "段34b 未摇桶：桶不在井口")
	var c1: int = wT.winch_crank()
	_check(c1 == 1 and absf((wT.get_node("VariantRoot/WinchCrank") as Node3D).rotation.z - 2.2) < 0.001
		and sT.bridge.winch_text(1, "").contains("绳子往下放了半截"), "段34c 一摇：放绳半截，摇臂转过 2.2")
	var c2: int = wT.winch_crank()
	_check(c2 == 2 and sT.bridge.winch_text(2, "").contains("水声"), "段34d 二摇：绳子一沉，水声近了")
	var c3: int = wT.winch_crank()
	_check(c3 == 3 and wT.get_node_or_null("VariantRoot/BucketGroup") != null
		and wT.get_node_or_null("VariantRoot/BucketGroup/BucketRelic") != null
		and sT.bridge.winch_text(3, "").contains("桶出了井口"), "段34e 三摇：桶出井口（桶+桶中旧物在场）")
	var c4: int = wT.winch_crank()   # 物理动作不倒摇：到顶后重复 E 不变
	var bc := 0
	for cn in wT.get_node("VariantRoot").get_children():
		if str(cn.name) == "BucketGroup":
			bc += 1
	_check(c4 == 3 and bc == 1, "段34f 重复摇：进度封顶、桶不重复生成")
	_check(sT.bridge.winch_text(3, "sci").contains("黄铜齿轮"), "段34g 科幻分化：桶底黄铜齿轮")
	_check(sT.bridge.winch_text(3, "warm").contains("小铃铛"), "段34h 温情分化：桶底红绳铃铛")
	_check(sT.bridge.winch_text(3, "susp").contains("生锈的钥匙"), "段34i 悬疑分化：桶底锈钥匙")
	sT.core.choose(1, 2)   # 井栏磨平 susp-1 → 井回盖板态 → 辘轳随事务撤除
	await physics_frame
	_check(not _has_ins(wT, "well_winch") and wT.get_node_or_null("VariantRoot/WinchPost") == null
		and wT.get_node_or_null("VariantRoot/BucketGroup") == null, "段34j 悬疑回落：辘轳与桶随事务撤除")
	await _drop(sT)

	# --- 段35：机制关卡 23「后院的晾衣绳」——温情≥1 拉绳，E 挂上/收回所选道具（布片换色） ---
	var sU: Node3D = await _boot()
	var wU: Node3D = sU.get_node("ChapterWorld")
	sU.core.choose(0, 0)   # 侦探 susp+1
	sU.core.choose(1, 0)   # 多雨南方小镇：flag_place=小镇 但不加温情 → warm=0
	sU.core.choose(2, 3)   # 旧照片
	sU.core.submit_chapter()
	sU.core.choose(0, 2)   # 调阅日志 sci+1
	sU.core.choose(1, 0)   # 黄铜钥匙 → 证物
	sU.core.choose(2, 0)   # 撤稿 susp+1
	sU.core.submit_chapter()   # 第 3 章：warm 仍 0 → 晾衣绳不在
	await physics_frame
	_check(not _has_ins(wU, "clothes_line") and wU.get_node_or_null("VariantRoot/LinePoleL") == null,
		"段35a 温情0：晾衣绳不出现")
	sU.core.choose(0, 1)   # 「他只是累了，想回家」warm+1 → 绳随事务拉起
	await physics_frame
	_check(_has_ins(wU, "clothes_line") and wU.get_node_or_null("VariantRoot/LinePoleL") != null
		and wU.get_node_or_null("VariantRoot/LineRope") != null, "段35b 温情+1：两杆拉绳在场（立柱+绳线+检查点）")
	var h1: bool = wU.line_toggle()
	_check(h1 and wU.get_node_or_null("VariantRoot/ClothItem") != null
		and sU.bridge.clothes_text(true, "旧照片").contains("夹上晾衣绳"), "段35c 挂上：布片在绳上，文本=夹上晾衣绳")
	var h2: bool = wU.line_toggle()
	_check(not h2 and wU.get_node_or_null("VariantRoot/ClothItem") == null
		and sU.bridge.clothes_text(false, "旧照片").contains("收回怀里"), "段35d 收回：布片随事务撤除，文本=收回怀里")
	var h3: bool = wU.line_toggle()
	var cc := 0
	for cn in wU.get_node("VariantRoot").get_children():
		if str(cn.name) == "ClothItem":
			cc += 1
	_check(h3 and cc == 1, "段35e 再挂：布片唯一（换向幂等）")
	_check(sU.bridge.clothes_text(true, "星图").contains("「星图」")
		and sU.bridge.clothes_text(true, "信件").contains("「信件」"), "段35f 文本随所选道具分化")
	_check(wU.line_prop == "旧照片", "段35g 道具快照与所选一致（布片换色依据）")
	await _drop(sU)

	# --- 段36：机制关卡 24「北坡老虎窗」——证物落定钉板卸下，屋顶矮道真实步入阁楼暗格 ---
	var sV: Node3D = await _boot()
	var wV: Node3D = sV.get_node("ChapterWorld")
	sV.core.choose(0, 2)   # 宇航员 sci+1
	sV.core.choose(1, 0)   # 多雨南方小镇
	sV.core.choose(2, 2)   # 加密星图 sci+1
	sV.core.submit_chapter()   # 第 2 章：证物未落定
	await physics_frame
	_check(wV.get_node_or_null("VariantRoot/DormerPlank") != null and not _has_ins(wV, "attic_stash"),
		"段36a 证物未落定：老虎窗钉板封死（推不开是真的推不开）、暗格不可检查")
	sV.core.choose(0, 2)   # 调阅日志 sci+1
	sV.core.choose(1, 0)   # 黄铜钥匙 → 证物派生落定（本章内即时生效，段13 同时序）
	await physics_frame
	_check(wV.get_node_or_null("VariantRoot/DormerPlank") == null
		and _has_ins(wV, "attic_stash") and wV.get_node_or_null("VariantRoot/AtticCrate") != null,
		"段36b 证物落定：钉板随事务卸下，阁楼木箱与检查点在场")
	var routeV := [Vector3(-5.4, 3.95, -7.0), Vector3(-4.6, 3.95, -8.8), Vector3(-4.25, 3.95, -9.5), Vector3(-4.25, 3.95, -10.6), Vector3(-4.25, 3.95, -11.0)]
	_check(_route_ok(wV, routeV), "段36c 屋顶矮道北行→门洞→老虎窗内 通路全通")
	_check(wV.is_position_safe(Vector3(-4.25, 3.95, -11.0)) and wV.is_position_safe(Vector3(-4.0, 3.95, -10.6)),
		"段36d 老虎窗内两处站位安全（净宽≥胶囊+裕度）")
	var evV: String = str(sV.core.flags.get("evidence", ""))
	_check(str(_ins_text(wV, "attic_stash")).contains("同出一手") and str(_ins_text(wV, "attic_stash")).contains(evV),
		"段36e 暗格文本=与所选证物同出一手（引证物名，盲测不泄底）")
	sV.core.reset_chapter()   # 重置本章：证物回滚 → 钉板重新封死（段13 同机制）
	await physics_frame
	_check(not sV.core.flags.has("evidence") and wV.get_node_or_null("VariantRoot/DormerPlank") != null
		and not _has_ins(wV, "attic_stash"), "段36f 证物回滚：钉板重新封死、暗格随事务撤除")
	_check(not wV.is_position_safe(Vector3(-4.25, 3.95, -10.4)), "段36g 封死态：窗内点位不可站（钉板带碰撞）")
	await _drop(sV)

	# --- 段37a：机制关卡 25「屋顶水箱与管线」——科幻0 时水箱/水缸不成对在场（门控负例） ---
	var sW: Node3D = await _boot()
	var wW: Node3D = sW.get_node("ChapterWorld")
	sW.core.choose(0, 0)   # 侦探 susp+1
	sW.core.choose(1, 0)   # 多雨南方小镇
	sW.core.choose(2, 3)   # 旧照片 → sci=0
	await physics_frame
	_check(not _has_ins(wW, "roof_tank") and not _has_ins(wW, "cistern")
		and wW.get_node_or_null("VariantRoot/RoofTank") == null, "段37a 科幻0：水箱/水缸不成对在场（门控负例）")
	await _drop(sW)

	# --- 段37b-e：水箱档位驱动水位（1=半缸/2=满缸微光），碗筷在场时缸沿搭木瓢（跨对象回响） ---
	var sX: Node3D = await _boot()
	var wX: Node3D = sX.get_node("ChapterWorld")
	sX.core.choose(0, 2)   # 宇航员 sci+1
	sX.core.choose(1, 1)   # 海边小镇 warm+1
	sX.core.choose(2, 3)   # 旧照片 → sci=1
	await physics_frame
	_check(_has_ins(wX, "roof_tank") and _has_ins(wX, "cistern")
		and wX.get_node_or_null("VariantRoot/CisternWater") != null,
		"段37b 科幻1：屋顶水箱+管线+后院水缸在场，缸内半缸暗水")
	_check(str(_ins_text(wX, "cistern")).contains("一滴"), "段37c-1 档1 缸文本=一滴一滴，很有耐心")
	sX.core.submit_chapter()
	sX.core.choose(0, 2)   # 调阅日志 sci+1 → sci=2 → 满缸微光
	sX.core.choose(1, 0)   # 黄铜钥匙 → 证物落定（温情×证物 → 缸沿搭木瓢）
	await physics_frame
	var cw: Node3D = wX.get_node_or_null("VariantRoot/CisternWater")
	_check(cw != null and absf(cw.position.y - 0.62) < 0.01 and (cw.material_override as StandardMaterial3D).emission_enabled,
		"段37c-2 科幻2：满缸水位升高且带微光")
	_check(str(_ins_text(wX, "roof_tank")).contains("满了"), "段37c-3 档2 水箱文本=满了/浮标顶到管口")
	_check(str(_ins_text(wX, "cistern")).contains("木瓢") and str(_ins_text(wX, "cistern")).contains("窗台那碗"),
		"段37d 温情×证物：缸沿搭木瓢回响窗台碗筷")
	_check(wX.is_position_safe(Vector3(0, 0.2, -16.4)) and wX.is_position_safe(Vector3(3.5, 3.95, -8.3)),
		"段37e 既有走位点安全（marks 路线与屋顶东行带不被水缸/水箱拦阻）")
	await _drop(sX)

	# --- 段38：机制关卡 26「第五张字条」——字条四读毕 × 温情满档 → 晾衣绳木夹下的收束字条 ---
	var sY: Node3D = await _boot()
	var wY: Node3D = sY.get_node("ChapterWorld")
	sY.core.choose(0, 1)   # 记者（echo 槽可给 susp；黄铜钥匙派生 warm）
	sY.core.choose(1, 1)   # 海边小镇 warm+1
	sY.core.choose(2, 2)   # 加密星图 sci+1（prop=星图）
	sY.core.submit_chapter()
	sY.core.choose(0, 2)   # 调阅日志 sci+1 → sci2
	sY.core.choose(1, 0)   # 黄铜钥匙 → 证物落定 + warm（记者派生）→ warm2
	sY.core.choose(2, 0)   # 悄悄撤下报道 susp+1 → 三刻痕全齐
	sY.core.submit_chapter()   # 第 3 章
	await physics_frame
	_check(_has_ins(wY, "well_mark") and _has_ins(wY, "sill_mark") and _has_ins(wY, "antenna_mark"),
		"段38a 温情2配置：三刻痕全部在场（收集线就绪）")
	sY.interact_text("well_mark")
	sY.interact_text("sill_mark")
	sY.interact_text("antenna_mark")
	await physics_frame
	await physics_frame
	sY.interact_text("echo_note")   # 读字条一 → 字条二浮现
	sY.interact_text("note2")       # 读二 → 三浮现（sci2）
	sY.interact_text("note3")       # 读三 → 四浮现（星图×sci2）
	await physics_frame
	_check(_has_ins(wY, "note4") and not _has_ins(wY, "note5"),
		"段38b 字条四已浮现、字条五未现（门控在字条四读毕）")
	sY.interact_text("note4")       # 读四 → 霜膜擦净 + 温情≥2 → 五浮现于晾衣绳
	await physics_frame
	_check(_has_ins(wY, "note5") and _has_ins(wY, "clothes_line")
		and wY.get_node_or_null("VariantRoot/Note5Paper") != null,
		"段38c 字条四读毕：第五张字条压上晾衣绳木夹（纸片+检查点在场）")
	_check(str(_ins_text(wY, "note5")).contains("灯也给你留着")
		and str(_ins_text(wY, "note5")).contains("小小的碗"), "段38d 字条五文本=温情收束（灯/碗，无基调数值）")
	sY.interact_text("note5")       # 读五 → 已读记入 + 重走事务
	await physics_frame
	var nc5 := 0
	for cn5 in wY.get_node("VariantRoot").get_children():
		if str(cn5.name) == "INS_note5":
			nc5 += 1
	_check(sY.bridge.read_notes.has("note5") and nc5 == 1, "段38e 字条五读毕记入、重走事务不重复")
	_check(bool(sY.bridge.build_spec().get("note5", false)), "段38f spec 门控=字条四已读×温情≥2（实测为真）")
	await _drop(sY)

	# --- 段39：机制关卡 27「辘轳×水缸联动」——桶出水后 E 倒进水缸（水线抬升，重复幂等） ---
	var sZ: Node3D = await _boot()
	var wZ: Node3D = sZ.get_node("ChapterWorld")
	sZ.core.choose(0, 1)   # 记者
	sZ.core.choose(1, 1)   # 海边小镇 warm+1
	sZ.core.choose(2, 2)   # 加密星图 sci+1
	sZ.core.submit_chapter()
	sZ.core.choose(0, 2)   # 调阅日志 sci+1 → sci2 → 水缸在场
	sZ.core.choose(1, 0)   # 黄铜钥匙 → 证物
	sZ.core.choose(2, 0)   # 撤稿 susp+1 → 辘轳在场
	sZ.core.submit_chapter()   # 第 3 章
	await physics_frame
	for i in 3:
		wZ.winch_crank()   # 三摇：桶出井口
	await physics_frame
	_check(wZ.get_node_or_null("VariantRoot/BucketGroup") != null
		and _has_ins(wZ, "bucket"), "段39a 三摇：桶出井口且自身可检查（INS_bucket 在场）")
	var w_y0: float = (wZ.get_node("VariantRoot/CisternWater") as Node3D).position.y
	var ps1: int = wZ.bucket_pour()
	var w_y1: float = (wZ.get_node("VariantRoot/CisternWater") as Node3D).position.y
	_check(ps1 == 1 and absf(w_y1 - w_y0 - 0.06) < 0.001
		and sZ.bridge.bucket_pour_text(1).contains("涟漪"), "段39b 倒进缸：水线抬升 0.06，文本=涟漪")
	var ps2: int = wZ.bucket_pour()
	var w_y2: float = (wZ.get_node("VariantRoot/CisternWater") as Node3D).position.y
	_check(ps2 == 2 and absf(w_y2 - w_y1) < 0.001
		and sZ.bridge.bucket_pour_text(2).contains("桶已经空了"), "段39c 重复倒：幂等（水位不再变，文本=桶已空）")
	_check(sZ.bridge.bucket_pour_text(0).contains("没有别的缸"), "段39d 无缸文本=桶先待着（分化备查）")
	sZ.core.choose(1, 2)   # 井栏磨平 susp-1 → 辘轳/桶随事务撤除（水缸不受影响）
	await physics_frame
	_check(not _has_ins(wZ, "bucket") and wZ.get_node_or_null("VariantRoot/BucketGroup") == null,
		"段39e 悬疑回落：桶随事务撤除（水缸保留）")
	await _drop(sZ)

	# --- 段39f：无缸负例——sci 线未接时桶无去处 ---
	var s0: Node3D = await _boot()
	var w0: Node3D = s0.get_node("ChapterWorld")
	s0.core.choose(0, 1)   # 记者
	s0.core.choose(1, 0)   # 多雨南方小镇
	s0.core.choose(2, 3)   # 旧照片 → sci0
	s0.core.submit_chapter()
	s0.core.choose(1, 0)   # 黄铜钥匙 → 证物
	s0.core.choose(2, 0)   # 撤稿 susp+1 → 辘轳在场
	s0.core.submit_chapter()   # 第 3 章
	await physics_frame
	for i in 3:
		w0.winch_crank()
	await physics_frame
	_check(_has_ins(w0, "bucket") and w0.bucket_pour() == 0
		and s0.bridge.bucket_pour_text(0).contains("桶里待着"), "段39f 无缸：倒水无去处（状态 0，桶先待着）")
	await _drop(s0)

	# --- 段40：机制关卡 28「改写留下的实物」——echo 槽写入 flag_case → 档案架南面出现对应实物 ---
	# （实物挂后院档案架，第 3 章后院可达起可见；第 2 章内先断 spec/文本层与同槽反悔回滚）
	var s1c: Node3D = await _boot()
	var w1c: Node3D = s1c.get_node("ChapterWorld")
	s1c.core.choose(0, 0)   # 侦探 susp+1
	s1c.core.choose(1, 0)   # 多雨南方小镇
	s1c.core.choose(2, 3)   # 旧照片
	s1c.core.submit_chapter()
	s1c.core.choose(0, 2)   # 调阅日志 sci+1
	s1c.core.choose(1, 0)   # 黄铜钥匙 → 证物
	s1c.core.choose(2, 1)   # 重查三年前的卷宗编号 → flag_case=旧卷宗
	await physics_frame
	_check(str(s1c.bridge.build_spec().get("case_mark", "")) == "旧卷宗"
		and str(_ins_text(s1c.get_node("ChapterWorld"), "case_mark")).contains("编号正是你重查的那一册"),
		"段40a 侦探线 echo 写入：spec 快照=旧卷宗、文本=红标卷宗回执")
	_check(not _has_ins(w1c, "case_mark"), "段40b 第 2 章后院未开：实物暂不可见（与井沿刻痕同章节门槛）")
	s1c.core.choose(2, 0)   # 同槽反悔改选井绳磨痕（无 flag）→ 旗标随 applied.delta 回滚
	await physics_frame
	_check(str(s1c.bridge.build_spec().get("case_mark", "")) == ""
		and str(_ins_text(w1c, "case_mark")) == "", "段40c 同槽反悔：旗标与文本条目随事务回滚")
	s1c.core.submit_chapter()   # 第 3 章（不带 case 旗标交稿）
	await physics_frame
	_check(not _has_ins(w1c, "case_mark") and w1c.get_node_or_null("VariantRoot/CaseMarkItem") == null,
		"段40d 未带旗标进第 3 章：档案架无实物")
	await _drop(s1c)
	var s1d: Node3D = await _boot()
	var w1d: Node3D = s1d.get_node("ChapterWorld")
	s1d.core.choose(0, 0)
	s1d.core.choose(1, 0)
	s1d.core.choose(2, 3)
	s1d.core.submit_chapter()
	s1d.core.choose(0, 2)
	s1d.core.choose(1, 0)
	s1d.core.choose(2, 1)   # 旧卷宗
	s1d.core.submit_chapter()   # 带旗标进第 3 章
	await physics_frame
	_check(_has_ins(w1d, "case_mark") and w1d.get_node_or_null("VariantRoot/CaseMarkItem") != null
		and str(_ins_text(w1d, "case_mark")).contains("编号正是你重查的那一册"),
		"段40e 带旗标进第 3 章：档案架南面实物在场（卷宗+标签+检查点+文本）")
	await _drop(s1d)
	var s1e: Node3D = await _boot()
	s1e.core.choose(0, 1)   # 记者（echo 槽分记者选项）
	s1e.core.choose(1, 0)
	s1e.core.choose(2, 3)
	s1e.core.submit_chapter()
	s1e.core.choose(2, 1)   # 那篇报道当年被紧急撤稿 → flag_case=被撤的报道
	s1e.core.submit_chapter()
	await physics_frame
	_check(str(_ins_text(s1e.get_node("ChapterWorld"), "case_mark")).contains("撤稿印件"),
		"段40f 记者线分化=撤稿印件回执（文本随 flag_case 值变化）")
	await _drop(s1e)

	# --- 段41：机制关卡 29「信箱回执」——E 一次性投递，第 5 章信箱多一封无寄件人的回信 ---
	var s1f: Node3D = await _boot()
	s1f.core.choose(0, 1)   # 记者
	s1f.core.choose(1, 1)   # 海边小镇 warm+1
	s1f.core.choose(2, 1)   # 家书 warm+1
	s1f.core.submit_chapter()
	await physics_frame
	_check(s1f.bridge.mail_send() and not s1f.bridge.mail_send(),
		"段41a E 投递：一次性（首次真、重复假，幂等）")
	_check(str(s1f.world.inspect_texts.get("mail_slot", {}).get("text", "")) == ""
		or not str(s1f.world.inspect_texts.get("mail_slot", {}).get("text", "")).contains("回信"),
		"段41b 第 2 章已投：信箱暂无回信（跨章门槛）")
	_check(str(_ins_text(s1f.get_node("ChapterWorld"), "mail_slot")).contains("他还活着"),
		"段41c 信箱基础文案不回退（那封信仍在）")
	s1f.core.choose(0, 1)   # 老友 warm+1
	s1f.core.choose(1, 0)   # 黄铜钥匙（记者派生 warm+1）
	s1f.core.choose(2, 1)   # 被撤的报道 susp+1
	s1f.core.submit_chapter()
	s1f.core.choose(0, 1)
	s1f.core.choose(1, 1)
	s1f.core.choose(2, 1)
	s1f.core.choose(3, 0)
	s1f.core.submit_chapter()
	s1f.core.choose(0, 1)
	s1f.core.choose(1, 1)
	s1f.core.choose(2, 2)
	s1f.core.choose(3, 1)
	s1f.core.submit_chapter()   # 第 5 章
	await physics_frame
	_check(int(s1f.core.chapter_idx) == 4 and s1f.bridge.mail_sent, "段41d 已投进第 5 章（mail_sent 跨章存活）")
	_check(str(_ins_text(s1f.get_node("ChapterWorld"), "mail_slot")).contains("回信")
		and str(_ins_text(s1f.get_node("ChapterWorld"), "mail_slot")).contains("锅还温着"),
		"段41e 第 5 章：信箱深处多一封回信（都收到了/锅还温着）")
	_check(not str(_ins_text(s1f.get_node("ChapterWorld"), "mail_slot")).contains("寄件人："),
		"段41f 盲测安全：回信无寄件人身份（只写「没有寄件人」）")
	await _drop(s1f)
	var s1g: Node3D = await _boot()
	s1g.core.choose(0, 1)
	s1g.core.choose(1, 1)
	s1g.core.choose(2, 1)
	s1g.core.submit_chapter()
	s1g.core.choose(0, 1)
	s1g.core.choose(1, 0)
	s1g.core.choose(2, 1)
	s1g.core.submit_chapter()
	s1g.core.choose(0, 1)
	s1g.core.choose(1, 1)
	s1g.core.choose(2, 1)
	s1g.core.choose(3, 0)
	s1g.core.submit_chapter()
	s1g.core.choose(0, 1)
	s1g.core.choose(1, 1)
	s1g.core.choose(2, 2)
	s1g.core.choose(3, 1)
	s1g.core.submit_chapter()   # 第 5 章（未投递）
	await physics_frame
	_check(int(s1g.core.chapter_idx) == 4 and not s1g.bridge.mail_sent
		and not str(_ins_text(s1g.get_node("ChapterWorld"), "mail_slot")).contains("回信"),
		"段41g 未投递对照：第 5 章信箱无回信（门控负例）")
	await _drop(s1g)

	# --- 段42：机制关卡 30「晾干的故事」——挂上道具跨过一章，布片变干仍在绳上（跨章账本） ---
	var s1h: Node3D = await _boot()
	var w1h: Node3D = s1h.get_node("ChapterWorld")
	s1h.core.choose(0, 1)   # 记者
	s1h.core.choose(1, 1)   # 海边小镇 warm+1
	s1h.core.choose(2, 3)   # 旧照片
	s1h.core.submit_chapter()
	s1h.core.choose(0, 2)   # 调阅日志 sci+1
	s1h.core.choose(1, 0)   # 黄铜钥匙 → 证物
	s1h.core.choose(2, 0)   # 撤稿 susp+1
	s1h.core.submit_chapter()   # 第 3 章（chapter_idx=2）
	await physics_frame
	w1h.line_toggle()   # 挂上（world 侧）
	s1h.bridge.line_hung_prop = "旧照片"   # root 分支同步账本（headless 直记，段32 同式）
	s1h.bridge.line_hung_chapter = 2
	await physics_frame
	_check(not bool(s1h.bridge.build_spec().get("line_dried", false)),
		"段42a 同章挂上：未跨章不变干（line_dried=false）")
	s1h.core.choose(0, 1)   # 老友 warm+1 → 进第 4 章
	s1h.core.choose(1, 1)
	s1h.core.choose(2, 1)
	s1h.core.choose(3, 0)
	s1h.core.submit_chapter()
	await physics_frame
	_check(bool(s1h.bridge.build_spec().get("line_dried", false))
		and str(s1h.bridge.build_spec().get("line_dried_prop", "")) == "旧照片",
		"段42b 跨过一章：spec line_dried=true（账本跨章存活）")
	_check(_has_ins(w1h, "clothes_line") and w1h.get_node_or_null("VariantRoot/ClothItem") != null
		and bool(w1h.line_hung), "段42c 第 4 章：干布片仍在绳上（重建由 spec 驱动）")
	_check(str(_ins_text(w1h, "clothes_line")).contains("晾了一夜")
		and str(_ins_text(w1h, "clothes_line")).contains("太阳的气味"), "段42d 绳文本=晾了一夜（太阳的气味）")
	w1h.line_toggle()   # E 收下干布片（world 侧）
	s1h.bridge.line_hung_prop = ""   # root 分支同步清账
	await physics_frame
	_check(not w1h.get_node_or_null("VariantRoot/ClothItem") != null
		and not bool(s1h.bridge.build_spec().get("line_dried", false)),
		"段42e E 收下：干布片随事务撤除、账本清空")
	await _drop(s1h)

	# --- 段43：机制关卡 31「起风了」——风档全局联动：布片掀转+井雾偏移+铃声追加布片一句 ---
	var s1i: Node3D = await _boot()
	var w1i: Node3D = s1i.get_node("ChapterWorld")
	s1i.core.choose(0, 1)   # 记者
	s1i.core.choose(1, 1)   # 海边小镇 warm+1
	s1i.core.choose(2, 2)   # 加密星图 sci+1
	s1i.core.submit_chapter()
	s1i.core.choose(0, 2)   # 调阅日志 sci+1
	s1i.core.choose(1, 0)   # 黄铜钥匙 → 证物
	s1i.core.choose(2, 0)   # 撤稿 susp+1
	s1i.core.submit_chapter()   # 第 3 章 susp1
	s1i.core.choose(3, 1)   # 第二串脚印 susp+1 → 悬疑2（井雾档）
	for m3i in ["well_mark", "sill_mark", "antenna_mark"]:
		s1i.interact_text(m3i)
	await physics_frame
	_check(_has_ins(w1i, "wind_chime") and _has_ins(w1i, "clothes_line")
		and w1i.get_node_or_null("VariantRoot/Well_Mist") != null, "段43a 风铃/晾衣绳/井雾三件在场")
	w1i.line_toggle()   # 挂上布片
	await physics_frame
	var c1i: Node3D = w1i.get_node("VariantRoot/ClothItem")
	w1i.wind_cycle()   # 一档
	await physics_frame
	_check(int(w1i.wind_level) == 1 and absf(c1i.rotation.y - 0.35) < 0.001
		and s1i.bridge.wind_chime_text(1, "", true).contains("布片"), "段43b 一档起风：布片掀转 0.35，铃声追加布片一句")
	w1i.wind_cycle()   # 二档
	await physics_frame
	var mist1i: Node3D = w1i.get_node("VariantRoot/Well_Mist")
	_check(absf(mist1i.position.x + 1.9) < 0.001, "段43c 二档：井雾顺风偏移（-2.5→-1.9）")
	w1i.wind_cycle()   # 回静
	await physics_frame
	_check(absf(c1i.rotation.y) < 0.001 and absf(mist1i.position.x + 2.5) < 0.001, "段43d 回静：布片与井雾复位")
	_check(not s1i.bridge.wind_chime_text(1, "", false).contains("布片"), "段43e 无布片时不追加（参数门控）")
	await _drop(s1i)

	# --- 段44：机制关卡 32「物证的归宿」——桶中旧物收起，证物匣文本追加一段（跨章存活） ---
	var s1j: Node3D = await _boot()
	var w1j: Node3D = s1j.get_node("ChapterWorld")
	s1j.core.choose(0, 1)   # 记者
	s1j.core.choose(1, 1)   # 海边小镇 warm+1
	s1j.core.choose(2, 2)   # 加密星图 sci+1
	s1j.core.submit_chapter()
	s1j.core.choose(0, 2)   # 调阅日志 sci+1
	s1j.core.choose(1, 0)   # 黄铜钥匙 → 证物匣在场
	s1j.core.choose(2, 0)   # 撤稿 susp+1 → 辘轳在场
	s1j.core.submit_chapter()   # 第 3 章
	await physics_frame
	for i3 in 3:
		w1j.winch_crank()   # 三摇桶出
	await physics_frame
	_check(w1j.relic_take(), "段44a E 收旧物：桶中旧物随场景移除（首收成功）")
	s1j.bridge.relic_store("一枚黄铜齿轮，齿口还很利")
	s1j._apply_world()
	await physics_frame
	_check(str(_ins_text(w1j, "evidence_box")).contains("井里捞上来的旧物")
		and str(_ins_text(w1j, "evidence_box")).contains("黄铜齿轮"), "段44b 证物匣文本追加一段（引旧物来历）")
	_check(not w1j.relic_take(), "段44c 桶中已无旧物（二次移除失败）")
	s1j.core.submit_chapter()
	s1j.core.choose(0, 0)
	s1j.core.choose(1, 0)
	s1j.core.choose(2, 0)
	s1j.core.choose(3, 0)
	s1j.core.submit_chapter()   # 第 4 章（重建多次）
	await physics_frame
	_check(str(_ins_text(w1j, "evidence_box")).contains("井里捞上来的旧物"),
		"段44d 跨章存活：第 4 章匣文本仍含旧物段")
	_check(not str(_ins_text(w1j, "evidence_box")).contains("金属的凉")
		and not str(_ins_text(w1j, "evidence_box")).contains("sci"), "段44e 盲测安全：匣文本无基调数值/键名")
	await _drop(s1j)

	# --- 段45：机制关卡 33「终稿前的清点」——三跨章账本在落点文本回声（无账本=无回声） ---
	var s2a: Node3D = await _boot()
	var w2a: Node3D = s2a.get_node("ChapterWorld")
	s2a.core.choose(0, 1)   # 记者
	s2a.core.choose(1, 1)   # 海边小镇 warm+1
	s2a.core.choose(2, 2)   # 加密星图 sci+1
	s2a.core.submit_chapter()
	s2a.core.choose(0, 2)   # 调阅日志 sci+1
	s2a.core.choose(1, 0)   # 黄铜钥匙 → 证物
	s2a.core.choose(2, 0)   # 撤稿 susp+1
	s2a.core.submit_chapter()   # 第 3 章
	w2a.line_toggle()   # 挂上道具（world 侧）
	s2a.bridge.line_hung_prop = "星图"
	s2a.bridge.line_hung_chapter = 2
	s2a.bridge.mail_sent = true   # 29 账本（headless 直记，root 分支同式）
	s2a.bridge.relic_stored = true
	s2a.bridge.relic_dom = "一枚黄铜齿轮，齿口还很利"
	s2a.core.choose(0, 1)
	s2a.core.choose(1, 1)
	s2a.core.choose(2, 1)
	s2a.core.choose(3, 0)
	s2a.core.submit_chapter()
	s2a.core.choose(0, 1)
	s2a.core.choose(1, 1)
	s2a.core.choose(2, 2)
	s2a.core.choose(3, 1)
	s2a.core.submit_chapter()   # 第 5 章
	await physics_frame
	var e45: String = str(_ins_text(w2a, "ending_spot"))
	_check(e45.contains("稿纸的最后一页"), "段45a 回信账本：落点文本回声（抄在最后一页）")
	_check(e45.contains("看了很多遍"), "段45b 旧物账本：落点文本回声（看了很多遍）")
	_check(e45.contains("叠好，压在手稿旁边"), "段45c 晾衣账本：落点文本回声（叠好压在手稿旁）")
	_check(e45.contains("归途"), "段45d 核心终稿文本完整保留（零核心改动）")
	await _drop(s2a)
	var s2b: Node3D = await _boot()
	s2b.core.choose(0, 1)
	s2b.core.choose(1, 1)
	s2b.core.choose(2, 2)
	s2b.core.submit_chapter()
	s2b.core.choose(0, 2)
	s2b.core.choose(1, 0)
	s2b.core.choose(2, 0)
	s2b.core.submit_chapter()
	s2b.core.choose(0, 1)
	s2b.core.choose(1, 1)
	s2b.core.choose(2, 1)
	s2b.core.choose(3, 0)
	s2b.core.submit_chapter()
	s2b.core.choose(0, 1)
	s2b.core.choose(1, 1)
	s2b.core.choose(2, 2)
	s2b.core.choose(3, 1)
	s2b.core.submit_chapter()   # 第 5 章（无任何账本）
	await physics_frame
	var e2b: String = str(_ins_text(s2b.get_node("ChapterWorld"), "ending_spot"))
	_check(not e2b.contains("稿纸的最后一页") and not e2b.contains("看了很多遍")
		and not e2b.contains("压在手稿旁边"), "段45e 无账本对照：落点无回声句（门控负例）")
	await _drop(s2b)

	# --- 段46：机制关卡 34「舷窗外的星」——空间站专属科幻线发现，档位双闪+秘密节奏分化 ---
	var s2c: Node3D = await _boot()
	var w2c: Node3D = s2c.get_node("ChapterWorld")
	s2c.core.choose(0, 1)   # 记者
	s2c.core.choose(1, 0)   # 多雨南方小镇（town 变体对照）
	s2c.core.choose(2, 3)
	await physics_frame
	_check(not _has_ins(w2c, "porthole_star"), "段46a town 变体：无舷窗星（站变体专属门控）")
	await _drop(s2c)
	var s2d: Node3D = await _boot()
	var w2d: Node3D = s2d.get_node("ChapterWorld")
	s2d.core.choose(0, 2)   # 宇航员 sci+1
	s2d.core.choose(1, 2)   # 环月空间站 sci+1 → sci2
	s2d.core.choose(2, 3)   # 旧照片
	await physics_frame
	var panes := 0
	for cn2 in w2d.get_node("VariantRoot").get_children():
		if cn2 is MeshInstance3D and absf((cn2 as MeshInstance3D).position.x - 2.76) < 0.01:
			panes += 1
	_check(_has_ins(w2d, "porthole_star") and panes == 2,
		"段46b 站变体×科幻2：舷窗星在场且双板（双闪节奏）")
	_check(str(_ins_text(w2d, "porthole_star")).contains("两下快"), "段46c 档2 文本=闪得更急（信号）")
	s2d.core.submit_chapter()
	s2d.core.choose(0, 2)
	s2d.core.choose(1, 0)
	s2d.core.choose(2, 0)
	s2d.core.submit_chapter()   # 第 3 章
	s2d.core.choose(0, 0)
	s2d.core.choose(1, 0)
	s2d.core.choose(2, 0)
	s2d.core.choose(3, 0)
	s2d.core.submit_chapter()   # 第 4 章
	s2d.core.choose(0, 3)   # colony → 秘密落定
	await physics_frame
	_check(str(_ins_text(w2d, "porthole_star")).contains("同一组数"), "段46d colony：节奏=星图坐标同拍")
	s2d.core.choose(0, 4)   # 改矿井
	await physics_frame
	_check(str(_ins_text(w2d, "porthole_star")).contains("探照灯"), "段46e mine：光来自地面探照灯")
	await _drop(s2d)

	# --- 段50：机制关卡 38「木箱的第二层」——E 掀盖（跨章盖态），旧纸下压着一沓信 ---
	var s5a: Node3D = await _boot()
	var w5a: Node3D = s5a.get_node("ChapterWorld")
	s5a.core.choose(0, 2)
	s5a.core.choose(1, 0)
	s5a.core.choose(2, 2)
	s5a.core.submit_chapter()
	s5a.core.choose(0, 2)
	s5a.core.choose(1, 0)
	s5a.core.choose(2, 1)
	s5a.core.submit_chapter()   # 第 3 章：证物落定 → 老虎窗开启
	await physics_frame
	var lid0: Node3D = w5a.get_node_or_null("VariantRoot/AtticCrateLid")
	_check(lid0 != null and absf(lid0.rotation.x) < 0.001
		and not str(_ins_text(w5a, "attic_stash")).contains("一沓信"), "段50a 盖板平放、文本无递进（未掀盖）")
	s5a.bridge.stash_opened = true   # root 分支同式（headless 直记）
	s5a._apply_world()
	await physics_frame
	var lid1: Node3D = w5a.get_node_or_null("VariantRoot/AtticCrateLid")
	_check(lid1 != null and absf(lid1.rotation.x + 1.2) < 0.001
		and str(_ins_text(w5a, "attic_stash")).contains("一沓信"), "段50b 掀盖：盖板立起 -1.2，文本递进=一沓信（同一人的字）")
	s5a.core.submit_chapter()
	s5a.core.choose(0, 0)
	s5a.core.choose(1, 0)
	s5a.core.choose(2, 0)
	s5a.core.choose(3, 0)
	s5a.core.submit_chapter()   # 第 4 章（多次重建）
	await physics_frame
	var lid2: Node3D = w5a.get_node_or_null("VariantRoot/AtticCrateLid")
	_check(bool(s5a.bridge.build_spec().get("stash_open", false)) and lid2 != null
		and absf(lid2.rotation.x + 1.2) < 0.001, "段50c 跨章盖态存活：重建后盖板仍立起")
	await _drop(s5a)

	# --- 段47：机制关卡 35「桌子的抽屉」——E 拉开（跨章开态），内容随所选道具 ---
	var s3a: Node3D = await _boot()
	var w3a: Node3D = s3a.get_node("ChapterWorld")
	s3a.core.choose(0, 2)   # 宇航员
	s3a.core.choose(1, 0)   # 多雨南方小镇
	s3a.core.choose(2, 2)   # 加密星图 → prop=星图
	await physics_frame
	_check(_has_ins(w3a, "desk_drawer") and w3a.get_node_or_null("VariantRoot/DeskDrawer") != null
		and absf((w3a.get_node("VariantRoot/DeskDrawer") as Node3D).position.z + 8.6) < 0.001,
		"段47a 抽屉在场且闭合（盒体贴桌 z=-8.6）")
	s3a.bridge.drawer_opened = true   # root 分支同式（headless 直记）
	s3a._apply_world()
	await physics_frame
	var dz3: float = (w3a.get_node("VariantRoot/DeskDrawer") as Node3D).position.z
	_check(absf(dz3 + 8.36) < 0.001 and str(_ins_text(w3a, "desk_drawer")).contains("坐标草稿"),
		"段47b 拉开：抽屉盒南移 0.24，内容=坐标草稿（随道具星图）")
	await _drop(s3a)
	var s3b: Node3D = await _boot()
	s3b.core.choose(0, 1)   # 记者
	s3b.core.choose(1, 0)
	s3b.core.choose(2, 3)   # 旧照片
	await physics_frame
	s3b.bridge.drawer_opened = true
	s3b._apply_world()
	await physics_frame
	_check(str(_ins_text(s3b.get_node("ChapterWorld"), "desk_drawer")).contains("底片袋"),
		"段47c 内容随道具分化（旧照片=底片袋）")
	s3b.core.submit_chapter()
	s3b.core.choose(0, 2)
	s3b.core.choose(1, 0)
	s3b.core.choose(2, 0)
	s3b.core.submit_chapter()   # 第 3 章（多次重建）
	await physics_frame
	_check(bool(s3b.bridge.build_spec().get("drawer_open", false))
		and absf((s3b.get_node("ChapterWorld").get_node("VariantRoot/DeskDrawer") as Node3D).position.z + 8.36) < 0.001,
		"段47d 跨章开态存活：多次重建后抽屉仍拉开")
	await _drop(s3b)

	# --- 段48：机制关卡 36「井里的回应」——E 投币一次性，水面硬币 spec 驱动跨章常驻 ---
	var s4a: Node3D = await _boot()
	var w4a: Node3D = s4a.get_node("ChapterWorld")
	s4a.core.choose(0, 1)   # 记者
	s4a.core.choose(1, 1)   # 海边小镇 warm+1
	s4a.core.choose(2, 2)   # 加密星图 sci+1
	s4a.core.submit_chapter()
	s4a.core.choose(0, 2)   # 调阅日志 sci+1
	s4a.core.choose(1, 0)   # 黄铜钥匙 → 证物
	s4a.core.choose(2, 0)   # 撤稿 susp+1 → 揭盖+井沿圆痕
	s4a.core.submit_chapter()   # 第 3 章
	await physics_frame
	_check(_has_ins(w4a, "well_wish_spot") and w4a.get_node_or_null("VariantRoot/WishCoin") == null,
		"段48a 井沿圆痕在场、未投币无硬币")
	_check(s4a.bridge.well_wish() and not s4a.bridge.well_wish(), "段48b 投币一次性（首次真/重复假）")
	s4a._apply_world()
	await physics_frame
	_check(w4a.get_node_or_null("VariantRoot/WishCoin") != null
		and s4a.bridge.well_wish_text("sci").contains("打了个转"), "段48c 投后硬币在水面（spec 驱动）+ 首投文本")
	_check(bool(s4a.bridge.build_spec().get("well_wished", false)), "段48d spec h 维置位")
	s4a.core.submit_chapter()
	s4a.core.choose(0, 0)
	s4a.core.choose(1, 0)
	s4a.core.choose(2, 0)
	s4a.core.choose(3, 0)
	s4a.core.submit_chapter()   # 第 4 章（多次重建）
	await physics_frame
	_check(w4a.get_node_or_null("VariantRoot/WishCoin") != null, "段48e 跨章存活：重建后硬币仍在水面")
	_check(s4a.bridge.well_wish_text("sci").contains("排得很整齐")
		and s4a.bridge.well_wish_text("warm").contains("应了一声")
		and s4a.bridge.well_wish_text("susp").contains("收走了"), "段48f dom 三分化文本")
	await _drop(s4a)

	# --- 段49：机制关卡 37「屋里暗下来了」——灯的开关（双变体通用，表现层瞬态） ---
	var s4b: Node3D = await _boot()
	var w4b: Node3D = s4b.get_node("ChapterWorld")
	s4b.core.choose(0, 1)
	s4b.core.choose(1, 1)
	s4b.core.choose(2, 3)
	await physics_frame
	var rl0: OmniLight3D = w4b.get_node("VariantRoot/RoomLight")
	_check(_has_ins(w4b, "light_switch") and absf(rl0.light_energy - 1.2) < 0.001, "段49a 开关在场，室内灯常亮（energy=1.2）")
	var off: bool = w4b.light_toggle()
	await physics_frame
	_check(off and absf(rl0.light_energy - 0.144) < 0.001
		and s4b.bridge.light_text(true).contains("窗外的光都进来了"), "段49b 熄灯：energy 1.2→0.144，文本=窗外的光都进来了")
	var on: bool = w4b.light_toggle()
	await physics_frame
	_check(not on and absf(rl0.light_energy - 1.2) < 0.001, "段49c 开灯：复位 1.2")
	await _drop(s4b)
	var s4c: Node3D = await _boot()
	var w4c: Node3D = s4c.get_node("ChapterWorld")
	s4c.core.choose(0, 2)
	s4c.core.choose(1, 2)
	s4c.core.choose(2, 3)
	await physics_frame
	var rl1: OmniLight3D = w4c.get_node("VariantRoot/RoomLight")
	var off2: bool = w4c.light_toggle()
	await physics_frame
	_check(off2 and absf(rl1.light_energy - 0.144) < 0.001, "段49d 空间站变体：熄灯同样生效（面板通用）")
	w4c.light_toggle()
	await physics_frame
	_check(absf(rl1.light_energy - 1.2) < 0.001, "段49e 空间站开灯复位")
	await _drop(s4c)

	# --- 段52：机制关卡 40「桌边的椅子」——E 坐下/站起（姿态切换；坐过入终稿清点） ---
	var s7a: Node3D = await _boot()
	var w7a: Node3D = s7a.get_node("ChapterWorld")
	var ex7: CharacterBody3D = s7a.get_node("Explorer")
	await physics_frame
	_check(_has_ins(w7a, "chair") and w7a.get_node_or_null("VariantRoot/ChairSeat") != null, "段52a 椅子在场（座面+靠背+检查点）")
	var prev7: Vector3 = ex7.global_position
	var sat: bool = w7a.chair_sit(ex7)
	await physics_frame
	_check(sat and w7a.chair_sitting and ex7.global_position.distance_to(Vector3(-1.35, 0.5, -9.0)) < 0.25, "段52b E 坐下：落座座面（物理沉降位 1.35,0.5,-9.0）")
	s7a.bridge.chair_sitted = true   # root 分支同式（headless 直记）
	var stood: bool = w7a.chair_stand(ex7)
	await physics_frame
	_check(stood and not w7a.chair_sitting and w7a.is_position_safe(ex7.global_position), "段52c E 站起：回到坐下前位置且安全")
	_check(bool(s7a.bridge.chair_sitted) and s7a.bridge._ending_spot().text.contains("坐在那里读完的"), "段52d 坐过入终稿清点（信是坐在那里读完的）")
	await _drop(s7a)

	# --- 段56：机制关卡 44「舷窗的霜」——站×科幻满档结霜，E 擦霜一次性（跨章保持） ---
	var s11a: Node3D = await _boot()
	var w11a: Node3D = s11a.get_node("ChapterWorld")
	s11a.core.choose(0, 2)   # 宇航员 sci+1
	s11a.core.choose(1, 2)   # 环月空间站 sci+1 → sci2
	s11a.core.choose(2, 3)   # 旧照片 → 未满档
	await physics_frame
	_check(_has_ins(w11a, "porthole_star") and w11a.get_node_or_null("VariantRoot/PortholeFrost") == null,
		"段56a 科幻未满档：星在场但无霜（满档门控负例）")
	s11a.core.choose(2, 2)   # 加密星图 sci+1 → 科幻满档
	await physics_frame
	_check(w11a.get_node_or_null("VariantRoot/PortholeFrost") != null,
		"段56b 科幻满档：霜板覆在星窗上")
	var e056: String = str(_ins_text(w11a, "porthole_star"))
	_check(not e056.contains("比你记得的多"), "段56c 未擦时星检查文本无擦霜句")
	s11a.bridge.porthole_wiped = true   # root 分支同式（headless 直记）
	s11a._apply_world()
	await physics_frame
	_check(w11a.get_node_or_null("VariantRoot/PortholeFrost") == null,
		"段56d E 擦霜：霜板随事务撤除")
	var panes56 := 0
	for cn in w11a.get_node("VariantRoot").get_children():
		if cn is MeshInstance3D and absf((cn as MeshInstance3D).position.x - 2.76) < 0.01:
			panes56 += 1
	_check(panes56 >= 1, "段56e 擦霜后星板仍在（透过擦净处可见）")
	s11a.core.submit_chapter()
	s11a.core.choose(0, 0)
	s11a.core.choose(1, 0)
	s11a.core.choose(2, 0)
	s11a.core.choose(3, 0)
	s11a.core.submit_chapter()   # 第 3 章（多次重建）
	await physics_frame
	_check(bool(s11a.bridge.build_spec().get("porthole_wiped", false))
		and w11a.get_node_or_null("VariantRoot/PortholeFrost") == null, "段56f 跨章保持：擦净后重建不再结霜")
	await _drop(s11a)
	# --- 段57：机制关卡 45「收件槽的绿植」——站×温情专属，E 浇水一次性，温情档开花 ---
	var s12a: Node3D = await _boot()
	var w12a: Node3D = s12a.get_node("ChapterWorld")
	var ex12: CharacterBody3D = s12a.get_node("Explorer")
	s12a.core.choose(0, 2)   # 宇航员 sci+1
	s12a.core.choose(1, 2)   # 环月空间站 sci+1（warm 0）
	s12a.core.choose(2, 3)   # 旧照片
	s12a.core.submit_chapter()   # 第 2 章（warm 0）
	await physics_frame
	_check(not _has_ins(w12a, "station_plant"), "段57a 温情 0：无盆栽（门控负例）")
	s12a.core.choose(0, 1)   # 老友 warm+1 → warm1（盆栽随事务在场）
	await physics_frame
	_check(_has_ins(w12a, "station_plant") and w12a.get_node_or_null("VariantRoot/PlantPot") != null
		and w12a.get_node_or_null("VariantRoot/PlantFlower") == null, "段57b 温情 1：盆栽在场（新芽、无花）")
	_check(str(_ins_text(w12a, "station_plant")).contains("新芽刚冒头"), "段57c tier1 文本=新芽刚冒头")
	var pw1: bool = s12a.bridge.plant_water()
	var pw2: bool = s12a.bridge.plant_water()
	_check(pw1 and not pw2, "段57d 浇水一次性（首次真/重复假）")
	s12a.core.choose(1, 2)   # 未寄出的手稿（宇航员派生 sci+1）→ 证物落定
	s12a.core.choose(2, 0)
	s12a.core.submit_chapter()   # 第 3 章
	await physics_frame
	s12a.core.choose(0, 1)   # 想回家 warm+1 → warm2（tier2 开花）
	await physics_frame
	_check(w12a.get_node_or_null("VariantRoot/PlantFlower") != null
		and str(_ins_text(w12a, "station_plant")).contains("一朵很小的花"), "段57e 温情 2：开花，文本=一朵很小的花")
	s12a.core.choose(2, 1)
	s12a.core.choose(3, 0)
	s12a.core.submit_chapter()   # 第 4 章（多次重建）
	await physics_frame
	_check(str(_ins_text(w12a, "station_plant")).contains("浇过它"), "段57f 跨章存活：浇过水追加句仍在")
	var es12: String = s12a.bridge._ending_spot().text
	_check(es12.contains("浇活的"), "段57g 终稿清点：绿植是你浇活的")
	await _drop(s12a)
	# --- 段58：机制关卡 46「锁纹对位」——抽屉×证物匣联动，E 对位收进夹层（跨章账本） ---
	var s14a: Node3D = await _boot()
	var w14a: Node3D = s14a.get_node("ChapterWorld")
	s14a.core.choose(0, 1)
	s14a.core.choose(1, 1)
	s14a.core.choose(2, 2)
	s14a.core.submit_chapter()
	s14a.core.choose(0, 1)
	s14a.core.choose(1, 0)
	s14a.core.choose(2, 0)
	await physics_frame
	s14a.bridge.drawer_opened = true
	s14a._apply_world()
	await physics_frame
	var m0: bool = s14a.bridge.drawer_match(str(s14a.core.flags.get("evidence", "")))
	s14a._apply_world()
	await physics_frame
	_check(m0 and s14a.bridge.drawer_matched
		and str(_ins_text(w14a, "desk_drawer")).contains("收进了证物匣的夹层"),
		"段58a 对位：抽屉文本追加=收进了证物匣的夹层")
	_check(str(_ins_text(w14a, "evidence_box")).contains("折角正好卡进锁纹"),
		"段58b 证物匡文本追加=折角卡进锁纹（像钥匙的齿）")
	var m1: bool = s14a.bridge.drawer_match(str(s14a.core.flags.get("evidence", "")))
	_check(not m1, "段58c 对位一次性（重复假）")
	s14a.core.submit_chapter()
	s14a.core.choose(0, 1)
	s14a.core.choose(1, 1)
	s14a.core.choose(2, 0)
	s14a.core.choose(3, 0)
	s14a.core.submit_chapter()
	await physics_frame
	_check(str(_ins_text(w14a, "evidence_box")).contains("折角正好卡进锁纹"),
		"段58d 跨章存活：夹层段仍在")
	await _drop(s14a)
	var s14b: Node3D = await _boot()
	var w14b: Node3D = s14b.get_node("ChapterWorld")
	s14b.core.choose(0, 1)
	s14b.core.choose(1, 1)
	s14b.core.choose(2, 3)
	s14b.core.submit_chapter()
	s14b.bridge.drawer_opened = true
	var m2: bool = s14b.bridge.drawer_match("")
	_check(not m2 and not s14b.bridge.drawer_matched,
		"段58e 无证物对照：对位无效且不记账（门控负例）")
	await _drop(s14b)
	# --- 段59：机制关卡 47「应急广播」——站×悬疑≥1专属，双解释的声音空间化 ---
	var s13a: Node3D = await _boot()
	var w13a: Node3D = s13a.get_node("ChapterWorld")
	s13a.core.choose(0, 1)   # 记者（echo 槽可 susp）
	s13a.core.choose(1, 2)   # 环月空间站 sci+1
	s13a.core.choose(2, 3)   # 旧照片
	s13a.core.submit_chapter()   # 第 2 章
	await physics_frame
	s13a.core.choose(0, 1)   # 老友 warm+1
	s13a.core.choose(1, 0)   # 黄铜钥匙 → 证物
	s13a.core.choose(2, 0)   # 撤稿 susp+1 → 广播在场
	await physics_frame
	_check(_has_ins(w13a, "station_broadcast") and w13a.get_node_or_null("VariantRoot/BroadcastPanel") != null,
		"段59a 站×悬疑：应急广播面板在场")
	var bc1: bool = w13a.broadcast_toggle()
	await physics_frame
	var bl: MeshInstance3D = w13a.get_node("VariantRoot/BroadcastLamp")
	_check(bc1 and w13a.broadcast_on and bl.visible
		and s13a.bridge.broadcast_text("").contains("平静的音乐"), "段59b E 开：无秘密=平静音乐，红灯亮")
	var bc2: bool = w13a.broadcast_toggle()
	await physics_frame
	_check(not bc2 and not w13a.broadcast_on and not bl.visible, "段59c E 关：静音，红灯灭")
	s13a.core.choose(0, 3)   # colony → 秘密落定
	await physics_frame
	var bc3: bool = w13a.broadcast_toggle()
	await physics_frame
	_check(bc3 and s13a.bridge.broadcast_text("colony_ship").contains("登船流程"),
		"段59d colony：广播循环登船流程")
	s13a.core.choose(0, 4)   # 改矿井
	await physics_frame
	var bc4: bool = w13a.broadcast_toggle()
	await physics_frame
	_check(s13a.bridge.broadcast_text("mine_door").contains("下井安全须知"),
		"段59e mine：广播循环下井安全须知")
	await _drop(s13a)
	var s13b: Node3D = await _boot()
	var w13b: Node3D = s13b.get_node("ChapterWorld")
	s13b.core.choose(0, 2)
	s13b.core.choose(1, 2)
	s13b.core.choose(2, 3)
	await physics_frame
	_check(not _has_ins(w13b, "station_broadcast"),
		"段59f 悬疑 0 站变体：无广播（门控负例）")
	await _drop(s13b)
	# --- 段60：机制关卡 48「缸水的记忆」——倒过桶水的缸跨章保持满水位（账本固化） ---
	var s15a: Node3D = await _boot()
	var w15a: Node3D = s15a.get_node("ChapterWorld")
	s15a.core.choose(0, 1)   # 记者
	s15a.core.choose(1, 1)   # 海边小镇 warm+1
	s15a.core.choose(2, 2)   # 加密星图 sci+1
	s15a.core.submit_chapter()
	s15a.core.choose(0, 2)   # 调阅日志 sci+1 → sci2 水缸在场
	s15a.core.choose(1, 0)   # 黄铜钥匙 → 证物
	s15a.core.choose(2, 0)   # 撤稿 susp+1 → 辌轺在场
	s15a.core.submit_chapter()   # 第 3 章
	await physics_frame
	for i48 in 3:
		w15a.winch_crank()
	await physics_frame
	var cw0f: float = (w15a.get_node("VariantRoot/CisternWater") as Node3D).position.y
	var p48: bool = w15a.bucket_pour()
	s15a.bridge.cistern_filled = true   # root 分支同式（headless 直记）
	await physics_frame
	var cw1f: float = (w15a.get_node("VariantRoot/CisternWater") as Node3D).position.y
	_check(p48 and absf(cw1f - cw0f - 0.06) < 0.001, "段60a E 倒水：水位 +0.06（即时）")
	s15a.core.submit_chapter()
	s15a.core.choose(0, 1)
	s15a.core.choose(1, 0)
	s15a.core.choose(2, 0)
	s15a.core.choose(3, 0)
	s15a.core.submit_chapter()   # 第 4 章（多次重建）
	await physics_frame
	var cw2f: float = (w15a.get_node("VariantRoot/CisternWater") as Node3D).position.y
	_check(absf(cw2f - cw1f) < 0.001 and s15a.bridge.cistern_filled
		and str(_ins_text(w15a, "cistern")).contains("比记忆里的满"),
		"段60b 跨章重建：水位固化保持，文本=比记忆里的满")
	var es48: String = s15a.bridge._ending_spot().text
	_check(es48.contains("水缸是满的"), "段60c 终稿清点：后院的水缸是满的")
	await _drop(s15a)
	var s15b: Node3D = await _boot()
	var w15b: Node3D = s15b.get_node("ChapterWorld")
	s15b.core.choose(0, 1)
	s15b.core.choose(1, 1)
	s15b.core.choose(2, 2)
	s15b.core.submit_chapter()
	s15b.core.choose(0, 2)
	s15b.core.choose(1, 0)
	s15b.core.choose(2, 0)
	s15b.core.submit_chapter()   # sci2 但未倒水
	await physics_frame
	var cw3: float = (w15b.get_node("VariantRoot/CisternWater") as Node3D).position.y
	_check(not s15b.bridge.cistern_filled and absf(cw3 - 0.62) < 0.001,
		"段60d 未倒水对照：水位基础值、账本未置位")
	await _drop(s15b)
	# --- 段61：机制关卡 49「舱顶通道」——站变体第 3 章起竖向通行，与镇梯对称 ---
	var s16a: Node3D = await _boot()
	var w16a: Node3D = s16a.get_node("ChapterWorld")
	var ex16: CharacterBody3D = s16a.get_node("Explorer")
	s16a.core.choose(0, 2)   # 宇航员 sci+1
	s16a.core.choose(1, 2)   # 环月空间站 sci+1
	s16a.core.choose(2, 3)   # 旧照片
	s16a.core.submit_chapter()   # 第 2 章（后门/舱顶通道未开）
	await physics_frame
	_check(not _has_ins(w16a, "roof_look_station"), "段61a 第 2 章：舱顶通道未开（门控负例）")
	s16a.core.choose(0, 1)   # 老友 warm+1（填满词槽，第 2 章交稿需全填）
	s16a.core.choose(1, 0)   # 黄铜钥匙 → 证物
	s16a.core.choose(2, 0)   # 撤稿 susp+1
	s16a.core.submit_chapter()   # 第 3 章（后门+舱顶通道开）
	await physics_frame
	_check(_has_ins(w16a, "roof_look_station") and w16a.get_node_or_null("VariantRoot/SRoofPlate") != null,
		"段61b 第 3 章：舱顶碰撞板+俯瞰检查点在场")
	ex16.global_position = Vector3(-2.4, 0.2, 8.2)
	await physics_frame
	var base_hit: bool = false
	for cn in w16a.get_node("VariantRoot").get_children():
		if str(cn.name) == "INS_station_roof_base":
			base_hit = true
	_check(base_hit, "段61c 梯基垫点在场")
	ex16.global_position = Vector3(-2.4, 3.62, 10.5)
	await physics_frame
	_check(w16a.is_position_safe(ex16.global_position), "段61d 舱顶站位安全（碰撞板上）")
	_check(str(_ins_text(w16a, "roof_look_station")).contains("小河"), "段61e 俯瞰文本=走廊像小河")
	ex16.global_position = Vector3(-2.4, 0.2, 9.6)
	await physics_frame
	_check(w16a.is_position_safe(ex16.global_position), "段61f 返回走廊：地面站位安全")
	await _drop(s16a)
	# --- 段62：机制关卡 50「舱壁的字条」——站×悬疑满档对称件 ---
	var s17a: Node3D = await _boot()
	var w17a: Node3D = s17a.get_node("ChapterWorld")
	s17a.core.choose(0, 1)   # 记者
	s17a.core.choose(1, 2)   # 环月空间站
	s17a.core.choose(2, 3)   # 旧照片
	s17a.core.submit_chapter()
	s17a.core.choose(0, 1)   # 老友 warm+1
	s17a.core.choose(1, 0)   # 黄铜钥匙 → 证物
	s17a.core.choose(2, 0)   # 撤稿 susp+1
	await physics_frame
	_check(_has_ins(w17a, "station_broadcast") and not _has_ins(w17a, "wall_note_station"),
		"段62a 延用：悬疑 1 时广播在场、字条不在（满档门控负例）")
	s17a.core.choose(1, 2)   # 未寄出的手稿（记者派生 susp+1）→ 悬疛 2
	await physics_frame
	_check(_has_ins(w17a, "wall_note_station") and w17a.get_node_or_null("VariantRoot/WallNotePaper") != null,
		"段62b 悬疛满档：字条在场（纸+检查点）")
	_check(str(_ins_text(w17a, "wall_note_station")).contains("别等广播了"),
		"段62c 字条文本=别等广播了（不指认写字人）")
	await _drop(s17a)
	# --- 段63：机制关卡 51「信箱的小旗」——投递后旗立起，跨章保持 ---
	var s18a: Node3D = await _boot()
	var w18a: Node3D = s18a.get_node("ChapterWorld")
	s18a.core.choose(0, 1)   # 记者
	s18a.core.choose(1, 1)   # 海边小镇 warm+1
	s18a.core.choose(2, 2)   # 加密星图 sci+1
	s18a.core.submit_chapter()   # 第 2 章
	await physics_frame
	_check(not s18a.bridge.mail_sent and w18a.get_node_or_null("VariantRoot/MailFlagPole") == null,
		"段63a 未投递：旗不立（门控负例）")
	s18a.bridge.mail_send()   # 29 投递（账本直记，root 分支同式）
	s18a._apply_world()
	await physics_frame
	_check(w18a.get_node_or_null("VariantRoot/MailFlagPole") != null
		and w18a.get_node_or_null("VariantRoot/MailFlagCloth") != null, "段63b 投递：小旗立起（旗杆+旗面）")
	_check(str(_ins_text(w18a, "mail_slot")).contains("小旗立了起来"),
		"段63c 信箱文本追加=小旗立了起来")
	s18a.core.submit_chapter()
	s18a.core.choose(0, 1)
	s18a.core.choose(1, 0)
	s18a.core.choose(2, 0)
	s18a.core.submit_chapter()   # 第 3 章（多次重建）
	await physics_frame
	_check(w18a.get_node_or_null("VariantRoot/MailFlagPole") != null, "段63d 跨章保持：旗仍立起")
	_check(str(_ins_text(w18a, "mail_slot")).contains("小旗立了起来"), "段63e 跨章文本仍在")
	await _drop(s18a)
	# --- 段64：机制关卡 52「墙上的挂画」——歪画 E 摆正一次性，跨章保持 ---
	var s19a: Node3D = await _boot()
	var w19a: Node3D = s19a.get_node("ChapterWorld")
	var ex19: CharacterBody3D = s19a.get_node("Explorer")
	await physics_frame
	ex19.global_position = Vector3(-4.2, 0.2, -6.0)
	await physics_frame
	_check(_has_ins(w19a, "wall_picture") and w19a.get_node_or_null("VariantRoot/PictureCanvas") != null,
		"段64a 歪画在场（框+画布）")
	var cv: MeshInstance3D = w19a.get_node("VariantRoot/PictureCanvas")
	_check(absf(cv.rotation.x + 0.12) < 0.001, "段64b 画布歪斜 -0.12（未摆正）")
	ex19.global_position = Vector3(-4.2, 0.2, -6.0)
	await physics_frame
	_log("DIAG64_PRE: bridge_ps=%s" % str(s19a.bridge.picture_straight))
	s19a.bridge.straighten_picture()
	_log("DIAG64_POST_CALL: bridge_ps=%s" % str(s19a.bridge.picture_straight))
	s19a._apply_world()
	_log("DIAG64_POST_APPLY: bridge_ps=%s ch=%d" % [str(s19a.bridge.picture_straight), s19a.core.chapter_idx])
	await physics_frame
	var cv3: MeshInstance3D = w19a.get_node("VariantRoot/PictureCanvas")
	_log("DIAG64C: rot=%s ps=%s cv3=%s" % [str(cv3.rotation.x), str(s19a.bridge.picture_straight), str(cv3)])
	_check(absf(cv3.rotation.x) < 0.001 and s19a.bridge.picture_straight,
		"段64c E 摆正：画布转正 0，账本置位")
	_check(str(_ins_text(w19a, "wall_picture")).contains("湖面平了"),
		"段64d 摆正后文本=湖面平了，岸线稳了")
	s19a.core.submit_chapter()
	s19a.core.choose(0, 1)
	s19a.core.choose(1, 0)
	s19a.core.choose(2, 0)
	s19a.core.submit_chapter()   # 第 3 章（多次重建）
	await physics_frame
	var cv2: MeshInstance3D = w19a.get_node("VariantRoot/PictureCanvas")
	_check(absf(cv2.rotation.x) < 0.001 and s19a.bridge.picture_straight, "段64e 跨章保持：摆正态跨章存活")
	await _drop(s19a)
	# --- 段65：机制关卡 53「信号灯箱」——镇×科幻满档对称件 ---
	var s20a: Node3D = await _boot()
	var w20a: Node3D = s20a.get_node("ChapterWorld")
	s20a.core.choose(0, 2)   # 宇航员 sci+1
	s20a.core.choose(1, 0)   # 多雨南方小镇（镇变体，无基调）
	s20a.core.choose(2, 3)   # 旧照片（无基调） → sci 1
	await physics_frame
	_check(not _has_ins(w20a, "signal_box"), "段65a 科幻 1：无灯箱（门控负例）")
	s20a.core.submit_chapter()   # 第 2 章
	s20a.core.choose(0, 2)   # 调阅日志 sci+1
	s20a.core.choose(1, 2)   # 未寄出的手稿（宇航员派生 sci+1）→ sci 3
	s20a.core.choose(2, 1)   # 导航日志被改写 sci+1（宇航员 echo）
	s20a.core.submit_chapter()   # 第 3 章 sci 满档
	await physics_frame
	_check(_has_ins(w20a, "signal_box") and w20a.get_node_or_null("VariantRoot/SignalBoxGreen") != null,
		"段65b 科幻满档：信号灯箱在场（面板+绿灯）")
	_check(str(_ins_text(w20a, "signal_box")).contains("满功率运转"),
		"段65c 文本=满功率运转，等一个愿意听的人")
	await _drop(s20a)	# --- 段66：机制关卡 54「收件槽的应答器」——站×科幻≥2 中档专属 ---
	var s21a: Node3D = await _boot()
	var w21a: Node3D = s21a.get_node("ChapterWorld")
	s21a.core.choose(0, 1)   # 记者（无 sci）
	s21a.core.choose(1, 2)   # 环月空间站 sci+1
	s21a.core.choose(2, 3)   # 旧照片 → sci 1，不满档
	await physics_frame
	_check(not _has_ins(w21a, "transponder"), "段66a 科幻 1：无应答器（门控负例）")
	s21a.core.submit_chapter()   # 第 2 章
	s21a.core.choose(0, 2)   # 调阅日志 sci+1 → sci 2
	s21a.core.choose(1, 2)   # 未寄出的手稿（宇航员派生 sci+1）→ sci 满档
	s21a.core.choose(2, 1)   # 导航日志被改写 sci+1（宇航员 echo）
	s21a.core.submit_chapter()   # 第 3 章
	await physics_frame
	_check(_has_ins(w21a, "transponder") and w21a.get_node_or_null("VariantRoot/TransponderLED") != null,
		"段66b 科幻 2：应答器在场（LED 在场）")
	_check(str(_ins_text(w21a, "transponder")).contains("自动发射信号"),
		"段66c 文本=自动发射信号，等一个回应")
	s21a.core.choose(2, 2)   # 加密星图 sci+1 → sci 4（满档不撤除）
	await physics_frame
	_check(_has_ins(w21a, "transponder"), "段66d 科幻 3：应答器不撤除（与霜不冲突）")
	await _drop(s21a)
	var s21b: Node3D = await _boot()
	var w21b: Node3D = s21b.get_node("ChapterWorld")
	s21b.core.choose(0, 1)   # 记者
	s21b.core.choose(1, 0)   # 多雨南方小镇（镇变体，无基调）
	s21b.core.choose(2, 2)   # 加密星图 sci+1
	await physics_frame
	_check(not _has_ins(w21b, "transponder"), "段66e 镇变体对照：无应答器（站专属）")
	await _drop(s21b)
	# --- 段67：机制关卡 55「壁炉的灰熼」——第 4 章起室内壁炉，dom 三分化检查文本 ---
	var s22a: Node3D = await _boot()
	var w22a: Node3D = s22a.get_node("ChapterWorld")
	s22a.core.choose(0, 1)   # 记者
	s22a.core.choose(1, 1)   # 海边小镇 warm+1
	s22a.core.choose(2, 2)   # 加密星图 sci+1
	s22a.core.submit_chapter()   # 第 2 章
	await physics_frame
	_check(not _has_ins(w22a, "fireplace_ash"), "段67a 第 2 章：壁炉未在场（门控负例）")
	s22a.core.choose(0, 1)
	s22a.core.choose(1, 0)
	s22a.core.choose(2, 0)
	s22a.core.choose(3, 0)
	s22a.core.submit_chapter()   # 第 4 章
	await physics_frame
	_check(_has_ins(w22a, "fireplace_ash") and w22a.get_node_or_null("VariantRoot/FireplaceGlow") != null,
		"段67b 第 4 章：壁炉+灰烬+火光在场")
	var fa_text: String = str(_ins_text(w22a, "fireplace_ash"))
	_check(fa_text.length() > 0, "段67c 灰烬检查文本非空")
	s22a.core.choose(1, 2)   # 改选加密星图 sci+1 → 切 sci 语基
	await physics_frame
	var fa_text2: String = str(_ins_text(w22a, "fireplace_ash"))
	_check(fa_text2.length() > 0, "段67d 基调切换后灰烬检查文本仍在")
	await _drop(s22a)
	# --- 段68：机制关卡 56「停摆的挂钟」——室内北墙常驻挂钟，指针随章节三段递进
	# （停摆 3:00 → 走动 3:40 → 对时 6:30；键控驱动：back_open/ending_dom；悬疑满档→钟摆倾斜+文本后缀）
	var s23a: Node3D = await _boot()
	var w23a: Node3D = s23a.get_node("ChapterWorld")
	_check(_has_ins(w23a, "wall_clock") and w23a.get_node_or_null("VariantRoot/ClockHourPivot") != null,
		"段68a 第 1 章：挂钟常驻在场（钟面+指针）")
	var hp0: Node3D = w23a.get_node("VariantRoot/ClockHourPivot")
	_check(absf(hp0.rotation.z + PI / 2) < 0.001, "段68b 第 1 章：指针停 3:00 整（时针 -90°）")
	var pen0: Node3D = w23a.get_node("VariantRoot/ClockPendulum")
	_check(absf(pen0.rotation.z) < 0.001, "段68c 低悬疑：钟摆垂直下垂")
	var ck0: String = str(_ins_text(w23a, "wall_clock"))
	_check(ck0.contains("三点整"), "段68d 第 1 章：文本=停摆段（三点整）")
	s23a.core.choose(0, 1)   # 记者
	s23a.core.choose(1, 1)   # 海边小镇
	s23a.core.choose(2, 2)   # 加密星图
	s23a.core.submit_chapter()   # 第 2 章（idx1，仍停摆段）
	await physics_frame
	var hp1: Node3D = w23a.get_node("VariantRoot/ClockHourPivot")
	_check(absf(hp1.rotation.z + PI / 2) < 0.001 and str(_ins_text(w23a, "wall_clock")).contains("三点整"),
		"段68e 第 2 章：仍停摆（负例：未到走动门控）")
	s23a.core.choose(0, 0)
	s23a.core.choose(1, 0)
	s23a.core.choose(2, 0)
	s23a.core.submit_chapter()   # 第 3 章（idx2，back_open 翻转 → 走动段）
	await physics_frame
	var hp2: Node3D = w23a.get_node("VariantRoot/ClockHourPivot")
	var mp2: Node3D = w23a.get_node("VariantRoot/ClockMinutePivot")
	_check(absf(hp2.rotation.z + 1.9199) < 0.001 and absf(mp2.rotation.z + 4.18879) < 0.001,
		"段68f 第 3 章：指针走到 3:40（时针 110°/分针 240°）")
	_check(str(_ins_text(w23a, "wall_clock")).contains("走起来"), "段68g 第 3 章：文本=走动段")
	# 悬疑满档：同章切悬疑 → 键维 s 翻转重建 → 钟摆倾斜 + 文本后缀
	s23a.core.choose(0, 0)   # 重读卷宗 susp+1
	s23a.core.choose(1, 2)   # 未寄出的手稿 susp+1
	s23a.core.choose(2, 0)   # 撤稿 susp+1 → 悬疑 3 → 满档
	await physics_frame
	var pen2: Node3D = w23a.get_node("VariantRoot/ClockPendulum")
	_check(absf(pen2.rotation.z + 0.22) < 0.001, "段68h 悬疑满档：钟摆倾斜 -0.22（s 键维重建）")
	_check(str(_ins_text(w23a, "wall_clock")).contains("秒针每跳"), "段68i 悬疑满档：文本追加后缀")
	await _drop(s23a)
	# --- 段69：机制关卡 57「会响的地板」——踩踏响应区（第十二种原型：走过触发，非 E 交互）
	var s24a: Node3D = await _boot()
	var w24a: Node3D = s24a.get_node("ChapterWorld")
	_check(_has_ins(w24a, "floor_board") and w24a.get_node_or_null("VariantRoot/FloorPlank") != null,
		"段69a 室内西走道：松木板+检查点常驻在场")
	_check(not str(_ins_text(w24a, "floor_board")).contains("还挂在耳朵里"),
		"段69b 初始未踩：文本无踩响追加")
	_check(w24a.try_floor_creak_at(Vector3(-3.2, 0.2, -7.6)), "段69c 区内点触发：首次返回 true")
	_check(bool(w24a.floor_creaked), "段69d 触发后 floor_creaked=true")
	_check(str(_ins_text(w24a, "floor_board")).contains("还挂在耳朵里"),
		"段69e 踩后文本：追加「还挂在耳朵里」")
	_check(not w24a.try_floor_creak_at(Vector3(-3.2, 0.2, -7.6)), "段69f 幂等：本章二次踩返回 false")
	_check(not w24a.try_floor_creak_at(Vector3(0.0, 0.2, -7.6)), "段69g 区外点：不触发且状态不变")
	# 真实通路①：重建复位（瞬态语义）
	s24a.core.choose(0, 1)   # 记者
	s24a.core.choose(1, 2)   # 空间站（变体切换 → 重建）
	s24a.core.choose(2, 2)   # 加密星图
	await physics_frame
	_check(not bool(w24a.floor_creaked), "段69h 重建复位：踩响态归零")
	# 真实通路②：Explorer 步入区内 → 物理帧自动触发（非 E、非直调）
	var ex57: Node3D = s24a.get_node("Explorer")
	ex57.teleport_to(Vector3(-3.2, 0.2, -7.6), true)
	await physics_frame
	await physics_frame
	_check(bool(w24a.floor_creaked), "段69i 真实通路：物理帧踩踏触发")
	ex57.teleport_to(Vector3(0.0, 0.2, -5.0), true)   # 走出触发区（防重建后原地复触发）
	await physics_frame
	# 基调三分化（重建后瞬态复位、文本活派生）
	s24a.core.choose(2, 1)   # 泛黄家书 warm+1（替换加密星图，撤 sci）
	s24a.core.choose(1, 1)   # 切海边小镇 warm+1（撤空间站 sci）→ warm=2>sci=0 严格占优
	await physics_frame
	var fb_warm: String = str(_ins_text(w24a, "floor_board"))
	_check(fb_warm.contains("记得每一个走过的人") and not fb_warm.contains("还挂在耳朵里"),
		"段69j 温情基调：文本=温情段且重建后无踩响追加")
	await _drop(s24a)
	# --- 段70：机制关卡 58「门后的镜子」——文本身份三分化（第 13 种原型：身份驱动文本）+ 悬疑满档后缀
	var s25a: Node3D = await _boot()
	var w25a: Node3D = s25a.get_node("ChapterWorld")
	_check(_has_ins(w25a, "wall_mirror") and w25a.get_node_or_null("VariantRoot/MirrorGlass") != null,
		"段70a 南墙内面：镜框+镜面+检查点常驻在场")
	_check(str(_ins_text(w25a, "wall_mirror")).contains("还没看清自己"),
		"段70b 未选身份：文本=倒影兜底段")
	s25a.core.choose(0, 0)   # 侦探（susp+1）
	await physics_frame
	_check(str(_ins_text(w25a, "wall_mirror")).contains("核对一张旧照片"),
		"段70c 侦探身份：文本=核对照片段")
	s25a.core.choose(0, 1)   # 记者（撤侦探）
	await physics_frame
	_check(str(_ins_text(w25a, "wall_mirror")).contains("袖口沾着墨"),
		"段70d 记者身份：同章文本活刷新（无重建）")
	s25a.core.choose(0, 2)   # 宇航员（sci+1）
	await physics_frame
	_check(str(_ins_text(w25a, "wall_mirror")).contains("训练手册"),
		"段70e 宇航员身份：文本=训练手册段")
	s25a.core.choose(0, 0)   # 回侦探（susp+1）
	s25a.core.choose(2, 0)   # 井边的合影（susp+1）→ 悬疑 2 满档
	await physics_frame
	var mt70: String = str(_ins_text(w25a, "wall_mirror"))
	_check(mt70.contains("核对一张旧照片") and mt70.contains("只有你一个人"),
		"段70f 悬疑满档：侦探段+「只有你一个人」后缀（反向安放，盲测安全）")
	_check(not mt70.contains("袖口沾着墨"), "段70g 身份切换不残留：无前身份文本")
	await _drop(s25a)
	# --- 段71：机制关卡 59「烟囱与炊烟」——壁炉 55 的屋顶对应件（第 3 章起同章出现，
	# 空间垂直闭合）；烟柱=任一基调满档，颜色/文本随主基调三分化（零新键维）
	var s26a: Node3D = await _boot()
	var w26a: Node3D = s26a.get_node("ChapterWorld")
	_check(not _has_ins(w26a, "roof_chimney"), "段71a 第 1 章：烟囱未在场（back_open 门控负例）")
	s26a.core.choose(0, 0)   # 侦探 susp+1
	s26a.core.choose(1, 0)   # 多雨南方小镇（无基调）
	s26a.core.choose(2, 0)   # 井边的合影 susp+1 → 悬疑 2 满档
	s26a.core.submit_chapter()   # 第 2 章
	s26a.core.choose(0, 0)   # 重读卷宗 susp+1
	s26a.core.choose(1, 2)   # 未寄出的手稿（侦探派生 susp）
	s26a.core.choose(2, 0)   # echo 槽
	s26a.core.submit_chapter()   # 第 3 章（back_open 翻转）
	await physics_frame
	_check(_has_ins(w26a, "roof_chimney") and w26a.get_node_or_null("VariantRoot/ChimneyCap") != null,
		"段71b 第 3 章：烟囱体+帽+检查点在场（与壁炉同章）")
	_check(_has_ins(w26a, "fireplace_ash") and w26a.get_node_or_null("VariantRoot/SmokeStack") != null,
		"段71c 悬疑满档：烟柱在场（室内炉↔屋顶囱垂直闭合）")
	var ch71: String = str(_ins_text(w26a, "roof_chimney"))
	_check(ch71.contains("屋里没有火"), "段71d 悬疑文本：烟从别的什么地方来（呼应灰烬不泄底）")
	await _drop(s26a)
	# 温情线：炊烟白
	var s26b: Node3D = await _boot()
	var w26b: Node3D = s26b.get_node("ChapterWorld")
	s26b.core.choose(0, 1)   # 记者（无基调）
	s26b.core.choose(1, 1)   # 海边小镇 warm+1
	s26b.core.choose(2, 1)   # 泛黄家书 warm+1 → 温情 2 满档
	s26b.core.submit_chapter()
	s26b.core.choose(0, 1)   # 看儿时老友 warm+1
	s26b.core.choose(1, 1)   # 泛黄的旧照片（记者派生 warm）
	s26b.core.choose(2, 0)
	s26b.core.submit_chapter()   # 第 3 章
	await physics_frame
	_check(w26b.get_node_or_null("VariantRoot/SmokeStack") != null
		and str(_ins_text(w26b, "roof_chimney")).contains("白汽"),
		"段71e 温情满档：烟柱在场+炊烟白汽文本")
	await _drop(s26b)
	# 科幻线：淡蓝烟
	var s26c: Node3D = await _boot()
	var w26c: Node3D = s26c.get_node("ChapterWorld")
	s26c.core.choose(0, 2)   # 宇航员 sci+1
	s26c.core.choose(1, 2)   # 环月空间站 sci+1
	s26c.core.choose(2, 2)   # 加密星图 sci+1 → 科幻 3 满档
	s26c.core.submit_chapter()
	s26c.core.choose(0, 2)   # 旧日志 sci+1
	s26c.core.choose(1, 0)   # 黄铜钥匙（宇航员派生 sci）
	s26c.core.choose(2, 0)
	s26c.core.submit_chapter()   # 第 3 章
	await physics_frame
	_check(w26c.get_node_or_null("VariantRoot/SmokeStack") != null
		and str(_ins_text(w26c, "roof_chimney")).contains("有效率"),
		"段71f 科幻满档：烟柱在场+高效率文本")
	await _drop(s26c)
	# --- 段72：机制关卡 60「壁炉的火」——E 点火/熄火（瞬态重建复位），火光+烟囱同步冒烟
	# （几何级跨机制联动：点火烟独立于基调烟；无壁炉章不响应）
	var s27a: Node3D = await _boot()
	var w27a: Node3D = s27a.get_node("ChapterWorld")
	_check(not bool(w27a.fireplace_toggle()) and w27a.get_node_or_null("VariantRoot/FireLight") == null,
		"段72a 第 1 章：无壁炉不响应（门控负例）")
	s27a.core.choose(0, 0)   # 侦探 susp+1
	s27a.core.choose(1, 0)
	s27a.core.choose(2, 0)   # → 悬疑 2 满档
	s27a.core.submit_chapter()
	s27a.core.choose(0, 0)
	s27a.core.choose(1, 2)
	s27a.core.choose(2, 0)
	s27a.core.submit_chapter()   # 第 3 章
	await physics_frame
	_check(w27a.fireplace_toggle(), "段72b E 点火：返回 true（lit 置位）")
	_check(w27a.get_node_or_null("VariantRoot/FireLight") != null, "段72c 点火：火光 OmniLight 在场")
	var glow72: Node3D = w27a.get_node("VariantRoot/FireplaceGlow")
	_check(glow72.scale.x > 2.0, "段72d 点火：余烬微光放大")
	_check(w27a.get_node_or_null("VariantRoot/FireSmoke/FireSmokeSeg2") != null,
		"段72e 点火：烟囱同步冒暖白烟（三节，几何级联动）")
	var lit_t: String = str(s27a.bridge.fireplace_state_text(true, "susp"))
	_check(lit_t.contains("发信号") and lit_t.contains("烟变浓"), "段72f 悬疑点火文本：发信号+烟变浓")
	_check(str(s27a.bridge.fireplace_state_text(false, "susp")).contains("灰烬还是那些灰烬"),
		"段72g 熄火文本：统一短句")
	_check(not w27a.fireplace_toggle(), "段72h 再 E 熄火：返回 false")
	_check(w27a.get_node_or_null("VariantRoot/FireLight") == null
		and w27a.get_node_or_null("VariantRoot/FireSmoke") == null
		and glow72.scale.x < 1.01, "段72i 熄火：光/烟撤除+余烬复原")
	w27a.fireplace_toggle()   # 再点火（供重建复位断言）
	s27a.core.choose(0, 1)   # 第 3 章槽 0 改温情词 → w 维翻转 → 重建
	await physics_frame
	_check(not bool(w27a.fireplace_lit) and w27a.get_node_or_null("VariantRoot/FireLight") == null,
		"段72j 重建复位：点火态归零（时间跳跃=火熄）")
	await _drop(s27a)
	# --- 段73：机制关卡 61「窗台的天光」——窗色随章节三段（夜→微亮→金黄），
	# 悬疑满档反转近黑（第 15 种原型：双轴材质状态；文本后缀与窗色同源）
	var s28a: Node3D = await _boot()
	var w28a: Node3D = s28a.get_node("ChapterWorld")
	var win73: MeshInstance3D = w28a.get_node("VariantRoot/Window")
	var wc73: StandardMaterial3D = win73.material_override as StandardMaterial3D
	_check(wc73.albedo_color.is_equal_approx(Color(0.55, 0.6, 0.7)),
		"段73a 第 1 章：窗色=夜（镇基色零回归）")
	_check(not str(_ins_text(w28a, "window_look")).contains("天色比昨天"),
		"段73b 第 1 章：窗文本无天光后缀")
	s28a.core.choose(0, 0)   # 侦探 susp+1
	s28a.core.choose(1, 0)
	s28a.core.choose(2, 0)   # 合影 susp+1 → 悬疑 2 满档
	await physics_frame
	wc73 = (w28a.get_node("VariantRoot/Window") as MeshInstance3D).material_override as StandardMaterial3D
	_check(wc73.albedo_color.is_equal_approx(Color(0.07, 0.08, 0.11)),
		"段73c 悬疑满档：窗色反转近黑（s 维重建）")
	_check(str(_ins_text(w28a, "window_look")).contains("不该是黑的"),
		"段73d 悬疑反转文本：窗外不该是黑的（盲测安全）")
	s28a.core.choose(0, 1)   # 记者撤侦探
	s28a.core.choose(1, 1)   # 海边 warm+1
	s28a.core.choose(2, 1)   # 家书 warm+1（撤合影）→ warm=2
	await physics_frame
	wc73 = (w28a.get_node("VariantRoot/Window") as MeshInstance3D).material_override as StandardMaterial3D
	_check(wc73.albedo_color.is_equal_approx(Color(0.55, 0.6, 0.7)),
		"段73e 悬疑回落：窗色复原夜色（反转可逆）")
	s28a.core.submit_chapter()   # 第 2 章
	s28a.core.choose(0, 1)   # 老友 warm+1
	s28a.core.choose(1, 1)   # 旧照片
	s28a.core.choose(2, 0)
	s28a.core.submit_chapter()   # 第 3 章（back_open）
	await physics_frame
	wc73 = (w28a.get_node("VariantRoot/Window") as MeshInstance3D).material_override as StandardMaterial3D
	_check(wc73.albedo_color.is_equal_approx(Color(0.68, 0.7, 0.72))
		and str(_ins_text(w28a, "window_look")).contains("天色比昨天亮了一点"),
		"段73f 第 3 章：窗色微亮+天光后缀一（b 维）")
	# 第 3/4 章填槽避开悬疑词（悬疑≥2 会让反转分支压过金黄段）：全程走 warm
	s28a.core.choose(0, 1)   # 「他只是累了」warm+1
	s28a.core.choose(1, 1)   # 妹妹代笔 warm+1
	s28a.core.choose(2, 1)   # 汤要凉了 warm+1
	s28a.core.choose(3, 0)   # 饭菜香气 warm+1
	s28a.core.submit_chapter()   # 第 4 章
	s28a.core.choose(0, 1)   # 温着的粥 warm+1
	s28a.core.choose(1, 1)   # 等我回家 warm+1
	s28a.core.choose(2, 1)   # （改稿）催泪收尾 warm+2 sci-1（陷阱+1 抗议：不交第 5 章无碍；避悬疑）
	s28a.core.choose(3, 1)   # 热饭 warm+1
	s28a.core.submit_chapter()   # 第 5 章（ending_dom 非空）
	await physics_frame
	wc73 = (w28a.get_node("VariantRoot/Window") as MeshInstance3D).material_override as StandardMaterial3D
	_check(wc73.albedo_color.is_equal_approx(Color(0.8, 0.66, 0.42))
		and str(_ins_text(w28a, "window_look")).contains("天亮透了"),
		"段73g 第 5 章：窗色金黄晨光+天光后缀二（ending_dom 维）")
	await _drop(s28a)
	# --- 段74：机制关卡 62「墙角的木箱堆」——遮挡揭示（第 16 种原型）：E 推开顶层箱
	# 露出墙裙身高刻痕；账本跨章保持（y%d 键维）；文本复用身份轴（58）
	var s29a: Node3D = await _boot()
	var w29a: Node3D = s29a.get_node("ChapterWorld")
	_check(_has_ins(w29a, "crate_stack") and w29a.get_node_or_null("VariantRoot/HeightMark3") != null
		and w29a.get_node_or_null("VariantRoot/HeightMarkNum") != null,
		"段74a 北墙墙角：箱堆+四道刻痕+数字板常驻在场")
	var ct74: Node3D = w29a.get_node("VariantRoot/CrateTop")
	_check(absf(ct74.position.x - 3.0) < 0.01 and str(_ins_text(w29a, "crate_stack")).contains("挡住了"),
		"段74b 未推：顶箱在原位+文本=遮挡提示句")
	s29a.core.choose(0, 0)   # 侦探
	await physics_frame
	s29a.bridge.crate_slide()
	s29a._apply_world()
	await physics_frame
	var ct74b: Node3D = w29a.get_node("VariantRoot/CrateTop")
	_check(absf(ct74b.position.x - 2.3) < 0.01, "段74c E 推箱：顶箱侧滑 0.7m（遮挡解除）")
	var ckt74: String = str(_ins_text(w29a, "crate_stack"))
	_check(ckt74.contains("长高的孩子") and bool(s29a.bridge.crate_slid),
		"段74d 侦探身份：揭示文本=身高刻痕段+账本置位")
	s29a.bridge.crate_slide()
	s29a._apply_world()
	await physics_frame
	var ct74c: Node3D = w29a.get_node("VariantRoot/CrateTop")
	_check(bool(s29a.bridge.crate_slid) and absf(ct74c.position.x - 2.3) < 0.01,
		"段74e 幂等：再推不回滑（一次性）")
	# 身份轴活切换（须在第 1 章内：身份槽随章首快照锁定）
	s29a.core.choose(0, 1)   # 改选记者（role 不在键 → 无重建，文本活刷新）
	await physics_frame
	_check(str(_ins_text(w29a, "crate_stack")).contains("铅笔写的日期"),
		"段74f 记者身份：揭示文本活切换（同章无重建）")
	s29a.core.choose(0, 0)   # 回侦探
	s29a.core.choose(1, 0)
	s29a.core.choose(2, 0)
	s29a.core.submit_chapter()   # 第 2 章
	await physics_frame
	var ct74d: Node3D = w29a.get_node("VariantRoot/CrateTop")
	_check(absf(ct74d.position.x - 2.3) < 0.01,
		"段74g 跨章保持：第 2 章顶箱仍推开（y 维账本驱动）")
	await _drop(s29a)
	# --- 段75：机制关卡 63「休眠舱的呼吸灯」——站专属常驻+时间驱动程序循环动画（第 17 种原型）
	var s30a: Node3D = await _boot()
	var w30a: Node3D = s30a.get_node("ChapterWorld")
	s30a.core.choose(1, 1)   # 海边小镇 → 镇变体
	await physics_frame
	_check(not _has_ins(w30a, "sleep_pod") and w30a.get_node_or_null("VariantRoot/SleepPodBody") == null,
		"段75a 镇变体：无休眠舱（门控负例）")
	s30a.core.choose(1, 2)   # 环月空间站 → 站变体（place 键翻转重建）
	await physics_frame
	_check(_has_ins(w30a, "sleep_pod") and w30a.get_node_or_null("VariantRoot/SleepPodLamp") != null,
		"段75b 站变体：舱体+呼吸灯+检查点在场")
	var lamp75: MeshInstance3D = w30a.get_node("VariantRoot/SleepPodLamp")
	var lm75: StandardMaterial3D = lamp75.material_override as StandardMaterial3D
	var emax75: float = lm75.emission_energy_multiplier
	var emin75: float = emax75
	for i75 in 5:
		for j75 in 16:
			await physics_frame
		var ev75: float = lm75.emission_energy_multiplier
		emax75 = maxf(emax75, ev75)
		emin75 = minf(emin75, ev75)
	_check(emax75 - emin75 > 0.3, "段75c 呼吸中：emission 正弦波动（%.2f~%.2f，跨相位采样）" % [emin75, emax75])
	s30a.core.choose(0, 2)   # 宇航员
	await physics_frame
	_check(str(_ins_text(w30a, "sleep_pod")).contains("自己的名字"),
		"段75d 宇航员身份：名单上自己的名字")
	s30a.core.choose(0, 1)   # 记者（身份槽第 1 章内活切换）
	await physics_frame
	_check(str(_ins_text(w30a, "sleep_pod")).contains("灯为谁亮着"),
		"段75e 记者身份：灯为谁亮着（活刷新）")
	s30a.core.choose(1, 1)   # 切回镇变体（place 键翻转重建）
	await physics_frame
	_check(w30a.get_node_or_null("VariantRoot/SleepPodBody") == null
		and str(_ins_text(w30a, "sleep_pod")).length() == 0,
		"段75f 切回镇变体：舱体/检查点/文本同步撤除")
	await _drop(s30a)
	# --- 段76：机制关卡 64「檐下的雨」——镇变体常驻，雨势三档随悬疑轴（第 18 种原型：
	# 全局环境状态机——文本里「一直在下的雨」实体化为滴线/水花/雨声三档）
	var s31a: Node3D = await _boot()
	var w31a: Node3D = s31a.get_node("ChapterWorld")
	s31a.core.choose(1, 2)   # 环月空间站
	await physics_frame
	_check(not _has_ins(w31a, "eaves_rain") and w31a.get_node_or_null("VariantRoot/RainDrop0") == null,
		"段76a 站变体：无檐水（门控负例）")
	s31a.core.choose(1, 1)   # 海边小镇 → 镇变体（susp 0=雨歇档）
	await physics_frame
	_check(w31a.get_node_or_null("VariantRoot/RainDrop0") != null
		and w31a.get_node_or_null("VariantRoot/RainDrop1") == null,
		"段76b 雨歇档：残滴 1 条（滴线负例）")
	var rp76: AudioStreamPlayer = w31a.get_node("VariantRoot/RainPlayer")
	_check(absf(rp76.volume_db + 60.0) < 0.1 and str(_ins_text(w31a, "eaves_rain")).contains("雨停了"),
		"段76c 雨歇档：雨声静音 -60+文本=最后一滴水")
	s31a.core.choose(2, 0)   # 合影 susp+1 → 小雨档
	await physics_frame
	_check(w31a.get_node_or_null("VariantRoot/RainDrop1") != null
		and w31a.get_node_or_null("VariantRoot/RainDrop2") == null
		and absf((w31a.get_node("VariantRoot/RainPlayer") as AudioStreamPlayer).volume_db + 18.0) < 0.1
		and str(_ins_text(w31a, "eaves_rain")).contains("小雨"),
		"段76d 小雨档：滴线 2 条+雨声 -18+文本=连成线")
	s31a.core.choose(0, 0)   # 侦探 susp+1 → 满档暴雨
	await physics_frame
	_check(w31a.get_node_or_null("VariantRoot/RainDrop2") != null
		and absf((w31a.get_node("VariantRoot/RainPlayer") as AudioStreamPlayer).volume_db + 8.0) < 0.1
		and str(_ins_text(w31a, "eaves_rain")).contains("打拍子"),
		"段76e 暴雨档：滴线 3 条+雨声 -8+文本=间隔完全相等（盲测安全）")
	s31a.core.choose(1, 2)   # 切回站变体（place 键翻转重建）
	await physics_frame
	_check(w31a.get_node_or_null("VariantRoot/RainDrop0") == null
		and w31a.get_node_or_null("VariantRoot/RainPlayer") == null,
		"段76f 切回站变体：滴线与雨声同步撤除")
	await _drop(s31a)
	# --- 段77：机制关卡 65「夜里的叩门声」——镇×悬疑满档×有证物三条件激活循环敲击音
	# （第 19 种原型：无检查点的事件反馈；门槛石常驻作观察入口；三条件全键控零新维）
	var s32a: Node3D = await _boot()
	var w32a: Node3D = s32a.get_node("ChapterWorld")
	s32a.core.choose(0, 0)   # 侦探 susp+1
	s32a.core.choose(1, 1)   # 海边小镇 → 镇变体
	s32a.core.choose(2, 0)   # 合影 susp+1 → 悬疑 2 满档（但无证物）
	await physics_frame
	_check(w32a.get_node_or_null("VariantRoot/DoorStepStone") != null
		and w32a.get_node_or_null("VariantRoot/KnockPlayer") == null,
		"段77a 镇+满档无证物：门槛石在场+叩门未激活（evidence 条件负例）")
	_check(str(_ins_text(w32a, "door_step")).contains("进出门的人都走这里"),
		"段77b 门槛石静默文本：日常句")
	# 变体对照/可逆性（第 1 章内：地点槽随章首快照锁定，交稿后无法切变体）
	s32a.core.choose(1, 2)   # 切站变体（place 首维翻转 → 全件撤除）
	await physics_frame
	_check(w32a.get_node_or_null("VariantRoot/KnockPlayer") == null
		and w32a.get_node_or_null("VariantRoot/DoorStepStone") == null,
		"段77c 切站变体：敲门与门槛石同步撤除")
	s32a.core.choose(1, 1)   # 切回镇（仍无证物 → 叩门保持未激活）
	await physics_frame
	_check(w32a.get_node_or_null("VariantRoot/DoorStepStone") != null
		and w32a.get_node_or_null("VariantRoot/KnockPlayer") == null,
		"段77d 切回镇：门槛石恢复、叩门仍待证物（条件可逆）")
	s32a.core.submit_chapter()   # 第 2 章
	s32a.core.choose(1, 0)   # 黄铜钥匙（evidence flag 立即生效 → e 维翻转重建）
	await physics_frame
	_check(w32a.get_node_or_null("VariantRoot/KnockPlayer") != null,
		"段77e 拿到证物：三条件齐 → KnockPlayer 激活（循环叩门）")
	_check(str(_ins_text(w32a, "door_step")).contains("三下敲门声") and str(_ins_text(w32a, "door_step")).contains("门外只有雨"),
		"段77f 门槛石敲门文本：听见+无人（盲测安全）")
	await _drop(s32a)
	# --- 段78：机制关卡 66「松动的地板下面」——57 咯吱板的空间因果补完：E 掀板露浅洞铁盒
	# （账本 z%d 键维跨章；文本身份三分化；掀板后踩响禁用=空间因果自洽）
	var s33a: Node3D = await _boot()
	var w33a: Node3D = s33a.get_node("ChapterWorld")
	_check(w33a.get_node_or_null("VariantRoot/DarkHole") == null
		and str(_ins_text(w33a, "floor_board")).contains("踩上去会响"),
		"段78a 未掀：无浅洞+文本=57 松板句（dom 兼容）")
	s33a.core.choose(0, 0)   # 侦探
	s33a.bridge.floorboard_lift()
	s33a._apply_world()
	await physics_frame
	_check(w33a.get_node_or_null("VariantRoot/DarkHole") != null
		and w33a.get_node_or_null("VariantRoot/OldBox") != null,
		"段78b E 掀板：浅洞+铁盒在场（遮挡解除）")
	var plk78: Node3D = w33a.get_node("VariantRoot/FloorPlank")
	_check(absf(plk78.position.x + 3.9) < 0.01 and plk78.rotation.x < -0.5,
		"段78c 板斜靠墙根：位移+倾斜（视觉遮挡解除）")
	var fb78: String = str(_ins_text(w33a, "floor_board"))
	_check(fb78.contains("烧掉一半的照片") and bool(s33a.bridge.floorboard_open),
		"段78d 侦探身份：掀开文本=半张照片+账本置位")
	_check(not w33a.try_floor_creak_at(Vector3(-3.2, 0.2, -7.6)),
		"段78e 掀板后踩响禁用：板不在了不响（空间因果）")
	s33a.bridge.floorboard_lift()
	s33a._apply_world()
	await physics_frame
	_check(bool(s33a.bridge.floorboard_open) and w33a.get_node_or_null("VariantRoot/OldBox") != null,
		"段78f 幂等：再掀不回盖（一次性）")
	s33a.core.choose(1, 1)
	s33a.core.choose(2, 1)
	s33a.core.submit_chapter()   # 第 2 章
	await physics_frame
	_check(w33a.get_node_or_null("VariantRoot/OldBox") != null
		and w33a.get_node_or_null("VariantRoot/DarkHole") != null,
		"段78g 跨章保持：第 2 章浅洞铁盒仍在（z 维账本驱动）")
	await _drop(s33a)
	# --- 段79：机制关卡 67「墙上的软木板」——证物描摹钉板（与 46 收进互补的外向展示，
	# 第 20 种机制原型：collect 的展示外化；账本 p2 维跨章；已钉句带 prop 派生轮廓）
	var s34a: Node3D = await _boot()
	var w34a: Node3D = s34a.get_node("ChapterWorld")
	_check(_has_ins(w34a, "soft_board") and w34a.get_node_or_null("VariantRoot/SoftBoard") != null
		and w34a.get_node_or_null("VariantRoot/PinnedPaper") == null,
		"段79a 东墙内面：软木板+图钉常驻，未钉无描摹纸（负例）")
	_check(str(_ins_text(w34a, "soft_board")).contains("散在板角"),
		"段79b 无证物：空板句")
	s34a.core.choose(0, 1)   # 记者
	s34a.core.choose(1, 1)   # 海边小镇
	s34a.core.choose(2, 2)   # 加密星图（prop=星图）
	s34a.core.submit_chapter()   # 第 2 章
	s34a.core.choose(1, 2)   # 未寄出的手稿（记者派生证物，flag evidence 立即生效）
	await physics_frame
	_check(not bool(s34a.bridge.evidence_pinned)
		and str(_ins_text(w34a, "soft_board")).contains("描一份轮廓"),
		"段79c 有证物未钉：邀请句（evidence flag 即时、pinned 独立）")
	s34a.bridge.board_pin()
	s34a._apply_world()
	await physics_frame
	_check(bool(s34a.bridge.evidence_pinned)
		and w34a.get_node_or_null("VariantRoot/PinnedPaper") != null
		and w34a.get_node_or_null("VariantRoot/PinRedLine") != null,
		"段79d E 钉板：描摹纸+红线在场+账本置位")
	var bt79: String = str(_ins_text(w34a, "soft_board"))
	_check(bt79.contains("红线从") and bt79.contains("星图"),
		"段79e 已钉句：红线+证物轮廓随 prop 派生（星图）")
	s34a.bridge.board_pin()
	s34a._apply_world()
	await physics_frame
	_check(w34a.get_node_or_null("VariantRoot/PinnedPaper") != null,
		"段79f 幂等：再钉不变化（一次性）")
	s34a.core.choose(2, 0)
	s34a.core.submit_chapter()   # 第 3 章
	await physics_frame
	_check(w34a.get_node_or_null("VariantRoot/PinnedPaper") != null,
		"段79g 跨章保持：第 3 章描摹纸仍在（p2 维账本驱动）")
	await _drop(s34a)
	# --- 段80：机制关卡 68「八音盒」——有限演奏（上发条→1.6s 程序旋律→曲终落闩），
	# 第 21 种机制原型：有限时长演奏（与 43 收音机无限循环对照；音频第四型：离散音符序列）
	var s35a: Node3D = await _boot()
	var w35a: Node3D = s35a.get_node("ChapterWorld")
	_check(_has_ins(w35a, "music_box") and w35a.get_node_or_null("VariantRoot/MusicBox") != null
		and not bool(w35a.music_playing),
		"段80a 小凳八音盒常驻在场+初始静默")
	_check(w35a.musicbox_wind(), "段80b E 上发条：开始演奏（返回 true）")
	_check(bool(w35a.music_playing) and not bool(w35a.music_done),
		"段80c 演奏中：playing 置位+未落闩")
	_check(not w35a.musicbox_wind(), "段80d 演奏中再 E：不重播（幂等负例）")
	for i80 in 110:
		await physics_frame
	_check(bool(w35a.music_done) and not bool(w35a.music_playing),
		"段80e 曲终落闩：1.8s 后 done 置位（有限演奏）")
	_check(w35a.musicbox_wind() and bool(w35a.music_playing) and not bool(w35a.music_done),
		"段80f 曲终再上发条：可重复演奏（瞬态重置）")
	var sci80: String = str(s35a.bridge.musicbox_text(false, false, "sci"))
	var warm80: String = str(s35a.bridge.musicbox_text(false, false, "warm"))
	_check(sci80.contains("星历") and warm80.contains("哄人睡觉"),
		"段80g 听后感随主基调三分化（星历/哄人睡觉）")
	await _drop(s35a)
	# --- 段81：机制关卡 69「窗台的回信」——玩家写作实体化：E 循环三档语气（可逆改写），
	# 账本记最终档跨章（l2 键维）；墨线随档位视觉递进；与词槽改写同构（第 22 种原型：循环后固化）
	var s36a: Node3D = await _boot()
	var w36a: Node3D = s36a.get_node("ChapterWorld")
	_check(_has_ins(w36a, "letter_draft") and w36a.get_node_or_null("VariantRoot/LetterPaper") != null
		and int(s36a.bridge.letter_stage) == 0,
		"段81a 窗台稿纸常驻+初始未写（stage=0）")
	_check(str(_ins_text(w36a, "letter_draft")).contains("还没开头"),
		"段81b 未写文本：blank 句")
	var st1: int = s36a.bridge.letter_cycle()
	_check(st1 == 1 and int(s36a.bridge.letter_stage) == 1,
		"段81c 第一次 E：档 1（平静=勿念）")
	var st2: int = s36a.bridge.letter_cycle()
	_check(st2 == 2, "段81d 第二次 E：档 2（牵挂=井边的花）")
	var st3: int = s36a.bridge.letter_cycle()
	s36a._apply_world()   # E 分支同款：刷新世界与文本（直调 cycle 不自动应用）
	await physics_frame
	_check(st3 == 3 and str(_ins_text(w36a, "letter_draft")).contains("到底看见了什么"),
		"段81e 第三次 E：档 3（追问）+文本固化当前档")
	_check(w36a.get_node_or_null("VariantRoot/LetterInk2") != null,
		"段81f 墨线视觉递进：3 条随档位出现（l2 键维重建）")
	s36a.core.choose(0, 1)
	s36a.core.choose(1, 1)
	s36a.core.choose(2, 1)
	s36a.core.submit_chapter()   # 第 2 章
	await physics_frame
	_check(int(s36a.bridge.letter_stage) == 3
		and str(_ins_text(w36a, "letter_draft")).contains("到底看见了什么"),
		"段81g 跨章保持：第 2 章仍为档 3（最终档账本驱动）")
	await _drop(s36a)
	# --- 段82：机制关卡 70「守夜」——灯灭（37）×壁炉点火（60）×坐椅子（40）三瞬态叠加
	# 涌现态（第 23 种原型）：火光增旺 1.6→2.4+守夜文本；任一退出即消散；重建复位
	var s37a: Node3D = await _boot()
	var w37a: Node3D = s37a.get_node("ChapterWorld")
	var ex82: Node3D = s37a.get_node("Explorer")
	# 壁炉第 3 章才在场（60 门控）——先推进章节再验证守夜
	s37a.core.choose(0, 0); s37a.core.choose(1, 0); s37a.core.choose(2, 0)
	s37a.core.submit_chapter()
	s37a.core.choose(0, 0); s37a.core.choose(1, 2); s37a.core.choose(2, 0)
	s37a.core.submit_chapter()   # 第 3 章
	await physics_frame
	_check(not bool(w37a.hearth_vigil), "段82a 初始：非守夜")
	w37a.fireplace_toggle()
	_check(not bool(w37a.hearth_vigil), "段82b 仅点火：未涌现（缺灯灭+未坐）")
	w37a.light_toggle()
	_check(not bool(w37a.hearth_vigil), "段82c 点火+灯灭：仍未涌现（缺坐着）")
	w37a.chair_sit(ex82)
	await physics_frame
	var fl82: OmniLight3D = w37a.get_node_or_null("VariantRoot/FireLight")
	_check(bool(w37a.hearth_vigil) and fl82 != null and absf(fl82.light_energy - 2.4) < 0.01,
		"段82d 三瞬态齐：守夜涌现+火光增旺 2.4")
	_check(str(s37a.bridge.vigil_text()).contains("守着这炉火"),
		"段82e 守夜文本：今晚不睡了，等门响（盲测安全）")
	w37a.chair_stand(ex82)
	await physics_frame
	fl82 = w37a.get_node_or_null("VariantRoot/FireLight")
	_check(not bool(w37a.hearth_vigil) and fl82 != null and absf(fl82.light_energy - 1.6) < 0.01,
		"段82f 站起即消散：火光回落 1.6（任一退出即不成立）")
	w37a.chair_sit(ex82)
	s37a.core.choose(0, 1)   # 切基调（w 维翻转重建）
	await physics_frame
	_check(not bool(w37a.hearth_vigil),
		"段82g 重建复位：守夜态归零（瞬态涌现不跨章）")
	await _drop(s37a)
	# --- 段83：机制关卡 71「回敲门」——65 叩门的镜像对话：E 木门=玩家回应世界的事件
	# （第 24 种原型：事件回应交互；激活态首敲=「像在听」本章一次；原门句保留拼接）
	var s38a: Node3D = await _boot()
	var w38a: Node3D = s38a.get_node("ChapterWorld")
	_check(not bool(w38a.knock_active) and not bool(w38a.knock_answered),
		"段83a 初始：叩门未激活（镇+无证物+低悬疑）")
	var dt83a: String = str(s38a.bridge.door_knock_back_text(false, false))
	_check(dt83a.contains("没有人应"), "段83b 非激活敲门文本：这屋里本来也只有你")
	s38a.core.choose(0, 0)   # 侦探 susp+1
	s38a.core.choose(1, 1)   # 镇
	s38a.core.choose(2, 0)   # 合影 susp+1 → 满档
	s38a.core.submit_chapter()
	s38a.core.choose(1, 0)   # 黄铜钥匙 → evidence 置位 → 65 激活（knock_active 快照）
	await physics_frame
	_check(bool(w38a.knock_active) and not bool(w38a.knock_answered),
		"段83c 三条件齐：knock_active 快照置位、回应待发")
	_check(str(s38a.bridge.door_knock_back_text(true, false)).contains("像在听"),
		"段83d 激活回应文本：里面安静得像在听（盲测安全）")
	w38a.knock_answered = true
	_check(str(s38a.bridge.door_knock_back_text(true, true)).contains("用完了"),
		"段83e 已回应幂等文本：刚才那一下用完了")
	await _drop(s38a)
	# --- 段84：机制关卡 72「你自己的脚印」——42 的镜像对仗：动线采样 0.9m 留痕，
	# 8 枚淡足迹循环复用（无检查点：世界记住你的动线，不需要按 E 看）
	var s39a: Node3D = await _boot()
	var w39a: Node3D = s39a.get_node("ChapterWorld")
	var ex84: Node3D = s39a.get_node("Explorer")
	var f0: MeshInstance3D = w39a.get_node_or_null("VariantRoot/TrailFoot0")
	_check(f0 != null and f0.visible and absf(f0.position.z - 14.0) < 0.5,
		"段84a 出生点首样本：足迹 0 于 spawn（起点也是动线的一部分）")
	ex84.teleport_to(Vector3(0.3, 0.2, 6.2), true)   # >0.9m 第二样本
	await physics_frame
	await physics_frame
	var f1: MeshInstance3D = w39a.get_node_or_null("VariantRoot/TrailFoot1")
	_check(f1 != null and f1.visible and absf(f1.position.z - 6.2) < 0.5,
		"段84b 动线样本：足迹 1 于传送目的地（0.9m 间距采样）")
	var hidden_cnt := 0
	for hi84 in 8:
		var hm: MeshInstance3D = w39a.get_node("VariantRoot/TrailFoot%d" % hi84)
		if not hm.visible:
			hidden_cnt += 1
	_check(hidden_cnt == 6, "段84c 其余 6 枚保持隐藏（循环复用未到）")
	await _drop(s39a)
	# --- 段85：机制关卡 73「地方的记忆」——走过三处记忆点唤起闪回（信号→hud toast；
	# 本章一次、重建重置；位置家族第四处：42 泥印/57 踩响/72 留痕/73 唤起）
	var s40a: Node3D = await _boot()
	var w40a: Node3D = s40a.get_node("ChapterWorld")
	var ex85: Node3D = s40a.get_node("Explorer")
	var recalled := []
	w40a.memory_recalled.connect(func(t: String) -> void: recalled.append(t))
	_check(w40a.memory_fired == [false, false, false],
		"段85a 初始：三处记忆均未唤起")
	ex85.teleport_to(Vector3(-2.5, 0.2, -17.2), true)   # 井边
	await physics_frame
	await physics_frame
	_check(bool(w40a.memory_fired[0]) and recalled.size() == 1
		and str(recalled[0]).contains("小时候打水"),
		"段85b 井边唤起：信号发出+文本=打水的记忆")
	ex85.teleport_to(Vector3(0, 0.2, -3.0), true)   # 门槛
	await physics_frame
	await physics_frame
	_check(bool(w40a.memory_fired[1]) and recalled.size() == 2
		and str(recalled[1]).contains("鞋底"),
		"段85c 门槛唤起：凹痕=三代人的鞋底")
	ex85.teleport_to(Vector3(-3.6, 3.85, -7.0), true)   # 屋顶
	await physics_frame
	await physics_frame
	_check(bool(w40a.memory_fired[2]) and recalled.size() == 3
		and str(recalled[2]).contains("多少个黄昏"),
		"段85d 屋顶唤起：俯瞰的记忆")
	ex85.teleport_to(Vector3(0, 0.2, 10), true)   # 离开记忆点（站着不动会原地重新唤起）
	await physics_frame
	s40a.core.choose(0, 1)
	s40a.core.choose(1, 1)
	s40a.core.choose(2, 1)
	s40a.core.submit_chapter()   # 第 2 章（重建 → 记忆重置）
	await physics_frame
	_check(w40a.memory_fired == [false, false, false],
		"段85e 重建重置：新的一天可重新唤起（每章一次语义）")
	await _drop(s40a)
	# --- 段86：机制关卡 74「断线的风筝」——镇变体常驻挂树梢，21/31 风家族新成员
	# （wind_level 驱动摆角；悬念文本盲测安全）
	var s41a: Node3D = await _boot()
	var w41a: Node3D = s41a.get_node("ChapterWorld")
	s41a.core.choose(1, 2)   # 站变体
	await physics_frame
	_check(not _has_ins(w41a, "tree_kite"), "段86a 站变体：无风筝（门控负例）")
	s41a.core.choose(1, 1)   # 切镇变体（海边小镇）
	await physics_frame
	_check(_has_ins(w41a, "tree_kite") and w41a.get_node_or_null("VariantRoot/KiteTail") != null,
		"段86b 镇变体：风筝+尾穗挂树梢")
	var kf86: Node3D = w41a.get_node("VariantRoot/TreeKite")
	var r0: float = kf86.rotation.z
	_check(str(_ins_text(w41a, "tree_kite")).contains("放它的人不知道去了哪"),
		"段86c 风筝文本：悬念句（盲测安全）")
	w41a.wind_cycle()
	w41a.wind_apply_level()
	_check(absf(kf86.rotation.z - (r0 + 0.15)) < 0.01,
		"段86d 风档 1：风筝摆角 +0.15（家族联动）")
	w41a.wind_cycle()
	w41a.wind_apply_level()
	_check(absf(kf86.rotation.z - (r0 + 0.30)) < 0.01,
		"段86e 风档 2：摆角 +0.30（三档递进）")
	s41a.core.choose(2, 1)   # 家书 warm+1（w 维 0→1 翻转重建；slot0 记者无基调不翻键）
	await physics_frame
	var kf86b: Node3D = w41a.get_node("VariantRoot/TreeKite")
	_check(absf(kf86b.rotation.z - PI / 4) < 0.01,
		"段86f 重建复位：风档归零摆角回正（瞬态家族语义）")
	await _drop(s41a)
	# --- 段87：机制关卡 75「舷窗外的蓝点」——站×解释落定的认知门控：同一光点两种世界观
	# （colony=地球「你认得」/ mine=矿灯「这个时辰不该亮」；纯视觉不泄底）
	var s42a: Node3D = await _boot()
	var w42a: Node3D = s42a.get_node("ChapterWorld")
	s42a.core.choose(0, 2)   # 宇航员
	s42a.core.choose(1, 2)   # 站
	s42a.core.choose(2, 2)   # 星图 sci+1（34 星门控 sci>=1）
	s42a.core.submit_chapter()
	s42a.core.choose(0, 2)   # 旧日志 sci+1
	s42a.core.choose(1, 0)   # 黄铜钥匙（宇航员派生 sci）——此时 secret 未定
	s42a.core.choose(2, 0)
	await physics_frame
	_check(not bool(s42a.bridge.build_spec().sky_blue_dot) and w42a.get_node_or_null("VariantRoot/SkyBlueDot") == null,
		"段87a 解释未落定：无蓝点（认知门控负例）")
	s42a.core.submit_chapter()   # 第 3 章
	s42a.core.choose(0, 0); s42a.core.choose(1, 2); s42a.core.choose(2, 0); s42a.core.choose(3, 0)
	s42a.core.submit_chapter()   # 第 4 章
	s42a.core.choose(0, 3)   # 第 4 章槽 0 选项 3：「殖民飞船」colony_ship（secret 落定 → k 维翻转）
	await physics_frame
	_check(bool(s42a.bridge.build_spec().sky_blue_dot)
		and w42a.get_node_or_null("VariantRoot/SkyBlueDot") != null,
		"段87b colony 落定：蓝点在场（认知解锁）")
	_check(str(_ins_text(w42a, "porthole_star")).contains("你知道那是什么"),
		"段87c colony 星文本：你知道那是什么（地球，盲测安全）")
	s42a.core.choose(0, 4)   # 换选槽 0 选项 4：「矿井防爆门」mine_door（对称回退 → 换世界观）
	await physics_frame
	_check(bool(s42a.bridge.build_spec().sky_blue_dot)
		and str(_ins_text(w42a, "porthole_star")).contains("矿早收工了"),
		"段87d 换 mine：蓝点仍在但文本换世界观（矿灯）")
	await _drop(s42a)
	# --- 段88：机制关卡 76「晨光进屋」——第 5 章（ending_dom 键控）窗下暖金光斑，
	# 61 窗色金黄的室内印证（光的家族收官：37 灯/60 火/61 天光/76 晨光）
	var s43a: Node3D = await _boot()
	var w43a: Node3D = s43a.get_node("ChapterWorld")
	_check(w43a.get_node_or_null("VariantRoot/MorningPatch") == null,
		"段88a 第 1 章：无晨光斑（门控负例）")
	# 复用段73 温情流程到第 5 章（避开悬疑词）
	s43a.core.choose(0, 1); s43a.core.choose(1, 1); s43a.core.choose(2, 1)
	s43a.core.submit_chapter()
	s43a.core.choose(0, 1); s43a.core.choose(1, 1); s43a.core.choose(2, 0)
	s43a.core.submit_chapter()   # 第 3 章
	await physics_frame
	_check(w43a.get_node_or_null("VariantRoot/MorningPatch") == null,
		"段88b 第 3 章：仍无晨光斑（back_open 已翻但 end_dom 空——负例二）")
	s43a.core.choose(0, 1); s43a.core.choose(1, 1); s43a.core.choose(2, 1); s43a.core.choose(3, 0)
	s43a.core.submit_chapter()   # 第 4 章（槽 3 选 0=饭菜香 w+1，避悬疑——susp 满 2 会触发 61 黑窗反转）
	s43a.core.choose(0, 1); s43a.core.choose(1, 1); s43a.core.choose(2, 1); s43a.core.choose(3, 1); s43a.core.choose(4, 1)
	s43a.core.submit_chapter()   # 进入第 5 章（不交第 5 章稿——避免出版结算，state 保持 play）
	await physics_frame
	var mp88: MeshInstance3D = w43a.get_node_or_null("VariantRoot/MorningPatch")
	_check(mp88 != null and absf(mp88.rotation.y - 0.18) < 0.01,
		"段88c 第 5 章：晨光斑在场+斜置角（与窗对位）")
	var win88: StandardMaterial3D = (w43a.get_node("VariantRoot/Window") as MeshInstance3D).material_override as StandardMaterial3D
	_check(win88.albedo_color.is_equal_approx(Color(0.8, 0.66, 0.42)) and w43a.get_node_or_null("VariantRoot/MorningSill") != null,
		"段88d 同章联动：窗色金黄+窗台暖光小片（61×76 同键控）")
	await _drop(s43a)
	# --- 段55：机制关卡 43「旧收音机」——镇变体×悬疑满档专属，E 开关杂音（dom 三分化） ---
	var s10a: Node3D = await _boot()
	var w10a: Node3D = s10a.get_node("ChapterWorld")
	s10a.core.choose(0, 1)   # 记者
	s10a.core.choose(1, 1)   # 海边小镇 warm+1
	s10a.core.choose(2, 3)   # 旧照片
	s10a.core.submit_chapter()   # 第 2 章
	s10a.core.choose(0, 0)   # 重读卷宗 susp+1
	s10a.core.choose(1, 2)   # 未寄出的手稿（记者派生 susp+1）→ 悬疑 2
	s10a.core.choose(2, 0)   # 撤稿 susp+1 → 悬疑 3
	await physics_frame
	_check(not _has_ins(w10a, "radio"), "段55a 悬疑 1 时无收音机（历史态已过，现满档应在场）") if false else null
	_check(_has_ins(w10a, "radio") and w10a.get_node_or_null("VariantRoot/RadioBody") != null
		and w10a.get_node_or_null("VariantRoot/RadioLamp") != null, "段55a 悬疑满档：五斗柜+收音机+指示灯在场")
	var r1: bool = w10a.radio_toggle()
	await physics_frame
	var lamp: MeshInstance3D = w10a.get_node("VariantRoot/RadioLamp")
	_check(r1 and w10a.radio_on and lamp.visible
		and s10a.bridge.radio_text(true, "sci").contains("电码"), "段55b E 开：指示灯亮，杂音文本（sci=电码）")
	var r2: bool = w10a.radio_toggle()
	await physics_frame
	_check(not r2 and not w10a.radio_on and not lamp.visible
		and s10a.bridge.radio_text(false, "").contains("杂音停了"), "段55c E 关：指示灯灭，文本=杂音停了")
	_check(s10a.bridge.radio_text(true, "warm").contains("哼歌的调子")
		and s10a.bridge.radio_text(true, "susp").contains("呼吸"), "段55d dom 三分化文本（warm=哼歌/susp=呼吸）")
	await _drop(s10a)
	var s10b: Node3D = await _boot()
	s10b.core.choose(0, 2)   # 宇航员
	s10b.core.choose(1, 2)   # 空间站
	s10b.core.choose(2, 3)
	s10b.core.submit_chapter()   # 第 2 章
	s10b.core.choose(0, 0)   # 卷宗 susp+1
	s10b.core.choose(1, 0)
	s10b.core.choose(2, 0)
	s10b.core.submit_chapter()   # 第 3 章（站变体悬疑 1）
	await physics_frame
	_check(s10b.core.stats.susp >= 1 and not _has_ins(s10b.get_node("ChapterWorld"), "radio"),
		"段55e 空间站对照：站变体无收音机（镇专属门控）")
	await _drop(s10b)

	# --- 段54：机制关卡 42「门前的脚印」——镇变体×悬疑≥1，密度随档（3/5 枚） ---
	var s9a: Node3D = await _boot()
	var w9a: Node3D = s9a.get_node("ChapterWorld")
	s9a.core.choose(0, 1)   # 记者
	s9a.core.choose(1, 1)   # 海边小镇 warm+1
	s9a.core.choose(2, 3)   # 旧照片 → susp 0
	await physics_frame
	_check(not _has_ins(w9a, "footprints"), "段54a 悬疑 0：无脚印（门控负例）")
	s9a.core.choose(0, 0)   # 重读案件卷宗 susp+1
	s9a.core.submit_chapter()   # 第 2 章（footprints 门控=第 2 章起）
	await physics_frame
	var fp1 := 0
	for cn9 in w9a.get_node("VariantRoot").get_children():
		if str(cn9.name).begins_with("Footprint"):
			fp1 += 1
	_check(_has_ins(w9a, "footprints") and fp1 == 3
		and str(_ins_text(w9a, "footprints")).contains("不是你的"), "段54b 悬疑 1：三枚脚印在场，文本=不是你的")
	s9a.core.choose(1, 2)   # 未寄出的手稿（记者派生 susp+1）→ 悬疑 2
	await physics_frame
	var fp2 := 0
	for cn9 in w9a.get_node("VariantRoot").get_children():
		if str(cn9.name).begins_with("Footprint"):
			fp2 += 1
	_check(fp2 == 5 and str(_ins_text(w9a, "footprints")).contains("不止一趟"), "段54c 悬疑 2：五枚脚印（密度随档），文本=不止一趟")
	await _drop(s9a)

	# --- 段53：机制关卡 41「檐下燕巢」——随章节三段渐进（新泥→巢环→雏鸟） ---
	var s8a: Node3D = await _boot()
	var w8a: Node3D = s8a.get_node("ChapterWorld")
	s8a.core.choose(0, 1)   # 记者
	s8a.core.choose(1, 0)   # 多雨南方小镇（非站，town 檐）
	s8a.core.choose(2, 3)   # 旧照片
	s8a.core.submit_chapter()   # 第 2 章（warm 0）
	await physics_frame
	_check(not _has_ins(w8a, "nest"), "段53a 温情 0：无巢（门控负例）")
	s8a.core.choose(0, 1)   # 老友 warm+1
	s8a.core.choose(1, 2)   # 未寄出的手稿（记者派生 susp，warm 保持 1）
	s8a.core.choose(2, 0)   # 撤稿 susp+1
	s8a.core.submit_chapter()   # 第 3 章
	await physics_frame
	_check(_has_ins(w8a, "nest") and w8a.get_node_or_null("VariantRoot/NestMud") != null
		and w8a.get_node_or_null("VariantRoot/NestRing") != null, "段53b 第 3 章：新泥+巢环累积在场")
	_check(str(_ins_text(w8a, "nest")).contains("巢筑好了"), "段53c stage2 文本=筑好了")
	s8a.core.choose(0, 1)   # 想回家 warm+1（暖 2，过第 3 章 tone_max≥2 门槛）
	s8a.core.choose(1, 0)
	s8a.core.choose(2, 0)
	s8a.core.choose(3, 0)
	s8a.core.submit_chapter()   # 第 4 章
	await physics_frame
	_check(w8a.get_node_or_null("VariantRoot/NestChick") != null
		and str(_ins_text(w8a, "nest")).contains("细的，嫩的"), "段53d 第 4 章：雏鸟在场，文本=有了声音")
	await _drop(s8a)

	# --- 段51：机制关卡 39「后院的猫」——温情门控常驻，E 摸猫 dom 三分化，账本入终稿清点 ---
	var s6a: Node3D = await _boot()
	var w6a: Node3D = s6a.get_node("ChapterWorld")
	s6a.core.choose(0, 1)   # 记者
	s6a.core.choose(1, 0)   # 多雨南方小镇（warm 0）
	s6a.core.choose(2, 3)   # 旧照片
	s6a.core.submit_chapter()
	s6a.core.choose(0, 2)
	s6a.core.choose(1, 2)   # 未寄出的手稿（记者派生 susp）→ 证物落定且 warm 保持 0
	s6a.core.choose(2, 0)
	s6a.core.submit_chapter()   # 第 3 章：温情 0
	await physics_frame
	_check(not _has_ins(w6a, "yard_cat"), "段51a 温情 0：猫不出现（门控负例）")
	s6a.core.choose(0, 1)   # 老友 warm+1
	await physics_frame
	_check(_has_ins(w6a, "yard_cat") and w6a.get_node_or_null("VariantRoot/CatBody") != null
		and w6a.is_position_safe(Vector3(-4.5, 0.2, -15.0)) == false, "段51b 温情+1：猫常驻（实体占位=不可穿）")
	var pet1: bool = s6a.bridge.cat_pet()
	var pet2: bool = s6a.bridge.cat_pet()
	_check(pet1 and not pet2 and s6a.bridge.cat_text("sci").contains("天线尖")
		and s6a.bridge.cat_text("warm").contains("呼噜")
		and s6a.bridge.cat_text("susp").contains("认出了你"), "段51c 摸猫账本一次性 + dom 三分化文本")
	s6a.core.choose(0, 1)
	s6a.core.choose(1, 1)
	s6a.core.choose(2, 1)
	s6a.core.choose(3, 0)
	s6a.core.submit_chapter()
	s6a.core.choose(0, 1)
	s6a.core.choose(1, 1)
	s6a.core.choose(2, 2)
	s6a.core.choose(3, 1)
	s6a.core.submit_chapter()   # 第 5 章
	await physics_frame
	_check(str(_ins_text(w6a, "ending_spot")).contains("卧垫"), "段51d 终稿清点：猫的回声（稿纸当卧垫）")
	await _drop(s6a)

	_log("==========================================")
	_log("PASS %d / FAIL %d" % [passes, fails])
	if fails > 0:
		quit(1)
	else:
		quit(0)


func _spec_back_open(s: Node3D) -> bool:
	var spec: Dictionary = s.bridge.build_spec()
	return bool(spec.back_open)
