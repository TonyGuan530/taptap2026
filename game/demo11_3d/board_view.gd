extends Node3D
## DEMO11 3D 地形视图：把规则核心的整数格子画成几何体。
## 场景应用约定（用户指令 2026-10-04）：分支一律基于 3d-shared，本文件不复制套件、不自带美术资产——
## 压力板/门用 comic_style 的 ModelLibrary ComicObject 模型，地形用统一 comic 材质（plain_toon 着色族）。
## 表现约定（指南 §4）：旧格 (x,y) → 世界 Vector3((x+0.5)*CELL, 高度, (y+0.5)*CELL)，CELL=1；
## 世界 Y 只表现高度。遮挡墙用低墙表现，规则墙仍在核心 grid。本类只读核心状态，不写格子。

const ComicStyle := preload("res://comic_style/comic_style.gd")
const ModelLibrary := preload("res://comic_style/model_library.gd")

const ROOM_W := 12
const ROOM_H := 7
const CELL := 1.0

# 地形统一色板（comic 材质族；物体色板以 ModelLibrary.COLORS 为准）
const TERRAIN_COLORS := {
	"floor_0": Color("39435a"), "floor_1": Color("343d53"), "wall": Color("232b3d"),
	"water": Color("1e4e74"), "pit": Color("0b0d14"), "bridge": Color("cf8958"),
	"fill": Color("6b5f40"), "ice": Color("a8d8ef"),
	"gate_base_closed": Color("3d3320"), "gate_base_open": Color("f5ce7a"),
	"door_closed": Color("8c3b47"), "switch_ring": Color("e8b45c"),
	"switch_ring_not": Color("6f9fd8"),  # 反相板蓝环以示区分
	"switch_ring_heavy": Color("8a919e"),  # 重压板钢灰环（EXT-10，仅铁可压）
	"switch_ring_latch": Color("8fd89f"),  # 自锁踏板亮绿环（EXT-18）
	"switch_face_latch": Color("6fcf7f"),  # 自锁踏板锁定绿面
	"switch_ring_double": Color("d8c88f"),  # 双踩板淡金环（EXT-50，未满二为淡金面）

	"thin_ice": Color("8fbcd4"),  # 薄冰：暗于永久冰（a8d8ef），且更薄
	"crack_line": Color("4a7a94"),  # 薄冰裂纹线（暗于薄冰底色）
	"reset_stone": Color("5a6068"),  # 重置石：石灰色板（视觉区分普通地板）
	"reset_ring": Color("c8b896"),  # 重置石中央圆环（ EXT-6）
	"oneway_base": Color("4a4258"),  # 单向阀格：暗琥珀紫板（区别于普通地板，EXT-8）
	"oneway_arrow": Color("e8b45c"),  # 单向阀箭头（amber，与开关环同族高亮）
	"portal_base": Color("4a3d66"),  # 传送对格：暗紫板（EXT-9，成对同色）
	"portal_ring": Color("9fd8e8"),  # 传送对格亮环（冰青，与暗紫板成对醒目）
	"slide_ice": Color("c9ecfa"),  # 滑冰格：淡于永久冰的亮面（EXT-12，流纹白线标识）
	"slide_streak": Color("eef9ff"),  # 滑冰格流纹（顺滑向的细白条）
	"phase_base": Color("3a4460"),  # 相位门底座：冷蓝板（EXT-13）
	"phase_bar": Color("7a8fb8"),  # 相位门栏栅（闭相可见的立柱）
	"phase_bar_inv": Color("c88f5a"),  # 反相门栏栅：暖琥珀柱（EXT-15，与正相钢蓝区分拍子）
	"pbridge_base": Color("56628a"),  # 相位桥桥板：蓝灰填土面（EXT-24，开窗可走的视觉）
	"launcher_base": Color("1f5f5f"),  # 弹射垫：深青板（EXT-26，与苔绿弹簧垫区分）
	"launcher_ring": Color("63d6c4"),  # 弹射垫圆环：亮青环（货物弹射方向感）
	"link_base": Color("274766"),  # 联动桥位：断开时暗水蓝（EXT-27；压住时 refresh_state 调成填土暖色）
	"link_ring": Color("7fb8d8"),  # 联动桥位圆环：冷蓝环（桥位标记）
	"switch_ring_link": Color("9f8fd8"),  # 联动开关紫环（EXT-27，压住的不是门而是桥）
	"key_base": Color("4a4436"),  # 钥匙格：暖沙暗底（EXT-36，金色钥匙环的衬底）
	"key_gold": Color("d8b04a"),  # 钥匙环金色（信物高亮；锁孔点同色呼应）
	"lock_base": Color("4a3a34"),  # 锁门底座：锈暗板（EXT-36，与压力板门红金区分）
	"lock_door": Color("8a4a3a"),  # 锁门锈红门体（无钥匙时的心事）
	"tgate_base": Color("274766"),  # 潮闸底座：石青板（EXT-43，潮相位驱动的通道闸）
	"tgate_bar": Color("3a2a2a"),  # 潮闸横杆：闭窗暗杆（开窗被 set_tide_gate_state 翻潮青）
	"key_silver": Color("c8cdd8"),  # 银钥环银灰（EXT-42，与金钥色温区分）
	"lock_s_base": Color("3a4048"),  # 银门底座：钢暗板（EXT-42，通道门非终点）
	"lock_s_door": Color("b8bec8"),  # 银门银灰门体
	"ivy_base": Color("3d6b45"),  # 藤蔓墙：苔绿墙体（EXT-37，玩家可攀越的墙）
	"ivy_vine": Color("6fae6f"),  # 藤蔓墙亮藤条纹（攀越抓手的高亮暗示）
	"well_ring": Color("9fe8d8"),  # 换相井双环：冰青（EXT-39，相位机关的踏板）
	"belt_base": Color("2a3038"),  # 输送带：暗金属带面（EXT-40，时间驱动的货运地形）
	"belt_arrow": Color("8a97a8"),  # 输送带箭羽：顺带向的钢灰箭头
	"spring_base": Color("3f6b46"),  # 弹簧垫：苔绿底座（EXT-14）
	"spring_ring": Color("a8d8a0"),  # 弹簧垫浅绿环（弹射方向居中圆环）
	"crumble_base": Color("5a4a3a"),  # 脆壁：裂纹暗褐墙（EXT-20）
	"crumble_line": Color("2a2018"),  # 脆壁裂纹线（深于底色）
	"grease_base": Color("3a2f4a"),  # 油道：暗紫油面（EXT-29，木箱滑道的视觉）
	"grease_streak": Color("8a6ab8"),  # 油道油光（顺滑向的细紫条）
	"stub_base": Color("5a6a7a"),  # 推塌桩：灰蓝假墙（EXT-34，比真墙浅、有裂纹暗示可推塌）
	"stub_line": Color("2a3440"),  # 推塌桩裂纹线（深于底色）
	"tide_base": Color("1e4e74"),  # 潮汐格：淹没时水蓝（EXT-31；露出时 refresh/main 调湿泥绿）
	"tide_foam": Color("9fd8c8"),  # 潮汐格泡沫环（潮格标记，常显）
	"tide_late_base": Color("6a5a1e"),  # 反相潮汐格：闭窗时暗琥珀水（EXT-33；开窗时调暖沙色）
	"tide_late_foam": Color("d8c89f"),  # 反相潮汐格泡沫环：琥珀环（与 u 冷蓝环区分相位）
	"slot_frame": Color("454060"),  # 暗缝：缝框冷紫灰（比墙浅半档，暗示中空）（EXT-22）
	"slot_gap": Color("14101e"),  # 暗缝：缝身近黑（窄于箱/铁的视觉信号）
	"latch_ring": Color("8fd89f"),  # 自锁踏板亮绿环（EXT-18，锁定后变压下面）
	"latch_face": Color("6fcf7f"),  # 自锁踏板锁定绿面
	"vent_base": Color("4a3038"),  # 间歇泉：暗红热岩板（EXT-17）
	"vent_glow": Color("e8935a"),  # 间歇泉热辉（中央热斑）
	"cold_base": Color("2f4a5a"),  # 寒泉：冰蓝冷岩板（EXT-19）
	"cold_glow": Color("a8d8ef"),  # 寒泉冷辉（中央霜斑）
}
const SWITCH_PRESSED_COLOR := Color("7f9e67")  # 压下反馈（leaf）
const SWITCH_RING_COLOR := Color("e8b45c")     # 贴地边缘环（amber）：被箱/铁压住时环仍露出可见

# 高度：可走面顶 y=0；水面低于地板；深坑明显更低；冰/桥/填土与地板齐平
const TOP_Y := 0.0
const WATER_TOP := -0.14
const PIT_TOP := -0.45
const WALL_TOP := 0.55   # 低墙：遮挡表现，非规则高度

var _tiles := {}       # "x,y" -> MeshInstance3D（格基座）
var _switches := {}    # "x,y" -> {model: ComicObject, top: MeshInstance3D}
var _gates := {}       # "x,y" -> {frame: Node3D, door: Node3D, base: MeshInstance3D}
var _phase_bars: Array = []  # EXT-13 正相门栏栅节点（闭相可见）
var _phase_bars_inv: Array = []  # EXT-15 反相门栏栅节点（正相门开时可见）
var _mats := {}        # 色名 -> ShaderMaterial 缓存（统一 comic 材质）
var _style: Resource


func _ready() -> void:
	_style = ComicStyle.new()


func cell_to_world(x: int, y: int, top: float = TOP_Y) -> Vector3:
	return Vector3((x + 0.5) * CELL, top, (y + 0.5) * CELL)


func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / CELL)), int(floor(pos.z / CELL)))


func _body_mat(color_key: String) -> ShaderMaterial:
	if not _mats.has(color_key):
		_mats[color_key] = _style.body_material(TERRAIN_COLORS[color_key])
	return _mats[color_key]


func _clear_all() -> void:
	for c in get_children():
		c.queue_free()
	_tiles.clear()
	_switches.clear()
	_gates.clear()
	_phase_bars.clear()
	_phase_bars_inv.clear()


## EXT-13/15 相位门开合切换（栏栅在各自闭相可见；main_3d 每帧轮询两相变化后调用）
func set_phase_state(z_open: bool, z_inv_open: bool) -> void:
	for bar in _phase_bars:
		if bar != null:
			bar.visible = not z_open
	for bar in _phase_bars_inv:
		if bar != null:
			bar.visible = not z_inv_open


## EXT-31/33 潮汐格双态：露出=湿泥绿（可走）/ 淹没=水蓝（断）——main 每帧沿轮询驱动
## 反相潮汐格：开窗 [2,6)=暖沙色（可走）/ 闭窗=暗琥珀水（断）
func set_tide_state(open: bool, late_open: bool) -> void:
	_body_mat("tide_base").set_shader_parameter("base_color",
		Color("6a7a4a") if open else Color("1e4e74"))
	_body_mat("tide_late_base").set_shader_parameter("base_color",
		Color("c8b47a") if late_open else Color("6a5a1e"))


## EXT-43 潮闸双态：开窗=潮青横杆（可通行）/ 闭窗=暗杆（拒）——main 每帧沿轮询驱动
func set_tide_gate_state(open: bool) -> void:
	_body_mat("tgate_bar").set_shader_parameter("base_color",
		Color("63c8c8") if open else Color("3a2a2a"))


## 全量重建（房间装载/过房后调用；只读 rules）
func build(rules) -> void:
	_clear_all()
	for y in ROOM_H:
		for x in ROOM_W:
			_build_tile(x, y, String(rules.grid[rules._idx(x, y)]), rules)
	for o in rules.objects:
		var od: Dictionary = o
		if String(od.type) == "switch" or String(od.type) == "switch_not" or String(od.type) == "switch_heavy" or String(od.type) == "switch_latch" or String(od.type) == "switch_double":
			_build_switch(int(od.x), int(od.y), String(od.type))
	refresh_state(rules)


func _build_tile(x: int, y: int, tile: String, rules) -> void:
	var old = _tiles.get("%d,%d" % [x, y])
	if old != null:
		old.queue_free()
	var mi := MeshInstance3D.new()
	mi.name = "T_%d_%d" % [x, y]
	var box := BoxMesh.new()
	var top := TOP_Y
	match tile:
		"wall":
			box.size = Vector3(0.96, WALL_TOP, 0.96)
			top = WALL_TOP
			mi.material_override = _body_mat("wall")
		"cracked_wall":
			# EXT-11 裂纹墙：墙体略矮于普通墙 + 顶面交叉裂纹线（可烧毁的暗示）
			box.size = Vector3(0.96, WALL_TOP - 0.08, 0.96)
			top = WALL_TOP - 0.08
			mi.material_override = _body_mat("wall")
			for i in 2:
				var cw_crack := MeshInstance3D.new()
				cw_crack.name = "WallCrack%d" % i
				var cwb := BoxMesh.new()
				cwb.size = Vector3(0.7, 0.02, 0.08)
				cw_crack.mesh = cwb
				cw_crack.material_override = _body_mat("crack_line")
				cw_crack.rotation_degrees = Vector3(0, -35.0 + 70.0 * i, 0)
				cw_crack.position = Vector3(0, WALL_TOP - 0.03, 0)
				mi.add_child(cw_crack)
		"water":
			box.size = Vector3(0.96, 0.5, 0.96)
			top = WATER_TOP
			mi.material_override = _body_mat("water")
		"pit":
			box.size = Vector3(0.96, 0.2, 0.96)
			top = PIT_TOP
			mi.material_override = _body_mat("pit")
		"bridge":
			box.size = Vector3(0.96, 0.2, 0.96)
			mi.material_override = _body_mat("bridge")
		"fill":
			box.size = Vector3(0.96, 0.2, 0.96)
			mi.material_override = _body_mat("fill")
		"ice":
			box.size = Vector3(0.96, 0.2, 0.96)
			mi.material_override = _body_mat("ice")
		"thin_ice":
			box.size = Vector3(0.96, 0.14, 0.96)
			top = TOP_Y - 0.02
			mi.material_override = _body_mat("thin_ice")
			# 裂纹线：两条交叉的暗色细条（规格 §1 承诺的裂纹视觉）
			for i in 2:
				var crack := MeshInstance3D.new()
				crack.name = "Crack%d" % i
				var cb := BoxMesh.new()
				cb.size = Vector3(0.9, 0.02, 0.06)
				crack.mesh = cb
				crack.material_override = _body_mat("crack_line")
				crack.rotation_degrees = Vector3(0, -35.0 + 70.0 * i, 0)
				crack.position = Vector3(0, 0.09, 0)
				mi.add_child(crack)
		"reset_stone":
			box.size = Vector3(0.96, 0.16, 0.96)
			mi.material_override = _body_mat("reset_stone")
			# 中央圆环凸起：与普通地板区分（EXT-6 回声石）
			var ring := MeshInstance3D.new()
			ring.name = "Ring"
			var torus := TorusMesh.new()
			torus.inner_radius = 0.18
			torus.outer_radius = 0.3
			torus.rings = 20
			torus.ring_segments = 8
			ring.mesh = torus
			ring.material_override = _body_mat("reset_ring")
			ring.position = Vector3(0, 0.1, 0)
			mi.add_child(ring)
		"oneway_e", "oneway_w", "oneway_n", "oneway_s":
			# EXT-8 单向阀格：暗琥珀板 + 箭头（杆+头两根条），按箭头方向整体旋转
			box.size = Vector3(0.96, 0.16, 0.96)
			mi.material_override = _body_mat("oneway_base")
			var shaft := MeshInstance3D.new()
			shaft.name = "ArrowShaft"
			var sb := BoxMesh.new()
			sb.size = Vector3(0.52, 0.03, 0.1)
			shaft.mesh = sb
			shaft.material_override = _body_mat("oneway_arrow")
			shaft.position = Vector3(-0.08, 0.1, 0)
			mi.add_child(shaft)
			var head := MeshInstance3D.new()
			head.name = "ArrowHead"
			var hb := BoxMesh.new()
			hb.size = Vector3(0.16, 0.03, 0.26)
			head.mesh = hb
			head.material_override = _body_mat("oneway_arrow")
			head.position = Vector3(0.2, 0.1, 0)
			mi.add_child(head)
			var yaw := 0.0
			match String(tile):
				"oneway_w": yaw = 180.0
				"oneway_n": yaw = 90.0
				"oneway_s": yaw = -90.0
			mi.rotation_degrees = Vector3(0, yaw, 0)
		"portal_x", "portal_y":
			# EXT-9 传送对格：暗紫板 + 冰青圆环（成对同款，位置即标识）
			box.size = Vector3(0.96, 0.16, 0.96)
			mi.material_override = _body_mat("portal_base")
			var pring := MeshInstance3D.new()
			pring.name = "PortalRing"
			var ptorus := TorusMesh.new()
			ptorus.inner_radius = 0.16
			ptorus.outer_radius = 0.28
			ptorus.rings = 20
			ptorus.ring_segments = 8
			pring.mesh = ptorus
			pring.material_override = _body_mat("portal_ring")
			pring.position = Vector3(0, 0.1, 0)
			mi.add_child(pring)
		"slide_ice":
			# EXT-12 滑冰格：淡冰面 + 两条顺向流纹（东西向滑道的视觉暗示；四向滑道共用东西纹）
			box.size = Vector3(0.96, 0.12, 0.96)
			top = TOP_Y - 0.02
			mi.material_override = _body_mat("slide_ice")
			for i in 2:
				var streak := MeshInstance3D.new()
				streak.name = "Streak%d" % i
				var stb := BoxMesh.new()
				stb.size = Vector3(0.7, 0.02, 0.05)
				streak.mesh = stb
				streak.material_override = _body_mat("slide_streak")
				streak.position = Vector3(0, 0.08, -0.2 + 0.4 * i)
				mi.add_child(streak)
		"crumble":
			# EXT-20 脆壁：暗褐墙 + 交叉裂纹（可碰碎的视觉提示）
			box.size = Vector3(0.96, WALL_TOP, 0.96)
			mi.material_override = _body_mat("crumble_base")
			for ci in 2:
				var cw := MeshInstance3D.new()
				cw.name = "CrumbCrack%d" % ci
				var cwb := BoxMesh.new()
				cwb.size = Vector3(0.7, 0.04, 0.08)
				cw.mesh = cwb
				cw.material_override = _body_mat("crumble_line")
				cw.rotation_degrees = Vector3(0, -35.0 + 70.0 * ci, WALL_TOP * 0.6)
				cw.position = Vector3(0, 0, 0)
				mi.add_child(cw)
		"slot":
			# EXT-22 暗缝：缝框矮墙 + 居中竖缝（只有玩家能挤过的视觉提示）
			box.size = Vector3(0.96, WALL_TOP, 0.96)
			mi.material_override = _body_mat("slot_frame")
			var slit := MeshInstance3D.new()
			slit.name = "SlotGap"
			var sb := BoxMesh.new()
			sb.size = Vector3(0.18, WALL_TOP * 1.02, 0.98)
			slit.mesh = sb
			slit.material_override = _body_mat("slot_gap")
			slit.position = Vector3(0, 0, 0)
			mi.add_child(slit)
		"phase_gate", "phase_gate_inv":
			# EXT-13/15 相位门：底座 + 栏栅立柱（闭相可见；开相由 set_phase_state 隐藏；反相门暖柱区分拍子）
			box.size = Vector3(0.96, 0.16, 0.96)
			mi.material_override = _body_mat("phase_base")
			var pbar := MeshInstance3D.new()
			pbar.name = "PhaseBar"
			var pbb := BoxMesh.new()
			pbb.size = Vector3(0.16, WALL_TOP, 0.16)
			pbar.mesh = pbb
			pbar.material_override = _body_mat("phase_bar_inv" if tile == "phase_gate_inv" else "phase_bar")
			pbar.position = Vector3(0, WALL_TOP * 0.5, 0)
			mi.add_child(pbar)
			if tile == "phase_gate_inv":
				_phase_bars_inv.append(pbar)
			else:
				_phase_bars.append(pbar)
		"phase_bridge":
			# EXT-24 相位桥：平桥板 + 栏栅（闭窗可见；开合复用 _phase_bars 同步——桥与 Z 同拍）
			box.size = Vector3(0.96, 0.2, 0.96)
			mi.material_override = _body_mat("pbridge_base")
			var wbar := MeshInstance3D.new()
			wbar.name = "PhaseBar"
			var wbb := BoxMesh.new()
			wbb.size = Vector3(0.16, WALL_TOP, 0.16)
			wbar.mesh = wbb
			wbar.material_override = _body_mat("phase_bar")
			wbar.position = Vector3(0, WALL_TOP * 0.5, 0)
			mi.add_child(wbar)
			_phase_bars.append(wbar)
		"cold_vent":
			# EXT-19 寒泉：冰蓝冷岩 + 中央霜斑（与热泉 V 对偶的视觉提示）
			box.size = Vector3(0.96, 0.2, 0.96)
			mi.material_override = _body_mat("cold_base")
			var cglow := MeshInstance3D.new()
			cglow.name = "ColdGlow"
			var cgb := BoxMesh.new()
			cgb.size = Vector3(0.4, 0.24, 0.4)
			cglow.mesh = cgb
			cglow.material_override = _body_mat("cold_glow")
			cglow.position = Vector3(0, 0.06, 0)
			mi.add_child(cglow)
		"vent":
			# EXT-17 间歇泉：暗红热岩 + 中央热斑（周期喷发的视觉提示）
			box.size = Vector3(0.96, 0.2, 0.96)
			mi.material_override = _body_mat("vent_base")
			var vglow := MeshInstance3D.new()
			vglow.name = "VentGlow"
			var vgb := BoxMesh.new()
			vgb.size = Vector3(0.4, 0.24, 0.4)
			vglow.mesh = vgb
			vglow.material_override = _body_mat("vent_glow")
			vglow.position = Vector3(0, 0.06, 0)
			mi.add_child(vglow)
		"spring":
			# EXT-14 弹簧垫：苔绿底座 + 浅绿圆环（定距弹射的落点节奏暗示）
			box.size = Vector3(0.96, 0.16, 0.96)
			mi.material_override = _body_mat("spring_base")
			var sring := MeshInstance3D.new()
			sring.name = "SpringRing"
			var storus := TorusMesh.new()
			storus.inner_radius = 0.2
			storus.outer_radius = 0.32
			storus.rings = 20
			storus.ring_segments = 8
			sring.mesh = storus
			sring.material_override = _body_mat("spring_ring")
			sring.position = Vector3(0, 0.1, 0)
			mi.add_child(sring)
		"grease":
			# EXT-29 油道：暗紫油面 + 两条顺向油光（木箱滑道的视觉；与淡冰滑冰格对偶）
			box.size = Vector3(0.96, 0.12, 0.96)
			top = TOP_Y - 0.02
			mi.material_override = _body_mat("grease_base")
			for i in 2:
				var gstreak := MeshInstance3D.new()
				gstreak.name = "GreaseStreak%d" % i
				var gstb := BoxMesh.new()
				gstb.size = Vector3(0.7, 0.02, 0.05)
				gstreak.mesh = gstb
				gstreak.material_override = _body_mat("grease_streak")
				gstreak.position = Vector3(0, 0.08, -0.2 + 0.4 * i)
				mi.add_child(gstreak)
		"tide_cell":
			# EXT-31 潮汐格：湿泥/水面双态板 + 泡沫环（开合颜色由 set_tide_state 每帧驱动）
			box.size = Vector3(0.96, 0.12, 0.96)
			top = TOP_Y - 0.02
			mi.material_override = _body_mat("tide_base")
			var tring := MeshInstance3D.new()
			tring.name = "TideFoam"
			var ttb := BoxMesh.new()
			ttb.size = Vector3(0.7, 0.02, 0.05)
			tring.mesh = ttb
			tring.material_override = _body_mat("tide_foam")
			tring.position = Vector3(0, 0.08, 0)
			mi.add_child(tring)
		"tide_late":
			# EXT-33 反相潮汐格：暖沙/暗琥珀双态板 + 琥珀环（开合颜色由 set_tide_state 驱动）
			box.size = Vector3(0.96, 0.12, 0.96)
			top = TOP_Y - 0.02
			mi.material_override = _body_mat("tide_late_base")
			var jring := MeshInstance3D.new()
			jring.name = "TideLateFoam"
			var jtb := BoxMesh.new()
			jtb.size = Vector3(0.7, 0.02, 0.05)
			jring.mesh = jtb
			jring.material_override = _body_mat("tide_late_foam")
			jring.position = Vector3(0, 0.08, 0)
			mi.add_child(jring)
		"push_stub":
			# EXT-34 推塌桩：灰蓝假墙 + 竖向裂纹（比真墙浅、暗示可推塌；不阻挡弹射垫弹射视认）
			box.size = Vector3(0.96, WALL_TOP, 0.96)
			mi.material_override = _body_mat("stub_base")
			for i in 2:
				var yline := MeshInstance3D.new()
				yline.name = "StubCrack%d" % i
				var ylb := BoxMesh.new()
				ylb.size = Vector3(0.05, WALL_TOP * 0.7, 0.02)
				yline.mesh = ylb
				yline.material_override = _body_mat("stub_line")
				yline.position = Vector3(-0.15 + 0.3 * i, 0, 0.3)
				mi.add_child(yline)
		"launcher":
			# EXT-26 弹射垫：深青底座 + 亮青圆环（货物弹射垫，与苔绿玩家弹簧垫区分）
			box.size = Vector3(0.96, 0.16, 0.96)
			mi.material_override = _body_mat("launcher_base")
			var lring := MeshInstance3D.new()
			lring.name = "LauncherRing"
			var ltorus := TorusMesh.new()
			ltorus.inner_radius = 0.2
			ltorus.outer_radius = 0.32
			ltorus.rings = 20
			ltorus.ring_segments = 8
			lring.mesh = ltorus
			lring.material_override = _body_mat("launcher_ring")
			lring.position = Vector3(0, 0.1, 0)
			mi.add_child(lring)
		"link_slot":
			# EXT-27 联动桥位：桥板 + 冷蓝环（压住联动开关时 refresh_state 把板调成填土暖色）
			box.size = Vector3(0.96, 0.2, 0.96)
			mi.material_override = _body_mat("link_base")
			var kring := MeshInstance3D.new()
			kring.name = "LinkRing"
			var ktorus := TorusMesh.new()
			ktorus.inner_radius = 0.18
			ktorus.outer_radius = 0.3
			ktorus.rings = 20
			ktorus.ring_segments = 8
			kring.mesh = ktorus
			kring.material_override = _body_mat("link_ring")
			kring.position = Vector3(0, 0.1, 0)
			mi.add_child(kring)
		"gate":
			box.size = Vector3(0.96, 0.2, 0.96)
			mi.material_override = _body_mat("gate_base_closed")
			var gate := _build_gate(x, y, rules)
			_gates["%d,%d" % [x, y]] = gate
			add_child(gate.frame)
			add_child(gate.door)
		"key_item":
			# EXT-36 钥匙格：暖沙暗底 + 金色钥匙环与柄（信物高亮，踩上即拾）
			box.size = Vector3(0.96, 0.2, 0.96)
			mi.material_override = _body_mat("key_base")
			var key_ring := MeshInstance3D.new()
			var key_torus := TorusMesh.new()
			key_torus.inner_radius = 0.09
			key_torus.outer_radius = 0.15
			key_ring.mesh = key_torus
			key_ring.material_override = _body_mat("key_gold")
			key_ring.position = Vector3(-0.16, 0.14, 0)
			mi.add_child(key_ring)
			var key_shaft := MeshInstance3D.new()
			var key_box := BoxMesh.new()
			key_box.size = Vector3(0.32, 0.05, 0.06)
			key_shaft.mesh = key_box
			key_shaft.material_override = _body_mat("key_gold")
			key_shaft.position = Vector3(0.1, 0.14, 0)
			mi.add_child(key_shaft)
		"locked_gate":
			# EXT-36 锁门：锈红门体 + 金色锁孔点（与压力板门红金配色一眼区分）
			box.size = Vector3(0.96, 0.2, 0.96)
			mi.material_override = _body_mat("lock_base")
			var lock_door := MeshInstance3D.new()
			var lock_box := BoxMesh.new()
			lock_box.size = Vector3(0.7, 0.55, 0.14)
			lock_door.mesh = lock_box
			lock_door.material_override = _body_mat("lock_door")
			lock_door.position = Vector3(0, 0.32, 0)
			mi.add_child(lock_door)
			var lock_hole := MeshInstance3D.new()
			var lock_hole_mesh := SphereMesh.new()
			lock_hole_mesh.radius = 0.05
			lock_hole_mesh.height = 0.1
			lock_hole.mesh = lock_hole_mesh
			lock_hole.material_override = _body_mat("key_gold")
			lock_hole.position = Vector3(0, 0.36, 0.09)
			mi.add_child(lock_hole)
		"ivy":
			# EXT-37 藤蔓墙：苔绿墙体略矮于普通墙（可攀越暗示）+ 两条亮藤条纹
			box.size = Vector3(0.96, WALL_TOP - 0.15, 0.96)
			top = WALL_TOP - 0.15
			mi.material_override = _body_mat("ivy_base")
			for vi in 2:
				var ivy_vine := MeshInstance3D.new()
				var ivy_streak := BoxMesh.new()
				ivy_streak.size = Vector3(0.08, 0.02, 0.66)
				ivy_vine.mesh = ivy_streak
				ivy_vine.name = "IvyVine%d" % vi
				ivy_vine.material_override = _body_mat("ivy_vine")
				ivy_vine.position = Vector3(-0.22 + 0.44 * vi, (WALL_TOP - 0.15) * 0.5, 0)
				mi.add_child(ivy_vine)
		"key_silver":
			# EXT-42 银钥格：暗钢底 + 银灰钥匙环柄（踩上即拾）
			box.size = Vector3(0.96, 0.2, 0.96)
			mi.material_override = _body_mat("lock_s_base")
			var sv_ring := MeshInstance3D.new()
			var sv_torus := TorusMesh.new()
			sv_torus.inner_radius = 0.09
			sv_torus.outer_radius = 0.15
			sv_ring.mesh = sv_torus
			sv_ring.material_override = _body_mat("key_silver")
			sv_ring.position = Vector3(-0.16, 0.14, 0)
			mi.add_child(sv_ring)
			var sv_shaft := MeshInstance3D.new()
			var sv_box := BoxMesh.new()
			sv_box.size = Vector3(0.32, 0.05, 0.06)
			sv_shaft.mesh = sv_box
			sv_shaft.material_override = _body_mat("key_silver")
			sv_shaft.position = Vector3(0.1, 0.14, 0)
			mi.add_child(sv_shaft)
		"locked_gate_s":
			# EXT-42 银门：银灰门体 + 深锁孔（通道门——有银钥即穿行，不触发过关）
			box.size = Vector3(0.96, 0.2, 0.96)
			mi.material_override = _body_mat("lock_s_base")
			var sdoor := MeshInstance3D.new()
			var sdoor_box := BoxMesh.new()
			sdoor_box.size = Vector3(0.7, 0.55, 0.14)
			sdoor.mesh = sdoor_box
			sdoor.material_override = _body_mat("lock_s_door")
			sdoor.position = Vector3(0, 0.32, 0)
			mi.add_child(sdoor)
			var shole := MeshInstance3D.new()
			var shole_mesh := SphereMesh.new()
			shole_mesh.radius = 0.05
			shole_mesh.height = 0.1
			shole.mesh = shole_mesh
			shole.material_override = _body_mat("lock_s_base")
			shole.position = Vector3(0, 0.36, 0.09)
			mi.add_child(shole)
		"tide_gate":
			# EXT-43 潮闸：石青闸框双柱 + 潮青横杆（开窗提色可通行/闭窗暗杆拒——
			# 杆色由 set_tide_gate_state 按 main 轮询翻转）
			box.size = Vector3(0.96, 0.2, 0.96)
			mi.material_override = _body_mat("tgate_base")
			for pi in 2:
				var tgate_post := MeshInstance3D.new()
				var tgate_post_box := BoxMesh.new()
				tgate_post_box.size = Vector3(0.12, 0.66, 0.12)
				tgate_post.mesh = tgate_post_box
				tgate_post.name = "TGatePost%d" % pi
				tgate_post.material_override = _body_mat("belt_base")
				tgate_post.position = Vector3(-0.3 + 0.6 * pi, 0.33, 0.28)
				mi.add_child(tgate_post)
			var tgate_bar := MeshInstance3D.new()
			var tgate_bar_box := BoxMesh.new()
			tgate_bar_box.size = Vector3(0.8, 0.1, 0.1)
			tgate_bar.mesh = tgate_bar_box
			tgate_bar.name = "TGateBar"
			tgate_bar.material_override = _body_mat("tgate_bar")
			tgate_bar.position = Vector3(0, 0.4, 0)
			mi.add_child(tgate_bar)
		"tide_well":
			# EXT-39 换相井：地板 + 双同心环（相位机关踏板；换相调色由 main 沿轮询接管）
			box.size = Vector3(0.96, 0.2, 0.96)
			mi.material_override = _body_mat("floor_%d" % ((x + y) % 2))
			for wi in 2:
				var well_ring := MeshInstance3D.new()
				var well_torus := TorusMesh.new()
				well_torus.inner_radius = 0.1 + 0.14 * wi
				well_torus.outer_radius = 0.16 + 0.14 * wi
				well_ring.mesh = well_torus
				well_ring.name = "WellRing%d" % wi
				well_ring.material_override = _body_mat("well_ring")
				well_ring.position = Vector3(0, 0.12 + 0.02 * wi, 0)
				mi.add_child(well_ring)
		"belt_e", "belt_w", "belt_s", "belt_n":
			# EXT-40/41 输送带：暗金属带面 + 三枚顺带向箭羽（f 东 / h 西 / m 南 / t 北）
			box.size = Vector3(0.96, 0.2, 0.96)
			mi.material_override = _body_mat("belt_base")
			if tile == "belt_e" or tile == "belt_w":
				var sign_x := 1.0 if tile == "belt_e" else -1.0
				for ai in 3:
					var belt_arrow := MeshInstance3D.new()
					var arrow_box := BoxMesh.new()
					arrow_box.size = Vector3(0.1, 0.03, 0.26)
					belt_arrow.mesh = arrow_box
					belt_arrow.name = "BeltArrow%d" % ai
					belt_arrow.material_override = _body_mat("belt_arrow")
					belt_arrow.position = Vector3(sign_x * (-0.24 + 0.24 * ai), 0.13, 0)
					mi.add_child(belt_arrow)
			else:
				var sign_z := 1.0 if tile == "belt_s" else -1.0
				for ai in 3:
					var belt_arrow_v := MeshInstance3D.new()
					var arrow_box_v := BoxMesh.new()
					arrow_box_v.size = Vector3(0.26, 0.03, 0.1)
					belt_arrow_v.mesh = arrow_box_v
					belt_arrow_v.name = "BeltArrow%d" % ai
					belt_arrow_v.material_override = _body_mat("belt_arrow")
					belt_arrow_v.position = Vector3(0, 0.13, sign_z * (-0.24 + 0.24 * ai))
					mi.add_child(belt_arrow_v)
		_:
			box.size = Vector3(0.96, 0.2, 0.96)
			mi.material_override = _body_mat("floor_%d" % ((x + y) % 2))
	mi.mesh = box
	mi.position = cell_to_world(x, y, top - box.size.y * 0.5)
	add_child(mi)
	_tiles["%d,%d" % [x, y]] = mi


## 门 = 套件 gate_frame 模型（按 1 格缩放）+ 关门板；门框朝向按相邻墙推断（approach 沿哪轴）
func _build_gate(x: int, y: int, rules) -> Dictionary:
	var frame: Node3D = ModelLibrary.create_model("gate_frame")
	frame.name = "GateFrame_%d_%d" % [x, y]
	frame.scale = Vector3(0.5, 0.5, 0.5)
	var walls_lr: bool = x > 0 and x < ROOM_W - 1 \
		and String(rules.grid[rules._idx(x - 1, y)]) == "wall" \
		and String(rules.grid[rules._idx(x + 1, y)]) == "wall"
	if not walls_lr:
		frame.rotation_degrees = Vector3(0, 90, 0)  # 上下是墙 → 从左右进入 → 门框跨 Z
	frame.position = cell_to_world(x, y, 0.0)
	var door := Node3D.new()
	door.name = "GateDoor_%d_%d" % [x, y]
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.86, 0.95, 0.18)
	mi.mesh = box
	mi.material_override = _body_mat("door_closed")
	mi.position = Vector3(0, 0.475, 0)
	door.add_child(mi)
	door.position = cell_to_world(x, y, 0.0)
	return {frame = frame, door = door, base = null}


func _build_switch(x: int, y: int, ptype: String = "switch") -> void:
	var model: Node3D = ModelLibrary.create_model("pressure_plate")
	model.name = "Switch_%d_%d" % [x, y]
	model.scale = Vector3(0.8, 0.8, 0.8)  # 板原 1.3m，缩到 1 格内
	model.position = cell_to_world(x, y, 0.0)
	var top: MeshInstance3D = null
	var top_y := -1.0
	for c in model.get_children():
		if c is MeshInstance3D and c.position.y > top_y:
			top_y = c.position.y
			top = c
	# 贴地边缘环：模型局部半径 0.6-0.69（×0.8 缩放后世界 0.48-0.55，大于箱脚 0.5），
	# 箱/铁压住时环仍从四周露出（指南 §4 遮挡项）；反相板（switch_not）蓝环以示区分
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.69
	torus.rings = 24
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = _body_mat("switch_ring_latch") if ptype == "switch_latch" \
		else (_body_mat("switch_ring_double") if ptype == "switch_double" \
		else (_body_mat("switch_ring_heavy") if ptype == "switch_heavy" \
		else (_body_mat("switch_ring_not") if ptype == "switch_not" \
		else (_body_mat("switch_ring_link") if ptype == "switch_link" else _body_mat("switch_ring")))))
	ring.position = Vector3(0, 0.02, 0)
	model.add_child(ring)
	add_child(model)
	_switches["%d,%d" % [x, y]] = {model = model, top = top, type = ptype}


## 单格地形变化（freeze/melt/sink 事件后调用）
func refresh_tile(x: int, y: int, rules) -> void:
	if x < 0 or x >= ROOM_W or y < 0 or y >= ROOM_H:
		return
	_build_tile(x, y, String(rules.grid[rules._idx(x, y)]), rules)


## 板满足/未满足形态（每次核心动作后调用；颜色+形状双反馈，不只用红绿）
## 普通板：压住=满足；反相板：空置=满足。满足=整板压低+绿面；未满足=抬起+原色/红面
func refresh_state(rules) -> void:
	# EXT-27 联动桥位：全部联动开关压住 → 桥板调填土暖色（断开=暗水蓝）
	_body_mat("link_base").set_shader_parameter("base_color",
		Color("cf8958") if rules._link_pressed() else Color("274766"))
	for key in _switches:
		var sw: Dictionary = _switches[key]
		var parts: PackedStringArray = key.split(",")
		var sx := int(parts[0])
		var sy := int(parts[1])
		var ptype: String = sw.type
		var satisfied: bool = rules._plate_satisfied({x = sx, y = sy, type = ptype})
		var model: Node3D = sw.model
		model.scale.y = 0.55 if satisfied else 0.8  # 满足：整板压低（形状反馈）
		var top: MeshInstance3D = sw.top
		if top != null and top.material_override is ShaderMaterial:
			if ptype == "switch_not":
				# 反相板：空置导通=绿面；被占断开=暗红面
				top.material_override.set_shader_parameter("base_color",
					SWITCH_PRESSED_COLOR if satisfied else Color("a34a3f"))
			elif ptype == "switch_heavy":
				# 重压板：铁压导通=钢蓝面；空置=冷灰面（与普通板 amber 区分）
				top.material_override.set_shader_parameter("base_color",
					Color("8fa8c8") if satisfied else Color("5a6068"))
			elif ptype == "switch_latch":
				# 自锁踏板：锁定=亮绿面；未锁=灰面（一旦锁定永不翻转）
				top.material_override.set_shader_parameter("base_color",
					Color("6fcf7f") if satisfied else Color("5a6068"))
			elif ptype == "switch_double":
				# 双踩板：满二锁定=亮绿面；未满=淡金面（与自锁的灰面区分"还差一脚"）
				top.material_override.set_shader_parameter("base_color",
					Color("6fcf7f") if satisfied else Color("c8a95a"))
			else:
				top.material_override.set_shader_parameter("base_color",
					SWITCH_PRESSED_COLOR if satisfied else ModelLibrary.COLORS.plate)
	for key2 in _gates:
		var g: Dictionary = _gates[key2]
		var open: bool = rules.gate_open()
		g.door.visible = not open
		var parts2: PackedStringArray = key2.split(",")
		var base: MeshInstance3D = _tiles.get("%s,%s" % [parts2[0], parts2[1]])
		if base != null:
			base.material_override = _body_mat("gate_base_open") if open else _body_mat("gate_base_closed")
