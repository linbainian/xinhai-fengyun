extends "res://tests/chapter2_visual.gd"


func capture(label: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	var path: String = "res://.dev/cultivation-%s.png" % label
	root.get_texture().get_image().save_png(path)
	captures.append(path)
	print("[CULTIVATION VISUAL] ",label," ",(Time.get_ticks_msec()-started)/1000.0,"s")


func panel_click(action: String, value: String="") -> void:
	await frames(4)
	expect(app.mode=="menu" and app.hud.cultivation_panel.visible,"Cultivation panel accepts an action")
	var button: Button = app.hud.cultivation_panel.buttons.get(action+":"+value)
	expect(button!=null and not button.disabled,"Cultivation action is enabled: "+action+"/"+value)
	await click(button)
	await drain_dialogue()


func assert_text(node: Node) -> void:
	if node is Label:
		expect(node.get_minimum_size().y<=node.size.y+1,"Cultivation Chinese label fits: "+node.text.left(26))
		if node.get_parent() is Panel:
			expect(Rect2(Vector2.ZERO,node.get_parent().size).encloses(Rect2(node.position,node.size)),"Label stays inside its panel: "+node.text.left(26))
	if node is Panel and node.get_parent()==app.hud.cultivation_panel.content:
		for label: Node in node.get_children():
			if not label is Label: continue
			for button: Node in node.get_children():
				if button is Button: expect(not Rect2(label.position,label.size).intersects(Rect2(button.position,button.size)),"Action description stays above its button: "+label.text.left(26))
	for child: Node in node.get_children(): assert_text(child)


func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	started=Time.get_ticks_msec()
	app=SCENE.instantiate() as ChapterOne
	app.save_path="res://.dev/cultivation-visual-save.json"
	root.add_child(app); current_scene=app
	root.size=Vector2i(1920,1080)
	await frames(12)
	var seed: ChapterSession = completed_first()
	expect(seed.save_to(app.save_path)==OK,"Isolated cultivation save fixture created")
	app.load_game()
	await click(app.hud.next_chapter_button)
	await drain_dialogue()
	expect(app.state.phase=="cultivation" and app.state.chapter_two.day==4 and app.mode=="menu","Playable January 4 opens after Chapter 1 ending")
	await frames(6)
	assert_text(app.hud.cultivation_panel)
	await capture("train-1920")
	for area: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1000,900),Vector2i(2560,1080)]:
		root.size=area
		await frames(12)
		var panel: ChapterCultivationPanel = app.hud.cultivation_panel
		var bounds: Rect2 = Rect2(panel.card.position,panel.card.size)
		expect(Rect2(Vector2.ZERO,panel.size).encloses(bounds),"Cultivation card fits adaptive logical UI: "+str(area))
		expect(app.display.world_viewport.size.x>=960,"World viewport continues to fill resized window")
		await capture("size-%d-%d" % [area.x,area.y])
	root.size=Vector2i(1920,1080)
	await frames(12)
	await panel_click("growth_train","body")
	expect(app.state.max_hp()==223 and app.state.chapter_two.slot==1,"Real click spends one action and increases HP maximum")
	await panel_click("tab","roam")
	assert_text(app.hud.cultivation_panel)
	await capture("roam-panel")
	await panel_click("growth_roam","hill")
	expect(app.mode=="choice" and app.state.room=="hill" and app.world.actor_for("growth_event")!=null,"Roaming automatically presents the real hill encounter and choices without E")
	await capture("hill-discovery")
	app.return_to_title()
	await click(app.hud.continue_button)
	expect(app.mode=="choice" and app.state.chapter_two.cultivation.active_event=="hill_herbs" and app.world.actor_for("growth_event")!=null,"Continue automatically restores the saved pending choice")
	await capture("herbs-choice")
	await choose(0)
	expect(app.state.chapter_two.cultivation.inventory.herb==2 and app.world.actor_for("growth_event")==null,"Choice rewards herbs and removes the resolved map actor")
	await panel_click("tab","life")
	assert_text(app.hud.cultivation_panel)
	await capture("life-panel")
	await panel_click("growth_night","read")
	expect(app.state.chapter_two.night_used and app.state.chapter_two.cultivation.life.study==5,"Night reading is usable through the panel")
	await panel_click("c2_sleep_now")
	expect(app.state.chapter_two.day==5 and app.state.hp==223,"Next day refreshes actions and restores trained max HP")
	await panel_click("tab","jobs")
	assert_text(app.hud.cultivation_panel)
	await capture("jobs-panel")
	await panel_click("growth_job","courier")
	var before_money: int = app.state.money
	await key(KEY_C)
	await travel("cbd")
	await interact("reception")
	expect(app.state.money==before_money+150 and app.state.chapter_two.cultivation.job=="","Actual travel and counter interaction settle a cultivation courier job")
	await panel_click("growth_job","files")
	expect(app.state.chapter_two.slot==2,"Second job consumes the last daytime action")
	await panel_click("c2_sleep_now")
	await key(KEY_C)
	await key(KEY_C)
	expect(app.hud.cultivation_panel.visible and app.mode=="menu","C closes and reopens the cultivation panel")
	await key(KEY_F5); await key(KEY_F9)
	expect(app.state.chapter_two.day==6 and app.state.chapter_two.cultivation.attributes.constitution==11 and app.state.chapter_two.cultivation.inventory.herb==2,"Save/load retains current date, attributes and inventory")
	await key(KEY_C)
	await panel_click("c2_repeat_week")
	expect(app.state.chapter_two.day==13 and app.state.phase=="cultivation","Seven-day schedule advances only seven days before the story date")
	await panel_click("c2_repeat_week")
	expect(app.state.chapter_two.day==15 and app.state.phase=="chapter_two" and app.state.flags.get("c2_notice_seen",false) and app.mode=="world","Date transition automatically plays and resolves the January 15 notice")
	expect(app.state.chapter_two.cultivation.inventory.herb==2 and app.state.max_hp()==223,"Chapter 2 preserves free-period items and physical growth")
	await capture("jan15-notice-done")
	await travel("c2_infirmary")
	await interact("c2_exam"); await interact("c2_list"); await interact("c2_box"); await interact("c2_exam")
	expect(app.state.chapter_two.stage=="campus","Existing rescreen scene remains playable after the cultivation period")
	await key(KEY_C)
	await panel_click("tab","train")
	await capture("after-rescreen")
	expect(app.state.chapter_two.cultivation.proficiency.strike>0,"The reopened training panel displays pre-rescreen accumulated practice")
	await key(KEY_C)
	app.return_to_title()
	await frames(6)
	expect(app.hud.first_completion_button.visible,"Title offers the preserved Chapter 1 completion archive")
	await click(app.hud.first_completion_button)
	expect(app.mode=="complete" and app.state.phase=="complete","Archive title button loads the completed first chapter through actual input")
	await click(app.hud.next_chapter_button)
	await drain_dialogue()
	expect(app.state.phase=="cultivation" and app.state.chapter_two.day==4 and app.hud.cultivation_panel.visible,"Archived completion opens the new January 4 period without replaying Chapter 1")
	_write_report()
	print("[CULTIVATION VISUAL] %d/%d checks passed; %.1fs" % [checks.size()-failures.size(),checks.size(),(Time.get_ticks_msec()-started)/1000.0])
	quit(0 if failures.is_empty() else 1)


func _write_report() -> void:
	var file: FileAccess = FileAccess.open("res://.dev/cultivation-visual-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"captures":captures,"seconds":(Time.get_ticks_msec()-started)/1000.0},"\t")); file.close()
