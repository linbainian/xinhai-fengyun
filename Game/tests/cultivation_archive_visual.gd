extends "res://tests/chapter2_visual.gd"


func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	started=Time.get_ticks_msec()
	app=SCENE.instantiate() as ChapterOne
	app.save_path="res://.dev/cultivation-archive-save.json"
	var first: ChapterSession = completed_first()
	expect(first.save_to(app.save_path.get_basename()+"-chapter1-cleared.json")==OK,"Chapter 1 archive fixture exists")
	ChapterTwoCalendar.new(first).begin()
	var narrative: ChapterTwoStory = ChapterTwoStory.new(first)
	while int(first.chapter_two.day)<15: narrative.calendar.sleep()
	for action: String in ["c2_notice","c2_exam","c2_list","c2_box","c2_exam"]: narrative.perform(action)
	first.money=4567
	expect(first.save_to(app.save_path)==OK,"Existing Chapter 2 main save fixture exists")
	root.add_child(app); current_scene=app
	root.size=Vector2i(1920,1080)
	await frames(12)
	expect(app.hud.first_completion_button.visible,"Existing completion archive is available at title")
	await click(app.hud.first_completion_button)
	expect(app.mode=="complete" and app.state.phase=="complete","Actual title button loads the first completion")
	var preserved: ChapterSession = ChapterSession.new()
	expect(preserved.load_from(app.save_path.get_basename()+"-before-cultivation-replay.json") and preserved.phase=="chapter_two" and preserved.money==4567 and int(preserved.chapter_two.day)==15,"Existing Chapter 2 progress is archived before the selected replay overwrites the shared slot")
	await click(app.hud.next_chapter_button)
	await drain_dialogue()
	expect(app.mode=="menu" and app.state.phase=="cultivation" and app.state.chapter_two.day==4,"Replay opens January 4 cultivation through actual input")
	_write_report()
	print("[CULTIVATION ARCHIVE] %d/%d checks passed" % [checks.size()-failures.size(),checks.size()])
	quit(0 if failures.is_empty() else 1)


func _write_report() -> void:
	var file: FileAccess = FileAccess.open("res://.dev/cultivation-archive-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures},"\t")); file.close()
