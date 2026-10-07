extends Node3D
## DEMO10 3D 阶段 A：ChapterWorld——按 WorldSpec 搭建第一章可进入灰模。
## 布局（XZ 平面，米）：南面街巷/对接通道（出生点）→ 北面建筑（老屋/居住舱）→ 室内正文事件区。
## 两种地点变体共享同一走行骨架与同一门位（x∈[-1.2,1.2] 的南门洞），
## 让玩家在变体切换后能认出「还是前面那扇门」（指南第 3 节）。
## 事务式 apply_spec：先验证再重建，立即 free 旧变体（不留一帧旧碰撞）；
## 失败返回 false，由根脚本保留旧版本并提示，不出现「正文空间站、碰撞却是小镇」。

const GROUND_HALF := Vector2(22.0, 28.0)   # 地面半宽（x）/ 半深（z）；北延到 -28 容纳后山与解释舱室
const DOOR_HALF_W := 1.2                    # 南墙门洞半宽（前后门同宽：「还是那扇门」）
const BUILD := Rect2(-6.0, -12.0, 12.0, 10.0)   # 建筑足迹 x/z_min + 尺寸
const FENCE_Z := -20.0                      # 后山围栏/气闸门线

## 3d-shared 统一美术基座：所有世界物体用统一 comic 材质；套件物件用模型库（不复制套件文件）
const ComicStyle := preload("res://comic_style/comic_style.gd")
const ModelLibrary := preload("res://comic_style/model_library.gd")

var current_key := ""                       # 复合重建键：变体|后山|解释|气闸|终稿
var current_variant := ""                   # 当前地点变体（供测试/工具读取）
var comic_style: Resource                   # 统一 comic 材质来源
var wall_aabbs: Array = []                  # [Rect3-ish {x0,x1,z0,z1}] 供安全检查
var inspect_texts := {}                     # id → {title, text}（来自 spec）
var _variant_root: Node3D
var _env: WorldEnvironment
var _sun: DirectionalLight3D
var _room_light: OmniLight3D


func _ready() -> void:
	comic_style = ComicStyle.new()
	# 常驻部分：地面与边界墙（跨变体共享，不随 spec 重建）
	_build_ground_and_bounds()
	_env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.13, 0.17)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.56, 0.6)
	e.ambient_light_energy = 0.7
	_env.environment = e
	add_child(_env)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52, 28, 0)
	_sun.light_energy = 0.9
	add_child(_sun)
	_variant_root = Node3D.new()
	_variant_root.name = "VariantRoot"
	add_child(_variant_root)


## 基调氛围（指南红线允许：世界灯光可读基调；盲测安全——纯氛围，无数值、不改判定）。
## dom=sci/warm/susp，intensity 0..1（主基调值/3，封顶中性无偏移）。
func set_tone_mood(dom: String, intensity: float) -> void:
	intensity = clampf(intensity, 0.0, 1.0)
	var tint: Color
	match dom:
		"sci":
			tint = Color(0.72, 0.84, 1.0)
		"warm":
			tint = Color(1.0, 0.8, 0.62)
		"susp":
			tint = Color(0.78, 0.7, 1.0)
		_:
			tint = Color(1.0, 1.0, 1.0)
	var base_sun := Color(1.0, 0.96, 0.9)
	var base_amb := Color(0.55, 0.56, 0.6)
	_sun.light_color = base_sun.lerp(tint, 0.4 * intensity)
	_sun.light_energy = 0.9 - 0.12 * intensity
	_env.environment.ambient_light_color = base_amb.lerp(tint, 0.3 * intensity)


## 应用 spec：重建键（变体|后山|解释）变化则整体重建；检查文本始终刷新。
## 返回 {ok, variant_changed, reason}；ok=false 时调用方保留旧版本。
func apply_spec(spec: Dictionary) -> Dictionary:
	if str(spec.get("variant", "")) == "":
		return {ok = false, variant_changed = false, reason = "spec 无变体"}
	var want_variant: String = str(spec.variant)
	var back_open := bool(spec.get("back_open", false))
	var secret := str(spec.get("secret", ""))
	var end_dom := str(spec.get("ending_dom", ""))
	mood_dom = str(spec.get("mood_dom", ""))   # 机制关卡 22：主基调快照
	line_prop = str(spec.get("prop", ""))   # 机制关卡 23：所选道具快照
	var evidence_open := str(spec.get("evidence", "")) != ""
	var susp_tier := clampi(int(spec.get("susp_tier", 0)), 0, 2)
	var warm_tier := clampi(int(spec.get("warm_tier", 0)), 0, 2)
	var sci_tier := clampi(int(spec.get("sci_tier", 0)), 0, 2)
	var combo_well := bool(spec.get("combo_well", false))
	var combo_antenna := bool(spec.get("combo_antenna", false))
	var combo_table := bool(spec.get("combo_table", false))
	var key := "%s|%s|%s|%s|%s|%s|w%d|f%d|s%d|c%d|a%d|t%d|n%d|r%d%d|o%d|f%d|5%d|k%s|d%d|x%d|h%d|g%d|q%d|i%d|j%d|m%d|n%d|y%d|z%d|p2%d|l2%d" % [want_variant, "b" if back_open else "n", secret, "a" if bool(spec.get("has_airlock", false)) else "-", end_dom, "e" if evidence_open else "-", susp_tier, warm_tier, sci_tier, 1 if combo_well else 0, 1 if combo_antenna else 0, 1 if combo_table else 0, 1 if bool(spec.get("echo_note", false)) else 0, 1 if bool(spec.get("note2", false)) else 0, 1 if bool(spec.get("note3", false)) else 0, 1 if bool(spec.get("note4", false)) else 0, 1 if bool(spec.get("frost_cleared", false)) else 0, 1 if bool(spec.get("note5", false)) else 0, str(spec.get("case_mark", "")), 1 if bool(spec.get("line_dried", false)) else 0, 1 if bool(spec.get("drawer_open", false)) else 0, 1 if bool(spec.get("well_wished", false)) else 0, 1 if bool(spec.get("stash_open", false)) else 0, clampi(int(spec.get("nest_stage", 1)), 1, 3) if bool(spec.get("nest", false)) else 0, 1 if bool(spec.get("porthole_wiped", false)) else 0, 1 if bool(spec.get("cistern_filled", false)) else 0, 1 if bool(spec.get("mail_flag_up", false)) else 0, 1 if bool(spec.get("picture_straight", false)) else 0, 1 if bool(spec.get("crate_slid", false)) else 0, 1 if bool(spec.get("floorboard_open", false)) else 0, 1 if bool(spec.get("evidence_pinned", false)) else 0, int(spec.get("letter_stage", 0))]
	if key == current_key:
		_refresh_texts(spec)
		return {ok = true, variant_changed = false, reason = ""}
	for c in _variant_root.get_children():
		_variant_root.remove_child(c)
		c.free()   # 立即释放：不留旧碰撞体到下一帧
	wall_aabbs.clear()
	has_cistern = false       # 机制关卡 27：水缸/桶状态随重建复位
	floor_creaked = false     # 机制关卡 57：踩响态随重建复位（每章重新可踩）
	fireplace_lit = false     # 机制关卡 60：点火态随重建复位（时间跳跃=火熄）
	hearth_vigil = false      # 机制关卡 70：守夜态随重建复位（瞬态涌现不跨章）
	knock_answered = false    # 机制关卡 71：回应态随重建复位（每次叩门只应一次）
	trail_ready = false       # 机制关卡 72：动线采样复位（重建=新的一天，旧痕已被扫去）
	memory_fired = [false, false, false]  # 机制关卡 73：记忆随重建重置（每章可重新唤起）
	pod_lamp = null           # 机制关卡 63：呼吸灯材质随重建重建（悬挂引用清理）
	cistern_poured = false
	bucket_emptied = false
	lights_off = false
	broadcast_on = false        # 机制关卡 47：重建复位为关        # 机制关卡 37：重建复位为亮灯（屋子替你把灯点回去）
	radio_on = false           # 机制关卡 43：重建复位为关
	current_variant = want_variant
	var ids := []
	for ins in spec.inspectables:
		ids.append(str(ins.id))
	if want_variant == "town":
		_build_town(spec, ids)
	elif want_variant == "station":
		_build_station(spec, ids)
	else:
		current_key = ""
		return {ok = false, variant_changed = false, reason = "未知变体 " + want_variant}
	_build_ending_spot_in_root(end_dom, want_variant == "station", ids)
	var changed := current_key == "" or key.split("|")[0] != current_key.split("|")[0]
	current_key = key
	_refresh_texts(spec)
	return {ok = true, variant_changed = changed, reason = ""}


func _refresh_texts(spec: Dictionary) -> void:
	inspect_texts.clear()
	for ins in spec.inspectables:
		var id := str(ins.id)
		inspect_texts[id] = {title = str(ins.title), text = str(ins.text)}
		var node := _variant_root.get_node_or_null("INS_" + id)
		if node != null:
			node.set_meta("title", str(ins.title))
			node.set_meta("text", str(ins.text))


## 玩家胶囊（半径 0.45，身高 ~1.75）站立是否安全：在地面范围内且不嵌墙。
## AABB 带 Y 重叠判定（高度感知）：障碍须真的高于玩家脚位才阻挡——
## 玩家经检修梯在屋顶时地面墙不再误判卡墙；门楣等高位构件对地面玩家仍不算障碍
func is_position_safe(pos: Vector3) -> bool:
	if absf(pos.x) > GROUND_HALF.x - 0.6 or pos.z > GROUND_HALF.y - 0.6 or pos.z < -GROUND_HALF.y + 0.6:
		return false
	for b in wall_aabbs:
		if float(b.y1) <= pos.y + 0.1 or float(b.y0) >= pos.y + 1.75:
			continue
		if pos.x > float(b.x0) - 0.45 and pos.x < float(b.x1) + 0.45 \
				and pos.z > float(b.z0) - 0.45 and pos.z < float(b.z1) + 0.45:
			return false
	return true


## 从锚点列表里找第一个安全锚点；都unsafe返回 null
func find_safe_anchor(anchors: Array) -> Dictionary:
	for a in anchors:
		var p: Vector3 = a.pos
		if is_position_safe(p):
			return a
	return {}


# ---------------- 几何助手 ----------------

## 统一材质：非发光世界物体一律 comic body_material（3d-shared 基座）；
## 发光强调（少量可读性标记：信槽指示/门条/舱口灯等）保留自发光
func _mat(col: Color, emission := 0.0) -> Material:
	if emission <= 0.0:
		return comic_style.body_material(col)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = emission
	return m


## 套件物件（视觉，无碰撞）：碰撞仍由原有 _box/StaticBody 承担（碰撞/物理零改动）
func _kit_model(id: String, name_: String, pos: Vector3, yaw_deg := 0.0, scale_v := Vector3.ONE) -> Node3D:
	var obj: Node3D = ModelLibrary.create_model(id)
	obj.name = name_
	obj.position = pos
	obj.rotation_degrees.y = yaw_deg
	obj.scale = scale_v
	_variant_root.add_child(obj)
	return obj


## 只碰撞不显示的盒（供套件物件占位原有碰撞足迹）
func _box_collide_only(name_: String, pos: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.name = name_
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	sb.add_child(cs)
	sb.position = pos
	_variant_root.add_child(sb)
	wall_aabbs.append({x0 = pos.x - size.x * 0.5, x1 = pos.x + size.x * 0.5,
		z0 = pos.z - size.z * 0.5, z1 = pos.z + size.z * 0.5, y0 = pos.y - size.y * 0.5, y1 = pos.y + size.y * 0.5})


func _box(parent: Node3D, name_: String, pos: Vector3, size: Vector3, m: Material, collide := true) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name_
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		sb.add_child(cs)
		mi.add_child(sb)
		wall_aabbs.append({x0 = pos.x - size.x * 0.5, x1 = pos.x + size.x * 0.5,
			z0 = pos.z - size.z * 0.5, z1 = pos.z + size.z * 0.5, y0 = pos.y - size.y * 0.5, y1 = pos.y + size.y * 0.5})


func _inspectable(id: String, pos: Vector3, radius := 0.9) -> Area3D:
	var a := Area3D.new()
	a.name = "INS_" + id
	a.collision_layer = 4
	a.collision_mask = 0
	a.monitoring = false
	a.set_meta("inspect_id", id)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	cs.shape = sh
	a.add_child(cs)
	a.position = pos
	return a


func _build_ground_and_bounds() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var gm := PlaneMesh.new()
	gm.size = Vector2(GROUND_HALF.x * 2.0, GROUND_HALF.y * 2.0)
	ground.mesh = gm
	ground.material_override = _mat(Color(0.36, 0.4, 0.34))
	ground.position = Vector3(0, 0, 0)
	add_child(ground)
	var sb := StaticBody3D.new()
	sb.name = "GroundBody"
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(GROUND_HALF.x * 2.0, 0.4, GROUND_HALF.y * 2.0)
	cs.shape = sh
	sb.add_child(cs)
	sb.position = Vector3(0, -0.2, 0)
	add_child(sb)
	# 四面边界矮墙（可视化，防走出地面）
	var bm := _mat(Color(0.5, 0.42, 0.3))
	_box(self, "Bound_N", Vector3(0, 0.6, -GROUND_HALF.y), Vector3(GROUND_HALF.x * 2.0, 1.2, 0.6), bm)
	_box(self, "Bound_S", Vector3(0, 0.6, GROUND_HALF.y), Vector3(GROUND_HALF.x * 2.0, 1.2, 0.6), bm)
	_box(self, "Bound_W", Vector3(-GROUND_HALF.x, 0.6, 0), Vector3(0.6, 1.2, GROUND_HALF.y * 2.0), bm)
	_box(self, "Bound_E", Vector3(GROUND_HALF.x, 0.6, 0), Vector3(0.6, 1.2, GROUND_HALF.y * 2.0), bm)


## 共用建筑体：南墙带门洞、东西墙、室内桌+信+道具座+窗、室内灯；back_open 时北墙开同样宽的后门；
## evidence_open 时东墙开暗门通往证物间（支线机制：派生证物落定→世界物理化）
func _build_building(spec: Dictionary, _ids: Array, town: bool) -> void:
	var back_open := bool(spec.get("back_open", false))
	var evidence_open := str(spec.get("evidence", "")) != ""
	var combo_table := bool(spec.get("combo_table", false))
	var combo_deep := combo_table and int(spec.get("susp_tier", 0)) >= 1
	var wall_col := Color(0.85, 0.76, 0.62) if town else Color(0.56, 0.63, 0.74)
	var wall_m := _mat(wall_col)
	var x0: float = BUILD.position.x
	var x1: float = BUILD.position.x + BUILD.size.x
	var z0: float = BUILD.position.y          # -12
	var z1: float = BUILD.position.y + BUILD.size.y   # -2
	var h := 3.4
	var th := 0.4
	# 南墙两段（门洞居中 x∈[-1.2,1.2]）+ 门楣
	var left_w: float = -DOOR_HALF_W - x0
	var left_center := (x0 + -DOOR_HALF_W) * 0.5
	var right_w: float = x1 - DOOR_HALF_W
	var right_center := (DOOR_HALF_W + x1) * 0.5
	_box(_variant_root, "Wall_S_L", Vector3(left_center, h * 0.5, z1), Vector3(left_w, h, th), wall_m)
	_box(_variant_root, "Wall_S_R", Vector3(right_center, h * 0.5, z1), Vector3(right_w, h, th), wall_m)
	# 门楣
	_box(_variant_root, "Wall_S_Top", Vector3(0, h - 0.35, z1), Vector3(DOOR_HALF_W * 2.0, 0.7, th), wall_m)
	# 东西墙（evidence_open 时东墙在 z∈[-6.8,-5.2] 开 1.6m 暗门洞）
	_box(_variant_root, "Wall_W", Vector3(x0 + th * 0.5, h * 0.5, (z0 + z1) * 0.5), Vector3(th, h, BUILD.size.y), wall_m)
	if evidence_open:
		_box(_variant_root, "Wall_E_S", Vector3(x1 - th * 0.5, h * 0.5, (z1 + -5.2) * 0.5), Vector3(th, h, z1 - -5.2), wall_m)
		_box(_variant_root, "Wall_E_N", Vector3(x1 - th * 0.5, h * 0.5, (z0 + -6.8) * 0.5), Vector3(th, h, -6.8 - z0), wall_m)
		_box(_variant_root, "Wall_E_Top", Vector3(x1 - th * 0.5, h - 0.35, -6.0), Vector3(th, 0.7, 1.6), wall_m)
	else:
		_box(_variant_root, "Wall_E", Vector3(x1 - th * 0.5, h * 0.5, (z0 + z1) * 0.5), Vector3(th, h, BUILD.size.y), wall_m)
	# 北墙：第 3 章起开后门（与南门同宽，「还是那扇门」的稳定门位语言）
	if back_open:
		var nl_w: float = -DOOR_HALF_W - x0
		var nr_w: float = x1 - DOOR_HALF_W
		_box(_variant_root, "Wall_N_L", Vector3((x0 + -DOOR_HALF_W) * 0.5, h * 0.5, z0 + th * 0.5), Vector3(nl_w, h, th), wall_m)
		_box(_variant_root, "Wall_N_R", Vector3((DOOR_HALF_W + x1) * 0.5, h * 0.5, z0 + th * 0.5), Vector3(nr_w, h, th), wall_m)
		_box(_variant_root, "Wall_N_Top", Vector3(0, h - 0.35, z0 + th * 0.5), Vector3(DOOR_HALF_W * 2.0, 0.7, th), wall_m)
	else:
		_box(_variant_root, "Wall_N", Vector3(0, h * 0.5, z0 + th * 0.5), Vector3(BUILD.size.x, h, th), wall_m)
	# 屋顶/舱顶（带碰撞：检修梯机制——玩家可经梯架登顶行走；AABB 对地面检查因高度被跳过）
	var roof_m := _mat(Color(0.5, 0.44, 0.36) if town else Color(0.42, 0.48, 0.58))
	_box(_variant_root, "Roof", Vector3(0, h + 0.15, (z0 + z1) * 0.5), Vector3(BUILD.size.x + 0.6, 0.3, BUILD.size.y + 0.6), roof_m)
	# 机制关卡 24：北坡老虎窗（壳体常在；证物落定钉板卸下可进，箱底旧纸与所选证物同出一手）
	_build_dormer(evidence_open, bool(spec.get("stash_open", false)))
	# 屋顶检查点（梯架登顶后视线可达；地面够不到）
	_variant_root.add_child(_inspectable("roof_look", Vector3(-3.6, 4.55, -7.0), 0.5))
	if bool(spec.get("echo_note", false)):
		# 机制关卡 12：三处刻痕集齐 → 屋顶浮现回响字条（可视小纸条+检查点）
		var paper := MeshInstance3D.new()
		paper.name = "EchoNotePaper"
		var pm := BoxMesh.new()
		pm.size = Vector3(0.28, 0.03, 0.2)
		paper.mesh = pm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.93, 0.9, 0.8)
		pmat.emission_enabled = true
		pmat.emission = Color(0.85, 0.8, 0.6)
		pmat.emission_energy_multiplier = 0.4
		paper.material_override = pmat
		paper.position = Vector3(-2.4, 3.74, -7.4)
		_variant_root.add_child(paper)
		_variant_root.add_child(_inspectable("echo_note", Vector3(-2.4, 4.1, -7.4)))
	# 室内灯
	_room_light = OmniLight3D.new()
	_room_light.name = "RoomLight"
	_room_light.position = Vector3(0, 2.6, -7.5)
	_room_light.omni_range = 9.0
	_room_light.light_energy = 1.2
	_room_light.light_color = Color(1.0, 0.85, 0.65) if town else Color(0.72, 0.85, 1.0)
	_variant_root.add_child(_room_light)
	# 桌 + 信
	var desk_m := _mat(Color(0.55, 0.4, 0.28) if town else Color(0.45, 0.5, 0.6))
	_box(_variant_root, "Desk", Vector3(0, 0.375, -9.0), Vector3(1.6, 0.75, 0.8), desk_m)
	_box(_variant_root, "DeskLetter", Vector3(0, 0.79, -9.0), Vector3(0.42, 0.03, 0.3), _mat(Color(0.92, 0.88, 0.78), 0.15), false)
	var ins_desk := _inspectable("desk_letter", Vector3(0, 1.1, -9.0), 0.5)
	_variant_root.add_child(ins_desk)
	# 机制关卡 35：桌子的抽屉（E 拉开；跨章开态经 spec x 维驱动拉出量，向南 +z 拉出）
	var drawer_open := bool(spec.get("drawer_open", false))
	var drawer_z := -8.6 + (0.24 if drawer_open else 0.0)
	_box(_variant_root, "DeskDrawer", Vector3(0, 0.42, drawer_z), Vector3(0.5, 0.18, 0.24), _mat(Color(0.48, 0.35, 0.25)))
	_box(_variant_root, "DeskDrawerKnob", Vector3(0, 0.42, drawer_z + 0.13), Vector3(0.08, 0.05, 0.04), _mat(Color(0.62, 0.5, 0.36)), false)
	_variant_root.add_child(_inspectable("desk_drawer", Vector3(0, 0.55, -8.1), 0.4))
	# 机制关卡 40：桌边的椅子（E 坐下/站起；座面实体可站，靠背朝东）
	_box(_variant_root, "ChairSeat", Vector3(-1.35, 0.46, -8.9), Vector3(0.45, 0.08, 0.45), _mat(Color(0.5, 0.37, 0.26)))
	_box(_variant_root, "ChairBack", Vector3(-1.35, 0.75, -8.32), Vector3(0.06, 0.6, 0.45), _mat(Color(0.5, 0.37, 0.26)))
	_box(_variant_root, "ChairLegF", Vector3(-1.17, 0.21, -9.12), Vector3(0.06, 0.42, 0.4), _mat(Color(0.46, 0.34, 0.24)))
	_box(_variant_root, "ChairLegB", Vector3(-1.53, 0.21, -8.68), Vector3(0.06, 0.42, 0.4), _mat(Color(0.46, 0.34, 0.24)))
	_variant_root.add_child(_inspectable("chair", Vector3(-1.35, 0.62, -8.9), 0.4))
	# 机制关卡 55：壁炉（南墙内面灯开关旁；第 4 章起灰烬可见）
	if int(spec.get("chapter_idx", 0)) >= 2:
		_box(_variant_root, "FireplaceFrame", Vector3(-1.6, 0.6, BUILD.position.y + BUILD.size.y - th - 0.06), Vector3(0.6, 0.9, 0.12), _mat(Color(0.42, 0.34, 0.26)))
		_box(_variant_root, "FireplaceAsh", Vector3(-1.6, 0.35, BUILD.position.y + BUILD.size.y - th - 0.08), Vector3(0.4, 0.06, 0.2), _mat(Color(0.3, 0.28, 0.26)), false)
		var fa_glow := _box_glow(Vector3(-1.6, 0.42, BUILD.position.y + BUILD.size.y - th - 0.08), Vector3(0.1, 0.04, 0.06), Color(0.9, 0.55, 0.25))
		fa_glow.name = "FireplaceGlow"
		_variant_root.add_child(fa_glow)
		_variant_root.add_child(_inspectable("fireplace_ash", Vector3(-1.6, 0.55, BUILD.position.y + BUILD.size.y - th - 0.3), 0.4))
	# 机制关卡 52：墙上的挂画（西墙内面；歪斜 0.12，E 摆正后转正）
	var pic_rot := 0.0 if bool(spec.get("picture_straight", false)) else -0.12
	print("[DIAG pic] pic_rot=%s spec_ps=%s" % [str(pic_rot), str(spec.get("picture_straight", "MISSING"))])
	_box(_variant_root, "PictureFrame", Vector3(-5.15, 1.6, -6.0), Vector3(0.04, 0.6, 0.8), _mat(Color(0.45, 0.34, 0.24)))
	_box(_variant_root, "PictureCanvas", Vector3(-5.12, 1.6, -6.0), Vector3(0.03, 0.44, 0.64), _mat(Color(0.55, 0.65, 0.7)), false)
	var pic_cv := _variant_root.get_node("PictureCanvas")
	pic_cv.rotation.x = pic_rot
	_box(_variant_root, "PictureLamp", Vector3(-5.1, 2.0, -6.0), Vector3(0.06, 0.04, 0.5), _mat(Color(0.7, 0.65, 0.5)), false)
	_variant_root.add_child(_inspectable("wall_picture", Vector3(-4.8, 1.6, -6.0), 0.45))
	# 机制关卡 37：灯的开关（南墙内侧门旁；E 熄灯/开灯——两变体通用）
	_box(_variant_root, "LightPanel", Vector3(1.6, 1.45, BUILD.position.y + BUILD.size.y - th - 0.03), Vector3(0.16, 0.24, 0.04), _mat(Color(0.7, 0.68, 0.6)), false)
	_variant_root.add_child(_inspectable("light_switch", Vector3(1.6, 1.45, BUILD.position.y + BUILD.size.y - th - 0.25), 0.4))
	# 机制关卡 56：停摆的挂钟（北墙内面东侧常驻；指针随章节递进：停摆→走动→对时；
	# 三段全部由已键控维驱动——ending_dom 非空=对时 / back_open=走动，零新键维；悬疑满档→钟摆倾斜）
	var clock_stage := 0
	if str(spec.get("ending_dom", "")) != "":
		clock_stage = 2
	elif back_open:
		clock_stage = 1
	_box(_variant_root, "ClockBody", Vector3(3.0, 1.7, z0 + th + 0.03), Vector3(0.5, 0.5, 0.06), _mat(Color(0.82, 0.78, 0.7)), false)
	var clock_hm := _mat(Color(0.25, 0.22, 0.2))
	var hour_pv := Node3D.new()
	hour_pv.name = "ClockHourPivot"
	hour_pv.position = Vector3(3.0, 1.7, z0 + th + 0.07)
	_variant_root.add_child(hour_pv)
	var hour_hand := MeshInstance3D.new()
	hour_hand.name = "ClockHourHand"
	var hh_mesh := BoxMesh.new()
	hh_mesh.size = Vector3(0.035, 0.18, 0.02)
	hour_hand.mesh = hh_mesh
	hour_hand.position = Vector3(0, 0.09, 0)
	hour_hand.material_override = clock_hm
	hour_pv.add_child(hour_hand)
	var min_pv := Node3D.new()
	min_pv.name = "ClockMinutePivot"
	min_pv.position = Vector3(3.0, 1.7, z0 + th + 0.085)
	_variant_root.add_child(min_pv)
	var min_hand := MeshInstance3D.new()
	min_hand.name = "ClockMinuteHand"
	var mh_mesh := BoxMesh.new()
	mh_mesh.size = Vector3(0.025, 0.23, 0.015)
	min_hand.mesh = mh_mesh
	min_hand.position = Vector3(0, 0.115, 0)
	min_hand.material_override = clock_hm
	min_pv.add_child(min_hand)
	# 指针角（顺时针=绕 z 负角）：停 3:00 整 → 走到 3:40 → 对上天色 6:30
	match clock_stage:
		1:
			hour_pv.rotation.z = -1.9199
			min_pv.rotation.z = -4.18879
		2:
			hour_pv.rotation.z = -3.40339
			min_pv.rotation.z = -PI
		_:
			hour_pv.rotation.z = -PI / 2
			min_pv.rotation.z = 0.0
	# 钟摆：停摆时垂直下垂；悬疑满档（s%d 键维）→ 摆至半程的倾斜角
	var pen_pv := Node3D.new()
	pen_pv.name = "ClockPendulum"
	pen_pv.position = Vector3(3.0, 1.45, z0 + th + 0.06)
	_variant_root.add_child(pen_pv)
	var pen_rod := MeshInstance3D.new()
	pen_rod.name = "ClockPendulumRod"
	var pr_mesh := BoxMesh.new()
	pr_mesh.size = Vector3(0.035, 0.34, 0.02)
	pen_rod.mesh = pr_mesh
	pen_rod.position = Vector3(0, -0.17, 0)
	pen_rod.material_override = clock_hm
	pen_pv.add_child(pen_rod)
	var pen_bob := MeshInstance3D.new()
	pen_bob.name = "ClockPendulumBob"
	var pb_mesh := BoxMesh.new()
	pb_mesh.size = Vector3(0.1, 0.1, 0.03)
	pen_bob.mesh = pb_mesh
	pen_bob.position = Vector3(0, -0.36, 0)
	pen_bob.material_override = _mat(Color(0.62, 0.5, 0.36))
	pen_pv.add_child(pen_bob)
	pen_pv.rotation.z = -0.22 if int(spec.get("susp_tier", 0)) >= 2 else 0.0
	_variant_root.add_child(_inspectable("wall_clock", Vector3(3.0, 1.7, z0 + th + 0.35), 0.45))
	# 机制关卡 58：门后的镜子（南墙内面西侧常驻；文本身份三分化+悬疑满档后缀活派生，
	# 零键维零分支；镜面微发光=灯下可读）
	_box(_variant_root, "MirrorFrame", Vector3(-2.6, 1.55, z1 - th - 0.02), Vector3(0.5, 0.7, 0.05), _mat(Color(0.45, 0.34, 0.24)), false)
	var mirror_glass := _box_glow(Vector3(-2.6, 1.55, z1 - th - 0.05), Vector3(0.4, 0.6, 0.02), Color(0.72, 0.78, 0.82))
	mirror_glass.name = "MirrorGlass"
	_variant_root.add_child(mirror_glass)
	_variant_root.add_child(_inspectable("wall_mirror", Vector3(-2.6, 1.55, z1 - th - 0.35), 0.45))
	# 机制关卡 67：墙上的软木板（东墙内面北段常驻；E 描摹证物钉板——与 46 收进互补的外向
	# 展示；pinned 时描摹纸+红线出现，账本 p2%d 键维跨章；检查点距 desk_letter 5.4m 达标）
	_box(_variant_root, "SoftBoard", Vector3(5.56, 1.5, -9.0), Vector3(0.03, 0.7, 0.9), _mat(Color(0.62, 0.52, 0.38)))
	for pi67 in 4:
		_box(_variant_root, "BoardPin%d" % pi67, Vector3(5.53, 1.78 if pi67 < 2 else 1.22, -9.32 + (pi67 % 2) * 0.64), Vector3(0.02, 0.03, 0.03), _mat(Color(0.7, 0.35, 0.3)), false)
	if bool(spec.get("evidence_pinned", false)):
		_box(_variant_root, "PinnedPaper", Vector3(5.53, 1.5, -9.0), Vector3(0.015, 0.26, 0.2), _mat(Color(0.92, 0.88, 0.78)), false)
		_box(_variant_root, "PinRedLine", Vector3(5.52, 1.52, -8.82), Vector3(0.008, 0.01, 0.16), _mat(Color(0.75, 0.2, 0.18)), false)
		_box(_variant_root, "BlankPaper", Vector3(5.53, 1.42, -8.6), Vector3(0.015, 0.2, 0.15), _mat(Color(0.88, 0.86, 0.8)), false)
	_variant_root.add_child(_inspectable("soft_board", Vector3(5.42, 1.5, -9.0), 0.45))
	# 机制关卡 68：八音盒（室内中央小凳常驻；E 上发条→程序生成五声音阶旋律 1.6s，
	# 有限演奏曲终即止——与 43 收音机无限循环对照；瞬态 radio 同式重建复位）
	_box(_variant_root, "MusicStool", Vector3(1.8, 0.24, -7.0), Vector3(0.42, 0.48, 0.42), _mat(Color(0.48, 0.38, 0.28)), false)   # 纯视觉不拦路：低凳可跨过
	_box(_variant_root, "MusicBox", Vector3(1.8, 0.53, -7.0), Vector3(0.3, 0.14, 0.22), _mat(Color(0.55, 0.42, 0.3)), false)
	_box(_variant_root, "MusicBoxCrank", Vector3(1.98, 0.56, -7.0), Vector3(0.06, 0.03, 0.14), _mat(Color(0.62, 0.5, 0.36)), false)
	if music_box_player == null or not is_instance_valid(music_box_player):
		music_box_player = AudioStreamPlayer3D.new()
		music_box_player.name = "MusicBoxPlayer"
		music_box_player.position = Vector3(1.8, 0.62, -7.0)
		music_box_player.volume_db = -6.0
		_variant_root.add_child(music_box_player)
	_variant_root.add_child(_inspectable("music_box", Vector3(1.8, 0.72, -6.62), 0.45))
	# 机制关卡 72：你自己的脚印（42 的镜像对仗）——8 枚淡色足迹循环留痕（纯视觉不拦路、
	# 无检查点：世界记住你的动线，不需要按 E 看）；位置驱动家族第三处（57 踩响/71 回应/72 留痕）
	for ti72 in 8:
		_box(_variant_root, "TrailFoot%d" % ti72, Vector3(0, -5, 0), Vector3(0.12, 0.015, 0.2), _mat(Color(0.5, 0.48, 0.44)), false)
		(_variant_root.get_node("TrailFoot%d" % ti72) as MeshInstance3D).visible = false
	# 机制关卡 69：窗台的回信（北墙窗台东段常驻；E 循环三档语气，账本 l2%d 键维跨章；
	# 已写时墨线随档位增加——写作进度的视觉化；纯视觉不拦路）
	_box(_variant_root, "LetterPaper", Vector3(0.5, 1.16, -11.45), Vector3(0.3, 0.02, 0.22), _mat(Color(0.92, 0.88, 0.78)), false)
	var ls69 := int(spec.get("letter_stage", 0))
	for li69 in ls69:
		_box(_variant_root, "LetterInk%d" % li69, Vector3(0.5, 1.175, -11.5 + li69 * 0.05), Vector3(0.2, 0.005, 0.015), _mat(Color(0.25, 0.25, 0.35)), false)
	_variant_root.add_child(_inspectable("letter_draft", Vector3(0.5, 1.4, -11.15), 0.45))
	# 机制关卡 76：晨光进屋（第 5 章 ending_dom 键控——61 窗色金黄的室内印证；
	# 窗下地板斜置暖金光斑+窗台暖光小片，零新键维纯视觉不拦路）
	if str(spec.get("ending_dom", "")) != "":
		_box(_variant_root, "MorningPatch", Vector3(-2.5, 0.03, -10.65), Vector3(1.4, 0.02, 0.7), _mat(Color(0.85, 0.72, 0.45)), false)
		(_variant_root.get_node("MorningPatch") as MeshInstance3D).rotation.y = 0.18
		_box(_variant_root, "MorningSill", Vector3(-2.5, 1.13, -11.52), Vector3(1.5, 0.015, 0.1), _mat(Color(0.88, 0.76, 0.5)), false)
	# 机制关卡 62：墙角的木箱堆（北墙东侧常驻；E 推开顶层箱露出墙裙身高刻痕——遮挡揭示，
	# 第 16 种原型；账本 crate_slid 经 y%d 键维驱动顶箱位移，跨章保持；刻痕常驻被顶箱遮挡）
	var crate_m := _mat(Color(0.52, 0.42, 0.3))
	_box(_variant_root, "CrateBottom", Vector3(3.0, 0.2, -11.28), Vector3(0.6, 0.4, 0.5), crate_m)
	_box(_variant_root, "CrateTop", Vector3(3.0, 0.59, -11.24), Vector3(0.55, 0.38, 0.46), _mat(Color(0.56, 0.45, 0.32)), false)
	var crate_top: MeshInstance3D = _variant_root.get_node("CrateTop")
	crate_top.rotation.z = 0.06
	crate_top.position.x = 2.3 if bool(spec.get("crate_slid", false)) else 3.0
	_box(_variant_root, "CrateSide", Vector3(3.72, 0.175, -11.2), Vector3(0.5, 0.35, 0.42), crate_m)
	var mark_m := _mat(Color(0.38, 0.3, 0.22))
	for mi62 in 4:
		_box(_variant_root, "HeightMark%d" % mi62, Vector3(3.06 + mi62 * 0.14, 0.52 + mi62 * 0.14, z0 + th + 0.035), Vector3(0.14, 0.018, 0.012), mark_m, false)
	_box(_variant_root, "HeightMarkNum", Vector3(3.62, 0.98, z0 + th + 0.03), Vector3(0.22, 0.09, 0.01), _mat(Color(0.45, 0.4, 0.3)), false)
	_variant_root.add_child(_inspectable("crate_stack", Vector3(3.0, 0.5, -10.95), 0.45))
	if not town and _ids.has("sleep_pod"):
		_build_sleep_pod()
	# 机制关卡 64：檐下的雨（镇变体常驻；南墙门楣下缘滴线+地面水花三档+程序雨声；
	# 档位随悬疑轴 s%d——零新键维；雨声恒在场，档位只调音量：-60 静/-18 小/-8 暴）
	if town and _ids.has("eaves_rain"):
		var st64 := int(spec.get("susp_tier", 0))
		var drop_n := 1 if st64 <= 0 else (2 if st64 == 1 else 3)
		var drop_len := 0.25 if st64 <= 0 else (0.5 if st64 == 1 else 0.75)
		for di64 in drop_n:
			_box(_variant_root, "RainDrop%d" % di64, Vector3(-0.3 + di64 * 0.3, 2.35 - drop_len * 0.5, -1.95), Vector3(0.02, drop_len, 0.02), _mat(Color(0.62, 0.7, 0.8)), false)
			_box(_variant_root, "RainSplash%d" % di64, Vector3(-0.3 + di64 * 0.3, 0.03, -1.55), Vector3(0.14 + st64 * 0.06, 0.008, 0.14 + st64 * 0.06), _mat(Color(0.6, 0.68, 0.78)), false)
		if rain_stream == null:
			_gen_rain_stream()
		var rain_player := AudioStreamPlayer.new()
		rain_player.name = "RainPlayer"
		rain_player.stream = rain_stream
		rain_player.volume_db = -60.0 if st64 <= 0 else (-18.0 if st64 == 1 else -8.0)
		rain_player.autoplay = true
		_variant_root.add_child(rain_player)
		rain_player.play()
		_variant_root.add_child(_inspectable("eaves_rain", Vector3(0, 2.45, -1.85), 0.45))
	knock_active = bool(spec.get("door_knock", false))
	# 机制关卡 65：门槛石（镇变体常驻观察入口）+夜里的叩门声（镇×悬疑满档×有证物三条件；
	# 敲击节律内嵌 5 秒循环 WAV 三响+静音——零 _process；e 维+s 维+首维全键控，零新键维）
	if town:
		_box(_variant_root, "DoorStepStone", Vector3(0, 0.03, -2.25), Vector3(0.9, 0.06, 0.3), _mat(Color(0.5, 0.48, 0.44)))
		_variant_root.add_child(_inspectable("door_step", Vector3(0, 0.2, -2.5), 0.45))
		if bool(spec.get("door_knock", false)):
			var knock_player := AudioStreamPlayer3D.new()
			knock_player.name = "KnockPlayer"
			knock_player.stream = _gen_knock_stream()
			knock_player.position = Vector3(0, 1.3, -2.0)
			knock_player.volume_db = -6.0
			_variant_root.add_child(knock_player)
			knock_player.play()
	# 机制关卡 59：烟囱与炊烟（屋顶南端，与室内壁炉 55 同 x 对齐=空间垂直闭合；
	# 第 3 章起与壁炉同章出现；烟柱=任一基调满档，颜色随主基调——零新键维）
	if back_open:
		var brick_m := _mat(Color(0.5, 0.4, 0.34))
		_box(_variant_root, "ChimneyBody", Vector3(-1.6, 4.05, -3.4), Vector3(0.5, 0.9, 0.5), brick_m)
		_box(_variant_root, "ChimneyCap", Vector3(-1.6, 4.55, -3.4), Vector3(0.62, 0.12, 0.62), _mat(Color(0.42, 0.34, 0.29)))
		var wt := int(spec.get("warm_tier", 0))
		var st59 := int(spec.get("susp_tier", 0))
		var ct := int(spec.get("sci_tier", 0))
		if max(wt, max(st59, ct)) >= 2:
			var smoke_col := Color(0.72, 0.8, 0.85)
			match str(spec.get("mood_dom", "")):
				"warm":
					smoke_col = Color(0.88, 0.87, 0.83)
				"susp":
					smoke_col = Color(0.55, 0.55, 0.58)
			var smoke := Node3D.new()
			smoke.name = "SmokeStack"
			smoke.position = Vector3(-1.6, 0, -3.4)
			_variant_root.add_child(smoke)
			var seg_sizes := [Vector3(0.3, 0.5, 0.3), Vector3(0.24, 0.5, 0.24), Vector3(0.18, 0.5, 0.18)]
			for si in seg_sizes.size():
				var seg := MeshInstance3D.new()
				seg.name = "SmokeSeg%d" % si
				var seg_mesh := BoxMesh.new()
				seg_mesh.size = seg_sizes[si]
				seg.mesh = seg_mesh
				seg.position = Vector3(0, 4.85 + si * 0.48, 0)
				seg.material_override = _mat(smoke_col)
				smoke.add_child(seg)
		_variant_root.add_child(_inspectable("roof_chimney", Vector3(-1.6, 4.75, -3.4), 0.5))
	# 机制关卡 57：会响的地板（室内西走道常驻；松木板纯视觉不拦路+踩踏响应区；零新键维，
	# 文本主基调三分化由 inspectables 活派生，踩响态为本章瞬态——第十二种机制原型：走过触发）
	var fb_open := bool(spec.get("floorboard_open", false))
	if fb_open:
		# 机制关卡 66：板掀开斜靠墙根（遮挡解除），浅洞+铁盒露出的空间因果补完
		_box(_variant_root, "FloorPlank", Vector3(-3.9, 0.28, -8.05), Vector3(0.96, 0.05, 0.64), _mat(Color(0.47, 0.38, 0.28)), false)
		var fb_plank: MeshInstance3D = _variant_root.get_node("FloorPlank")
		fb_plank.rotation.x = -0.9
		_box(_variant_root, "DarkHole", Vector3(-3.2, -0.12, -7.6), Vector3(0.9, 0.24, 0.58), _mat(Color(0.06, 0.05, 0.045)), false)
		_box(_variant_root, "OldBox", Vector3(-3.2, 0.02, -7.68), Vector3(0.3, 0.16, 0.22), _mat(Color(0.45, 0.32, 0.2)), false)
	else:
		_box(_variant_root, "FloorPlank", Vector3(-3.2, 0.025, -7.6), Vector3(0.96, 0.05, 0.64), _mat(Color(0.47, 0.38, 0.28)), false)
	_box(_variant_root, "FloorPlankGap", Vector3(-3.2, 0.008, -7.6), Vector3(1.04, 0.02, 0.06), _mat(Color(0.3, 0.24, 0.18)), false)
	_variant_root.add_child(_inspectable("floor_board", Vector3(-3.2, 0.25, -7.6), 0.5))
	# 机制关卡 43：旧收音机（镇变体 × 悬疑满档；五斗柜+收音机+指示灯，E 开关杂音）
	if town and _ids.has("radio"):
		_build_radio()
	# 机制关卡 45：收件槽的绿植（站 × 温情≥1；温情档=开花）
	if not town and _ids.has("station_plant"):
		_build_station_plant(int(spec.get("warm_tier", 0)))
	# 机制关卡 54：收件槽的应答器（站 × 科幻中档；LED 球+检查点）
	if not town and _ids.has("transponder"):
		_build_transponder()
	# 机制关卡 47：应急广播（站 × 悬疑≥1；西墙面板+红指示灯，E 开/关）
	if _ids.has("station_broadcast"):
		_build_station_broadcast()
	# 机制关卡 50：舱壁的字条（站 × 悬疑满档；广播旁舱壁错位贴纸+检查点）
	if _ids.has("wall_note_station"):
		_build_wall_note_station()
	# 机制关卡 49：舱顶通道（站 × 第 3 章后门同步；壁挂梯垫点+舱顶碰撞板+俯瞰检查点）
	if back_open and _ids.has("roof_look_station"):
		_build_station_roof()
	# 道具座 + 道具物（默认「一张照片」灰盒；具体物随 flags.prop）
	_box(_variant_root, "Pedestal", Vector3(2.6, 0.45, -8.2), Vector3(0.6, 0.9, 0.6), desk_m)
	_add_prop_visual()
	var ins_prop := _inspectable("prop_item", Vector3(2.6, 1.35, -8.2))
	_variant_root.add_child(ins_prop)
	# 窗（北墙内侧，发光暗板）；机制关卡 61：天光随章节三段（夜→微亮→金黄晨光），
	# 悬疑满档反转=近黑（双轴材质状态：b 维/ending_dom/s%d 既有键控，零新键维；
	# 第 1-2 章保持原色=零回归）
	var win_col := Color(0.55, 0.6, 0.7) if town else Color(0.65, 0.75, 0.95)
	var win_emit := 0.25 if town else 0.6
	if int(spec.get("susp_tier", 0)) >= 2:
		win_col = Color(0.07, 0.08, 0.11)
		win_emit = 0.1
	elif str(spec.get("ending_dom", "")) != "":
		win_col = Color(0.8, 0.66, 0.42) if town else Color(0.75, 0.7, 0.55)
		win_emit = 0.8
	elif back_open:
		win_col = Color(0.68, 0.7, 0.72) if town else Color(0.72, 0.8, 0.95)
		win_emit = 0.5 if town else 0.7
	var win_m := _mat(win_col, win_emit)
	_box(_variant_root, "Window", Vector3(-2.5, 1.7, z0 + th + 0.06), Vector3(1.6, 1.1, 0.05), win_m, false)
	## r0.5：与窗台刻痕（-1.7,1.15,-11.3，r0.9）仅距 0.97——r0.9 球会吞掉 sill 射线（巡检 E2E 实测）
	var ins_win := _inspectable("window_look", Vector3(-2.5, 1.7, z0 + 0.75), 0.5)
	_variant_root.add_child(ins_win)
	# 证物联动暗室（支线机制：派生证物落定→东墙暗门后的小间）
	if evidence_open:
		_build_evidence_room(town, _ids)
	# 机制关卡 10：窗台的碗筷（温情×证物组合观察）
	if combo_table:
		_build_window_setting(town, combo_deep, _ids)


## 机制关卡 24：北坡老虎窗。壳体常在（钉板封死的窗龛，推不开是真的推不开）；
## 证物落定 → 钉板随事务卸下，自屋顶矮道真实步入，箱底旧纸与所选证物同出一手（盲测安全）。
## 开合走既有 evidence 键维度，证物回滚即重新封钉；玩家在龛内时回滚由安全锚点自动迁回。
func _build_dormer(open: bool, stash_open: bool = false) -> void:
	var body_m := _mat(Color(0.55, 0.44, 0.33))
	_box(_variant_root, "Dormer_W", Vector3(-5.075, 4.9, -11.1), Vector3(0.15, 2.4, 2.4), body_m)
	_box(_variant_root, "Dormer_E", Vector3(-3.425, 4.9, -11.1), Vector3(0.15, 2.4, 2.4), body_m)
	_box(_variant_root, "Dormer_N", Vector3(-4.25, 4.9, -12.225), Vector3(1.8, 2.4, 0.15), body_m)
	_box(_variant_root, "Dormer_F_W", Vector3(-5.05, 4.9, -9.975), Vector3(0.2, 2.4, 0.15), body_m)
	_box(_variant_root, "Dormer_F_E", Vector3(-3.45, 4.9, -9.975), Vector3(0.2, 2.4, 0.15), body_m)
	_box(_variant_root, "Dormer_Cap", Vector3(-4.25, 6.175, -11.1), Vector3(2.0, 0.15, 2.6), body_m)
	if not open:
		_box(_variant_root, "DormerPlank", Vector3(-4.25, 4.75, -9.975), Vector3(1.8, 1.9, 0.12), _mat(Color(0.45, 0.36, 0.26)))
	else:
		_box(_variant_root, "AtticCrate", Vector3(-4.25, 4.05, -11.875), Vector3(0.7, 0.7, 0.5), _mat(Color(0.5, 0.38, 0.25)))
		var lid := MeshInstance3D.new()
		lid.name = "AtticCrateLid"
		var lm := BoxMesh.new()
		lm.size = Vector3(0.7, 0.05, 0.5)
		lid.mesh = lm
		lid.material_override = _mat(Color(0.44, 0.33, 0.22))
		if stash_open:
			lid.position = Vector3(-4.25, 4.42, -11.86)
			lid.rotation.x = -1.2
		else:
			lid.position = Vector3(-4.25, 4.42, -11.875)
		_variant_root.add_child(lid)
		_box(_variant_root, "AtticPaper", Vector3(-4.25, 4.42, -11.875), Vector3(0.3, 0.02, 0.22), _mat(Color(0.92, 0.88, 0.78), 0.1), false)
		_variant_root.add_child(_inspectable("attic_stash", Vector3(-4.25, 4.7, -11.875), 0.45))


## 机制关卡 10：窗台的碗筷。温情≥1 × 证物落定 × 第 2 章起 → 窗台浮现一份摆好的碗筷（两副）。
## 只读 flags.evidence/stats.warm（低耦合）；combo 进重建键，条件破随事务撤除。
func _build_window_setting(town: bool, deep: bool, ids: Array) -> void:
	var sill_m := _mat(Color(0.6, 0.54, 0.44) if town else Color(0.44, 0.5, 0.6))
	_box(_variant_root, "WindowSill", Vector3(-2.5, 1.05, -11.35), Vector3(1.8, 0.12, 0.4), sill_m, false)
	var bowl_m := _mat(Color(0.9, 0.88, 0.82))
	_box(_variant_root, "SettingBowl1", Vector3(-2.85, 1.16, -11.3), Vector3(0.2, 0.1, 0.2), bowl_m, false)
	_box(_variant_root, "SettingBowl2", Vector3(-2.25, 1.16, -11.3), Vector3(0.2, 0.1, 0.2), bowl_m, false)
	_box(_variant_root, "SettingChopsticks", Vector3(-2.55, 1.17, -11.14), Vector3(0.26, 0.03, 0.03), _mat(Color(0.75, 0.6, 0.4)), false)
	if ids.has("sill_mark"):
		# 机制关卡 12：窗台刻痕（收集 2/3）
		_variant_root.add_child(_inspectable("sill_mark", Vector3(-1.7, 1.15, -11.3)))
	if deep:
		# 三条件深层组合：碗筷×井台回光同框 → 窗台多一碗刚打上来的井水
		var wb := MeshInstance3D.new()
		wb.name = "WaterBowl"
		var wbm := BoxMesh.new()
		wbm.size = Vector3(0.22, 0.09, 0.22)
		wb.mesh = wbm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.35, 0.55, 0.8)
		wmat.emission_enabled = true
		wmat.emission = Color(0.3, 0.5, 0.8)
		wmat.emission_energy_multiplier = 0.5
		wb.material_override = wmat
		wb.position = Vector3(-2.55, 1.17, -11.48)
		_variant_root.add_child(wb)
	## r0.5：与窗台刻痕（-1.7,1.15,-11.3，r0.9）仅距 0.85——r0.9 球会吞掉 sill 射线（巡检 E2E 实测）
	_variant_root.add_child(_inspectable("window_setting", Vector3(-2.55, 1.4, -11.35), 0.5))


## 证物联动暗室：只读 flags.evidence（低耦合）；封死/开启随重建键事务切换；重置本章证物回滚→重新封死
func _build_evidence_room(town: bool, ids: Array) -> void:
	var wall_m := _mat(Color(0.6, 0.54, 0.44) if town else Color(0.44, 0.5, 0.6))
	_box(_variant_root, "EvRoom_N", Vector3(8.0, 1.5, -9.0), Vector3(4.4, 3.0, 0.4), wall_m)
	_box(_variant_root, "EvRoom_S", Vector3(8.0, 1.5, -4.0), Vector3(4.4, 3.0, 0.4), wall_m)
	_box(_variant_root, "EvRoom_E", Vector3(10.0, 1.5, -6.5), Vector3(0.4, 3.0, 5.4), wall_m)
	_box(_variant_root, "EvRoom_Roof", Vector3(8.0, 3.15, -6.5), Vector3(4.6, 0.3, 5.8), _mat(Color(0.5, 0.44, 0.36) if town else Color(0.42, 0.48, 0.58)), false)
	var light := OmniLight3D.new()
	light.name = "EvRoomLight"
	light.position = Vector3(8.0, 2.3, -6.5)
	light.omni_range = 5.5
	light.light_energy = 1.0
	light.light_color = Color(1.0, 0.88, 0.66) if town else Color(0.75, 0.88, 1.0)
	_variant_root.add_child(light)
	_box(_variant_root, "EvRoomTable", Vector3(8.8, 0.4, -7.8), Vector3(1.1, 0.8, 0.7), _mat(Color(0.5, 0.4, 0.28) if town else Color(0.42, 0.48, 0.58)))
	_variant_root.add_child(_inspectable("evidence_box", Vector3(8.8, 1.1, -7.8)))
	if ids.has("note2"):
		# 机制关卡 13：回响字条·二（证物匣夹层）
		var p2 := MeshInstance3D.new()
		p2.name = "Note2Paper"
		var p2m := BoxMesh.new()
		p2m.size = Vector3(0.24, 0.03, 0.18)
		p2.mesh = p2m
		var p2mat := StandardMaterial3D.new()
		p2mat.albedo_color = Color(0.93, 0.9, 0.8)
		p2mat.emission_enabled = true
		p2mat.emission = Color(0.85, 0.8, 0.6)
		p2mat.emission_energy_multiplier = 0.4
		p2.material_override = p2mat
		p2.position = Vector3(8.55, 0.84, -7.55)
		_variant_root.add_child(p2)
		_variant_root.add_child(_inspectable("note2", Vector3(8.55, 1.05, -7.55)))
	refresh_evidence_stash("")


## 机制关卡 4：证物匣三个藏格，开格随 flags.prop 切换（根脚本每次事务后调用 refresh）
func refresh_evidence_stash(prop: String) -> void:
	var old := _variant_root.get_node_or_null("EvStashGroup")
	if old != null:
		_variant_root.remove_child(old)
		old.free()
	if _variant_root.get_node_or_null("EvRoomTable") == null:
		return   # 证物间未建（证物未落定）
	var group := Node3D.new()
	group.name = "EvStashGroup"
	_variant_root.add_child(group)
	var open_i := _stash_index(prop)
	for i in 3:
		var cell := MeshInstance3D.new()
		cell.name = "EvStashOpen" if i == open_i else "EvStashCell%d" % i
		var cm := BoxMesh.new()
		cm.size = Vector3(0.16, 0.1, 0.22)
		cell.mesh = cm
		var is_open := i == open_i
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.78, 0.6) if is_open else Color(0.4, 0.36, 0.3)
		if is_open:
			m.emission_enabled = true
			m.emission = Color(0.95, 0.8, 0.45)
			m.emission_energy_multiplier = 0.7
		cell.material_override = m
		cell.position = Vector3(8.45 + i * 0.24, 0.86, -7.62)
		group.add_child(cell)


## prop → 开格下标（古井0 / 信件1 / 星图2 / 旧照片1；未匹配=0）
func _stash_index(prop: String) -> int:
	match prop:
		"古井":
			return 0
		"信件":
			return 1
		"星图":
			return 2
		"旧照片":
			return 1
	return 0


func _add_prop_visual() -> void:
	# 灰模默认「一张照片」薄盒；选完道具后由 refresh_prop_visual 换外观
	refresh_prop_visual("")


## 按 flags.prop 刷新道具外观（变体不重建时也要跟着词槽变化，根脚本每次 apply 后调用）
func refresh_prop_visual(prop: String) -> void:
	var old := _variant_root.get_node_or_null("PropVisual")
	if old != null:
		_variant_root.remove_child(old)
		old.free()
	var col := Color(0.85, 0.82, 0.75)
	var size := Vector3(0.4, 0.04, 0.3)
	var glow := 0.2
	match prop:
		"古井":
			col = Color(0.7, 0.66, 0.55)
		"信件":
			col = Color(0.93, 0.86, 0.68)
			size = Vector3(0.3, 0.03, 0.42)
		"星图":
			col = Color(0.25, 0.4, 0.8)
			glow = 0.9
		"旧照片":
			col = Color(0.6, 0.58, 0.52)
	var mi := MeshInstance3D.new()
	mi.name = "PropVisual"
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _mat(col, glow)
	mi.position = Vector3(2.6, 1.0, -8.2)
	_variant_root.add_child(mi)


func _build_town(spec: Dictionary, ids: Array) -> void:
	var town := true
	var back_open := bool(spec.get("back_open", false))
	var secret := str(spec.get("secret", ""))
	var evidence_open := str(spec.get("evidence", "")) != ""
	var susp_tier := clampi(int(spec.get("susp_tier", 0)), 0, 2)
	var warm_tier := clampi(int(spec.get("warm_tier", 0)), 0, 2)
	var sci_tier := clampi(int(spec.get("sci_tier", 0)), 0, 2)
	var combo_well := bool(spec.get("combo_well", false))
	var combo_antenna := bool(spec.get("combo_antenna", false))
	var combo_table := bool(spec.get("combo_table", false))
	var combo_deep := combo_table and susp_tier >= 1
	# 街巷：石板路条 + 路灯柱 + 信箱（老屋门口）
	var path_m := _mat(Color(0.45, 0.42, 0.38))
	_box(_variant_root, "StreetPath", Vector3(0, 0.05, 6.0), Vector3(4.0, 0.1, 20.0), path_m, false)
	var lamp_m := _mat(Color(0.3, 0.28, 0.26))
	_box(_variant_root, "LampPost", Vector3(-3.0, 1.5, 6.0), Vector3(0.18, 3.0, 0.18), lamp_m)
	var lamp_head := OmniLight3D.new()
	lamp_head.position = Vector3(-3.0, 3.1, 6.0)
	lamp_head.light_color = Color(1.0, 0.8, 0.55)
	lamp_head.omni_range = 7.0
	lamp_head.light_energy = 0.8
	_variant_root.add_child(lamp_head)
	# 信箱
	var mb_m := _mat(Color(0.5, 0.32, 0.24))
	_box(_variant_root, "MailboxPost", Vector3(2.5, 0.5, 2.0), Vector3(0.12, 1.0, 0.12), mb_m)
	_box(_variant_root, "MailboxBox", Vector3(2.5, 1.15, 2.0), Vector3(0.5, 0.35, 0.35), _mat(Color(0.36, 0.24, 0.2)))
	var ins_mail := _inspectable("mail_slot", Vector3(2.5, 1.15, 2.0))
	_variant_root.add_child(ins_mail)
	# 机制关卡 51：信箱的小旗（投过回执 → 旗面竖起；builder-time by spec）
	if bool(spec.get("mail_flag_up", false)):
		_box(_variant_root, "MailFlagPole", Vector3(2.78, 1.5, 1.78), Vector3(0.03, 0.34, 0.03), _mat(Color(0.4, 0.4, 0.42)), false)
		_box(_variant_root, "MailFlagCloth", Vector3(2.86, 1.6, 1.78), Vector3(0.16, 0.1, 0.02), _mat(Color(0.85, 0.3, 0.25)), false)
	_build_building(spec, ids, true)
	# 门牌检查点（门外侧）
	var ins_door := _inspectable("door_front", Vector3(0, 1.4, BUILD.position.y + BUILD.size.y + 0.5))
	_variant_root.add_child(ins_door)
	# 点缀：套件木箱（碰撞足迹保留原盒）+ 院树/灌木（套件，纯视觉、避开通路）
	_box_collide_only("Crate1", Vector3(-8.5, 0.4, 8.0), Vector3(0.8, 0.8, 0.8))
	_kit_model("crate", "KitCrate1", Vector3(-8.5, 0.0, 8.0), 12.0, Vector3(0.8, 0.8, 0.8))
	_box_collide_only("Crate2", Vector3(8.0, 0.35, 10.5), Vector3(0.7, 0.7, 0.7))
	_kit_model("crate", "KitCrate2", Vector3(8.0, 0.0, 10.5), -20.0, Vector3(0.7, 0.7, 0.7))
	_kit_model("tree", "KitTree1", Vector3(-10.5, 0.0, 13.0), 0.0)
	_kit_model("tree", "KitTree2", Vector3(9.5, 0.0, 2.5), 40.0, Vector3(0.9, 0.9, 0.9))
	_kit_model("bush", "KitBush1", Vector3(-7.5, 0.0, -4.5), 0.0, Vector3(0.8, 0.8, 0.8))
	_kit_model("bush", "KitBush2", Vector3(12.5, 0.0, 3.0), 70.0)
	# 机制关卡 74：断线的风筝（镇变体常驻，挂 KitTree2 树梢；菱形盒+尾穗；
	# 摆角随 wind_level——21/31 风家族新成员，wind_apply_level 统一驱动）
	if ids.has("tree_kite"):
		_box(_variant_root, "TreeKite", Vector3(9.8, 3.05, 2.7), Vector3(0.34, 0.34, 0.02), _mat(Color(0.78, 0.42, 0.35)), false)
		(_variant_root.get_node("TreeKite") as MeshInstance3D).rotation.z = PI / 4
		_box(_variant_root, "KiteTail", Vector3(9.72, 2.78, 2.68), Vector3(0.03, 0.4, 0.01), _mat(Color(0.85, 0.7, 0.5)), false)
		_variant_root.add_child(_inspectable("tree_kite", Vector3(9.35, 2.85, 2.75), 0.45))
	if back_open:
		_build_backzone(false, secret, ids, bool(spec.get("airlock_water", false)), str(spec.get("case_mark", "")))
		_build_well(susp_tier, combo_well, ids)   # 机制关卡 2/8：井台进化 + 组合观察（井底的回光）
		if ids.has("well_wish_spot"):
			_build_well_wish(bool(spec.get("well_wished", false)))   # 机制关卡 36：井里的回应
		if ids.has("yard_cat"):
			_build_yard_cat()   # 机制关卡 39：后院的猫（温情≥1 常驻）
		if ids.has("clothes_line"):
			_build_clothes_line(ids, bool(spec.get("line_dried", false)), str(spec.get("line_dried_prop", "")))   # 机制关卡 23/30
		_build_ladder(true, ids)       # 机制关卡 3：检修梯（E 交互上/下屋顶矮道）
	if ids.has("nest"):
		_build_nest(clampi(int(spec.get("nest_stage", 1)), 1, 3))   # 机制关卡 41：檐下燕巢三段渐进（第 2 章即可见，不受后院门槛限制）
	if ids.has("footprints"):
		_build_footprints(susp_tier)   # 机制关卡 42：门前的脚印（悬疑档驱动密度）
	if ids.has("signal_box"):
		_build_signal_box()   # 机制关卡 53：信号灯箱（镇×科幻满档对称件）
	_build_antenna(sci_tier, combo_antenna, ids, str(spec.get("secret", "")), bool(spec.get("frost_cleared", false)))
	_build_bush_flowers(warm_tier)   # 机制关卡 6：温情基调驱动的灌木开花
	if ids.has("roof_tank"):
		_build_sci_tank(sci_tier, bool(spec.get("cistern_filled", false)))   # 机制关卡 25/48

## 机制关卡 7：旧天线复苏。天线是老屋常驻旧物；科幻基调让它「活」——1=尖端微光 2=蓝光晕。
## 只读 stats.sci（低耦合）；档位进重建键，跨档事务重建、回落即撤。空间站本身即科幻语境，不加。
func _build_antenna(tier: int, combo: bool, ids: Array, secret: String, frost_cleared: bool) -> void:
	var pole_m := _mat(Color(0.35, 0.34, 0.32))
	_box(_variant_root, "AntennaPole", Vector3(4.5, 4.4, -4.5), Vector3(0.08, 1.4, 0.08), pole_m)
	# 横枝装进容器：combo（星图×科幻2）时整体偏转校准到星图坐标方向（机制关卡 9）
	var arms := Node3D.new()
	arms.name = "AntennaArms"
	arms.position = Vector3(4.5, 5.0, -4.5)
	arms.rotation.z = 0.55 if combo else 0.0
	_variant_root.add_child(arms)
	for i in 3:
		var w := 1.1 - i * 0.3
		_box(arms, "AntennaArm", Vector3(0, -i * 0.28, 0), Vector3(w, 0.05, 0.05), pole_m, false)
	if combo:
		_variant_root.add_child(_inspectable("antenna_note", Vector3(4.5, 5.3, -4.5)))
	if ids.has("antenna_mark"):
		# 机制关卡 12：底座刻痕（收集 3/3）
		_variant_root.add_child(_inspectable("antenna_mark", Vector3(3.7, 4.3, -5.5)))
	if ids.has("note3"):
		# 机制关卡 13：回响字条·三（天线底座）
		var p3 := MeshInstance3D.new()
		p3.name = "Note3Paper"
		var p3m := BoxMesh.new()
		p3m.size = Vector3(0.24, 0.03, 0.18)
		p3.mesh = p3m
		var p3mat := StandardMaterial3D.new()
		p3mat.albedo_color = Color(0.93, 0.9, 0.8)
		p3mat.emission_enabled = true
		p3mat.emission = Color(0.85, 0.8, 0.6)
		p3mat.emission_energy_multiplier = 0.4
		p3.material_override = p3mat
		p3.position = Vector3(4.6, 4.28, -6.22)
		p3.rotation.y = 0.3
		_variant_root.add_child(p3)
		_variant_root.add_child(_inspectable("note3", Vector3(4.5, 4.35, -6.2)))
	if tier >= 1:
		var tip := MeshInstance3D.new()
		tip.name = "AntennaTip"
		var tm := SphereMesh.new()
		tm.radius = 0.14
		tm.height = 0.28
		tip.mesh = tm
		var tip_m := StandardMaterial3D.new()
		tip_m.albedo_color = Color(0.6, 0.85, 1.0)
		tip_m.emission_enabled = true
		tip_m.emission = Color(0.6, 0.85, 1.0)
		tip_m.emission_energy_multiplier = 1.1
		tip.material_override = tip_m
		tip.position = Vector3(4.5, 5.18, -4.5)
		_variant_root.add_child(tip)
	if tier >= 2:
		var glow := OmniLight3D.new()
		glow.name = "AntennaGlow"
		glow.position = Vector3(4.5, 5.0, -4.5)
		glow.light_color = Color(0.6, 0.8, 1.0)
		glow.omni_range = 5.0
		glow.light_energy = 0.7
		_variant_root.add_child(glow)
	if combo:
		# 机制关卡 14：观星台——天线校准后，屋顶东端围出可进入小板房（门洞朝西连屋顶矮道）
		_build_starhut(ids, secret, frost_cleared)

## 机制关卡 14：观星台。科幻≥2 × 星图 → 屋顶东端小板房（围绕天线杆），单筒望远镜对准星图坐标。
## 只读 flags.prop/stats.sci（低耦合）；随天线 combo 进重建键，条件破随事务撤除。
var telescope_aim := 0   # 机制关卡 20：望远镜指向档位 0=目镜 1=月亮 2=后山（表现层瞬态）
var wind_level := 0      # 机制关卡 21：风铃风档 0=静 1=微风 2=风起（表现层瞬态）
var winch_stage := 0     # 机制关卡 22：辘轳摇柄进度 0..3（表现层瞬态；随辘轳重建归零）
var mood_dom := ""       # 机制关卡 22：apply 时快照的主基调（桶中旧物外观用）
var line_hung := false   # 机制关卡 23：晾衣绳挂/收瞬态（表现层；随绳杆重建归零）
var line_prop := ""      # 机制关卡 23：apply 时快照的所选道具（挂上布片换色用）
var has_cistern := false     # 机制关卡 27：水缸在场（随重建复位；辘轳桶倒水用）
var cistern_poured := false  # 机制关卡 27：桶已倒进缸（表现层瞬态；重复 E 幂等）
var bucket_emptied := false  # 机制关卡 32：桶已倒过（首按倒水/待着，次按起收旧物）
var lights_off := false      # 机制关卡 37：室内灯已熄（表现层瞬态；重建复位为亮灯）
var radio_on := false        # 机制关卡 43：收音机开着（表现层瞬态；重建复位为关）
var floor_creaked := false   # 机制关卡 57：地板已踩响（本章一次性瞬态；重建复位）
var fireplace_lit := false   # 机制关卡 60：壁炉点火中（表现层瞬态；重建复位=熄灭）
var pod_lamp: StandardMaterial3D = null  # 机制关卡 63：呼吸灯材质（emission 随时间 sin 驱动）
var pod_t := 0.0             # 机制关卡 63：呼吸相位累加（_process 时间轴）
var rain_stream: AudioStreamWAV = null   # 机制关卡 64：程序生成雨声（懒生成一次，档位只调音量）
var music_playing := false   # 机制关卡 68：八音盒演奏中（表现层瞬态）
var music_done := false      # 机制关卡 68：曲终（表现层瞬态；再上发条即重置）
var hearth_vigil := false    # 机制关卡 70：守夜涌现态（灯灭×点火×坐着——三瞬态叠加）
var knock_active := false    # 机制关卡 71：65 叩门是否激活（builder 快照）
var knock_answered := false  # 机制关卡 71：玩家已回应叩门（本章一次；重建复位）
var trail_idx := 0           # 机制关卡 72：脚印循环游标（8 枚覆盖复用）
var trail_last := Vector3.ZERO  # 机制关卡 72：上次采样位（0.9m 间距）
var trail_ready := false     # 机制关卡 72：首样本旗标（避免出生点即留痕）
signal memory_recalled(text: String)  # 机制关卡 73：地方的记忆唤起（demo10_3d 接 hud toast）
var memory_fired := [false, false, false]  # 机制关卡 73：三处记忆本章已唤起旗标
const MEMORY_SPOTS := [Vector3(-2.5, 0.2, -17.5), Vector3(0, 0.2, -2.8), Vector3(-3.6, 3.85, -7.0)]
const MEMORY_TEXTS := [
	"这口井你太熟了——小时候打水，胳膊上还留着力气的记忆。",
	"门槛上这道凹痕，是几十年的鞋底磨的。你爷爷的，你爸的，你的。",
	"从屋顶望出去，整个院子一眼收尽——你在这里看过多少个黄昏？",
]
var music_box_player: AudioStreamPlayer3D = null  # 机制关卡 68：旋律发声（常驻，play 触发）
var music_stream: AudioStreamWAV = null  # 机制关卡 68：程序生成旋律（懒生成一次）
var creak_stream: AudioStreamWAV = null  # 机制关卡 57：程序生成吱呀声（懒生成一次）
var creak_player: AudioStreamPlayer3D = null  # 机制关卡 57：空间化发声（挂 VariantRoot，重建随撤）
var frost_present := false   # 机制关卡 44：舷窗霜在场（apply 快照；root 擦霜分支用）
var broadcast_on := false    # 机制关卡 47：应急广播播放中（表现层瞬态；重建复位为关）
var chair_sitting := false   # 机制关卡 40：坐在桌边椅子上（表现层瞬态）
var chair_prev := Vector3.ZERO  # 机制关卡 40：坐下前的位置（站起恢复用）

func _build_starhut(ids: Array, secret: String, frost_cleared: bool) -> void:
	if not ids.has("antenna_note"):
		return
	var wall_m := _mat(Color(0.52, 0.56, 0.64))
	_box(_variant_root, "Hut_N", Vector3(4.9, 4.6, -6.6), Vector3(2.6, 1.8, 0.3), wall_m)
	_box(_variant_root, "Hut_S", Vector3(4.9, 4.6, -4.4), Vector3(2.6, 1.8, 0.3), wall_m)
	_box(_variant_root, "Hut_E", Vector3(6.15, 4.6, -5.5), Vector3(0.3, 1.8, 2.5), wall_m)
	# 西侧敞开（观星朝西），仅两根角柱示意门框
	_box(_variant_root, "Hut_Post_N", Vector3(3.7, 4.6, -6.45), Vector3(0.3, 1.8, 0.3), wall_m)
	_box(_variant_root, "Hut_Post_S", Vector3(3.7, 4.6, -4.55), Vector3(0.3, 1.8, 0.3), wall_m)
	_box(_variant_root, "Hut_Roof", Vector3(4.95, 5.6, -5.5), Vector3(2.9, 0.2, 2.6), _mat(Color(0.42, 0.48, 0.58)), false)
	var light := OmniLight3D.new()
	light.name = "HutLight"
	light.position = Vector3(4.9, 5.2, -5.5)
	light.light_color = Color(0.7, 0.85, 1.0)
	light.omni_range = 4.5
	light.light_energy = 0.8
	_variant_root.add_child(light)
	var tube := MeshInstance3D.new()
	tube.name = "TelescopeTube"
	var tm := BoxMesh.new()
	tm.size = Vector3(0.12, 0.12, 0.7)
	tube.mesh = tm
	var tubm := _mat(Color(0.3, 0.34, 0.4))
	tube.material_override = tubm
	tube.position = Vector3(5.3, 4.72, -5.5)
	# 机制关卡 16：镜筒指向随双解释分化（colony 上仰指月 / mine 下俯指矿井）；
	# 实时校准互动（机制关卡 20）由 telescope_apply_aim() 驱动
	tube.rotation.x = 0.35 if secret == "mine_door" else (-0.55 if secret == "colony_ship" else -0.5)
	# 机制关卡 17：镜片霜膜（未读字条四时有霜；读毕擦净透亮）
	if not frost_cleared:
		var frost := MeshInstance3D.new()
		frost.name = "LensFrost"
		var fm := BoxMesh.new()
		fm.size = Vector3(0.14, 0.14, 0.16)
		frost.mesh = fm
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = Color(0.9, 0.95, 1.0, 0.55)
		fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		frost.material_override = fmat
		frost.position = Vector3(5.3, 4.72, -5.5)
		_variant_root.add_child(frost)
	if frost_cleared:
		var spark := MeshInstance3D.new()
		spark.name = "LensSpark"
		var sm := SphereMesh.new()
		sm.radius = 0.045
		sm.height = 0.09
		spark.mesh = sm
		var spm := StandardMaterial3D.new()
		spm.albedo_color = Color(1, 1, 0.9)
		spm.emission_enabled = true
		spm.emission = Color(1, 1, 0.85)
		spm.emission_energy_multiplier = 1.3
		spark.material_override = spm
		spark.position = Vector3(5.42, 4.86, -5.32)
		_variant_root.add_child(spark)
	_variant_root.add_child(tube)
	_box(_variant_root, "TelescopeTripod", Vector3(5.3, 4.15, -5.5), Vector3(0.1, 0.9, 0.1), _mat(Color(0.3, 0.3, 0.32)), false)
	_variant_root.add_child(_inspectable("telescope", Vector3(5.3, 4.75, -5.5), 0.45))
	if ids.has("note4"):
		# 机制关卡 15：回响字条·四（三脚架抽屉，系列收束）
		var p4 := MeshInstance3D.new()
		p4.name = "Note4Paper"
		var p4m := BoxMesh.new()
		p4m.size = Vector3(0.22, 0.03, 0.16)
		p4.mesh = p4m
		var p4mat := StandardMaterial3D.new()
		p4mat.albedo_color = Color(0.93, 0.9, 0.8)
		p4mat.emission_enabled = true
		p4mat.emission = Color(0.85, 0.8, 0.6)
		p4mat.emission_energy_multiplier = 0.45
		p4.material_override = p4mat
		p4.position = Vector3(5.05, 4.32, -5.42)
		_variant_root.add_child(p4)
		_variant_root.add_child(_inspectable("note4", Vector3(5.05, 4.5, -5.42)))

## 机制关卡 6：灌木开花。0=绿叶 / 1=每丛 3 朵小花 / 2=每丛 6 朵+微光。
## 只读 stats.warm（低耦合）；档位进重建键，跨档事务重建、回落即撤。空间站无灌木不受影响。
func _build_bush_flowers(tier: int) -> void:
	if tier <= 0:
		return
	var spots := [Vector3(-7.5, 0.55, -4.5), Vector3(12.5, 0.45, 3.0)]
	var flower_m := _mat(Color(0.95, 0.78, 0.85))
	var flower_m2 := _mat(Color(0.98, 0.92, 0.75))
	var idx := 0
	for spot in spots:
		var count := 6 if tier >= 2 else 3
		for i in count:
			var f := MeshInstance3D.new()
			f.name = "BushFlower_%d" % idx
			idx += 1
			var fm := SphereMesh.new()
			fm.radius = 0.06
			fm.height = 0.12
			f.mesh = fm
			f.material_override = flower_m if (idx % 2 == 0) else flower_m2
			var ang := float(i) * TAU / float(count)
			f.position = spot + Vector3(cos(ang) * 0.45, 0.28, sin(ang) * 0.35)
			_variant_root.add_child(f)
	if tier >= 2:
		var glow := OmniLight3D.new()
		glow.name = "BushGlow"
		glow.position = Vector3(-7.5, 1.2, -4.5)
		glow.light_color = Color(1.0, 0.85, 0.9)
		glow.omni_range = 3.5
		glow.light_energy = 0.5
		_variant_root.add_child(glow)


## 机制关卡 3：检修梯。梯基/梯顶两块交互垫（meta ladder_to=锚点 id），
## E 命中即沿锚点表传送；屋顶可行走（Roof 启用碰撞）。梯架只造视觉与垫点，不改规则。
func _build_ladder(town: bool, ids: Array) -> void:
	var rail_m := _mat(Color(0.45, 0.36, 0.26) if town else Color(0.4, 0.46, 0.56))
	for rx in [-7.9, -7.1]:
		_box(_variant_root, "LadderRail", Vector3(rx, 2.0, -10.5), Vector3(0.12, 4.0, 0.12), rail_m)
	for i in 5:
		_box(_variant_root, "LadderRung", Vector3(-7.5, 0.55 + i * 0.75, -10.5), Vector3(0.7, 0.08, 0.14), rail_m, false)
	_box(_variant_root, "LadderTopPlat", Vector3(-7.5, 3.62, -8.9), Vector3(1.2, 0.12, 2.6), rail_m)
	if ids.has("wind_chime"):
		# 机制关卡 21：三刻痕集齐 → 屋脊风铃显形（E 循环三档风，文本随主基调分化）
		_build_wind_chime(town)
	var base := _inspectable("ladder_base", Vector3(-7.5, 1.1, -10.5))
	base.set_meta("ladder_to", "roof_top")
	_variant_root.add_child(base)
	var top := _inspectable("ladder_top", Vector3(-6.6, 4.35, -8.6))
	top.set_meta("ladder_to", "yard_ladder_base")
	_variant_root.add_child(top)


## 机制关卡 2：井台进化。0=盖板封井 / 1=揭盖暗水 / 2=水面雾光。
## 只读 stats.susp（低耦合）；第 5 章悬疑终稿的红布由 ending_spot 在同一口井上追加（不预演）。
func _build_well(tier: int, combo: bool, ids: Array) -> void:
	var base_m := _mat(Color(0.52, 0.5, 0.47))
	_box(_variant_root, "Well_Base", Vector3(-2.5, 0.35, -17.5), Vector3(1.6, 0.7, 1.6), base_m)
	# 井沿四沿（视觉）
	var rim_m := _mat(Color(0.58, 0.56, 0.52))
	for r in [[0.0, -0.72, 1.7, 0.16], [0.0, 0.72, 1.7, 0.16], [-0.72, 0.0, 0.16, 1.28], [0.72, 0.0, 0.16, 1.28]]:
		_box(_variant_root, "Well_Rim", Vector3(-2.5 + r[0], 0.78, -17.5 + r[1]), Vector3(r[2], 0.16, r[3]), rim_m, false)
	if tier >= 1:
		# 揭盖：暗水面（微弱反光）
		var water := MeshInstance3D.new()
		water.name = "Well_Water"
		var wm := CylinderMesh.new()
		wm.top_radius = 0.62
		wm.bottom_radius = 0.62
		wm.height = 0.04
		water.mesh = wm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.14, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(0.08, 0.12, 0.22)
		mat.emission_energy_multiplier = 0.6
		water.material_override = mat
		water.position = Vector3(-2.5, 0.62, -17.5)
		_variant_root.add_child(water)
	if tier >= 2:
		# 雾光：井口上方的半透明冷雾 + 微光
		var mist := MeshInstance3D.new()
		mist.name = "Well_Mist"
		var mm := BoxMesh.new()
		mm.size = Vector3(1.1, 0.5, 1.1)
		mist.mesh = mm
		var mist_m := StandardMaterial3D.new()
		mist_m.albedo_color = Color(0.55, 0.75, 0.95, 0.28)
		mist_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mist_m.emission_enabled = true
		mist_m.emission = Color(0.5, 0.7, 0.95)
		mist_m.emission_energy_multiplier = 0.5
		mist.material_override = mist_m
		mist.position = Vector3(-2.5, 1.05, -17.5)
		_variant_root.add_child(mist)
		var glow := OmniLight3D.new()
		glow.name = "Well_Glow"
		glow.position = Vector3(-2.5, 1.4, -17.5)
		glow.light_color = Color(0.55, 0.75, 1.0)
		glow.omni_range = 4.0
		glow.light_energy = 0.6
		_variant_root.add_child(glow)
	if ids.has("well_mark"):
		# 机制关卡 12：揭盖后井沿显形刻痕（收集 1/3）
		_variant_root.add_child(_inspectable("well_mark", Vector3(-1.4, 0.85, -17.5)))
	if ids.has("well_winch"):
		# 机制关卡 22：井口的辘轳（E 摇三段，桶出井口带回一件随主基调的旧物）
		_build_well_winch()
	if combo and tier >= 1:
		# 机制关卡 8：组合观察——证物落定且悬疑≥1，水面浮现「井底的回光」
		var glint := MeshInstance3D.new()
		glint.name = "Well_Glint"
		var gm := BoxMesh.new()
		gm.size = Vector3(0.12, 0.03, 0.18)
		glint.mesh = gm
		var glm := StandardMaterial3D.new()
		glm.albedo_color = Color(0.95, 0.9, 0.7)
		glm.emission_enabled = true
		glm.emission = Color(0.95, 0.85, 0.55)
		glm.emission_energy_multiplier = 1.0
		glint.material_override = glm
		glint.position = Vector3(-2.5, 0.68, -17.3)
		_variant_root.add_child(glint)
		## r0.5：井台边小反光物——r0.9 会吞掉东侧木桶（bucket）射线（巡检 E2E 实测）
		_variant_root.add_child(_inspectable("well_reflection", Vector3(-2.5, 0.95, -17.4), 0.5))


## 机制关卡 22：井口的辘轳。井架西侧立架+摇臂+垂绳；E 摇三段拉桶（winch_crank），
## 桶出井口时桶内旧物随主基调换色（sci=黄铜齿轮 / warm=红绳铃铛 / susp=锈钥匙）。
## 摇臂/桶体纯视觉无碰撞，井架立柱带碰撞；重建时随 _variant_root 整体撤除、进度归零。
## 机制关卡 36：井里的回应。井沿西南角检查点（E 投币）；投过硬币 → 水面小圆硬币
## （spec h 维驱动，重建后仍在；揭盖态才可见，盖板态随井台撤除）。
## 选址 (-3.2,1.05,-16.9)：西北瞄准线经探针验证 reflection/winch/mark 三球全避开（余量≥0.33）。
func _build_well_wish(wished: bool) -> void:
	if wished:
		var coin := MeshInstance3D.new()
		coin.name = "WishCoin"
		var cc := CylinderMesh.new()
		cc.top_radius = 0.05
		cc.bottom_radius = 0.05
		cc.height = 0.015
		coin.mesh = cc
		coin.material_override = _mat(Color(0.85, 0.72, 0.4))
		coin.position = Vector3(-2.5, 0.66, -17.5)
		_variant_root.add_child(coin)
	_variant_root.add_child(_inspectable("well_wish_spot", Vector3(-3.2, 1.05, -16.9), 0.35))


func _build_well_winch() -> void:
	winch_stage = 0
	var post_m := _mat(Color(0.42, 0.34, 0.26))
	_box(_variant_root, "WinchPost", Vector3(-4.2, 0.75, -17.5), Vector3(0.14, 1.5, 0.14), post_m)
	_box(_variant_root, "WinchAxle", Vector3(-3.7, 1.3, -17.5), Vector3(1.0, 0.1, 0.1), post_m, false)
	# 垂绳：井口到绳筒的连线（视觉）
	_box(_variant_root, "WinchRope", Vector3(-3.35, 1.1, -17.5), Vector3(0.02, 0.9, 0.02), _mat(Color(0.35, 0.3, 0.24)), false)
	# 摇臂（E 后绕轴转动）
	var crank := Node3D.new()
	crank.name = "WinchCrank"
	crank.position = Vector3(-4.2, 1.3, -17.5)
	_variant_root.add_child(crank)
	var arm := MeshInstance3D.new()
	arm.name = "WinchArm"
	var am := BoxMesh.new()
	am.size = Vector3(0.08, 0.5, 0.08)
	arm.mesh = am
	arm.material_override = post_m
	arm.position = Vector3(0, 0.22, 0.12)
	crank.add_child(arm)
	# 摇柄球头
	_box(crank, "WinchKnob", Vector3(0, 0.45, 0.12), Vector3(0.09, 0.09, 0.09), _mat(Color(0.55, 0.5, 0.4)), false)
	_variant_root.add_child(_inspectable("well_winch", Vector3(-4.0, 1.05, -17.5), 0.42))


## 机制关卡 27：E 摇辘轳——推进 1..3 段（物理动作不倒摇，到顶后重复 E 只复述所见）；
## 第 3 段桶出井口：BucketGroup（木桶+桶中旧物，旧物颜色随 mood_dom），重复 E 不重复生成。
func winch_crank() -> int:
	winch_stage = mini(winch_stage + 1, 3)
	var crank := _variant_root.get_node_or_null("WinchCrank")
	if crank != null:
		crank.rotation.z = 2.2 * winch_stage
	if winch_stage >= 3 and _variant_root.get_node_or_null("BucketGroup") == null:
		var bucket := Node3D.new()
		bucket.name = "BucketGroup"
		bucket.position = Vector3(-3.5, 0.95, -17.5)
		_variant_root.add_child(bucket)
		var bm := MeshInstance3D.new()
		bm.name = "BucketMesh"
		var bc := CylinderMesh.new()
		bc.top_radius = 0.16
		bc.bottom_radius = 0.13
		bc.height = 0.26
		bm.mesh = bc
		bm.material_override = _mat(Color(0.5, 0.38, 0.25))
		bucket.add_child(bm)
		var item := MeshInstance3D.new()
		item.name = "BucketRelic"
		var ic := BoxMesh.new()
		ic.size = Vector3(0.12, 0.05, 0.08)
		item.mesh = ic
		var relic_col := Color(0.45, 0.38, 0.3)
		if mood_dom == "sci":
			relic_col = Color(0.72, 0.62, 0.35)
		elif mood_dom == "warm":
			relic_col = Color(0.8, 0.3, 0.28)
		item.material_override = _mat(relic_col)
		item.position = Vector3(0, 0.14, 0)
		bucket.add_child(item)
		# 机制关卡 27：桶出水后自身可检查（E 倒进水缸；运行时生成一次，不进 spec 验证清单）
		# ⚠️ 必须在守卫内：函数体层级会随每次 crank 重复生成，同名 add_child 被 Godot 改匿名名，
		# root 的 collider.name 分支永远匹配不上（巡检 E2E 实测）
		_variant_root.add_child(_inspectable("bucket", Vector3(-3.5, 1.35, -17.5), 0.4))
	return winch_stage


## 机制关卡 27：把井水倒进水缸。返回状态 0=后院无缸（sci 线未接）/ 1=本次倒进 / 2=已倒过（幂等）；
## 倒进时缸内水面抬升 0.06（表现层反馈，不改判定）。
func bucket_pour() -> int:
	if not has_cistern:
		return 0
	if cistern_poured:
		return 2
	cistern_poured = true
	var water := _variant_root.get_node_or_null("CisternWater")
	if water != null:
		water.position.y += 0.06
	return 1


## 机制关卡 32：把桶中旧物收起来（E 桶第二次起）——BucketRelic 随场景移除；
## 返回是否本次移除（false=桶里已没有旧物）。入匣记账在 bridge.relic_store（root 调）。
func relic_take() -> bool:
	var relic := _variant_root.get_node_or_null("BucketGroup/BucketRelic")
	if relic == null:
		return false
	relic.get_parent().remove_child(relic)
	relic.free()
	return true


## 机制关卡 37：灯的开关——E 熄灯/开灯（室内灯 energy 1.2↔0.14；表现层瞬态，重建复位亮灯）。
## 返回熄灯后的状态（true=灭）。
## 机制关卡 70：守夜涌现态——灯灭（37）×壁炉点火（60）×坐椅子（40）三瞬态同时成立；
## 守夜时火光更旺（FireLight 1.6→2.4）；任何一条件退出即消散；重建复位。
func _update_vigil() -> void:
	var v := lights_off and fireplace_lit and chair_sitting
	if v == hearth_vigil:
		return
	hearth_vigil = v
	var fl := _variant_root.get_node_or_null("FireLight")
	if fl != null:
		fl.light_energy = 2.4 if v else 1.6


func light_toggle() -> bool:
	lights_off = not lights_off
	_apply_lights()
	_update_vigil()
	return lights_off


func _apply_lights() -> void:
	if _room_light != null:
		_room_light.light_energy = 1.2 * (0.12 if lights_off else 1.0)


## 机制关卡 43：旧收音机。五斗柜+收音机+指示灯（E 开关杂音，root 分支 → radio_toggle）。
## 纯氛围盲测安全；重建复位为关。
## 机制关卡 45：收件槽的绿植。站 × 温情≥1 → 收件槽旁小盆栽（盆+叶；温情档2 加小花）；
## E 浇水（root 分支 → bridge.plant_water 账本）。纯视觉不拦路。
## 机制关卡 49：舱顶通道（站变体竖向通行，与镇梯关卡 3 对称）。西墙壁挂梯（垫点 meta ladder_to
## 沿锚点表 station_roof_top/station_roof_base 传送）；Corr_Top 加碰撞薄板使舱顶可站；
## 俯瞰检查点 roof_look_station 在舱顶南缘。纯通行零规则改动。
func _build_station_roof() -> void:
	var rail_m := _mat(Color(0.42, 0.48, 0.58))
	# 梯架纯视觉（避免走廊内实体拦路）；通行全靠垫点传送
	for rz in [9.6, 10.5]:
		for rx in [-2.62, -2.18]:
			_box(_variant_root, "SLadderRail", Vector3(rx, 1.8, rz), Vector3(0.1, 3.2, 0.1), rail_m, false)
		for i in 4:
			_box(_variant_root, "SLadderRung", Vector3(-2.4, 0.6 + i * 0.75, rz), Vector3(0.5, 0.07, 0.13), rail_m, false)
	# 舱顶可走碰撞板（Corr_Top 上方，站走位的新一层）
	_box(_variant_root, "SRoofPlate", Vector3(-1.7, 3.5, 10.5), Vector3(2.8, 0.08, 5.0), rail_m)
	var base := _inspectable("station_roof_base", Vector3(-2.4, 1.2, 9.6))
	base.set_meta("ladder_to", "station_roof_top")
	_variant_root.add_child(base)
	var top := _inspectable("station_roof_top", Vector3(-2.4, 3.72, 10.5))
	top.set_meta("ladder_to", "station_roof_base")
	_variant_root.add_child(top)
	_variant_root.add_child(_inspectable("roof_look_station", Vector3(-1.0, 3.65, 9.0), 0.6))


## 机制关卡 47：应急广播。走廊西墙面板+红指示灯（E 开/关，root 分支 → broadcast_toggle）；
## 播放内容随双解释分化（bridge.broadcast_text）。纯氛围盲测安全；重建复位为关。
## 机制关卡 50：舱壁的字条。广播面板同墙错位（z=4.5 vs 6.0，射线互不吞）；
## 纸条+检查点 wall_note_station，纯检查无 root 分支；重建随 _variant_root。
func _build_wall_note_station() -> void:
	_box(_variant_root, "WallNotePaper", Vector3(-2.76, 1.35, 4.5), Vector3(0.02, 0.22, 0.18), _mat(Color(0.9, 0.87, 0.78)), false)
	_variant_root.add_child(_inspectable("wall_note_station", Vector3(-2.4, 1.35, 4.5), 0.35))


## 机制关卡 54：收件槽的应答器。站 × 科幻中档 → 收件槽旁小型应答器（LED 球发光）。
## 纯检查点无 root 分支；纯视觉不拦路；选址距 mail_slot 1.2m 射线零冲突。
func _build_transponder() -> void:
	_box(_variant_root, "TransponderBase", Vector3(1.5, 1.05, 1.0), Vector3(0.18, 0.3, 0.18), _mat(Color(0.32, 0.34, 0.4)))
	var led := _box_glow(Vector3(1.5, 1.28, 1.0), Vector3(0.06, 0.06, 0.06), Color(0.4, 0.7, 1.0))
	led.name = "TransponderLED"
	_variant_root.add_child(led)
	_variant_root.add_child(_inspectable("transponder", Vector3(1.5, 1.0, 1.5), 0.4))


func _build_station_broadcast() -> void:
	broadcast_on = false
	_box(_variant_root, "BroadcastPanel", Vector3(-2.76, 1.7, 6.0), Vector3(0.05, 0.45, 0.65), _mat(Color(0.32, 0.34, 0.4)))
	_box(_variant_root, "BroadcastGrill", Vector3(-2.72, 1.7, 6.0), Vector3(0.02, 0.3, 0.5), _mat(Color(0.2, 0.2, 0.22)), false)
	var lamp := _box_glow(Vector3(-2.72, 1.45, 5.8), Vector3(0.05, 0.05, 0.05), Color(1.0, 0.35, 0.3))
	lamp.name = "BroadcastLamp"
	lamp.visible = broadcast_on
	_variant_root.add_child(lamp)
	_variant_root.add_child(_inspectable("station_broadcast", Vector3(-2.4, 1.7, 6.0), 0.45))


## 机制关卡 47：E 开/关广播（换向）；红指示灯随状态亮灭。返回开后的状态（true=播放中）。
func broadcast_toggle() -> bool:
	broadcast_on = not broadcast_on
	var lamp := _variant_root.get_node_or_null("BroadcastLamp")
	if lamp != null:
		lamp.visible = broadcast_on
	return broadcast_on


func _build_station_plant(warm_tier: int) -> void:
	_box(_variant_root, "PlantPot", Vector3(1.75, 0.35, 2.02), Vector3(0.2, 0.22, 0.2), _mat(Color(0.55, 0.35, 0.3)))
	_box(_variant_root, "PlantLeaf", Vector3(1.75, 0.55, 2.02), Vector3(0.16, 0.24, 0.16), _mat(Color(0.35, 0.6, 0.38)), false)
	if warm_tier >= 2:
		_box(_variant_root, "PlantFlower", Vector3(1.75, 0.7, 2.02), Vector3(0.06, 0.06, 0.06), _mat(Color(0.9, 0.6, 0.7)), false)
	_variant_root.add_child(_inspectable("station_plant", Vector3(1.75, 0.55, 1.6), 0.45))


func _build_radio() -> void:
	radio_on = false
	var cab_m := _mat(Color(0.44, 0.33, 0.28))
	_box(_variant_root, "RadioCabinet", Vector3(-2.0, 0.5, -2.6), Vector3(0.7, 1.0, 0.45), cab_m)
	_box(_variant_root, "RadioBody", Vector3(-2.0, 1.15, -2.6), Vector3(0.5, 0.3, 0.3), _mat(Color(0.35, 0.3, 0.26)))
	_box(_variant_root, "RadioGrill", Vector3(-2.0, 1.15, -2.44), Vector3(0.3, 0.16, 0.02), _mat(Color(0.22, 0.2, 0.18)), false)
	var lamp := _box_glow(Vector3(-2.18, 1.24, -2.44), Vector3(0.05, 0.05, 0.02), Color(0.5, 0.9, 0.5))
	lamp.name = "RadioLamp"
	_variant_root.add_child(lamp)
	_variant_root.add_child(_inspectable("radio", Vector3(-2.0, 1.0, -2.3), 0.45))


## 机制关卡 43：E 开/关收音机（换向）；指示灯随状态亮灭。返回开后的状态（true=开着）。
## 机制关卡 63：呼吸灯循环动画——emission 随 sin(t) 呼吸（时间驱动状态，headless 可采样断言）
func _process(delta: float) -> void:
	if pod_lamp != null:
		pod_t += delta
		pod_lamp.emission_energy_multiplier = 1.1 + 0.8 * sin(pod_t * 4.0)
	# 机制关卡 68：曲终检测——演奏完自动落闩（music_done 置位，再上发条即重置）
	if music_playing and music_box_player != null and not music_box_player.playing:
		music_playing = false
		music_done = true


## 机制关卡 57：踩踏响应——玩家走进松动木板矩形（仅水平判定）即触发一次吱呀。
## 本章一次性（floor_creaked 瞬态，重建复位）；文本追加由触发时双写 dict+节点 meta。
func _physics_process(_delta: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ex := parent.get_node_or_null("Explorer") as Node3D
	if ex == null:
		return
	# 机制关卡 72：动线采样——移动 0.9m 留一枚淡脚印（循环复用 8 枚；不受踩响态影响）
	if not trail_ready or ex.global_position.distance_to(trail_last) > 0.9:
		trail_ready = true
		trail_last = ex.global_position
		var foot := _variant_root.get_node_or_null("TrailFoot%d" % trail_idx)
		if foot != null:
			foot.visible = true
			foot.position = Vector3(ex.global_position.x, 0.02, ex.global_position.z)
		trail_idx = (trail_idx + 1) % 8
	# 机制关卡 73：走过记忆点（3D 距离 1.6m 内）→ 唤起一次（toast 由 demo10_3d 信号接出）
	for mi73 in MEMORY_SPOTS.size():
		if not memory_fired[mi73] and ex.global_position.distance_to(MEMORY_SPOTS[mi73]) < 1.6:
			memory_fired[mi73] = true
			memory_recalled.emit(MEMORY_TEXTS[mi73])
	if floor_creaked:
		return
	try_floor_creak_at(ex.global_position)


## 直接触发探测（水平含判定；供物理帧与测试共用）。返回 true=本次踩响。
func try_floor_creak_at(pos: Vector3) -> bool:
	if floor_creaked:
		return false
	if _variant_root.get_node_or_null("DarkHole") != null:
		return false   # 机制关卡 66：板已掀开，踩不响了（空间因果）
	if pos.x < -3.68 or pos.x > -2.72 or pos.z < -7.92 or pos.z > -7.28:
		return false
	floor_creaked = true
	if creak_stream == null:
		_gen_creak_stream()
	if creak_player == null or not is_instance_valid(creak_player):
		creak_player = AudioStreamPlayer3D.new()
		creak_player.name = "FloorCreakPlayer"
		creak_player.position = Vector3(-3.2, 0.3, -7.6)
		_variant_root.add_child(creak_player)
	creak_player.stream = creak_stream
	creak_player.play()
	var entry: Dictionary = inspect_texts.get("floor_board", {})
	if not entry.is_empty():
		entry["text"] = str(entry.get("text", "")) + "（刚才那一声还挂在耳朵里。）"
		inspect_texts["floor_board"] = entry
		var node := _variant_root.get_node_or_null("INS_floor_board")
		if node != null:
			node.set_meta("text", entry["text"])
	return true


## 程序生成 0.45 秒吱呀声（零资产依赖）：下滑 210→140Hz+13Hz 颤+衰减包络（木纹摩擦感）
func _gen_creak_stream() -> void:
	var rate := 11025
	var n := int(rate * 0.45)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var ph := float(i) / float(n)
		var freq := 210.0 - 70.0 * ph
		var vib := 1.0 + 0.18 * sin(TAU * 13.0 * t)
		var env := (1.0 - ph) * (0.35 + 0.65 * sin(PI * minf(ph * 3.0, 1.0)))
		var v := 0.5 * sin(TAU * freq * vib * t) * env
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	wav.data = data
	creak_stream = wav


## 机制关卡 60：壁炉点火/熄火（E，瞬态；重建复位=熄灭）——火光实体点亮+屋顶烟囱
## 同步冒暖白烟（几何级跨机制联动，独立于基调烟 SmokeStack）；无壁炉（第 2 章前）不响应。
func fireplace_toggle() -> bool:
	var glow := _variant_root.get_node_or_null("FireplaceGlow")
	if glow == null:
		return fireplace_lit
	fireplace_lit = not fireplace_lit
	var fire_light := _variant_root.get_node_or_null("FireLight")
	var fire_smoke := _variant_root.get_node_or_null("FireSmoke")
	if fireplace_lit:
		glow.scale = Vector3(2.2, 2.2, 2.2)
		if fire_light == null:
			var fl := OmniLight3D.new()
			fl.name = "FireLight"
			fl.position = Vector3(-1.6, 0.9, -3.0)
			fl.omni_range = 5.0
			fl.light_energy = 1.6
			fl.light_color = Color(1.0, 0.62, 0.3)
			_variant_root.add_child(fl)
		if fire_smoke == null and _variant_root.get_node_or_null("ChimneyCap") != null:
			var fsmoke := Node3D.new()
			fsmoke.name = "FireSmoke"
			fsmoke.position = Vector3(-1.6, 0, -3.4)
			_variant_root.add_child(fsmoke)
			var fs_cols := [Color(0.82, 0.78, 0.72), Color(0.78, 0.74, 0.7), Color(0.74, 0.72, 0.7)]
			for fi in 3:
				var fseg := MeshInstance3D.new()
				fseg.name = "FireSmokeSeg%d" % fi
				var fmesh := BoxMesh.new()
				fmesh.size = Vector3(0.26 - fi * 0.05, 0.55, 0.26 - fi * 0.05)
				fseg.mesh = fmesh
				fseg.position = Vector3(0, 4.85 + fi * 0.5, 0)
				fseg.material_override = _mat(fs_cols[fi])
				fsmoke.add_child(fseg)
	else:
		glow.scale = Vector3.ONE
		if fire_light != null:
			_variant_root.remove_child(fire_light)
			fire_light.free()
		if fire_smoke != null:
			_variant_root.remove_child(fire_smoke)
			fire_smoke.free()
	_update_vigil()
	return fireplace_lit


## 机制关卡 63：休眠舱（站变体室内西北角常驻）——舱体+斜开舱盖+呼吸灯发光条+检查点。
## 灯材质挂成员（pod_lamp）由 _process 驱动呼吸；选址距 window_look 1.1m / sill 1.4m。
func _build_sleep_pod() -> void:
	var pod_m := _mat(Color(0.5, 0.56, 0.64))
	_box(_variant_root, "SleepPodBody", Vector3(-2.9, 0.45, -11.05), Vector3(1.2, 0.9, 0.55), pod_m)
	_box(_variant_root, "SleepPodGlass", Vector3(-2.9, 0.98, -10.88), Vector3(1.1, 0.06, 0.24), _mat(Color(0.72, 0.8, 0.86)), false)
	pod_lamp = StandardMaterial3D.new()
	pod_lamp.albedo_color = Color(0.55, 0.75, 0.7)
	pod_lamp.emission_enabled = true
	pod_lamp.emission = Color(0.5, 0.85, 0.75)
	pod_lamp.emission_energy_multiplier = 1.1
	var lamp := MeshInstance3D.new()
	lamp.name = "SleepPodLamp"
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.9, 0.06, 0.03)
	lamp.mesh = lamp_mesh
	lamp.material_override = pod_lamp
	lamp.position = Vector3(-2.9, 0.95, -10.76)
	_variant_root.add_child(lamp)
	_variant_root.add_child(_inspectable("sleep_pod", Vector3(-2.9, 0.7, -10.55), 0.45))


## 机制关卡 64：程序生成 2 秒雨声循环（确定性 LCG 白噪声嘶嘶声；零资产依赖；
## WAV 与档位无关——重建只调音量，流缓存一次）
func _gen_rain_stream() -> void:
	var rate := 11025
	var n := int(rate * 2.0)
	var data := PackedByteArray()
	data.resize(n * 2)
	var seed64 := 1234567
	for i in n:
		seed64 = (seed64 * 1103515245 + 12345) % 2147483648
		var v := float(seed64 % 2000 - 1000) / 1000.0 * 0.35
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	wav.data = data
	rain_stream = wav


## 机制关卡 65：程序生成 5 秒叩门循环（110Hz 衰减脉冲三响 @0.2/0.55/0.9s+静音；
## 节律内嵌于流——LOOP_FORWARD 自动节律，零 _process；零资产依赖）
func _gen_knock_stream() -> AudioStreamWAV:
	var rate := 11025
	var n := int(rate * 5.0)
	var data := PackedByteArray()
	data.resize(n * 2)
	var knocks := [0.2, 0.55, 0.9]
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		for kt in knocks:
			var dt: float = t - kt
			if dt >= 0.0 and dt < 0.18:
				v += 0.85 * sin(TAU * 110.0 * dt) * exp(-dt * 22.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	wav.data = data
	return wav


## 机制关卡 68：E 上发条——播放程序旋律（演奏中=不重播；曲终/首次=重置落闩并播放）
func musicbox_wind() -> bool:
	if music_playing:
		return false
	if music_stream == null:
		_gen_music_stream()
	music_done = false
	music_playing = true
	music_box_player.stream = music_stream
	music_box_player.play()
	return true


## 机制关卡 68：程序生成 1.6 秒八音盒旋律（五声音阶随机游走 8 音符+长尾音；
## 确定性 seed——同一首曲子，每次上发条都是它；零资产依赖）
func _gen_music_stream() -> void:
	var rate := 11025
	var note_n := int(rate * 0.18)
	var tail_n := int(rate * 0.32)
	var n := note_n * 8 + tail_n
	var data := PackedByteArray()
	data.resize(n * 2)
	var scale_hz := [261.6, 293.7, 329.6, 392.0, 440.0, 523.3, 587.3, 659.3]
	var seed68 := 42
	var idx := 3
	for ni in 8:
		seed68 = (seed68 * 1103515245 + 12345) % 2147483648
		idx = clampi(idx + (int(seed68 % 3) - 1), 0, 7)
		var f: float = scale_hz[idx]
		for i in note_n:
			var t := float(i) / rate
			var env := exp(-t * 5.5)
			var v := 0.5 * (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t)) * env
			var pos := ni * note_n + i
			data.encode_s16(pos * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var f_last: float = scale_hz[idx]
	for i in tail_n:
		var t2 := float(i) / rate
		var env2 := exp(-t2 * 3.0)
		var v2 := 0.5 * (sin(TAU * f_last * t2) + 0.35 * sin(TAU * f_last * 2.0 * t2)) * env2
		data.encode_s16((note_n * 8 + i) * 2, int(clampf(v2, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	wav.data = data
	music_stream = wav


func radio_toggle() -> bool:
	radio_on = not radio_on
	var lamp := _variant_root.get_node_or_null("RadioLamp")
	if lamp != null:
		lamp.visible = radio_on
	return radio_on


## 机制关卡 40：E 椅子坐下——传送到座面并朝向桌上的信；记下坐下前位置（站起恢复用）。
## 返回 true=本次坐下（false=已坐着）。
func chair_sit(ex: Node3D) -> bool:
	if chair_sitting:
		return false
	chair_prev = ex.global_position
	chair_sitting = true
	ex.teleport_to(Vector3(-1.35, 0.52, -8.9), true)
	_update_vigil()
	return true


## 机制关卡 40：E 站起——回到坐下前的位置（不安全则用椅旁固定点）；返回 true=本次站起。
func chair_stand(ex: Node3D) -> bool:
	if not chair_sitting:
		return false
	chair_sitting = false
	var back: Vector3 = chair_prev if is_position_safe(chair_prev) else Vector3(1.1, 0.2, -7.4)
	ex.teleport_to(back, true)
	_update_vigil()
	return true


## 机制关卡 23：后院的晾衣绳。两立柱（带碰撞）+ 绳线 + 三只空木夹；E 挂上/收回所选道具
## （line_toggle 换向，ClothItem 布片颜色随 line_prop：星图微光/信件米黄/古井蓝灰/旧照片棕）。
## 重建随 _variant_root 整体撤除、挂/收状态归零；绳子纯视觉不拦路。
func _build_clothes_line(ids: Array, dried: bool = false, dried_prop: String = "") -> void:
	line_hung = dried   # 机制关卡 30：干布片在场=视为挂着（E 即收下）
	var pole_m := _mat(Color(0.42, 0.34, 0.26))
	_box(_variant_root, "LinePoleL", Vector3(1.5, 0.85, -15.8), Vector3(0.12, 1.7, 0.12), pole_m)
	_box(_variant_root, "LinePoleR", Vector3(4.2, 0.85, -15.8), Vector3(0.12, 1.7, 0.12), pole_m)
	_box(_variant_root, "LineRope", Vector3(2.85, 1.58, -15.8), Vector3(2.8, 0.03, 0.03), _mat(Color(0.72, 0.68, 0.6)), false)
	for i in 3:
		_box(_variant_root, "LinePeg%d" % i, Vector3(2.2 + i * 0.6, 1.5, -15.8), Vector3(0.04, 0.09, 0.02), _mat(Color(0.6, 0.52, 0.4)), false)
	if ids.has("note5"):
		# 机制关卡 26：温情满档收束——字条四读毕 × 温情≥2 → 木夹下压着第五张字条
		var np := MeshInstance3D.new()
		np.name = "Note5Paper"
		var npm := BoxMesh.new()
		npm.size = Vector3(0.2, 0.02, 0.16)
		np.mesh = npm
		var npmat := StandardMaterial3D.new()
		npmat.albedo_color = Color(0.93, 0.9, 0.8)
		np.material_override = npmat
		np.position = Vector3(2.5, 1.44, -15.8)
		_variant_root.add_child(np)
		_variant_root.add_child(_inspectable("note5", Vector3(2.5, 1.55, -15.8), 0.45))
	if dried:
		# 机制关卡 30：上一章挂上的道具晾了一夜——干布片（浅色、无潮气）spec 驱动生成
		var dc := MeshInstance3D.new()
		dc.name = "ClothItem"
		var dcm := BoxMesh.new()
		dcm.size = Vector3(0.34, 0.26, 0.02)
		dc.mesh = dcm
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.93, 0.88, 0.76)
		dc.material_override = dm
		dc.position = Vector3(2.6, 1.42, -15.8)
		_variant_root.add_child(dc)
	_variant_root.add_child(_inspectable("clothes_line", Vector3(2.85, 1.25, -15.8), 0.5))


## 机制关卡 23：E 挂上/收回道具（换向）。挂上时 ClothItem 布片按道具换色（星图带微光）。
func line_toggle() -> bool:
	line_hung = not line_hung
	var cloth := _variant_root.get_node_or_null("ClothItem")
	if line_hung and cloth == null:
		cloth = MeshInstance3D.new()
		cloth.name = "ClothItem"
		var cm := BoxMesh.new()
		cm.size = Vector3(0.34, 0.26, 0.02)
		cloth.mesh = cm
		var m := StandardMaterial3D.new()
		match line_prop:
			"古井":
				m.albedo_color = Color(0.45, 0.55, 0.65)
			"信件":
				m.albedo_color = Color(0.9, 0.84, 0.6)
			"星图":
				m.albedo_color = Color(0.35, 0.5, 0.9)
				m.emission_enabled = true
				m.emission = Color(0.3, 0.45, 0.9)
				m.emission_energy_multiplier = 0.5
			_:
				m.albedo_color = Color(0.6, 0.5, 0.4)
		cloth.material_override = m
		cloth.position = Vector3(2.6, 1.42, -15.8)
		_variant_root.add_child(cloth)
	elif not line_hung and cloth != null:
		_variant_root.remove_child(cloth)
		cloth.free()
	return line_hung


## 机制关卡 25：屋顶水箱与管线。科幻≥1（天线已复苏）→ 屋顶立水箱、管线沿北墙落到后院水缸；
## 档位随 sci（1=半缸暗水 / 2=满缸微光）。管线纯视觉不拦路；水缸实心可碰（选址避开既有走位带）。
func _build_sci_tank(tier: int, filled: bool) -> void:
	has_cistern = true   # 机制关卡 27：水缸在场（辘轳桶倒水的去处判定）
	var tank_m := _mat(Color(0.52, 0.58, 0.62))
	_box(_variant_root, "TankLeg1", Vector3(3.2, 3.85, -9.2), Vector3(0.08, 0.3, 0.08), tank_m, false)
	_box(_variant_root, "TankLeg2", Vector3(3.8, 3.85, -9.2), Vector3(0.08, 0.3, 0.08), tank_m, false)
	_box(_variant_root, "TankLeg3", Vector3(3.2, 3.85, -9.8), Vector3(0.08, 0.3, 0.08), tank_m, false)
	_box(_variant_root, "TankLeg4", Vector3(3.8, 3.85, -9.8), Vector3(0.08, 0.3, 0.08), tank_m, false)
	_box(_variant_root, "RoofTank", Vector3(3.5, 4.45, -9.5), Vector3(0.9, 0.9, 0.9), tank_m)
	_variant_root.add_child(_inspectable("roof_tank", Vector3(3.5, 4.85, -9.5), 0.5))
	# 管线：屋顶北沿垂直落地 → 沿地面西行 → 进水缸口（纯视觉）
	var pipe_m := _mat(Color(0.4, 0.46, 0.5))
	_box(_variant_root, "PipeDrop", Vector3(3.5, 2.0, -12.32), Vector3(0.07, 3.6, 0.07), pipe_m, false)
	_box(_variant_root, "PipeRun1", Vector3(3.5, 0.7, -14.55), Vector3(0.07, 0.07, 4.7), pipe_m, false)
	_box(_variant_root, "PipeRun2", Vector3(2.35, 0.7, -16.8), Vector3(2.5, 0.07, 0.07), pipe_m, false)
	# 水缸（实心）：档 1=半缸暗水，档 2=满缸微光
	_box(_variant_root, "Cistern", Vector3(1.2, 0.35, -16.8), Vector3(0.7, 0.7, 0.7), _mat(Color(0.45, 0.42, 0.38)))
	if tier >= 1:
		var water := MeshInstance3D.new()
		water.name = "CisternWater"
		var wm := CylinderMesh.new()
		wm.top_radius = 0.28
		wm.bottom_radius = 0.28
		wm.height = 0.05
		water.mesh = wm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.12, 0.2, 0.3)
		if tier >= 2:
			wmat.emission_enabled = true
			wmat.emission = Color(0.3, 0.5, 0.85)
			wmat.emission_energy_multiplier = 0.6
		water.material_override = wmat
		# 机制关卡 48：倒过桶水的缸跨章保持满水位（+0.06 固化）
		water.position = Vector3(1.2, (0.42 if tier < 2 else 0.62) + (0.06 if filled else 0.0), -16.8)
		_variant_root.add_child(water)
	_variant_root.add_child(_inspectable("cistern", Vector3(1.2, 1.0, -16.8), 0.5))


## 机制关卡 41：檐下燕巢。后门檐下三段渐进（stage 累积：1=新泥 2=+巢环 3=+雏鸟）；
## 纯视觉不拦路；随 nest_stage 键维逐章生长，文本由 bridge 三段分化。
func _build_nest(stage: int) -> void:
	var mud := _mat(Color(0.5, 0.4, 0.3))
	_box(_variant_root, "NestMud", Vector3(1.8, 2.5, -12.32), Vector3(0.3, 0.12, 0.18), mud, false)
	if stage >= 2:
		_box(_variant_root, "NestRing", Vector3(1.8, 2.56, -12.38), Vector3(0.34, 0.12, 0.24), _mat(Color(0.56, 0.46, 0.34)), false)
	if stage >= 3:
		_box(_variant_root, "NestChick", Vector3(1.8, 2.62, -12.38), Vector3(0.12, 0.08, 0.1), _mat(Color(0.8, 0.62, 0.45)), false)
	_variant_root.add_child(_inspectable("nest", Vector3(1.8, 2.1, -12.7), 0.45))


## 机制关卡 53：信号灯箱。天线旁安装灯箱面板（面板+绿灯发光），镇×科幻满档对称件。
## 纯检查点无 root 分支；纯视觉不拦路；随 s%d 键维重建。
func _build_signal_box() -> void:
	_box(_variant_root, "SignalBoxPanel", Vector3(0.8, 0.7, -20.2), Vector3(0.35, 0.45, 0.12), _mat(Color(0.32, 0.34, 0.4)))
	var gl := _box_glow(Vector3(0.8, 0.8, -20.13), Vector3(0.12, 0.12, 0.03), Color(0.3, 0.9, 0.4))
	gl.name = "SignalBoxGreen"
	_variant_root.add_child(gl)
	_variant_root.add_child(_inspectable("signal_box", Vector3(0.8, 0.55, -19.9), 0.4))


## 机制关卡 42：门前的脚印。南门泥地弧线脚印（纯视觉无碰撞）：悬疑 1=三枚 / 2=五枚；
## 文本=物证事实不指认来者。选址距 door_front 2.0m 射线零冲突。
func _build_footprints(tier: int) -> void:
	var mud := _mat(Color(0.32, 0.28, 0.24))
	var spots := [[0.7, -2.7, 0.12, 0.2], [1.0, -2.95, 0.12, 0.2], [0.85, -3.2, 0.12, 0.2]]
	if tier >= 2:
		spots.append_array([[1.3, -3.05, 0.12, 0.2], [1.55, -3.3, 0.12, 0.2]])
	for i in spots.size():
		_box(_variant_root, "Footprint%d" % i, Vector3(spots[i][0], 0.06, spots[i][1]), Vector3(spots[i][2], 0.02, spots[i][3]), mud, false)
	_variant_root.add_child(_inspectable("footprints", Vector3(1.1, 0.25, -3.0), 0.45))


## 机制关卡 39：后院的猫。柴堆旁盒体猫（身体/头/耳/尾，纯视觉无碰撞，不拦路不占检查射线）；
## E 摸猫（root 分支 → bridge.cat_pet 账本）；温情≥1 常驻，随 f 维重建。
func _build_yard_cat() -> void:
	var fur := _mat(Color(0.6, 0.58, 0.55))
	var white := _mat(Color(0.85, 0.83, 0.78))
	_box(_variant_root, "CatBody", Vector3(-4.5, 0.33, -15.0), Vector3(0.5, 0.26, 0.26), fur)
	_box(_variant_root, "CatHead", Vector3(-4.22, 0.46, -15.0), Vector3(0.2, 0.2, 0.2), fur)
	_box(_variant_root, "CatEarL", Vector3(-4.24, 0.58, -14.94), Vector3(0.05, 0.09, 0.05), fur, false)
	_box(_variant_root, "CatEarR", Vector3(-4.24, 0.58, -15.07), Vector3(0.05, 0.09, 0.05), fur, false)
	_box(_variant_root, "CatTail", Vector3(-4.82, 0.3, -15.02), Vector3(0.3, 0.06, 0.06), white, false)
	_box(_variant_root, "CatPaw", Vector3(-4.3, 0.22, -14.92), Vector3(0.14, 0.08, 0.1), white, false)
	_variant_root.add_child(_inspectable("yard_cat", Vector3(-4.5, 0.5, -15.0), 0.45))


func _build_station(spec: Dictionary, ids: Array) -> void:
	var town := false
	var back_open := bool(spec.get("back_open", false))
	var secret := str(spec.get("secret", ""))
	var evidence_open := str(spec.get("evidence", "")) != ""
	var combo_table := bool(spec.get("combo_table", false))
	var combo_deep := combo_table and int(spec.get("susp_tier", 0)) >= 1
	# 对接通道：两排侧墙 + 肋骨环 + 收件槽
	var wall_m := _mat(Color(0.5, 0.57, 0.68))
	_box(_variant_root, "Corr_W", Vector3(-3.0, 1.5, 9.0), Vector3(0.4, 3.0, 14.0), wall_m)
	_box(_variant_root, "Corr_E", Vector3(3.0, 1.5, 9.0), Vector3(0.4, 3.0, 14.0), wall_m)
	_box(_variant_root, "Corr_Top", Vector3(0, 3.2, 9.0), Vector3(6.4, 0.4, 14.0), _mat(Color(0.4, 0.46, 0.56)), false)
	var rib_m := _mat(Color(0.35, 0.4, 0.5))
	for i in 4:
		var rz := 4.0 + i * 3.2
		# 肋环只做视觉节奏，不带碰撞——实心肋会把整条走廊隔断（E2E 实走抓出）
		_box(_variant_root, "Rib%d" % i, Vector3(0, 3.0, rz), Vector3(6.2, 0.18, 0.3), rib_m, false)
		_box(_variant_root, "Rib%d_W" % i, Vector3(-2.9, 1.5, rz), Vector3(0.18, 3.0, 0.3), rib_m, false)
		_box(_variant_root, "Rib%d_E" % i, Vector3(2.9, 1.5, rz), Vector3(0.18, 3.0, 0.3), rib_m, false)
	# 收件槽（与小镇信箱同一功能位）
	var lk_m := _mat(Color(0.3, 0.34, 0.42))
	_box(_variant_root, "Locker", Vector3(2.4, 0.9, 2.0), Vector3(0.7, 1.8, 0.5), lk_m)
	var slot_glow := _box_glow(Vector3(2.4, 1.35, 2.28), Vector3(0.4, 0.18, 0.04), Color(0.6, 0.85, 1.0))
	_variant_root.add_child(slot_glow)
	var ins_mail := _inspectable("mail_slot", Vector3(2.4, 1.35, 2.0))
	_variant_root.add_child(ins_mail)
	if bool(spec.get("mail_flag_up", false)):
		_box(_variant_root, "MailFlagPole2", Vector3(2.68, 1.7, 1.78), Vector3(0.03, 0.34, 0.03), _mat(Color(0.4, 0.4, 0.42)), false)
		_box(_variant_root, "MailFlagCloth2", Vector3(2.76, 1.8, 1.78), Vector3(0.16, 0.1, 0.02), _mat(Color(0.85, 0.3, 0.25)), false)
	_build_building(spec, ids, false)
	# 机制关卡 34：舷窗外的星（空间站专属，科幻≥1；档位=板数，秘密落定文本分化）
	if ids.has("porthole_star"):
		_build_porthole_star(clampi(int(spec.get("sci_tier", 0)), 0, 3), bool(spec.get("porthole_frost", false)), bool(spec.get("porthole_wiped", false)), bool(spec.get("sky_blue_dot", false)))
	var ins_door := _inspectable("door_front", Vector3(0, 1.4, BUILD.position.y + BUILD.size.y + 0.5))
	_variant_root.add_child(ins_door)
	# 走廊尽头设备块（碰撞保留原盒）+ 套件桶点缀
	_box(_variant_root, "EquipRack", Vector3(-8.0, 0.6, 12.0), Vector3(1.2, 1.2, 2.2), _mat(Color(0.34, 0.38, 0.47)))
	_kit_model("barrel", "KitBarrel1", Vector3(2.6, 0.0, 15.0), 0.0)
	_kit_model("barrel", "KitBarrel2", Vector3(-2.4, 0.0, 15.2), 55.0, Vector3(0.9, 0.9, 0.9))
	if back_open:
		_build_backzone(true, secret, ids, bool(spec.get("airlock_water", false)), str(spec.get("case_mark", "")))
		_build_ladder(false, ids)


## 后山区（第 3 章起）：档案架+三份记录+字条 → 通往后山围栏与「气闸」门；
## 已解释（flags.secret）时围栏开门进入同一舱室的不同内饰（飞船/矿井互斥，A→B 随事务换装）
## 机制关卡 21：屋脊风铃——三根小管悬于横杆，风档越高摆幅越大
func _build_wind_chime(town: bool) -> void:
	## 北坡屋檐东段（远离梯顶垫点与回响字条——垫点 r0.9 会吞掉近距射线，选址实证后定此）
	var chime_m := _mat(Color(0.75, 0.7, 0.55) if town else Color(0.6, 0.68, 0.78))
	var group := Node3D.new()
	group.name = "ChimeGroup"
	group.position = Vector3(-2.2, 4.0, -10.5)
	_variant_root.add_child(group)
	var bar := MeshInstance3D.new()
	bar.name = "ChimeBar"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.06, 0.06)
	bar.mesh = bm
	bar.material_override = chime_m
	bar.position = Vector3(0, 0.35, 0)
	group.add_child(bar)
	for i in 3:
		var tube := MeshInstance3D.new()
		tube.name = "ChimeTube%d" % i
		var cm := BoxMesh.new()
		cm.size = Vector3(0.04, 0.3 - i * 0.05, 0.04)
		tube.mesh = cm
		tube.material_override = chime_m
		tube.position = Vector3(0.15 - i * 0.15, 0.16, 0)
		group.add_child(tube)
	_variant_root.add_child(_inspectable("wind_chime", Vector3(-2.2, 4.0, -10.5), 0.45))


func _build_backzone(is_station: bool, secret: String, ids: Array, water: bool, case_mark: String = "") -> void:
	var wood_m := _mat(Color(0.42, 0.34, 0.26) if not is_station else Color(0.36, 0.4, 0.5))
	# 后院小径
	_box(_variant_root, "BackPath", Vector3(0, 0.05, -16.0), Vector3(3.0, 0.1, 8.0), _mat(Color(0.45, 0.42, 0.38) if not is_station else Color(0.4, 0.44, 0.52)), false)
	# 档案架 ×2 + 三份记录
	_box(_variant_root, "Shelf1", Vector3(2.8, 0.9, -13.0), Vector3(0.6, 1.8, 2.4), wood_m)
	_box(_variant_root, "Shelf2", Vector3(4.5, 0.9, -13.0), Vector3(0.6, 1.8, 2.4), wood_m)
	_variant_root.add_child(_inspectable("record_1", Vector3(2.8, 1.2, -13.0)))
	_variant_root.add_child(_inspectable("record_2", Vector3(4.5, 1.2, -13.0)))
	_box(_variant_root, "RecordTable", Vector3(5.6, 0.45, -13.0), Vector3(1.0, 0.9, 0.8), wood_m)
	_variant_root.add_child(_inspectable("record_3", Vector3(5.6, 1.05, -13.0)))
	# 字条座
	_box(_variant_root, "NotePedestal", Vector3(2.5, 0.45, -14.0), Vector3(0.6, 0.9, 0.6), wood_m)
	_variant_root.add_child(_inspectable("note_paper", Vector3(2.5, 1.05, -14.0)))
	if case_mark != "" and ids.has("case_mark"):
		# 机制关卡 28：改写留下的实物——echo 槽写下的那句话在档案架南面留下实物（红标卷宗灰模）
		# 选址 (3.4,1.0,-11.6)：距 record_1 1.53m（r0.9 球不吞射线，巡检治理同款原则）
		_box(_variant_root, "CaseMarkItem", Vector3(3.3, 0.85, -11.9), Vector3(0.5, 0.3, 0.35), _mat(Color(0.55, 0.2, 0.18)))
		_box(_variant_root, "CaseMarkTag", Vector3(3.3, 1.02, -11.72), Vector3(0.12, 0.08, 0.02), _mat(Color(0.9, 0.86, 0.7)), false)
		_variant_root.add_child(_inspectable("case_mark", Vector3(3.4, 1.0, -11.6), 0.45))
	# 围栏与气闸门线
	var fence_m := _mat(Color(0.3, 0.3, 0.34) if not is_station else Color(0.34, 0.4, 0.5))
	if secret == "":
		# 未解释：整排围栏封死，门扇关闭带碰撞（推不开是真的推不开）；门扇视觉=套件 gate_frame
		_box(_variant_root, "Fence_L", Vector3(-5.1, 1.1, FENCE_Z), Vector3(7.8, 2.2, 0.3), fence_m)
		_box(_variant_root, "Fence_R", Vector3(5.1, 1.1, FENCE_Z), Vector3(7.8, 2.2, 0.3), fence_m)
		_box_collide_only("Fence_Door", Vector3(0, 1.15, FENCE_Z), Vector3(2.4, 2.3, 0.25))
		_kit_model("gate_frame", "KitGateDoor", Vector3(0, 0.0, FENCE_Z), 0.0, Vector3(1.09, 0.96, 1.0))
		_box(_variant_root, "Fence_DoorStripe", Vector3(0, 1.9, FENCE_Z - 0.16), Vector3(2.0, 0.18, 0.02), _mat(Color(0.9, 0.7, 0.2), 0.5), false)
	else:
		# 已解释：门扇敞开（套件 gate_frame 转轴让位），门洞可走入围栏后的解释舱室
		_box(_variant_root, "Fence_L", Vector3(-5.1, 1.1, FENCE_Z), Vector3(7.8, 2.2, 0.3), fence_m)
		_box(_variant_root, "Fence_R", Vector3(5.1, 1.1, FENCE_Z), Vector3(7.8, 2.2, 0.3), fence_m)
		_kit_model("gate_frame", "KitGateDoor", Vector3(1.5, 0.0, FENCE_Z + 0.9), -68.0, Vector3(1.09, 0.96, 1.0))
	if ids.has("airlock_door"):
		_variant_root.add_child(_inspectable("airlock_door", Vector3(0, 1.3, FENCE_Z)))
	if secret != "":
		_build_chamber(secret, is_station)
	if water:
		# 机制关卡 19：气闸室的井水（温情×证物×悬疑×秘密 四线收束）
		var wb2 := MeshInstance3D.new()
		wb2.name = "AirWaterBowl"
		var wb2m := BoxMesh.new()
		wb2m.size = Vector3(0.2, 0.09, 0.2)
		wb2.mesh = wb2m
		var wb2mat := StandardMaterial3D.new()
		wb2mat.albedo_color = Color(0.35, 0.55, 0.8)
		wb2mat.emission_enabled = true
		wb2mat.emission = Color(0.3, 0.5, 0.8)
		wb2mat.emission_energy_multiplier = 0.5
		wb2.material_override = wb2mat
		wb2.position = Vector3(-1.9, 0.42, -22.3)
		_variant_root.add_child(wb2)
		_variant_root.add_child(_inspectable("airlock_water", Vector3(-1.9, 0.72, -22.3)))
	if ids.has("airlock_room"):
		# 机制关卡 18：围栏外气闸室（可走进去）
		_build_airlock_room(secret, is_station, water)


## 机制关卡 18：围栏外气闸室。秘密落定后气闸门开，可穿过围栏抵达。
## 文本随双解释分化（colony=登船闸内衬+星图复写 / mine=风封条+旧罗盘）。
func _build_airlock_room(secret: String, is_station: bool, water: bool) -> void:
	var wall_m := _mat(Color(0.42, 0.46, 0.54) if not is_station else Color(0.38, 0.44, 0.54))
	_box(_variant_root, "AirWall_W", Vector3(-2.4, 1.3, -22.6), Vector3(0.3, 2.6, 2.2), wall_m)
	_box(_variant_root, "AirWall_E", Vector3(2.4, 1.3, -22.6), Vector3(0.3, 2.6, 2.2), wall_m)
	_box(_variant_root, "AirWall_N", Vector3(0, 1.3, -23.6), Vector3(5.1, 2.6, 0.3), wall_m)
	_box(_variant_root, "AirRoof", Vector3(0, 2.7, -22.6), Vector3(5.2, 0.2, 2.5), _mat(Color(0.42, 0.48, 0.58)), false)
	var al := OmniLight3D.new()
	al.name = "AirLockLight"
	al.position = Vector3(0, 2.2, -22.6)
	al.omni_range = 5.0
	al.light_energy = 0.9
	al.light_color = Color(0.7, 0.85, 1.0) if secret == "colony_ship" else Color(1.0, 0.8, 0.6)
	_variant_root.add_child(al)
	_box(_variant_root, "AirCrate", Vector3(1.6, 0.4, -22.9), Vector3(0.7, 0.8, 0.7), _mat(Color(0.4, 0.36, 0.3)))
	_variant_root.add_child(_inspectable("airlock_room", Vector3(0, 1.1, -22.8)))
	if water:
		# 机制关卡 19：气闸室的井水（四线收束）
		var wb3 := MeshInstance3D.new()
		wb3.name = "AirWaterBowl"
		var wb3m := BoxMesh.new()
		wb3m.size = Vector3(0.2, 0.09, 0.2)
		wb3.mesh = wb3m
		var wb3mat := StandardMaterial3D.new()
		wb3mat.albedo_color = Color(0.35, 0.55, 0.8)
		wb3mat.emission_enabled = true
		wb3mat.emission = Color(0.3, 0.5, 0.8)
		wb3mat.emission_energy_multiplier = 0.5
		wb3.material_override = wb3mat
		wb3.position = Vector3(-1.9, 0.42, -22.3)
		_variant_root.add_child(wb3)
		_variant_root.add_child(_inspectable("airlock_water", Vector3(-1.9, 0.72, -22.3)))


## 终稿落点（第 5 章）：主基调决定位置——科幻=街边投递台 / 温情=室内饭桌 / 悬疑=后院井台
## 机制关卡 21：风铃风档循环——E 推进三档风（0=静 1=微风 2=风起），摆幅随档位变化
func wind_cycle() -> int:
	wind_level = (wind_level + 1) % 3
	wind_apply_level()
	return wind_level


func wind_apply_level() -> void:
	var group := _variant_root.get_node_or_null("ChimeGroup")
	if group != null:
		group.rotation.x = -0.12 * wind_level
		group.rotation.z = 0.08 * wind_level
	# 机制关卡 31：全局风——晾着的布片被掀、井台雾偏移（表现层联动，随档位复位）
	var cloth := _variant_root.get_node_or_null("ClothItem")
	if cloth != null:
		cloth.rotation.y = 0.35 * wind_level
		cloth.position.x = 2.6 - 0.05 * wind_level
	var mist := _variant_root.get_node_or_null("Well_Mist")
	if mist != null:
		mist.position.x = -2.5 + 0.3 * wind_level
	# 机制关卡 74：风筝随风（家族第三成员：铃/布/雾/风筝）
	var kite74 := _variant_root.get_node_or_null("TreeKite")
	if kite74 != null:
		kite74.rotation.z = PI / 4 + 0.15 * wind_level
		kite74.position.x = 9.8 + 0.08 * wind_level


## 机制关卡 20：E 校准循环——档位推进并实时转动镜筒（0=目镜 1=月亮 2=后山）
func telescope_cycle() -> int:
	telescope_aim = (telescope_aim + 1) % 3
	telescope_apply_aim()
	return telescope_aim


## 按档位转动镜筒：0=持平目镜 1=月亮（上仰） 2=后山（下俯）
func telescope_apply_aim() -> void:
	var tube := _variant_root.get_node_or_null("TelescopeTube")
	if tube == null:
		return
	match telescope_aim:
		1:
			tube.rotation.x = -0.9
		2:
			tube.rotation.x = 0.4
		_:
			tube.rotation.x = -0.5


func _build_ending_spot_in_root(dom: String, is_station: bool, ids: Array) -> void:
	if not ids.has("ending_spot"):
		return
	var wood_m := _mat(Color(0.5, 0.4, 0.28) if not is_station else Color(0.4, 0.46, 0.56))
	match dom:
		"sci":
			_box(_variant_root, "EndSpotTable", Vector3(4.0, 0.35, 8.0), Vector3(1.4, 0.7, 1.0), _mat(Color(0.34, 0.42, 0.55)))
			_box(_variant_root, "EndSpotPole", Vector3(4.6, 1.3, 8.0), Vector3(0.1, 1.6, 0.1), _mat(Color(0.3, 0.34, 0.42)))
			_box(_variant_root, "EndSpotLamp", Vector3(4.6, 2.2, 8.0), Vector3(0.22, 0.22, 0.22), _mat(Color(0.5, 0.8, 1.0), 1.2), false)
			_variant_root.add_child(_inspectable("ending_spot", Vector3(4.0, 1.05, 8.0)))
		"warm":
			_box(_variant_root, "EndSpotTable", Vector3(-3.5, 0.375, -6.5), Vector3(1.8, 0.75, 1.0), wood_m)
			_box(_variant_root, "EndSpotBowl1", Vector3(-3.9, 0.8, -6.5), Vector3(0.22, 0.08, 0.22), _mat(Color(0.9, 0.85, 0.75)), false)
			_box(_variant_root, "EndSpotBowl2", Vector3(-3.1, 0.8, -6.6), Vector3(0.22, 0.08, 0.22), _mat(Color(0.9, 0.85, 0.75)), false)
			var el := OmniLight3D.new()
			el.name = "EndSpotLight"
			el.position = Vector3(-3.5, 2.2, -6.5)
			el.light_color = Color(1.0, 0.8, 0.55)
			el.omni_range = 6.0
			el.light_energy = 0.9
			_variant_root.add_child(el)
			_variant_root.add_child(_inspectable("ending_spot", Vector3(-3.5, 1.05, -6.5)))
		_:
			# 悬疑终稿：镇上与井台进化共用同一口井（有 Well_Base 则只添红布，不重复建井）
			if not _variant_root.has_node("Well_Base"):
				_box(_variant_root, "EndSpotWell", Vector3(-2.5, 0.35, -17.5), Vector3(1.6, 0.7, 1.6), _mat(Color(0.45, 0.44, 0.42)))
			_box(_variant_root, "EndSpotRedCloth", Vector3(-2.5, 0.88, -17.5), Vector3(1.2, 0.06, 0.1), _mat(Color(0.8, 0.15, 0.15), 0.3), false)
			_variant_root.add_child(_inspectable("ending_spot", Vector3(-2.5, 1.05, -17.5)))


## 解释舱室：同一空间两种互斥内饰（A→B 由重建键触发整体换装），证物各不同
func _build_chamber(secret: String, is_station: bool) -> void:
	var wall_m := _mat(Color(0.32, 0.3, 0.28))
	_box(_variant_root, "Cham_W", Vector3(-8.0, 1.3, -23.5), Vector3(0.4, 2.6, 7.4), wall_m)
	_box(_variant_root, "Cham_E", Vector3(8.0, 1.3, -23.5), Vector3(0.4, 2.6, 7.4), wall_m)
	_box(_variant_root, "Cham_N", Vector3(0, 1.3, -27.0), Vector3(16.4, 2.6, 0.4), wall_m)
	var light := OmniLight3D.new()
	light.name = "ChamberLight"
	light.position = Vector3(0, 2.2, -24)
	light.omni_range = 10.0
	if secret == "colony_ship":
		# 飞船说：舱内走道——冷光、储物柜、登船闸控制台
		_box(_variant_root, "Cham_Floor", Vector3(0, 0.03, -23.5), Vector3(16.4, 0.06, 7.4), _mat(Color(0.22, 0.26, 0.34)), false)
		_box(_variant_root, "ShipLocker1", Vector3(-4.0, 0.7, -22.0), Vector3(1.2, 1.4, 0.6), _mat(Color(0.4, 0.48, 0.6)))
		_box(_variant_root, "ShipLocker2", Vector3(3.5, 0.7, -22.0), Vector3(1.2, 1.4, 0.6), _mat(Color(0.4, 0.48, 0.6)))
		_box(_variant_root, "ShipConsole", Vector3(0, 0.55, -25.5), Vector3(2.4, 1.1, 0.7), _mat(Color(0.3, 0.42, 0.58)))
		_box(_variant_root, "ShipConsoleGlow", Vector3(0, 1.16, -25.5), Vector3(2.0, 0.08, 0.5), _mat(Color(0.5, 0.8, 1.0), 1.1), false)
		_box(_variant_root, "ShipHatch", Vector3(0, 1.2, -26.7), Vector3(1.8, 2.0, 0.15), _mat(Color(0.42, 0.6, 0.8), 0.5))
		_kit_model("iron_block", "KitCargo1", Vector3(-5.8, 0.0, -24.6), 0.0)
		_kit_model("crate", "KitCargo2", Vector3(5.2, 0.0, -24.8), 25.0)
		_variant_root.add_child(_inspectable("ship_proof", Vector3(0, 1.5, -25.5)))
		_variant_root.add_child(_inspectable("secret_tail", Vector3(0, 1.2, -26.2)))
		light.light_color = Color(0.6, 0.8, 1.0)
		light.light_energy = 1.1
	else:
		# 矿井说：防爆门后的记录间——暖暗光、支撑木架、矿车、停工记录
		_box(_variant_root, "Cham_Floor", Vector3(0, 0.03, -23.5), Vector3(16.4, 0.06, 7.4), _mat(Color(0.28, 0.24, 0.2)), false)
		for i in 4:
			var px := -3.0 + (i % 2) * 6.0
			var pz := -21.5 if i < 2 else -25.5
			_box(_variant_root, "Beam%d" % i, Vector3(px, 1.3, pz), Vector3(0.25, 2.6, 0.25), _mat(Color(0.4, 0.32, 0.22)))
		_box(_variant_root, "MineCart", Vector3(2.5, 0.45, -23.0), Vector3(1.4, 0.9, 0.9), _mat(Color(0.36, 0.3, 0.26)))
		_kit_model("barrel", "KitMineBarrel", Vector3(4.6, 0.0, -23.2), 0.0)
		_box(_variant_root, "MineTable", Vector3(-2.5, 0.45, -25.0), Vector3(1.4, 0.9, 0.8), _mat(Color(0.42, 0.34, 0.26)))
		_box(_variant_root, "MineInnerDoor", Vector3(0, 1.0, -26.7), Vector3(1.4, 2.0, 0.15), _mat(Color(0.3, 0.26, 0.22)))
		_box(_variant_root, "MineInnerGlow", Vector3(0, 1.6, -26.6), Vector3(0.5, 0.12, 0.04), _mat(Color(1.0, 0.75, 0.4), 0.9), false)
		_variant_root.add_child(_inspectable("mine_proof", Vector3(-2.5, 1.05, -25.0)))
		_variant_root.add_child(_inspectable("secret_tail", Vector3(0, 1.2, -26.2)))
		light.light_color = Color(1.0, 0.75, 0.5)
		light.light_energy = 0.9
	_variant_root.add_child(light)


func _box_glow(pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _mat(col, 1.2)
	mi.position = pos
	return mi


## 机制关卡 34：舷窗外的星（空间站专属，科幻≥1）。东墙内侧发光板：档1 一块慢闪，
## 档2 两块错位（双闪节奏）；秘密落定文本三分化。选址距 mail_slot 4m，射线零冲突。
func _build_porthole_star(tier: int, frost: bool, wiped: bool, blue_dot: bool) -> void:
	_variant_root.add_child(_box_glow(Vector3(2.76, 1.7, 6.0), Vector3(0.05, 0.5, 0.5), Color(0.65, 0.8, 1.0)))
	if blue_dot:
		# 机制关卡 75：舷窗外的蓝点（站×解释落定——同一光点两种世界观；认知门控：
		# colony=地球（不闪不动，你认得）/ mine=矿灯（这个时辰不该亮）——纯视觉不泄底）
		var dot75 := StandardMaterial3D.new()
		dot75.albedo_color = Color(0.35, 0.55, 0.85)
		dot75.emission_enabled = true
		dot75.emission = Color(0.4, 0.6, 0.9)
		dot75.emission_energy_multiplier = 1.4
		var dotm75 := MeshInstance3D.new()
		dotm75.name = "SkyBlueDot"
		var dotmesh := BoxMesh.new()
		dotmesh.size = Vector3(0.07, 0.07, 0.07)
		dotm75.mesh = dotmesh
		dotm75.material_override = dot75
		dotm75.position = Vector3(2.76, 2.05, 6.3)
		_variant_root.add_child(dotm75)
	if tier >= 2:
		_variant_root.add_child(_box_glow(Vector3(2.76, 1.55, 6.55), Vector3(0.05, 0.35, 0.35), Color(0.55, 0.75, 1.0)))
	if frost and not wiped:
		var fp := MeshInstance3D.new()
		fp.name = "PortholeFrost"
		var fpm := BoxMesh.new()
		fpm.size = Vector3(0.04, 0.62, 0.62)
		fp.mesh = fpm
		var fpmat := StandardMaterial3D.new()
		fpmat.albedo_color = Color(0.85, 0.9, 0.95, 0.72)
		fpmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fp.material_override = fpmat
		fp.position = Vector3(2.74, 1.7, 6.0)
		_variant_root.add_child(fp)
	frost_present = frost and not wiped
	_variant_root.add_child(_inspectable("porthole_star", Vector3(2.4, 1.7, 6.0), 0.5))
