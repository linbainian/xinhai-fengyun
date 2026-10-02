class_name TutorialSandbox
extends BattleSandbox

@export_file("*.tres") var tutorial_path: String = "res://data/battle/tutorial/m1_d_tutorial.tres"
var tutorial: TutorialDefinition
var lesson_index: int = 0
var flow: StringName = &"intro"
var hints_enabled: bool = true
var attempts: Array[Dictionary] = []
var completed_lessons: Array[StringName] = []
var checkpoints: Array[Dictionary] = []
var tutorial_events: Array[Dictionary] = []
var last_export_path: String = ""
var _opening: Dictionary = {}
var _carry: Dictionary = {}
var _attempt_number: int = 0
var _fatal_error: String = ""
var _player_id: StringName = &""
var _definition_id: StringName = &""


func _ready() -> void:
	tutorial = ResourceLoader.load(tutorial_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as TutorialDefinition
	controller.battle_finished.connect(_on_lesson_finished)
	var tutorial_hud: TutorialHUD = hud as TutorialHUD
	tutorial_hud.primary_requested.connect(_on_primary)
	tutorial_hud.secondary_requested.connect(_on_secondary)
	tutorial_hud.hints_requested.connect(toggle_hints)
	tutorial_hud.replay_requested.connect(replay_tutorial)
	super._ready()
	print("[M1-D] Ready | three lessons | guide remains outside battle")


func restart_battle() -> void:
	if _opening.is_empty():
		_reset_run()
		return
	if flow == &"error":
		return
	if flow == &"battle":
		_archive_attempt("retry")
	while completed_lessons.size() > lesson_index:
		completed_lessons.pop_back()
	_carry.clear()
	_stop_presentation()
	if flow != &"intro":
		flow = &"battle"
	_record_flow("retry")
	_launch_lesson()


func begin_tutorial(with_hints: bool = true) -> void:
	if flow != &"intro" or not _fatal_error.is_empty():
		return
	hints_enabled = with_hints
	flow = &"battle"
	_record_flow("begin", {"hints": hints_enabled})
	_on_state_changed()


func advance_lesson() -> void:
	if flow != &"between":
		return
	_stop_presentation()
	lesson_index += 1
	flow = &"battle"
	if not _prepare_opening(_carry):
		return
	_record_flow("advance")
	_launch_lesson()


func replay_tutorial(quick: bool = false) -> void:
	_stop_presentation()
	tutorial = ResourceLoader.load(tutorial_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as TutorialDefinition
	_reset_run()
	if quick:
		begin_tutorial(false)


func toggle_hints() -> void:
	hints_enabled = not hints_enabled
	_record_flow("hints", {"enabled": hints_enabled})
	_refresh_tutorial_view()


func _reset_run() -> void:
	lesson_index = 0
	flow = &"intro"
	hints_enabled = true
	attempts.clear()
	completed_lessons.clear()
	checkpoints.clear()
	tutorial_events.clear()
	_opening.clear()
	_carry.clear()
	_attempt_number = 0
	_fatal_error = ""
	_player_id = &""
	_definition_id = &""
	last_export_path = ""
	hud.clear_export_result()
	if tutorial == null:
		_fatal_error = "无法加载教程配表"
	else:
		_fatal_error = "；".join(tutorial.validation_errors())
	if not _fatal_error.is_empty():
		flow = &"error"
		controller.start_battle(null)
		_refresh_tutorial_view()
		return
	if not _prepare_opening({}):
		return
	_launch_lesson()


func _load_encounter() -> EncounterDefinition:
	return ResourceLoader.load(tutorial.lessons[lesson_index].encounter_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EncounterDefinition


func _prepare_opening(carried: Dictionary) -> bool:
	var source: EncounterDefinition = _load_encounter()
	if not _validate_source(source):
		return false
	_opening.clear()
	for slot: CombatantSetup in source.allies:
		var values: Dictionary = carried.get(slot.instance_id, {})
		var hp: int = source_value_hp(slot)
		if not values.is_empty():
			hp = mini(int(values.hp), slot.definition.max_hp)
		var sl: int = slot.initial_sl if values.is_empty() else int(values.sl)
		_opening[slot.instance_id] = {"hp": hp, "sl": clampi(sl, 0, 100)}
	checkpoints.append({"lesson": lesson_index + 1, "units": _opening.duplicate(true)})
	return true


func _validate_source(source: EncounterDefinition) -> bool:
	var errors: PackedStringArray = PackedStringArray(["无法读取遭遇配表"]) if source == null else source.validation_errors()
	if errors.is_empty():
		if source.allies.size() != 1:
			errors.append("本次后山教程由一名主角独自战斗；修改队伍后请从头重玩")
		else:
			var slot: CombatantSetup = source.allies[0]
			if _player_id == &"":
				_player_id = slot.instance_id
				_definition_id = slot.definition.id
			elif slot.instance_id != _player_id or slot.definition.id != _definition_id:
				errors.append("连续教程的角色或实例编号已改变；检查三段配表后请从头重玩")
	if errors.is_empty():
		return true
	_fatal_error = "；".join(errors)
	flow = &"error"
	controller.start_battle(null)
	_refresh_tutorial_view()
	return false


func source_value_hp(slot: CombatantSetup) -> int:
	return slot.definition.max_hp if slot.initial_hp < 0 else mini(slot.initial_hp, slot.definition.max_hp)


func _launch_lesson() -> void:
	_stop_presentation()
	hud.clear_export_result()
	var source: EncounterDefinition = _load_encounter()
	if not _validate_source(source):
		return
	for slot: CombatantSetup in source.allies:
		slot.initial_hp = mini(int(_opening[slot.instance_id].hp), slot.definition.max_hp)
		slot.initial_sl = int(_opening[slot.instance_id].sl)
		slot.initial_critical = 0
	source.previous_battles = lesson_index
	hud.selected_target = &""
	(hud as TutorialHUD)._preview_skill = &""
	_attempt_number += 1
	if not controller.start_battle(source):
		_fatal_error = controller.error_message
		flow = &"error"
	_refresh_tutorial_view()


func _on_state_changed() -> void:
	(hud as TutorialHUD).command_locked = flow != &"battle"
	var configured_flow: bool = automatic_flow
	automatic_flow = configured_flow and flow == &"battle"
	super._on_state_changed()
	automatic_flow = configured_flow
	_refresh_tutorial_view()


func _on_command_requested(command: StringName, target_id: StringName) -> void:
	if flow == &"battle":
		super._on_command_requested(command, target_id)


func _on_skill_requested(skill_id: StringName, target_id: StringName) -> void:
	if flow == &"battle":
		super._on_skill_requested(skill_id, target_id)


func _on_target_selected(id: StringName) -> void:
	if flow == &"battle":
		super._on_target_selected(id)


func _on_enemy_timeout() -> void:
	if flow == &"battle":
		super._on_enemy_timeout()


func _on_presentation_timeout() -> void:
	if flow == &"battle":
		super._on_presentation_timeout()


func _on_action_presented(action: Dictionary) -> void:
	if flow == &"battle":
		super._on_action_presented(action)


func _on_lesson_finished(result_value: StringName) -> void:
	if flow != &"battle":
		return
	_stop_presentation()
	_archive_attempt(String(result_value))
	_record_flow("lesson_result", {"result": String(result_value)})
	if result_value == &"victory":
		completed_lessons.append(tutorial.lessons[lesson_index].id)
		_carry.clear()
		for unit: CombatantState in controller.living_team(true):
			_carry[unit.id] = {"hp": unit.hp, "sl": unit.sl}
		flow = &"complete" if lesson_index == tutorial.lessons.size() - 1 else &"between"
	else:
		flow = &"failed"
	_refresh_tutorial_view()


func _archive_attempt(outcome: String) -> void:
	attempts.append({"attempt": _attempt_number, "lesson": lesson_index + 1,
		"lesson_id": String(tutorial.lessons[lesson_index].id), "outcome": outcome,
		"battle": controller.log_snapshot()})


func _record_flow(kind: String, details: Dictionary = {}) -> void:
	tutorial_events.append({"sequence": tutorial_events.size(), "lesson": lesson_index + 1,
		"kind": kind, "details": details.duplicate(true)})


func observed_goals() -> PackedStringArray:
	var observed: PackedStringArray = []
	for event: Dictionary in controller.events:
		if event.kind == "target_selected" and not observed.has("target"):
			observed.append("target")
		elif event.kind == "action":
			var actor: CombatantState = controller.get_combatant(StringName(event.details.actor_id))
			var command: String = event.details.command
			if actor.is_player and not observed.has(command):
				observed.append(command)
	return observed


func _refresh_tutorial_view() -> void:
	if not _fatal_error.is_empty():
		(hud as TutorialHUD).show_error(_fatal_error)
		return
	if tutorial == null or tutorial.lessons.size() != 3:
		return
	var lesson: TutorialLesson = tutorial.lessons[lesson_index]
	var labels: Dictionary = {"target": "观察目标", "attack": "普攻", "skill": "用技能", "defend": "防御降压"}
	var observations: PackedStringArray = observed_goals()
	var goals: PackedStringArray = []
	for goal: String in lesson.goals:
		goals.append(String(labels[goal]) + (" ✓" if observations.has(goal) else " ○"))
	var modal_text: String = ""
	match flow:
		&"intro":
			modal_text = tutorial.introduction + "\n\n" + lesson.introduction
		&"between":
			var next: TutorialLesson = tutorial.lessons[lesson_index + 1]
			modal_text = "这一段已经清完。\nHP/SL直接带入下一段，期间不会自动回复。\n\n接下来：" + next.title + "\n" + next.introduction
		&"complete":
			modal_text = tutorial.conclusion + "\n\n三段均已完成。可按E导出整段记录，或重玩检查不同选择。"
		&"failed":
			modal_text = "先退回入口缓一缓。\n重试恢复本段开场HP/SL，不必重打前面的段落。\n看看负荷与剩余血量，再决定何时用技能、何时防御。"
		&"error":
			modal_text = _fatal_error
	var checkpoint_text: String = ""
	if not _opening.is_empty():
		var values: Dictionary = _opening.values()[0]
		checkpoint_text = "本段开场：HP %d · SL %d" % [values.hp, values.sl]
	if (flow == &"between" or flow == &"complete") and not _carry.is_empty():
		var values: Dictionary = _carry.values()[0]
		checkpoint_text = "当前：HP %d · SL %d  /  已完成 %d/3段" % [values.hp, values.sl, completed_lessons.size()]
	(hud as TutorialHUD).present_lesson(tutorial, lesson_index, flow, hints_enabled,
		_current_hint(), " · ".join(goals), modal_text, checkpoint_text)


func _current_hint() -> String:
	var lesson: TutorialLesson = tutorial.lessons[lesson_index]
	var players: Array[CombatantState] = controller.living_team(true)
	if players.is_empty():
		return lesson.opening_hint
	var unit: CombatantState = players[0]
	if unit.uncontrolled_remaining > 0:
		return tutorial.uncontrolled_hint
	if unit.weak_actions > 0:
		return tutorial.weakness_hint
	if controller.can_breakthrough(unit):
		return tutorial.breakthrough_hint
	if unit.sl >= controller.encounter.rules.ai_defense_threshold:
		return tutorial.overload_hint
	for index: int in range(controller.events.size() - 1, -1, -1):
		var event: Dictionary = controller.events[index]
		if event.kind != "action" or String(event.details.actor_id) != String(unit.id):
			continue
		match event.details.command:
			"skill":
				return lesson.skill_hint
			"defend":
				return lesson.defense_hint
			"attack":
				return lesson.attack_hint
	return lesson.opening_hint


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		match key:
			KEY_H:
				toggle_hints()
			KEY_T:
				replay_tutorial()
			KEY_ESCAPE:
				_return_to_m0()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if flow == &"battle":
					super._input(event)
					return
				_on_primary()
			_:
				super._input(event)
				return
		get_viewport().set_input_as_handled()
		return
	super._input(event)


func _on_primary() -> void:
	match flow:
		&"intro":
			begin_tutorial(hints_enabled)
		&"between":
			advance_lesson()
		&"failed":
			restart_battle()
		&"complete":
			replay_tutorial()


func _on_secondary() -> void:
	match flow:
		&"intro":
			begin_tutorial(false)
		&"between":
			restart_battle()
		&"failed":
			replay_tutorial()
		&"complete":
			replay_tutorial(true)


func tutorial_snapshot() -> Dictionary:
	return {"stage": "M1-D", "tutorial_id": String(tutorial.id) if tutorial != null else "",
		"version": tutorial.data_version if tutorial != null else "", "flow": String(flow),
		"lesson": lesson_index + 1, "hints_enabled": hints_enabled,
		"completed_lessons": completed_lessons.duplicate(), "checkpoints": checkpoints.duplicate(true),
		"navigation": tutorial_events.duplicate(true), "attempts": attempts.duplicate(true),
		"current_battle": controller.log_snapshot() if controller.encounter != null else {}}


func export_tutorial_log(destination: String = "") -> Error:
	if not _fatal_error.is_empty() or tutorial == null:
		return ERR_UNCONFIGURED
	var path: String = destination
	if path.is_empty():
		path = "user://battle_logs/m1-d_%d_%d.json" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if directory_error != OK:
		return directory_error
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(tutorial_snapshot(), "\t"))
	file.close()
	last_export_path = ProjectSettings.globalize_path(path)
	return OK


func _export_log() -> void:
	var error: Error = export_tutorial_log()
	hud.show_export_result(error, last_export_path)
	if error == OK:
		print("[M1-D] Tutorial log exported: ", last_export_path)
