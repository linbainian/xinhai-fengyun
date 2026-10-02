extends SceneTree

const SANDBOX: PackedScene = preload("res://scenes/battle/battle_sandbox.tscn")
const SIZES: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]

var _failures: Array[String] = []
var _checks: Array[Dictionary] = []
var _samples: Array[Dictionary] = []
var _sandbox: BattleSandbox


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("M1 visual verification requires an actual graphics display.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.dev"))
	_sandbox = SANDBOX.instantiate()
	_sandbox.automatic_flow = false
	root.add_child(_sandbox)
	current_scene = _sandbox
	await _frames(12)
	for requested_size: Vector2i in SIZES:
		root.size = requested_size
		await _frames(16)
		await RenderingServer.frame_post_draw
		var world: SubViewport = _sandbox.get_node("WorldContainer/WorldViewport")
		var transform: Transform2D = root.get_final_transform()
		var scale_value: float = transform.get_scale().x
		var expected_scale: float = floorf(minf(requested_size.x / 960.0, requested_size.y / 540.0))
		_expect(root.size == requested_size, "%s: actual window matches request" % requested_size)
		_expect(scale_value == expected_scale, "%s: world scaling is integer" % requested_size)
		_expect(world.size == Vector2i(960, 540), "%s: world viewport remains fixed" % requested_size)
		_expect(_sandbox.hud.scale.x * scale_value == expected_scale * 0.5, "%s: UI has its independent scale" % requested_size)
		var image: Image = root.get_texture().get_image()
		_expect(image.get_size() == Vector2i(960, 540) * int(expected_scale), "%s: content excludes letterbox bars" % requested_size)
		image.save_png("res://.dev/m1-a-%dx%d.png" % [requested_size.x, requested_size.y])
		if requested_size == Vector2i(1920, 1080):
			_check_pixel_layers(image)
		_samples.append({"window": [root.size.x, root.size.y], "world_scale": scale_value,
			"ui_scale": _sandbox.hud.scale.x * scale_value, "image": [image.get_width(), image.get_height()],
			"origin": [transform.origin.x, transform.origin.y]})
		await _click(_sandbox.hud.defense_button)
		_expect(_sandbox.controller.combatants[0].hp == 102 and _sandbox.controller.combatants[0].sl == 15,
			"%s: actual mouse click reaches defense through scaling/letterboxing" % requested_size)
		await _click(_sandbox.hud.attack_button)
		_expect(_sandbox.controller.events.size() == 3, "%s: disabled attack cannot add a second action" % requested_size)
		_sandbox.restart_battle()
		await _frames(2)
	_sandbox.automatic_flow = true
	for _step: int in range(800):
		if _sandbox.controller.phase == BattleController.Phase.FINISHED:
			break
		if _sandbox.controller.phase == BattleController.Phase.PLAYER_COMMAND:
			await _tap_key(KEY_A)
		await _frames(1)
	_expect(_sandbox.controller.result == &"victory", "Actual A key and presentation timers complete a winning battle")
	await _capture("res://.dev/m1-a-victory.png")
	await _tap_key(KEY_E)
	_expect(FileAccess.file_exists(_sandbox.controller.last_export_path), "Actual E key exports a log")
	await _tap_key(KEY_R)
	_expect(_sandbox.controller.round_number == 1 and _sandbox.controller.combatants[0].hp == 90,
		"Actual R key restarts after victory")
	var loss: EncounterDefinition = ResourceLoader.load("res://data/battle/m1_a_encounter.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EncounterDefinition
	loss.enemy.speed = 99
	loss.enemy.attack = 10000.0
	loss.enemy.accuracy = 100.0
	loss.enemy.perception = loss.ally.perception
	loss.ally.evasion = 0.0
	_sandbox.controller.start_battle(loss)
	for _step: int in range(180):
		if _sandbox.controller.phase == BattleController.Phase.FINISHED:
			break
		await _frames(1)
	_expect(_sandbox.controller.result == &"defeat", "Actual enemy timers reach a defeat state")
	await _capture("res://.dev/m1-a-defeat.png")
	await _tap_key(KEY_R)
	_expect(_sandbox.controller.phase == BattleController.Phase.PLAYER_COMMAND, "Retry also works after defeat")
	await _tap_key(KEY_F11)
	_expect(root.mode == Window.MODE_FULLSCREEN, "F11 enters fullscreen")
	await _tap_key(KEY_F11)
	_expect(root.mode == Window.MODE_WINDOWED, "F11 restores windowed mode")
	await _click(_sandbox.hud.back_button)
	await _frames(6)
	_expect(current_scene != null and current_scene.name == &"Main", "Return button opens the original M0 scene")
	var report: FileAccess = FileAccess.open("res://.dev/m1-a-visual-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": _failures.is_empty(), "samples": _samples,
		"checks": _checks, "failures": _failures}, "\t"))
	report.close()
	print("[M1-A VISUAL] %d/%d checks passed" % [_checks.size() - _failures.size(), _checks.size()])
	quit(0 if _failures.is_empty() else 1)


func _check_pixel_layers(image: Image) -> void:
	var uniform_world: bool = true
	for y: int in range(232, 400, 2):
		for x: int in range(500, 880, 2):
			var color: Color = image.get_pixel(x, y)
			if color != image.get_pixel(x + 1, y) or color != image.get_pixel(x, y + 1) or color != image.get_pixel(x + 1, y + 1):
				uniform_world = false
	_expect(uniform_world, "1080p world pixels are exact 2x2 blocks")
	var detailed_ui: bool = false
	for y: int in range(30, 90, 2):
		for x: int in range(48, 600, 2):
			var color: Color = image.get_pixel(x, y)
			if color != image.get_pixel(x + 1, y) or color != image.get_pixel(x, y + 1):
				detailed_ui = true
	_expect(detailed_ui, "1080p UI font has detail within 2x2 world pixels")


func _click(button: Button) -> void:
	var point: Vector2 = root.get_final_transform() * (button.get_global_transform_with_canvas() * (button.size * 0.5))
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(1)
	event = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)


func _tap_key(key: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)


func _capture(path: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _expect(condition: bool, description: String) -> void:
	_checks.append({"passed": condition, "description": description})
	if not condition:
		_failures.append(description)
		push_error("[M1-A VISUAL] " + description)
