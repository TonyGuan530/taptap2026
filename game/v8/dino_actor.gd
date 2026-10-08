extends "res://v6/dino_actor.gd"
var world: Node3D
func step(delta: float) -> void:
	# A ready terrain chunk and its real collider must exist before crossing.
	if world and world.stream and drive.length() > 0.01:
		var ahead := global_position+drive*maxf(1.0,speed*delta+0.6)
		if not world.terrain_ready(ahead):
			drive = Vector3.ZERO
			if self == world.player: world.notify("前方地形正在生成，稍候即可继续探索。")
	super.step(delta)
