extends Node2D
## demo-04 v10 上板素材驱动：机器人连通 5 关全程录制（Movie Maker 离线渲染）
## 运行：godot --path game --write-movie <帧目录>/f.png --fixed-fps 30 res://tests/movie_demo04.tscn
## 注：跳输入走 parse_input_event（v9 实录验证可用；直写 keys 在 Movie 模式不稳定）。

var game: Node2D
var jump_cd := 0


func _ready() -> void:
	game = load("res://demo04_soup.tscn").instantiate()
	add_child(game)


func _key(code: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code as Key
	ev.pressed = down
	Input.parse_input_event(ev)


func _ground_ahead(x: float) -> bool:
	for b in game.blocks:
		if b[0] <= x and b[0] + b[2] >= x and b[1] >= 440 and b[1] <= 500:
			return true
	return false


func _wall_ahead() -> bool:
	for b in game.blocks:
		if b[0] > game.px + 40 and b[0] < game.px + 84 and b[1] < game.py - 6:
			return true
	return false


func _physics_process(_delta: float) -> void:
	if game == null:
		return
	if game.state == "win":
		if game.level_idx >= game.LEVELS.size() - 1:
			get_tree().quit()   # 5 关全通，录制结束
			return
		game._advance()
		return
	if not game.keys.get(KEY_RIGHT, false):
		_key(KEY_RIGHT, true)
	for a in game.aliens:
		if not game.dna.has(a.id) and absf(game.px - a.x) < 55.0:
			game._try_fuse()
	jump_cd = maxi(0, jump_cd - 1)
	if jump_cd > 0:
		_key(KEY_SPACE, false)
		return
	if game.on_floor:
		if (not _ground_ahead(game.px + 50.0)) or (not _ground_ahead(game.px + 110.0)) or _wall_ahead():
			_key(KEY_SPACE, true)
			jump_cd = 3
	elif game.dna.has("double") and game.jumps_used == 1 and game.vy > -40.0:
		_key(KEY_SPACE, true)
		jump_cd = 6
