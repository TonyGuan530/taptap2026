extends SceneTree
## demo-01 试玩时长审计（回应 NEEDS_WORK：单局 2-3 分钟）
## 估算法：证词+线索文字量 / 300字每分钟（中文阅读速度）+ 每物品 4 秒交互 + 指认 20 秒
## 运行：godot --headless --path game -s res://tests/test_demo01_timing.gd

var scene = null
var logf: FileAccess

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://timinglog.txt", FileAccess.WRITE)
	await process_frame
	scene = load("res://demo01_detective.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	var total_all := 0.0
	for ci in 3:
		var c: Dictionary = scene.CASES[ci]
		var chars := 0
		for it in c.items:
			chars += (it.words as String).length() + (it.clue as String).length() + (it.name as String).length()
		chars += (c.question as String).length()
		for ch in c.choices:
			chars += (ch as String).length()
		chars += (c.ending as String).length()
		var read_sec := chars * 60.0 / 300.0
		var interact_sec: float = c.items.size() * 4.0 + 20.0
		var total_sec: float = read_sec + interact_sec
		total_all += total_sec
		var verdict := "达标（2-3分钟）" if total_sec >= 120.0 and total_sec <= 180.0 else ("偏短" if total_sec < 120.0 else "偏长")
		_log("案件%d: 文字%d字 阅读%.0fs 交互%.0fs 合计%.0fs（%.1f分钟）→ %s" % [ci + 1, chars, read_sec, interact_sec, total_sec, total_sec / 60.0, verdict])
	_log("三案合计: %.1f 分钟" % (total_all / 60.0))
	_log("ALL DONE")
	logf.flush()
	quit()
