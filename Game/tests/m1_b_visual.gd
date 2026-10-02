extends SceneTree

const SCENE: PackedScene = preload("res://scenes/battle/battle_rules_sandbox.tscn")
const SIZES: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]
var _failures: Array[String] = []
var _checks: Array[Dictionary] = []
var _sandbox: BattleSandbox


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
	await _frames(12)
	for requested: Vector2i in SIZES:
		root.size = requested
		await _frames(16)
		await RenderingServer.frame_post_draw
		var world: SubViewport = _sandbox.get_node("WorldContainer/WorldViewport")
		var scale_value: float = root.get_final_transform().get_scale().x
		var expected: float = floorf(minf(requested.x / 960.0, requested.y / 540.0))
		_expect(root.size == requested and scale_value == expected, "%s window and integer scale" % requested)
		_expect(world.size == Vector2i(960, 540), "%s fixed world viewport" % requested)
		_expect(_sandbox.hud.scale.x * scale_value == expected * 0.5, "%s separate UI scale" % requested)
		var image: Image = root.get_texture().get_image()
		image.save_png("res://.dev/m1-b-%dx%d.png" % [requested.x, requested.y])
		if requested.x == 1920:
			_check_pixels(image)
		var sample_hud: AdvancedBattleHUD = _sandbox.hud as AdvancedBattleHUD
		await _click(sample_hud.enemy_buttons[1])
		_expect(sample_hud.selected_target == &"elemental", "%s real mouse selects second enemy" % requested)
		await _click(sample_hud.skill_buttons[0])
		_expect(_sandbox.controller.events.back().details.skill_id == "strike", "%s real mouse submits skill" % requested)
		_expect(sample_hud.skill_buttons[0].disabled and sample_hud.attack_button.disabled, "%s locks commands during presentation" % requested)
		_sandbox.restart_battle()
		await _frames(2)
	_sandbox.automatic_flow = true
	for _step: int in range(1500):
		if _sandbox.controller.phase == BattleController.Phase.FINISHED:
			break
		if _sandbox.controller.phase == BattleController.Phase.PLAYER_COMMAND:
			var actor: CombatantState = _sandbox.controller.current_actor()
			if actor.sl >= 70:
				await _key(KEY_D)
			elif not actor.definition.skills.is_empty() and actor.cooldown_for(actor.definition.skills[0].id) == 0:
				await _key(KEY_1)
			else:
				await _key(KEY_A)
		await _frames(1)
	_expect(_sandbox.controller.phase == BattleController.Phase.FINISHED, "Actual skill input and automatic enemy timers finish a multi-unit battle")
	await _capture("res://.dev/m1-b-result.png")
	await _key(KEY_R)
	_expect(_sandbox.controller.round_number == 1 and _sandbox.controller.get_combatant(&"hero").cooldowns.is_empty(), "Actual R clears skill and turn state")
	_sandbox.automatic_flow = false
	var source: EncounterDefinition = ResourceLoader.load("res://data/battle/m1_b_encounter.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EncounterDefinition
	var ally_template: CombatantSetup = source.allies[0]
	var enemy_template: CombatantSetup = source.enemies[0]
	source.allies.clear()
	source.enemies.clear()
	for index: int in range(4):
		var slot: CombatantSetup = ally_template.duplicate(true)
		slot.instance_id = StringName("ally%d" % index)
		source.allies.append(slot)
	for index: int in range(6):
		var slot: CombatantSetup = enemy_template.duplicate(true)
		slot.instance_id = StringName("enemy%d" % index)
		source.enemies.append(slot)
	_sandbox.controller.start_battle(source)
	await _capture("res://.dev/m1-b-full-roster.png")
	var hud: AdvancedBattleHUD = _sandbox.hud as AdvancedBattleHUD
	_expect(_sandbox.controller.combatants.size() == 10 and hud.enemy_buttons[5].visible, "Maximum 4+6 roster is presented")
	var views: int = 0
	for node: Node in _sandbox.get_node("WorldContainer/WorldViewport/Arena").get_children():
		if node is CombatantView:
			views += 1
			_expect(node.scene_file_path == "res://scenes/battle/combatant.tscn", "Every roster member uses the same Combatant scene")
	_expect(views == 10, "Maximum roster has exactly ten view instances")
	await _click(hud.back_button)
	await _frames(6)
	_expect(current_scene != null and current_scene.name == &"Main", "Advanced return button reaches M0")
	var report: FileAccess = FileAccess.open("res://.dev/m1-b-visual-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": _failures.is_empty(), "checks": _checks, "failures": _failures}, "\t"))
	report.close()
	print("[M1-B VISUAL] %d/%d checks passed" % [_checks.size() - _failures.size(), _checks.size()])
	quit(0 if _failures.is_empty() else 1)


func _check_pixels(image: Image) -> void:
	var world_ok: bool = true
	for y: int in range(234, 320, 2):
		for x: int in range(500, 750, 2):
			var color: Color = image.get_pixel(x, y)
			if color != image.get_pixel(x + 1, y) or color != image.get_pixel(x, y + 1) or color != image.get_pixel(x + 1, y + 1):
				world_ok = false
	_expect(world_ok, "1080p world contains exact 2x2 pixels")
	var ui_detail: bool = false
	for y: int in range(30, 90, 2):
		for x: int in range(48, 600, 2):
			if image.get_pixel(x, y) != image.get_pixel(x + 1, y):
				ui_detail = true
	_expect(ui_detail, "1080p UI remains independently rendered")


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
