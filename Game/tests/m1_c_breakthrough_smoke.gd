extends SceneTree

const SOURCE: String = "res://data/battle/m1_c_encounter.tres"
const SCENE: PackedScene = preload("res://scenes/battle/breakthrough_sandbox.tscn")
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _pity_seed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _source() -> EncounterDefinition:
	return ResourceLoader.load(SOURCE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EncounterDefinition


func _start(source: EncounterDefinition) -> BattleController:
	var controller: BattleController = BattleController.new()
	root.add_child(controller)
	_expect(controller.start_battle(source), "C encounter starts")
	return controller


func _solid_source() -> EncounterDefinition:
	var source: EncounterDefinition = _source()
	source.allies[0].initial_sl = 0
	source.allies[0].definition.attack = 20
	source.allies[0].definition.perception = 100
	source.allies[0].definition.affinity = "强化"
	source.enemies[0].definition.defense = 12
	source.rules.damage_die_min = 5
	source.rules.damage_die_max = 5
	for slot: CombatantSetup in source.enemies:
		slot.definition.max_hp = 10000
		slot.definition.attack = 0
		slot.definition.accuracy = 0
		slot.definition.skills.clear()
	return source


func _step(controller: BattleController) -> void:
	match controller.phase:
		BattleController.Phase.PRESENTING:
			controller.complete_presentation()
		BattleController.Phase.ENEMY_COMMAND, BattleController.Phase.AUTO_COMMAND:
			controller.submit_enemy_command()
		BattleController.Phase.PLAYER_COMMAND:
			controller.submit_player_command(&"defend")


func _next_hero(controller: BattleController) -> void:
	for _index: int in range(100):
		if controller.phase == BattleController.Phase.PLAYER_COMMAND and controller.current_actor().id == &"hero":
			return
		_step(controller)
	_expect(false, "Hero receives its next action")


func _run() -> void:
	_check_success()
	_check_failure()
	_check_critical()
	_check_pity()
	_check_companion()
	_check_decisions()
	await _check_scene()
	var report: FileAccess = FileAccess.open("res://.dev/m1-c-smoke-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": _failures.is_empty(), "checks": _checks,
		"failures": _failures, "three_failure_seed": _pity_seed}, "\t"))
	report.close()
	print("[M1-C SMOKE] %d/%d checks passed" % [_checks.size() - _failures.size(), _checks.size()])
	quit(0 if _failures.is_empty() else 1)


func _check_success() -> void:
	var source: EncounterDefinition = _solid_source()
	source.rules.breakthrough_base_chance = 100
	source.allies[0].definition.max_hp = 120
	source.allies[0].initial_hp = 30
	var original: Dictionary = source.allies[0].definition.snapshot()
	var controller: BattleController = _start(source)
	var hero: CombatantState = controller.get_combatant(&"hero")
	hero.critical = 99
	var count: int = controller.events.size()
	_expect(not controller.submit_player_command(&"breakthrough"), "Gauge 99 cannot break through")
	_expect(controller.events.size() == count, "Rejected breakthrough consumes no RNG or action")
	hero.critical = 100
	hero.cooldowns[&"strike"] = 2
	_expect(controller.submit_player_command(&"breakthrough"), "Full gauge enables breakthrough")
	var action: Dictionary = controller.events.back().details
	_expect(action.success and action.chance == 100, "Displayed 100% succeeds")
	_expect(hero.max_hp() == 156 and hero.hp == 108, "Success boosts max HP once and heals 50% of new max HP")
	_expect(hero.critical == 0 and hero.sl == 0, "Success resets gauge and SL")
	_expect(is_equal_approx(hero.attack_value(), 26) and hero.speed_value() == 21, "Derived stats are scaled once")
	_expect(hero.cooldown_for(&"strike") == 1, "Breakthrough consumes one own action for existing CD")
	_expect(source.allies[0].definition.snapshot() == original, "Success never edits the definition Resource")
	_expect(hero.definition.awakening_rank == "D", "Battle breakthrough does not permanently change rank")
	_expect(not controller.can_breakthrough(hero), "Successful buff cannot stack within the battle")
	_expect(not controller.submit_player_command(&"breakthrough"), "Duplicate presentation input is rejected")
	hero.critical = 100
	controller.complete_presentation()
	_next_hero(controller)
	_expect(not controller.submit_player_command(&"breakthrough"), "Refilled gauge cannot repeat an already successful buff")
	controller.submit_player_command(&"attack", &"reinforced")
	action = controller.events.back().details
	_expect(action.damage == 30, "Boosted 26 ATK + 10 dice - 6 defense =30, without double scaling")
	controller.start_battle(source)
	hero = controller.get_combatant(&"hero")
	_expect(hero.breakthrough_multiplier == 1 and hero.hp == 30 and hero.max_hp() == 120, "Retry removes successful boost and restores opening HP")
	controller.free()


func _check_failure() -> void:
	var source: EncounterDefinition = _solid_source()
	source.rules.breakthrough_base_chance = 0
	var controller: BattleController = _start(source)
	var hero: CombatantState = controller.get_combatant(&"hero")
	controller.submit_player_command(&"breakthrough")
	var first: Dictionary = controller.log_snapshot()
	var action: Dictionary = controller.events.back().details
	_expect(not action.success and action.chance == 0, "Displayed 0% fails")
	_expect(hero.sl == 25 and hero.critical == 50 and hero.breakthrough_failures == 1, "Failure adds 25 SL, resets gauge50, and records pity")
	_expect(hero.weak_actions == 1, "Failure weakness is not consumed by the failure action")
	controller.complete_presentation()
	_next_hero(controller)
	_expect(hero.weak_actions == 1, "Other combatants do not consume hero weakness")
	controller.submit_player_command(&"attack", &"reinforced")
	action = controller.events.back().details
	_expect(action.damage == 12 and action.modifiers.weak == 0.5, "Next own output is halved")
	_expect(hero.weak_actions == 0, "Weakness ends after that own action")
	controller.start_battle(source)
	controller.submit_player_command(&"breakthrough")
	_expect(controller.log_snapshot() == first, "Breakthrough failure and random roll replay exactly")
	source.rules.breakthrough_base_chance = 60
	for failures: int in range(4):
		hero = controller.get_combatant(&"hero")
		hero.breakthrough_failures = failures
		_expect(BattleCalculator.breakthrough_chance(hero, source) == [60, 75, 90, 90][failures], "Pity probability for %d failures" % failures)
	source.rules.breakthrough_low_hp_bonus = 20
	source.rules.breakthrough_consecutive_bonus = 10
	source.previous_battles = 2
	hero.hp = 1
	_expect(BattleCalculator.breakthrough_chance(hero, source) == 100, "Configured low-HP/continuous-battle bonuses are clamped and visible")
	controller.free()
	source = _source()
	source.rules.breakthrough_base_chance = 0
	source.allies[0].initial_sl = 80
	controller = _start(source)
	controller.submit_player_command(&"breakthrough")
	hero = controller.get_combatant(&"hero")
	_expect(hero.sl == 100 and hero.uncontrolled_remaining == 3, "Failure crossing SL100 also schedules loss of control")
	controller.free()


func _check_critical() -> void:
	var source: EncounterDefinition = _source()
	source.allies[0].initial_critical = 0
	source.allies[0].initial_sl = 0
	source.allies[0].definition.perception = 100
	source.enemies[1].definition = source.enemies[0].definition
	var controller: BattleController = _start(source)
	controller.submit_player_command(&"skill", &"reinforced", &"sweep")
	var actor: CombatantState = controller.get_combatant(&"hero")
	var action: Dictionary = controller.events.back().details
	_expect(actor.critical == 20, "AoE grants skill5 and advantage15 only once per action")
	for id: StringName in [&"reinforced", &"elemental"]:
		var victim: CombatantState = controller.get_combatant(id)
		_expect(victim.critical >= 8 and victim.critical <= 12, "Each hit victim independently gains 8–12 gauge")
	_expect(action.critical_gains.size() == 4, "Log records skill, both received rolls, and the one advantage gain")
	controller.start_battle(source)
	controller.get_combatant(&"hero").critical = 94
	controller.submit_player_command(&"skill", &"reinforced", &"sweep")
	_expect(controller.get_combatant(&"hero").critical == 100, "Gauge caps at100")
	controller.free()
	source = _source()
	source.allies[0].initial_critical = 0
	source.allies[0].initial_sl = 0
	source.allies[0].definition.accuracy = 0
	source.allies[0].definition.perception = 0
	controller = _start(source)
	controller.submit_player_command(&"skill", &"reinforced", &"strike")
	_expect(controller.get_combatant(&"hero").critical == 5, "Skill use gains5 even when the hit misses")
	_expect(controller.get_combatant(&"reinforced").critical == 0, "A missed attack does not grant received-hit gauge")
	controller.free()


func _fill_gauge(controller: BattleController) -> void:
	for _step_index: int in range(200):
		if controller.phase == BattleController.Phase.PLAYER_COMMAND:
			var hero: CombatantState = controller.current_actor()
			if hero.critical >= 100:
				return
			if hero.sl >= 40:
				controller.submit_player_command(&"defend")
			elif hero.cooldown_for(&"strike") == 0:
				controller.submit_player_command(&"skill", &"reinforced", &"strike")
			else:
				controller.submit_player_command(&"attack", &"reinforced")
		else:
			_step(controller)


func _check_pity() -> void:
	var source: EncounterDefinition = _source()
	source.allies.resize(1)
	source.enemies.resize(1)
	source.allies[0].initial_sl = 0
	source.allies[0].definition.max_hp = 10000
	source.allies[0].initial_hp = -1
	source.allies[0].definition.perception = 100
	source.enemies[0].definition.max_hp = 10000
	source.enemies[0].definition.accuracy = 0
	source.enemies[0].definition.perception = 0
	source.enemies[0].definition.attack = 0
	source.enemies[0].definition.skills.clear()
	var controller: BattleController = BattleController.new()
	root.add_child(controller)
	for seed_value: int in range(1, 1001):
		source.seed_value = seed_value
		controller.start_battle(source)
		var chances: Array[float] = []
		var all_failed: bool = true
		for attempt: int in range(3):
			_fill_gauge(controller)
			controller.submit_player_command(&"breakthrough")
			var action: Dictionary = controller.events.back().details
			chances.append(action.chance)
			if action.success:
				all_failed = false
				break
			controller.complete_presentation()
		if all_failed:
			_pity_seed = seed_value
			_expect(chances == [60.0, 75.0, 90.0], "Actual three-failure trace uses60/75/90")
			_fill_gauge(controller)
			controller.submit_player_command(&"breakthrough")
			_expect(controller.events.back().details.chance == 90.0, "Fourth real attempt stays at the two-step pity cap")
			controller.export_log("res://.dev/m1-c-pity-example.json")
			break
	_expect(_pity_seed > 0, "An actual consecutive-failure trace is reproduced with a fixed seed")
	controller.free()


func _check_companion() -> void:
	var source: EncounterDefinition = _source()
	var definition: CombatantDefinition = source.allies[1].definition
	_expect(definition.display_name == "温让" and definition.awakening_rank == "C" and definition.affinity == "强化", "Wen Rang matches source identity/rank/affinity")
	_expect(definition.defense > source.allies[0].definition.defense, "Companion prototype focuses on defense")
	source.enemies[0].definition = definition
	source.enemies.resize(1)
	var controller: BattleController = _start(source)
	var ally: CombatantState = controller.get_combatant(&"wen_rang")
	var enemy: CombatantState = controller.get_combatant(&"reinforced")
	_expect(ally.definition == enemy.definition and ally.is_player and not enemy.is_player, "Same definition runs on either side of the generic template")
	ally.hp = 1
	_expect(enemy.hp == definition.max_hp and definition.max_hp == 260, "Ally/enemy states do not share mutable HP")
	controller.free()


func _check_decisions() -> void:
	var source: EncounterDefinition = _source()
	source.rules.breakthrough_base_chance = 100
	source.allies[0].definition.max_hp = 1000
	source.allies[0].initial_hp = 600
	var controller: BattleController = _start(source)
	controller.record_target_choice(&"elemental")
	controller.submit_player_command(&"defend")
	controller.complete_presentation()
	_next_hero(controller)
	controller.submit_player_command(&"breakthrough")
	controller.complete_presentation()
	_next_hero(controller)
	controller.record_target_choice(&"reinforced")
	controller.submit_player_command(&"skill", &"reinforced", &"strike")
	var kinds: Array[String] = []
	for event: Dictionary in controller.events:
		if event.kind == "target_selected":
			kinds.append("target")
		elif event.kind == "action":
			kinds.append(event.details.command)
	_expect(kinds.has("target") and kinds.has("defend") and kinds.has("breakthrough"), "One real encounter logs target choice, load relief and breakthrough")
	_expect(controller.export_log("res://.dev/m1-c-decisions-example.json") == OK, "Three-decision trace exports with probability and before/after states")
	controller.free()


func _check_scene() -> void:
	var sandbox: BattleSandbox = SCENE.instantiate()
	sandbox.automatic_flow = false
	root.add_child(sandbox)
	await process_frame
	var hud: AdvancedBattleHUD = sandbox.hud as AdvancedBattleHUD
	_expect(not hud.break_button.disabled and hud.break_button.text.contains("60%"), "Full gauge unlocks a button showing the actual60%")
	_expect(hud.break_button.tooltip_text.contains("SL+25") and hud.break_button.tooltip_text.contains("输出50%"), "Breakthrough explains failure cost before committing an action")
	_expect(sandbox.get_node("WorldContainer/WorldViewport/Arena").get_child_count() == 4, "C roster uses four instances of the same view template")
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_B
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	_expect(sandbox.controller.events.back().details.command == "breakthrough", "Actual B key submits breakthrough")
	_expect(hud.break_button.disabled, "Break button is locked during presentation")
	sandbox.restart_battle()
	_expect(sandbox.controller.get_combatant(&"hero").weak_actions == 0 and sandbox.controller.get_combatant(&"hero").breakthrough_failures == 0, "Retry clears weakness and pity history")
	_expect(sandbox.controller.get_combatant(&"hero").critical == 100, "Retry restores the configured gauge fixture")
	sandbox.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks.append({"passed": condition, "description": message})
	if not condition:
		_failures.append(message)
		push_error("[M1-C SMOKE] " + message)
