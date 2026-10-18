extends SceneTree

const APP_SCENE: PackedScene = preload("res://scenes/chapter/chapter_one.tscn")
const PORTRAITS: Script = preload("res://scripts/chapter/chapter_portraits.gd")
const SIZES: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(1920, 1001), Vector2i(1920, 1200),
	Vector2i(2560, 1080), Vector2i(960, 1080),
]
var app: ChapterOne
var failures: Array[String] = []
var check_count: int = 0
var captures: Array[String] = []
var samples: Dictionary[String, Dictionary] = {}
var output_dir: String = "res://docs/previews/portraits-2026-10-18"
var started: int = 0


func _initialize() -> void:
	_run.call_deferred()


func frames(count: int) -> void:
	for index: int in range(count):
		await process_frame


func expect(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)
		push_error(message)


func screen_rect(control: Control) -> Rect2:
	var transform: Transform2D = root.get_final_transform() * control.get_global_transform_with_canvas()
	return Rect2(transform * Vector2.ZERO, transform.basis_xform(control.size))


func inside_window(control: Control) -> bool:
	return Rect2(Vector2.ZERO, Vector2(root.size)).grow(1.0).encloses(screen_rect(control))


func check_dialogue(label: String) -> void:
	expect(app.hud.portrait.is_visible_in_tree(), label + ": portrait is visible")
	expect(inside_window(app.hud.portrait), label + ": portrait remains inside the window")
	expect(inside_window(app.hud.body_label), label + ": body remains inside the window")
	expect(inside_window(app.hud.advance_button), label + ": Continue remains inside the window")
	expect(screen_rect(app.hud.body_label).end.x < screen_rect(app.hud.portrait).position.x,
		label + ": text does not overlap the portrait")
	expect(not screen_rect(app.hud.advance_button).intersects(screen_rect(app.hud.portrait)),
		label + ": portrait does not cover Continue")
	expect(app.hud.body_label.get_minimum_size().y <= app.hud.body_label.size.y,
		label + ": Chinese text fits")
	expect(app.hud.portrait.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		label + ": portrait cannot steal mouse input")
	expect(app.hud.portrait.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		label + ": HD art uses linear sampling")
	expect(app.world.get_viewport().canvas_item_default_texture_filter
		== Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST,
		label + ": world retains nearest pixel sampling")


func show_speaker(speaker: String) -> void:
	app.mode = "dialogue"
	app._line_index = 0
	app._lines.clear()
	app._lines.append(samples[speaker].duplicate(true))
	app._choices.clear()
	app.world.dialogue_framing = true
	app.world.player.blocked = true
	app._show_line()
	await frames(3)


func capture(name_value: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await frames(3)
	var path: String = output_dir + "/" + name_value + ".png"
	expect(root.get_texture().get_image().save_png(path) == OK, "Capture " + name_value)
	captures.append(path)


func _run() -> void:
	started = Time.get_ticks_msec()
	await process_frame
	create_timer(180.0).timeout.connect(func() -> void:
		push_error("Portrait validation timed out")
		quit(1))
	if OS.get_cmdline_user_args().has("--exported"):
		output_dir = "user://portrait-qa-export"
		expect(FileAccess.file_exists("res://project.binary"), "Using an exported project.binary")
		expect(not FileAccess.file_exists("res://project.godot"), "No loose source project is loaded")
		expect(not ResourceLoader.exists("res://assets/portraits/source/su_wan_yan_raw.png"),
			"Generated raw art is excluded from the player build")
		var catalog_hash: HashingContext = HashingContext.new()
		catalog_hash.start(HashingContext.HASH_SHA256)
		catalog_hash.update(FileAccess.get_file_as_bytes("res://data/portraits/characters.json"))
		var actual_hash: String = catalog_hash.finish().hex_encode()
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--catalog-sha="):
				expect(actual_hash == argument.trim_prefix("--catalog-sha="),
					"Exported portrait catalog matches the final source exactly")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	for path: String in ["res://data/chapter1/dialogues.json",
			"res://data/chapter2/dialogues.json", "res://data/cultivation/dialogues.json"]:
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
		for sequence: Variant in parsed.values():
			if not sequence is Array:
				continue
			for line: Dictionary in sequence:
				var speaker: String = String(line.get("speaker", ""))
				if speaker.is_empty() or speaker in ["旁白", "系统提示", "日程记录"]:
					continue
				if not samples.has(speaker):
					samples[speaker] = line.duplicate(true)
	expect(not samples.is_empty(), "Actual chapter dialogue supplies a cast")
	expect(PORTRAITS.speakers().size() == samples.size(), "Catalog covers the actual cast exactly")
	for speaker: String in samples:
		expect(PORTRAITS.has_speaker(speaker), "Registered speaker: " + speaker)
		var texture: Texture2D = PORTRAITS.texture_for(speaker)
		expect(texture != null, "Exportable texture loads: " + speaker)
		if texture == null:
			continue
		expect(texture.get_width() >= 640 and texture.get_height() >= 960,
			"HD resolution, not a pixel frame: " + speaker)
		var image: Image = texture.get_image()
		expect(image != null and not image.is_empty(), "Portrait image decodes: " + speaker)
		if image != null:
			if image.is_compressed():
				image.decompress()
			expect(image.get_pixel(0, 0).a < 0.1, "Transparent portrait corner: " + speaker)
	for speaker: String in ["旁白", "系统提示", "日程记录", ""]:
		expect(PORTRAITS.texture_for(speaker) == null, "Captions do not borrow a character: " + speaker)
	app = APP_SCENE.instantiate() as ChapterOne
	app.save_path = "user://saves/test_dialogue_portraits.json"
	root.add_child(app)
	current_scene = app
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await frames(10)
	app.state.phase = "hill"
	app.state.room = "hill"
	app._load_room()
	app.hud.show_world()
	for speaker: String in samples:
		await show_speaker(speaker)
		expect(app.hud.portrait.texture == PORTRAITS.texture_for(speaker),
			"Real chapter renderer selects the correct portrait: " + speaker)
		check_dialogue(speaker)
	for requested: Vector2i in SIZES:
		root.size = requested
		await frames(8)
		await show_speaker("苏挽颜")
		check_dialogue(str(requested))
		if requested in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			await capture("dialogue-su-%dx%d" % [root.size.x, root.size.y])
	root.size = Vector2i(1280, 720)
	await frames(6)
	await show_speaker("温让")
	await capture("dialogue-wen-rang")
	await show_speaker("唐半夏")
	await capture("dialogue-tang-ban-xia")
	app.state.room = "cult_library"
	app._load_room()
	await show_speaker("白沐瑶")
	await capture("dialogue-bai-mu-yao")
	app.state.room = "cult_ice_shop"
	app._load_room()
	await show_speaker("苏父")
	await capture("dialogue-su-father")
	var body_width: float = app.hud.body_label.size.x
	app.hud.show_line({"speaker": "旁白", "text": "交谈结束，整理好手边的东西。"}, null)
	await frames(3)
	expect(not app.hud.portrait.visible, "Narration clears the previous portrait")
	expect(app.hud.body_label.size.x > body_width, "Narration recovers the full text width")
	app.hud.show_line({"speaker": "系统提示", "text": "成长记录已保存。"}, null)
	expect(not app.hud.portrait.visible, "System message has no stale character")
	app.hud.show_choices([{"label": "先看看"}])
	expect(not app.hud.portrait.is_visible_in_tree(), "Choices hide the dialogue portrait")
	app.hud.show_world()
	expect(not app.hud.portrait.is_visible_in_tree(), "World mode hides the portrait")
	expect(app.world.player.frames.size() == 16, "All 16 pixel walking frames remain available")
	for frame: Texture2D in app.world.player.frames:
		expect(frame.get_width() == 96 and frame.get_height() == 96
			and frame.resource_path.begins_with("res://assets/chapter1/refined/lin_da/frames/"),
			"Walking retains the original 96x96 pixel source, drawn at 48x48 world units")
	app.state.room = "hill"
	app._load_room()
	app.mode = "world"
	app.world.dialogue_framing = false
	app.world.player.blocked = false
	app.world.player.position = Vector2(520, 460)
	var before: Vector2 = app.world.player.position
	Input.action_press("move_right")
	for index: int in range(12):
		await physics_frame
	Input.action_release("move_right")
	await frames(3)
	expect(app.world.player.position.x > before.x, "Pixel character still moves in the real world")
	await capture("pixel-world-movement")
	app.mode = "dialogue"
	app.world.player.blocked = true
	await show_speaker("苏挽颜")
	before = app.world.player.position
	Input.action_press("move_right")
	for index: int in range(8):
		await physics_frame
	Input.action_release("move_right")
	expect(app.world.player.position.is_equal_approx(before),
		"Dialogue preserves the existing movement lock")
	app.hud.show_world()
	var battle_hud: ChapterBattleHUD = ChapterBattleHUD.new()
	battle_hud.size = app.hud.size
	app.hud.add_child(battle_hud)
	await frames(4)
	var definition: TutorialDefinition = load("res://data/battle/tutorial/m1_d_tutorial.tres")
	battle_hud.present_lesson(definition, 0, &"intro", true, "先看看草坡。", "", "后山练习", "")
	battle_hud.apply_display_layout()
	await frames(3)
	expect(battle_hud._guide_portrait.texture == PORTRAITS.texture_for("苏挽颜"),
		"Tutorial dialogue uses the same HD Su portrait")
	expect(battle_hud._guide_portrait.is_visible_in_tree(), "Tutorial intro shows a portrait")
	expect(inside_window(battle_hud._guide_portrait), "Tutorial portrait stays inside the window")
	expect(not screen_rect(battle_hud._guide_portrait).intersects(screen_rect(battle_hud.primary_button)),
		"Tutorial portrait does not cover its button")
	await capture("tutorial-su-portrait")
	battle_hud.present_lesson(definition, 0, &"battle", true, "先看目标。", "", "", "")
	expect(not battle_hud._guide_portrait.is_visible_in_tree(),
		"Active combat hides the guide portrait and preserves the battlefield")
	battle_hud.queue_free()
	await frames(3)
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_MAXIMIZED
		await frames(10)
		await show_speaker("苏挽颜")
		check_dialogue("native maximized")
		await capture("dialogue-maximized")
		root.mode = Window.MODE_FULLSCREEN
		await frames(10)
		check_dialogue("native fullscreen")
		await capture("dialogue-fullscreen")
		root.mode = Window.MODE_WINDOWED
	var report: Dictionary = {
		"passed": failures.is_empty(), "checks": check_count, "speakers": samples.size(),
		"failures": failures, "captures": captures, "engine": Engine.get_version_info().string,
		"renderer": DisplayServer.get_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"seconds": float(Time.get_ticks_msec() - started) / 1000.0,
	}
	var report_name: String = "validation-headless.json" if DisplayServer.get_name() == "headless" else "validation-report.json"
	var file: FileAccess = FileAccess.open(output_dir + "/" + report_name, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("[DialoguePortraits] ", check_count, " checks; ", samples.size(), " speakers; failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
