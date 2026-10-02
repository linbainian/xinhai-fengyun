class_name CombatantDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var data_version: String = "m1-a.1"
@export var awakening_rank: String = "D"
@export var affinity: String = "强化"
@export var body_color: Color = Color.WHITE
@export var skills: Array[SkillDefinition] = []
@export_group("Six attributes (prototype values)")
@export var strength: int = 10
@export var agility: int = 10
@export var constitution: int = 10
@export var spirit: int = 10
@export var perception: int = 10
@export var willpower: int = 10
@export_group("Explicit combat stats (mapping pending)")
@export var max_hp: int = 100
@export var attack: float = 0.0
@export var defense: float = 0.0
@export var speed: int = 1
@export var accuracy: float = 100.0
@export var evasion: float = 0.0
@export var skill_sl_multiplier: float = 1.0


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"" or display_name.is_empty():
		errors.append("单位需要 id 和名称")
	if max_hp <= 0 or attack < 0.0 or defense < 0.0 or speed < 0:
		errors.append("HP 上限必须为正，攻击、防御、速度不能为负")
	if accuracy < 0.0 or accuracy > 100.0 or evasion < 0.0 or evasion > 100.0:
		errors.append("基础命中和闪避必须在 0–100%")
	if skill_sl_multiplier <= 0.0 or skill_sl_multiplier > 2.0:
		errors.append("技能负荷倍率必须在0至2之间")
	var skill_ids: Array[StringName] = []
	for skill: SkillDefinition in skills:
		if skill == null:
			errors.append("技能不能为空")
			continue
		errors.append_array(skill.validation_errors())
		if skill_ids.has(skill.id):
			errors.append("单位技能 id 不能重复")
		skill_ids.append(skill.id)
	return errors


func snapshot() -> Dictionary:
	var skill_data: Array[Dictionary] = []
	for skill: SkillDefinition in skills:
		skill_data.append(skill.snapshot())
	return {
		"id": String(id), "name": display_name, "version": data_version,
		"rank": awakening_rank, "affinity": affinity,
		"attributes": {"STR": strength, "AGI": agility, "CON": constitution,
			"SPI": spirit, "PER": perception, "WIL": willpower},
		"max_hp": max_hp, "attack": attack, "defense": defense,
		"speed": speed, "accuracy": accuracy, "evasion": evasion, "skills": skill_data,
		"skill_sl_multiplier": skill_sl_multiplier,
	}
