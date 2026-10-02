extends "res://tests/chapter2_visual.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	started = Time.get_ticks_msec()
	app = SCENE.instantiate() as ChapterOne
	app.save_path = "res://.dev/chapter2-route-save.json"
	root.add_child(app)
	current_scene = app
	root.size = Vector2i(1920, 1080)
	await frames(12)
	app.state = completed_first()
	ChapterTwoCalendar.new(app.state).begin()
	app.story = ChapterTwoStory.new(app.state)
	while int(app.state.chapter_two.day)<15: (app.story as ChapterTwoStory).calendar.sleep()
	for action: String in ["c2_notice", "c2_exam", "c2_list", "c2_box", "c2_exam"]:
		app.story.perform(action)
	app.story.perform("c2_join_club", "none")
	for week: int in range(3):
		app.story.perform("c2_repeat_week")
	app.story.perform("c2_accept_route", "mutual")
	app.story.perform("c2_enter_rift")
	# The battle itself is covered in the full-input and 40-branch tests.
	app.state.chapter_two.cleared = ["entry", "final"]
	app.state.chapter_two.storm = "push"
	app.state.chapter_two.stage = "clue"
	app._load_room()
	app._settle()
	await drain_dialogue()
	expect(app.state.flags.get("c2_hunter_seen", false), "Qin arrival finishes before corpse investigation")
	var actor: ChapterActor = app.world.actor_for("c2_qin")
	expect(actor != null and actor.visible and actor.position.distance_to(Vector2(1080, 550)) < 1, "Qin walks from the map edge to the investigation area")
	await key(KEY_F5)
	await key(KEY_F9)
	expect(app.world.actor_for("c2_qin").position.distance_to(Vector2(1080, 550)) < 1, "Reload preserves the arrived hunter and does not replay the entrance")
	await capture("qin-arrival")
	await interact("c2_corpse")
	await choose(0)
	await choose(1)
	await travel("c2_bar")
	await capture("hunter-bar")
	await interact("c2_bar")
	await interact("c2_old_hunter")
	expect(app.state.flags.get("c2_clue_delivered", false) and app.state.chapter_two.reputation.mutual == 3, "Real bar interactions record the old hunter's clue and mutual-association reputation")
	await interact("c2_bar_guest_worker")
	await travel("hall")
	await interact("task")
	expect(app.mode == "complete" and app.state.chapter_two.grade == "A", "Mutual-association and bar route reaches A settlement after passing the storm")
	await capture("mutual-ending")
	var file: FileAccess = FileAccess.open("res://.dev/chapter2-route-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "captures": captures}, "\t"))
	file.close()
	print("[CHAPTER2 ROUTE] %d/%d checks passed" % [checks.size() - failures.size(), checks.size()])
	quit(0 if failures.is_empty() else 1)
