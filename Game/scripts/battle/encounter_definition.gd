class_name EncounterDefinition
extends Resource

@export var id: StringName = &""
@export var title: String = "M1-A 战斗沙盒"
@export var data_version: String = "m1-a.1"
@export var rules: BattleRules
# Preserve the original A fixture and resource paths.
@export var ally: CombatantDefinition
@export var enemy: CombatantDefinition
@export var seed_value: int = 220101
@export var ally_initial_hp: int = -1
@export var ally_initial_sl: int = 0
@export var enemy_initial_hp: int = -1
@export var enemy_initial_sl: int = 0
@export var affinity_modifier: float = 1.0
@export var environment_modifier: float = 1.0
@export var rank_modifier: float = 1.0
@export_group("Multi-unit encounters")
@export var allies: Array[CombatantSetup] = []
@export var enemies: Array[CombatantSetup] = []
@export var environment_by_affinity: Dictionary = {}
@export var previous_battles: int = 0


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if rules == null:
		errors.append("遭遇缺少规则")
		return errors
	errors.append_array(rules.validation_errors())
	var slots: Array[CombatantSetup] = get_setups()
	var ids: Array[StringName] = []
	if not allies.is_empty() or not enemies.is_empty():
		if allies.is_empty() or allies.size() > 4 or enemies.is_empty() or enemies.size() > 6:
			errors.append("战斗需要 1–4 名友方和 1–6 名敌方")
		if not rules.advanced_enabled:
			errors.append("多单位遭遇需要启用 M1-B 规则")
	for slot: CombatantSetup in slots:
		if slot == null:
			errors.append("出场配置不能为空")
			continue
		errors.append_array(slot.validation_errors())
		if ids.has(slot.instance_id):
			errors.append("出场实例 id 不能重复")
		ids.append(slot.instance_id)
		if slot.definition != null:
			if not rules.rank_order.has(slot.definition.awakening_rank):
				errors.append("未知觉醒等级")
			if not rules.affinities.has(slot.definition.affinity):
				errors.append("未知系别")
	if not rules.advanced_enabled and ally != null and enemy != null:
		if ally.awakening_rank != enemy.awakening_rank:
			errors.append("M1-A 测试遭遇必须同等级")
		if affinity_modifier != 1.0 or environment_modifier != 1.0 or rank_modifier != 1.0:
			errors.append("M1-A 只启用中性修正 ×1")
	for affinity_key: String in environment_by_affinity:
		var modifier: float = float(environment_by_affinity[affinity_key])
		if not rules.affinities.has(affinity_key) or modifier < 0.7 or modifier > 1.2:
			errors.append("环境系别或修正无效（范围 0.7–1.2）")
	return errors


func get_setups() -> Array[CombatantSetup]:
	if not allies.is_empty() or not enemies.is_empty():
		var combined: Array[CombatantSetup] = []
		combined.append_array(allies)
		combined.append_array(enemies)
		return combined
	var first: CombatantSetup = CombatantSetup.new()
	first.instance_id = ally.id if ally != null else &""
	first.definition = ally
	first.initial_hp = ally_initial_hp
	first.initial_sl = ally_initial_sl
	var second: CombatantSetup = CombatantSetup.new()
	second.instance_id = enemy.id if enemy != null else &""
	second.definition = enemy
	second.initial_hp = enemy_initial_hp
	second.initial_sl = enemy_initial_sl
	return [first, second]


func ally_count() -> int:
	return allies.size() if not allies.is_empty() else 1
