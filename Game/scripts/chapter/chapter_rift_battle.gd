class_name ChapterRiftBattle
extends BattleSandbox

signal rift_finished(encounter: String, vitals: Dictionary, log_data: Dictionary)
signal rift_aborted

var chapter_state: ChapterSession
var encounter_id: String = "entry"
var config: Dictionary
var display: ChapterDisplay
var effects: ChapterBattleEffects
var _leaving: bool = false
var _art: Dictionary = {}
var _formation: String = ""


func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter2/settings.json")) as Dictionary
	display = ChapterDisplay.new()
	display.layout_changed.connect(_ensure_views)
	add_child(display)
	effects = ChapterBattleEffects.new()
	$WorldContainer/WorldViewport/Arena.add_child(effects)
	effects.configure(hud,display)
	controller.battle_finished.connect(_on_finished)
	(hud as ChapterRiftHUD).primary_requested.connect(_on_primary)
	(hud as ChapterRiftHUD).secondary_requested.connect(_return_to_m0)
	super._ready()


func build_encounter() -> EncounterDefinition:
	var source: EncounterDefinition = EncounterDefinition.new()
	source.id = StringName("chapter2_"+encounter_id)
	source.title = String(config.encounters[encounter_id].title)
	source.data_version = String(config.version)
	source.seed_value = int(config.encounters[encounter_id].seed)
	source.previous_battles = chapter_state.chapter_two.cleared.size()
	source.rules = BattleRules.new()
	source.rules.advanced_enabled = true
	source.rules.breakthrough_enabled = true
	source.environment_by_affinity = {"元素":1.15,"念动力":1.15,"强化":1.15,"精神":1.15,"特殊":1.15}
	_art.clear()
	var growth: ChapterCultivation = ChapterCultivation.new(chapter_state)
	var attributes: Dictionary = growth.attributes()
	var stats: Dictionary = growth.combat_stats()
	var hero: CombatantDefinition = _unit("lin_da",{"name":"林大","rank":growth.data().rank,"affinity":chapter_state.affinity,
		"max_hp":chapter_state.max_hp(),"attack":stats.attack,
		"defense":stats.defense,"speed":stats.speed,"accuracy":100,"evasion":2,
		"art":"res://assets/chapter1/refined/lin_da/frames/frame_008.png"})
	var bonus: Dictionary = chapter_state.settings.mentor.get(chapter_state.mentor,{})
	for attribute: String in attributes: hero.set(attribute,int(attributes[attribute]))
	hero.skill_sl_multiplier = float(bonus.get("skill_sl_multiplier",1.0))*float(stats.load)
	for index: int in range(chapter_state.settings.skill_values.size()):
		var values: Dictionary = chapter_state.settings.skill_values[index]
		var proficiency: int = int(growth.data().proficiency["strike" if index==0 else "sweep"])
		hero.skills.append(_skill(String(values.id),String(chapter_state.settings.skills[chapter_state.affinity][index]),float(values.multiplier)*float(stats.power)*ChapterCultivation.proficiency_bonus(proficiency),int(values.sl_cost),maxi(0,int(values.cooldown)-int(bonus.get("cooldown_reduction",0))),String(values.target_mode)))
	source.allies.append(_slot(hero,chapter_state.hp,chapter_state.sl))
	for id: String in chapter_state.chapter_two.party:
		var values: Dictionary = config.party[id]
		var unit: CombatantDefinition = _unit(id,values)
		if values.has("skill_name"):
			unit.skills.append(_skill(id+"_skill",String(values.skill_name),float(values.skill_multiplier),int(values.skill_sl),int(values.skill_cooldown)))
		var vitals: Dictionary = chapter_state.chapter_two.party_vitals[id]
		if int(vitals.hp) > 0: source.allies.append(_slot(unit,int(vitals.hp),int(vitals.sl)))
	for values: Dictionary in config.encounters[encounter_id].enemies:
		source.enemies.append(_slot(_unit(String(values.id),values),int(values.max_hp),0))
	return source


func _unit(id: String, values: Dictionary) -> CombatantDefinition:
	var unit: CombatantDefinition = CombatantDefinition.new()
	unit.id = StringName(id)
	unit.display_name = String(values.name)
	unit.data_version = String(config.version)
	unit.awakening_rank = String(values.rank)
	unit.affinity = String(values.affinity)
	unit.max_hp = int(values.max_hp)
	unit.attack = float(values.attack)
	unit.defense = float(values.defense)
	unit.speed = int(values.speed)
	unit.accuracy = float(values.get("accuracy",100))
	unit.evasion = float(values.get("evasion",0))
	_art[id] = String(values.art)
	return unit


func _slot(unit: CombatantDefinition, hp: int, sl: int) -> CombatantSetup:
	var slot: CombatantSetup = CombatantSetup.new()
	slot.instance_id = unit.id
	slot.definition = unit
	slot.initial_hp = hp
	slot.initial_sl = sl
	return slot


func _skill(id: String, label: String, multiplier: float, sl: int, cooldown: int, targeting: String = "single_enemy") -> SkillDefinition:
	var skill: SkillDefinition = SkillDefinition.new()
	skill.id = StringName(id)
	skill.display_name = label
	skill.multiplier = multiplier
	skill.sl_cost = sl
	skill.cooldown = cooldown
	skill.target_mode = targeting
	return skill


func restart_battle() -> void:
	_stop_presentation()
	_formation = ""
	(hud as ChapterRiftHUD)._overlay.hide()
	controller.start_battle(build_encounter())


func _ensure_views() -> void:
	if controller.combatants.is_empty(): return
	super._ensure_views()
	var area: Vector2 = Vector2($WorldContainer/WorldViewport.size)
	var identifiers: Array[String] = []
	for unit: CombatantState in controller.combatants: identifiers.append(String(unit.id))
	var key: String = ",".join(identifiers)+str(area)
	var allies: int = controller.encounter.allies.size()
	var enemies: int = controller.encounter.enemies.size()
	var ally_index: int = 0
	var enemy_index: int = 0
	var hit_positions: Array[Vector2] = []
	var field: Rect2 = (hud as ChapterRiftHUD).battlefield_rect()
	var ratio: Vector2 = display.world_to_ui(Vector2.ONE)-display.world_to_ui(Vector2.ZERO)
	for unit: CombatantState in controller.combatants:
		var view: CombatantView = _views[unit.id]
		view.art_texture = load(String(_art[String(unit.id)])) as Texture2D
		view.scale = Vector2(3,3)
		var index: int = ally_index if unit.is_player else enemy_index
		var count: int = allies if unit.is_player else enemies
		var home: Vector2 = Vector2(244 if unit.is_player else 720,334)
		if count > 1: home = Vector2((200 if unit.is_player else 670)+(index%2)*115,245+floori(index/2.0)*130+(index%2)*65)
		home = (home*area/Vector2(960,540)).round()
		home.y = clampf(home.y,field.position.y/ratio.y-view._art_rect.position.y*3+8,field.end.y/ratio.y-view._art_rect.end.y*3-8)
		home.x = clampf(home.x,-view._art_rect.position.x*3+8,area.x-view._art_rect.end.x*3-8)
		if key != _formation: view.set_home(home.round())
		if unit.is_player: ally_index += 1
		else: enemy_index += 1; hit_positions.append(home)
	_formation = key
	(hud as ChapterRiftHUD).set_enemy_hit_positions(hit_positions,display)


func _on_action_presented(action: Dictionary) -> void:
	super._on_action_presented(action)
	if automatic_flow: effects.present(action,_views,controller.encounter.rules.presentation_seconds)


func _on_presentation_timeout() -> void:
	effects.clear()
	super._on_presentation_timeout()


func _stop_presentation() -> void:
	if is_instance_valid(effects): effects.clear()
	super._stop_presentation()


func _on_finished(result: StringName) -> void:
	(hud as ChapterRiftHUD).show_result(result == &"victory")


func _on_primary() -> void:
	if controller.phase != BattleController.Phase.FINISHED or _leaving: return
	if controller.result != &"victory": restart_battle(); return
	_leaving = true
	_stop_presentation()
	var vitals: Dictionary = chapter_state.chapter_two.party_vitals.duplicate(true)
	for unit: CombatantState in controller.combatants:
		if unit.is_player: vitals[String(unit.id)] = {"hp":unit.hp,"sl":unit.sl}
	rift_finished.emit(encounter_id,vitals,controller.log_snapshot())


func _return_to_m0() -> void:
	if _leaving: return
	_leaving = true
	_stop_presentation()
	rift_aborted.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_L:
			(hud as ChapterRiftHUD).toggle_log()
		elif key == KEY_ESCAPE:
			if (hud as ChapterRiftHUD).log_drawer.visible: (hud as ChapterRiftHUD).log_drawer.hide()
			else: _return_to_m0()
		elif key in [KEY_ENTER,KEY_KP_ENTER] and controller.phase == BattleController.Phase.FINISHED: _on_primary()
		else: super._input(event); return
		get_viewport().set_input_as_handled()
