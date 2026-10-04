extends Node3D
## demo-03-3d 展示录制驱动：自动开局+合理节奏（建造/升级/晋升）
var game: Node3D
var started := false
func _ready() -> void:
	var ps: PackedScene = load("res://demo03_3d.tscn")
	game = ps.instantiate()
	add_child(game)
func _process(delta: float) -> void:
	if game == null or started == false:
		if game != null and game.sim != null and game.sim.round_state == "menu":
			started = true
			game._start("classic")
		return
	var sim = game.sim
	if sim.round_state != "play":
		return
	if sim.elapsed > 3.5 and sim.towers[0] == 0 and sim.water >= sim.build_cost():
		sim.try_build(0)
	elif sim.elapsed > 12.0 and sim.towers[1] == 0 and sim.water >= sim.build_cost():
		sim.try_build(1)
	elif sim.elapsed > 21.0 and sim.villagers.size() > 0 and sim.villagers[0].level == 0 \
			and sim.water >= sim.NPC_UP_COST:
		sim.try_promote(sim.villagers[0].id)
	elif sim.elapsed > 24.0 and sim.towers[0] == 1 and sim.water >= sim.upgrade_cost():
		sim.try_upgrade(0)
	elif sim.elapsed > 40.0 and sim.towers[2] == 0 and sim.water >= sim.build_cost():
		sim.try_build(2)
