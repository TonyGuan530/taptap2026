extends "res://v6/dino_rules.gd"
## Free exploration advances fuel/energy/survival but never arms the volcano.
var volcano_armed := false
var exploration_elapsed := 0.0
func arm_volcano() -> bool:
	if volcano_armed: return false
	volcano_armed = true
	elapsed = 0.0
	phase = "calm"
	sheltered_seconds = 0.0
	return true
func tick(delta: float, player_below := false, buddy_below := false) -> void:
	exploration_elapsed += delta
	if volcano_armed:
		super.tick(delta,player_below,buddy_below)
		return
	# Technology runs on exploration time, independent of disaster time.
	wheel_running = built.has("wheel")
	steam_running = built.has("steam") and fuel_seconds > 0
	if steam_running:
		fuel_seconds = maxf(0,fuel_seconds-delta)
		steam_seconds += delta
	charge = clampf(charge+delta*((2.5 if wheel_running else 0.0)+(3.2 if steam_running else 0.0)-(0.3 if built.has("lamp") else 0.0)),0,120)
	lamp_on = built.has("lamp") and charge > 0
	if built.has("cable") and steam_running: underground_power = minf(160,underground_power+delta*2)
	elapsed = 0.0
	phase = "calm"
func can_launch(boarded: bool) -> bool:
	return volcano_armed and super.can_launch(boarded)
func can_settle(player_below: bool, buddy_below: bool) -> bool:
	return volcano_armed and super.can_settle(player_below,buddy_below)
func surface_damage(pos: Vector3) -> float:
	if not volcano_armed: return 0.0
	# The original volcano threatens its valley, not every distant biome.
	if absf(pos.x) > 30.0 or pos.z < -24.0 or pos.z > 34.0: return 0.0
	return super.surface_damage(pos)
