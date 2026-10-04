extends Node
## DEMO4 3D 能力状态——语义逐项对应 2D demo04_soup.gd（指南 §2 对照矩阵）。

signal dna_gained(id: String)
signal combo_discovered(id: String)
signal shards_changed(count: int, total: int)

const WALK_SPEED := 2.6
const GRAVITY := 15.0
const JUMP_V := 5.6
const HIGHJUMP_MULT := 1.45
const DOUBLE_MULT := 0.95
const DARK_SPEED_FACTOR := 0.45

var dna: Dictionary = {}
var combos_found: Dictionary = {}
var shards_level: int = 0
var shards_total: int = 0

func has_dna(id: String) -> bool:
	return dna.get(id, false)

func gain_dna(id: String) -> void:
	if dna.get(id, false):
		return
	dna[id] = true
	dna_gained.emit(id)
	_check_combo_discovery()

func _check_combo_discovery() -> void:
	if has_dna("highjump") and has_dna("double") and not combos_found.has("superjump"):
		combos_found["superjump"] = true
		combo_discovered.emit("superjump")
	if has_dna("double") and has_dna("glow") and not combos_found.has("nightwing"):
		combos_found["nightwing"] = true
		combo_discovered.emit("nightwing")

func jump_velocity_first() -> float:
	return JUMP_V * (HIGHJUMP_MULT if has_dna("highjump") else 1.0)

func jump_velocity_double() -> float:
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

func collect_shard() -> void:
	shards_level += 1
	shards_total += 1
	shards_changed.emit(shards_level, shards_total)

func reset_level_state(keep_combos: bool) -> void:
	dna = {}
	shards_level = 0
	if not keep_combos:
		combos_found = {}

func dna_names() -> Array:
	var names := {
		"highjump": "弹簧腿 DNA", "double": "振翅 DNA", "glow": "荧光 DNA", "break": "碎岩 DNA",
	}
	var out := []
	for id in dna.keys():
		out.append(names.get(id, id))
	return out
