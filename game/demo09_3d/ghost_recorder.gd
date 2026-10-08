extends RefCounted
## B4 幽灵录制器（契约 §11 D13）：固定 0.1s 间隔采样 pos+basis；
## 键 = 关卡+seed+rule_version（+构建），上一局/当前局缓冲由场景层持有、录制器只管当前局。
## 替代旧 2D 的每 6 物理帧采样（契约 §7：非时间对齐回放）。

const SAMPLE_DT := 0.1

var key := ""
var _t := 0.0
var _samples: Array = []   # {t: float, pos: Vector3, bx: Vector3, by: Vector3, bz: Vector3}


func start(p_key: String) -> void:
	key = p_key
	_t = 0.0
	_samples = []


## 每物理帧调用：dt 累计，满 0.1s 记一点（时间对齐）
func sample(dt: float, pos: Vector3, basis: Basis) -> void:
	_t += dt
	if _samples.is_empty() or _t - float(_samples[-1].t) >= SAMPLE_DT - 1e-6:
		_samples.append({t = _t, pos = pos, bx = basis.x, by = basis.y, bz = basis.z})


func sample_count() -> int:
	return _samples.size()


## 结算时取走本局记录（场景层存入 ghost_last，键隔离）
func finish() -> Dictionary:
	return {key = key, samples = _samples.duplicate(true)}


static func record_key(level_idx: int, seed_v: int, rule_version: String) -> String:
	return "l%d_s%d_%s" % [level_idx, seed_v, rule_version]
