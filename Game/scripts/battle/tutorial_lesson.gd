class_name TutorialLesson
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export_file("*.tres") var encounter_path: String = ""
@export_multiline var introduction: String = ""
@export_multiline var opening_hint: String = ""
@export_multiline var attack_hint: String = ""
@export_multiline var skill_hint: String = ""
@export_multiline var defense_hint: String = ""
@export var goals: PackedStringArray = []


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"" or title.is_empty() or not ResourceLoader.exists(encounter_path):
		errors.append("教程段落需要编号、标题和有效遭遇路径")
	for goal: String in goals:
		if not ["attack", "target", "skill", "defend"].has(goal):
			errors.append("未知教学观察项")
	return errors
