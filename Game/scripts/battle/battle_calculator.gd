class_name BattleCalculator
extends RefCounted


static func affinity_modifier(source: String, target: String, rules: BattleRules) -> float:
	if source == "特殊" or target == "特殊":
		return 1.0
	if String(rules.affinity_advantages.get(source, "")) == target:
		return rules.advantage_multiplier
	if String(rules.affinity_advantages.get(target, "")) == source:
		return rules.disadvantage_multiplier
	return 1.0


static func rank_modifier(source: String, target: String, rules: BattleRules) -> float:
	var delta: int = rules.rank_order.find(source) - rules.rank_order.find(target)
	var index: int = mini(absi(delta), rules.higher_rank_multipliers.size() - 1)
	return rules.higher_rank_multipliers[index] if delta >= 0 else rules.lower_rank_multipliers[index]


static func sl_modifiers(sl: int, rules: BattleRules) -> Dictionary:
	if not rules.advanced_enabled or sl < rules.sl_light_threshold:
		return {"damage": 1.0, "hit": 1.0, "hit_points": 0.0}
	if sl < rules.sl_medium_threshold:
		return {"damage": rules.sl_light_multiplier, "hit": rules.sl_light_multiplier, "hit_points": 0.0}
	return {"damage": rules.sl_medium_multiplier, "hit": rules.sl_medium_multiplier,
		"hit_points": rules.sl_medium_hit_penalty}


static func skill_cost(actor: CombatantState, skill: SkillDefinition, rules: BattleRules) -> int:
	var cost: int = skill.sl_cost * (rules.dual_skill_cost_multiplier if skill.dual_affinity else 1)
	if actor.skills_used_this_round > 0:
		cost += rules.repeat_skill_sl_cost
	return roundi(cost * actor.definition.skill_sl_multiplier)


static func attack_preview(actor: CombatantState, target: CombatantState,
		encounter: EncounterDefinition, skill: SkillDefinition = null, projected_sl: int = -1,
		uncontrolled: bool = false) -> Dictionary:
	var rules: BattleRules = encounter.rules
	var affinity: String = actor.definition.affinity
	var multiplier: float = rules.attack_multiplier
	if skill != null:
		multiplier = skill.multiplier
		if not skill.affinity.is_empty():
			affinity = skill.affinity
	var modifiers: Dictionary = {"skill": multiplier, "affinity": encounter.affinity_modifier,
		"environment": encounter.environment_modifier, "rank": encounter.rank_modifier,
		"sl": 1.0, "uncontrolled": 1.0, "weak": 1.0}
	if rules.advanced_enabled:
		modifiers.affinity = affinity_modifier(affinity, target.definition.affinity, rules)
		modifiers.rank = rank_modifier(actor.definition.awakening_rank, target.definition.awakening_rank, rules)
		modifiers.environment = float(encounter.environment_by_affinity.get(affinity, 1.0))
	var load_value: int = actor.sl if projected_sl < 0 else projected_sl
	var penalties: Dictionary = sl_modifiers(load_value, rules)
	modifiers.sl = penalties.damage
	if uncontrolled:
		modifiers.uncontrolled = rules.uncontrolled_damage_multiplier
	if rules.breakthrough_enabled and actor.weak_actions > 0:
		modifiers.weak = rules.weak_damage_multiplier
	var base_chance: float = actor.definition.accuracy \
		+ (actor.perception_value() - target.perception_value()) * rules.perception_hit_bonus \
		- target.definition.evasion
	var chance: float = clampf(base_chance * float(penalties.hit) - float(penalties.hit_points), 0.0, 100.0)
	return {"hit_chance": chance, "affinity": affinity, "modifiers": modifiers}


static func calculate_attack(actor: CombatantState, target: CombatantState,
		encounter: EncounterDefinition, rng: RandomNumberGenerator,
		skill: SkillDefinition = null, uncontrolled: bool = false) -> Dictionary:
	var rules: BattleRules = encounter.rules
	var preview: Dictionary = attack_preview(actor, target, encounter, skill, -1, uncontrolled)
	var chance: float = preview.hit_chance
	var hit_roll: float = rng.randf_range(0.0, 100.0)
	var hit: bool = chance >= 100.0 or (chance > 0.0 and hit_roll < chance)
	var dice: Array[int] = []
	var dice_total: int = 0
	var raw_damage: float = 0.0
	var damage: int = 0
	var modifiers: Dictionary = preview.modifiers
	if hit:
		for _index: int in range(rules.damage_dice_count):
			var roll: int = rng.randi_range(rules.damage_die_min, rules.damage_die_max)
			dice.append(roll)
			dice_total += roll
		raw_damage = ((actor.attack_value() * float(modifiers.skill) + dice_total)
			* float(modifiers.affinity) * float(modifiers.environment) * float(modifiers.rank)
			- target.defense_value() * rules.defense_coefficient) \
			* float(modifiers.sl) * float(modifiers.uncontrolled) * float(modifiers.weak)
		damage = maxi(rules.minimum_hit_damage, roundi(raw_damage))
	return {"command": "attack" if skill == null else "skill",
		"actor_id": String(actor.id), "target_id": String(target.id),
		"hit": hit, "hit_chance": chance, "hit_roll": hit_roll, "dice": dice,
		"raw_damage": raw_damage, "damage": damage, "hp_loss": mini(target.hp, damage),
		"affinity": preview.affinity, "modifiers": modifiers}


static func calculate_defense(actor: CombatantState, rules: BattleRules) -> Dictionary:
	var healing: int = mini(actor.max_hp() - actor.hp, roundi(actor.max_hp() * rules.defense_hp_ratio))
	var relief: int = mini(actor.sl - rules.sl_min, rules.defense_sl_relief)
	return {"command": "defend", "actor_id": String(actor.id),
		"target_id": String(actor.id), "healing": healing, "sl_relief": relief}


static func breakthrough_chance(actor: CombatantState, encounter: EncounterDefinition) -> float:
	var rules: BattleRules = encounter.rules
	var chance: float = rules.breakthrough_base_chance \
		+ mini(actor.breakthrough_failures, rules.breakthrough_pity_limit) * rules.breakthrough_pity_bonus
	if float(actor.hp) / actor.max_hp() <= rules.breakthrough_low_hp_threshold:
		chance += rules.breakthrough_low_hp_bonus
	chance += encounter.previous_battles * rules.breakthrough_consecutive_bonus
	return clampf(chance, 0.0, 100.0)


static func calculate_breakthrough(actor: CombatantState, encounter: EncounterDefinition,
		rng: RandomNumberGenerator) -> Dictionary:
	var chance: float = breakthrough_chance(actor, encounter)
	var roll: float = rng.randf_range(0.0, 100.0)
	return {"command": "breakthrough", "actor_id": String(actor.id), "target_id": String(actor.id),
		"chance": chance, "roll": roll, "success": chance >= 100.0 or (chance > 0.0 and roll < chance)}
