extends RefCounted
## Resource costs and six-minute disaster clock. Positions decide real danger.
const RECIPES := {
	"wheel":{"name":"水轮发电","cost":{"wood":3,"copper":2,"magnet":1},"charge":0,"stage":0,"site":"wheel"},
	"lamp":{"name":"营地灯泡","cost":{"copper":1,"quartz":1},"charge":8,"stage":1,"site":"camp"},
	"steam":{"name":"蒸汽动力","cost":{"wood":3,"copper":2,"coal":2,"water":2},"charge":0,"stage":2,"site":"camp"},
	"ship":{"name":"高地飞船","cost":{"wood":6,"copper":3,"quartz":2,"coal":3},"charge":25,"stage":3,"site":"highland"},
	"shelter":{"name":"地下寝室与通风","cost":{"wood":6,"copper":2,"quartz":1},"charge":0,"stage":3,"site":"underground"},
	"cable":{"name":"地下电缆与储能","cost":{"copper":2,"magnet":1},"charge":15,"stage":3,"site":"underground"},
	"provisions":{"name":"地下食水储备","cost":{"food":6,"water":3},"charge":0,"stage":3,"site":"underground"}
}
var stock := {"wood":0,"food":0,"copper":0,"magnet":0,"quartz":0,"coal":0,"water":0}
var built: Dictionary = {}
var stage := 0
var elapsed := 0.0
var phase := "calm"
var charge := 0.0
var wheel_running := false
var steam_running := false
var lamp_on := false
var fuel_seconds := 0.0
var steam_seconds := 0.0
var sheltered_seconds := 0.0
var underground_power := 0.0
func craft(key: String) -> bool:
	if not RECIPES.has(key) or built.has(key): return false
	var recipe: Dictionary = RECIPES[key]
	if stage < recipe.stage or charge < recipe.charge: return false
	for material in recipe.cost:
		if stock[material] < recipe.cost[material]: return false
	for material in recipe.cost: stock[material] -= recipe.cost[material]
	charge -= recipe.charge
	built[key] = true
	if key in ["wheel","lamp","steam"]: stage += 1
	if key == "steam": fuel_seconds = 240.0
	if key == "cable": underground_power = 160.0
	return true
func refuel() -> bool:
	if not built.has("steam") or stock.coal < 1 or stock.water < 1: return false
	stock.coal -= 1
	stock.water -= 1
	fuel_seconds += 180.0
	return true
func tick(delta: float, player_below := false, buddy_below := false) -> void:
	var previous_elapsed := elapsed
	elapsed += delta
	phase = "after" if elapsed >= 360 else ("eruption" if elapsed >= 300 else ("ash" if elapsed >= 240 else ("warning" if elapsed >= 180 else "calm")))
	wheel_running = built.has("wheel") and elapsed < 240
	steam_running = built.has("steam") and fuel_seconds > 0
	if steam_running:
		fuel_seconds = maxf(0,fuel_seconds-delta)
		steam_seconds += delta
	charge = clampf(charge + delta*((2.5 if wheel_running else 0.0)+(3.2 if steam_running else 0.0)-(0.3 if built.has("lamp") else 0.0)),0,120)
	lamp_on = built.has("lamp") and charge > 0
	if built.has("cable"):
		if steam_running: underground_power = minf(160,underground_power+delta*2)
		elif elapsed >= 300: underground_power = maxf(0,underground_power-delta)
	if player_below and buddy_below and underground_ready():
		# Credit only the actual part of this frame spent enduring the eruption.
		sheltered_seconds += maxf(0,minf(elapsed,360)-maxf(previous_elapsed,300))
func underground_ready() -> bool:
	return built.has("shelter") and built.has("cable") and built.has("provisions") and underground_power > 0
func can_launch(buddy_boarded: bool) -> bool:
	return elapsed >= 300 and built.has("ship") and stage == 3 and steam_seconds >= 5 and charge >= 25 and buddy_boarded
func can_settle(player_below: bool, buddy_below: bool) -> bool:
	return elapsed >= 360 and sheltered_seconds >= 20 and underground_ready() and player_below and buddy_below
func surface_damage(pos: Vector3) -> float:
	if elapsed < 300 or elapsed >= 360 or pos.y < -3.5 or pos.y > 4.5: return 0.0
	return 11.0
