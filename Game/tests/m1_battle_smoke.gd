extends SceneTree

const SANDBOX: PackedScene = preload("res://scenes/battle/battle_sandbox.tscn")
const ENCOUNTER_PATH: String = "res://data/battle/m1_a_encounter.tres"

var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _sample_log: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_calculator()
	_check_controller()
	_check_order_and_outcomes()
	_check_replay_and_export()
	await _check_scene_and_input()
	await _check_reload()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.dev"))
	var file: FileAccess = FileAccess.open("res://.dev/m1-a-smoke-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"stage": "M1-A", "engine": Engine.get_version_info().string,
		"checks": _checks, "passed": _failures.is_empty(), "failures": _failures,
		"sample_result": _sample_log.result}, "\t"))
	file.close()
	print("[M1-A SMOKE] %d/%d checks passed" % [_checks.size() - _failures.size(), _checks.size()])
	quit(0 if _failures.is_empty() else 1)


func _encounter() -> EncounterDefinition:
	return ResourceLoader.load(ENCOUNTER_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EncounterDefinition


func _controller(source: EncounterDefinition) -> BattleController:
	var controller: BattleController = BattleController.new()
	root.add_child(controller)
	_expect(controller.start_battle(source), "Valid encounter starts")
	return controller


func _check_calculator() -> void:
	var source: EncounterDefinition = _encounter()
	_expect(source.validation_errors().is_empty(), "External prototype tables are valid")
	source.ally.accuracy = 100.0
	source.enemy.evasion = 0.0
	source.ally.perception = source.enemy.perception
	source.rules.damage_die_min = 5
	source.rules.damage_die_max = 5
	var ally: CombatantState = CombatantState.new(source.ally, true, 90, 30, source.rules)
	var enemy: CombatantState = CombatantState.new(source.enemy, false, -1, 0, source.rules)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var attack: Dictionary = BattleCalculator.calculate_attack(ally, enemy, source, rng)
	_expect(attack.hit and attack.damage == 24, "20 ATK + two 5s - 12 DEF * 0.5 = 24 damage")
	_expect(attack.dice == [5, 5], "Damage logs include both die results")
	_expect(enemy.hp == 110 and ally.hp == 90, "Calculator returns results without mutating participants")
	source.ally.attack = 20.5
	attack = BattleCalculator.calculate_attack(ally, enemy, source, rng)
	_expect(attack.damage == 25, "24.5 rounds to 25 at final damage")
	source.enemy.defense = 9999.0
	attack = BattleCalculator.calculate_attack(ally, enemy, source, rng)
	_expect(attack.damage == 1, "Excess defense yields minimum 1, never healing")
	source.ally.accuracy = 0.0
	attack = BattleCalculator.calculate_attack(ally, enemy, source, rng)
	_expect(not attack.hit and attack.damage == 0 and attack.dice.is_empty(), "0% hit misses and does not roll damage")
	source.ally.accuracy = 100.0
	source.ally.perception = 100
	attack = BattleCalculator.calculate_attack(ally, enemy, source, rng)
	_expect(attack.hit_chance == 100.0 and attack.hit, "Hit chance is capped at 100%")
	source.ally.perception = -100
	attack = BattleCalculator.calculate_attack(ally, enemy, source, rng)
	_expect(attack.hit_chance == 0.0 and not attack.hit, "Hit chance is floored at 0%")
	var defense: Dictionary = BattleCalculator.calculate_defense(ally, source.rules)
	_expect(defense.healing == 12 and defense.sl_relief == 15, "Defense restores 10% max HP and relieves 15 SL")
	ally.hp = 119
	ally.sl = 3
	defense = BattleCalculator.calculate_defense(ally, source.rules)
	_expect(defense.healing == 1 and defense.sl_relief == 3, "Defense caps actual healing and SL relief")
	ally.hp = 120
	ally.sl = 0
	defense = BattleCalculator.calculate_defense(ally, source.rules)
	_expect(defense.healing == 0 and defense.sl_relief == 0, "Full HP and zero SL cannot exceed boundaries")
	var other: CombatantState = CombatantState.new(source.ally, true, -1, 999, source.rules)
	_expect(other.hp == 120 and other.sl == 100, "Opening state clamps upper resource limits")
	other.hp = 0
	_expect(ally.hp == 120 and source.ally.max_hp == 120, "Instances using one definition keep independent HP")
	_expect(not other.is_alive(), "Zero HP is downed")


func _check_controller() -> void:
	var source: EncounterDefinition = _encounter()
	var definition_before: Dictionary = source.ally.snapshot()
	var controller: BattleController = _controller(source)
	_expect(controller.phase == BattleController.Phase.PLAYER_COMMAND, "Higher SPD ally gets the first command")
	var event_count: int = controller.events.size()
	_expect(not controller.submit_player_command(&"skill", source.enemy.id), "Unimplemented command is rejected")
	_expect(not controller.submit_player_command(&"attack", &"missing"), "Missing target is rejected")
	_expect(not controller.submit_player_command(&"attack", source.ally.id), "Friendly target is rejected")
	_expect(not controller.submit_enemy_command(), "Enemy cannot act on player's turn")
	_expect(controller.events.size() == event_count, "Rejected commands do not advance log or RNG")
	_expect(controller.submit_player_command(&"defend"), "Defense is accepted during player's command")
	_expect(controller.combatants[0].hp == 102 and controller.combatants[0].sl == 15, "Controller applies defense once")
	_expect(controller.phase == BattleController.Phase.PRESENTING, "Input is locked before presentation")
	_expect(not controller.submit_player_command(&"defend"), "Second click during presentation is rejected")
	controller.complete_presentation()
	_expect(controller.phase == BattleController.Phase.ENEMY_COMMAND, "Defense consumes the player's one action")
	_expect(not controller.submit_player_command(&"attack", source.enemy.id), "Player cannot act during enemy turn")
	controller.submit_enemy_command()
	var after_enemy: int = controller.combatants[0].hp
	_expect(not controller.submit_enemy_command(), "Enemy submission cannot be duplicated")
	_expect(controller.combatants[0].hp == after_enemy, "Duplicate enemy input does not deal more damage")
	controller.complete_presentation()
	_expect(controller.round_number == 2 and controller.phase == BattleController.Phase.PLAYER_COMMAND, "After both actions a new round starts")
	controller.start_battle(source)
	_expect(controller.combatants[0].hp == 90 and controller.combatants[0].sl == 30, "Retry restores opening HP/SL")
	_expect(controller.round_number == 1 and controller.result == &"", "Retry clears turn and result state")
	_expect(source.ally.snapshot() == definition_before, "Combat does not alter original unit definition")
	var invalid: EncounterDefinition = _encounter()
	invalid.rules = null
	_expect(not controller.start_battle(invalid) and controller.phase == BattleController.Phase.IDLE, "Invalid tables fail before any turn starts")
	_expect(not controller.error_message.is_empty(), "Invalid tables have a readable diagnostic")
	invalid = _encounter()
	invalid.rank_modifier = 1.4
	_expect(not controller.start_battle(invalid), "Non-neutral modifiers cannot silently enable later rules")
	controller.free()


func _check_order_and_outcomes() -> void:
	var source: EncounterDefinition = _encounter()
	source.enemy.speed = source.ally.speed + 1
	var controller: BattleController = _controller(source)
	_expect(controller.phase == BattleController.Phase.ENEMY_COMMAND, "Faster enemy acts first")
	controller.free()
	source = _encounter()
	source.enemy.speed = source.ally.speed
	var probe: RandomNumberGenerator = RandomNumberGenerator.new()
	for candidate: int in range(1, 200):
		probe.seed = candidate
		if probe.randi_range(1, 6) == probe.randi_range(1, 6):
			source.seed_value = candidate
			break
	controller = _controller(source)
	var rolls: Array[Dictionary] = []
	for event: Dictionary in controller.events:
		if event.kind == "initiative_roll":
			rolls.append(event.details)
	_expect(rolls.size() >= 2 and rolls[0].ally_roll == rolls[0].enemy_roll, "Equal d6 results are rerolled and recorded")
	var final_roll: Dictionary = rolls.back()
	_expect((controller.current_actor().is_player) == (final_roll.ally_roll > final_roll.enemy_roll), "Tie winner matches the recorded d6")
	controller.free()
	source = _encounter()
	source.enemy_initial_hp = 1
	source.ally.accuracy = 100.0
	source.enemy.evasion = 0.0
	controller = _controller(source)
	controller.submit_player_command(&"attack", source.enemy.id)
	_expect(controller.combatants[1].hp == 0, "Lethal attack caps target HP at zero")
	controller.complete_presentation()
	_expect(controller.result == &"victory" and controller.phase == BattleController.Phase.FINISHED, "Lethal player action ends in victory")
	_expect(not controller.submit_enemy_command(), "Downed enemy never takes its queued turn")
	_expect(not controller.submit_player_command(&"attack", source.enemy.id), "Finished battle rejects more commands")
	controller.free()
	source = _encounter()
	source.enemy.speed = 100
	source.enemy.attack = 10000.0
	source.enemy.accuracy = 100.0
	source.enemy.perception = source.ally.perception
	source.ally.evasion = 0.0
	controller = _controller(source)
	controller.submit_enemy_command()
	controller.complete_presentation()
	_expect(controller.result == &"defeat" and controller.combatants[0].hp == 0, "Enemy lethal action ends in defeat")
	controller.free()


func _play_to_end(controller: BattleController, opening_defense: bool = false) -> void:
	var defended: bool = false
	for _step: int in range(200):
		match controller.phase:
			BattleController.Phase.PLAYER_COMMAND:
				if opening_defense and not defended:
					controller.submit_player_command(&"defend")
					defended = true
				else:
					controller.submit_player_command(&"attack", controller.encounter.enemy.id)
			BattleController.Phase.ENEMY_COMMAND:
				controller.submit_enemy_command()
			BattleController.Phase.PRESENTING:
				controller.complete_presentation()
			BattleController.Phase.FINISHED:
				return
	_expect(false, "Battle must finish within 200 state transitions")


func _check_replay_and_export() -> void:
	var source: EncounterDefinition = _encounter()
	var controller: BattleController = _controller(source)
	_play_to_end(controller)
	_sample_log = controller.log_snapshot()
	_expect(controller.result == &"victory", "Default encounter can be won using normal attacks")
	controller.start_battle(source)
	_play_to_end(controller)
	_expect(controller.log_snapshot() == _sample_log, "Same seed and commands reproduce the complete log")
	controller.start_battle(source)
	_play_to_end(controller, true)
	_expect(controller.log_snapshot() != _sample_log, "A defense choice changes the outcome trace")
	_expect(controller.log_snapshot().opening.states[0].sl == 30, "Log keeps initial state independently of later mutations")
	_expect(controller.export_log("res://.dev/m1-a-example-battle.json") == OK, "Full battle log exports as JSON")
	var file: FileAccess = FileAccess.open("res://.dev/m1-a-example-battle.json", FileAccess.READ)
	var loaded: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	_expect(loaded.events.size() == controller.events.size() and loaded.opening.seed == source.seed_value, "Export includes seed and every event")
	_expect(loaded.opening.definitions.size() == 2 and loaded.opening.rules.defense_sl_relief == 15, "Export includes the exact starting tables")
	_expect(controller.export_log() == OK and FileAccess.file_exists(controller.last_export_path), "Default export writes to the local user data folder")
	controller.free()


func _check_scene_and_input() -> void:
	var sandbox: BattleSandbox = SANDBOX.instantiate()
	sandbox.automatic_flow = false
	root.add_child(sandbox)
	await _frames(3)
	var world: SubViewport = sandbox.get_node("WorldContainer/WorldViewport")
	_expect(world.size == Vector2i(960, 540), "Battle world stays at 960x540")
	_expect(world.snap_2d_vertices_to_pixel and world.snap_2d_transforms_to_pixel, "Battle world snaps geometry to pixels")
	_expect(sandbox.hud.size == Vector2(1920, 1080) and sandbox.hud.scale == Vector2(0.5, 0.5), "Battle UI is independently 1920x1080")
	_expect(sandbox.ally_view.scene_file_path == sandbox.enemy_view.scene_file_path, "Both sides instantiate the same Combatant scene")
	_expect(not sandbox.hud.attack_button.disabled, "Attack is enabled on player turn")
	await _tap_key(KEY_D)
	_expect(sandbox.controller.combatants[0].sl == 15, "Actual D key selects defense")
	_expect(sandbox.hud.attack_button.disabled and sandbox.hud.defense_button.disabled, "HUD buttons are disabled during action presentation")
	await _tap_key(KEY_R)
	_expect(sandbox.controller.combatants[0].sl == 30 and sandbox.controller.round_number == 1, "Actual R key restores opening state")
	sandbox.automatic_flow = true
	sandbox.controller.submit_player_command(&"attack", sandbox.hud.selected_target)
	_expect(not sandbox.presentation_timer.is_stopped(), "Accepted command starts the presentation timer")
	sandbox.restart_battle()
	await _frames(75)
	_expect(sandbox.controller.events.size() == 2 and sandbox.controller.phase == BattleController.Phase.PLAYER_COMMAND, "Retry during presentation cancels stale callbacks")
	_expect(sandbox.ally_view.position == Vector2(304, 286), "Retry resets the actor animation position")
	sandbox.controller.submit_player_command(&"attack", sandbox.hud.selected_target)
	sandbox.presentation_timer.stop()
	sandbox.controller.complete_presentation()
	_expect(not sandbox.enemy_timer.is_stopped(), "Enemy turn starts its think timer")
	sandbox.restart_battle()
	await _frames(75)
	_expect(sandbox.controller.events.size() == 2, "Retry during enemy wait cancels the old enemy action")
	sandbox.queue_free()
	await process_frame
	sandbox = SANDBOX.instantiate()
	sandbox.automatic_flow = false
	root.add_child(sandbox)
	await _frames(2)
	_expect(sandbox.controller.events.size() == 2, "Re-entering the scene has exactly one set of signal connections")
	sandbox.queue_free()
	await process_frame


func _check_reload() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.dev"))
	var source: EncounterDefinition = _encounter()
	ResourceSaver.save(source.rules, "res://.dev/m1-a-reload-rules.tres")
	source.rules.take_over_path("res://.dev/m1-a-reload-rules.tres")
	ResourceSaver.save(source.ally, "res://.dev/m1-a-reload-ally.tres")
	source.ally.take_over_path("res://.dev/m1-a-reload-ally.tres")
	ResourceSaver.save(source.enemy, "res://.dev/m1-a-reload-enemy.tres")
	source.enemy.take_over_path("res://.dev/m1-a-reload-enemy.tres")
	ResourceSaver.save(source, "res://.dev/m1-a-reload-encounter.tres")
	var sandbox: BattleSandbox = SANDBOX.instantiate()
	sandbox.automatic_flow = false
	sandbox.encounter_path = "res://.dev/m1-a-reload-encounter.tres"
	root.add_child(sandbox)
	await _frames(2)
	var edited: BattleRules = ResourceLoader.load("res://.dev/m1-a-reload-rules.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as BattleRules
	edited.defense_sl_relief = 7
	ResourceSaver.save(edited, "res://.dev/m1-a-reload-rules.tres")
	sandbox.restart_battle()
	sandbox.controller.submit_player_command(&"defend")
	_expect(sandbox.controller.combatants[0].sl == 23, "Editing a referenced rule file changes the next battle without code edits")
	sandbox.queue_free()
	await process_frame


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


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _expect(condition: bool, description: String) -> void:
	_checks.append({"passed": condition, "description": description})
	if not condition:
		_failures.append(description)
		push_error("[M1-A SMOKE] " + description)
