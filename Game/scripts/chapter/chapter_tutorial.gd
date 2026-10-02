class_name ChapterTutorial
extends TutorialSandbox

signal chapter_finished(hp_value: int, sl_value: int, log_data: Dictionary)
signal chapter_aborted
const DISPLAY_SCRIPT: Script = preload("res://scripts/chapter/chapter_display.gd")
const EFFECTS_SCRIPT: Script = preload("res://scripts/chapter/chapter_battle_effects.gd")
var chapter_state: ChapterSession
var display: ChapterDisplay
var effects: ChapterBattleEffects
var settings: Dictionary = {}
var _leaving: bool = false
var _formation_key: String = ""
var _chapter_copy: Dictionary = {}


func _ready() -> void:
	if chapter_state == null: chapter_state = ChapterSession.new()
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter1/settings.json")) as Dictionary
	_chapter_copy = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter1/tutorial_text.json")) as Dictionary
	display = DISPLAY_SCRIPT.new() as ChapterDisplay
	display.name = "AdaptiveDisplay"
	display.layout_changed.connect(_ensure_views)
	add_child(display)
	effects = EFFECTS_SCRIPT.new() as ChapterBattleEffects
	effects.name = "BattleEffects"
	$WorldContainer/WorldViewport/Arena.add_child(effects)
	effects.configure(hud, display)
	super._ready()
	hud.back_button.text = "后山 [Esc]"
	(hud as TutorialHUD).modal_back_button.text = "返回后山 [Esc]"


func _on_action_presented(action: Dictionary) -> void:
	super._on_action_presented(action)
	if flow == &"battle" and automatic_flow:
		effects.present(action, _views, controller.encounter.rules.presentation_seconds)


func _on_presentation_timeout() -> void:
	effects.clear()
	super._on_presentation_timeout()


func _stop_presentation() -> void:
	if is_instance_valid(effects): effects.clear()
	super._stop_presentation()


func _load_encounter() -> EncounterDefinition:
	var source: EncounterDefinition = super._load_encounter()
	if source == null: return null
	var hero: CombatantDefinition = source.allies[0].definition
	var base: Dictionary = settings.hero
	hero.data_version = String(settings.version)
	hero.affinity = chapter_state.affinity
	hero.max_hp = chapter_state.max_hp()
	hero.attack = float(base.attack)
	hero.defense = float(base.defense)
	hero.speed = int(base.speed)
	hero.perception = int(base.perception)
	hero.accuracy = float(base.accuracy)
	hero.evasion = float(base.evasion)
	var bonus: Dictionary = settings.mentor.get(chapter_state.mentor, {})
	if bonus.has("attribute"):
		var attribute: String = String(bonus.attribute)
		hero.set(attribute, int(hero.get(attribute)) + int(bonus.attribute_bonus))
	hero.skill_sl_multiplier = float(bonus.get("skill_sl_multiplier", 1.0))
	hero.skills.clear()
	var names: Array = settings.skills[chapter_state.affinity]
	for index: int in range(settings.skill_values.size()):
		var values: Dictionary = settings.skill_values[index]
		var skill: SkillDefinition = SkillDefinition.new()
		skill.id = StringName(values.id)
		skill.display_name = String(names[index])
		skill.multiplier = float(values.multiplier)
		skill.sl_cost = int(values.sl_cost)
		skill.cooldown = maxi(0, int(values.cooldown) - int(bonus.get("cooldown_reduction", 0)))
		skill.target_mode = String(values.target_mode)
		hero.skills.append(skill)
	source.allies[0].initial_hp = chapter_state.hp
	source.allies[0].initial_sl = chapter_state.sl
	return source


func _ensure_views() -> void:
	if controller.combatants.is_empty(): return
	super._ensure_views()
	var identifiers: PackedStringArray = []
	for unit: CombatantState in controller.combatants: identifiers.append(String(unit.id))
	var viewport_size: Vector2 = Vector2($WorldContainer/WorldViewport.size)
	var formation: String = ",".join(identifiers) + str(viewport_size)
	if formation != _formation_key and is_instance_valid(effects): effects.clear()
	var enemy_points: Array[Vector2] = []
	var enemy_index: int = 0
	var enemy_count: int = controller.combatants.size() - 1
	var ui_per_world: Vector2 = display.world_to_ui(Vector2.ONE) - display.world_to_ui(Vector2.ZERO)
	var field: Rect2 = (hud as ChapterBattleHUD).battlefield_rect()
	for unit: CombatantState in controller.combatants:
		var path: String = "res://assets/chapter1/refined/lin_da/frames/frame_008.png" if unit.is_player else "res://assets/chapter1/rabbits/frames/frame_%03d.png" % (3 if unit.definition.id == &"rabbit_king" else 1 if unit.definition.affinity == "元素" else 2 if unit.definition.affinity == "强化" else 0)
		var view: CombatantView = _views[unit.id] as CombatantView
		view.art_texture = load(path) as Texture2D
		view.scale = Vector2(3.0, 3.0)
		var home: Vector2 = Vector2(250, 334)
		if not unit.is_player:
			home = Vector2(690, 334) if enemy_count == 1 else [Vector2(630, 236), Vector2(790, 310), Vector2(620, 400)][enemy_index]
		home = (home * viewport_size / Vector2(960, 540)).round()
		# Integer enlargement can crop the reference height. Keep the entire sprite
		# below the status bar and above the command bar at every window size.
		var top_limit: float = field.position.y / ui_per_world.y - view._art_rect.position.y * view.scale.y + 8.0
		var bottom_limit: float = field.end.y / ui_per_world.y - view._art_rect.end.y * view.scale.y - 8.0
		home.y = clampf(home.y, top_limit, bottom_limit)
		home.x = clampf(home.x, -view._art_rect.position.x * view.scale.x + 8.0, viewport_size.x - view._art_rect.end.x * view.scale.x - 8.0)
		home = home.round()
		if not unit.is_player:
			enemy_points.append(home)
			enemy_index += 1
		if formation != _formation_key: view.set_home(home)
	_formation_key = formation
	(hud as ChapterBattleHUD).set_enemy_hit_positions(enemy_points, display)


func _refresh_tutorial_view() -> void:
	_apply_chapter_copy()
	super._refresh_tutorial_view()
	if tutorial == null or not _fatal_error.is_empty(): return
	var tutorial_hud: TutorialHUD = hud as TutorialHUD
	tutorial_hud._heading.text = "第1章 · 后山野兔清剿"
	if chapter_state != null and chapter_state.affinity == "特殊" and lesson_index == 0:
		tutorial_hud._coach_text.text = "苏挽颜：先挑一只你有把握的。\n系统提示：特殊系在基础克制环外。先看预览，再选择目标。" if hints_enabled else "提示已隐藏，按 H 恢复。"
	if flow == &"complete":
		tutorial_hud.primary_button.text = "回到后山 [Enter]"
		tutorial_hud._modal_body.text = "三段清剿完成。\n带着当前HP/SL回入口，向苏挽颜交差。"


func _apply_chapter_copy() -> void:
	if tutorial == null or _chapter_copy.is_empty(): return
	# This instance owns its loaded copy; numerical M1-D resources stay intact.
	tutorial.introduction = ""
	tutorial.conclusion = ""
	for index: int in range(tutorial.lessons.size()):
		var entries: Dictionary = _chapter_copy.get("m1_d_lesson_%d" % (index + 1), {})
		for field: String in entries:
			tutorial.lessons[index].set(field, _copy_line(entries[field]))
	for field: String in _chapter_copy.get("m1_d_tutorial", {}):
		tutorial.set(field, _copy_line(_chapter_copy.m1_d_tutorial[field]))


func _copy_line(entry: Dictionary) -> String:
	return "苏挽颜：%s\n系统提示：%s" % [String(entry.dialogue), String(entry.system)]


func _on_primary() -> void:
	if flow == &"complete" and not _leaving:
		var hero: CombatantState = controller.get_combatant(_player_id)
		if hero == null or not hero.is_alive(): return
		_leaving = true
		_stop_presentation()
		chapter_finished.emit(hero.hp, hero.sl, tutorial_snapshot())
	else:
		super._on_primary()


func _return_to_m0() -> void:
	if _leaving: return
	_leaving = true
	_stop_presentation()
	chapter_aborted.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var chapter_hud: ChapterBattleHUD = hud as ChapterBattleHUD
		if event.physical_keycode == KEY_L:
			chapter_hud.toggle_log()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_ESCAPE and chapter_hud.log_drawer.visible:
			chapter_hud.log_drawer.hide()
			get_viewport().set_input_as_handled()
			return
	super._input(event)
