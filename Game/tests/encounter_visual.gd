extends "res://tests/cultivation_visual.gd"

var dialogue_captures: Array[String]=[]


func drain_dialogue(stop_at: String="") -> void:
	for attempt: int in range(1200):
		if app.mode!="cinematic": break
		await frames(1)
	var id: String=app.cinematics.sequence_id
	if app.mode=="dialogue" and not dialogue_captures.has(id) and id in ["clubs_to_dorm","chuxia_corridor","event_library_arrival","event_library_carry","event_ice_arrival","event_ice_eat","event_ice_takeaway","event_spar","event_lunch","event_lunch_count","event_flyers","event_flyers_help"]:
		dialogue_captures.append(id)
		await capture("dialogue-"+id)
		if id=="event_ice_takeaway":
			var bag: Sprite2D=app.world.object_for("event_takeaway") as Sprite2D
			expect(bag!=null and bag.visible and bag.get_parent()==app.world.foreground_props,"Paid takeaway bag visibly sits on the counter during the actual handover")
		for actor_id: String in ["growth_event","growth_partner_bai"]:
			var actor: Sprite2D=app.world.actor_for(actor_id) as Sprite2D
			if actor==null: continue
			var pixels: Rect2i=actor.texture.get_image().get_used_rect()
			var top: Vector2=app.display.world_to_ui(actor.get_global_transform_with_canvas()*(actor.offset+Vector2(pixels.position)))
			var bottom: Vector2=app.display.world_to_ui(actor.get_global_transform_with_canvas()*(actor.offset+Vector2(pixels.end)))
			expect(top.y>=app.hud.top_panel.position.y+app.hud.top_panel.size.y and bottom.y<=app.hud.dialog_panel.position.y,"Event speaker remains visible between header and dialogue: "+id+"/"+actor_id)
	await super.drain_dialogue(stop_at)


func assert_text(node: Node) -> void:
	super.assert_text(node)
	if node is Panel:
		for label: Node in node.get_children():
			if not label is Label: continue
			for button: Node in node.get_children():
				if button is Button: expect(not Rect2(label.position,label.size).intersects(Rect2(button.position,button.size)),"Panel label clear of buttons: %s at %s / %s; button %s at %s" % [label.text.left(38),label.position,label.size,button.text,button.position])


func capture(label: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	var path: String="res://.dev/encounters-%s.png" % label
	root.get_texture().get_image().save_png(path)
	captures.append(path)
	print("[ENCOUNTERS VISUAL] ",label," ",(Time.get_ticks_msec()-started)/1000.0,"s")


func install(state: ChapterSession) -> void:
	app.mode="world"
	expect(state.save_to(app.save_path)==OK,"Isolated visual fixture saved")
	app.load_game()
	await frames(8)


func grow_state(day: int) -> ChapterSession:
	var state: ChapterSession=completed_first()
	var calendar: ChapterTwoCalendar=ChapterTwoCalendar.new(state)
	calendar.begin()
	while int(state.chapter_two.day)<day: calendar.sleep()
	return state


func overview(label: String) -> void:
	app.world.camera.zoom=Vector2.ONE
	app.world.cinematic_camera=true
	app.world.cinematic_focus=Vector2(720,510)
	await capture(label)
	app.world.camera.zoom=Vector2(2,2)
	app.world.cinematic_camera=false


func depart(area: String, event_id: String) -> void:
	await frames(4)
	var button: Button = app.hud.cultivation_panel.buttons.get("growth_roam:" + area)
	expect(button != null and not button.disabled, "Actual roam button is available: " + area)
	await click(button)
	expect(app.mode == "cinematic" and app.cinematics.active and app.world.player.blocked, "Departure immediately starts a locked encounter scene without E: " + event_id)
	expect(not app.hud.cultivation_panel.visible and app.state.chapter_two.cultivation.active_event == event_id, "The selected encounter owns the scene: " + event_id)
	if event_id == "training_spar":
		while app.mode == "cinematic" and app.cinematics.step_index < 3: await frames(1)
		await capture("ice-lightning")
	await drain_dialogue()


func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(1);return
	started=Time.get_ticks_msec()
	app=SCENE.instantiate() as ChapterOne
	app.save_path="res://.dev/encounters-visual-save.json"
	root.add_child(app);current_scene=app
	root.size=Vector2i(1920,1080)
	await frames(12)
	var first: ChapterSession=completed_first()
	first.phase="clubs";first.room="clubs"
	for id: String in ["slept","task_accepted","delivered","task_rewarded"]: first.flags.erase(id)
	await install(first)
	await overview("clubs-overview")
	await interact("club_sword");await interact("club_element");await interact("club_healing")
	await interact("clubs")
	expect(app.mode=="choice" and app.state.room=="clubs","Actual recruit E interaction keeps the scene at its stalls")
	await choose(1)
	expect(app.state.room=="dorm" and app.state.phase=="dorm" and app.mode=="world","Natural companion departure reaches the bedroom")
	await capture("dorm-explore")
	await overview("dorm-overview")
	expect(app.world.actor_for("chuxia")==null,"Chuxia never stands inside the bedroom")
	await interact("dorm_wen")
	await interact("dorm_exit")
	expect(app.state.room=="corridor" and app.world.actor_for("chuxia")!=null,"Room door actually opens a separate shared corridor")
	await capture("corridor-explore")
	await overview("corridor-overview")
	await interact("chuxia")
	expect(app.state.flags.get("chuxia_seen",false) and app.state.room=="corridor","Initial Chuxia entrance and exit both take place outside the bedroom")
	await interact("dorm_enter")
	await interact("sleep")
	expect(app.state.phase=="hall" and app.state.hp==app.state.max_hp(),"Return through the room door and sleep preserves January 3 progression")
	for index: int in range(5):
		var ids: Array[String]=["campus_library","street_ice","training_spar","training_lunch","dormitory_flyers"]
		var areas: Array[String]=["campus","street","training","training","dormitory"]
		var days: Array[int]=[5,6,10,12,9]
		var state: ChapterSession=grow_state(days[index])
		if index==3:
			state.chapter_two.cultivation.seen.append("training_spar")
			state.room = "c2_training"
		if index==2: state.chapter_two.cultivation.seen.append("campus_library")
		await install(state)
		await key(KEY_C)
		app.hud.cultivation_panel.selected_tab="roam"
		app.hud.cultivation_panel._rebuild()
		await frames(6)
		assert_text(app.hud.cultivation_panel)
		if index==0:
			await create_timer(3.9).timeout
			await capture("roam-panel")
		await depart(areas[index], ids[index])
		expect(app.state.chapter_two.cultivation.active_event==ids[index],"Real panel departure chooses dated encounter: "+ids[index])
		expect(app.mode=="choice" and app._choices.size()==3,"The automatically played scene reaches three choices")
		await capture(ids[index]+"-choices")
		var checkpoint: ChapterSession=ChapterSession.new()
		expect(checkpoint.load_from(app.save_path) and checkpoint.chapter_two.cultivation.event_started and checkpoint.chapter_two.cultivation.active_event==ids[index],"Entrance endpoint automatically saves a real pending choice")
		var count: int = app.cinematics.completed.size()
		var position: Vector2 = app.world.actor_for("growth_event").position
		app.return_to_title()
		await click(app.hud.continue_button)
		await frames(6)
		expect(app.mode=="choice" and app.cinematics.completed.size()==count,"Continue immediately restores the pending choice without replay or E")
		expect(app.world.actor_for("growth_event").position == position,"Saved choice restores the exact actor endpoint: " + ids[index])
		await choose(0)
		expect(app.state.chapter_two.cultivation.seen.has(ids[index]) and app.hud.cultivation_panel.visible,"Real choice settles, removes encounter and returns to growth panel")
		await key(KEY_C)
		await key(KEY_F5);await key(KEY_F9)
		expect(app.state.chapter_two.cultivation.seen.has(ids[index]),"Actual save/load retains once-only character event")
		await capture(ids[index]+"-resolved")
	var definitions: Array = (app.story as ChapterTwoStory).growth.events
	for event: Dictionary in definitions:
		if event.get("character_event", false): continue
		var original: ChapterSession = grow_state(int(event.min_day))
		for other: Dictionary in definitions:
			if other.id != event.id: original.chapter_two.cultivation.seen.append(String(other.id))
		if event.id == "street_books": original.money = 0
		await install(original)
		await key(KEY_C)
		app.hud.cultivation_panel.selected_tab = "roam"
		app.hud.cultivation_panel._rebuild()
		await depart(String(event.area), String(event.id))
		expect(app.mode == "choice" and app._choices.size() == 3, "Original encounter automatically offers choices: " + String(event.id))
		await capture("automatic-" + String(event.id))
		if event.id == "street_books":
			await choose(0)
			expect(app.mode == "choice" and app.state.money == 0 and app.state.chapter_two.cultivation.active_event == event.id, "Insufficient funds return directly to the same choices")
			await choose(1)
		else:
			await choose(0)
		expect(app.state.chapter_two.cultivation.seen.has(String(event.id)) and app.hud.cultivation_panel.visible, "Original encounter settles once and returns to the panel: " + String(event.id))
	var takeaway: ChapterSession=grow_state(6)
	var takeaway_story: ChapterTwoStory=ChapterTwoStory.new(takeaway)
	takeaway_story.perform("growth_roam","street")
	await install(takeaway)
	expect(app.mode == "choice", "Loading a pending takeaway automatically resumes choices")
	await choose(1)
	expect(app.state.money==3270 and int(app.state.relations.wen_rang)==82 and int(app.state.chapter_two.cultivation.inventory.coupon)==2,"Actual cash takeaway preserves the voucher and settles the planned cost and friendship")
	var skipped: ChapterSession=grow_state(10)
	var story: ChapterTwoStory=ChapterTwoStory.new(skipped)
	story.perform("growth_roam","training")
	skipped.chapter_two.cultivation.event_started = false
	await install(skipped)
	expect(app.mode=="cinematic","Old pending encounter automatically starts a skippable entrance")
	await key(KEY_ESCAPE)
	await drain_dialogue()
	expect(app.mode=="choice" and app.state.chapter_two.cultivation.seen.is_empty(),"Skipping animation reaches the same choice and grants no premature rewards")
	await choose(2)
	expect(app.state.chapter_two.cultivation.active_event=="" and app.state.chapter_two.cultivation.seen.is_empty(),"Leave option clears the encounter without a permanent completion flag")
	_write_report()
	print("[ENCOUNTERS VISUAL] %d/%d checks passed" % [checks.size()-failures.size(),checks.size()])
	quit(0 if failures.is_empty() else 1)


func _write_report() -> void:
	var file: FileAccess=FileAccess.open("res://.dev/encounters-visual-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"captures":captures,"seconds":(Time.get_ticks_msec()-started)/1000.0},"\t"));file.close()
