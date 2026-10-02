class_name BattleRules
extends Resource

@export var data_version: String = "m1-a.1"
@export var damage_dice_count: int = 2
@export var damage_die_min: int = 1
@export var damage_die_max: int = 10
@export var attack_multiplier: float = 1.0
@export var defense_coefficient: float = 0.5
@export var perception_hit_bonus: float = 2.0
@export var minimum_hit_damage: int = 1
@export var defense_hp_ratio: float = 0.1
@export var defense_sl_relief: int = 15
@export var sl_min: int = 0
@export var sl_max: int = 100
@export var initiative_die_sides: int = 6
@export_group("M1-B rules")
@export var advanced_enabled: bool = false
@export var affinities: PackedStringArray = ["念动力", "强化", "精神", "元素", "特殊"]
@export var affinity_advantages: Dictionary = {"念动力": "强化", "强化": "精神", "精神": "元素", "元素": "念动力"}
@export var advantage_multiplier: float = 1.2
@export var disadvantage_multiplier: float = 0.8
@export var rank_order: PackedStringArray = ["F", "E", "D", "C", "B", "A", "S", "SS", "SSS"]
@export var higher_rank_multipliers: Array[float] = [1.0, 1.18, 1.4, 1.6]
@export var lower_rank_multipliers: Array[float] = [1.0, 0.85, 0.7, 0.55]
@export var sl_light_threshold: int = 50
@export var sl_medium_threshold: int = 70
@export var sl_deviation_threshold: int = 85
@export var sl_light_multiplier: float = 0.9
@export var sl_medium_multiplier: float = 0.8
@export var sl_medium_hit_penalty: float = 15.0
@export var skill_deviation_chance: float = 15.0
@export var advantage_sl_relief: int = 2
@export var repeat_skill_sl_cost: int = 5
@export var dual_skill_cost_multiplier: int = 2
@export var uncontrolled_actions: int = 3
@export var uncontrolled_damage_multiplier: float = 1.5
@export var uncontrolled_recovery_sl: int = 40
@export var ai_defense_threshold: int = 70
@export_group("M1-C breakthrough")
@export var breakthrough_enabled: bool = false
@export var critical_max: int = 100
@export var critical_received_min: int = 8
@export var critical_received_max: int = 12
@export var critical_advantage_gain: int = 15
@export var critical_skill_gain: int = 5
@export var breakthrough_base_chance: float = 60.0
@export var breakthrough_pity_bonus: float = 15.0
@export var breakthrough_pity_limit: int = 2
@export var breakthrough_success_multiplier: float = 1.3
@export var breakthrough_success_heal_ratio: float = 0.5
@export var breakthrough_failure_sl: int = 25
@export var breakthrough_failure_critical: int = 50
@export var breakthrough_weak_actions: int = 1
@export var weak_damage_multiplier: float = 0.5
@export var breakthrough_low_hp_threshold: float = 0.3
@export var breakthrough_low_hp_bonus: float = 0.0
@export var breakthrough_consecutive_bonus: float = 0.0
@export_group("Presentation (seconds)")
@export var presentation_seconds: float = 0.48
@export var enemy_think_seconds: float = 0.55


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if damage_dice_count < 0 or damage_die_min < 1 or damage_die_max < damage_die_min:
		errors.append("伤害骰范围无效")
	if attack_multiplier < 0.0 or defense_coefficient < 0.0 or minimum_hit_damage < 0:
		errors.append("伤害系数不能为负")
	if defense_hp_ratio < 0.0 or defense_hp_ratio > 1.0 or defense_sl_relief < 0:
		errors.append("防御回复参数无效")
	if sl_min != 0 or sl_max != 100 or initiative_die_sides < 2:
		errors.append("本批 SL 边界为 0–100，同速骰至少需要两面")
	if presentation_seconds <= 0.0 or enemy_think_seconds <= 0.0:
		errors.append("演出和敌方等待时长必须为正")
	if higher_rank_multipliers.size() != 4 or lower_rank_multipliers.size() != 4:
		errors.append("等级修正表需要同级、差1、差2、差3以上四项")
	if not (sl_light_threshold < sl_medium_threshold and sl_medium_threshold < sl_deviation_threshold and sl_deviation_threshold < sl_max):
		errors.append("SL 阈值顺序无效")
	if uncontrolled_actions < 1 or uncontrolled_recovery_sl < 0 or uncontrolled_recovery_sl >= sl_max:
		errors.append("失控时长或恢复负荷无效")
	if skill_deviation_chance < 0.0 or skill_deviation_chance > 100.0:
		errors.append("偏离概率必须在 0–100%")
	if breakthrough_enabled and not advanced_enabled:
		errors.append("突破需要启用 M1-B 基础规则")
	if critical_max != 100 or critical_received_min < 0 or critical_received_max < critical_received_min:
		errors.append("临界槽或受击临界范围无效")
	if breakthrough_base_chance < 0.0 or breakthrough_base_chance > 100.0 or breakthrough_pity_limit < 0:
		errors.append("突破概率或保底上限无效")
	if breakthrough_success_multiplier < 1.0 or breakthrough_success_heal_ratio < 0.0 or breakthrough_success_heal_ratio > 1.0:
		errors.append("突破成功参数无效")
	if breakthrough_failure_critical < 0 or breakthrough_failure_critical > critical_max or breakthrough_weak_actions < 1:
		errors.append("突破失败参数无效")
	return errors


func snapshot() -> Dictionary:
	var values: Dictionary = {"version": data_version}
	for property: Dictionary in get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (int(property.usage) & PROPERTY_USAGE_STORAGE) != 0:
			values[String(property.name)] = get(property.name)
	return values
