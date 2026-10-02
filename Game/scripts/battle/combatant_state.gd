class_name CombatantState
extends RefCounted

var definition: CombatantDefinition
var id: StringName
var is_player: bool = false
var hp: int = 0
var sl: int = 0
var cooldowns: Dictionary = {}
var uncontrolled_remaining: int = 0
var skills_used_this_round: int = 0
var critical: int = 0
var breakthrough_failures: int = 0
var breakthrough_multiplier: float = 1.0
var weak_actions: int = 0


func _init(source: CombatantDefinition, player_controlled: bool, initial_hp: int,
		initial_sl: int, rules: BattleRules, instance_id: StringName = &"",
		initial_critical: int = 0) -> void:
	definition = source
	id = source.id if instance_id == &"" else instance_id
	is_player = player_controlled
	hp = source.max_hp if initial_hp < 0 else clampi(initial_hp, 0, source.max_hp)
	sl = clampi(initial_sl, rules.sl_min, rules.sl_max)
	critical = clampi(initial_critical, 0, rules.critical_max) if rules.breakthrough_enabled else 0
	if rules.advanced_enabled and sl == rules.sl_max:
		uncontrolled_remaining = rules.uncontrolled_actions


func is_alive() -> bool:
	return hp > 0


func max_hp() -> int:
	return roundi(definition.max_hp * breakthrough_multiplier)


func attack_value() -> float:
	return definition.attack * breakthrough_multiplier


func defense_value() -> float:
	return definition.defense * breakthrough_multiplier


func speed_value() -> int:
	return roundi(definition.speed * breakthrough_multiplier)


func perception_value() -> float:
	return definition.perception * breakthrough_multiplier


func get_skill(skill_id: StringName) -> SkillDefinition:
	for skill: SkillDefinition in definition.skills:
		if skill.id == skill_id:
			return skill
	return null


func cooldown_for(skill_id: StringName) -> int:
	return int(cooldowns.get(skill_id, 0))


func snapshot() -> Dictionary:
	return {"id": String(id), "definition_id": String(definition.id), "player": is_player,
		"hp": hp, "max_hp": max_hp(), "sl": sl, "alive": is_alive(),
		"cooldowns": cooldowns.duplicate(), "uncontrolled_remaining": uncontrolled_remaining,
		"critical": critical, "breakthrough_failures": breakthrough_failures,
		"breakthrough_multiplier": breakthrough_multiplier, "weak_actions": weak_actions,
		"effective_attributes": {"STR": definition.strength * breakthrough_multiplier,
			"AGI": definition.agility * breakthrough_multiplier, "CON": definition.constitution * breakthrough_multiplier,
			"SPI": definition.spirit * breakthrough_multiplier, "PER": perception_value(),
			"WIL": definition.willpower * breakthrough_multiplier}}
