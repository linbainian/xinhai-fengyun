class_name CombatantSetup
extends Resource

@export var instance_id: StringName = &""
@export var definition: CombatantDefinition
@export var initial_hp: int = -1
@export var initial_sl: int = 0
@export var initial_critical: int = 0


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if definition == null:
		errors.append("出场配置缺少单位定义")
		return errors
	errors.append_array(definition.validation_errors())
	if instance_id == &"" or initial_hp == 0 or initial_hp < -1:
		errors.append("出场实例需要唯一 id 和存活开场 HP")
	if initial_critical < 0 or initial_critical > 100:
		errors.append("开场临界槽必须在 0–100")
	return errors
