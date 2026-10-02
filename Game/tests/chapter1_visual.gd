extends SceneTree

const SCENE: PackedScene = preload("res://scenes/chapter/chapter_one.tscn")
var app: ChapterOne
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var captures: Array[String] = []
var started: int = 0
var timer_trace: Array[Dictionary] = []
var _last_trace: int = 0
var focus_events: Array[Dictionary] = []
var held_input_resets: int = 0


func _initialize() -> void:
	_run.call_deferred()


func expect(condition: bool, message: String) -> void:
	checks.append({"passed": condition, "message": message})
	if not condition:
		failures.append(message)
		push_error(message)
		_write_report()
		quit(1)


func frames(count: int) -> void:
	for index: int in range(count): await process_frame


func key(code: int, held_frames: int = 1) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(held_frames)
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	await frames(2)


func click(button: Button) -> void:
	if button == null:
		expect(false, "Expected visible button exists")
		return
	var point: Vector2 = root.get_final_transform() * (button.get_global_transform_with_canvas() * (button.size * 0.5))
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await frames(1)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(2)


func button_named(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix): return node as Button
	for child: Node in node.get_children():
		var found: Button = button_named(child, prefix)
		if found != null: return found
	return null


func capture(label: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	var path: String = "res://.dev/chapter1-%s.png" % label
	root.get_texture().get_image().save_png(path)
	captures.append(path)
	print("[CHAPTER1 VISUAL] capture ", label, " at ", (Time.get_ticks_msec()-started)/1000.0, "s")


func drain_dialogue(photograph_speaker: String = "") -> void:
	for index: int in range(1200):
		if app.mode == "cinematic":
			await create_timer(0.05).timeout
			continue
		if app.mode != "dialogue": return
		if app.hud.speaker_label.text == photograph_speaker:
			await capture("su-visit" if photograph_speaker == "苏挽颜" else "dorm-video")
			photograph_speaker = ""
		if app.hud.advance_button.disabled:
			await create_timer(0.05).timeout
		else:
			expect(app.hud.body_label.get_minimum_size().y <= app.hud.body_label.size.y, "Chinese dialogue fits: " + app.hud.speaker_label.text)
			await key(KEY_ENTER)
	expect(false, "Dialogue completes within bounded input loop")


func wait_for_mode(target: String, seconds: float = 8.0) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while app.mode != target and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	expect(app.mode == target, "Timed scene reaches " + target)


func skip_arrival() -> void:
	if app.mode == "cinematic": app.cinematics.skip()
	while app.mode == "dialogue": app.advance_dialogue()
	if app.mode == "cinematic": app.cinematics.skip()
	expect(app.mode == "world" and app.state.room == "auditorium", "Skip follows arrival endpoints into the detection hall")


func choose(index: int) -> void:
	expect(app.mode == "choice", "Choice modal available")
	if index <= 1:
		await click(button_named(app.hud.choice_layer, "%d · " % (index + 1)))
	else:
		await key(KEY_1 + index)
	await drain_dialogue("苏挽颜" if app.state.phase == "cafe" else "")


func move_axis(axis: int, target: float) -> void:
	var offset: float = target - app.world.player.position[axis]
	if absf(offset) < 4.0: return
	var code: int = (KEY_D if offset > 0 else KEY_A) if axis == 0 else (KEY_S if offset > 0 else KEY_W)
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	var movement_deadline: int = Time.get_ticks_msec() + int(absf(offset) / app.world.player.move_speed * 1000) + 3000
	for count: int in range(550):
		if count > 0 and not Input.is_physical_key_pressed(code):
			held_input_resets += 1
			var held_event: InputEventKey = InputEventKey.new()
			held_event.physical_keycode = code
			held_event.pressed = true
			Input.parse_input_event(held_event)
		await physics_frame
		var remaining: float = target - app.world.player.position[axis]
		if absf(remaining) < 4.0 or signf(remaining) != signf(offset): break
		if Time.get_ticks_msec() >= movement_deadline: break
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	await frames(2)
	expect(absf(app.world.player.position[axis] - target) < 7.0, "Walking reaches requested axis without collision deadlock: axis%d, wanted %.1f, actual %s, mode %s" % [axis, target, app.world.player.position, app.mode])


func walk_to(id: String) -> void:
	if app.state.room in ["clubs","dorm","c2_dorm","corridor","cult_library","cult_ice_shop"]:
		await walk_furnished(id)
		return
	var entry: Dictionary = {}
	for actor: Dictionary in app.world.interactions:
		if actor.id == id: entry = actor; break
	if entry.is_empty(): expect(false, "Interaction exists: " + id); return
	var target: Array = entry.get("interactionPosition",entry.position)
	await move_axis(0, float(target[0]))
	await move_axis(1, float(target[1]) + 58.0)
	expect(String(app.world.closest_interaction().get("id", "")) == id, "Walking exposes correct E target: " + id)


func walk_furnished(id: String) -> void:
	var entry: Dictionary = {}
	for actor: Dictionary in app.world.interactions:
		if actor.id==id: entry=actor;break
	expect(not entry.is_empty(),"Interaction exists: "+id)
	var anchor: Array = entry.get("interactionPosition",entry.position)
	var target: Vector2 = Vector2(float(anchor[0]),float(anchor[1])+58)
	# Small furnished rooms need an approach beside a table, or between neighbours.
	# Choose a free point that really makes this actor the closest E interaction.
	var best_distance: float = INF
	for x: int in range(floori((float(anchor[0])-84)/12),ceili((float(anchor[0])+85)/12)):
		for y: int in range(floori((float(anchor[1])-84)/12),ceili((float(anchor[1])+85)/12)):
			var point: Vector2 = Vector2(x,y)*12
			var distance: float = point.distance_to(Vector2(float(anchor[0]),float(anchor[1])))
			if distance>=82 or not app.world.can_stand(point): continue
			var closest: bool = true
			for other: Dictionary in app.world.interactions:
				if String(other.id)==id: continue
				var other_anchor: Array = other.get("interactionPosition",other.position)
				if point.distance_to(Vector2(float(other_anchor[0]),float(other_anchor[1])))<=distance: closest=false;break
			var score: float = point.distance_to(app.world.player.position)+distance*.5
			if closest and score<best_distance: best_distance=score;target=point
	expect(best_distance<INF,"Free approach exposes nearest E interaction: "+id)
	# Find a route using real collision footprints; play every segment through WASD.
	var origin: Vector2i = Vector2i((app.world.player.position/12).round())
	var goal: Vector2i = Vector2i((target/12).round())
	var parents: Dictionary = {origin:origin}
	var queue: Array[Vector2i] = [origin]
	var found: bool = false
	while not queue.is_empty():
		var point: Vector2i = queue.pop_front()
		if point==goal: found=true;break
		for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = point+direction
			if not parents.has(next) and app.world.can_stand(Vector2(next)*12): parents[next]=point;queue.append(next)
	expect(found,"Collision route reaches "+id)
	if not found: return
	var path: Array[Vector2i] = [goal]
	while path.back()!=origin: path.append(parents[path.back()])
	path.reverse()
	var simplified: Array[Vector2i] = []
	for index: int in range(path.size()):
		if index==0 or index==path.size()-1 or path[index]-path[index-1]!=path[index+1]-path[index]: simplified.append(path[index])
	for point: Vector2i in simplified:
		await move_axis(0,point.x*12)
		await move_axis(1,point.y*12)
	await move_axis(0,target.x)
	await move_axis(1,target.y)
	expect(String(app.world.closest_interaction().get("id",""))==id,"Walking exposes correct E target: "+id)


func interact(id: String) -> void:
	await walk_to(id)
	await key(KEY_E)
	expect(app.mode in ["dialogue","cinematic"], "E opens scene interaction for " + id)
	await drain_dialogue()


func travel(room: String) -> void:
	await key(KEY_M)
	await click(button_named(app.hud.menu_card, String(ChapterStory.ROOM_NAMES[room])))
	expect(app.mode == "world" and app.state.room == room, "Mouse map travel reaches " + room)


func actual_command(sandbox: ChapterTutorial) -> void:
	var controller: BattleController = sandbox.controller
	var actor: CombatantState = controller.current_actor()
	var targets: Array[CombatantState] = controller.living_team(false)
	var target: CombatantState = targets[0]
	for candidate: CombatantState in targets:
		var advantage: float = BattleCalculator.attack_preview(actor, candidate, controller.encounter).modifiers.affinity
		var current: float = BattleCalculator.attack_preview(actor, target, controller.encounter).modifiers.affinity
		if advantage > current or (advantage == current and candidate.hp < target.hp): target = candidate
	for attempt: int in range(6):
		if sandbox.hud.selected_target == target.id: break
		await key(KEY_TAB)
	if sandbox.lesson_index > 0 and controller.can_breakthrough(actor) and actor.hp < actor.max_hp() * 0.8 and actor.weak_actions == 0:
		await click(sandbox.hud.break_button)
	elif (sandbox.lesson_index == 2 and not sandbox.observed_goals().has("defend")) or (targets.size() == 1 and actor.hp < actor.max_hp() * 0.6) or actor.sl >= 70 or actor.weak_actions > 0:
		await click(sandbox.hud.defense_button)
	elif sandbox.lesson_index > 0 and targets.size() > 1 and actor.cooldown_for(&"sweep") == 0:
		await click((sandbox.hud as TutorialHUD).skill_buttons[1])
	elif sandbox.lesson_index > 0 and actor.cooldown_for(&"strike") == 0:
		await key(KEY_1)
	else:
		await click(sandbox.hud.attack_button)


func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	started = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.dev"))
	app = SCENE.instantiate() as ChapterOne
	app.save_path = "user://saves/test_chapter1_visual.json"
	root.add_child(app)
	current_scene = app
	root.focus_entered.connect(func() -> void: focus_events.append({"seconds": (Time.get_ticks_msec()-started)/1000.0, "focused": true}))
	root.focus_exited.connect(func() -> void: focus_events.append({"seconds": (Time.get_ticks_msec()-started)/1000.0, "focused": false}))
	await frames(12)
	for requested: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = requested
		await frames(12)
		var expected: int = maxi(1, roundi(minf(requested.x / 960.0, requested.y / 540.0)))
		expect(root.size == requested and app.display.world_scale == expected, "Integer world scale at " + str(requested))
		var expected_source: Vector2i = Vector2i(ceili(float(requested.x) / expected), ceili(float(requested.y) / expected))
		expect(app.display.world_viewport.size == expected_source and app.hud.size.x >= 1919.9 and app.hud.size.y >= 1079.9, "Adaptive world and separate 1080p UI at " + str(requested))
		expect(app.world.camera.zoom == Vector2(2, 2), "Exploration uses integer 2x close camera at " + str(requested))
		await capture("title-%dx%d" % [requested.x, requested.y])
	root.mode = Window.MODE_MAXIMIZED
	await frames(12)
	expect(root.mode == Window.MODE_MAXIMIZED and root.get_final_transform().is_equal_approx(Transform2D.IDENTITY), "Full chapter playthrough uses the native maximized client area")
	await capture("title-maximized")
	await click(button_named(app.hud.title_layer, "开始游戏"))
	expect(app.mode == "cinematic" and app.state.room == "gate", "New game begins with an actual walk to the academy gate")
	await wait_for_mode("dialogue")
	expect(app.mode == "dialogue" and app.state.relations.wen_rang == 80, "Actual new game opens arrival with Wen")
	var before: Vector2 = app.world.player.position
	await key(KEY_W, 12)
	expect(app.world.player.position == before, "Dialogue blocks actual walking input")
	await capture("arrival")
	await drain_dialogue()
	await walk_to("exam")
	await capture("exploration-close")
	await interact("exam")
	expect(app.state.phase == "mentors" and app.state.sl == 5, "Reading-delay test opens mentor phase")
	await capture("plaza")
	await interact("liu")
	await travel("training")
	await interact("comic")
	await interact("liu")
	await choose(1)
	await travel("plaza")
	await interact("shen")
	await choose(0)
	for answer: int in [0, 1, 2]: await choose(answer)
	await choose(1)
	await interact("wen")
	await travel("lab")
	for sample: String in ["sample_fire", "sample_water", "sample_earth"]: await interact(sample)
	await capture("lab")
	await interact("wen")
	await choose(1)
	await travel("plaza")
	await interact("tang")
	await travel("infirmary")
	await interact("cabinet")
	await choose(1)
	await choose(0)
	await choose(0)
	await choose(0)
	await choose(0)
	await choose(1)
	await choose(1)
	expect(app.state.mentor.is_empty() and app.state.flags.get("tang_done", false), "Actual incorrect/correct medicine choices preserve optional trial")
	await travel("plaza")
	await key(KEY_F5)
	var saved_point: Vector2 = app.world.player.position.round()
	await key(KEY_D, 12)
	await key(KEY_F9)
	expect(app.world.player.position.round() == saved_point and app.state.flags.get("shen_done", false), "Actual F5/F9 preserves position and trial answers")
	await interact("liu")
	await choose(0)
	expect(app.state.mentor == "liu", "Actual mentor confirmation locks one branch")
	expect(app.mode == "choice" and app.state.room == "plaza" and app.state.flags.get("su_visit_seen", false), "Su walks up and starts her request automatically in the current mentor area")
	expect(app.state.flags.get("hill_route_received", false), "Every Su option follows the shared voucher and entrance-location dialogue")
	await choose(2)
	expect(app.state.phase == "hill" and app.state.flags.invite_wen and app.state.relations.su == 40, "Invitation route reaches next morning with Wen")
	await capture("hill")
	await interact("hill")
	await choose(0)
	expect(app.mode == "battle" and app.battle != null, "Actual interaction enters skinned tutorial")
	var sandbox: ChapterTutorial = app.battle
	var hud: TutorialHUD = sandbox.hud as TutorialHUD
	var chapter_hud: ChapterBattleHUD = hud as ChapterBattleHUD
	expect(chapter_hud != null and (chapter_hud.FIELD_BOTTOM - chapter_hud.FIELD_TOP) / 1080.0 >= 0.62, "Compact chapter HUD leaves over 62 percent of height for the battlefield")
	await capture("battle-intro")
	await click(hud.primary_button)
	await key(KEY_H)
	expect(not sandbox.hints_enabled, "Actual H still hides chapter battle hints")
	await key(KEY_H)
	await key(KEY_A)
	await key(KEY_R)
	expect(sandbox.lesson_index == 0 and sandbox.controller.living_team(true)[0].hp == app.state.hp, "Actual R restores campaign opening during presentation")
	await key(KEY_L)
	expect(chapter_hud.log_drawer.visible, "Actual L opens optional battle log")
	await key(KEY_ESCAPE)
	expect(not chapter_hud.log_drawer.visible and app.battle == sandbox, "Esc closes battle log before leaving the fight")
	var photographed: Dictionary = {}
	var battle_deadline: int = Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < battle_deadline:
		trace_timers(sandbox)
		if sandbox.flow in [&"complete", &"failed"]: break
		if not photographed.has(sandbox.lesson_index):
			photographed[sandbox.lesson_index] = true
			for view: CombatantView in sandbox._views.values():
				expect(view.scale == Vector2(3, 3), "Chapter combatant uses integer 3x art scale")
				var art_bounds: Rect2 = Rect2(view.position + view._art_rect.position * view.scale, view._art_rect.size * view.scale)
				var ui_bounds: Rect2 = Rect2(sandbox.display.world_to_ui(art_bounds.position), sandbox.display.world_to_ui(art_bounds.end) - sandbox.display.world_to_ui(art_bounds.position))
				expect(art_bounds.size.y >= 110 and ui_bounds.position.y >= chapter_hud.FIELD_TOP and ui_bounds.end.y < chapter_hud.size.y - 232, "Large combatant remains wholly inside the uncovered field")
			if sandbox.lesson_index == 1:
				await click(chapter_hud._enemy_hit_buttons[1])
				expect(hud.selected_target == sandbox.controller.combatants[2].id, "Mouse click directly on rabbit selects it")
			await capture("battle-lesson%d" % (sandbox.lesson_index + 1))
		if sandbox.flow == &"between":
			var hero: CombatantState = sandbox.controller.living_team(true)[0]
			var hp_value: int = mini(hero.hp, app.state.max_hp())
			var sl_value: int = hero.sl
			await click(hud.primary_button)
			expect(sandbox.controller.living_team(true)[0].hp == hp_value and sandbox.controller.living_team(true)[0].sl == sl_value, "Actual next-stage click carries campaign HP/SL")
		elif sandbox.controller.phase == BattleController.Phase.PLAYER_COMMAND:
			await actual_command(sandbox)
		await frames(1)
	expect(sandbox.flow == &"complete" and sandbox.completed_lessons.size() == 3, "Real GPU inputs and timers clear all three lessons")
	if sandbox.flow != &"complete": _write_report(); quit(1); return
	await capture("battle-complete")
	await click(hud.primary_button)
	await drain_dialogue()
	expect(app.battle == null and app.state.phase == "clubs" and app.state.tutorial_log.completed_lessons.size() == 3, "Completion returns HP/SL and all logs to chapter")
	await travel("clubs")
	await interact("clubs")
	expect(app.mode=="choice" and app.state.room=="clubs" and app.state.phase=="clubs","Recruit conversation remains at the actual stalls until the player chooses to leave")
	await choose(1)
	await walk_to("dorm_wen")
	await key(KEY_E)
	await drain_dialogue("凌未央")
	await interact("dorm_exit")
	await walk_to("chuxia")
	await key(KEY_E)
	await capture("chuxia")
	await drain_dialogue()
	await interact("dorm_enter")
	await interact("sleep")
	expect(app.state.phase == "hall" and app.state.sl == 0 and app.state.hp == app.state.max_hp(), "Actual dorm sleep advances Jan3 and restores shared HP/SL")
	await interact("task")
	await choose(0)
	await key(KEY_M)
	await capture("city-map")
	await click(button_named(app.hud.menu_card, "管理局服务大厅"))
	await walk_to("reception")
	await key(KEY_E)
	await capture("delivery")
	await drain_dialogue()
	await travel("hall")
	await interact("task")
	expect(app.mode == "complete" and app.state.money == 3300 and app.state.contribution == 5, "Title-to-chapter1 ending completes through real inputs")
	expect(not app.hud.toast_panel.visible, "Previous objective toast cannot cover the chapter ending")
	await capture("ending")
	await key(KEY_J)
	expect(app.mode == "menu", "Ending opens chapter archive")
	expect(not app.hud.toast_panel.visible, "Previous objective toast cannot cover the archive title")
	await capture("archive")
	await click(button_named(app.hud.menu_card, "关闭"))
	expect(app.mode == "complete", "Mouse close returns to ending")
	await key(KEY_F11)
	await frames(12)
	expect(root.mode == Window.MODE_FULLSCREEN, "Chapter F11 enters fullscreen")
	await key(KEY_F11)
	await frames(12)
	await click(button_named(app.hud.ending_layer, "回到标题"))
	await click(app.hud.continue_button)
	expect(app.mode == "complete" and app.state.flags.task_rewarded, "Actual Continue restores saved chapter ending")
	_write_report()
	print("[CHAPTER1 VISUAL] %d/%d checks passed; title to ending; %.1fs" % [checks.size()-failures.size(), checks.size(), (Time.get_ticks_msec()-started)/1000.0])
	quit(0 if failures.is_empty() else 1)


func _write_report() -> void:
	var report: FileAccess = FileAccess.open("res://.dev/chapter1-visual-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": failures.is_empty(), "display": DisplayServer.get_name(), "checks": checks, "failures": failures, "captures": captures, "seconds": (Time.get_ticks_msec()-started)/1000.0, "chapter": app.state.snapshot(), "battle": app.battle.tutorial_snapshot() if app.battle != null else {}, "timer_trace": timer_trace, "focus_events": focus_events, "held_input_resets": held_input_resets}, "\t"))
	report.close()


func trace_timers(sandbox: ChapterTutorial) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_trace < 1000: return
	_last_trace = now
	timer_trace.append({"seconds": (now-started)/1000.0, "lesson": sandbox.lesson_index+1, "flow": String(sandbox.flow), "phase": sandbox.controller.phase, "automatic": sandbox.automatic_flow, "paused": paused, "focused": root.has_focus(), "processing": sandbox.presentation_timer.can_process(), "presentation_stopped": sandbox.presentation_timer.is_stopped(), "presentation_left": sandbox.presentation_timer.time_left, "enemy_left": sandbox.enemy_timer.time_left, "fps": Engine.get_frames_per_second(), "delta": sandbox.get_process_delta_time()})
	if timer_trace.size() > 24: timer_trace.pop_front()
