class_name BattleController
extends Node

signal state_changed
signal action_presented(action: Dictionary)
signal battle_finished(result: StringName)

enum Phase { IDLE, PLAYER_COMMAND, ENEMY_COMMAND, PRESENTING, FINISHED, AUTO_COMMAND }

var phase: Phase = Phase.IDLE
var encounter: EncounterDefinition
var combatants: Array[CombatantState] = []
var turn_order: Array[StringName] = []
var round_number: int = 0
var result: StringName = &""
var error_message: String = ""
var last_export_path: String = ""
var events: Array[Dictionary] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _turn_index: int = 0
var _action_number: int = 0
var _opening_snapshot: Dictionary = {}


func start_battle(source: EncounterDefinition) -> bool:
	phase = Phase.IDLE
	encounter = source
	combatants.clear()
	turn_order.clear()
	events.clear()
	round_number = 0
	_turn_index = 0
	_action_number = 0
	result = &""
	error_message = ""
	last_export_path = ""
	_opening_snapshot.clear()
	var errors: PackedStringArray = []
	if source == null:
		errors.append("无法加载遭遇配表")
	else:
		errors = source.validation_errors()
	if not errors.is_empty():
		error_message = "；".join(errors)
		state_changed.emit()
		return false
	_rng.seed = source.seed_value
	var definitions: Array[Dictionary] = []
	var slots: Array[CombatantSetup] = source.get_setups()
	for index: int in range(slots.size()):
		var slot: CombatantSetup = slots[index]
		combatants.append(CombatantState.new(slot.definition, index < source.ally_count(),
			slot.initial_hp, slot.initial_sl, source.rules, slot.instance_id, slot.initial_critical))
		definitions.append(slot.definition.snapshot())
	_opening_snapshot = {"encounter_id": String(source.id), "version": source.data_version,
		"seed": source.seed_value, "rules": source.rules.snapshot(), "definitions": definitions,
		"environment": source.environment_by_affinity.duplicate(), "states": _states_snapshot()}
	_opening_snapshot["previous_battles"] = source.previous_battles
	_record(&"battle_start")
	_start_round()
	return true


func get_combatant(id: StringName) -> CombatantState:
	for unit: CombatantState in combatants:
		if unit.id == id:
			return unit
	return null


func living_team(player_team: bool) -> Array[CombatantState]:
	var units: Array[CombatantState] = []
	for unit: CombatantState in combatants:
		if unit.is_player == player_team and unit.is_alive():
			units.append(unit)
	return units


func current_actor() -> CombatantState:
	if phase == Phase.IDLE or phase == Phase.FINISHED or _turn_index >= turn_order.size():
		return null
	return get_combatant(turn_order[_turn_index])


func remaining_order() -> Array[StringName]:
	return turn_order.slice(_turn_index)


func submit_player_command(command: StringName, target_id: StringName = &"",
		skill_id: StringName = &"") -> bool:
	if phase != Phase.PLAYER_COMMAND:
		return false
	var actor: CombatantState = current_actor()
	if command == &"breakthrough":
		if not can_breakthrough(actor):
			return false
		_execute(actor, [actor], command)
		return true
	if command == &"defend":
		_execute(actor, [actor], command)
		return true
	var skill: SkillDefinition = null
	if command == &"skill":
		if not encounter.rules.advanced_enabled:
			return false
		skill = actor.get_skill(skill_id)
		if skill == null or actor.cooldown_for(skill_id) > 0:
			return false
	elif command != &"attack":
		return false
	var targets: Array[CombatantState] = []
	var retargeted: bool = false
	if skill != null and skill.target_mode == "all_enemies":
		targets = living_team(not actor.is_player)
	else:
		var target: CombatantState = get_combatant(target_id)
		if target == null or target.is_player == actor.is_player:
			return false
		if not target.is_alive():
			if not encounter.rules.advanced_enabled:
				return false
			targets = living_team(not actor.is_player)
			retargeted = true
			if not targets.is_empty():
				targets = [targets[0]]
		else:
			targets = [target]
	if targets.is_empty():
		return false
	_execute(actor, targets, command, skill,
		{"requested_target": String(target_id), "retargeted": retargeted})
	return true


func submit_enemy_command() -> bool:
	if phase != Phase.ENEMY_COMMAND and phase != Phase.AUTO_COMMAND:
		return false
	var actor: CombatantState = current_actor()
	if phase == Phase.AUTO_COMMAND:
		var pool: Array[CombatantState] = _random_target_pool(actor)
		if pool.is_empty():
			return false
		var selection: int = _rng.randi_range(0, pool.size() - 1)
		_execute(actor, [pool[selection]], &"uncontrolled",
			null, {"ai_reason": "觉醒失控：随机攻击敌我", "target_roll": selection})
		return true
	var targets: Array[CombatantState] = living_team(not actor.is_player)
	if targets.is_empty():
		return false
	if encounter.rules.advanced_enabled:
		if can_breakthrough(actor) and actor.sl >= encounter.rules.ai_defense_threshold:
			_execute(actor, [actor], &"breakthrough", null, {"ai_reason": "临界槽已满，尝试突破降压"})
			return true
		if actor.sl >= encounter.rules.ai_defense_threshold:
			_execute(actor, [actor], &"defend", null, {"ai_reason": "负荷达到降压阈值"})
			return true
		for skill: SkillDefinition in actor.definition.skills:
			if actor.cooldown_for(skill.id) > 0:
				continue
			if skill.target_mode == "all_enemies":
				if targets.size() < 2:
					continue
			else:
				targets = [targets[0]]
			_execute(actor, targets, &"skill", skill, {"ai_reason": "技能可用：" + skill.display_name})
			return true
	_execute(actor, [targets[0]], &"attack", null, {"ai_reason": "普通攻击"})
	return true


func complete_presentation() -> void:
	if phase != Phase.PRESENTING:
		return
	if living_team(true).is_empty():
		_finish(&"defeat")
	elif living_team(false).is_empty():
		_finish(&"victory")
	else:
		_turn_index += 1
		_advance_turn()


func log_snapshot() -> Dictionary:
	var stage: String = "M1-B" if encounter != null and encounter.rules.advanced_enabled else "M1-A"
	if encounter != null and encounter.rules.breakthrough_enabled:
		stage = "M1-C"
	return {"stage": stage, "engine": Engine.get_version_info().string,
		"opening": _opening_snapshot.duplicate(true), "events": events.duplicate(true),
		"result": String(result), "phase": Phase.keys()[phase], "states": _states_snapshot()}


func export_log(destination: String = "") -> Error:
	if encounter == null or not error_message.is_empty():
		return ERR_UNCONFIGURED
	var path: String = destination
	if path.is_empty():
		path = "user://battle_logs/%s_%d_%d_%d.json" % [String(log_snapshot().stage).to_lower(),
			encounter.seed_value, int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var directory: String = ProjectSettings.globalize_path(path.get_base_dir())
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK:
		return directory_error
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(log_snapshot(), "\t"))
	file.close()
	last_export_path = ProjectSettings.globalize_path(path)
	return OK


func _execute(actor: CombatantState, targets: Array[CombatantState],
		command: StringName, skill: SkillDefinition = null, metadata: Dictionary = {}) -> void:
	phase = Phase.PRESENTING
	var before: Array[Dictionary] = _states_snapshot()
	var was_uncontrolled: bool = command == &"uncontrolled"
	var weak_before: int = actor.weak_actions
	var new_weakness: bool = false
	var newly_cast: StringName = &""
	var action: Dictionary = metadata.duplicate(true)
	var actual_targets: Array[CombatantState] = targets.duplicate()
	if command == &"defend":
		action.merge(BattleCalculator.calculate_defense(actor, encounter.rules), true)
		actor.hp += int(action.healing)
		actor.sl -= int(action.sl_relief)
	elif command == &"breakthrough":
		action.merge(BattleCalculator.calculate_breakthrough(actor, encounter, _rng), true)
		if action.success:
			actor.breakthrough_multiplier = encounter.rules.breakthrough_success_multiplier
			actor.critical = 0
			actor.sl = 0
			actor.weak_actions = 0
			actor.uncontrolled_remaining = 0
			var healing: int = mini(actor.max_hp() - actor.hp,
				roundi(actor.max_hp() * encounter.rules.breakthrough_success_heal_ratio))
			actor.hp += healing
			action["healing"] = healing
		else:
			actor.critical = encounter.rules.breakthrough_failure_critical
			actor.sl = mini(encounter.rules.sl_max, actor.sl + encounter.rules.breakthrough_failure_sl)
			actor.breakthrough_failures += 1
			actor.weak_actions = encounter.rules.breakthrough_weak_actions
			new_weakness = true
			_latch_uncontrolled(actor)
	else:
		var critical_gains: Array[Dictionary] = []
		if skill != null:
			var cost: int = BattleCalculator.skill_cost(actor, skill, encounter.rules)
			actor.sl = clampi(actor.sl + cost, encounter.rules.sl_min, encounter.rules.sl_max)
			actor.skills_used_this_round += 1
			actor.cooldowns[skill.id] = skill.cooldown
			newly_cast = skill.id
			action["sl_cost"] = cost
			action["skill_id"] = String(skill.id)
			action["skill_name"] = skill.display_name
			_gain_critical(actor, encounter.rules.critical_skill_gain, "skill", critical_gains)
			_latch_uncontrolled(actor)
			if actor.sl >= encounter.rules.sl_deviation_threshold:
				var deviation_roll: float = _rng.randf_range(0.0, 100.0)
				action["deviation_roll"] = deviation_roll
				if deviation_roll < encounter.rules.skill_deviation_chance:
					var pool: Array[CombatantState] = _random_target_pool(actor)
					var selection: int = _rng.randi_range(0, pool.size() - 1)
					actual_targets = [pool[selection]]
					action["deviated"] = true
					action["deviation_target_roll"] = selection
		var outcomes: Array[Dictionary] = []
		var advantage_hit: bool = false
		for target: CombatantState in actual_targets:
			var outcome: Dictionary = BattleCalculator.calculate_attack(actor, target, encounter, _rng, skill, was_uncontrolled)
			target.hp = maxi(0, target.hp - int(outcome.damage))
			if encounter.rules.breakthrough_enabled and outcome.hit:
				var gain: int = _rng.randi_range(encounter.rules.critical_received_min, encounter.rules.critical_received_max)
				_gain_critical(target, gain, "received", critical_gains)
			outcomes.append(outcome)
			if outcome.hit and float(outcome.modifiers.affinity) > 1.0:
				advantage_hit = true
		action.merge(outcomes[0], true)
		action["outcomes"] = outcomes
		action["command"] = String(command)
		action["critical_gains"] = critical_gains
		if encounter.rules.advanced_enabled and advantage_hit:
			var relief: int = mini(actor.sl, encounter.rules.advantage_sl_relief)
			actor.sl -= relief
			action["advantage_sl_relief"] = relief
			_gain_critical(actor, encounter.rules.critical_advantage_gain, "advantage", critical_gains)
	if weak_before > 0 and not new_weakness:
		actor.weak_actions = maxi(0, actor.weak_actions - 1)
	for skill_id: StringName in actor.cooldowns.keys():
		if skill_id != newly_cast:
			actor.cooldowns[skill_id] = maxi(0, int(actor.cooldowns[skill_id]) - 1)
	if was_uncontrolled:
		actor.uncontrolled_remaining -= 1
		if actor.uncontrolled_remaining == 0:
			actor.sl = encounter.rules.uncontrolled_recovery_sl
	action["action_number"] = _action_number + 1
	action["actor_id"] = String(actor.id)
	action["before"] = before
	action["after"] = _states_snapshot()
	_action_number += 1
	_record(&"action", action)
	state_changed.emit()
	action_presented.emit(action.duplicate(true))


func _latch_uncontrolled(actor: CombatantState) -> void:
	if encounter.rules.advanced_enabled and actor.sl >= encounter.rules.sl_max and actor.uncontrolled_remaining == 0:
		actor.uncontrolled_remaining = encounter.rules.uncontrolled_actions


func can_breakthrough(actor: CombatantState) -> bool:
	return actor != null and encounter != null and encounter.rules.breakthrough_enabled \
		and actor.critical >= encounter.rules.critical_max and actor.breakthrough_multiplier == 1.0 \
		and actor.uncontrolled_remaining == 0 and actor.is_alive()


func record_target_choice(target_id: StringName) -> void:
	var target: CombatantState = get_combatant(target_id)
	if phase != Phase.PLAYER_COMMAND or not encounter.rules.advanced_enabled or target == null or target.is_player or not target.is_alive():
		return
	_record(&"target_selected", {"actor_id": String(current_actor().id), "target_id": String(target_id),
		"affinity_modifier": BattleCalculator.attack_preview(current_actor(), target, encounter).modifiers.affinity})


func _gain_critical(actor: CombatantState, amount: int, source: String,
		gains: Array[Dictionary]) -> void:
	if not encounter.rules.breakthrough_enabled:
		return
	var before: int = actor.critical
	actor.critical = clampi(actor.critical + amount, 0, encounter.rules.critical_max)
	gains.append({"unit_id": String(actor.id), "source": source, "roll_or_amount": amount,
		"before": before, "after": actor.critical})


func _random_target_pool(actor: CombatantState) -> Array[CombatantState]:
	var pool: Array[CombatantState] = []
	for unit: CombatantState in combatants:
		if unit != actor and unit.is_alive():
			pool.append(unit)
	return pool


func _start_round() -> void:
	round_number += 1
	_turn_index = 0
	turn_order.clear()
	var units: Array[CombatantState] = []
	for unit: CombatantState in combatants:
		unit.skills_used_this_round = 0
		if unit.is_alive():
			units.append(unit)
	units.sort_custom(func(a: CombatantState, b: CombatantState) -> bool:
		if a.speed_value() == b.speed_value():
			return String(a.id) < String(b.id)
		return a.speed_value() > b.speed_value())
	var offset: int = 0
	while offset < units.size():
		var end: int = offset + 1
		while end < units.size() and units[end].speed_value() == units[offset].speed_value():
			end += 1
		var group: Array[CombatantState] = units.slice(offset, end)
		for unit: CombatantState in _order_ties(group):
			turn_order.append(unit.id)
		offset = end
	_record(&"round_start", {"order": turn_order.duplicate()})
	_advance_turn()


func _order_ties(group: Array[CombatantState]) -> Array[CombatantState]:
	if group.size() <= 1:
		return group
	var rolls: Dictionary = {}
	for unit: CombatantState in group:
		rolls[unit.id] = _rng.randi_range(1, encounter.rules.initiative_die_sides)
	var details: Dictionary = {"rolls": rolls.duplicate()}
	if not encounter.rules.advanced_enabled:
		details["ally_roll"] = rolls[combatants[0].id]
		details["enemy_roll"] = rolls[combatants[1].id]
	_record(&"initiative_roll", details)
	group.sort_custom(func(a: CombatantState, b: CombatantState) -> bool:
		if rolls[a.id] == rolls[b.id]:
			return String(a.id) < String(b.id)
		return int(rolls[a.id]) > int(rolls[b.id]))
	var ordered: Array[CombatantState] = []
	var offset: int = 0
	while offset < group.size():
		var end: int = offset + 1
		while end < group.size() and rolls[group[end].id] == rolls[group[offset].id]:
			end += 1
		ordered.append_array(_order_ties(group.slice(offset, end)))
		offset = end
	return ordered


func _advance_turn() -> void:
	while _turn_index < turn_order.size():
		var actor: CombatantState = get_combatant(turn_order[_turn_index])
		if actor.is_alive():
			_latch_uncontrolled(actor)
			if actor.uncontrolled_remaining > 0:
				phase = Phase.AUTO_COMMAND
			else:
				phase = Phase.PLAYER_COMMAND if actor.is_player else Phase.ENEMY_COMMAND
			state_changed.emit()
			return
		_turn_index += 1
	_record(&"round_end")
	_start_round()


func _finish(outcome: StringName) -> void:
	phase = Phase.FINISHED
	result = outcome
	_record(&"battle_end", {"result": String(result)})
	state_changed.emit()
	battle_finished.emit(result)


func _states_snapshot() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for unit: CombatantState in combatants:
		snapshots.append(unit.snapshot())
	return snapshots


func _record(kind: StringName, details: Dictionary = {}) -> void:
	events.append({"sequence": events.size(), "round": round_number,
		"kind": String(kind), "details": details.duplicate(true), "states": _states_snapshot()})
