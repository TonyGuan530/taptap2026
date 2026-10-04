extends Node
## 能力状态（DNA/组合发现）——v12 语义的 3D 移植，规则逐项对应 2D demo04_soup.gd。
## 只存状态与派生参数；移动/表现层只读本节点。

signal dna_gained(id: String)
signal combo_discovered(id: String)
signal shards_changed(count: int, total: int)

const WALK_SPEED := 2.6          # m/s（2D WALK 260）
const GRAVITY := 15.0            # m/s²（2D GRAV 1500）
const JUMP_V := 5.6              # m/s（2D JUMP_V 560）
const HIGHJUMP_MULT := 1.45
const DOUBLE_MULT := 0.95
const DARK_SPEED_FACTOR := 0.45  # 无荧光暗区水平速度

var dna: Dictionary = {}         # id -> true
var combos_found: Dictionary = {}  # combo id -> true
var shards_level: int = 0
var shards_total: int = 0

func has_dna(id: String) -> bool:
	return dna.get(id, false)

func gain_dna(id: String) -> void:
	if dna.get(id, false):
		return
	dna[id] = true
	emit_signal("dna_gained", id)
	_check_combo_discovery()

func _check_combo_discovery() -> void:
	if has_dna("highjump") and has_dna("double") and not combos_found.has("superjump"):
		combos_found["superjump"] = true
		emit_signal("combo_discovered", "superjump")
	if has_dna("double") and has_dna("glow") and not combos_found.has("nightwing"):
		combos_found["nightwing"] = true
		emit_signal("combo_discovered", "nightwing")

func jump_velocity_first() -> float:
	return JUMP_V * (HIGHJUMP_MULT if has_dna("highjump") else 1.0)

func jump_velocity_double() -> float:
	# 2D 语义：第二跳 560×0.95，有高跳时再×1.45
	var v := JUMP_V * DOUBLE_MULT
	if has_dna("highjump"):
		v *= HIGHJUMP_MULT
	return v

func max_jumps() -> int:
	return 2 if has_dna("double") else 1

func horizontal_speed(in_dark: bool) -> float:
	if in_dark and not has_dna("glow"):
		return WALK_SPEED * DARK_SPEED_FACTOR
	return WALK_SPEED

func has_nightwing_speed_bonus() -> bool:
	# 对照矩阵：nightwing 现分支不可达，仅发现与显示；不擅加增益
	return false

func collect_shard() -> void:
	shards_level += 1
	shards_total += 1
	emit_signal("shards_changed", shards_level, shards_total)

func reset_level_state(keep_combos: bool) -> void:
	dna = {}
	shards_level = 0
	if not keep_combos:
		combos_found = {}

func dna_names() -> Array:
	var names := {
		"highjump": "弹簧腿 DNA",
		"double": "振翅 DNA",
		"glow": "荧光 DNA",
		"break": "碎岩 DNA",
	}
	var out := []
	for id in dna.keys():
		out.append(names.get(id, id))
	return out
