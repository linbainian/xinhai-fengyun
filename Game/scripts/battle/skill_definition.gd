class_name SkillDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var multiplier: float = 1.0
@export var affinity: String = ""
@export_enum("single_enemy", "all_enemies") var target_mode: String = "single_enemy"
@export var sl_cost: int = 5
@export var cooldown: int = 1
@export var dual_affinity: bool = false


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"" or display_name.is_empty() or multiplier < 0.0 or sl_cost < 0 or cooldown < 0:
		errors.append("技能名称、倍率、负荷或冷却无效")
	if target_mode != "single_enemy" and target_mode != "all_enemies":
		errors.append("不支持的技能目标类型")
	return errors


func snapshot() -> Dictionary:
	return {"id": String(id), "name": display_name, "multiplier": multiplier,
		"affinity": affinity, "target_mode": target_mode, "sl_cost": sl_cost,
		"cooldown": cooldown, "dual_affinity": dual_affinity}
