extends Node
## demo-05 v2 演示录制驱动（配合 --write-movie 离线渲染）：
## 自动玩一局展示 v2 机制：特产存入 → 萨满预报 → 火山爆发 → 灾后抢运 → 撤离 → 末日故事
## 运行：godot --path game --write-movie <out.avi> --fixed-fps 30 res://tests/demo05_showcase.tscn

var v: Control
var t := 0.0
var steps: Array = []
var si := 0


func _ready() -> void:
	seed(_find_seed())
	v = load("res://demo05_volcano.tscn").instantiate()
	add_child(v)
	steps = [
		{at = 5.0, kind = "dep", arg = "valley"},
		{at = 7.0, kind = "dep", arg = "valley"},
		{at = 9.0, kind = "dep", arg = "valley"},
		{at = 11.0, kind = "dep", arg = "forest"},
		{at = 13.0, kind = "dep", arg = "forest"},
		{at = 15.0, kind = "dep", arg = "cave"},
		{at = 17.0, kind = "dep", arg = "highland"},
		{at = 32.0, kind = "emg", arg = ""},
		{at = 34.0, kind = "reloc", arg = "valley"},
		{at = 38.0, kind = "route", arg = 0},
		{at = 42.0, kind = "quit", arg = ""},
	]


## 选一个「东风+下雨+预报全对」的种子：展示高地哨兵确认预报、河谷押注与抢运救局的完整故事
func _find_seed() -> int:
	for s in range(2000, 3000, 17):
		seed(s)
		var w: bool = randf() < 0.5      # true = 东风
		var r: bool = randf() < 0.6      # true = 下雨
		var fw: bool = randf() < 0.75    # true = 风向预报正确
		var fr: bool = randf() < 0.75    # true = 降雨预报正确
		if w and r and fw and fr:
			return s
	return 2000


func _idx(id: String) -> int:
	for i in v.TILES.size():
		if v.TILES[i].id == id:
			return i
	return 0


func _tick_step(s: Dictionary) -> bool:
	match s.kind:
		"dep":
			if v.gather <= 0:
				return false
			v._on_tile_click(_idx(s.arg))
			return true
		"emg":
			v._use_emergency("relocate")
			return v.emergency == "relocate" or v.relocating
		"reloc":
			v._do_relocate(_idx(s.arg))
			return v.emergency == "relocate"
		"route":
			v._choose_route(s.arg)
			return v.route_chosen != -1
		"quit":
			get_tree().quit()
			return true
	return false


func _process(delta: float) -> void:
	t += delta
	if t > 55.0:
		get_tree().quit()
		return
	if si >= steps.size():
		return
	if t >= steps[si].at:
		if _tick_step(steps[si]):
			si += 1
