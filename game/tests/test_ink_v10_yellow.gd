extends SceneTree
## Behavior contracts use real scene, geometry, physics queries and ordinary held keys.
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ",message)

func _run() -> void:
	check(ResourceLoader.exists("res://v10/blade.gd"),"yellow blade module exists")
	if failures: _finish(); return
	var rules = load("res://v10/sketch_rules.gd")
	var short: Dictionary = rules.analyze(_blade(45),"blade")
	var long: Dictionary = rules.analyze(_blade(170),"blade")
	check(short.ok and long.ok and long.length > short.length,"blade keeps actual short and long dimensions")
	check(long.segments.size() == 4 and long.strokes.size() == 2,"blade retains original outline and separate handguard without pen-up connector")
	var elastic: Dictionary = rules.analyze(_blade(170),"blade","Elastic")
	check(elastic.ok and is_equal_approx(elastic.length,long.length*1.4) and is_equal_approx(elastic.segments[0][1].y,long.segments[0][1].y*1.4),"Elastic scales both real blade mesh and contact coordinates")
	check(rules.analyze(_blade(170),"blade","Sharp").ok,"Sharp is a valid single yellow property")
	check(not rules.analyze(_blade(170),"blade","Sticky").ok,"unsupported yellow property fails explicitly")
	var game = load("res://v10/ink_world.tscn").instantiate()
	root.add_child(game)
	await physics_frame; await process_frame
	game.begin_adventure()
	game.select_color("yellow")
	check(game.selected_color == "black" and game.selected_kind == "ladder","yellow is locked before actual black pickups")
	game.goals = [true,true,false]; game.collect_goals()
	check(not game.yellow_unlocked and not game.won,"two black goals cannot unlock yellow or final ending")
	game.player.position = game.goal_positions[2]+Vector3(0,game.FEET_OFFSET,0)
	game.collect_goals()
	check(game.yellow_unlocked and not game.won and game.result_open,"three actual black contacts unlock chapter transition without winning")
	check(game.result_label.text.contains("黄墨") and not game.result_label.text.contains("路是你画出来的"),"transition copy is distinct from final ending")
	game.close_result(); game.select_color("yellow")
	check(game.selected_kind == "blade" and game.buttons.ladder.disabled and not game.buttons.blade.disabled,"yellow exposes blade with clear color/category relationship")
	game.draw_pad.set_strokes(_blade(170)); game.select_property("Sharp")
	check(game.selected_property == "None","uncollected Sharp cannot be activated")
	game.player.position = game.landmark_positions.word_Sharp+Vector3(0,game.FEET_OFFSET,0)
	game.collect_words(); game.select_property("Sharp")
	check("Sharp" in game.words and game.selected_property == "Sharp","Sharp word is picked up at its actual world location")
	var black_before: float = game.ink.black
	var yellow_before: float = game.ink.yellow
	check(game.apply_drawing() and game.weapon != null,"saving yellow drawing equips original geometry at the hand")
	check(game.ink.black == black_before and game.ink.yellow < yellow_before,"yellow drawing spends only yellow ink")
	check(game.weapon.analysis.segments == game.active_tool.segments and game.weapon.get_parent() == game.actor,"held mesh uses retained analysis and follows original painter")
	game.toggle_notebook()
	var swing_before: int = game.weapon.swing_number
	var mouse := InputEventMouseButton.new(); mouse.button_index = MOUSE_BUTTON_LEFT; mouse.pressed = true
	mouse.position = game.draw_pad.get_global_rect().get_center()
	game._unhandled_input(mouse)
	check(game.weapon.swing_number == swing_before and game.structures.is_empty(),"notebook drawing clicks never swing or place into the world")
	game.toggle_notebook()
	var paid: float = game.weapon.analysis.cost
	game.ink.yellow = 0; game.draw_pad.set_strokes(_blade(260))
	var retained: Dictionary = game.active_tool.duplicate(true)
	check(not game.apply_drawing() and game.active_tool == retained and game.draw_pad.get_strokes().size() == 2,"failed expensive replacement preserves equipped tool and drawing")
	game.player.position = game.fountains[-1]+Vector3(0,game.FEET_OFFSET,0); game.interact()
	check(game.ink.yellow == game.MAX_YELLOW_INK and game.ink.black == game.MAX_BLACK_INK,"courtyard fountain refills both independently metered inks")
	check(game.reclaim_weapon() and game.weapon == null and game.ink.yellow == game.MAX_YELLOW_INK,"safe blade refund has no ink softlock")
	game.draw_pad.set_strokes(_blade(45)); game.select_property("Sharp"); game.apply_drawing()
	game.player.position = Vector3(28.55,game.FEET_OFFSET,0); game.actor.rotation.y = PI/2
	await physics_frame
	check(game.attack() and not game.attack(),"attack has a real cooldown preventing repeated immediate strikes")
	await _frames(32)
	check(not game.vines_cut,"short original blade cannot contact same far vine")
	game.draw_pad.set_strokes(_blade(170)); game.apply_drawing()
	game.attack(); await _frames(32)
	check(game.vines_cut and not game.vine_body.collision_layer,"long Sharp blade physically contacts and cuts blocking vine collision")
	game.reset_run(); await physics_frame
	check(not game.vines_cut and game.vine_body.collision_layer != 0 and game.weapon == null and game.player_hp == game.MAX_HP,"reset restores vines, health, locked yellow and unequipped state")
	_unlock(game); game.close_result(); game.select_color("yellow")
	game.draw_pad.set_strokes(_blade(170)); game.apply_drawing()
	game.player.position = Vector3(28.55,game.FEET_OFFSET,0); game.actor.rotation.y = PI/2
	game.attack(); await _frames(32)
	check(not game.vines_cut,"plain blade contact cannot cut soft vines without Sharp")
	game.player.position = game.landmark_positions.word_Sharp+Vector3(0,game.FEET_OFFSET,0); game.collect_words()
	game.select_property("Sharp"); game.apply_drawing()
	game.player.position = Vector3(28.55,game.FEET_OFFSET,0); game.actor.rotation.y = PI/2
	game.attack(); game.select_color("black"); await _frames(32)
	check(not game.vines_cut and not game.weapon.visible and not game.attack(),"switching to black stows real blade and cancels hidden combat")
	game.select_color("yellow")
	game.select_property("None")
	game.draw_pad.set_strokes(_blade(130)); game.apply_drawing()
	game.player.position = Vector3(31.0,game.FEET_OFFSET,0); game.actor.rotation.y = PI/2
	game.attack(); await _frames(32)
	check(game.enemy_hp == game.ENEMY_MAX_HP,"ordinary 130px blade cannot reach far inkling at same player position")
	game.words.append("Elastic"); game.select_property("Elastic")
	game.draw_pad.set_strokes(_blade(130)); game.apply_drawing()
	check(is_equal_approx(game.weapon.analysis.length,130*0.014*1.4),"equipped Elastic blade has its larger physical reach")
	game.attack(); await _frames(32)
	check(game.enemy_hp < game.ENEMY_MAX_HP,"same original Elastic blade now physically contacts far inkling collider")
	var hp_after: int = game.enemy_hp
	await _frames(15)
	check(game.enemy_hp == hp_after,"each swing damages a contacted target only once")
	game.player.position = game.enemy_body.position-Vector3(0.7,0,0)
	game.player_invulnerability = 0
	await _frames(65)
	check(game.player_hp < game.MAX_HP,"enemy has readable windup followed by actual near attack")
	var player_hp_after: int = game.player_hp
	await _frames(8)
	check(game.player_hp == player_hp_after,"enemy recovery prevents frame-by-frame contact damage")
	game.safe_point = Vector3(27.2,game.FEET_OFFSET,0); game.player_hp = 1; game.player_invulnerability = 0
	game.damage_player(1)
	check(game.player_hp == game.MAX_HP and game.weapon != null and game.draw_pad.get_strokes().size() == 2,"death safely restores health while preserving drawing and held weapon")
	game.reset_run(); await physics_frame
	_unlock(game); game.close_result()
	game.player.position = Vector3(28.05,game.FEET_OFFSET,0); await physics_frame
	await _hold(KEY_D,60)
	check(game.player.position.x < 30.3 and not game.won,"actual uncut vine blocks ordinary walking and cannot trigger ending")
	game.player.position = Vector3(27.9,game.FEET_OFFSET,0.65); await physics_frame
	game.draw_pad.set_strokes(_ladder(280)); game.select_kind("ladder"); game.apply_drawing()
	check(game.place_active(game.landmark_positions.yellow_ledge),"black original ladder reaches actual bypass ledge above vines")
	await _tap(KEY_E)
	check(game.climbing_id >= 0,"ordinary E beside bypass ladder foot enters real climb instead of nearby fountain")
	await _climb_with_input(game)
	check(game.climbing_id < 0 and game.player.position.y > 3.1,"bypass ladder exits on supported ledge above obstruction")
	await _hold(KEY_D,90)
	check(game.player.position.x > 32 and not game.vines_cut,"black bypass physically crosses vine without cutting or walking around fence")
	check(not game.won,"crossing vines and enemy alone does not complete final page")
	game.player.position = game.fountains[-1]+Vector3(0,game.FEET_OFFSET,0); game.ink.black = 0
	await physics_frame; await _tap(KEY_E)
	check(game.ink.black == game.MAX_BLACK_INK and game.climbing_id < 0,"ordinary E at fountain still refills when bypass ladder is also nearby")
	game.player.position = Vector3(34.85,game.FEET_OFFSET,0)
	await _frames(3)
	await _tap(KEY_SPACE); await _hold(KEY_D,55)
	print("FINAL_PAGE_DIAGNOSTIC player=",game.player.position," final=",game.final_goal_collected," message=",game.message_label.text)
	check(game.won and game.final_goal_collected and game.result_label.text.contains("路是你画出来的。"),"only actual final courtyard page arrival completes ending")
	var qa: Dictionary = game.qa_snapshot()
	check(qa.has("combat") and qa.has("weapon") and qa.has("vines") and qa.has("enemy") and qa.has("final_goal") and qa.ui.has("result_text"),"read-only QA publishes real combat, geometry, target and distinct result text")
	game.queue_free(); await process_frame
	_finish()

func _unlock(game) -> void:
	for i in 3:
		game.player.position = game.goal_positions[i]+Vector3(0,game.FEET_OFFSET,0)
		game.collect_goals()

func _blade(length: float) -> Array:
	return [PackedVector2Array([Vector2(130,280),Vector2(120,280-length),Vector2(140,280-length),Vector2(130,280)]),PackedVector2Array([Vector2(100,267),Vector2(160,267)])]

func _ladder(height: float) -> Array:
	return [PackedVector2Array([Vector2(80,290),Vector2(80,290-height)]),PackedVector2Array([Vector2(145,290),Vector2(145,290-height)]),PackedVector2Array([Vector2(80,290-height*0.3),Vector2(145,290-height*0.3)]),PackedVector2Array([Vector2(80,290-height*0.7),Vector2(145,290-height*0.7)])]

func _frames(count: int) -> void:
	for frame in count: await physics_frame

func _hold(code: Key, count: int) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.keycode = code; event.pressed = true
	Input.parse_input_event(event); await _frames(count)
	event.pressed = false; Input.parse_input_event(event); await physics_frame

func _climb_with_input(game) -> void:
	var event := InputEventKey.new(); event.physical_keycode = KEY_W; event.keycode = KEY_W; event.pressed = true
	Input.parse_input_event(event)
	for frame in 200:
		await physics_frame
		if game.climbing_id < 0: break
	event.pressed = false; Input.parse_input_event(event); await physics_frame

func _tap(code: Key) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.keycode = code; event.pressed = true
	Input.parse_input_event(event); await physics_frame
	event.pressed = false; Input.parse_input_event(event); await physics_frame

func _finish() -> void:
	print("INK_V10_YELLOW_CHECKS=%d FAILURES=%d" % [checks,failures]); quit(1 if failures else 0)
