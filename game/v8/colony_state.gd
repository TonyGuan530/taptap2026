extends RefCounted
## Durable colony journal. Positions are always absolute world coordinates.
const SPECIES := {"triceratops":"三角龙","stegosaurus":"剑龙","velociraptor":"迅猛龙"}
const SPECIALTIES := {"triceratops":"采集每趟3份 / 搬运","stegosaurus":"设施工作加速 / 驻守","velociraptor":"远距巡逻 / 驱赶捕食者"}
const TASKS := {"follow":"跟随","guard":"驻守","harvest":"采集","work":"营地工作","idle":"休息"}
const BUILDINGS := {
	"depot":{"name":"补给仓","cost":{"wood":4,"copper":1},"size":[3.0,2.2],"detail":"存入3果作为附近伙伴工资；采集伙伴在最近仓库交货。"},
	"farm":{"name":"浆果农圃","cost":{"wood":4,"water":2},"size":[3.0,3.0],"detail":"20秒成熟；用1水收获3果。派伙伴照料可加速。"},
	"workshop":{"name":"燃料工坊","cost":{"wood":5,"copper":3},"size":[3.2,2.4],"detail":"点亮科技灯后，木2铜1制煤2。工人可每12秒自动加工。"},
	"shelter":{"name":"伙伴休息棚","cost":{"wood":6,"food":2},"size":[3.4,3.0],"detail":"消耗1果治疗；在棚旁休息恢复生命、减缓饥饿。"},
	"beacon":{"name":"营地灯塔","cost":{"wood":2,"copper":1,"quartz":1},"size":[1.6,1.6],"detail":"需要灯泡科技与蓄电；实际照明，守卫警戒范围扩大。"}
}
var relationships: Dictionary = {}
var buildings: Dictionary = {}
var next_building := 1
func meet(id: String, kind: String, home: Array, saved: Dictionary = {}) -> Dictionary:
	if relationships.has(id): return relationships[id]
	var value := absi(id.hash())
	var species := "velociraptor" if kind == "predator" else ("triceratops" if value%2 == 0 else "stegosaurus")
	var record := {"id":id,"kind":kind,"species":species,"name":["苔","栗","云","石","叶","灰"][value%6]+["角","芽","尾","点","铃"][value%5]+str(value%97),"temperament":["友善","谨慎","倔强"][value%3],"trust":0,"greeted":false,"last_feed":-1000.0,"hired":false,"task":"idle","building":"","xyz":home.duplicate(),"home":home.duplicate(),"wage_timer":0.0,"fed":true,"delivered":0,"carry":0,"carry_key":"","work_timer":0.0,"phase":"outbound","guard_xyz":home.duplicate()}
	for key in record:
		if saved.has(key): record[key] = saved[key]
	record.detached = bool(saved.get("detached",false))
	if id == "core:buddy": record.name = "阿角"; record.species = "triceratops"; record.temperament = "友善"
	if id == "core:predator": record.name = "赤尾"; record.species = "velociraptor"
	relationships[id] = record
	return record
func social(id: String, action: String, stock: Dictionary, now: float) -> Dictionary:
	if not relationships.has(id): return {"ok":false,"message":"这只恐龙已经离开。"}
	var record: Dictionary = relationships[id]
	match action:
		"greet":
			if record.greeted: return {"ok":false,"message":"已经互相认识了。投喂食物可继续建立信任。"}
			record.greeted = true; record.trust = mini(100,record.trust+8)
			return {"ok":true,"message":"%s记住了你的气味。信任 +8。" % record.name}
		"feed":
			if now-float(record.last_feed) < 5: return {"ok":false,"message":"刚刚吃过，继续行动5秒后再喂。"}
			if int(stock.food) < 1: return {"ok":false,"message":"投喂需要1果。捕食者在得到信任前仍可能攻击。"}
			stock.food -= 1; record.last_feed = now; record.fed = true
			var gain: int = {"友善":18,"谨慎":16,"倔强":14}[record.temperament]
			record.trust = mini(100,record.trust+gain)
			return {"ok":true,"message":"%s吃下1果。信任 +%d（%d/35 可雇佣）。" % [record.name,gain,record.trust]}
		"hire":
			if record.hired: return {"ok":false,"message":"它已经是营地伙伴。"}
			if record.trust < 35: return {"ok":false,"message":"需要信任35。先问候和投喂；投喂间隔5秒。"}
			if int(stock.food) < 2: return {"ok":false,"message":"雇佣需2果，之后每45秒1果工资。"}
			var count := 0
			for friend in relationships.values():
				if friend.hired: count += 1
			if count >= 8: return {"ok":false,"message":"营地最多8位伙伴，先解雇一位再邀请。"}
			stock.food -= 2; record.hired = true; record.task = "follow"; record.wage_timer = 0.0
			return {"ok":true,"message":"%s加入营地！每45秒需1果；%s。" % [record.name,SPECIALTIES[record.species]]}
		"dismiss":
			record.hired = false; record.task = "idle"; record.building = ""
			# Dismissal does not recreate an actor at its original spawn point.
			record.home = record.xyz.duplicate()
			return {"ok":true,"message":"%s自由了；信任保留，可在这里再次相遇。" % record.name}
	return {"ok":false,"message":"无法执行这个互动。"}
func assign(id: String, task: String, location: Array, building := "") -> bool:
	if not relationships.has(id) or not relationships[id].hired or not TASKS.has(task): return false
	var record: Dictionary = relationships[id]
	record.task = task; record.building = building; record.guard_xyz = location.duplicate(); record.work_timer = 0.0
	return true
func afford(stock: Dictionary, cost: Dictionary) -> bool:
	for key in cost:
		if int(stock.get(key,0)) < int(cost[key]): return false
	return true
func spend(stock: Dictionary, cost: Dictionary) -> void:
	for key in cost: stock[key] -= int(cost[key])
func footprint(kind: String, point: Vector3, yaw: float, margin := 0.0) -> Rect2:
	var dims: Array = BUILDINGS[kind].size
	var extent := Vector2(float(dims[0]),float(dims[1]))
	if absi(roundi(yaw/(PI/2)))%2 == 1: extent = Vector2(extent.y,extent.x)
	return Rect2(Vector2(point.x,point.z)-extent/2,extent).grow(margin)
func construct(kind: String, point: Vector3, yaw: float, stock: Dictionary) -> String:
	if not BUILDINGS.has(kind) or not afford(stock,BUILDINGS[kind].cost): return ""
	spend(stock,BUILDINGS[kind].cost)
	var id := "building:%d" % next_building
	next_building += 1
	buildings[id] = {"id":id,"kind":kind,"xyz":[point.x,point.y,point.z],"yaw":yaw,"level":1,"progress":0.0,"ready":false,"stored_food":0,"spent":BUILDINGS[kind].cost.duplicate(),"produced":0,"powered":false}
	return id
func upgrade_cost(id: String) -> Dictionary:
	if not buildings.has(id): return {}
	return {"wood":4*int(buildings[id].level),"copper":2*int(buildings[id].level)}
func upgrade(id: String, stock: Dictionary) -> bool:
	if not buildings.has(id) or int(buildings[id].level) >= 3: return false
	var cost := upgrade_cost(id)
	if not afford(stock,cost): return false
	spend(stock,cost); buildings[id].level += 1
	for key in cost: buildings[id].spent[key] = int(buildings[id].spent.get(key,0))+int(cost[key])
	return true
func demolish(id: String, stock: Dictionary) -> bool:
	if not buildings.has(id): return false
	var building: Dictionary = buildings[id]
	for key in building.spent: stock[key] += int(building.spent[key])/2
	stock.food += int(building.stored_food)
	buildings.erase(id)
	for record in relationships.values():
		if record.building == id: record.building = ""; record.task = "guard"
	return true
func snapshot() -> Dictionary:
	return {"relationships":relationships.duplicate(true),"buildings":buildings.duplicate(true),"next_building":next_building}
func restore(data: Dictionary) -> void:
	relationships = data.get("relationships",{}).duplicate(true)
	buildings = data.get("buildings",{}).duplicate(true)
	next_building = int(data.get("next_building",1))
