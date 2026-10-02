extends "res://tests/chapter2_visual.gd"


func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(1);return
	started=Time.get_ticks_msec()
	app=SCENE.instantiate() as ChapterOne
	app.save_path="res://.dev/chapter2-art-test.json"
	root.add_child(app);current_scene=app
	root.size=Vector2i(1920,1080)
	await frames(12)
	app.state=completed_first()
	ChapterTwoCalendar.new(app.state).begin()
	app.state.flags.c2_notice_seen=true;app.state.flags.c2_rescreen_done=true;app.state.flags.c2_task_accepted=true;app.state.flags.c2_hunter_seen=true
	app.state.chapter_two.stage="report";app.state.chapter_two.route="bureau";app.state.chapter_two.clue_destination="bar";app.state.chapter_two.cleared=["entry","final"];app.state.chapter_two.storm="shelter"
	app.story=ChapterTwoStory.new(app.state)
	for room: String in ["hall","cbd","c2_dorm","c2_infirmary","c2_classroom","c2_training","c2_clubs","c2_port","c2_rift","c2_bar"]:
		app.state.chapter_two.stage="clue" if room=="c2_rift" else "report"
		app.state.room=room;app._load_room();app._settle()
		app.world.camera.zoom=Vector2.ONE;app.world.cinematic_camera=true;app.world.cinematic_focus=Vector2(720,510)
		await capture("overview-"+room)
		app.world.camera.zoom=Vector2(2,2);app.world.cinematic_camera=false
		if room in ["hall","cbd"]:
			app.world.player.position=Vector2(720,610)
			await capture("desk-"+room)
	print("[CHAPTER2 ART] ",captures.size()," actual GPU captures")
	quit(0)
