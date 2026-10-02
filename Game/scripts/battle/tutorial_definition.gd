class_name TutorialDefinition
extends Resource

@export var id: StringName = &"back_hill"
@export var data_version: String = "m1-d.1"
@export var title: String = "后山野兔清剿"
@export var guide_name: String = "苏挽颜"
@export var guide_identity: String = "B级冰系 · 大二青梅学姐"
@export_multiline var introduction: String = ""
@export_multiline var conclusion: String = ""
@export_multiline var overload_hint: String = ""
@export_multiline var breakthrough_hint: String = ""
@export_multiline var uncontrolled_hint: String = ""
@export_multiline var weakness_hint: String = ""
@export var lessons: Array[TutorialLesson] = []


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if lessons.size() != 3:
		errors.append("后山教程需要三个段落")
	var ids: Array[StringName] = []
	var player_id: StringName = &""
	var definition_id: StringName = &""
	for lesson: TutorialLesson in lessons:
		if lesson == null:
			errors.append("教程段落不能为空")
			continue
		errors.append_array(lesson.validation_errors())
		if ids.has(lesson.id):
			errors.append("教程段落编号不能重复")
		ids.append(lesson.id)
		if not ResourceLoader.exists(lesson.encounter_path):
			continue
		var source: EncounterDefinition = ResourceLoader.load(lesson.encounter_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EncounterDefinition
		if source == null:
			errors.append("无法读取教程遭遇")
			continue
		errors.append_array(source.validation_errors())
		if source.allies.size() != 1:
			errors.append("本次后山教程由一名主角独自战斗")
			continue
		var slot: CombatantSetup = source.allies[0]
		if slot == null or slot.definition == null:
			continue
		if player_id == &"":
			player_id = slot.instance_id
			definition_id = slot.definition.id
		elif player_id != slot.instance_id or definition_id != slot.definition.id:
			errors.append("连续教程必须使用同一角色与实例编号")
	return errors
