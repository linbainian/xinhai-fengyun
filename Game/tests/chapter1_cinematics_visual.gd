extends "res://tests/chapter1_visual.gd"

var movie_frames: Dictionary = {}
var walking_textures: Dictionary = {}
var introductions: Array[String] = []
var route_samples: int = 0
var _probe_follow: bool = false
var follow_samples: int = 0


func _record_frame(id: String) -> void:
	await RenderingServer.frame_post_draw
	var folder: String = "res://.dev/cinematics-frames/" + id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var paths: Array = movie_frames.get(id, [])
	var path: String = folder + "/%03d.png" % paths.size()
	var frame: Image = root.get_texture().get_image()
	frame.resize(frame.get_width()/2, frame.get_height()/2, Image.INTERPOLATE_NEAREST)
	frame.save_png(path)
	paths.append(path)
	movie_frames[id] = paths


func _watch_scene(record: bool = true) -> void:
	var id: String = app.cinematics.sequence_id
	var resources: Array = [app.state.hp, app.state.sl, app.state.money, app.state.relations.duplicate(true)]
	var deadline: int = Time.get_ticks_msec() + 30000
	var photographed: Array[int] = []
	while app.mode == "cinematic" and Time.get_ticks_msec() < deadline:
		expect(app.world.player.blocked and app.world.camera.zoom == Vector2.ONE, "Cinematic locks movement and uses an integer establishing camera")
		for actor_id: String in ["player", "wen_rang", "liu", "shen", "wen", "tang", "SuWanyanVisitor"]:
			var actor: Node2D = app.world.actor_for(actor_id)
			if actor == null or not actor.visible: continue
			expect(app.world.can_stand(actor.position), "Authored route avoids walls and furniture: %s / %s / %s" % [id, actor_id, actor.position])
			route_samples += 1
			if actor is ChapterActor and (actor as ChapterActor).walking:
				var paths: Array = walking_textures.get(actor_id, [])
				var resource: String = (actor as ChapterActor).texture.resource_path
				if not paths.has(resource): paths.append(resource)
				walking_textures[actor_id] = paths
		if record: await _record_frame(id)
		if app.cinematics._card.visible and app.cinematics._age > 0.5 and not photographed.has(app.cinematics.step_index):
			photographed.append(app.cinematics.step_index)
			expect(app.cinematics._role.get_minimum_size().y <= app.cinematics._role.size.y, "Entrance name-card text fits")
			await capture("cinematic-" + id + "-" + str(app.cinematics.step_index))
		await create_timer(0.13).timeout
	expect(app.mode != "cinematic" and app.world.camera.zoom == Vector2(2,2), "Natural scene completes and restores the exploration camera: " + id)
	expect(resources == [app.state.hp, app.state.sl, app.state.money, app.state.relations], "Presentation preserves HP/SL, money and relationship values: " + id)
	if id == "test_to_assembly":
		for mentor: String in ["liu", "shen", "wen", "tang"]:
			var actor: ChapterActor = app.world.actor_for(mentor) as ChapterActor
			expect(actor != null and actor.visible and not actor.walking and actor.facing == Vector2.DOWN, "Mentor finishes on stage facing the audience: " + mentor)
		await capture("cinematic-ceremony-complete")


func _read_scenes(record: bool = true) -> void:
	for index: int in range(150):
		if app.mode == "cinematic":
			await _watch_scene(record)
		elif app.mode == "dialogue":
			if app.state.room == "assembly_stage" and app.hud.speaker_label.text in ["柳无眠", "沈听澜", "温若水", "唐半夏"]:
				introductions.append(app.hud.speaker_label.text)
				await capture("cinematic-stage-dialogue-" + str(introductions.size()))
			if app.hud.advance_button.disabled: await create_timer(0.05).timeout
			else: await key(KEY_ENTER)
		else: return
	expect(false, "Authored dialogue and scenes finish within their bound")


func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	started = Time.get_ticks_msec()
	app = SCENE.instantiate() as ChapterOne
	app.save_path = "user://saves/test_chapter1_cinematics.json"
	root.add_child(app)
	current_scene = app
	physics_frame.connect(func() -> void:
		if not _probe_follow or app.mode != "world": return
		var follower: Node2D = app.world.actor_for("wen_rang")
		if follower != null:
			follow_samples += 1
			expect(app.world.can_stand(follower.position), "Follower's feet remain clear while rounding the stage corner"))
	root.mode = Window.MODE_MAXIMIZED
	await frames(10)
	app.start_new_game()
	await key(KEY_M)
	expect(app.mode == "cinematic" and not app.hud.menu_layer.visible, "Map input cannot interrupt the opening scene")
	await _read_scenes()
	expect(app.state.room == "auditorium" and app.state.flags.get("gate_entered", false), "Both students enter the detection hall after the gate conversation")
	await key(KEY_D, 28)
	var companion: ChapterActor = app.world.actor_for("wen_rang") as ChapterActor
	var follow_origin: Vector2 = companion.position
	await key(KEY_S, 24)
	expect(companion.position.distance_to(follow_origin) > 15 and companion.walk_frames.size() == 16, "Wen follows the actual exploration route with a directional sheet")
	_probe_follow = true
	await move_axis(0,650)
	await move_axis(1,474)
	await move_axis(0,680)
	await move_axis(1,425)
	await move_axis(0,700)
	_probe_follow = false
	expect(follow_samples > 20 and companion.position.distance_to(app.world.player.position) < 110, "Wen rounds the real stage corner without clipping or losing the player")
	app.interact("exam")
	await _read_scenes()
	expect(introductions == ["柳无眠", "沈听澜", "温若水", "唐半夏"], "Four mentors introduce themselves in the actual stage dialogue")
	expect(app.cinematics.completed.slice(0,4) == ["gate_arrival","enter_auditorium","test_to_assembly","assembly_to_exhibits"], "Gate, detection hall, ceremony and exhibits form one ordered sequence")
	expect(app.state.phase == "mentors" and app.state.room == "plaza" and app.state.mentor.is_empty(), "Ceremony returns control for the four optional apprenticeship tasks")
	app.present(app.story.perform("liu"))
	await _read_scenes(false)
	app.travel("training")
	app.present(app.story.perform("comic"))
	await _read_scenes(false)
	app.present(app.story.perform("liu"))
	await _read_scenes(false)
	app.select_choice(0)
	await _read_scenes()
	expect(app.mode == "choice" and app.state.flags.get("su_visit_seen",false) and app.state.flags.get("hill_route_received",false), "Su walks in, greets both students and provides the shared hill directions before all responses")
	for actor_id: String in ["wen_rang", "liu", "shen", "wen", "tang", "SuWanyanVisitor"]:
		expect(walking_textures.get(actor_id,[]).size() >= 3, "Entrance has changing directional walking frames: " + actor_id)
	# Cancellation must never let a previous scene mutate a later session.
	app.start_new_game()
	await frames(8)
	app.return_to_title()
	var cancelled: Dictionary = app.state.snapshot()
	await create_timer(2.0).timeout
	expect(app.mode == "title" and not app.cinematics.active and not app.cinematics._ui.visible and app.state.snapshot() == cancelled, "Returning to title cancels movement and any delayed story callback")
	app.load_game()
	expect(app.mode == "cinematic" and app.state.room == "gate", "Loading the initial checkpoint safely restarts the gate scene")
	await key(KEY_F11)
	expect(root.mode == Window.MODE_FULLSCREEN and app.cinematics.active and app.cinematics._ui.size == app.hud.size, "F11 keeps the active cinematic overlay at the new full-screen size")
	await click(app.cinematics._skip)
	expect(app.mode == "dialogue" and app.state.flags.get("gate_arrival_seen",false), "Mouse Skip reaches the same opening dialogue")
	while app.mode == "dialogue": app.advance_dialogue()
	await key(KEY_ESCAPE)
	expect(app.mode == "world" and app.state.room == "auditorium" and app.world.player.position == Vector2(700,520), "Esc Skip applies the exact hall entry endpoint and restores input")
	await key(KEY_F11)
	# Saves made before the gate was added remain valid and do not replay arrival.
	var legacy: ChapterSession = ChapterSession.new()
	legacy.room = "auditorium"
	legacy.player_position = Vector2(700,520)
	legacy.save_to(app.save_path)
	app.return_to_title()
	app.load_game()
	expect(app.mode == "world" and app.state.room == "auditorium" and app.world.player.position == legacy.player_position, "Legacy test-room saves preserve the player's position and resume normally")
	app.interact("exam")
	while app.mode == "dialogue":
		if app.hud.advance_button.disabled: await create_timer(0.05).timeout
		else: app.advance_dialogue()
	expect(app.mode == "cinematic", "Legacy progress can still enter the new ceremony")
	await key(KEY_ESCAPE)
	expect(app.mode == "dialogue" and app.state.room == "assembly_stage" and app.state.flags.get("mentor_ceremony_seen",false), "Skipping all mentor entrances still reaches the introductions once")
	app.cinematics.skip()
	var flags: int = 0
	for entry: Dictionary in app.state.events:
		if entry.kind == "flag" and entry.details.id == "mentor_ceremony_seen": flags += 1
	expect(flags == 1 and app.state.sl == 5 and app.state.mentor.is_empty(), "Repeated Skip cannot repeat a ceremony commit or apprenticeship reward")
	_write_report()
	print("[CHAPTER1 CINEMATICS] %d/%d checks; %d collision-free actor samples; %.1fs" % [checks.size()-failures.size(),checks.size(),route_samples,(Time.get_ticks_msec()-started)/1000.0])
	quit(0 if failures.is_empty() else 1)


func _write_report() -> void:
	var report: FileAccess = FileAccess.open("res://.dev/chapter1-cinematics-report.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"captures":captures,
		"movie_frames":movie_frames,"walking_textures":walking_textures,"introductions":introductions,
		"route_samples":route_samples,"follow_samples":follow_samples,"trace":app.cinematics.trace if app != null and app.cinematics != null else [],
		"seconds":(Time.get_ticks_msec()-started)/1000.0},"\t"))
	report.close()
