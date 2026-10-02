extends SceneTree

const SCENE: PackedScene = preload("res://scenes/battle/back_hill_tutorial.tscn")
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _balance: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _new_sandbox() -> TutorialSandbox:
	var sandbox: TutorialSandbox = SCENE.instantiate()
	sandbox.automatic_flow = false
	root.add_child(sandbox)
	return sandbox


func _hero(sandbox: TutorialSandbox) -> CombatantState:
	return sandbox.controller.living_team(true)[0]


func _command(sandbox: TutorialSandbox) -> void:
	var controller: BattleController = sandbox.controller
	var actor: CombatantState = controller.current_actor()
	var targets: Array[CombatantState] = controller.living_team(false)
	var target: CombatantState = targets[0]
	for candidate: CombatantState in targets:
		var candidate_affinity: float = BattleCalculator.attack_preview(actor, candidate, controller.encounter).modifiers.affinity
		var target_affinity: float = BattleCalculator.attack_preview(actor, target, controller.encounter).modifiers.affinity
		if candidate_affinity > target_affinity or (candidate_affinity == target_affinity and candidate.hp < target.hp):
			target = candidate
	if sandbox.hud.selected_target != target.id:
		sandbox.hud.selected_target = target.id
		sandbox.hud.target_selected.emit(target.id)
	if sandbox.lesson_index == 2 and not sandbox.observed_goals().has("defend"):
		sandbox._on_command_requested(&"defend", &"")
	elif actor.weak_actions > 0:
		sandbox._on_command_requested(&"defend", &"")
	elif sandbox.lesson_index == 2 and controller.can_breakthrough(actor) and actor.hp < actor.max_hp() * 0.8:
		sandbox._on_command_requested(&"breakthrough", &"")
	elif actor.hp < actor.max_hp() * 0.6 or actor.sl >= 70:
		sandbox._on_command_requested(&"defend", &"")
	elif sandbox.lesson_index > 0 and targets.size() > 1 and actor.cooldown_for(&"sweep") == 0:
		sandbox._on_skill_requested(&"sweep", target.id)
	elif sandbox.lesson_index > 0 and actor.cooldown_for(&"strike") == 0:
		sandbox._on_skill_requested(&"strike", target.id)
	else:
		sandbox._on_command_requested(&"attack", target.id)


func _finish_lesson(sandbox: TutorialSandbox) -> bool:
	for _step: int in range(900):
		if sandbox.flow != &"battle":
			return sandbox.flow == &"between" or sandbox.flow == &"complete"
		match sandbox.controller.phase:
			BattleController.Phase.PLAYER_COMMAND:
				_command(sandbox)
			BattleController.Phase.PRESENTING:
				sandbox._on_presentation_timeout()
			BattleController.Phase.ENEMY_COMMAND, BattleController.Phase.AUTO_COMMAND:
				sandbox._on_enemy_timeout()
	return false


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.dev"))
	await _check_entry()
	_check_carry_and_replay()
	_check_defeat_and_retry()
	_check_temporary_states()
	_check_reload_and_validation()
	_check_identity_reload()
	_check_sample_seeds()
	await _check_timers()
	var report: FileAccess = FileAccess.open("res://.dev/m1-d-smoke-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": _failures.is_empty(), "checks": _checks,
		"failures": _failures, "sample_seeds": _balance}, "\t"))
	report.close()
	print("[M1-D SMOKE] %d/%d checks passed" % [_checks.size() - _failures.size(), _checks.size()])
	quit(0 if _failures.is_empty() else 1)


func _check_entry() -> void:
	var sandbox: TutorialSandbox = _new_sandbox()
	var hud: TutorialHUD = sandbox.hud as TutorialHUD
	_expect(sandbox.flow == &"intro" and hud._overlay.visible, "Tutorial starts at a readable introduction")
	_expect(hud._modal_body.text.contains("苏挽颜") and hud._modal_body.text.contains("奶茶"), "Source guide introduces the back-hill commission")
	_expect(sandbox.tutorial.guide_identity.contains("B级冰系") and sandbox.tutorial.guide_identity.contains("大二"), "Guide source identity is preserved")
	_expect(sandbox.controller.combatants.size() == 3 and sandbox.controller.living_team(true).size() == 1, "Lin Da fights alone; Su and Wen are not forced into the roster")
	var before: Dictionary = sandbox.controller.log_snapshot()
	for command: StringName in [&"attack", &"defend", &"breakthrough"]:
		sandbox._on_command_requested(command, &"rabbit_force")
	sandbox._on_skill_requested(&"strike", &"rabbit_force")
	hud.cycle_target()
	_expect(sandbox.controller.log_snapshot() == before, "Introduction blocks action and target keys without RNG or cost")
	_expect(hud.attack_button.disabled and hud.primary_button.text.contains("开始"), "Intro commands are disabled but start is available")
	hud.secondary_button.pressed.emit()
	_expect(sandbox.flow == &"battle" and not sandbox.hints_enabled, "Secondary starts immediately without hints")
	_expect(not hud.attack_button.disabled and not hud.skill_buttons[0].disabled, "Start restores command availability, including optional skills")
	await _key(KEY_H)
	_expect(sandbox.hints_enabled and hud._coach_text.text.contains("目标"), "Actual H restores optional guidance")
	await _key(KEY_TAB)
	_expect(sandbox.observed_goals().has("target"), "Actual Tab records target observation")
	await _key(KEY_A)
	_expect(sandbox.controller.events.back().details.command == "attack", "Actual A executes the lesson's normal attack")
	var count: int = sandbox.controller.events.size()
	await _key(KEY_1)
	_expect(sandbox.controller.events.size() == count, "Presentation blocks a second keyboard command")
	await _key(KEY_R)
	_expect(sandbox.flow == &"battle" and _hero(sandbox).hp == 220 and _hero(sandbox).sl == 45, "Actual R restores the first lesson checkpoint")
	await _key(KEY_T)
	_expect(sandbox.flow == &"intro" and sandbox.attempts.is_empty(), "Actual T resets the whole tutorial")
	sandbox.queue_free()
	await process_frame


func _check_carry_and_replay() -> void:
	var sandbox: TutorialSandbox = _new_sandbox()
	sandbox.begin_tutorial()
	(sandbox.hud as TutorialHUD).enemy_buttons[1].pressed.emit()
	(sandbox.hud as TutorialHUD).enemy_buttons[0].pressed.emit()
	for lesson: int in range(3):
		_expect(sandbox.lesson_index == lesson and _finish_lesson(sandbox), "Default guided strategy clears lesson%d" % (lesson + 1))
		_expect((sandbox.hud as TutorialHUD)._overlay.visible and sandbox.hud.attack_button.disabled, "Lesson%d completion locks commands and offers navigation" % (lesson + 1))
		if lesson == 2:
			break
		var ending: CombatantState = _hero(sandbox)
		var ending_hp: int = ending.hp
		var ending_sl: int = ending.sl
		var count: int = sandbox.attempts.size()
		sandbox._on_lesson_finished(&"victory")
		_expect(sandbox.attempts.size() == count and sandbox.completed_lessons.size() == lesson + 1, "Repeated finish callback has no duplicate result")
		sandbox.advance_lesson()
		_expect(_hero(sandbox).hp == ending_hp and _hero(sandbox).sl == ending_sl, "Next lesson carries exact HP/SL without free healing")
		var checkpoint: Dictionary = sandbox._opening.duplicate(true)
		sandbox.advance_lesson()
		_expect(sandbox.lesson_index == lesson + 1 and sandbox._opening == checkpoint, "Repeated advance input cannot skip a lesson")
		_expect(_hero(sandbox).critical == 0 and _hero(sandbox).cooldowns.is_empty(), "Next lesson clears gauge and CD")
	_expect(sandbox.flow == &"complete" and sandbox.completed_lessons.size() == 3, "Third victory completes the tutorial")
	var final: Dictionary = sandbox.tutorial_snapshot()
	_expect(sandbox.export_tutorial_log("res://.dev/m1-d-example-tutorial.json") == OK, "Whole tutorial exports as one reviewable log")
	var commands: PackedStringArray = []
	for attempt: Dictionary in sandbox.attempts:
		for event: Dictionary in attempt.battle.events:
			if event.kind == "target_selected":
				commands.append("target")
			elif event.kind == "action" and String(event.details.actor_id) == "lin_da":
				commands.append(event.details.command)
	_expect(commands.has("target") and commands.has("skill") and commands.has("defend") and commands.has("breakthrough"), "Full tutorial contains target, skill, load relief and breakthrough decisions")
	_expect(_hero(sandbox).hp > 0, "Default run ends with the hero alive")
	sandbox.replay_tutorial()
	sandbox.begin_tutorial()
	(sandbox.hud as TutorialHUD).enemy_buttons[1].pressed.emit()
	(sandbox.hud as TutorialHUD).enemy_buttons[0].pressed.emit()
	for lesson: int in range(3):
		_finish_lesson(sandbox)
		if lesson < 2:
			sandbox.advance_lesson()
	_expect(sandbox.tutorial_snapshot() == final, "Same version, seeds, inputs and hints reproduce the entire run")
	sandbox.replay_tutorial(true)
	_expect(sandbox.flow == &"battle" and not sandbox.hints_enabled, "Completed run can restart in quick mode")
	_expect(sandbox.lesson_index == 0 and sandbox.checkpoints.size() == 1 and sandbox.attempts.is_empty(), "Quick replay clears all old history and checkpoints")
	sandbox.free()


func _check_defeat_and_retry() -> void:
	var sandbox: TutorialSandbox = _new_sandbox()
	sandbox.begin_tutorial()
	_finish_lesson(sandbox)
	sandbox.advance_lesson()
	var checkpoint: Dictionary = sandbox._opening.duplicate(true)
	_hero(sandbox).hp = 1
	for enemy: CombatantState in sandbox.controller.living_team(false):
		enemy.definition.attack = 1000
		enemy.definition.accuracy = 100
		enemy.definition.perception = 100
	sandbox._on_command_requested(&"defend", &"")
	for _step: int in range(12):
		if sandbox.flow == &"failed":
			break
		if sandbox.controller.phase == BattleController.Phase.PRESENTING:
			sandbox._on_presentation_timeout()
		else:
			sandbox._on_enemy_timeout()
	_expect(sandbox.flow == &"failed" and sandbox.lesson_index == 1, "A real enemy hit produces lesson2 defeat without resetting progress")
	_expect(sandbox.completed_lessons.size() == 1 and sandbox.attempts.back().outcome == "defeat", "Failure archives the attempt and preserves earlier victory")
	sandbox.restart_battle()
	var hero: CombatantState = _hero(sandbox)
	_expect(hero.hp == checkpoint[hero.id].hp and hero.sl == checkpoint[hero.id].sl, "Retry recovers exact current-stage opening HP/SL")
	_expect(sandbox.lesson_index == 1 and sandbox.controller.get_combatant(&"rabbit_1").definition.attack == 8, "Retry reloads data and removes fixture mutation")
	_expect(_finish_lesson(sandbox), "Retried second stage is playable to victory")
	var wins: int = sandbox.completed_lessons.size()
	sandbox.restart_battle()
	_expect(sandbox.completed_lessons.size() == wins - 1 and sandbox.flow == &"battle", "Replaying a cleared stage removes its cleared flag until victory")
	var prior_count: int = sandbox.attempts.size()
	sandbox._on_skill_requested(&"strike", &"rabbit_1")
	sandbox.restart_battle()
	_expect(sandbox.attempts.size() == prior_count + 1 and sandbox.attempts.back().outcome == "retry", "Mid-action retry archives one interrupted attempt")
	_expect(hero != _hero(sandbox) and _hero(sandbox).cooldowns.is_empty(), "Retry creates new independent state")
	sandbox.free()


func _check_temporary_states() -> void:
	var sandbox: TutorialSandbox = _new_sandbox()
	sandbox.begin_tutorial()
	var hero: CombatantState = _hero(sandbox)
	var original: Dictionary = hero.definition.snapshot()
	sandbox.controller.encounter.rules.breakthrough_base_chance = 100
	hero.critical = 100
	sandbox._on_command_requested(&"breakthrough", &"")
	sandbox._on_presentation_timeout()
	_expect(hero.breakthrough_multiplier == 1.3 and hero.hp > hero.definition.max_hp, "Fixture creates real temporary maxHP and heal")
	_finish_lesson(sandbox)
	var carried_sl: int = hero.sl
	var capped_hp: int = mini(hero.hp, hero.definition.max_hp)
	sandbox.advance_lesson()
	var fresh: CombatantState = _hero(sandbox)
	_expect(fresh.hp == capped_hp and fresh.max_hp() == 220 and fresh.sl == carried_sl, "Transition removes boost and caps carried HP to the base maximum")
	_expect(fresh.breakthrough_multiplier == 1 and fresh.critical == 0 and fresh.breakthrough_failures == 0 and fresh.weak_actions == 0, "Transition clears temporary boost, gauge, pity and weakness")
	_expect(hero.definition.snapshot() == original, "Battle and transition leave source character data unchanged")
	sandbox.free()


func _check_reload_and_validation() -> void:
	var sandbox: TutorialSandbox = _new_sandbox()
	var source: EncounterDefinition = ResourceLoader.load("res://data/battle/tutorial/m1_d_encounter_1.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EncounterDefinition
	var rules_path: String = "res://.dev/m1-d-reload-rules.tres"
	var encounter_path: String = "res://.dev/m1-d-reload-encounter.tres"
	source.rules.defense_sl_relief = 7
	ResourceSaver.save(source.rules, rules_path, ResourceSaver.FLAG_CHANGE_PATH)
	source.rules = ResourceLoader.load(rules_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as BattleRules
	ResourceSaver.save(source, encounter_path)
	sandbox.tutorial.lessons[0].encounter_path = encounter_path
	sandbox.begin_tutorial()
	sandbox.restart_battle()
	sandbox._on_command_requested(&"defend", &"")
	_expect(_hero(sandbox).sl == 38, "Changing an external rule to7 is applied on stage retry")
	source.rules.defense_sl_relief = 3
	ResourceSaver.save(source.rules, rules_path)
	sandbox.restart_battle()
	sandbox._on_command_requested(&"defend", &"")
	_expect(_hero(sandbox).sl == 42, "Second external change to3 reloads without script changes")
	var definition: TutorialDefinition = sandbox.tutorial.duplicate(true)
	definition.lessons.resize(2)
	_expect(not definition.validation_errors().is_empty(), "Invalid lesson count is rejected")
	var wrong: TutorialLesson = sandbox.tutorial.lessons[0].duplicate()
	wrong.encounter_path = "res://.dev/nonexistent-m1-d.tres"
	_expect(not wrong.validation_errors().is_empty(), "Missing encounter is rejected before navigation")
	sandbox.free()


func _check_identity_reload() -> void:
	for change: String in ["instance", "definition", "roster"]:
		var sandbox: TutorialSandbox = _new_sandbox()
		sandbox.begin_tutorial()
		var source: EncounterDefinition = ResourceLoader.load("res://data/battle/tutorial/m1_d_encounter_1.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EncounterDefinition
		var path: String = "res://.dev/m1-d-identity-%s.tres" % change
		match change:
			"instance":
				source.allies[0].instance_id = &"changed_player"
			"definition":
				source.allies[0].definition.id = &"changed_definition"
				var character_path: String = "res://.dev/m1-d-identity-character.tres"
				ResourceSaver.save(source.allies[0].definition, character_path)
				source.allies[0].definition = ResourceLoader.load(character_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as CombatantDefinition
			"roster":
				var extra: CombatantSetup = source.allies[0].duplicate()
				extra.instance_id = &"extra_player"
				source.allies.append(extra)
		ResourceSaver.save(source, path)
		sandbox.tutorial.lessons[0].encounter_path = path
		var opening: Dictionary = sandbox._opening.duplicate(true)
		sandbox.restart_battle()
		_expect(sandbox.flow == &"error" and sandbox._opening == opening, "Retry rejects changed %s without replacing the checkpoint" % change)
		_expect((sandbox.hud as TutorialHUD)._overlay.visible and sandbox.hud.attack_button.disabled and not sandbox._fatal_error.is_empty(), "Changed %s shows a safe error with battle commands locked" % change)
		sandbox.replay_tutorial()
		_expect(sandbox.flow == &"intro" and sandbox._player_id == &"lin_da", "Whole replay reloads valid source after %s error" % change)
		sandbox.free()
	for change: String in ["instance", "definition"]:
		var sandbox: TutorialSandbox = _new_sandbox()
		sandbox.begin_tutorial()
		_finish_lesson(sandbox)
		var carried: Dictionary = sandbox._carry.duplicate(true)
		var source: EncounterDefinition = ResourceLoader.load("res://data/battle/tutorial/m1_d_encounter_2.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EncounterDefinition
		if change == "instance":
			source.allies[0].instance_id = &"changed_player"
		else:
			var character_path: String = "res://.dev/m1-d-identity-character.tres"
			source.allies[0].definition = ResourceLoader.load(character_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as CombatantDefinition
		var path: String = "res://.dev/m1-d-next-%s.tres" % change
		ResourceSaver.save(source, path)
		sandbox.tutorial.lessons[1].encounter_path = path
		sandbox.advance_lesson()
		_expect(sandbox.flow == &"error" and sandbox._carry == carried and sandbox.checkpoints.size() == 1, "Next stage rejects changed %s without silently restoring default HP/SL" % change)
		sandbox.free()


func _check_sample_seeds() -> void:
	var all_passed: bool = true
	for seed_value: int in range(1, 21):
		var sandbox: TutorialSandbox = _new_sandbox()
		sandbox.begin_tutorial(false)
		for lesson: int in range(3):
			sandbox.controller.encounter.seed_value = seed_value * 10 + lesson
			# Reinitialize the unchanged opening to apply each test seed before any action.
			sandbox.controller.start_battle(sandbox.controller.encounter)
			if not _finish_lesson(sandbox):
				all_passed = false
				break
			if lesson < 2:
				sandbox.advance_lesson()
		var hp: int = 0 if sandbox.controller.living_team(true).is_empty() else _hero(sandbox).hp
		_balance.append({"seed_group": seed_value, "completed": sandbox.flow == &"complete", "hp": hp})
		sandbox.free()
	_expect(all_passed, "Guided resource-management strategy completes all20 seed groups")
	_expect(_balance.size() == 20, "Sample balance results remain available for later play feedback")


func _check_timers() -> void:
	var sandbox: TutorialSandbox = SCENE.instantiate()
	root.add_child(sandbox)
	sandbox.begin_tutorial()
	sandbox._on_command_requested(&"attack", &"rabbit_force")
	_expect(not sandbox.presentation_timer.is_stopped(), "Normal tutorial starts real presentation timer")
	sandbox.restart_battle()
	await create_timer(0.8).timeout
	_expect(sandbox.flow == &"battle" and sandbox.controller.events.size() == 2, "Retry cancels real presentation and enemy timers")
	sandbox._on_command_requested(&"attack", &"rabbit_force")
	sandbox.replay_tutorial()
	await create_timer(0.8).timeout
	_expect(sandbox.flow == &"intro" and sandbox.controller.events.size() == 2, "Whole replay remains at the intro after old callbacks would have fired")
	sandbox.queue_free()
	await process_frame
	var again: TutorialSandbox = _new_sandbox()
	again.begin_tutorial(false)
	again._on_command_requested(&"attack", &"rabbit_force")
	_expect(again.controller.events.back().details.action_number == 1, "Reentering has no duplicate input or signal connections")
	again.free()


func _key(key: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = key
	Input.parse_input_event(event)
	await process_frame


func _expect(condition: bool, description: String) -> void:
	_checks.append({"passed": condition, "description": description})
	if not condition:
		_failures.append(description)
		push_error("[M1-D SMOKE] " + description)
