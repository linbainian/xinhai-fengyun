extends SceneTree

const SCENE: PackedScene = preload("res://scenes/battle/breakthrough_sandbox.tscn")
const SOURCE: String = "res://data/battle/m1_c_encounter.tres"
const SIZES: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _sandbox: BattleSandbox
var _hud: AdvancedBattleHUD


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
	_hud = _sandbox.hud as AdvancedBattleHUD
	await _frames(12)
	for requested: Vector2i in SIZES:
		root.size = requested
		await _frames(16)
		var world: SubViewport = _sandbox.get_node("WorldContainer/WorldViewport")
		var scale_value: float = root.get_final_transform().get_scale().x
		var expected: float = floorf(minf(requested.x / 960.0, requested.y / 540.0))
		_expect(root.size == requested and scale_value == expected, "%s window and integer scale" % requested)
		_expect(world.size == Vector2i(960, 540), "%s fixed world viewport" % requested)
		_expect(_hud.scale.x * scale_value == expected * 0.5, "%s separate UI scale" % requested)
		_expect(not _hud.break_button.disabled and _hud.break_button.text.contains("60%"), "%s displays configured breakthrough chance" % requested)
		await _capture("res://.dev/m1-c-%dx%d.png" % [requested.x, requested.y])
		if requested.x == 1920:
			_expect(_hud.break_button.tooltip_text.contains("新HP上限的50%") and _hud.break_button.tooltip_text.contains("SL+25"), "Breakthrough tooltip explains both outcomes before submission")
		await _click(_hud.enemy_buttons[1])
		_expect(_hud.selected_target == &"elemental", "%s mouse selects elemental target" % requested)
		await _click(_hud.break_button)
		_expect(_sandbox.controller.events.back().details.command == "breakthrough", "%s mouse submits breakthrough" % requested)
		_expect(_hud.break_button.disabled and _hud.attack_button.disabled, "%s presentation locks commands" % requested)
		await _key(KEY_R)
		_expect(_sandbox.controller.get_combatant(&"hero").breakthrough_multiplier == 1.0, "%s R clears battle-only boost" % requested)
		_expect(_sandbox.controller.get_combatant(&"hero").weak_actions == 0, "%s R clears failure weakness" % requested)
	await _check_outcome(100.0, "success")
	await _check_outcome(0.0, "failure")
	await _key(KEY_R)
	_sandbox.automatic_flow = true
	await _click(_hud.enemy_buttons[1])
	await _key(KEY_D)
	_expect(_sandbox.controller.get_combatant(&"hero").sl == 55, "Actual D relieves opening load by15")
	var requested_break: bool = false
	for _step: int in range(1800):
		if _sandbox.controller.phase == BattleController.Phase.FINISHED:
			break
		if _sandbox.controller.phase == BattleController.Phase.PLAYER_COMMAND:
			var actor: CombatantState = _sandbox.controller.current_actor()
			if _sandbox.controller.can_breakthrough(actor):
				await _key(KEY_B)
				requested_break = true
			elif actor.sl >= 70:
				await _key(KEY_D)
			elif not actor.definition.skills.is_empty() and actor.cooldown_for(actor.definition.skills[0].id) == 0:
				await _key(KEY_1)
			else:
				await _key(KEY_A)
		await _frames(1)
	_expect(requested_break, "Actual B is used during a complete battle")
	_expect(_sandbox.controller.phase == BattleController.Phase.FINISHED, "Actual commands and automatic enemy timers finish C battle")
	await _capture("res://.dev/m1-c-result.png")
	await _key(KEY_E)
	var log_file: FileAccess = FileAccess.open(_sandbox.controller.last_export_path, FileAccess.READ)
	var exported: Dictionary = JSON.parse_string(log_file.get_as_text())
	log_file.close()
	var kinds: Array[String] = []
	for event: Dictionary in exported.events:
		if event.kind == "target_selected":
			kinds.append("target")
		elif event.kind == "action":
			kinds.append(event.details.command)
	_expect(kinds.has("target") and kinds.has("defend") and kinds.has("breakthrough"), "E exports all three decision types from one actual-input battle")
	_expect(exported.opening.rules.breakthrough_pity_limit == 2 and exported.stage == "M1-C", "Export includes C rules and pity cap")
	await _key(KEY_R)
	await _key(KEY_B)
	await _key(KEY_R)
	await create_timer(0.8).timeout
	_expect(_sandbox.controller.round_number == 1 and _sandbox.controller.phase == BattleController.Phase.PLAYER_COMMAND, "Retry during breakthrough cancels old presentation and enemy timers")
	_expect(_sandbox.controller.events.size() == 2, "Old breakthrough callbacks do not enter the restarted battle")
	await _key(KEY_F11)
	await _frames(12)
	_expect(root.mode == Window.MODE_FULLSCREEN, "Actual F11 enters fullscreen")
	await _key(KEY_F11)
	await _frames(12)
	_expect(root.mode == Window.MODE_WINDOWED, "Actual F11 restores windowed mode")
	await _click(_hud.back_button)
	await _frames(6)
	_expect(current_scene != null and current_scene.name == &"Main", "C return button reaches M0")
	var report: FileAccess = FileAccess.open("res://.dev/m1-c-visual-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": _failures.is_empty(), "checks": _checks, "failures": _failures}, "\t"))
	report.close()
	print("[M1-C VISUAL] %d/%d checks passed" % [_checks.size() - _failures.size(), _checks.size()])
	quit(0 if _failures.is_empty() else 1)


func _check_outcome(chance: float, outcome: String) -> void:
	# Isolated fixture changes only this test's loaded Resource, never the authored table.
	var source: EncounterDefinition = ResourceLoader.load(SOURCE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EncounterDefinition
	source.rules.breakthrough_base_chance = chance
	_sandbox.controller.start_battle(source)
	await _click(_hud.break_button)
	var hero: CombatantState = _sandbox.controller.get_combatant(&"hero")
	var action: Dictionary = _sandbox.controller.events.back().details
	_expect(action.chance == chance and action.success == (chance == 100.0), "Mouse breakthrough resolves the displayed %s fixture" % outcome)
	_expect(_hud._preview_label.get_minimum_size().y <= _hud._preview_label.size.y, "%s preview stays within its panel" % outcome)
	if chance == 100.0:
		_expect(hero.max_hp() == 286 and hero.hp == 283 and hero.sl == 0, "Success UI uses runtime maxHP and healing")
		_expect(_hud._ally_labels[0].text.contains("283/286") and _hud._preview_label.text.contains("已生效"), "Success HP and boost are visible")
	else:
		_expect(hero.weak_actions == 1 and hero.sl == 95, "Failure fixture keeps next-action weakness and adds25 SL")
		_expect(_hud._ally_labels[0].text.contains("虚弱") and _hud._preview_label.text.contains("15%"), "Failure weakness and fixture's next pity chance are visible")
	await _capture("res://.dev/m1-c-%s.png" % outcome)
	await _key(KEY_R)


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
		push_error(description)
