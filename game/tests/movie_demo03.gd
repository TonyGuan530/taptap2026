extends Node2D
## demo-03 上板素材驱动（v5）：MODE 选 "classic" / "storm"。
## classic：21.5s 预警截图（demo-03.png）+ 25s 酸雨中截图（demo-03-v4-acid.png）
## storm：31.5s 第二场风暴截图（demo-03-v5-storm.png，含 ▼设施/▲精英村民）
## 剧本：正常建设，预警/酸雨窗口内投资村民（策略迁移）。
## 运行：godot --path game --write-movie <绝对路径>/f.png --fixed-fps 30 --quit-after 1000 res://tests/movie_demo03.tscn

const MODE := "storm"

var game: Node2D
var shot_saved := false
var acid_shot_saved := false
var storm_shot_saved := false


func _ready() -> void:
	var ps: PackedScene = load("res://demo03_kingdom.tscn")
	game = ps.instantiate()
	add_child(game)
	game._setup_round(MODE)


func _save_shot(path: String, e: float) -> void:
	var img := get_viewport().get_texture().get_image()
	var out: String = ProjectSettings.globalize_path("res://") + "../" + path
	img.save_png(out)
	print("SHOT_SAVED: ", out, " elapsed=", e)


func _process(_delta: float) -> void:
	if game == null or game.state != "play":
		return
	var e: float = game.elapsed
	# 剧本：先正常建设（3.5s/12s 双设施），24s 升 II 级
	if e > 3.5 and game.towers[0] == 0 and game.water >= game._build_cost():
		game._try_build(0)
	elif e > 12.0 and game.towers[1] == 0 and game.water >= game._build_cost():
		game._try_build(1)
	elif e > 24.0 and game.towers[0] == 1 and game.water >= game._upgrade_cost():
		game._try_upgrade(0)
	# 预警/酸雨窗口内投资村民（策略迁移；风暴第一场 15s 时村民未到，第二场起生效）
	var in_window := false
	for ev in game.acid_events:
		var s: float = float(ev.start)
		if e >= s - 3.0 and e < s + 8.0:
			in_window = true
			break
	if in_window and game.water >= game.NPC_UP_COST:
		for n in game.npcs:
			if n.level == 0:
				game._try_promote(n)
				break
	# 定格剧情：classic 只留第一场 22s；storm 留前两场 15s/30s（31.5s 截图落在第二场），第三场取消
	if MODE == "classic":
		for i in game.acid_events.size():
			game.acid_events[i].start = 22.0 if i == 0 else 999.0
	else:
		var storm_starts := [15.0, 30.0, 999.0]
		for i in game.acid_events.size():
			game.acid_events[i].start = float(storm_starts[i])
	# 截图
	if MODE == "classic":
		if e >= 21.5 and not shot_saved:
			shot_saved = true
			_save_shot("reviews/shots/demo-03.png", e)
		elif e >= 25.0 and not acid_shot_saved:
			acid_shot_saved = true
			_save_shot("reviews/shots/demo-03-v4-acid.png", e)
	else:
		if e >= 31.5 and not storm_shot_saved:
			storm_shot_saved = true
			_save_shot("reviews/shots/demo-03-v5-storm.png", e)
