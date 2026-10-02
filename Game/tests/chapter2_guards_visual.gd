extends "res://tests/chapter2_visual.gd"


func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(1);return
	started=Time.get_ticks_msec()
	app=SCENE.instantiate() as ChapterOne
	app.save_path="res://.dev/chapter2-guard-save.json"
	root.add_child(app);current_scene=app
	await frames(12)
	app.state=completed_first();ChapterTwoCalendar.new(app.state).begin()
	app.story=ChapterTwoStory.new(app.state)
	while int(app.state.chapter_two.day)<15: (app.story as ChapterTwoStory).calendar.sleep()
	for action: String in ["c2_notice","c2_exam","c2_list","c2_box","c2_exam"]: app.story.perform(action)
	app.story.perform("c2_join_club","healing")
	for week: int in range(3): app.story.perform("c2_repeat_week")
	app.story.perform("c2_class");app.story.perform("c2_training");app.story.perform("c2_social","jiang")
	for id: String in ChapterTwoCalendar.COMPANIONS: app.story.perform("c2_invite",id)
	app.story.perform("c2_sleep_now");app.story.perform("c2_accept_route","mutual");app.story.perform("c2_enter_rift")
	app._load_room();app._settle();app._start_rift_battle("entry")
	await frames(6)
	var sandbox: ChapterRiftBattle = app.rift_battle
	for resolution: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1100,900)]:
		root.size=resolution;await frames(12)
		var field: Rect2 = (sandbox.hud as ChapterRiftHUD).battlefield_rect()
		for view: CombatantView in sandbox._views.values():
			var occupied: Rect2 = Rect2(sandbox.display.world_to_ui(view.position+view._art_rect.position*3),sandbox.display.world_to_ui(view._art_rect.size*3)-sandbox.display.world_to_ui(Vector2.ZERO))
			expect(field.grow(1).encloses(occupied),"Four-member battle stays between status and commands at "+str(resolution))
		if resolution==Vector2i(1100,900): await capture("battle-tall-window")
	await key(KEY_ESCAPE)
	expect(app.rift_battle==null and app.mode in ["dialogue","world"],"Escape aborts battle and restores the world view")
	await drain_dialogue()
	expect(app.mode=="world","Abort dialogue returns to exploration")
	app.state.chapter_two.party=[];app.state.hp=1
	app._start_rift_battle("entry");await frames(3)
	sandbox=app.rift_battle
	sandbox.config.encounters.entry.enemies[0].speed=99
	sandbox.config.encounters.entry.enemies[0].attack=999
	sandbox.restart_battle()
	await create_timer(2).timeout
	expect(sandbox.controller.result==&"defeat" and (sandbox.hud as ChapterRiftHUD)._overlay.visible,"Actual enemy timers reach the defeat modal")
	await click((sandbox.hud as ChapterRiftHUD).primary_button)
	expect(sandbox.controller.result==&"" and sandbox.controller.get_combatant(&"lin_da").hp==1,"Mouse retry restores encounter opening checkpoint")
	await key(KEY_ESCAPE);await drain_dialogue()
	expect(app.state.hp==1 and app.state.chapter_two.cleared.is_empty(),"Abort and retry leave campaign HP and cleared encounters unchanged")
	app.state.room="c2_dorm";app.state.chapter_two.stage="campus";app._load_room();app._settle()
	app._play_scene("c2_sleep",func() -> void: app._settle())
	await key(KEY_ESCAPE)
	expect(not app.cinematics.active and app.world.camera.zoom==Vector2(2,2),"Esc skip restores the exploration camera and callback")
	app._play_scene("c2_notice",func() -> void: app.state.mark("guard_forbidden_callback"))
	app.return_to_title();await frames(8)
	expect(not app.cinematics.active and not app.state.flags.get("guard_forbidden_callback",false),"Returning to title cancels cinematic callback")
	_write_report()
	print("[CHAPTER2 GUARDS] %d/%d checks passed" % [checks.size()-failures.size(),checks.size()])
	quit(0 if failures.is_empty() else 1)


func _write_report() -> void:
	var file: FileAccess = FileAccess.open("res://.dev/chapter2-guards-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"captures":captures},"\t"));file.close()
