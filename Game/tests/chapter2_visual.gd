extends "res://tests/chapter1_visual.gd"


func completed_first() -> ChapterSession:
	var state: ChapterSession = ChapterSession.new()
	state.phase="complete";state.room="hall";state.mentor="shen";state.money=3300;state.contribution=5
	for id: String in ["tested","apprenticed","hill_accepted","hill_done","clubs_seen","slept","task_accepted","delivered","task_rewarded"]: state.flags[id]=true
	return state


func capture(label: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	var path: String = "res://.dev/chapter2-%s.png" % label
	root.get_texture().get_image().save_png(path)
	captures.append(path)
	print("[CHAPTER2 VISUAL] ",label," ",(Time.get_ticks_msec()-started)/1000.0,"s")


func move_axis(axis: int, target: float) -> void:
	for attempt: int in range(4):
		var offset: float = target-app.world.player.position[axis]
		if absf(offset)<6: return
		var code: int = (KEY_D if offset>0 else KEY_A) if axis==0 else (KEY_S if offset>0 else KEY_W)
		var deadline: int = Time.get_ticks_msec()+int(absf(offset)/app.world.player.move_speed*1000)+3000
		while Time.get_ticks_msec()<deadline:
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode=code;event.pressed=true
			Input.parse_input_event(event)
			await physics_frame
			var remaining: float = target-app.world.player.position[axis]
			if absf(remaining)<4 or signf(remaining)!=signf(offset): break
		var release: InputEventKey = InputEventKey.new()
		release.physical_keycode=code
		Input.parse_input_event(release)
		await frames(2)
		if absf(app.world.player.position[axis]-target)<7: return
	expect(false,"WASD route reaches axis %d at %.1f; actual %s" % [axis,target,app.world.player.position])


func walk_to(id: String) -> void:
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


func do_action(action: String, value: String="") -> void:
	app.present(app.story.perform(action,value))
	await drain_dialogue()


func choose(index: int) -> void:
	expect(app.mode == "choice", "Choice modal available")
	var original: String = JSON.stringify(app._choices)
	for attempt: int in range(3):
		# Let newly built controls and a native window resize finish their layout.
		await frames(4)
		if index <= 1:
			await click(button_named(app.hud.choice_layer, "%d · " % (index + 1)))
		else:
			await key(KEY_1 + index)
		if app.mode != "choice" or JSON.stringify(app._choices) != original:
			await drain_dialogue()
			return
	expect(false, "Choice receives real mouse or keyboard input after layout")


func interact(id: String) -> void:
	await walk_to(id)
	await key(KEY_E)
	expect(app.mode in ["dialogue","cinematic"],"E opens interaction for "+id)
	await drain_dialogue()


func real_fight() -> void:
	var sandbox: ChapterRiftBattle = app.rift_battle
	expect(sandbox!=null and sandbox.controller.phase!=BattleController.Phase.IDLE,"Chapter 2 opens real party battle")
	await capture("battle-"+sandbox.encounter_id)
	var deadline: int = Time.get_ticks_msec()+120000
	while sandbox.controller.phase!=BattleController.Phase.FINISHED and Time.get_ticks_msec()<deadline:
		if sandbox.controller.phase==BattleController.Phase.PLAYER_COMMAND:
			var actor: CombatantState = sandbox.controller.current_actor()
			var target: CombatantState = sandbox.controller.living_team(false)[0]
			for attempt: int in range(6):
				if sandbox.hud.selected_target==target.id: break
				await key(KEY_TAB)
			if actor.hp<actor.max_hp()*.45 or actor.sl>=65 or actor.weak_actions>0: await key(KEY_D)
			elif not actor.definition.skills.is_empty() and actor.cooldown_for(actor.definition.skills[0].id)==0: await key(KEY_1)
			else: await key(KEY_A)
		else: await create_timer(.03).timeout
	expect(sandbox.controller.result==&"victory","Actual keyboard commands win "+sandbox.encounter_id)
	await key(KEY_ENTER)
	await drain_dialogue()
	expect(app.rift_battle==null and app.mode=="world","Victory returns to exploration and saves party vitals")


func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(1);return
	started=Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.dev"))
	app=SCENE.instantiate() as ChapterOne
	app.save_path="res://.dev/chapter2-visual-save.json"
	root.add_child(app);current_scene=app
	root.size=Vector2i(1920,1080)
	await frames(12)
	var seed: ChapterSession = completed_first()
	expect(seed.save_to(app.save_path)==OK,"Chapter 1 ending fixture uses isolated test save")
	app.load_game()
	expect(app.mode=="complete","Continue restores existing Chapter 1 ending")
	await click(app.hud.next_chapter_button)
	await drain_dialogue()
	expect(app.state.phase=="cultivation" and int(app.state.chapter_two.day)==4 and app.hud.cultivation_panel.visible,"Chapter 1 ending opens January 4 cultivation panel")
	for routine: int in range(2):
		await frames(4)
		await click(app.hud.cultivation_panel.buttons["c2_repeat_week:"])
		await drain_dialogue()
	expect(app.state.phase=="chapter_two" and app.story is ChapterTwoStory,"Ending button enters Chapter 2 and plays notice scene")
	expect(FileAccess.file_exists(app.save_path.get_basename()+"-chapter1-cleared.json"),"Chapter 1 completion is archived before advancing the campaign save")
	await travel("c2_infirmary")
	await interact("c2_exam")
	await capture("rescreen")
	await interact("c2_list")
	await interact("c2_box")
	await interact("c2_exam")
	expect(app.state.chapter_two.stage=="campus","Rescreen interactions release campus exploration")
	await travel("c2_clubs")
	await interact("c2_club_signup")
	await choose(1)
	await travel("c2_classroom")
	await interact("c2_class")
	await travel("c2_training")
	await interact("c2_training")
	await travel("c2_dorm")
	await interact("c2_jiang")
	await choose(0)
	for id: String in ["c2_wen","c2_jiang"]:
		await interact(id)
		await choose(1)
	await interact("dorm_exit")
	await interact("c2_chuxia")
	await choose(1)
	await interact("dorm_enter")
	expect(app.state.chapter_two.party.size()==3,"Three recruited students form a four-member battle party")
	await capture("dorm-party")
	await interact("c2_sleep")
	await choose(1)
	await interact("c2_sleep")
	await choose(1)
	for day: int in range(3):
		await interact("c2_sleep")
		await choose(0)
	expect(app.state.chapter_two.day==32,"Calendar reaches February 1 through sleep and weekly schedule choices")
	await travel("hall")
	await capture("academy-hall")
	await interact("task")
	await choose(0)
	await travel("c2_port")
	await capture("port")
	await interact("c2_contact")
	await choose(0)
	await capture("rift")
	await walk_to("c2_entry")
	await key(KEY_E)
	await real_fight()
	await interact("c2_storm")
	await choose(0)
	await capture("storm-shelter")
	await walk_to("c2_final")
	await key(KEY_E)
	await real_fight()
	await interact("c2_corpse")
	await choose(0)
	await capture("cuts-choice")
	await choose(0)
	await travel("cbd")
	await capture("bureau-hall")
	await interact("reception")
	await travel("hall")
	await interact("task")
	expect(app.mode=="complete" and app.state.chapter_two.grade=="S","Actual Chapter 2 input flow reaches S settlement")
	await capture("ending")
	await click(app.hud.next_chapter_button)
	expect(app.mode=="world","Chapter 2 ending allows continued campus activity")
	await key(KEY_F5)
	await key(KEY_F9)
	expect(app.state.phase=="chapter_two" and app.state.chapter_two.grade=="S","F5 and F9 preserve Chapter 2 result and party")
	await key(KEY_F11);await frames(12)
	expect(root.mode==Window.MODE_FULLSCREEN,"Chapter 2 enters fullscreen")
	await key(KEY_F11);await frames(12)
	for room: String in ["hall","cbd","c2_infirmary","c2_classroom","c2_training","c2_clubs","c2_port"]:
		app.state.room=room;app._load_room();app._settle()
		app.world.camera.zoom=Vector2.ONE
		app.world.cinematic_camera=true;app.world.cinematic_focus=Vector2(720,510)
		await capture("overview-"+room)
		app.world.camera.zoom=Vector2(2,2);app.world.cinematic_camera=false
	_write_report()
	print("[CHAPTER2 VISUAL] %d/%d checks passed; %.1fs" % [checks.size()-failures.size(),checks.size(),(Time.get_ticks_msec()-started)/1000.0])
	quit(0 if failures.is_empty() else 1)


func _write_report() -> void:
	var file: FileAccess = FileAccess.open("res://.dev/chapter2-visual-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"display":DisplayServer.get_name(),"checks":checks,"failures":failures,"captures":captures,"seconds":(Time.get_ticks_msec()-started)/1000.0,"chapter":app.state.snapshot()},"\t"));file.close()
