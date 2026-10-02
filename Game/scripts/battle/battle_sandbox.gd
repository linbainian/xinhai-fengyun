class_name BattleSandbox
extends Control

const COMBATANT_SCENE: PackedScene = preload("res://scenes/battle/combatant.tscn")
@export_file("*.tres") var encounter_path: String = "res://data/battle/m1_a_encounter.tres"
var automatic_flow: bool = true
var _views: Dictionary = {}

@onready var controller: BattleController = $BattleController
@onready var hud: BattleHUD = $UI/LogicalUI
@onready var ally_view: CombatantView = $WorldContainer/WorldViewport/Arena/Ally
@onready var enemy_view: CombatantView = $WorldContainer/WorldViewport/Arena/Enemy
@onready var enemy_timer: Timer = $EnemyTimer
@onready var presentation_timer: Timer = $PresentationTimer


func _ready() -> void:
	controller.state_changed.connect(_on_state_changed)
	controller.action_presented.connect(_on_action_presented)
	hud.command_requested.connect(_on_command_requested)
	hud.retry_requested.connect(restart_battle)
	hud.export_requested.connect(_export_log)
	hud.back_requested.connect(_return_to_m0)
	hud.target_selected.connect(_on_target_selected)
	if hud is AdvancedBattleHUD:
		(hud as AdvancedBattleHUD).skill_requested.connect(_on_skill_requested)
	enemy_timer.timeout.connect(_on_enemy_timeout)
	presentation_timer.timeout.connect(_on_presentation_timeout)
	restart_battle()
	print("[%s] Ready | world=960x540 | UI=1920x1080" % controller.log_snapshot().stage)


func restart_battle() -> void:
	_stop_presentation()
	hud.clear_export_result()
	var source: EncounterDefinition = ResourceLoader.load(encounter_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EncounterDefinition
	controller.start_battle(source)


func _input(event: InputEvent) -> void:
	# Tab normally belongs to GUI focus navigation; reserve it before the GUI consumes it.
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB and hud is AdvancedBattleHUD:
		(hud as AdvancedBattleHUD).cycle_target()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match key:
		KEY_A:
			_on_command_requested(&"attack", hud.selected_target)
		KEY_D:
			_on_command_requested(&"defend", &"")
		KEY_B:
			_on_command_requested(&"breakthrough", &"")
		KEY_R:
			restart_battle()
		KEY_E:
			_export_log()
		KEY_1, KEY_2, KEY_3:
			if hud is AdvancedBattleHUD:
				(hud as AdvancedBattleHUD).request_skill(key - KEY_1)
		KEY_TAB:
			if hud is AdvancedBattleHUD:
				(hud as AdvancedBattleHUD).cycle_target()
		KEY_F11:
			get_window().mode = Window.MODE_WINDOWED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		_:
			return
	get_viewport().set_input_as_handled()


func _on_command_requested(command: StringName, target_id: StringName) -> void:
	controller.submit_player_command(command, target_id)


func _on_skill_requested(skill_id: StringName, target_id: StringName) -> void:
	controller.submit_player_command(&"skill", target_id, skill_id)


func _on_state_changed() -> void:
	hud.refresh(controller)
	_ensure_views()
	var actor: CombatantState = controller.current_actor()
	for unit: CombatantState in controller.combatants:
		var view: CombatantView = _views[unit.id]
		view.update_state(unit, actor == unit, hud.selected_target == unit.id)
	if automatic_flow and (controller.phase == BattleController.Phase.ENEMY_COMMAND or controller.phase == BattleController.Phase.AUTO_COMMAND):
		enemy_timer.start(controller.encounter.rules.enemy_think_seconds)


func _ensure_views() -> void:
	var rebuild: bool = _views.size() != controller.combatants.size()
	for unit: CombatantState in controller.combatants:
		if not _views.has(unit.id):
			rebuild = true
	if not rebuild:
		return
	for view: CombatantView in _views.values():
		if view != ally_view and view != enemy_view:
			view.free()
	_views.clear()
	ally_view.hide()
	enemy_view.hide()
	var allies: int = controller.living_team(true).size()
	var enemies: int = controller.living_team(false).size()
	var ally_index: int = 0
	var enemy_index: int = 0
	for unit: CombatantState in controller.combatants:
		var index: int = ally_index if unit.is_player else enemy_index
		var count: int = allies if unit.is_player else enemies
		var view: CombatantView
		if index == 0:
			view = ally_view if unit.is_player else enemy_view
		else:
			view = COMBATANT_SCENE.instantiate()
			$WorldContainer/WorldViewport/Arena.add_child(view)
		view.show()
		var home: Vector2 = Vector2(304 if unit.is_player else 656, 286)
		if count > 1:
			if count <= 2:
				home.y = 216 + index * 88
			elif unit.is_player:
				home = Vector2(272 + (index % 2) * 72, 216 + floori(index / 2.0) * 88)
			else:
				home = Vector2(616 + (index % 2) * 72, 176 + floori(index / 2.0) * 68)
		view.set_home(home)
		_views[unit.id] = view
		if unit.is_player:
			ally_index += 1
		else:
			enemy_index += 1


func _on_action_presented(action: Dictionary) -> void:
	if not automatic_flow:
		return
	var view: CombatantView = _views[StringName(action.actor_id)]
	view.animate_action(StringName(action.command), controller.encounter.rules.presentation_seconds)
	presentation_timer.start(controller.encounter.rules.presentation_seconds)


func _on_enemy_timeout() -> void:
	controller.submit_enemy_command()


func _on_presentation_timeout() -> void:
	for view: CombatantView in _views.values():
		view.finish_animation()
	controller.complete_presentation()


func _on_target_selected(id: StringName) -> void:
	controller.record_target_choice(id)
	_on_state_changed()


func _export_log() -> void:
	var error: Error = controller.export_log()
	hud.show_export_result(error, controller.last_export_path)
	if error == OK:
		print("[M1] Log exported: ", controller.last_export_path)


func _return_to_m0() -> void:
	_stop_presentation()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _stop_presentation() -> void:
	enemy_timer.stop()
	presentation_timer.stop()
	ally_view.finish_animation()
	enemy_view.finish_animation()
	for view: CombatantView in _views.values():
		view.finish_animation()


func _exit_tree() -> void:
	_stop_presentation()
