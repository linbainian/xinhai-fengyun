extends SceneTree

const SCENE: PackedScene = preload("res://scenes/battle/back_hill_tutorial.tscn")
const SIZES: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]
var _sandbox: TutorialSandbox
var _hud: TutorialHUD
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _durations: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Requires the real graphics display")
		quit(1)
		return
	_sandbox = SCENE.instantiate()
	_sandbox.automatic_flow = false
	root.add_child(_sandbox)
	current_scene = _sandbox
	_hud = _sandbox.hud as TutorialHUD
	await _frames(12)
	for requested: Vector2i in SIZES:
		root.size = requested
		await _frames(16)
		var scale_value: float = root.get_final_transform().get_scale().x
		var expected: float = floorf(minf(requested.x / 960.0, requested.y / 540.0))
		_expect(root.size == requested and scale_value == expected, "%s window and integer scale" % requested)
		_expect(_sandbox.get_node("WorldContainer/WorldViewport").size == Vector2i(960, 540), "%s fixed world viewport" % requested)
		_expect(_hud.scale.x * scale_value == expected * 0.5, "%s separate UI scale" % requested)
		_expect(_hud._modal_body.get_minimum_size().y <= _hud._modal_body.size.y, "%s introduction fits its card" % requested)
		await _capture("res://.dev/m1-d-intro-%dx%d.png" % [requested.x, requested.y])
		await _click(_hud.secondary_button)
		_expect(_sandbox.flow == &"battle" and not _sandbox.hints_enabled, "%s mouse starts in quick mode" % requested)
		_expect(not _hud.attack_button.disabled, "%s commands unlock after start" % requested)
		await _capture("res://.dev/m1-d-%dx%d.png" % [requested.x, requested.y])
		if requested.x == 1920:
			_check_pixels(root.get_texture().get_image())
		await _click(_hud.enemy_buttons[1])
		_expect(_hud.selected_target == &"rabbit_element" and _hud._preview_label.text.contains("0.80"), "%s mouse target changes affinity preview" % requested)
		await _click(_hud.attack_button)
		var count: int = _sandbox.controller.events.size()
		await _click(_hud.attack_button)
		_expect(_sandbox.controller.events.size() == count, "%s duplicate mouse command is locked" % requested)
		await _key(KEY_T)
		_expect(_sandbox.flow == &"intro", "%s T restarts the whole tutorial" % requested)
	_sandbox.automatic_flow = true
	await _click(_hud.primary_button)
	await _key(KEY_H)
	_expect(not _sandbox.hints_enabled and _hud._coach_text.text.contains("隐藏"), "Actual H hides guidance without locking commands")
	await _key(KEY_H)
	_expect(_sandbox.hints_enabled, "Actual H restores guidance")
	await _key(KEY_TAB)
	_expect(_hud.selected_target == &"rabbit_element", "Actual Tab switches to a different threat")
	await _key(KEY_TAB)
	_expect(_hud._preview_label.text.contains("1.20"), "Actual target choice reveals the stronger affinity")
	var stage_start: int = Time.get_ticks_msec()
	var photographed: Dictionary = {}
	for _step: int in range(5000):
		if _sandbox.flow == &"complete" or _sandbox.flow == &"failed":
			break
		if not photographed.has(_sandbox.lesson_index):
			photographed[_sandbox.lesson_index] = true
			await _capture("res://.dev/m1-d-lesson%d.png" % (_sandbox.lesson_index + 1))
			_expect(_hud._coach_text.get_minimum_size().y <= _hud._coach_text.size.y, "Lesson%d coach text fits" % (_sandbox.lesson_index + 1))
		if _sandbox.flow == &"between":
			var ending: CombatantState = _sandbox.controller.living_team(true)[0]
			var ending_hp: int = ending.hp
			var ending_sl: int = ending.sl
			_durations.append({"lesson": _sandbox.lesson_index + 1, "seconds": (Time.get_ticks_msec() - stage_start) / 1000.0, "hp": ending_hp, "sl": ending_sl})
			await _capture("res://.dev/m1-d-between%d.png" % (_sandbox.lesson_index + 1))
			await _click(_hud.primary_button)
			var entering: CombatantState = _sandbox.controller.living_team(true)[0]
			_expect(entering.hp == ending_hp and entering.sl == ending_sl, "Real next-stage click carries exact HP/SL")
			stage_start = Time.get_ticks_msec()
		elif _sandbox.controller.phase == BattleController.Phase.PLAYER_COMMAND:
			await _actual_command()
		await _frames(1)
	_expect(_sandbox.flow == &"complete" and _sandbox.completed_lessons.size() == 3, "Real mouse/key commands and timers complete all three lessons")
	if _sandbox.flow == &"complete":
		var ending: CombatantState = _sandbox.controller.living_team(true)[0]
		_durations.append({"lesson": 3, "seconds": (Time.get_ticks_msec() - stage_start) / 1000.0, "hp": ending.hp, "sl": ending.sl})
	await _capture("res://.dev/m1-d-complete.png")
	await _key(KEY_E)
	_expect(not _sandbox.last_export_path.is_empty() and FileAccess.file_exists(_sandbox.last_export_path), "Actual E exports the complete tutorial")
	var file: FileAccess = FileAccess.open(_sandbox.last_export_path, FileAccess.READ)
	var exported: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	_expect(exported.stage == "M1-D" and exported.attempts.size() == 3, "Export preserves all three successful battle logs")
	var second_decisions: PackedStringArray = []
	for event: Dictionary in exported.attempts[1].battle.events:
		if event.kind == "target_selected":
			second_decisions.append("target")
		elif event.kind == "action" and event.details.actor_id == "lin_da":
			second_decisions.append(event.details.command)
	_expect(second_decisions.has("target") and second_decisions.has("skill") and second_decisions.has("defend"), "One actual lesson includes meaningful target, skill and load-relief decisions")
	_sandbox.export_tutorial_log("res://.dev/m1-d-visual-example.json")
	await _click(_hud.secondary_button)
	_expect(_sandbox.flow == &"battle" and not _sandbox.hints_enabled and _sandbox.lesson_index == 0, "Completion button starts a fresh quick replay (flow=%s hints=%s lesson=%d)" % [_sandbox.flow, _sandbox.hints_enabled, _sandbox.lesson_index])
	await _key(KEY_A)
	await _key(KEY_R)
	await create_timer(0.8).timeout
	_expect(_sandbox.controller.events.size() == 2 and _sandbox.flow == &"battle", "Actual R interrupts an action without stale callbacks")
	await _key(KEY_F11)
	await _frames(12)
	_expect(root.mode == Window.MODE_FULLSCREEN, "Actual F11 enters fullscreen")
	await _key(KEY_F11)
	await _frames(12)
	_expect(root.mode == Window.MODE_WINDOWED, "Actual F11 restores the window")
	await _key(KEY_T)
	await _click(_hud.modal_back_button)
	await _frames(6)
	_expect(current_scene != null and current_scene.name == &"Main", "Intro return button reaches M0")
	var report: FileAccess = FileAccess.open("res://.dev/m1-d-visual-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": _failures.is_empty(), "checks": _checks,
		"failures": _failures, "input_run_durations": _durations}, "\t"))
	report.close()
	print("[M1-D VISUAL] %d/%d checks passed" % [_checks.size() - _failures.size(), _checks.size()])
	quit(0 if _failures.is_empty() else 1)


func _actual_command() -> void:
	var actor: CombatantState = _sandbox.controller.current_actor()
	var targets: Array[CombatantState] = _sandbox.controller.living_team(false)
	var target: CombatantState = targets[0]
	for candidate: CombatantState in targets:
		var candidate_affinity: float = BattleCalculator.attack_preview(actor, candidate, _sandbox.controller.encounter).modifiers.affinity
		var target_affinity: float = BattleCalculator.attack_preview(actor, target, _sandbox.controller.encounter).modifiers.affinity
		if candidate_affinity > target_affinity or (candidate_affinity == target_affinity and candidate.hp < target.hp):
			target = candidate
	if _hud.selected_target != target.id:
		for index: int in range(_hud.enemy_buttons.size()):
			if not _hud.enemy_buttons[index].visible:
				continue
			var enemy_ids: Array[StringName] = []
			for unit: CombatantState in _sandbox.controller.combatants:
				if not unit.is_player:
					enemy_ids.append(unit.id)
			if enemy_ids[index] == target.id:
				await _click(_hud.enemy_buttons[index])
				break
	# Demonstrate cooldown/load relief in lesson2 and resource planning in the boss lesson.
	if _sandbox.lesson_index > 0 and not _sandbox.observed_goals().has("defend"):
		await _key(KEY_D)
	elif actor.weak_actions > 0:
		await _key(KEY_D)
	elif _sandbox.lesson_index == 2 and _sandbox.controller.can_breakthrough(actor) and actor.hp < actor.max_hp() * 0.8:
		await _key(KEY_B)
	elif actor.hp < actor.max_hp() * 0.6 or actor.sl >= 70:
		await _key(KEY_D)
	elif _sandbox.lesson_index > 0 and targets.size() > 1 and actor.cooldown_for(&"sweep") == 0:
		await _key(KEY_2)
	elif _sandbox.lesson_index > 0 and actor.cooldown_for(&"strike") == 0:
		await _key(KEY_1)
	else:
		await _key(KEY_A)


func _check_pixels(image: Image) -> void:
	var exact: bool = true
	for y: int in range(220, 278, 2):
		for x: int in range(486, 778, 2):
			var color: Color = image.get_pixel(x, y)
			if color != image.get_pixel(x + 1, y) or color != image.get_pixel(x, y + 1) or color != image.get_pixel(x + 1, y + 1):
				exact = false
	_expect(exact, "1080p world contains exact2x2 pixels")
	var ui_detail: bool = false
	for y: int in range(30, 90, 2):
		for x: int in range(48, 600, 2):
			if image.get_pixel(x, y) != image.get_pixel(x + 1, y):
				ui_detail = true
	_expect(ui_detail, "1080p UI keeps independent font detail")


func _click(button: Button) -> void:
	var point: Vector2 = root.get_final_transform() * (button.get_global_transform_with_canvas() * (button.size * 0.5))
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await _frames(1)
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
	Input.parse_input_event(event)
	await _frames(2)


func _key(key: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(1)
	event = InputEventKey.new()
	event.physical_keycode = key
	Input.parse_input_event(event)
	await _frames(1)


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
		push_error("[M1-D VISUAL] " + description)
