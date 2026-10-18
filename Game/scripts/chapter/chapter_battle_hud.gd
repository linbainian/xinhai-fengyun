class_name ChapterBattleHUD
extends TutorialHUD

# Rectangles use a 1920×1080 reference; extra space follows the window aspect.
const FIELD_TOP: float = 168.0
const FIELD_BOTTOM: float = 848.0
const PORTRAIT_LIBRARY: Script = preload("res://scripts/chapter/chapter_portraits.gd")
var log_drawer: Panel
var log_button: Button
var _hero_hp: ProgressBar
var _hero_sl: ProgressBar
var _hero_gauge: Label
var _enemy_hit_buttons: Array[Button] = []
var _status_bar: Panel
var _command_bar: Panel
var _lesson_card: Panel
var _guide_portrait: TextureRect


func _ready() -> void:
	_build_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: Panel = _panel("StatusBar", Rect2(0, 0, 1920, FIELD_TOP))
	_status_bar = top
	_heading = _label(top, "", Rect2(24, 10, 750, 44), 32)
	_round_label = _label(top, "", Rect2(800, 10, 250, 40), 26)
	_subtitle = _label(top, "", Rect2(24, 54, 1000, 30), 22)
	_order_label = _label(top, "", Rect2(1070, 56, 826, 28), 20)
	hints_button = _button(top, "提示 [H]", Rect2(1504, 10, 186, 40), 22)
	replay_button = _button(top, "重玩 [T]", Rect2(1704, 10, 192, 40), 22)
	hints_button.pressed.connect(func() -> void: hints_requested.emit())
	replay_button.pressed.connect(func() -> void: replay_requested.emit())
	_ally_labels.append(_label(top, "", Rect2(24, 91, 610, 30), 24))
	_hero_hp = _bar(top, Rect2(24, 133, 268, 14), Color(0.35, 0.74, 0.62))
	_hero_sl = _bar(top, Rect2(312, 133, 162, 14), Color(0.79, 0.62, 0.32))
	_hero_gauge = _label(top, "", Rect2(490, 123, 152, 32), 21)
	for index: int in range(6):
		var button: Button = _button(top, "", Rect2(664 + index * 412, 91, 398, 64), 22)
		button.pressed.connect(_on_enemy_selected.bind(index))
		enemy_buttons.append(button)
		var hit: Button = _button(self, "", Rect2(0, 0, 144, 144))
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			hit.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		hit.pressed.connect(_on_enemy_selected.bind(index))
		_enemy_hit_buttons.append(hit)
	target_button = enemy_buttons[0]
	var commands: Panel = _panel("CommandBar", Rect2(24, FIELD_BOTTOM, 1872, 208))
	_command_bar = commands
	_phase_label = _label(commands, "", Rect2(24, 10, 360, 38), 26)
	_preview_label = _label(commands, "", Rect2(394, 10, 1454, 38), 24)
	attack_button = _button(commands, "攻击 [A]", Rect2(24, 56, 236, 74), 26)
	defense_button = _button(commands, "防御 [D]", Rect2(272, 56, 236, 74), 26)
	for index: int in range(3):
		var button: Button = _button(commands, "", Rect2(520 + index * 300, 56, 288, 74), 24)
		button.pressed.connect(_on_skill_pressed.bind(index))
		button.mouse_entered.connect(_on_skill_hovered.bind(index))
		skill_buttons.append(button)
	break_button = _button(commands, "突破 [B]", Rect2(1120, 56, 240, 74), 24)
	break_button.pressed.connect(_on_break_pressed)
	log_button = _button(commands, "记录 [L]", Rect2(1388, 56, 142, 74), 22)
	log_button.pressed.connect(toggle_log)
	retry_button = _button(commands, "重试 [R]", Rect2(1542, 56, 142, 74), 22)
	back_button = _button(commands, "后山 [Esc]", Rect2(1696, 56, 158, 74), 22)
	_coach_name = _label(commands, "", Rect2(), 22)
	_coach_identity = _label(commands, "", Rect2(), 22)
	_goals_label = _label(commands, "", Rect2(), 22)
	_defense_hint = _label(commands, "", Rect2(), 22)
	for label: Label in [_coach_name, _coach_identity, _goals_label, _defense_hint]: label.hide()
	_coach_text = _label(commands, "", Rect2(24, 140, 1824, 62), 22)
	_coach_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attack_button.pressed.connect(_on_attack_pressed)
	attack_button.mouse_entered.connect(_on_attack_hovered)
	defense_button.pressed.connect(_on_defense_pressed)
	retry_button.pressed.connect(_on_retry_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_build_log_drawer()
	_result_panel = _panel("UnusedResult", Rect2())
	_result_label = _label(_result_panel, "", Rect2(), 24)
	_result_panel.hide()
	_build_lesson_modal()
	clear_export_result()


func apply_display_layout() -> void:
	_status_bar.size.x = size.x
	hints_button.position.x = size.x - 416.0
	replay_button.position.x = size.x - 216.0
	_order_label.position.x = size.x - 850.0
	_command_bar.position.y = size.y - 232.0
	_command_bar.size.x = size.x - 48.0
	_preview_label.size.x = _command_bar.size.x - 418.0
	_coach_text.size.x = _command_bar.size.x - 48.0
	break_button.position.x = _command_bar.size.x - 752.0
	log_button.position.x = _command_bar.size.x - 484.0
	retry_button.position.x = _command_bar.size.x - 330.0
	back_button.position.x = _command_bar.size.x - 176.0
	log_drawer.position.x = size.x - 740.0
	_overlay.size = size
	_lesson_card.position = (size - _lesson_card.size) / 2.0
	_guide_portrait.position = size - _guide_portrait.size - Vector2(24, 24)
	if _controller != null:
		refresh(_controller)


func battlefield_rect() -> Rect2:
	return Rect2(0, FIELD_TOP, size.x, _command_bar.position.y - FIELD_TOP)


func _build_log_drawer() -> void:
	log_drawer = _panel("BattleLogDrawer", Rect2(1180, 192, 716, 606))
	log_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_label(log_drawer, "战斗记录", Rect2(24, 16, 520, 42), 28)
	var close: Button = _button(log_drawer, "关闭 [L]", Rect2(548, 16, 144, 42), 22)
	close.pressed.connect(toggle_log)
	_log_box = RichTextLabel.new()
	_log_box.position = Vector2(24, 76)
	_log_box.size = Vector2(668, 376)
	_log_box.scroll_following = true
	_log_box.add_theme_font_size_override("normal_font_size", 24)
	log_drawer.add_child(_log_box)
	export_button = _button(log_drawer, "导出日志 [E]", Rect2(24, 478, 260, 54), 24)
	export_button.pressed.connect(_on_export_pressed)
	_export_label = _label(log_drawer, "", Rect2(24, 548, 668, 36), 22)
	log_drawer.hide()


func _build_lesson_modal() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "TutorialModal"
	_overlay.size = Vector2(1920, 1080)
	_overlay.color = Color(0.015, 0.025, 0.035, 0.76)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	var modal: Panel = _panel("TutorialCard", Rect2(480, 250, 960, 580))
	_lesson_card = modal
	modal.reparent(_overlay, false)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_title = _label(modal, "", Rect2(32, 26, 896, 58), 36)
	_modal_body = _label(modal, "", Rect2(32, 106, 896, 246), 26)
	_modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_checkpoint_label = _label(modal, "", Rect2(32, 368, 896, 40), 22)
	primary_button = _button(modal, "", Rect2(32, 432, 432, 64), 26)
	secondary_button = _button(modal, "", Rect2(496, 432, 432, 64), 26)
	modal_back_button = _button(modal, "返回后山 [Esc]", Rect2(340, 522, 280, 42), 22)
	primary_button.pressed.connect(func() -> void: primary_requested.emit())
	secondary_button.pressed.connect(func() -> void: secondary_requested.emit())
	modal_back_button.pressed.connect(_on_back_pressed)
	_guide_portrait = TextureRect.new()
	_guide_portrait.name = "GuidePortrait"
	_guide_portrait.size = Vector2(400, 600)
	_guide_portrait.position = Vector2(1496, 456)
	_guide_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_guide_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_guide_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_guide_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_portrait.hide()
	_overlay.add_child(_guide_portrait)


func refresh(controller: BattleController) -> void:
	super.refresh(controller)
	if controller.encounter == null or not controller.error_message.is_empty(): return
	_round_label.text = "第 %d 轮" % controller.round_number
	var hero: CombatantState = controller.living_team(true)[0] if not controller.living_team(true).is_empty() else controller.combatants[0]
	_ally_labels[0].text = "%s · %s/%s    HP %d/%d    SL %d" % [hero.definition.display_name, hero.definition.awakening_rank, hero.definition.affinity, hero.hp, hero.max_hp(), hero.sl]
	_ally_labels[0].tooltip_text = _status(hero)
	_hero_hp.max_value = hero.max_hp()
	_hero_hp.value = hero.hp
	_hero_sl.value = hero.sl
	_hero_gauge.text = "临界槽 %d" % hero.critical
	_hero_sl.tooltip_text = "精神负荷：50轻度 / 70中度 / 85偏离 / 100失控\n" + _status(hero)
	defense_button.tooltip_text = _defense_hint.text
	var index: int = 0
	var enemies: Array[CombatantState] = []
	for unit: CombatantState in controller.combatants:
		if not unit.is_player: enemies.append(unit)
	for button: Button in enemy_buttons:
		if index < enemies.size():
			var unit: CombatantState = enemies[index]
			button.tooltip_text = button.text + "\n" + _status(unit)
			button.text = "%s%s · %s\nHP %d/%d" % ["◆ " if unit.id == selected_target else "", unit.definition.display_name, unit.definition.affinity, unit.hp, unit.max_hp()]
			var target_width: float = (size.x - 688.0) / enemies.size()
			button.position.x = 664 + index * target_width
			button.size.x = target_width - 14
		var hit: Button = _enemy_hit_buttons[index]
		hit.visible = button.visible
		hit.disabled = button.disabled
		hit.tooltip_text = button.tooltip_text
		index += 1
	for skill_index: int in range(skill_buttons.size()):
		skill_buttons[skill_index].visible = skill_index < hero.definition.skills.size()
	if command_locked:
		for hit: Button in _enemy_hit_buttons: hit.disabled = true


func set_enemy_hit_positions(points: Array[Vector2], display: ChapterDisplay) -> void:
	for index: int in range(points.size()):
		_enemy_hit_buttons[index].position = display.world_to_ui(points[index] - Vector2(72, 144))
		_enemy_hit_buttons[index].size = display.world_to_ui(Vector2(144, 144)) - display.world_to_ui(Vector2.ZERO)


func present_lesson(definition: TutorialDefinition, index: int, flow: StringName,
		hints: bool, hint_text: String, goal_text: String, modal_body: String,
		checkpoint_text: String) -> void:
	super.present_lesson(definition, index, flow, hints, hint_text, goal_text, modal_body, checkpoint_text)
	_guide_portrait.texture = PORTRAIT_LIBRARY.texture_for(definition.guide_name)
	_guide_portrait.visible = _guide_portrait.texture != null
	_coach_text.text = (hint_text if hint_text.begins_with(definition.guide_name + "：") else "%s：%s" % [definition.guide_name, hint_text]) if hints else "提示已隐藏，按 H 恢复。"
	_coach_text.tooltip_text = goal_text + "\n" + definition.guide_identity
	hints_button.text = "隐藏提示 [H]" if hints else "显示提示 [H]"
	replay_button.text = "重玩 [T]"
	_subtitle.text = "第 %d / 3 段 · %s · HP/SL 连续携带" % [index + 1, definition.lessons[index].title]
	if command_locked:
		log_drawer.hide()
		for hit: Button in _enemy_hit_buttons: hit.disabled = true


func _refresh_preview() -> void:
	if _controller == null or _controller.encounter == null: return
	var actor: CombatantState = _controller.current_actor()
	var target: CombatantState = _controller.get_combatant(selected_target)
	if actor == null or target == null:
		_preview_label.text = "战斗结束"
		return
	var skill: SkillDefinition = actor.get_skill(_preview_skill)
	var cost: int = 0 if skill == null else BattleCalculator.skill_cost(actor, skill, _controller.encounter.rules)
	var load_value: int = mini(100, actor.sl + cost)
	var preview: Dictionary = BattleCalculator.attack_preview(actor, target, _controller.encounter, skill, load_value)
	_preview_label.text = "%s → %s  ·  命中 %.0f%%  ·  克制 ×%.2f  ·  SL %d→%d" % ["普攻" if skill == null else skill.display_name, target.definition.display_name, preview.hit_chance, preview.modifiers.affinity, actor.sl, load_value]
	_preview_label.tooltip_text = "等级×%.2f · 环境×%.2f · 负荷修正×%.2f\n临界槽%d / 100 · 突破%.0f%%\nTab或点击兔子切换目标；鼠标移到技能可查看预览。" % [preview.modifiers.rank, preview.modifiers.environment, preview.modifiers.sl, actor.critical, BattleCalculator.breakthrough_chance(actor, _controller.encounter)]


func toggle_log() -> void:
	if not command_locked: log_drawer.visible = not log_drawer.visible


func clear_export_result() -> void:
	_export_label.text = "记录显示最近五次行动。"
	_export_label.tooltip_text = ""
