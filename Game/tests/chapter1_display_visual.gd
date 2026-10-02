extends "res://tests/chapter1_visual.gd"

const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1366, 768),
	Vector2i(1600, 900), Vector2i(1920, 1001), Vector2i(1920, 1040),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
	Vector2i(1920, 1200), Vector2i(2560, 1080), Vector2i(960, 1080),
]
var samples: Array[Dictionary] = []


func _screen_rect(control: Control) -> Rect2:
	var transform: Transform2D = root.get_final_transform() * control.get_global_transform_with_canvas()
	return Rect2(transform * Vector2.ZERO, transform.basis_xform(control.size))


func _fills_window(control: Control) -> bool:
	var rect: Rect2 = _screen_rect(control)
	return rect.position.length() < 0.1 and rect.end.x >= root.size.x - 0.1 and rect.end.y >= root.size.y - 0.1


func _inside_window(control: Control) -> bool:
	return Rect2(Vector2.ZERO, Vector2(root.size)).grow(0.1).encloses(_screen_rect(control))


func _check_display(display: ChapterDisplay, label: String) -> void:
	expect(root.get_final_transform().is_equal_approx(Transform2D.IDENTITY), label + ": no global letterboxing")
	expect(_fills_window(display.world_container), label + ": pixel world fills the client area")
	var scale_value: Vector2 = display.world_container.get_global_transform_with_canvas().get_scale()
	expect(scale_value.x >= 1.0 and is_equal_approx(scale_value.x, roundf(scale_value.x)) and scale_value.is_equal_approx(Vector2.ONE * scale_value.x), label + ": uniform integer pixel scale")
	expect(display.world_viewport.snap_2d_transforms_to_pixel and display.world_container.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, label + ": nearest sampling and pixel snapping")
	expect(_fills_window(display.logical_ui), label + ": UI spans the full client area")
	samples.append({"label": label, "window": [root.size.x, root.size.y], "world": [display.world_viewport.size.x, display.world_viewport.size.y], "pixel_scale": scale_value.x, "ui_scale": display.logical_ui.scale.x})


func _check_rendered_title() -> void:
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	expect(frame.get_size() == root.size, "Title framebuffer matches the window size")
	var clear_color: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	for point: Vector2i in [Vector2i(2, 2), Vector2i(frame.get_width() - 3, 2), Vector2i(2, frame.get_height() - 3), frame.get_size() - Vector2i(3, 3)]:
		var pixel: Color = frame.get_pixelv(point)
		var difference: float = absf(pixel.r - clear_color.r) + absf(pixel.g - clear_color.g) + absf(pixel.b - clear_color.b)
		expect(difference > 0.01, "Title paints the window corner " + str(point))


func _check_exploration(label: String) -> void:
	_check_display(app.display, label)
	expect(_inside_window(app.hud.dialog_panel) and _inside_window(app.hud.advance_button), label + ": dialogue and Continue remain visible")
	expect(_inside_window(app.hud.top_panel) and _inside_window(app.hud.prompt_label), label + ": exploration HUD stays at the window edges")
	await key(KEY_M)
	expect(app.mode == "menu" and _fills_window(app.hud.menu_layer) and _inside_window(app.hud.menu_card), label + ": map modal fits and covers the window")
	await click(button_named(app.hud.menu_card, "关闭"))
	expect(app.mode == "world", label + ": map close responds to mouse after resizing")
	app.present({"dialogue": "wen_arrival", "choices": [{"label": "继续探索", "action": "close"}]})
	await drain_dialogue()
	expect(app.mode == "choice" and _fills_window(app.hud.choice_layer), label + ": choice overlay covers the window")
	await click(button_named(app.hud.choice_layer, "1 · "))
	expect(app.mode == "world", label + ": choice responds to mouse after resizing")


func _check_battle(sandbox: ChapterTutorial, label: String) -> void:
	_check_display(sandbox.display, label)
	var battle_hud: ChapterBattleHUD = sandbox.hud as ChapterBattleHUD
	expect(_inside_window(battle_hud._status_bar) and _inside_window(battle_hud._command_bar), label + ": battle status and commands fit")
	expect(_inside_window(battle_hud.attack_button) and _inside_window(battle_hud.back_button), label + ": outer command buttons remain visible")
	for unit: CombatantState in sandbox.controller.combatants:
		var view: CombatantView = sandbox._views[unit.id]
		var art: Rect2 = Rect2(view.position + view._art_rect.position * view.scale, view._art_rect.size * view.scale)
		var ui_art: Rect2 = Rect2(sandbox.display.world_to_ui(art.position), sandbox.display.world_to_ui(art.end) - sandbox.display.world_to_ui(art.position))
		expect(ui_art.position.y >= battle_hud.FIELD_TOP and ui_art.end.y < battle_hud._command_bar.position.y, label + ": sprite is fully inside the open battlefield")
	var enemy: CombatantState = sandbox.controller.living_team(false)[0]
	var enemy_view: CombatantView = sandbox._views[enemy.id]
	var hit_button: Button = battle_hud._enemy_hit_buttons[0]
	var screen_point: Vector2 = sandbox.display.world_container.get_global_transform_with_canvas() * (enemy_view.position - Vector2(0, 72))
	expect(_screen_rect(hit_button).has_point(screen_point), label + ": rabbit hit area follows the sprite")
	await click(hit_button)
	expect(battle_hud.selected_target == enemy.id, label + ": clicking the rabbit selects it")
	await key(KEY_L)
	expect(battle_hud.log_drawer.visible and _inside_window(battle_hud.log_drawer), label + ": battle log fits")
	await key(KEY_ESCAPE)
	expect(not battle_hud.log_drawer.visible and app.battle == sandbox, label + ": Esc closes the log without exiting battle")


func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	started = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.dev"))
	app = SCENE.instantiate() as ChapterOne
	app.save_path = "user://saves/test_chapter1_display.json"
	root.add_child(app)
	current_scene = app
	await frames(8)
	for requested: Vector2i in WINDOW_SIZES:
		root.size = requested
		await frames(8)
		_check_display(app.display, "title " + str(requested))
		expect(_fills_window(app.hud.title_layer) and _inside_window(button_named(app.hud.title_layer, "开始游戏")), "Title covers the window and its Start button fits")
		await _check_rendered_title()
		if requested in [Vector2i(1366, 768), Vector2i(1920, 1001), Vector2i(2560, 1440)]:
			await capture("display-title-%dx%d" % [requested.x, requested.y])
	await click(button_named(app.hud.title_layer, "开始游戏"))
	await wait_for_mode("dialogue")
	expect(app.mode == "dialogue", "Resized title Start button opens the game")
	await drain_dialogue()
	for requested: Vector2i in WINDOW_SIZES:
		root.size = requested
		await frames(8)
		await _check_exploration("exploration " + str(requested))
	root.mode = Window.MODE_MAXIMIZED
	await frames(12)
	expect(root.mode == Window.MODE_MAXIMIZED, "Native maximize succeeds")
	await _check_exploration("native maximized")
	await capture("display-maximized-world")
	app.present({"dialogue": "wen_arrival"})
	await capture("display-maximized-dialogue")
	expect(_inside_window(app.hud.dialog_panel) and _inside_window(app.hud.advance_button), "Maximized dialogue fits the actual client area")
	await drain_dialogue()
	app.story.perform("exam")
	app.story.perform("liu")
	app.story.perform("comic")
	app.story.perform("liu")
	app.story.perform("join", "liu")
	app.story.perform("accept_su", "0")
	app.travel("hill")
	app.start_battle()
	var sandbox: ChapterTutorial = app.battle
	sandbox.automatic_flow = false
	var battle_hud: ChapterBattleHUD = sandbox.hud as ChapterBattleHUD
	expect(_fills_window(battle_hud._overlay) and _inside_window(battle_hud._lesson_card), "Maximized battle intro covers the client area")
	await click(battle_hud.primary_button)
	expect(sandbox.flow == &"battle", "Resized tutorial Start button responds to mouse")
	for requested: Vector2i in WINDOW_SIZES:
		root.mode = Window.MODE_WINDOWED
		root.size = requested
		await frames(8)
		await _check_battle(sandbox, "battle " + str(requested))
	root.mode = Window.MODE_MAXIMIZED
	await frames(12)
	await _check_battle(sandbox, "battle native maximized")
	await capture("display-maximized-battle")
	await key(KEY_F11)
	await frames(12)
	expect(root.mode == Window.MODE_FULLSCREEN, "Battle F11 enters fullscreen")
	await _check_battle(sandbox, "battle fullscreen")
	await key(KEY_F11)
	await frames(12)
	expect(root.mode == Window.MODE_WINDOWED, "Battle F11 returns to a window")
	await _check_battle(sandbox, "battle restored window")
	await key(KEY_ESCAPE)
	await frames(4)
	expect(app.battle == null and app.mode == "dialogue", "Resized battle returns to chapter dialogue")
	_check_display(app.display, "exploration after battle")
	_write_report()
	print("[CHAPTER1 DISPLAY] %d/%d checks passed; %.1fs" % [checks.size() - failures.size(), checks.size(), (Time.get_ticks_msec() - started) / 1000.0])
	quit(0 if failures.is_empty() else 1)


func _write_report() -> void:
	var report: FileAccess = FileAccess.open("res://.dev/chapter1-display-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": failures.is_empty(), "engine": Engine.get_version_info().string, "gpu": RenderingServer.get_video_adapter_name(), "screen": str(DisplayServer.screen_get_size()), "checks": checks, "failures": failures, "samples": samples, "captures": captures, "seconds": (Time.get_ticks_msec() - started) / 1000.0}, "\t"))
	report.close()
