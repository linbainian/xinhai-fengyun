extends "res://tests/chapter1_visual.gd"

var sandbox: ChapterTutorial


func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	started = Time.get_ticks_msec()
	app = SCENE.instantiate() as ChapterOne
	app.save_path = "user://saves/test_chapter1_refinement.json"
	root.add_child(app)
	current_scene = app
	root.mode = Window.MODE_MAXIMIZED
	await frames(12)
	app.start_new_game()
	skip_arrival()
	app.state.phase = "hill"
	app._settle()
	app.start_battle()
	await frames(8)
	sandbox = app.battle
	sandbox.begin_tutorial(true)
	for command: String in ["attack", "sweep", "miss", "defend", "success", "failure"]:
		_fresh_battle()
		var controller: BattleController = sandbox.controller
		var hero: CombatantState = controller.living_team(true)[0]
		var targets: Array[CombatantState] = controller.living_team(false)
		hero.definition.accuracy = 1000.0
		if command in ["defend", "success", "failure"]:
			hero.hp = 150
			hero.sl = 40
		if command in ["success", "failure"]:
			hero.critical = 100
			controller.encounter.rules.breakthrough_base_chance = 100.0 if command == "success" else 0.0
		if command == "miss": hero.definition.accuracy = -1000.0
		var accepted: bool
		if command == "sweep": accepted = controller.submit_player_command(&"skill", targets[0].id, &"sweep")
		elif command in ["success", "failure"]: accepted = controller.submit_player_command(&"breakthrough")
		elif command == "defend": accepted = controller.submit_player_command(&"defend")
		else: accepted = controller.submit_player_command(&"attack", targets[0].id)
		expect(accepted and controller.phase == BattleController.Phase.PRESENTING, "Actual controller emits presentation: " + command)
		var action: Dictionary = controller.events.back().details
		var state_after: Array[Dictionary] = controller._states_snapshot()
		var rng_after: int = controller._rng.state
		await create_timer(0.60).timeout
		expect(controller._states_snapshot() == state_after and controller._rng.state == rng_after, "FX do not change HP/SL, CD, critical or RNG: " + command)
		expect(not sandbox.effects._records.is_empty(), "Visible feedback exists: " + command)
		var labels: Array[String] = []
		for record: Dictionary in sandbox.effects._records:
			if record.kind == "float":
				var label: Label = record.node
				labels.append(label.text)
				expect(label.visible and (sandbox.hud as ChapterBattleHUD).battlefield_rect().encloses(Rect2(label.position,label.size)), "Float stays in uncovered battlefield: " + label.text)
		if command in ["attack", "sweep", "miss"]:
			expect(sandbox.effects.last_feedback.size() == action.outcomes.size(), "All real outcomes receive individual FX: " + command)
			for index: int in range(action.outcomes.size()):
				var outcome: Dictionary = action.outcomes[index]
				var feedback: Dictionary = sandbox.effects.last_feedback[index]
				expect(feedback.target_id == outcome.target_id and feedback.damage == outcome.damage and feedback.hit == outcome.hit, "Feedback matches real target/hit/damage")
			if command == "sweep": expect(action.outcomes.size() == 2, "Group skill presents both rabbits")
			if command == "miss": expect(labels.has("未命中") and sandbox.effects._affected.is_empty(), "Miss has a label without an impact or hit reaction")
			else:
				var reacted: bool = false
				for view: CombatantView in sandbox.effects._affected:
					reacted = reacted or view._hit_tint != Color.WHITE or view._hit_offset != Vector2.ZERO
				expect(reacted, "Real hit flashes and knocks the target")
		elif command == "defend": expect(labels[0].contains("防御") and labels[0].contains(str(action.healing)) and labels[0].contains(str(action.sl_relief)), "Defense shows actual HP/SL changes")
		else: expect(bool(action.success) == (command == "success") and labels.has("突破成功" if command == "success" else "突破受阻"), "Breakthrough success/failure have distinct real outcomes")
		await capture("fx-" + command)
		sandbox.restart_battle()
		_check_cleared("retry after " + command)
	_fresh_battle()
	sandbox.controller.submit_player_command(&"defend")
	sandbox.replay_tutorial()
	_check_cleared("replay")
	sandbox.begin_tutorial()
	_fresh_battle()
	for unit: CombatantState in sandbox.controller.living_team(false): unit.hp = 1
	sandbox.controller.living_team(true)[0].definition.accuracy = 1000.0
	sandbox.controller.submit_player_command(&"skill", sandbox.controller.living_team(false)[0].id, &"sweep")
	sandbox.controller.complete_presentation()
	expect(sandbox.flow == &"between", "Real victory reaches between-stage boundary")
	_check_cleared("victory")
	sandbox.advance_lesson()
	_check_cleared("next stage")
	_fresh_battle()
	sandbox.controller.submit_player_command(&"defend")
	await key(KEY_F11)
	await frames(8)
	_check_cleared("F11 formation resize")
	await key(KEY_F11)
	await frames(8)
	_fresh_battle()
	sandbox.controller.submit_player_command(&"defend")
	sandbox._return_to_m0()
	await frames(3)
	expect(app.battle == null and app.mode == "dialogue" and app.world.player.resting, "Exit clears battle and presents a seated rest without healing")
	await capture("rest-at-entrance")
	for mentor: String in ["liu", "shen", "wen", "tang"]:
		for attitude: int in range(3):
			app.start_new_game()
			skip_arrival()
			app.story.perform("exam")
			app.state.room = {"liu":"training", "shen":"plaza", "wen":"lab", "tang":"infirmary"}[mentor]
			app._load_room()
			app.state.flags[mentor + "_done"] = true
			app.present(app.story.perform("join",mentor))
			while app.mode == "dialogue": app.advance_dialogue()
			expect(app.mode == "cinematic" and app.world.player.blocked, "Automatic Su visit after formal join: " + mentor)
			var visitor: Sprite2D = app.world.actors.get_node("SuWanyanVisitor") as Sprite2D
			var initial_x: float = visitor.position.x
			await create_timer(1.85).timeout
			expect(visitor.position.x < initial_x and app.state.room == "plaza", "Su actually moves along the current scene's approach")
			await wait_for_mode("dialogue")
			expect(app.mode == "dialogue" and app.state.flags.get("su_visit_seen",false), "Su starts conversation once after arriving")
			if mentor == "liu" and attitude == 0: await capture("su-framed-visit")
			while app.mode == "dialogue": app.advance_dialogue()
			expect(app.mode == "choice" and app.state.flags.get("hill_route_received",false), "Shared route/voucher precedes all three responses")
			var hp_before: int = app.state.hp
			var sl_before: int = app.state.sl
			app.select_choice(attitude)
			expect(app._lines.back().text == app.dialogues.day_one_close[0].text, "Every attitude includes the dorm/night common transition")
			while app.mode == "dialogue": app.advance_dialogue()
			expect(app.state.phase == "hill" and app.state.room == "hill" and app.state.hp == hp_before and app.state.sl == sl_before, "Common transition keeps existing resource rules")
			expect(app.state.relations.su == (45 if attitude==0 else 43 if attitude==1 else 40) and bool(app.state.flags.invite_wen) == (attitude==2), "All four mentors preserve each Su attitude's reward")
	app.start_new_game()
	skip_arrival()
	app.story.perform("exam")
	app.state.room = "plaza"
	app.state.player_position = Vector2(720,510)
	app.state.save_to(app.save_path)
	app.load_game()
	expect(app.world.player.position == Vector2(720,842) and app.world.can_stand(app.world.player.position), "An older save inside the rebuilt facade resumes at a safe entry")
	app.world.player.position = Vector2(720,904)
	app.save_game()
	app.load_game()
	expect(app.world.player.position == Vector2(720,904), "Save/load preserves legal positions beyond the old map height")
	var outside: Dictionary = app.state.snapshot()
	outside.player_position = [720,961]
	expect(not ChapterSession.new().restore(outside), "Positions beyond the actual room height remain invalid")
	_write_report()
	print("[CHAPTER1 REFINEMENT] %d/%d passed; real FX, cleanup, 12 automatic visits" % [checks.size()-failures.size(),checks.size()])
	quit(0 if failures.is_empty() else 1)


func _fresh_battle() -> void:
	sandbox.restart_battle()
	if sandbox.flow == &"intro": sandbox.begin_tutorial()
	# Longer lifetime only in this fixture lets the GPU inspect middle animation frames.
	sandbox.controller.encounter.rules.presentation_seconds = 1.2
	expect(sandbox.controller.current_actor().is_player, "Fixture begins at a legal player command")


func _check_cleared(context: String) -> void:
	expect(sandbox.effects._records.is_empty() and sandbox.effects.get_child_count()==0 and sandbox.effects._floating_layer.get_child_count()==0, "No FX/labels remain: " + context)
	for view: CombatantView in sandbox._views.values():
		expect(view._hit_offset==Vector2.ZERO and view._hit_tint==Color.WHITE, "Hit state reset: " + context)


func _write_report() -> void:
	var report: FileAccess = FileAccess.open("res://.dev/chapter1-refinement-report.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"captures":captures,
		"seconds":(Time.get_ticks_msec()-started)/1000.0,"display":DisplayServer.get_name()},"\t"))
	report.close()
