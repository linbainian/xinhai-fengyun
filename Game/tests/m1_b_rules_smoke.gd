extends SceneTree

const SOURCE: String = "res://data/battle/m1_b_encounter.tres"
const SCENE: PackedScene = preload("res://scenes/battle/battle_rules_sandbox.tscn")
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _source() -> EncounterDefinition:
	return ResourceLoader.load(SOURCE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EncounterDefinition


func _start(source: EncounterDefinition) -> BattleController:
	var controller: BattleController = BattleController.new()
	root.add_child(controller)
	_expect(controller.start_battle(source), "Valid multi-unit fixture starts")
	return controller


func _stable_source() -> EncounterDefinition:
	var source: EncounterDefinition = _source()
	for slot: CombatantSetup in source.get_setups():
		slot.definition.max_hp = 1000
		slot.initial_hp = 1000
		slot.definition.attack = 0
		slot.definition.perception = 100
		slot.definition.accuracy = 100
	source.rules.skill_deviation_chance = 0
	return source


func _run() -> void:
	_check_modifiers()
	_check_skills()
	_check_targets()
	_check_uncontrolled()
	_check_replay()
	await _check_scene()
	var file: FileAccess = FileAccess.open("res://.dev/m1-b-smoke-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": _failures.is_empty(), "checks": _checks, "failures": _failures}, "\t"))
	file.close()
	print("[M1-B SMOKE] %d/%d checks passed" % [_checks.size() - _failures.size(), _checks.size()])
	quit(0 if _failures.is_empty() else 1)


func _check_modifiers() -> void:
	var source: EncounterDefinition = _source()
	var rules: BattleRules = source.rules
	var ring: Array[String] = ["念动力", "强化", "精神", "元素"]
	for index: int in range(4):
		var affinity: String = ring[index]
		_expect(BattleCalculator.affinity_modifier(affinity, ring[(index + 1) % 4], rules) == 1.2, "%s has its documented advantage" % affinity)
		_expect(BattleCalculator.affinity_modifier(affinity, ring[(index + 3) % 4], rules) == 0.8, "%s has its documented disadvantage" % affinity)
		_expect(BattleCalculator.affinity_modifier(affinity, affinity, rules) == 1.0, "Same-affinity combat is neutral")
		_expect(BattleCalculator.affinity_modifier(affinity, "特殊", rules) == 1.0, "Special affinity is neutral")
	var higher: Array[float] = [1.0, 1.18, 1.4, 1.6, 1.6]
	var lower: Array[float] = [1.0, 0.85, 0.7, 0.55, 0.55]
	for delta: int in range(5):
		_expect(is_equal_approx(BattleCalculator.rank_modifier(rules.rank_order[delta + 2], "D", rules), higher[delta]), "Higher rank difference %d" % delta)
		_expect(is_equal_approx(BattleCalculator.rank_modifier("D", rules.rank_order[delta + 2], rules), lower[delta]), "Lower rank difference %d" % delta)
	var hero: CombatantState = CombatantState.new(source.allies[0].definition, true, -1, 0, rules)
	var enemy: CombatantState = CombatantState.new(source.enemies[0].definition, false, -1, 0, rules)
	hero.definition.affinity = "强化"
	hero.definition.perception = enemy.definition.perception
	hero.definition.attack = 20
	enemy.definition.defense = 12
	rules.damage_die_min = 5
	rules.damage_die_max = 5
	var loads: Array[int] = [49, 50, 69, 70, 84, 85, 99]
	var hits: Array[float] = [100, 90, 90, 65, 65, 65, 65]
	var damage: Array[int] = [24, 22, 22, 19, 19, 19, 19]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var seed_value: int = 1
	for candidate: int in range(1, 100):
		rng.seed = candidate
		if rng.randf_range(0.0, 100.0) < 60.0:
			seed_value = candidate
			break
	for index: int in range(loads.size()):
		hero.sl = loads[index]
		var preview: Dictionary = BattleCalculator.attack_preview(hero, enemy, source)
		_expect(is_equal_approx(preview.hit_chance, hits[index]), "SL %d hit boundary is visible in preview" % loads[index])
		rng.seed = seed_value
		var outcome: Dictionary = BattleCalculator.calculate_attack(hero, enemy, source, rng)
		_expect(outcome.damage == damage[index], "SL %d damage boundary" % loads[index])
	source.environment_by_affinity["强化"] = 0.7
	_expect(BattleCalculator.attack_preview(hero, enemy, source).modifiers.environment == 0.7, "Environment modifier comes from the active affinity")
	source.environment_by_affinity["强化"] = 1.3
	_expect(not source.validation_errors().is_empty(), "Out-of-range environment is rejected")
	var invalid: EncounterDefinition = _source()
	invalid.enemies[0].instance_id = invalid.allies[0].instance_id
	_expect(not invalid.validation_errors().is_empty(), "Duplicate instance ids are rejected")


func _advance_to_hero(controller: BattleController) -> void:
	for _step: int in range(100):
		if controller.phase == BattleController.Phase.PLAYER_COMMAND and controller.current_actor().id == &"hero":
			return
		_step_battle(controller)
	_expect(false, "Hero receives its next command")


func _step_battle(controller: BattleController) -> void:
	match controller.phase:
		BattleController.Phase.PRESENTING:
			controller.complete_presentation()
		BattleController.Phase.ENEMY_COMMAND, BattleController.Phase.AUTO_COMMAND:
			controller.submit_enemy_command()
		BattleController.Phase.PLAYER_COMMAND:
			controller.submit_player_command(&"defend")


func _check_skills() -> void:
	var source: EncounterDefinition = _stable_source()
	source.allies[0].initial_sl = 20
	source.enemies[1].definition = source.enemies[0].definition
	var controller: BattleController = _start(source)
	var hero: CombatantState = controller.get_combatant(&"hero")
	_expect(controller.combatants.size() == 4, "2v2 builds four independent combatants")
	var count: int = controller.events.size()
	_expect(not controller.submit_player_command(&"skill", &"reinforced", &"missing"), "Unknown skill is rejected")
	_expect(not controller.submit_player_command(&"skill", &"missing", &"strike"), "Unknown target does not consume skill")
	_expect(hero.sl == 20 and controller.events.size() == count, "Illegal submission has no cost or RNG event")
	_expect(controller.submit_player_command(&"skill", &"reinforced", &"sweep"), "Multi-target skill is accepted")
	var action: Dictionary = controller.events.back().details
	_expect(action.outcomes.size() == 2, "AoE affects both living enemies")
	_expect(hero.sl == 28 and action.sl_cost == 10 and action.advantage_sl_relief == 2, "AoE charges once and refunds advantage once")
	_expect(hero.cooldown_for(&"sweep") == 2, "New cooldown is not decremented on the cast action")
	_expect(not controller.submit_player_command(&"skill", &"reinforced", &"sweep"), "Repeated skill submission is locked")
	controller.complete_presentation()
	_expect(hero.cooldown_for(&"sweep") == 2, "Other units do not decrement hero cooldown")
	_advance_to_hero(controller)
	_expect(not controller.submit_player_command(&"skill", &"reinforced", &"sweep"), "CD 2 blocks the first following own action")
	controller.submit_player_command(&"defend")
	_expect(hero.cooldown_for(&"sweep") == 1, "Defense consumes one cooldown action")
	controller.complete_presentation()
	_advance_to_hero(controller)
	_expect(not controller.submit_player_command(&"skill", &"reinforced", &"sweep"), "CD 1 blocks the second following own action")
	controller.submit_player_command(&"defend")
	controller.complete_presentation()
	_advance_to_hero(controller)
	_expect(hero.cooldown_for(&"sweep") == 0 and controller.submit_player_command(&"skill", &"reinforced", &"sweep"), "Skill becomes legal after N own actions")
	var skill: SkillDefinition = hero.get_skill(&"strike")
	skill.dual_affinity = true
	hero.skills_used_this_round = 1
	_expect(BattleCalculator.skill_cost(hero, skill, source.rules) == 15, "Dual skill doubles base cost; second-skill surcharge is added once")
	hero.definition.spirit = 1000
	hero.definition.willpower = 1000
	_expect(BattleCalculator.skill_cost(hero, skill, source.rules) == 15, "Unspecified SPI/WIL functions are not invented")
	controller.free()


func _check_targets() -> void:
	var source: EncounterDefinition = _stable_source()
	var controller: BattleController = _start(source)
	controller.get_combatant(&"reinforced").hp = 0
	controller.submit_player_command(&"skill", &"reinforced", &"strike")
	var action: Dictionary = controller.events.back().details
	_expect(action.retargeted and action.target_id == "elemental", "A downed former target is replaced by a living enemy")
	controller.complete_presentation()
	_expect(controller.current_actor().id == &"elemental", "Downed combatants are skipped in the round queue")
	controller.free()
	source = _stable_source()
	source.allies[0].initial_sl = 85
	source.rules.skill_deviation_chance = 100
	controller = _start(source)
	controller.submit_player_command(&"skill", &"reinforced", &"sweep")
	action = controller.events.back().details
	_expect(action.deviated and action.outcomes.size() == 1, "Deviating AoE becomes a random single-target cast")
	_expect(action.target_id != "hero" and controller.get_combatant(StringName(action.target_id)).is_alive(), "Deviation targets a living unit and excludes the caster")
	var first_log: Dictionary = controller.log_snapshot()
	controller.start_battle(source)
	controller.submit_player_command(&"skill", &"reinforced", &"sweep")
	_expect(controller.log_snapshot() == first_log, "Deviation can be replayed with the same seed")
	controller.free()
	source = _stable_source()
	source.allies[0].initial_sl = 96
	controller = _start(source)
	controller.submit_player_command(&"skill", &"reinforced", &"strike")
	var hero: CombatantState = controller.get_combatant(&"hero")
	action = controller.events.back().details
	_expect(hero.uncontrolled_remaining == 3 and hero.sl == 98, "Touching SL 100 latches loss of control even after advantage relief")
	_expect(action.outcomes[0].modifiers.uncontrolled == 1.0, "Triggering cast does not receive next-action uncontrolled damage")
	controller.free()


func _check_uncontrolled() -> void:
	var source: EncounterDefinition = _stable_source()
	source.allies[0].initial_sl = 100
	var controller: BattleController = _start(source)
	var hero: CombatantState = controller.get_combatant(&"hero")
	hero.cooldowns[&"strike"] = 3
	_expect(controller.phase == BattleController.Phase.AUTO_COMMAND, "Opening SL 100 starts automatic control")
	_expect(not controller.submit_player_command(&"defend"), "Loss of control prevents player commands")
	var auto_actions: int = 0
	for _step: int in range(150):
		if controller.phase == BattleController.Phase.AUTO_COMMAND and controller.current_actor() == hero:
			controller.submit_enemy_command()
			var action: Dictionary = controller.events.back().details
			_expect(action.target_id != "hero", "Uncontrolled attack excludes itself")
			_expect(action.outcomes[0].modifiers.uncontrolled == 1.5, "Uncontrolled attack receives the documented damage bonus")
			auto_actions += 1
		elif controller.phase == BattleController.Phase.PLAYER_COMMAND and controller.current_actor() == hero:
			break
		else:
			_step_battle(controller)
	_expect(auto_actions == 3 and hero.sl == 40 and hero.uncontrolled_remaining == 0, "Exactly three own actions end loss of control and reset SL to 40")
	_expect(hero.cooldown_for(&"strike") == 0, "Uncontrolled own actions also decrement existing cooldowns")
	controller.free()
	source = _source()
	for unit: CombatantSetup in source.allies:
		unit.definition.speed = 1
	source.enemies[0].initial_sl = 70
	controller = _start(source)
	controller.submit_enemy_command()
	_expect(controller.events.back().details.command == "defend", "AI defends at its configured load threshold")
	controller.free()


func _check_replay() -> void:
	var source: EncounterDefinition = _source()
	var controller: BattleController = _start(source)
	_play(controller)
	var first: Dictionary = controller.log_snapshot()
	_expect(controller.phase == BattleController.Phase.FINISHED, "Default mixed-affinity battle reaches victory or defeat")
	controller.start_battle(source)
	_play(controller)
	_expect(controller.log_snapshot() == first, "Multi-unit skill AI battle replays exactly")
	_expect(controller.export_log("res://.dev/m1-b-example-battle.json") == OK, "B log exports all skill outcomes and runtime states")
	controller.free()


func _play(controller: BattleController) -> void:
	for _step: int in range(600):
		if controller.phase == BattleController.Phase.FINISHED:
			return
		if controller.phase == BattleController.Phase.PLAYER_COMMAND:
			var actor: CombatantState = controller.current_actor()
			var target: CombatantState = controller.living_team(false)[0]
			if actor.sl >= 70:
				controller.submit_player_command(&"defend")
			elif not actor.definition.skills.is_empty() and actor.cooldown_for(actor.definition.skills[0].id) == 0:
				controller.submit_player_command(&"skill", target.id, actor.definition.skills[0].id)
			else:
				controller.submit_player_command(&"attack", target.id)
		else:
			_step_battle(controller)
	_expect(false, "Default battle finishes within 600 state transitions")


func _check_scene() -> void:
	var sandbox: BattleSandbox = SCENE.instantiate()
	sandbox.automatic_flow = false
	root.add_child(sandbox)
	await process_frame
	var hud: AdvancedBattleHUD = sandbox.hud as AdvancedBattleHUD
	_expect(hud != null and sandbox.controller.combatants.size() == 4, "Advanced scene uses the shared sandbox with multi-unit UI")
	hud.attack_button.grab_focus()
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_TAB
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	_expect(hud.selected_target == &"elemental", "Tab changes target even while a GUI button has focus")
	event = InputEventKey.new()
	event.physical_keycode = KEY_1
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	_expect(sandbox.controller.events.back().details.skill_id == "strike", "Actual 1 key submits the first skill")
	_expect(hud.skill_buttons[0].disabled and hud.attack_button.disabled, "Advanced UI locks during presentation")
	sandbox.restart_battle()
	_expect(sandbox.controller.get_combatant(&"hero").cooldowns.is_empty(), "Retry clears all cooldown states")
	var invalid: EncounterDefinition = _source()
	invalid.rules = null
	sandbox.controller.start_battle(invalid)
	_expect(hud.enemy_buttons[0].disabled and hud.skill_buttons[0].disabled, "Invalid reload cannot leave stale target or skill buttons active")
	sandbox.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks.append({"passed": condition, "description": message})
	if not condition:
		_failures.append(message)
		push_error("[M1-B SMOKE] " + message)
