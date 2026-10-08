extends Node
## DEMO10 3D 阶段 B：WorldBridge——把纯规则核心（story_core.gd）投影为 WorldSpec。
## 职责（指南第 5 节）：状态映射、对象 ID、版本、验证；不渲染、不持引用网格。
## UI 与世界读取同一份 spec；禁止任何一方绕过它改核心状态。
## 盲测安全：这里产出的检查文本只描述「世界当前事实」，不含基调数值、
## 派生义标注、可圆回提示或「哪个选项正确」的暗示。
##
## 表现层记忆 chapter_picks：核心交稿后词槽即重建，历史选择只剩旗标；
## 世界表现（第 2 章夜记、第 3 章三份记录等）需要「当时选了什么」，故在每次
## 状态变化时按章记录当前 chosen。这是表现保存，不进规则、不影响任何判定。

## 集齐三处刻痕时发出（根脚本接后重走 WorldSpec 事务，屋顶浮现回响字条）
signal marks_completed

var core: RefCounted            # story_core.gd 实例（根脚本注入）
var version := 0                # 每次生成 spec +1；旧异步任务完成时校验，过期即丢弃
var chapter_picks := {}         # 表现层记忆：chapter_idx → [chosen...]（-1=未选）
var inspected_once := {}        # 表现层记忆：已首次检查过的对象 id（机制关卡 5：初见观察）
var collected_marks := {}       # 表现层记忆：已检查过的刻痕 id（机制关卡 12：三处刻痕收集）
var telescope_aim := 0          # 表现层状态：望远镜指向档位 0=目镜 1=月亮 2=后山（机制关卡 20）
var read_notes := {}            # 表现层记忆：已读的回响字条 id（机制关卡 13：字条递进链）
var mail_sent := false          # 表现层记忆：回执字条已投（机制关卡 29：跨章存活，重建不灭）
var picture_straight := false   # 表现层记忆：挂画已摆正（机制关卡 52：跨章存活）
var crate_slid := false         # 表现层记忆：木箱已推开（机制关卡 62：跨章存活）
var floorboard_open := false    # 表现层记忆：地板已掀开（机制关卡 66：跨章存活）
var evidence_pinned := false    # 表现层记忆：证物已描摹钉板（机制关卡 67：跨章存活）
var letter_stage := 0           # 表现层记忆：回信档位 0=未写 1-3=已写（机制关卡 69：跨章存活）
var line_hung_prop := ""        # 表现层记忆：晾在绳上的道具（机制关卡 30：跨章变干；空=没收着）
var line_hung_chapter := -1     # 表现层记忆：挂上时的章节（与当前章比较判定「晾了一夜」）
var relic_stored := false       # 表现层记忆：桶中旧物已收进证物匣（机制关卡 32：跨章存活）
var relic_dom := ""             # 表现层记忆：收进时记录的旧物来历（主基调，匣文本引用）
var drawer_opened := false      # 表现层记忆：桌子抽屉已拉开（机制关卡 35：跨章开态）
var well_wished := false        # 表现层记忆：已向井里投过硬币（机制关卡 36：跨章存活）
var stash_opened := false       # 表现层记忆：阁楼木箱已掀盖（机制关卡 38：跨章开态）
var cat_petted := false         # 表现层记忆：摸过后院的猫（机制关卡 39：跨章存活）
var porthole_wiped := false   # 表现层记忆：舷窗霜已擦净（机制关卡 44：跨章存活）
var plant_watered := false     # 表现层记忆：绿植已浇水（机制关卡 45：跨章存活）
var drawer_matched := false    # 表现层记忆：抽屉那张纸已对位收进证物匣（机制关卡 46：跨章存活）
var cistern_filled := false    # 表现层记忆：缸里被倒过桶水（机制关卡 48：跨章存活）
var chair_sitted := false       # 表现层记忆：在桌边的椅子上坐过（机制关卡 40：跨章存活）

## 三处刻痕 id（井沿/窗台/天线底座；在场条件各异，收集按检查记入）
const MARK_IDS := ["well_mark", "sill_mark", "antenna_mark"]


## 机制关卡 12：刻痕检查记入收集账本；集齐三枚时 bump 触发事务，屋顶浮现回响字条
func mark_inspected(id: String) -> void:
	if MARK_IDS.has(id) and not collected_marks.has(id):
		collected_marks[id] = true
		if collected_marks.size() >= MARK_IDS.size():
			marks_completed.emit()


## 机制关卡 13：回响字条已读记入（返回是否有变化；root 据此重走事务）
func mark_note_read(id: String) -> bool:
	if read_notes.has(id):
		return false
	read_notes[id] = true
	version += 1
	return true


## 机制关卡 5：某对象首次检查时追加的「初见观察」行（固定文案，无机制信息，盲测安全）
func first_look(id: String) -> String:
	match id:
		"mail_slot":
			return "你第一次凑近它——信封上的邮戳已经模糊了。"
		"door_front":
			return "你第一次凑近它——门轴发出轻微的吱声。"
		"prop_item":
			return "你第一次把它拿起来又放下，指尖留了一点凉。"
		"desk_letter":
			return "你第一次凑近它——纸张边缘有反复摩挲的毛边。"
		"window_look":
			return "你第一次凑近它——玻璃上留着一道旧雨痕。"
		"night_record":
			return "你第一次翻看它——某一页的折角比其他的更深。"
		"record_1", "record_2", "record_3":
			return "你第一次展平这页纸——墨迹下还压着一层更淡的字。"
		"note_paper":
			return "你第一次翻过它——背面是一行被划掉的草稿。"
		"airlock_door":
			return "你第一次贴耳去听——门后没有一点声音。"
		"evidence_box":
			return "你第一次打开它——合页上了油，最近有人动过。"
		"ship_proof", "mine_proof":
			return "你第一次细读它——落款的墨色比正文新。"
		"secret_tail":
			return "你第一次走近它——那里的空气要更凉一些。"
		"ending_spot":
			return "你第一次站定在这里——像回到了故事开始之前。"
		"roof_look":
			return "你第一次登上高处——风把衣角吹得贴在腿上。"
	return ""


func bind(c: RefCounted) -> void:
	core = c
	core.state_changed.connect(_record_picks)


func _record_picks(_cmd: int) -> void:
	var picks := []
	for sl in core.slots:
		picks.append(int(sl.chosen))
	chapter_picks[int(core.chapter_idx)] = picks


## 取第 chapter 章 slot 号词槽的选择：进行中章读实时，历史章读表现记忆
func _pick(chapter: int, slot: int) -> int:
	if int(core.chapter_idx) == chapter:
		if slot < core.slots.size():
			return int(core.slots[slot].chosen)
		return -1
	var arr: Array = chapter_picks.get(chapter, [])
	if slot < arr.size():
		return int(arr[slot])
	return -1


## 主基调（与核心 _ending_text 同一判定次序；只读，供世界布置终稿落点）
func dominant_tone() -> String:
	var sci := int(core.stats.sci)
	var warm := int(core.stats.warm)
	var susp := int(core.stats.susp)
	if warm > sci and warm >= susp:
		return "warm"
	if susp > sci and susp > warm:
		return "susp"
	return "sci"


## 由核心当前状态生成完整 WorldSpec（纯函数式：不产生副作用）
func build_spec() -> Dictionary:
	version += 1
	var place: String = str(core.flags.get("place", ""))
	var role: String = str(core.flags.get("role", ""))
	var prop: String = str(core.flags.get("prop", ""))
	var chapter := int(core.chapter_idx)
	var secret := str(core.flags.get("secret", ""))
	var evidence := str(core.flags.get("evidence", ""))
	var spec := {
		version = version,
		command_seq = int(core.command_seq),
		chapter_idx = chapter,
		state = str(core.state),
		place = place,
		role = role,
		prop = prop,
		secret = secret,
		evidence = evidence,
		## 井台进化档位（机制关卡 2：世界读悬疑基调；0=盖板封井 1=揭盖暗水 2=雾光）
		susp_tier = clampi(int(core.stats.susp), 0, 2),
		## 灌木开花档位（机制关卡 6：世界读温情基调；0=绿叶 1=点缀小花 2=花盛微光）
		warm_tier = clampi(int(core.stats.warm), 0, 2),
		## 旧天线复苏档位（机制关卡 7：世界读科幻基调；0=静默旧物 1=尖端微光 2=蓝光晕）
		sci_tier = clampi(int(core.stats.sci), 0, 2),
		## 组合观察（机制关卡 8）：第 3 章后院井台在场 且 证物落定 且 悬疑≥1（井已揭盖）
		## → 井面浮现「井底的回光」；章节门槛保证文本与世界节点同生同灭
		combo_well = evidence != "" and int(core.stats.susp) >= 1 and chapter >= 2,
		## 三处刻痕在场条件（机制关卡 12）：井沿=揭盖后 / 窗台=温情×证物 / 天线底座=科幻≥1
		marks = {
			well = chapter >= 2 and int(core.stats.susp) >= 1,
			sill = evidence != "" and int(core.stats.warm) >= 1 and chapter >= 1,
			antenna = int(core.stats.sci) >= 1,
		},
		echo_note = collected_marks.size() >= MARK_IDS.size(),
		## 字条递进链（机制关卡 13）：回响字条已读 → 证物间浮现字条二；字条二已读且科幻≥2 → 天线底座字条三
		note2 = collected_marks.size() >= MARK_IDS.size() and inspected_once.has("echo_note") and evidence != "",
		note3 = read_notes.has("note2") and int(core.stats.sci) >= 2,
		## 字条四（机制关卡 15）：观星台在场（=combo_antenna）且 字条三已读 → 三脚架抽屉收束全系列
		note4 = str(core.flags.get("prop", "")) == "星图" and int(core.stats.sci) >= 2 and read_notes.has("note3"),
		## 镜片擦净（机制关卡 17）：字条四读毕 → 霜膜消失、镜片透亮
		frost_cleared = read_notes.has("note4"),
		## 字条五（机制关卡 26）：温情满档收束——字条四读毕 且 温情≥2 → 晾衣绳木夹下第五张字条
		note5 = read_notes.has("note4") and int(core.stats.warm) >= 2,
		## 穿过气闸（机制关卡 18）：秘密落定 → 气闸门开，可达围栏外气闸室
		airlock_room = secret != "",
		## 气闸室的井水（机制关卡 19）：秘密 × 井台揭盖 × 温情≥1 × 证物落定 → 气闸室角落浮现井水
		airlock_water = secret != "" and evidence != "" and int(core.stats.warm) >= 1 and int(core.stats.susp) >= 1,
		## 井口的辘轳（机制关卡 22）：第 3 章后院可达 且 井台揭盖 → 井架西侧立辘轳（E 摇三段拉桶）
		well_winch = chapter >= 2 and int(core.stats.susp) >= 1,
		## 主基调快照（机制关卡 22 桶中旧物外观用；世界侧不读核心，只在 apply 时快照）
		mood_dom = dominant_tone(),
		## 后院的晾衣绳（机制关卡 23）：第 3 章后院可达 且 温情≥1 → 两杆间拉起晾衣绳（E 挂/收道具）
		clothes_line = chapter >= 2 and int(core.stats.warm) >= 1,
		## 屋顶水箱与管线（机制关卡 25）：科幻≥1（天线已复苏）→ 屋顶立水箱、后院落水缸（档位驱动水位）
		sci_tank = int(core.stats.sci) >= 1,
		## 改写留下的实物（机制关卡 28）：第 2 章 echo 槽写入 flag_case → 档案架出现对应实物
		## （值=旧卷宗/被撤的报道/被改的日志/匿名卷宗；改写变化经重建键 k 维同步）
		case_mark = str(core.flags.get("case", "")),
		## 舷窗外的星（机制关卡 34）：空间站变体专属 × 科幻≥1 → 舷窗会闪的星（档位=闪烁急缓）
		porthole_star = place == "空间站" and int(core.stats.sci) >= 1,
		## 门前的脚印（机制关卡 42）：小镇变体 × 第 2 章起 × 悬疑≥1 → 门前泥地脚印（密度随悬疑档）
		footprints = place != "空间站" and chapter >= 1 and int(core.stats.susp) >= 1,
		## 信号灯箱（机制关卡 53）：小镇变体 × 科幻满档 → 天线旁信号灯箱绿灯亮（对称件）
		signal_box = place != "空间站" and int(core.stats.sci) >= 3,
		## 旧收音机（机制关卡 43）：小镇变体 × 悬疑满档 → 室内五斗柜上多一台旧收音机（E 开关杂音）
		radio = place != "空间站" and int(core.stats.susp) >= 2,
		## 应急广播（机制关卡 47）：空间站 × 悬疑≥1 → 走廊西墙应急广播面板（E 开/听；内容随双解释分化）
		station_broadcast = place == "空间站" and int(core.stats.susp) >= 1,
		## 舱壁的字条（机制关卡 50）：空间站 × 悬疑满档 → 广播旁舱壁贴一张手写字条（对称件）
		wall_note_station = place == "空间站" and int(core.stats.susp) >= 2,
		## 壁炉的灰烬（机制关卡 55）：第 4 章起（chapter≥3）→ 室内壁炉灰烬检查点
		fireplace_ash = chapter >= 2,
		## 停摆的挂钟（机制关卡 56）：两变体常驻；指针随已键控维递进（back_open→走动 / ending_dom→对时）
		wall_clock = true,
		## 会响的地板（机制关卡 57）：两变体常驻；文本主基调三分化活派生，踩响态为 world 侧瞬态
		floor_board = true,
		## 门后的镜子（机制关卡 58）：两变体常驻；文本随身份（role）三分化+悬疑满档后缀，活派生
		wall_mirror = true,
		## 烟囱与炊烟（机制关卡 59）：第 3 章起（back_open 同维）——壁炉 55 的屋顶对应件；
		## 烟柱出现=任一基调满档，颜色随主基调（炊烟白/青灰/淡蓝），w/s 维既有键控
		roof_chimney = chapter >= 2,
		## 收件槽的应答器（机制关卡 54）：空间站 × 科幻中档 → 收件槽旁小型应答器（LED 自动发射）
		transponder = place == "空间站" and int(core.stats.sci) >= 2,
		## 舷窗的霜（机制关卡 44）：空间站 × 科幻满档 → 舷窗结霜（霜板覆星窗；E 擦净跨章保持）
		porthole_frost = place == "空间站" and int(core.stats.sci) >= 3,
		## 收件槽的绿植（机制关卡 45）：空间站 × 温情≥1 → 收件槽旁小盆栽（温情档=开花；E 浇水）
		station_plant = place == "空间站" and int(core.stats.warm) >= 1,
		plant_watered = plant_watered and place == "空间站" and int(core.stats.warm) >= 1,
		porthole_wiped = porthole_wiped and place == "空间站" and int(core.stats.sci) >= 3,
		## 缸水的记忆（机制关卡 48）：倒过桶水的缸跨章保持满水位（账本×科幻线水缸在场）
		cistern_filled = cistern_filled and int(core.stats.sci) >= 1,
		## 桌子的抽屉（机制关卡 35）：E 拉开（bridge 跨章开态）→ 抽屉盒拉出（键维 x）
		drawer_open = drawer_opened,
		## 信箱的小旗（机制关卡 51）：投过回执 → 信箱旁小旗立起（29 投递的视觉闭环）
		mail_flag_up = mail_sent,
		## 墙上的挂画（机制关卡 52）：E 摆正后保持正位（键维 n）
		picture_straight = picture_straight,
		## 墙角的木箱堆（机制关卡 62）：E 推开顶层箱露出墙裙刻痕（遮挡揭示；账本跨章保持）
		crate_slid = crate_slid,
		## 休眠舱的呼吸灯（机制关卡 63）：站变体室内常驻；呼吸灯 emission 随时间 sin 驱动
		sleep_pod = place == "空间站",
		## 檐下的雨（机制关卡 64）：镇变体常驻；雨势三档随悬疑轴（s%d）——雨歇/小雨/暴雨
		eaves_rain = place != "空间站",
		## 夜里的叩门声（机制关卡 65）：镇×悬疑满档×有证物三条件——暴雨夜的三下敲门（可逆）
		door_knock = place != "空间站" and evidence != "" and int(core.stats.susp) >= 2,
		## 松动的地板下面（机制关卡 66）：E 掀开咯吱板（57）——板下浅洞+铁盒（账本跨章）
		floorboard_open = floorboard_open,
		## 墙上的软木板（机制关卡 67）：E 描摹证物钉板（与 46 收进互补的外向展示，账本跨章）
		evidence_pinned = evidence_pinned,
		## 窗台的回信（机制关卡 69）：E 循环三档语气，账本记最终档（与词槽改写同构，跨章）
		letter_stage = letter_stage,
		## 断线的风筝（机制关卡 74）：镇变体常驻；摆角随风档（21/31 家族新成员，瞬态驱动）
		tree_kite = place != "空间站",
		## 舷窗外的蓝点（机制关卡 75）：站×解释落定——同一光点的两种世界观（认知门控）
		sky_blue_dot = place == "空间站" and secret != "",
		## 檐下燕巢（机制关卡 41）：非空间站 且 第 2 章起 且 温情≥1 → 檐下燕巢随章节三段渐进
		nest = place != "空间站" and chapter >= 1 and int(core.stats.warm) >= 1,
		nest_stage = clampi(chapter, 1, 3),   # 第2章=1 新泥 / 第3章=2 巢环 / 第4章起=3 雏鸟
		## 井里的回应（机制关卡 36）：第 3 章后院 且 井台揭盖 → 井沿检查点（E 投币）；
		## 投过硬币经 bridge 账本（键维 h）驱动水面硬币 mesh
		well_wish_spot = chapter >= 2 and int(core.stats.susp) >= 1,
		well_wished = well_wished,
		stash_open = stash_opened,   # 机制关卡 38：木箱掀盖（键维 g）
		yard_cat = chapter >= 2 and int(core.stats.warm) >= 1,   # 机制关卡 39：后院的猫（温情 tier 键覆盖）
		## 晾干的故事（机制关卡 30）：道具挂上绳跨过一章 → 下一章布片变干仍在绳上
		## （bridge 跨章账本；收下即清账；进重建键 d 维）
		line_dried = line_hung_prop != "" and chapter > line_hung_chapter and int(core.stats.warm) >= 1 and chapter >= 2,
		line_dried_prop = line_hung_prop,
		## 屋脊风铃（机制关卡 21）：三处刻痕集齐 → 屋脊显形风铃（E 循环三档风）
		wind_chime = collected_marks.size() >= MARK_IDS.size(),
		## 风档联动主基调（机制关卡 21 文本用）：dominant_tone 传入 wind_chime_text
		wind_dom = dominant_tone(),
		## 组合观察（机制关卡 9）：科幻≥2（天线已复苏）且 道具=星图 → 天线校准到星图坐标
		combo_antenna = str(core.flags.get("prop", "")) == "星图" and int(core.stats.sci) >= 2,
		## 组合观察（机制关卡 10）：温情≥1 且 证物落定 且 第 2 章起 → 窗台浮现一份摆好的碗筷
		combo_table = evidence != "" and int(core.stats.warm) >= 1 and chapter >= 1,
		## 证物联动暗室（支线机制）：第 2 章派生证物落定后，室内东墙开启暗门通往证物间；
		## 重置本章（证物回滚）则重新封死——世界把选择物理化，不碰规则核心
		has_anomaly = not (core.anomalies as Array).is_empty(),
		## 气闸实物门是否在场（进入重建键：写入气闸的瞬间必须触发重建）
		has_airlock = false,   # 由下方赋值
		## 地点变体：未选地点（正文仍是「老家」）时用默认小镇样貌
		variant = "station" if place == "空间站" else "town",
		## 后山通道：第 3 章（chapter_idx>=2）起打开
		back_open = chapter >= 2,
		## 终稿落点：第 5 章进入时按主基调布置（""=未到第 5 章）
		ending_dom = dominant_tone() if chapter >= 4 else "",
		## 安全锚点：id/位置/朝向；迁移时按列表顺序取第一个安全者
		## （选址避开走廊肋环 z≈13.6 与桌体 z∈[-9.4,-8.6]）
		anchors = [
			{id = "street_spawn", pos = Vector3(0, 0.2, 15.2), yaw = 0.0},
			{id = "interior_desk", pos = Vector3(0, 0.2, -7.5), yaw = 0.0},
			{id = "door_front_outside", pos = Vector3(0, 0.2, -3.2), yaw = 0.0},
			{id = "back_zone", pos = Vector3(0, 0.2, -15.5), yaw = 0.0},
			{id = "chamber", pos = Vector3(0, 0.2, -22.5), yaw = 0.0},
			{id = "evidence_room", pos = Vector3(8.0, 0.2, -6.5), yaw = 0.0},
			{id = "yard_ladder_base", pos = Vector3(-7.5, 0.2, -9.0), yaw = 0.0},
			{id = "roof_top", pos = Vector3(-5.4, 3.95, -7.0), yaw = 0.0},
		],
		inspectables = _build_inspectables(place, role, prop, chapter, secret),
	}
	spec.has_airlock = (spec.inspectables as Array).any(func(ins: Dictionary) -> bool: return str(ins.id) == "airlock_door")
	if place == "空间站" and chapter >= 2:
		(spec.anchors as Array).append_array([
			{id = "station_roof_top", pos = Vector3(-2.4, 3.62, 10.5), yaw = 0.0},
			{id = "station_roof_base", pos = Vector3(-2.4, 0.2, 9.6), yaw = 0.0},
		])
	return spec


## 验证 spec：ID 齐备不重复、锚点可用。失败返回 false（根脚本保留旧版本）
func validate_spec(spec: Dictionary) -> bool:
	if int(spec.version) != version:
		return false
	var ids := []
	for ins in spec.inspectables:
		var id := str(ins.id)
		if ids.has(id):
			return false
		ids.append(id)
	for need in _expected_ids(spec):
		if not ids.has(need):
			return false
	if (spec.anchors as Array).is_empty():
		return false
	return true


func _expected_ids(spec: Dictionary) -> Array:
	var ids := ["mail_slot", "door_front", "prop_item", "desk_letter", "desk_drawer", "light_switch", "window_look", "roof_look"]
	var place := str(spec.place)
	var chapter := int(spec.chapter_idx)
	var secret := str(spec.secret)
	var evidence := str(spec.get("evidence", ""))
	var has_anomaly := bool(spec.has_anomaly)
	if chapter >= 1:
		ids.append("night_record")
	if chapter >= 2:
		ids.append_array(["record_1", "record_2", "record_3", "note_paper"])
		if has_anomaly or place == "空间站" or secret != "":
			ids.append("airlock_door")
	if secret == "colony_ship":
		ids.append_array(["ship_proof", "secret_tail"])
	elif secret == "mine_door":
		ids.append_array(["mine_proof", "secret_tail"])
	if evidence != "":
		ids.append("evidence_box")
		ids.append("attic_stash")   # 机制关卡 24：证物落定 → 老虎窗开启可进（与 builder 同门控）
	if combo_flag(spec, "combo_well"):
		ids.append("well_reflection")
	if combo_flag(spec, "combo_antenna"):
		ids.append("antenna_note")
		ids.append("telescope")
	if combo_flag(spec, "combo_table"):
		ids.append("window_setting")
	var marks: Dictionary = spec.get("marks", {})
	if bool(marks.get("well", false)):
		ids.append("well_mark")
	if bool(marks.get("sill", false)):
		ids.append("sill_mark")
	if bool(marks.get("antenna", false)):
		ids.append("antenna_mark")
	if bool(spec.get("echo_note", false)):
		ids.append("echo_note")
	if combo_flag(spec, "note2"):
		ids.append("note2")
	if combo_flag(spec, "note3"):
		ids.append("note3")
	if combo_flag(spec, "note4"):
		ids.append("note4")
	if combo_flag(spec, "note5"):
		ids.append("note5")   # 机制关卡 26：温情满档收束字条（与 builder/inspectables 同门控）
	if combo_flag(spec, "airlock_room"):
		ids.append("airlock_room")
	if combo_flag(spec, "airlock_water"):
		ids.append("airlock_water")
	if combo_flag(spec, "well_winch"):
		ids.append("well_winch")
	if combo_flag(spec, "well_wish_spot"):
		ids.append("well_wish_spot")   # 机制关卡 36：井里的回应（与 builder/inspectables 同门控）
	if combo_flag(spec, "yard_cat"):
		ids.append("yard_cat")   # 机制关卡 39：后院的猫（与 builder/inspectables 同门控）
	if combo_flag(spec, "nest"):
		ids.append("nest")   # 机制关卡 41：檐下燕巢（与 builder/inspectables 同门控）
	if combo_flag(spec, "clothes_line"):
		ids.append("clothes_line")
	if combo_flag(spec, "sci_tank"):
		ids.append_array(["roof_tank", "cistern"])   # 机制关卡 25：水箱（屋顶）+水缸（后院）成对在场
	if str(spec.get("case_mark", "")) != "":
		ids.append("case_mark")   # 机制关卡 28：改写留下的实物（与 builder/inspectables 同门控）
	if combo_flag(spec, "porthole_star"):
		ids.append("porthole_star")   # 机制关卡 34：空间站专属科幻线发现（与 builder/inspectables 同门控）
	if combo_flag(spec, "footprints"):
		ids.append("footprints")   # 机制关卡 42：门前的脚印（与 builder/inspectables 同门控）
	if combo_flag(spec, "signal_box"):
		ids.append("signal_box")   # 机制关卡 53：信号灯箱（与 builder/inspectables 同门控）
	if combo_flag(spec, "radio"):
		ids.append("radio")   # 机制关卡 43：旧收音机（与 builder/inspectables 同门控）
	if combo_flag(spec, "station_plant"):
		ids.append("station_plant")   # 机制关卡 45：收件槽的绿植（与 builder/inspectables 同门控）
	if combo_flag(spec, "station_broadcast"):
		ids.append("station_broadcast")   # 机制关卡 47：应急广播（与 builder/inspectables 同门控）
	ids.append("wall_picture")   # 机制关卡 52：墙上的挂画（常驻）
	ids.append("wall_clock")   # 机制关卡 56：停摆的挂钟（常驻，同 builder/inspectables 门控）
	ids.append("floor_board")   # 机制关卡 57：会响的地板（常驻，同 builder/inspectables 门控）
	ids.append("wall_mirror")   # 机制关卡 58：门后的镜子（常驻，同 builder/inspectables 门控）
	ids.append("crate_stack")   # 机制关卡 62：墙角的木箱堆（常驻，同 builder/inspectables 门控）
	if chapter >= 2:
		ids.append("roof_chimney")   # 机制关卡 59：烟囱与炊烟（第 3 章起与壁炉同步）
	if chapter >= 2:
		ids.append("fireplace_ash")   # 机制关卡 55：壁炉的灰烬（第 3 章起与后门同步）
	if combo_flag(spec, "wall_note_station"):
		ids.append("wall_note_station")   # 机制关卡 50：舱壁的字条（与 builder/inspectables 同门控）
	if combo_flag(spec, "transponder"):
		ids.append("transponder")   # 机制关卡 54：收件槽的应答器（与 builder/inspectables 同门控）
	if place == "空间站" and chapter >= 2:
		ids.append("roof_look_station")   # 机制关卡 49：舱顶通道（与 builder/inspectables 同门控）
	if place == "空间站":
		ids.append("sleep_pod")   # 机制关卡 63：休眠舱（站专属常驻，同 builder/inspectables 门控）
		## 机制关卡 75 的蓝点无独立检查点（纯视觉挂星旁），不入本校验列表——
		## 校验列表只收真实 inspectable；builder 门控读 spec.sky_blue_dot
	if place != "空间站":
		ids.append("eaves_rain")   # 机制关卡 64：檐下的雨（镇专属常驻，同 builder/inspectables 门控）
	if place != "空间站":
		ids.append("door_step")   # 机制关卡 65：门槛石（镇专属常驻，同 builder/inspectables 门控）
	if place != "空间站":
		ids.append("tree_kite")   # 机制关卡 74：断线的风筝（镇专属常驻，同 builder/inspectables 门控）
	if combo_flag(spec, "wind_chime"):
		ids.append("wind_chime")
	if chapter >= 4:
		ids.append("ending_spot")
	return ids


## combo 字段的空值安全读取
func combo_flag(spec: Dictionary, key: String) -> bool:
	return bool(spec.get(key, false))


## 机制关卡 20：望远镜校准——E 循环三档指向，指向与秘密真相一致时出现确认句（盲测安全：
## 确认只在指对后出现，不提示哪个方向对）
func telescope_cycle() -> int:
	telescope_aim = (telescope_aim + 1) % 3
	return telescope_aim

## 机制关卡 21：风铃文本——风档 × 主基调分化（盲测安全：纯氛围，无数值）
## 机制关卡 31：cloth_hung=布片在绳上且风起 → 追加一句（全局风联动，纯氛围）
func wind_chime_text(level: int, dom: String, cloth_hung: bool = false) -> String:
	var base := ""
	match level:
		0:
			base = "风铃静着，三根小管垂着不动。"
		1:
			base = "微风过铃，一声轻响，像谁在远处应了一声。"
		2:
			base = "风起，铃碎响成一片，把院子的安静敲开了。"
	if dom == "sci":
		base += "（铃声里带一点金属的凉。）"
	elif dom == "warm":
		base += "（铃声裹着一点灶火的暖。）"
	elif dom == "susp":
		base += "（铃声传出去，没有回音。）"
	if cloth_hung and level >= 1:
		base += "晾着的布片也被风掀了一下。"
	return base

## 机制关卡 22：辘轳文本——E 摇三段（1=放绳 2=水声 3=桶出井口），
## 桶底旧物随主基调分化（盲测安全：物件是「捞上来看到的事实」，不提示哪个基调正确）
func winch_text(stage: int, dom: String) -> String:
	var base := ""
	match stage:
		1:
			base = "你摇动辘轳，绳筒转过半圈，绳子往下放了半截——井里很深，还没到底。"
		2:
			base = "绳子忽然一沉。水声顺着井壁传上来，离井口近了。"
		3:
			base = "你把最后一圈摇上来——木桶出了井口，水面上……"
			if dom == "sci":
				base += "桶底躺着一枚防水的黄铜齿轮，齿口还很利，不像在井里泡过很多年。"
			elif dom == "warm":
				base += "桶底躺着一根系着红绳的小铃铛，绳结打得整整齐齐，像有人特意系好才放下去的。"
			elif dom == "susp":
				base += "桶底躺着一枚生锈的钥匙，锈得看不清齿——但柄上刻着一道短痕，和井沿的那道很像。"
	return base


## 机制关卡 23：晾衣绳文本——挂上/收回所选道具（已选事实的空间化，盲测安全：无基调数值、无解读提示）
func clothes_text(hung: bool, prop: String) -> String:
	if prop == "":
		return "几只木夹在风里轻轻晃着。绳子还空着。"
	if hung:
		return "你把「%s」夹上晾衣绳，用木夹固定——潮气总得有处可去。绳尾轻轻晃了一下，像是应了声。" % prop
	return "你把「%s」收回怀里。绳子上留下一道浅浅的夹痕，木夹还咬着那点布角的形状。" % prop


## 机制关卡 27：桶水去向文本——0=无缸（sci 线未接，桶先待着）/ 1=倒进缸（涟漪+水线）/ 2=已倒过
## （盲测安全：物证事实与动作反馈，无基调数值、无解读提示）
func bucket_pour_text(state: int) -> String:
	match state:
		0:
			return "桶里的井水映着天光——后院没有别的缸，它就先在桶里待着。"
		1:
			return "你把桶拎到水缸边，缓缓倒了进去——缸面晃开一圈涟漪，水线涨了一指。"
		_:
			return "桶已经空了，安安静静躺在缸边。"


## 机制关卡 29：信箱回执——E 把写了近况的字条投进信箱（一次性，跨章存活的表现层账本）。
## 返回是否本次新投（幂等）；第 5 章（chapter_idx≥4）且已投 → 信箱文本追加回信段（见 mail_slot 条目）。
func mail_send() -> bool:
	if mail_sent:
		return false
	mail_sent = true
	return true


## 机制关卡 32：物证的归宿——把桶中旧物收进证物匣（跨章账本；dom=收进时的主基调来历）。
## 匣文本按 relic_stored 追加一段；重复收（重摇出新桶）只保持一段不重复。
func relic_store(dom: String) -> void:
	relic_stored = true
	relic_dom = dom


## 机制关卡 36：井里的回应——E 投下一枚硬币（一次性，跨章账本）。
## 返回是否本次新投；投后水面硬币 mesh 经 spec h 维驱动（重建后仍在）。
func well_wish() -> bool:
	if well_wished:
		return false
	well_wished = true
	return true


## 机制关卡 36：投币文本——dom 三分化（盲测安全：水面的反应，无解读提示）
func well_wish_text(dom: String) -> String:
	match dom:
		"sci":
			return "硬币在水面上打了个转，沉下去了——水纹一圈圈散开，排得很整齐。"
		"warm":
			return "硬币在水面上打了个转，沉下去了——水花溅起来的声音很轻，像应了一声。"
		_:
			return "硬币在水面上打了个转，沉下去了——水面亮了一下就暗了，像有什么把它收走了。"


## 机制关卡 37：灯的开关文本——熄灯/开灯（两变体通用；纯氛围，盲测安全）
func light_text(off: bool) -> String:
	return "你熄了灯——灯灭的那一瞬间，窗外的光都进来了。" if off else "灯又亮了。"


## 机制关卡 43：收音机文本——开=杂音内容随主基调三分化 / 关=安静（盲测安全：纯氛围）
## 机制关卡 44：擦霜文本（一次性；盲测安全：纯视觉事实）
## 机制关卡 45：浇水——一次性（跨章账本；终稿清点引用）
## 机制关卡 46：锁纹对位——把抽屉里那张纸对折收进证物匣夹层（一次性；ev 为空=无匣不记账）。
func drawer_match(ev: String) -> bool:
	if drawer_matched or ev == "":
		return false
	drawer_matched = true
	return true


## 机制关卡 52：摆正挂画（一次性，跨章存活）
func straighten_picture() -> void:
	picture_straight = true


## 机制关卡 62：推开顶层木箱（一次性；跨章账本，幂等）
func crate_slide() -> void:
	crate_slid = true


## 机制关卡 66：掀开松动的地板（一次性；跨章账本，幂等——57 咯吱板的空间因果补完）
func floorboard_lift() -> void:
	floorboard_open = true


## 机制关卡 67：描摹证物钉上软木板（有证物才记账；一次性跨章，幂等）
func board_pin() -> bool:
	if str(core.flags.get("evidence", "")) == "":
		return false
	evidence_pinned = true
	return true


## 回敲门文本（机制关卡 71）：65 叩门的镜像——玩家回应世界的事件（第 24 种原型：事件回应）
func door_knock_back_text(active: bool, answered: bool) -> String:
	if active and not answered:
		return "你回敲了三下——这次，里面安静得像在听。"
	if active:
		return "你又敲了敲。这次什么都没有——刚才那一下，用完了。"
	return "你敲了敲门。没有人应——这屋里本来也只有你。"


## 守夜文本（机制关卡 70）：三瞬态涌现时的仪式句（盲测安全：等的是门响，不指认谁）
func vigil_text() -> String:
	return "你和衣坐着，守着这炉火——今晚不睡了，等门响。"


## 八音盒文本（机制关卡 68）：演奏中=进行句；上发条=听后感随主基调三分化；曲终=落闩句
func musicbox_text(playing: bool, done: bool, dom: String) -> String:
	if playing:
		return "摇柄转到一半——叮叮咚咚的音符还在走，像有人在小声数着什么。"
	if dom == "sci":
		return "发条上满了。音符一颗一颗落下来，间隔精确——像一段被写好的星历。"
	if dom == "warm":
		return "发条上满了。曲子很简单，翻来覆去只有几个音——正是哄人睡觉的那种。"
	return "发条上满了。曲子走着走着停在一个奇怪的地方——像是没写完，又像是故意的。"


## 回信三档（机制关卡 69）：玩家写作的实体化——写什么由你（元叙事）
const LETTER_LINES := ["", "我一切都好，勿念。", "你走后，井边的花倒又开了。", "那年冬天，你到底看见了什么？"]


## 机制关卡 69：E 循环回信档位（0→1→2→3→1；可逆改写，账本记最终档）
func letter_cycle() -> int:
	letter_stage = letter_stage % 3 + 1
	return letter_stage


## 回信文本（机制关卡 69）：未写=blank 句；已写=当前档+可逆提示（元叙事：改词槽的人也在改信）
func letter_text(stage: int) -> String:
	if stage <= 0:
		return "一张空白的稿纸压在窗台上——像是写给谁的回信，还没开头。"
	return "你在稿纸上写下：「" + str(LETTER_LINES[stage]) + "」。墨迹干了。不满意的话，可以再写。"


## 软木板文本（机制关卡 67）：空板/邀请/已钉三态；已钉句带证物轮廓（prop 派生）
func board_text(pinned: bool, prop: String) -> String:
	if pinned:
		var title := _prop_title(prop)
		return "描摹的证物钉在板中央——红线从「" + title + "」的轮廓连向一张空白的纸。下一步还没写。"
	if str(core.flags.get("evidence", "")) != "":
		return "软木板空着——你手里的证物，可以先描一份轮廓钉上去。"
	return "软木板空着，几枚图钉散在板角——像有人在等一张值得钉上去的东西。"


## 门槛石文本（机制关卡 65）：静=日常句；敲门激活=「三下敲门声，门外只有雨」（盲测安全）
func door_step_text(knock: bool) -> String:
	if knock:
		return "门槛石被踩得发亮。刚才雨声里混着三下敲门声——开门，门外只有雨。"
	return "门槛石被踩得发亮——进出门的人都走这里。"


## 檐水文本（机制关卡 64）：雨势三段随悬疑轴；满档=间隔完全相等的滴水（盲测安全）
func eaves_text(susp: int) -> String:
	if susp >= 2:
		return "暴雨砸在檐口，水帘一样往下灌。你数了数——滴水的间隔完全相等。太齐了，像谁在打拍子。"
	if susp >= 1:
		return "小雨。檐水连成了线，滴在石阶上，一声一声数得清。"
	return "雨停了，檐口的最后一滴水还没落下来——石阶上积着一小汪亮。"


## 休眠舱文本（机制关卡 63）：身份三分化；呼吸灯是时间驱动的程序循环动画（纯观察）
func pod_text(r: String) -> String:
	match r:
		"宇航员":
			return "舱盖内侧的名单上，你找到了自己的名字——编号还在，状态栏是空的。呼吸灯的节奏很稳。"
		"记者":
			return "呼吸灯一亮一暗，像有人在里面慢慢呼吸——可舱是空的，灯为谁亮着？"
		"侦探":
			return "呼吸灯的间隔完全相等——是机器在模仿呼吸，不是呼吸本身。"
		_:
			return "一台空置的休眠舱，呼吸灯一亮一暗，像在等一个名字。"


## 木箱堆文本（机制关卡 62）：未推=遮挡提示；已推=身高刻痕的身份三分化
func crate_text(r: String, slid: bool) -> String:
	if not slid:
		return "北墙墙角摞着几只木箱，最上面那只歪着——挡住了墙裙上的一小块。"
	match r:
		"侦探":
			return "墙裙上有一列矮矮的刻痕，一道比一道高——最后停在一米四。有人在量一个长高的孩子。"
		"记者":
			return "刻痕旁边有铅笔写的日期——每年同一个日子，字迹一年比一年潦草。"
		"宇航员":
			return "刻度是公制的，一米四整。这房子的人，用最普通的单位记了最重的事。"
		_:
			return "墙裙上有一列矮矮的刻痕，一道比一道高。像谁在很认真地记着什么。"


func plant_water() -> bool:
	if plant_watered:
		return false
	plant_watered = true
	return true


## 机制关卡 47：广播文本——播放内容随双解释分化（无秘密=音乐；盲测安全：广播内容是站内事实）
func broadcast_text(secret: String) -> String:
	if secret == "colony_ship":
		return "你按下播放——广播在循环播放登船流程：『请携带随身物品，按序登船。』声音平静得像在念天气。"
	if secret == "mine_door":
		return "你按下播放——广播在循环播放下井安全须知：『下井前请检查矿灯与瓦斯读数。』声音平静得像在念天气。"
	return "你按下播放——广播在放一段平静的音乐，中间插着失真的电流声，像谁隔着很远说了半句话。"


func frost_wipe_text() -> String:
	return "你用手掌在霜上蹭出一块干净的地方——外面的星星比你记得的多。"


func radio_text(on: bool, dom: String) -> String:
	if not on:
		return "收音机拧上了，杂音停了。"
	match dom:
		"sci":
			return "你拧开收音机——杂音里有极短的滴答，间隔完全相等，像一段没人听懂的电码。"
		"warm":
			return "你拧开收音机——杂音深处有一点哼歌的调子，走了音，但很耐心。"
		_:
			return "你拧开收音机——杂音里夹着一声很短的、像是从很远传来的呼吸。"


## 机制关卡 39：摸猫——记入账本（跨章存活；终稿清点引用），返回是否首次
func cat_pet() -> bool:
	if cat_petted:
		return false
	cat_petted = true
	return true


## 机制关卡 39：摸猫文本——dom 三分化（盲测安全：猫的反应是事实）
func cat_text(dom: String) -> String:
	match dom:
		"sci":
			return "猫盯着天线尖看了一会儿，才蹭了蹭你的手——像它也在核对什么。"
		"warm":
			return "猫在你手心里呼噜了很久，尾巴卷成一个圈。"
		_:
			return "猫的后背毛炸起来一瞬——然后认出了你，蹭了蹭你的手。"


## 壁炉点火/熄火文本（机制关卡 60）：点火=主基调三分化，熄火=统一短句
func fireplace_state_text(lit: bool, dom: String) -> String:
	if not lit:
		return "火熄了。灰烬还是那些灰烬。"
	match dom:
		"sci":
			return "火苗稳定地烧——热效率对得起这间屋子的体积。烟囱的烟变浓了。"
		"warm":
			return "火光把墙烤得发暖——屋子终于像有人住的样子。烟囱的烟变浓了。"
		_:
			return "火起来了。可你总觉得这火不为了取暖——像在给谁发信号。烟囱的烟变浓了。"


## 烟囱文本（机制关卡 59）：主基调三分化；与壁炉（55）灰烬文本同章呼应不泄底
func chimney_text(dom: String) -> String:
	match dom:
		"sci":
			return "烟囱内壁有高温气流过的痕迹——这炉子烧得很有效率，几乎没有浪费。"
		"warm":
			return "烟囱口飘着白汽——有人在里面生过火，煮过很软的东西。"
		_:
			return "烟囱在冒烟，可屋里没有火。烟是从别的什么地方来的。"


## 门后的镜子文本（机制关卡 58）：身份三分化+悬疑满档后缀；role 为空=还没看清自己
func mirror_text(r: String, susp: int) -> String:
	var t := ""
	match r:
		"侦探":
			t = "镜子里的那个人在打量你——像在核对一张旧照片。你移开视线，它没有。"
		"记者":
			t = "镜子里的人袖口沾着墨——你写下的那个记者，比你先学会了不睡觉。"
		"宇航员":
			t = "镜子里的人呼吸很稳，三秒一吸、五秒一呼——和训练手册一模一样。"
		_:
			t = "镜子里只有一间屋子的倒影——你还没看清自己。"
	if r != "" and susp >= 2:
		t += "（你数了数：镜子里只有你一个人。）"
	return t


## 松动的地板文本（机制关卡 66）：未掀=57 三分化句；已掀=浅洞铁盒身份三分化
## （宇航员=徽章编号同休眠舱名单——与 63 跨机制呼应）
func floorboard_text(dom: String, r: String, opened: bool) -> String:
	if not opened:
		return floor_board_text(dom)
	match r:
		"侦探":
			return "板掀开了——下面是一口浅洞，一只铁盒：一张烧掉一半的照片，剩下的半张上两个人的脸都还在。"
		"记者":
			return "板掀开了——下面是一口浅洞，一只铁盒：一叠信，每一封的开头都是同一句话，等你回来。"
		"宇航员":
			return "板掀开了——下面是一口浅洞，一只铁盒：一枚旧徽章，边缘的编号和休眠舱名单上的格式一样。"
		_:
			return "板掀开了——下面是一口浅洞，里面放着一只铁盒。盒盖上没有锁，像在等谁打开。"


## 会响的地板文本（机制关卡 57）：主基调三分化；踩响追加由 world 侧瞬态负责
func floor_board_text(dom: String) -> String:
	match dom:
		"sci":
			return "西走道有块地板颜色略深——木料收缩不均，踩上去会响。纯力学，没有别的。"
		"warm":
			return "西走道有块地板踩上去吱呀一声——这房子记得每一个走过的人。"
		_:
			return "西走道有块地板，每次只在你一个人走过去的时候响——刚才屋里明明只有你。"


## 挂钟文本（机制关卡 56）：随章节三段递进（停摆/走动/对时），悬疑≥2 追加后缀
## 章节阶段与 builder 键控驱动一致：idx≤1 停摆 / idx 2-3 走动 / idx≥4 对时
func clock_text(ch: int, susp: int) -> String:
	var t := ""
	if ch <= 1:
		t = "挂钟停在三点整，钟摆一动不动——像有人忘了它，或者它忘了自己。"
		if susp >= 2:
			t += "（你盯着看了很久才发现：钟摆还在极轻地晃。）"
	elif ch <= 3:
		t = "挂钟走起来了，滴答声在空屋里格外清楚——可没人记得是谁给它上的弦。"
		if susp >= 2:
			t += "（秒针每跳一下，你的心跳也跟着跳一下。）"
	else:
		t = "挂钟的指针和窗外的天色对上了——像是它一直在走，只是刚刚被发现。"
		if susp >= 2:
			t += "（钟摆每分钟摆六十次，和你此刻的呼吸一样稳。）"
	return t


func telescope_text(aim: int) -> String:
	var secret := str(core.flags.get("secret", ""))
	match aim:
		0:
			return "目镜里的视野：后院、井台、和远处镇子的灯——都是你写下来的地方。"
		1:
			if secret == "colony_ship":
				return "镜筒缓缓抬起，停在环月轨道的方向——星图上描过的坐标应答了：就是这里。"
			return "月亮在视场里安静地亮着。镜筒停了一会儿，没有等到应答。"
		2:
			if secret == "mine_door":
				return "镜筒压向后山的方向，停在矿井口的旧井架上——星图上描过的坐标应答了：就是这里。"
			return "后山黑黢黢的轮廓横在视场下沿。镜筒停了一会儿，没有等到应答。"
	return ""


func _build_inspectables(place: String, role: String, prop: String, chapter: int, secret: String) -> Array:
	var is_station := place == "空间站"
	var out := []
	# 信箱 / 收件槽：正文「信箱里出现了……」的现场对应物
	# 机制关卡 29：投过回执且进第 5 章 → 信箱里多一封回信（无寄件人，盲测安全：不揭示寄信者）
	var mail_text := "收件槽里躺着那封信——背面写着一行字：他还活着。" if is_station \
		else "信箱里躺着那封信，信封被雨打湿了。背面写着一行字：他还活着。"
	if mail_sent:
		mail_text += "\n投递口旁的小旗立了起来——像在说：这里有信待取。"
	if mail_sent and chapter >= 4:
		mail_text += "\n信箱深处还躺着一封回信，信封上没有寄件人，邮戳是温的：「都收到了。锅还温着，别急。」"
	out.append({
		id = "mail_slot",
		title = "居住舱收件槽" if is_station else "老屋的信箱",
		text = mail_text,
	})
	# 门：老屋门 / 舱门
	out.append({
		id = "door_front",
		title = "舱门" if is_station else "老屋的木门",
		text = "舱门密封条完好，指示灯稳定地亮着绿色。" if is_station
			else "门环上有雨的湿痕，门缝里透出一点旧木头的气味。",
	})
	# 道具物：未定稿=原稿「一张照片」；改写后=所选道具的现场对象。附身份观察一行。
	out.append({
		id = "prop_item",
		title = _prop_title(prop),
		text = _prop_text(place, role, prop),
	})
	# 桌上的信：室内正文事件区
	out.append({
		id = "desk_letter",
		title = "桌上的信",
		text = "信摊开着，字迹很急。落款处被撕掉了。",
	})
	## 机制关卡 35：桌子的抽屉——E 拉开（跨章开态），内容随所选道具（盲测安全：描述实物事实）
	var dd_text := "桌子侧面有一只抽屉，拉手磨得发亮。"
	if drawer_opened:
		dd_text = "抽屉拉开了。里面躺着"
		match prop:
			"古井":
				dd_text += "一张井栏的铅笔草图——画到一半，停了笔。"
			"信件":
				dd_text += "一只空信封，封口的胶还黏着——原稿似乎被谁取走过。"
			"星图":
				dd_text += "一页坐标草稿，数字被描过两遍——一遍深，一遍浅。"
			"旧照片":
				dd_text += "一只黑纸底片袋，袋口用铅笔写着：冲了，但没敢看。"
			_:
				dd_text += "几页空白的稿纸，边角卷了毛。"
	if drawer_matched:
		dd_text += "\n那张纸折好收进了证物匣的夹层——抽屉里只剩下空气和木屑的味道。"
	out.append({
		id = "desk_drawer",
		title = "桌子的抽屉",
		text = dd_text,
	})
	## 机制关卡 52：墙上的挂画——歪画 E 摆正（跨章开态）；文本两态
	if picture_straight:
		out.append({
			id = "wall_picture",
			title = "墙上的挂画",
			text = "挂画摆正了——画里的湖面平了，远处岸线也稳了。",
		})
	else:
		out.append({
			id = "wall_picture",
			title = "墙上的挂画",
			text = "墙上的挂画歪了——画里的湖面斜着，像要流出来。",
		})
	## 机制关卡 37：灯的开关——E 熄灯/开灯（两变体通用；熄灯后窗外的光更清楚）
	out.append({
		id = "light_switch",
		title = "墙上的开关" if is_station else "墙上的灯绳",
		text = "门边的触控面板亮着一枚小指示灯。" if is_station \
			else "门边垂着一根灯绳，拉手被摸得光滑。",
	})
	# 支路观察点：窗外；机制关卡 61：天光后缀随章节三段，悬疑满档反转（与窗色同源双轴）
	var win_text := ("舷窗外，环月轨道的阴影正缓缓移过，听不见任何声音。" if is_station
		else "窗外雨声不停，街上没有人，只有檐水滴在石阶上。")
	if int(core.stats.susp) >= 2:
		win_text += "你看了很久——天色不对，这个钟点，窗外不该是黑的。"
	elif chapter >= 4:
		win_text += "天亮透了，晨光落在窗台上。"
	elif chapter >= 2:
		win_text += "天色比昨天亮了一点。"
	out.append({
		id = "window_look",
		title = "舷窗" if is_station else "老屋的窗",
		text = win_text,
	})
	# 屋顶矮道（机制关卡 3：检修梯登顶后可达）
	out.append({
		id = "roof_look",
		title = "舱顶检修道" if is_station else "老屋的屋顶",
		text = "舱顶检修道的护栏很矮，脚下就是整个对接区——风从通风口的方向来。" if is_station
			else "屋顶上能望见整个后院，井沿的影子被夕阳拉得很长，风从北面来。",
	})
	if chapter >= 1:
		out.append(_night_record())
	if chapter >= 2:
		out.append({
			id = "record_1",
			title = "档案记录 · 一",
			text = _record_text(2, 0, "纸页受潮，字迹难辨"),
		})
		out.append({
			id = "record_2",
			title = "档案记录 · 二",
			text = _record_text(2, 1, "说法各有出入"),
		})
		out.append({
			id = "record_3",
			title = "档案记录 · 三",
			text = _record_text(2, 2, "「小心回来的人」"),
		})
		out.append({
			id = "note_paper",
			title = "压在最底下的字条",
			text = _note_text(),
		})
		## 气闸对象出现条件：小镇线挂了异常、空间站本来就正常存在、或已被解释
		var has_anomaly := not (core.anomalies as Array).is_empty()
		if has_anomaly or is_station or secret != "":
			out.append(_airlock_door(place, secret))
	if secret == "colony_ship":
		out.append({
			id = "ship_proof",
			title = "登船闸控制台",
			text = "控制台的航期表停在三年前——最后一行是：第一批登船者名单，确认。",
		})
		out.append({
			id = "secret_tail",
			title = "登船舱口",
			text = "舱口的加压灯是绿的——他说过，发射前所有灯都会变绿。",
		})
	elif secret == "mine_door":
		out.append({
			id = "mine_proof",
			title = "矿井停工记录",
			text = "记录间最底层的报告签着它的名字：停工，不是因为枯竭。",
		})
		out.append({
			id = "secret_tail",
			title = "记录间的里间",
			text = "里间还亮着一盏灯，桌上的茶杯是温的——像有人刚刚离开。",
		})
	if chapter >= 4:
		out.append(_ending_spot())
	var ev := str(core.flags.get("evidence", ""))
	if ev != "":
		out.append({
			id = "evidence_box",
			title = "证物匣",
			text = _evidence_box_text(ev, str(core.flags.get("prop", ""))),
		})
		## 机制关卡 24：老虎窗里的木箱——与 _expected_ids/builder 同门控（evidence 非空），
		## 文本只描述「同出一手」的物证事实，不提示解读方向（盲测安全）
		out.append({
			id = "attic_stash",
			title = "老虎窗里的木箱",
			text = "北坡老虎窗里蹲着一只旧木箱：箱底压着一张旧纸，字迹和「%s」同出一手——前后隔了许多年。窗缝漏下的光正好落在箱口，像有人常来坐。" % ev,
		})
		if stash_opened:
			out[out.size() - 1].text += "
箱盖已经掀开了——旧纸下面还压着一沓信，都是同一个人的字。"
	var deep := ev != "" and int(core.stats.warm) >= 1 and int(core.stats.susp) >= 1
	if ev != "" and int(core.stats.susp) >= 1:
		var wr_text := "井水深处浮着一点不肯熄灭的反光——形状和「%s」一模一样。你把它写进了证物，井就替你收着。" % ev
		if deep:
			wr_text += "井沿的石台上，不知谁放了一碗井水，还冒着热气。"
			if secret != "":
				wr_text += "而气闸室的角落，也多了一碗。"
		out.append({
			id = "well_reflection",
			title = "井底的回光",
			text = wr_text,
		})
	if str(core.flags.get("prop", "")) == "星图" and int(core.stats.sci) >= 2:
		var tel_text := ""
		match str(core.flags.get("secret", "")):
			"colony_ship":
				tel_text = "镜筒高高仰起，直指环月轨道——星图上描过的坐标就在那里，等待启程。"
			"mine_door":
				tel_text = "镜筒压得低低的，对着后山矿井的方向——星图上描过的坐标，原来落在地上。"
			_:
				tel_text = "自制三脚架上架着单筒望远镜，镜筒仰角对准的方向，正是星图上被描过的那组坐标——镜片上蒙着薄薄的霜，最近有人擦过。"
		if read_notes.has("note4"):
			tel_text += "镜片上的霜不知何时被擦净了——透过镜片看出去，连月亮都近了一点。"
		out.append({
			id = "telescope",
			title = "单筒望远镜",
			text = tel_text,
		})
		out.append({
			id = "antenna_note",
			title = "天线的指向",
			text = "三根横枝不再对着同一个方向——它们校准到了星图上被描过的那组坐标，尖端一下一下，朝着月亮的方向应答。",
		})
	# 机制关卡 12：三处刻痕（在场条件与 spec.marks 一致）+ 集齐后的回响字条
	if chapter >= 2 and int(core.stats.susp) >= 1:
		out.append({
			id = "well_mark",
			title = "井沿的刻痕",
			text = "井沿内侧刻着一道短痕，像是谁数到这里，就停了。",
		})
	if ev != "" and int(core.stats.warm) >= 1 and int(core.chapter_idx) >= 1:
		out.append({
			id = "sill_mark",
			title = "窗台的刻痕",
			text = "窗台边缘有一道浅浅的刻痕，和井沿那道如出一辙。",
		})
	if int(core.stats.sci) >= 1:
		out.append({
			id = "antenna_mark",
			title = "底座的刻痕",
			text = "天线底座刻着第三道短痕——三道痕的走向，连成了一个字。",
		})
	if collected_marks.size() >= MARK_IDS.size():
		var en_text := "字条压在天线底座下，字迹很轻：「井记得水，窗记得人，天线记得月亮。三条刻痕连起来，是一个名字的三个偏旁。」——落款只有两个字：他还活着。"
		if read_notes.has("note3"):
			en_text += "（字条背面，还有一行新添的小字：三条偏旁拼在一起，是「回家」。）"
		out.append({
			id = "echo_note",
			title = "回响字条",
			text = en_text,
		})
	## 机制关卡 21：屋脊风铃随三刻痕集齐显形（基础文案盲测安全；三档风文本走 E 循环分支）
	if collected_marks.size() >= MARK_IDS.size():
		out.append({
			id = "wind_chime",
			title = "屋脊的风铃",
			text = "屋脊上挂着一只旧风铃，三根小管在风里轻轻碰着——像是在等一阵更大的风。",
		})
	if collected_marks.size() >= MARK_IDS.size() and inspected_once.has("echo_note") and ev != "":
		out.append({
			id = "note2",
			title = "回响字条 · 二",
			text = "证物匣的夹层里夹着第二张字条：「偏旁之二，宝盖头——『家』的上面，原来是屋顶。」",
		})
	if read_notes.has("note2") and int(core.stats.sci) >= 2:
		out.append({
			id = "note3",
			title = "回响字条 · 三",
			text = "天线底座压着第三张字条：「最后一笔是捺——是归途的那一步。写到这里，笔停了。」",
		})
	if secret == "colony_ship":
		out.append({
			id = "airlock_room",
			title = "气闸室",
			text = "气闸室的内衬上贴着星图的复写——被描过的坐标旁边，手绘了一轮月亮。",
		})
	elif secret == "mine_door":
		out.append({
			id = "airlock_room",
			title = "气闸室",
			text = "气闸室挂着风侵的封条，矿井口的方向钉着一枚旧罗盘——指针早已不再转动。",
		})
	if secret != "" and str(core.flags.get("evidence", "")) != "" and int(core.stats.warm) >= 1 and int(core.stats.susp) >= 1:
		out.append({
			id = "airlock_water",
			title = "气闸室的井水",
			text = "气闸室的角落，也放了一碗井水——和窗台那碗一样，还温着。井、窗、门，都被同一个人擦亮了。",
		})
	## 机制关卡 45：收件槽的绿植——与 build_spec 的 station_plant 同门控（站 × 温情≥1）；
	## 温情档分化（tier1 新芽 / tier2 开花）+ 浇过水追加句
	if place == "空间站" and int(core.stats.warm) >= 1:
		var pl_text := "收件槽旁多了一小盆绿植，土还是湿的——新芽刚冒头。"
		if int(core.stats.warm) >= 2:
			pl_text = "绿植的叶子中间开出了一朵很小的花——在只有信号灯的空间站里，显眼得不得了。"
		if plant_watered:
			pl_text += "\n你用喝剩的水浇过它。"
		out.append({
			id = "station_plant",
			title = "收件槽的绿植",
			text = pl_text,
		})
	## 机制关卡 49：舱顶通道——与 build_spec 的 roof_look_station 同门控（站 × 第 3 章后门同步）；
	## 文本=舱顶俯瞰（高度感知视线，盲测安全）
	if place == "空间站" and chapter >= 2:
		out.append({
			id = "roof_look_station",
			title = "舱顶矮道",
			text = "从舱顶看下去，走廊像一条被灯照亮的小河——你写的每一个地方都在这条河里。",
		})
	## 机制关卡 54：收件槽的应答器——与 build_spec 的 transponder 同门控（站 × 科幻中档）；
	## 文本=自动发射信号（盲测安全：等回应是设备行为）
	if place == "空间站" and int(core.stats.sci) >= 2:
		out.append({
			id = "transponder",
			title = "收件槽的应答器",
			text = "收件槽旁多了一个小型应答器——LED 在自动发射信号，等一个回应。",
		})
	## 机制关卡 50：舱壁的字条——与 build_spec 的 wall_note_station 同门控（站 × 悬疑满档）；
	## 文本=物证事实不指认写字人（盲测安全）
	if place == "空间站" and int(core.stats.susp) >= 2:
		out.append({
			id = "wall_note_station",
			title = "舱壁的字条",
			text = "广播面板旁的舱壁上贴着一张手写字条——字迹被划掉又重写，最后一句是：『别等广播了。』",
		})
	## 机制关卡 47：应急广播——与 build_spec 的 station_broadcast 同门控（站 × 悬疑≥1）；
	## 播放内容随双解释分化（无秘密=音乐；盲测安全：广播内容是站内事实）
	if place == "空间站" and int(core.stats.susp) >= 1:
		out.append({
			id = "station_broadcast",
			title = "应急广播",
			text = "走廊尽头的应急广播面板，红色指示灯一格一格地跳。",
		})
	## 机制关卡 55：壁炉的灰烬——第 4 章起（与后门/舱顶通道同步）；dom 三分化
	if chapter >= 2:
		var fa_text := ""
		var dom55 := dominant_tone()
		if dom55 == "sci":
			fa_text = "壁炉里有灰烬——金属碎片混在纸灰里，不是普通信纸烧完的残留。"
		elif dom55 == "warm":
			fa_text = "壁炉里有灰烬——信封的碎片混在里面，有人在这里烧了很多封信。"
		else:
			fa_text = "壁炉里的灰烬比昨天又厚了一层——有人在不停地烧什么东西。"
		out.append({
			id = "fireplace_ash",
			title = "壁炉的灰烬",
			text = fa_text,
		})
	## 机制关卡 56：停摆的挂钟——常驻；文本随章节三段递进，悬疑满档追加后缀（与 builder 键控驱动一致）
	out.append({
		id = "wall_clock",
		title = "挂钟",
		text = clock_text(chapter, int(core.stats.susp)),
	})
	## 机制关卡 57+66：会响的地板——常驻；未掀=57 主基调三分化句（踩响追加由 world 瞬态双写）；
	## 已掀=浅洞铁盒的身份三分化掀开句（66，role 活派生——57 与 66 的空间因果闭合）
	out.append({
		id = "floor_board",
		title = "会响的地板",
		text = floorboard_text(dominant_tone(), role, floorboard_open),
	})
	## 机制关卡 67：墙上的软木板——常驻；三态文本（空板/邀请/已钉+证物轮廓）
	out.append({
		id = "soft_board",
		title = "墙上的软木板",
		text = board_text(evidence_pinned, prop),
	})
	## 机制关卡 69：窗台的回信——常驻；档位文本（玩家写作实体化，可逆改写）
	out.append({
		id = "letter_draft",
		title = "窗台的回信",
		text = letter_text(letter_stage),
	})
	## 机制关卡 74：断线的风筝——镇专属常驻；挂树梢随风摆（21/31 家族），纯观察悬念句
	if place != "空间站":
		out.append({
			id = "tree_kite",
			title = "断线的风筝",
			text = "断线的风筝挂在树梢——线还打着结，放它的人不知道去了哪。",
		})
	## 机制关卡 58：门后的镜子——常驻；文本随身份三分化（侦探=核对照片/记者=袖口的墨/宇航员=训练手册），
	## 未选身份=还没看清自己；悬疑满档追加「镜子里只有你一个人」（反向后缀，盲测安全）
	out.append({
		id = "wall_mirror",
		title = "门后的镜子",
		text = mirror_text(role, int(core.stats.susp)),
	})
	## 机制关卡 62：墙角的木箱堆——常驻；未推=遮挡提示句，已推=身份三分化揭示（复用 58 身份轴）
	out.append({
		id = "crate_stack",
		title = "墙角的木箱堆",
		text = crate_text(role, crate_slid),
	})
	## 机制关卡 63：休眠舱——站专属常驻；文本身份三分化（宇航员=名单上自己的名字）
	if place == "空间站":
		out.append({
			id = "sleep_pod",
			title = "休眠舱",
			text = pod_text(role),
		})
	## 机制关卡 64：檐下的雨——镇专属常驻；雨势三段随悬疑轴，满档追加「打拍子」后缀（盲测安全）
	if place != "空间站":
		out.append({
			id = "eaves_rain",
			title = "檐下的雨",
			text = eaves_text(int(core.stats.susp)),
		})
	## 机制关卡 65：门槛石——镇专属常驻；文本两态（静=发亮/敲门激活=三下敲门声），与 KnockPlayer 同条件
	if place != "空间站":
		out.append({
			id = "door_step",
			title = "门槛石",
			text = door_step_text(str(core.flags.get("evidence", "")) != "" and int(core.stats.susp) >= 2),
		})
	## 机制关卡 59：烟囱与炊烟——第 3 章起与壁炉同章；文本主基调三分化（科幻=高效率/温情=白汽/
	## 悬疑=屋里没有火），烟柱出现=任一基调满档（w/s 键维），颜色随主基调
	if chapter >= 2:
		out.append({
			id = "roof_chimney",
			title = "烟囱",
			text = chimney_text(dominant_tone()),
		})
	## 机制关卡 43：旧收音机——与 build_spec 的 radio 同门控（镇变体 × 悬疑满档）
	if place != "空间站" and int(core.stats.susp) >= 2:
		out.append({
			id = "radio",
			title = "旧收音机",
			text = "五斗柜上多了一台旧收音机，旋钮锃亮——像有人天天拧它。",
		})
	## 机制关卡 53：信号灯箱——与 build_spec 的 signal_box 同门控（镇变体 × 科幻满档）；
	## 文本=满功率信号的事实呈现（盲测安全：读数是物证）
	if place != "空间站" and int(core.stats.sci) >= 3:
		out.append({
			id = "signal_box",
			title = "信号灯箱",
			text = "天线旁安装了一只信号灯箱，绿灯亮到了最后一格——天线在满功率运转，等一个愿意听的人。",
		})
	## 机制关卡 42：门前的脚印——与 build_spec 的 footprints 同门控（镇变体 × 第2章起 × 悬疑≥1）；
	## 密度随悬疑档（1=三枚 / 2=五枚）；文本=物证事实（盲测安全：不指认来者）
	if place != "空间站" and chapter >= 1 and int(core.stats.susp) >= 1:
		var fp_text := "门前的泥地上有一串脚印——不是你的。鞋底纹路很新，从院门来，到墙角消失。"
		if int(core.stats.susp) >= 2:
			fp_text = "门前的脚印比昨天多了——还是同样的鞋底，来回走了不止一趟。"
		out.append({
			id = "footprints",
			title = "门前的脚印",
			text = fp_text,
		})
	## 机制关卡 41：檐下燕巢——与 build_spec 的 nest 同门控（非站 且 第2章起 且 温情≥1）；文本随章节三段
	if place != "空间站" and chapter >= 1 and int(core.stats.warm) >= 1:
		var ns_text := "檐下多了一小块新泥——燕子开始筑巢了。"
		if chapter >= 2:
			ns_text = "巢筑好了，泥里混着草茎，边缘被压得圆圆的。"
		if chapter >= 3:
			ns_text = "巢里有了声音——细的，嫩的，饿的那种。老燕子落上去的时候，翅膀几乎不出声。"
		out.append({
			id = "nest",
			title = "檐下的燕巢",
			text = ns_text,
		})
	## 机制关卡 39：后院的猫——与 build_spec 的 yard_cat 同门控（第 3 章 且 温情≥1）
	if int(core.chapter_idx) >= 2 and int(core.stats.warm) >= 1:
		out.append({
			id = "yard_cat",
			title = "后院的猫",
			text = "一只灰白相间的猫蹲在柴堆旁，尾巴绕着前爪——看见你，抬了下眼，又闭上了。",
		})
	## 机制关卡 36：井里的回应——与 build_spec 的 well_wish_spot 同门控（第 3 章 且 揭盖）
	if int(core.chapter_idx) >= 2 and int(core.stats.susp) >= 1:
		var ww_text := "井沿内侧有一小块被摩挲得发亮的圆痕——像常有人在这里投下什么。"
		out.append({
			id = "well_wish_spot",
			title = "井沿的圆痕",
			text = ww_text,
		})
	## 机制关卡 22：井口的辘轳——与 build_spec 的 well_winch 同门控（第 3 章 且 揭盖），缺一条 validate 必败
	if int(core.chapter_idx) >= 2 and int(core.stats.susp) >= 1:
		out.append({
			id = "well_winch",
			title = "井口的辘轳",
			text = "井架边立着一架旧辘轳，绳筒上的绳子绷得笔直——绳子的另一头，系着井底的什么东西。",
		})
	## 机制关卡 23：后院的晾衣绳——与 build_spec 的 clothes_line 同门控（第 3 章 且 温情≥1）
	if int(core.chapter_idx) >= 2 and int(core.stats.warm) >= 1:
		var cl_text := "后院两根木杆之间拉着一根晾衣绳，几只木夹空着——像在等一件值得晾出来的东西。"
		## 机制关卡 30：跨章变干——上一章挂上的道具还在绳上，晾了一夜
		if line_hung_prop != "" and int(core.chapter_idx) > line_hung_chapter:
			cl_text = "晾衣绳上还挂着「%s」——晾了一夜，干了。布料上留着太阳的气味。" % line_hung_prop
		out.append({
			id = "clothes_line",
			title = "后院的晾衣绳",
			text = cl_text,
		})
	## 机制关卡 28：改写留下的实物——与 build_spec 的 case_mark 同门控（flag_case 非空）；
	## 文本=你写下的那句话的物证回执（分角色三分化，盲测安全：只描述实物事实）
	if str(core.flags.get("case", "")) != "":
		var cm_text := "档案架深处多了一件与案卷有关的旧物——你写下的那句话，在这里留下了实物。"
		match str(core.flags.get("case", "")):
			"旧卷宗":
				cm_text = "档案架第三层多了一本红标卷宗，编号正是你重查的那一册——纸页间夹着一张借阅卡，最近的借阅日期，是三年前。"
			"被撤的报道":
				cm_text = "档案架的夹缝里插着一张撤稿印件，标题被红笔划掉——划痕很新，墨迹未干。"
			"被改的日志":
				cm_text = "档案架上多了一册日志的复写本，某一页的坐标数字有涂改的痕迹——先写的和后描的，不是同一个手劲。"
		out.append({
			id = "case_mark",
			title = "改写留下的实物",
			text = cm_text,
		})
	## 机制关卡 34：舷窗外的星——与 build_spec 的 porthole_star 同门控（空间站变体 × 科幻≥1）；
	## 档位=闪烁急缓（s%d），秘密落定后节奏分化（colony=坐标同拍 / mine=地面探照灯，盲测安全）
	if place == "空间站" and int(core.stats.sci) >= 1:
		var ps_text := "舷窗外多了一颗会闪的星——很慢，一明，一暗，像有人在很远的地方数着拍子。"
		if int(core.stats.sci) >= 2:
			ps_text = "舷窗外的星闪得更急了，两下快，一下慢——不像星星，倒像信号。"
		if secret == "colony_ship":
			ps_text += "你数了数它的节奏——和星图上描过的坐标，是同一组数。"
			ps_text += "星旁边还有一点蓝，不闪，也不动——那么远，又那么确定。你知道那是什么。"
		elif secret == "mine_door":
			ps_text += "那不是星星——光是从地面来的，矿井口的探照灯，隔着那么远还在转。"
			ps_text += "远处还有一点亮，稳稳的，不闪——后山的矿灯？可这个时辰，矿早收工了。"
		out.append({
			id = "porthole_star",
			title = "舷窗外的星",
			text = ps_text,
		})
	## 机制关卡 25：屋顶水箱与后院水缸——与 build_spec 的 sci_tank 同门控（科幻≥1），档位随科幻
	if int(core.stats.sci) >= 1:
		var tank_text := "屋顶立起一只旧水箱，管口接着一线水声——天线苏醒之后，它也开始工作了。"
		if int(core.stats.sci) >= 2:
			tank_text = "水箱满了，浮标顶到管口，沿屋脊的管线一路都在轻轻发抖。"
		out.append({
			id = "roof_tank",
			title = "屋顶的水箱",
			text = tank_text,
		})
		var cis_text := "后院多了口水缸，沿墙的管线正往里送水——一滴，一滴，很有耐心。"
		if int(core.stats.sci) >= 2:
			cis_text = "缸满了。水面浮着一层细碎的光，和天线尖上的那种是同一种。"
		if cistern_filled:
			cis_text += "\n缸里的水比记忆里的满——像有人续过。"
		if ev != "" and int(core.stats.warm) >= 1 and int(core.chapter_idx) >= 1:
			cis_text += "\n缸沿搭着一只木瓢——窗台那碗要是浅了，这里随时补得上。"
		out.append({
			id = "cistern",
			title = "后院的水缸",
			text = cis_text,
		})
	if str(core.flags.get("prop", "")) == "星图" and int(core.stats.sci) >= 2 and read_notes.has("note3"):
		out.append({
			id = "note4",
			title = "回响字条 · 四",
			text = "三脚架的抽屉里睡着第四张字条：「井水会干，晚饭会凉，天线会锈——但有人把它们都擦亮了。这个人回来了，这就够了。」",
		})
	## 机制关卡 26：字条五——与 build_spec 的 note5 同门控（字条四读毕 且 温情≥2）
	if read_notes.has("note4") and int(core.stats.warm) >= 2:
		out.append({
			id = "note5",
			title = "晾衣绳下的字条",
			text = "晾衣绳的木夹下压着第五张字条，字迹被太阳晒得发淡：「锅一直温着，衣裳今天也干了。回来得再晚，灯也给你留着。」——这次没有落款，落款的位置画着一只小小的碗。",
		})
	if ev != "" and int(core.stats.warm) >= 1 and int(core.chapter_idx) >= 1:
		var ws_text := "窗台上多出一副摆好的碗筷，紧挨着「%s」——有人留了一份晚饭，给回来的人。" % ev
		if deep:
			ws_text += "碗旁多了一碗刚打上来的井水，还温着——井台那边，也亮着一点回应。"
		out.append({
			id = "window_setting",
			title = "窗台的碗筷",
			text = ws_text,
		})
	return out


## 证物匣文本（机制关卡 4：藏格随道具联动）。只读已落定的旗标，不揭示任何机制信息。
func _evidence_box_text(ev: String, prop: String) -> String:
	var t := "匣子里收着「%s」——你把它留在了这里，屋子替你记着。" % ev
	match prop:
		"古井":
			t += "抽屉格深处还压着一枚井泥拓片，边缘的印痕和匣内的锁纹对得上。"
		"信件":
			t += "抽屉格深处压着半张信笺，撕口的宽度和匣内的锁纹同宽。"
		"星图":
			t += "抽屉格深处塞着一段纸条，描过的坐标正好嵌进匣内的锁纹。"
		"旧照片":
			t += "抽屉格深处滑出一条底片，药膜面正对着匣内的锁纹，像在等一张新的照片。"
		_:
			t += "抽屉格深处似乎还藏着什么，被锁纹卡住了。"
	# 机制关卡 32：物证的归宿——桶中旧物收进匣后，匣文本追加一段（来历随主基调，跨章存活）
	if relic_stored:
		t += "\n匣子角落多了一件井里捞上来的旧物——" + relic_dom
	if drawer_matched:
		t += "\n夹层里多了一张对折的纸——折角正好卡进锁纹，像钥匙的齿。"
	return t


## 终稿落点：第 5 章进入时按主基调出现在不同位置；文本=核心生成的终稿（现场与正文一致）
func _ending_spot() -> Dictionary:
	var dom := dominant_tone()
	var title := "终稿落点"
	match dom:
		"sci":
			title = "深空通讯投递台"
		"warm":
			title = "家里的饭桌"
		_:
			title = "井台"
	## 机制关卡 33：终稿前的清点——跨章账本在落点文本回声（零核心改动，纯表现层）
	var text := str(core._ending_text())
	if mail_sent:
		text += "\n信箱里那封回信的话，你抄在了稿纸的最后一页。"
	if relic_stored:
		text += "\n证物匣里那件井里捞上来的旧物，你已经看了很多遍。"
	if line_hung_prop != "":
		text += "\n绳上晾着的「%s」干了，你把它叠好，压在手稿旁边。" % line_hung_prop
	if cat_petted:
		text += "\n后院的猫把你的稿纸当成了卧垫，赶都赶不走。"
	if plant_watered:
		text += "\n收件槽旁的绿植是你浇活的——现在它比任何人都先起得早。"
	if picture_straight:
		text += "\n墙上的挂画正了——像屋子也松了口气。"
	if cistern_filled:
		text += "\n后院的水缸是满的——你记得是谁倒进去的。"
	if chair_sitted:
		text += "\n桌边那把椅子你坐过很久——信就是坐在那里读完的。"
	return {id = "ending_spot", title = title, text = text}


func _night_record() -> Dictionary:
	var p := _pick(1, 0)
	var base := "桌上空着，夜还长。"
	match p:
		0:
			base = "桌上摊着你重读的三年前案件卷宗，关键页折了角。"
		1:
			base = "杯子里还剩半杯凉掉的茶——老友刚坐过的位置。"
		2:
			base = "你申请调阅的空间站日志终端还亮着，光标停在被改写的那页。"
	var ev := str(core.flags.get("evidence", ""))
	if ev != "":
		base += "你把「%s」摆在手边。" % ev
	return {id = "night_record", title = "桌上的夜记", text = base}


func _record_text(chapter: int, slot: int, original: String) -> String:
	var p := _pick(chapter, slot)
	var word := original
	if p >= 0 and int(core.chapter_idx) == chapter:
		word = str((core.slots[slot].options as Array)[p].text)
	elif p >= 0:
		# 历史章：表现记忆只存下标，文本从规则数据表回查（CHAPTERS 是常量）
		var opts: Array = core.CHAPTERS[chapter].slots[slot].options
		if p < opts.size():
			word = str(opts[p].text)
	return "字迹各异，其中一份写着：%s" % word


func _note_text() -> String:
	var p := _pick(2, 2)
	if p < 0:
		return "字条压在最底下，你还没有翻开它。"
	var word := "「小心回来的人」"
	if int(core.chapter_idx) == 2:
		word = str((core.slots[2].options as Array)[p].text)
	else:
		var opts: Array = core.CHAPTERS[2].slots[2].options
		if p < opts.size():
			word = str(opts[p].text)
	return "字条上只有一句：%s" % word


func _airlock_door(place: String, secret: String) -> Dictionary:
	var title := "后山的「气闸」"
	if place == "空间站":
		return {id = "airlock_door", title = "尾部气闸",
			text = "一扇再正常不过的气闸舱门——船上到处都是这样的门。"}
	if secret == "colony_ship":
		return {id = "airlock_door", title = title,
			text = "门后是伪装成废弃矿场的登船闸——他当年是第一批登船的人。"}
	if secret == "mine_door":
		return {id = "airlock_door", title = title,
			text = "防爆门后是矿井时代的记录间，封存着他亲手写下的停工真相。"}
	return {id = "airlock_door", title = title,
		text = "这扇门和后山的一切都不搭。你暂时解释不了它——门锁着，推不开。"}


func _prop_title(prop: String) -> String:
	match prop:
		"古井":
			return "井边的合影"
		"信件":
			return "泛黄的家书"
		"星图":
			return "加密的星图"
		"旧照片":
			return "一张模糊的旧照片"
	return "一张照片"   # 词槽未定稿时的原稿物件


func _prop_text(place: String, role: String, prop: String) -> String:
	var base := ""
	match prop:
		"古井":
			base = "合影背景里有一口井，两个人的笑容被水渍晕开了。"
		"信件":
			base = "家书的折痕处快要断开，信纸上有反复摩挲的毛边。"
		"星图":
			base = "星图的一部分坐标被笔反复描过，其余区域是加密的乱码。"
		"旧照片":
			base = "画面模糊，认不出人脸，只能看清拍照的日期。"
		_:
			base = "一张照片，边角起了卷。"
	# 身份观察：同一样东西，不同身份多看一眼的角度（只加叙事观察，不揭示机制）
	var obs := ""
	match role:
		"侦探":
			obs = "你习惯性地翻看了背面——没有指纹，但边缘有被镊子夹过的痕迹。"
		"记者":
			obs = "你估计这张照片的冲印时间，和信里说的年份对不上。"
		"宇航员":
			obs = "你注意到画面一角的光源方向，不像地面上的任何一种照明。"
	var loc := ""
	if place == "空间站":
		loc = "它被吸附在桌面的固定贴上。"
	elif prop != "":
		loc = "它被压在桌上那封信的下面。"
	return base + obs + loc
