extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SIZES: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual verification requires an actual graphics display.")
		quit(1)
		return
	var main: Control = MAIN_SCENE.instantiate()
	root.add_child(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.dev"))
	# Let Windows finish applying the startup window before the first resize.
	for _index in range(12):
		await process_frame
	var samples: Array[Dictionary] = []
	var pixel_layers: Dictionary = {}
	for requested_size in SIZES:
		root.size = requested_size
		for _index in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		var world: SubViewport = main.get_node("WorldContainer/WorldViewport")
		var world_transform := root.get_final_transform()
		var scale_value := world_transform.get_scale().x
		var logical_ui: Control = main.get_node("UI/LogicalUI")
		var hud_scale := scale_value * logical_ui.scale.x
		var scale_ok := is_equal_approx(scale_value, floorf(scale_value)) and scale_value >= 1.0
		var viewport_ok := world.size == Vector2i(960, 540)
		if not scale_ok or not viewport_ok:
			_failures.append("Incorrect viewport or integer scale at %s" % requested_size)
		if root.size != requested_size:
			_failures.append("Requested %s but actual window is %s" % [requested_size, root.size])
		var expected_scale := floorf(minf(requested_size.x / 960.0, requested_size.y / 540.0))
		if not is_equal_approx(scale_value, expected_scale):
			_failures.append("Wrong world scale at %s" % requested_size)
		var image := root.get_texture().get_image()
		var path := "res://.dev/m0-%dx%d.png" % [requested_size.x, requested_size.y]
		var save_result := image.save_png(path)
		if save_result != OK:
			_failures.append("Could not save " + path)
		if image.get_size() != Vector2i(960, 540) * int(expected_scale):
			_failures.append("Wrong content render size at %s" % requested_size)
		if requested_size == Vector2i(1920, 1080):
			pixel_layers = _check_pixel_layers(image)
		samples.append({
			"requested_size": [requested_size.x, requested_size.y],
			"actual_window": [root.size.x, root.size.y],
			"image_size": [image.get_width(), image.get_height()],
			"world_viewport": [world.size.x, world.size.y],
			"world_scale": scale_value,
			"ui_scale": hud_scale,
			"viewport_origin": [world_transform.origin.x, world_transform.origin.y],
			"image": path,
		})
		print("[M0 VISUAL] %s | world scale %.2f | UI scale %.2f | image %s" % [root.size, scale_value, hud_scale, image.get_size()])
	await _tap_key(KEY_F11)
	var fullscreen_entered := root.mode == Window.MODE_FULLSCREEN
	await _tap_key(KEY_F11)
	var window_restored := root.mode == Window.MODE_WINDOWED
	if not fullscreen_entered or not window_restored:
		_failures.append("F11 did not toggle fullscreen and restore windowed mode")
	print("[M0 VISUAL] F11 fullscreen=%s | window restored=%s" % [fullscreen_entered, window_restored])
	var file := FileAccess.open("res://.dev/m0-visual-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": _failures.is_empty(), "samples": samples, "pixel_layers": pixel_layers, "fullscreen_entered": fullscreen_entered, "window_restored": window_restored, "failures": _failures}, "\t"))
	file.close()
	main.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)


func _check_pixel_layers(image: Image) -> Dictionary:
	# Empty ground below the HUD must consist of identical 2x2 world pixels.
	var uniform_world := true
	for y in range(600, 720, 2):
		for x in range(128, 384, 2):
			var color := image.get_pixel(x, y)
			if color != image.get_pixel(x + 1, y) or color != image.get_pixel(x, y + 1) or color != image.get_pixel(x + 1, y + 1):
				uniform_world = false
	if not uniform_world:
		_failures.append("World pixels are not exact 2x2 blocks at 1080p")
	# Native-resolution font edges must have detail within those same 2x2 blocks.
	var high_resolution_ui := false
	for y in range(32, 88, 2):
		for x in range(48, 520, 2):
			var color := image.get_pixel(x, y)
			if color != image.get_pixel(x + 1, y) or color != image.get_pixel(x, y + 1):
				high_resolution_ui = true
	if not high_resolution_ui:
		_failures.append("UI is not rendered independently at 1080p")
	print("[M0 VISUAL] exact 2x2 world pixels=%s | independent HD UI=%s" % [uniform_world, high_resolution_ui])
	return {"exact_2x2_world_pixels": uniform_world, "independent_hd_ui": high_resolution_ui}


func _tap_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	for _index in range(12):
		await process_frame
	event = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	for _index in range(12):
		await process_frame
