extends Node2D
## demo-03 上板素材驱动：以 30fps 固定帧率跑一局"会玩"剧本（v3：预警→村民投资 的决策故事），
## 21.5s 定格截图（酸雨预警 + 精英村民 + 双设施），全程帧序列供 ffmpeg 合成 mp4。
## 运行：godot --path game --write-movie <绝对路径>/f.png --fixed-fps 30 --quit-after 920 res://tests/movie_demo03.tscn

var game: Node2D
var shot_saved := false


func _ready() -> void:
	var ps: PackedScene = load("res://demo03_kingdom.tscn")
	game = ps.instantiate()
	add_child(game)


func _process(_delta: float) -> void:
	if game == null or game.state != "play":
		return
	var e: float = game.elapsed
	# 剧本：先正常建设（3.5s/12s 双设施），预警窗口（19-22s）投资村民 = 策略迁移
	if e > 3.5 and game.towers[0] == 0 and game.water >= game._build_cost():
		game._try_build(0)
	elif e > 12.0 and game.towers[1] == 0 and game.water >= game._build_cost():
		game._try_build(1)
	elif e > 24.0 and game.towers[0] == 1 and game.water >= game._upgrade_cost():
		game._try_upgrade(0)
	# 21s（预警期内）把第一位村民升为精英——"听到预警，把钱投给人"
	if e > 21.0 and game.npcs.size() >= 1 and game.npcs[0].level == 0 and game.water >= game.NPC_UP_COST:
		game._try_promote(game.npcs[0])
	# 定格酸雨剧情：第一场 22s 准时来，第二场不出场
	game.acid_events[0].start = 22.0
	game.acid_events[1].start = 999.0
	# 截图：预警倒计时 + 精英村民★ + 双设施
	if e >= 21.5 and not shot_saved:
		shot_saved = true
		var img := get_viewport().get_texture().get_image()
		var out: String = ProjectSettings.globalize_path("res://") + "../reviews/shots/demo-03.png"
		img.save_png(out)
		print("SHOT_SAVED: ", out, " elapsed=", e)
