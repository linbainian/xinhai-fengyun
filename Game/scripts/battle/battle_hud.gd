class_name BattleHUD
extends Control

signal command_requested(command: StringName, target_id: StringName)
signal retry_requested
signal export_requested
signal back_requested
signal target_selected(id: StringName)

var attack_button: Button
var defense_button: Button
var retry_button: Button
var export_button: Button
var back_button: Button
var target_button: Button
var selected_target: StringName = &""

var _heading: Label
var _round_label: Label
var _phase_label: Label
var _order_label: Label
var _ally_card: Dictionary
var _enemy_card: Dictionary
var _log_box: RichTextLabel
var _export_label: Label
var _defense_hint: Label
var _result_panel: Panel
var _result_label: Label


func _ready() -> void:
	_build_theme()
	_heading = _label(self, "战斗沙盒 · M1-A", Rect2(48, 30, 1120, 60), 40)
	_label(self, "同等级 · 中性环境 · 1 对 1", Rect2(48, 96, 1120, 48), 26)
	_round_label = _label(self, "", Rect2(1280, 32, 592, 48), 28)
	_order_label = _label(self, "", Rect2(48, 162, 1824, 44), 26)
	_ally_card = _make_card("AllyCard", Rect2(48, 250, 424, 334))
	_enemy_card = _make_card("EnemyCard", Rect2(1448, 250, 424, 334))
	target_button = _button(self, "已选中敌人", Rect2(1448, 602, 424, 58))
	_label(self, "黄色边框：当前行动者", Rect2(48, 610, 820, 44), 24)
	var commands: Panel = _panel("Commands", Rect2(48, 684, 710, 320))
	_phase_label = _label(commands, "", Rect2(24, 16, 662, 48), 26)
	attack_button = _button(commands, "攻击  [A]", Rect2(24, 78, 318, 68))
	defense_button = _button(commands, "防御  [D]", Rect2(368, 78, 318, 68))
	export_button = _button(commands, "导出日志  [E]", Rect2(24, 170, 318, 62))
	retry_button = _button(commands, "重新开始  [R]", Rect2(368, 170, 318, 62))
	back_button = _button(commands, "返回 M0", Rect2(24, 258, 174, 42), 22)
	_defense_hint = _label(commands, "", Rect2(222, 258, 464, 42), 22)
	var log_panel: Panel = _panel("Log", Rect2(792, 684, 1080, 320))
	_label(log_panel, "战斗记录", Rect2(24, 16, 1032, 42), 26)
	_log_box = RichTextLabel.new()
	_log_box.position = Vector2(24, 72)
	_log_box.size = Vector2(1032, 224)
	_log_box.scroll_following = true
	_log_box.add_theme_font_size_override("normal_font_size", 24)
	log_panel.add_child(_log_box)
	_export_label = _label(self, "日志尚未导出。F11 切换全屏。", Rect2(792, 1018, 1080, 40), 22)
	_label(self, "本批 SL 只验证防御回落；阈值惩罚在 M1-B 接入。", Rect2(48, 1018, 710, 40), 20)
	_result_panel = _panel("Result", Rect2(540, 280, 840, 290))
	_result_label = _label(_result_panel, "", Rect2(24, 22, 792, 92), 48)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var result_hint: Label = _label(_result_panel, "可重新开始，或导出本场日志\n同样的操作与种子会重现相同结果", Rect2(24, 132, 792, 122), 28)
	result_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_panel.hide()
	attack_button.pressed.connect(_on_attack_pressed)
	defense_button.pressed.connect(_on_defense_pressed)
	retry_button.pressed.connect(_on_retry_pressed)
	export_button.pressed.connect(_on_export_pressed)
	back_button.pressed.connect(_on_back_pressed)
	target_button.pressed.connect(_on_target_pressed)


func refresh(controller: BattleController) -> void:
	var ready_for_command: bool = controller.phase == BattleController.Phase.PLAYER_COMMAND
	attack_button.disabled = not ready_for_command
	defense_button.disabled = not ready_for_command
	export_button.disabled = controller.encounter == null or not controller.error_message.is_empty()
	if not controller.error_message.is_empty():
		_result_panel.hide()
		_phase_label.text = "配表错误"
		_log_box.text = controller.error_message
		return
	if controller.combatants.size() != 2:
		return
	_heading.text = controller.encounter.title
	_defense_hint.text = "防御：SL -%d / HP +%d%%" % [controller.encounter.rules.defense_sl_relief,
		roundi(controller.encounter.rules.defense_hp_ratio * 100.0)]
	_round_label.text = "第 %d 轮  /  种子 %d" % [controller.round_number, controller.encounter.seed_value]
	_update_card(_ally_card, controller.combatants[0])
	_update_card(_enemy_card, controller.combatants[1])
	selected_target = controller.combatants[1].definition.id
	target_button.disabled = not ready_for_command
	target_button.text = "目标：%s" % controller.combatants[1].definition.display_name
	var names: PackedStringArray = []
	for id: StringName in controller.remaining_order():
		names.append(controller.get_combatant(id).definition.display_name)
	_order_label.text = "行动顺序：" + "  →  ".join(names)
	var actor: CombatantState = controller.current_actor()
	match controller.phase:
		BattleController.Phase.PLAYER_COMMAND:
			_phase_label.text = "你的回合 · 请选择行动"
		BattleController.Phase.ENEMY_COMMAND:
			_phase_label.text = "敌方正在选择行动…"
		BattleController.Phase.PRESENTING:
			_phase_label.text = "%s正在行动…" % actor.definition.display_name
		BattleController.Phase.FINISHED:
			_phase_label.text = "战斗结束"
			_order_label.text = "本场战斗已结束；日志包含完整配表、随机抽样与结算。"
	_result_panel.visible = controller.phase == BattleController.Phase.FINISHED
	_result_label.text = "胜利" if controller.result == &"victory" else "战败"
	_log_box.text = _summarize(controller)


func show_export_result(error: Error, path: String) -> void:
	_export_label.text = "已导出：%s" % path.get_file() if error == OK else "日志导出失败：%s" % error_string(error)
	_export_label.tooltip_text = path


func clear_export_result() -> void:
	_export_label.text = "日志尚未导出。F11 切换全屏。"
	_export_label.tooltip_text = ""


func _build_theme() -> void:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimSun"])
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 26
	theme.set_color("font_color", "Label", Color(0.88, 0.91, 0.93))
	theme.set_stylebox("normal", "Button", _style(Color(0.12, 0.18, 0.22)))
	theme.set_stylebox("hover", "Button", _style(Color(0.20, 0.30, 0.34)))
	theme.set_stylebox("pressed", "Button", _style(Color(0.24, 0.39, 0.40)))
	theme.set_stylebox("disabled", "Button", _style(Color(0.075, 0.10, 0.13), Color(0.17, 0.20, 0.24)))
	theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), Color(0.94, 0.82, 0.48)))
	theme.set_color("font_disabled_color", "Button", Color(0.38, 0.43, 0.48))


func _style(background: Color, border: Color = Color(0.29, 0.38, 0.43)) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.set_border_width_all(2)
	style.border_color = border
	style.set_corner_radius_all(10)
	return style


func _panel(node_name: String, rect: Rect2) -> Panel:
	var panel: Panel = Panel.new()
	panel.name = node_name
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.085, 0.12, 0.98)))
	add_child(panel)
	return panel


func _label(parent: Node, text: String, rect: Rect2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, rect: Rect2, font_size: int = 28) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", font_size)
	parent.add_child(button)
	return button


func _make_card(node_name: String, rect: Rect2) -> Dictionary:
	var panel: Panel = _panel(node_name, rect)
	var name_label: Label = _label(panel, "", Rect2(24, 18, 376, 50), 32)
	var stats_label: Label = _label(panel, "", Rect2(24, 82, 376, 40), 24)
	var hp_label: Label = _label(panel, "", Rect2(24, 136, 376, 38), 26)
	var hp_bar: ProgressBar = _bar(panel, Rect2(24, 182, 376, 18), Color(0.34, 0.72, 0.64))
	var sl_label: Label = _label(panel, "", Rect2(24, 224, 376, 38), 26)
	var sl_bar: ProgressBar = _bar(panel, Rect2(24, 272, 376, 18), Color(0.78, 0.62, 0.33))
	return {"name": name_label, "stats": stats_label, "hp_label": hp_label,
		"hp_bar": hp_bar, "sl_label": sl_label, "sl_bar": sl_bar}


func _bar(parent: Node, rect: Rect2, color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.position = rect.position
	bar.size = rect.size
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _style(Color(0.035, 0.045, 0.06)))
	bar.add_theme_stylebox_override("fill", _style(color, color))
	parent.add_child(bar)
	return bar


func _update_card(card: Dictionary, unit: CombatantState) -> void:
	card["name"].text = unit.definition.display_name + (" · 倒地" if not unit.is_alive() else "")
	card["stats"].text = "%s级 · %s系 · SPD %d" % [unit.definition.awakening_rank, unit.definition.affinity, unit.definition.speed]
	card["hp_label"].text = "HP  %d / %d" % [unit.hp, unit.definition.max_hp]
	card["hp_bar"].max_value = unit.definition.max_hp
	card["hp_bar"].value = unit.hp
	card["sl_label"].text = "精神负荷  %d / 100" % unit.sl
	card["sl_bar"].value = unit.sl


func _summarize(controller: BattleController) -> String:
	var lines: PackedStringArray = []
	for event: Dictionary in controller.events:
		if event.kind != "action":
			continue
		var action: Dictionary = event.details
		var actor: String = controller.get_combatant(StringName(action.actor_id)).definition.display_name
		var target: String = controller.get_combatant(StringName(action.target_id)).definition.display_name
		var prefix: String = "第%d轮 · %s" % [event.round, actor]
		if action.command == "defend":
			lines.append(prefix + "防御：HP +%d，SL -%d" % [action.healing, action.sl_relief])
		elif action.hit:
			lines.append(prefix + "攻击%s：造成%d伤害" % [target, action.hp_loss])
		else:
			lines.append(prefix + "攻击%s：未命中" % target)
	if lines.is_empty():
		var ally: CombatantState = controller.combatants[0]
		return "开场 HP %d/%d、SL %d，便于观察防御回复。\n攻击无 SL 代价；防御回复 HP 并降低 SL。" % [ally.hp, ally.definition.max_hp, ally.sl]
	return "\n".join(lines.slice(maxi(0, lines.size() - 6)))


func _on_attack_pressed() -> void:
	command_requested.emit(&"attack", selected_target)


func _on_defense_pressed() -> void:
	command_requested.emit(&"defend", &"")


func _on_retry_pressed() -> void:
	retry_requested.emit()


func _on_export_pressed() -> void:
	export_requested.emit()


func _on_back_pressed() -> void:
	back_requested.emit()


func _on_target_pressed() -> void:
	target_selected.emit(selected_target)
