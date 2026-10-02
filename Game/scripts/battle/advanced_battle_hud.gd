class_name AdvancedBattleHUD
extends BattleHUD

signal skill_requested(skill_id: StringName, target_id: StringName)

var skill_buttons: Array[Button] = []
var enemy_buttons: Array[Button] = []
var break_button: Button
var _ally_labels: Array[Label] = []
var _controller: BattleController
var _preview_label: Label
var _preview_skill: StringName = &""


func _ready() -> void:
	_build_theme()
	_heading = _label(self, "", Rect2(48, 30, 1200, 60), 40)
	_label(self, "技能 1 / 2 / 3   ·   Tab 换目标   ·   A 攻击   D 防御   B 突破", Rect2(48, 96, 1400, 44), 24)
	_round_label = _label(self, "", Rect2(1300, 32, 572, 48), 26)
	_order_label = _label(self, "", Rect2(48, 162, 1824, 44), 24)
	var ally_panel: Panel = _panel("Allies", Rect2(48, 230, 424, 430))
	_label(ally_panel, "我方队伍", Rect2(24, 12, 376, 40), 24)
	for index: int in range(4):
		var entry: Label = _label(ally_panel, "", Rect2(24, 64 + index * 90, 376, 82), 20)
		_ally_labels.append(entry)
	var enemy_panel: Panel = _panel("Enemies", Rect2(1448, 230, 424, 430))
	_label(enemy_panel, "敌方 · 点击选择目标", Rect2(24, 10, 376, 40), 24)
	for index: int in range(6):
		var button: Button = _button(enemy_panel, "", Rect2(24, 54 + index * 62, 376, 58), 20)
		button.pressed.connect(_on_enemy_selected.bind(index))
		enemy_buttons.append(button)
	target_button = enemy_buttons[0]
	var preview: Panel = _panel("Preview", Rect2(792, 230, 360, 430))
	_preview_label = _label(preview, "", Rect2(24, 16, 312, 398), 20)
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var commands: Panel = _panel("Commands", Rect2(48, 684, 710, 320))
	_phase_label = _label(commands, "", Rect2(24, 14, 662, 42), 24)
	attack_button = _button(commands, "攻击 [A]", Rect2(24, 64, 210, 56), 24)
	defense_button = _button(commands, "防御 [D]", Rect2(250, 64, 210, 56), 24)
	break_button = _button(commands, "突破待接入", Rect2(476, 64, 210, 56), 22)
	break_button.disabled = true
	break_button.pressed.connect(_on_break_pressed)
	for index: int in range(3):
		var button: Button = _button(commands, "", Rect2(24 + index * 226, 134, 210, 64), 20)
		button.pressed.connect(_on_skill_pressed.bind(index))
		button.mouse_entered.connect(_on_skill_hovered.bind(index))
		skill_buttons.append(button)
	export_button = _button(commands, "导出 [E]", Rect2(24, 214, 210, 52), 22)
	retry_button = _button(commands, "重试 [R]", Rect2(250, 214, 210, 52), 22)
	back_button = _button(commands, "返回 M0", Rect2(476, 214, 210, 52), 22)
	_defense_hint = _label(commands, "", Rect2(24, 280, 662, 32), 20)
	var log_panel: Panel = _panel("Log", Rect2(792, 684, 1080, 320))
	_label(log_panel, "战斗记录 · 负荷 / 冷却 / 命中", Rect2(24, 16, 1032, 42), 26)
	_log_box = RichTextLabel.new()
	_log_box.position = Vector2(24, 72)
	_log_box.size = Vector2(1032, 224)
	_log_box.scroll_following = true
	_log_box.add_theme_font_size_override("normal_font_size", 22)
	log_panel.add_child(_log_box)
	_export_label = _label(self, "", Rect2(792, 1018, 1080, 40), 22)
	_label(self, "50 轻度 / 70 中度 / 85 偏离 / 100 失控", Rect2(48, 1018, 710, 40), 20)
	_result_panel = _panel("Result", Rect2(540, 280, 840, 290))
	_result_label = _label(_result_panel, "", Rect2(24, 22, 792, 92), 48)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint: Label = _label(_result_panel, "可重新开始，或导出本场日志\n本场增益在重试时清除", Rect2(24, 132, 792, 122), 28)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_panel.hide()
	attack_button.pressed.connect(_on_attack_pressed)
	attack_button.mouse_entered.connect(_on_attack_hovered)
	defense_button.pressed.connect(_on_defense_pressed)
	retry_button.pressed.connect(_on_retry_pressed)
	export_button.pressed.connect(_on_export_pressed)
	back_button.pressed.connect(_on_back_pressed)
	clear_export_result()


func refresh(controller: BattleController) -> void:
	_controller = controller
	var can_command: bool = controller.phase == BattleController.Phase.PLAYER_COMMAND
	attack_button.disabled = not can_command
	defense_button.disabled = not can_command
	export_button.disabled = not controller.error_message.is_empty()
	break_button.disabled = true
	for button: Button in enemy_buttons:
		button.disabled = true
	for button: Button in skill_buttons:
		button.disabled = true
	_result_panel.visible = controller.phase == BattleController.Phase.FINISHED
	_result_label.text = "胜利" if controller.result == &"victory" else "战败"
	if controller.encounter == null or not controller.error_message.is_empty():
		_phase_label.text = "配表错误"
		_log_box.text = controller.error_message
		return
	_heading.text = controller.encounter.title
	_round_label.text = "第%d轮 / 种子%d" % [controller.round_number, controller.encounter.seed_value]
	var allies: Array[CombatantState] = []
	var enemies: Array[CombatantState] = []
	for unit: CombatantState in controller.combatants:
		if unit.is_player:
			allies.append(unit)
		else:
			enemies.append(unit)
	var target: CombatantState = controller.get_combatant(selected_target)
	if target == null or not target.is_alive() or target.is_player:
		var living: Array[CombatantState] = controller.living_team(false)
		selected_target = living[0].id if not living.is_empty() else &""
	var actor: CombatantState = controller.current_actor()
	if controller.encounter.rules.breakthrough_enabled:
		var rules: BattleRules = controller.encounter.rules
		break_button.disabled = not can_command or not controller.can_breakthrough(actor)
		break_button.tooltip_text = "消耗一次自身行动；满槽才能尝试\n成功：本场属性×%.1f，SL清零，回复新HP上限的%d%%\n失败：SL+%d，临界槽回%d，接下来%d次自身行动输出%d%%\n本场成功增益只能获得一次" % [
			rules.breakthrough_success_multiplier, roundi(rules.breakthrough_success_heal_ratio * 100.0),
			rules.breakthrough_failure_sl, rules.breakthrough_failure_critical,
			rules.breakthrough_weak_actions, roundi(rules.weak_damage_multiplier * 100.0)]
		if actor != null:
			break_button.text = "本场已突破" if actor.breakthrough_multiplier > 1.0 else "突破 [B] %.0f%%" % BattleCalculator.breakthrough_chance(actor, controller.encounter)
	else:
		break_button.text = "突破未启用"
		break_button.tooltip_text = "此规则沙盒未启用临阵突破"
	for index: int in range(_ally_labels.size()):
		_ally_labels[index].visible = index < allies.size()
		if index < allies.size():
			var unit: CombatantState = allies[index]
			_ally_labels[index].text = "%s%s · %s/%s\nHP %d/%d   SL %d\n%s" % [
				"▶ " if unit == actor else "", unit.definition.display_name,
				unit.definition.awakening_rank, unit.definition.affinity,
				unit.hp, unit.max_hp(), unit.sl, "倒地" if not unit.is_alive() else _status(unit)]
			if controller.encounter.rules.breakthrough_enabled:
				_ally_labels[index].text = "%s%s · %s/%s\nHP%d/%d · SL%d · 槽%d\n%s" % [
					"▶ " if unit == actor else "", unit.definition.display_name,
					unit.definition.awakening_rank, unit.definition.affinity,
					unit.hp, unit.max_hp(), unit.sl, unit.critical, "倒地" if not unit.is_alive() else _status(unit)]
	for index: int in range(enemy_buttons.size()):
		var button: Button = enemy_buttons[index]
		button.visible = index < enemies.size()
		if index < enemies.size():
			var unit: CombatantState = enemies[index]
			button.disabled = not can_command or not unit.is_alive()
			button.text = "%s%s · %s/%s\nHP %d/%d   SL %d" % [
				"◆ " if unit.id == selected_target else "", unit.definition.display_name,
				unit.definition.awakening_rank, unit.definition.affinity, unit.hp, unit.max_hp(), unit.sl]
			if controller.encounter.rules.breakthrough_enabled:
				button.text += " · 槽%d" % unit.critical
	var order: PackedStringArray = []
	for id: StringName in controller.remaining_order():
		var unit: CombatantState = controller.get_combatant(id)
		if unit.is_alive():
			order.append(unit.definition.display_name)
	_order_label.text = "顺序：" + " → ".join(order)
	if controller.phase == BattleController.Phase.FINISHED:
		_phase_label.text = "战斗结束"
		_order_label.text = "本场战斗已结束"
	elif controller.phase == BattleController.Phase.AUTO_COMMAND:
		_phase_label.text = "%s失控：剩%d次行动" % [actor.definition.display_name, actor.uncontrolled_remaining]
	elif controller.phase == BattleController.Phase.PLAYER_COMMAND:
		_phase_label.text = "%s的回合" % actor.definition.display_name
	else:
		_phase_label.text = "%s正在行动…" % actor.definition.display_name
	for index: int in range(skill_buttons.size()):
		var button: Button = skill_buttons[index]
		var valid: bool = actor != null and index < actor.definition.skills.size()
		button.disabled = not can_command or not valid
		button.text = "—"
		if valid:
			var skill: SkillDefinition = actor.definition.skills[index]
			var cd: int = actor.cooldown_for(skill.id)
			button.disabled = button.disabled or cd > 0
			button.text = "[%d] %s\nSL+%d · CD %d" % [index + 1, skill.display_name,
				BattleCalculator.skill_cost(actor, skill, controller.encounter.rules), cd]
			button.tooltip_text = "倍率×%.2f · 冷却%d次自身行动 · %s" % [
				skill.multiplier, skill.cooldown, "敌方全体" if skill.target_mode == "all_enemies" else "敌方单体"]
	_defense_hint.text = "防御回复%d%% HP、SL -%d；鼠标移到技能查看预览" % [
		roundi(controller.encounter.rules.defense_hp_ratio * 100.0), controller.encounter.rules.defense_sl_relief]
	_refresh_preview()
	_log_box.text = _summarize(controller)


func _status(unit: CombatantState) -> String:
	if unit.uncontrolled_remaining > 0:
		return "失控 %d 次" % unit.uncontrolled_remaining
	if unit.weak_actions > 0:
		return "虚弱：本次输出减半"
	if unit.breakthrough_multiplier > 1.0:
		return "本场突破增益 ×%.1f" % unit.breakthrough_multiplier
	if unit.sl >= _controller.encounter.rules.sl_deviation_threshold:
		return "重度透支：技能可能偏离"
	if unit.sl >= _controller.encounter.rules.sl_medium_threshold:
		return "中度透支：伤害/命中降低"
	if unit.sl >= _controller.encounter.rules.sl_light_threshold:
		return "轻度透支：伤害/命中降低"
	return "状态正常"


func _refresh_preview() -> void:
	if _controller == null:
		return
	var actor: CombatantState = _controller.current_actor()
	var target: CombatantState = _controller.get_combatant(selected_target)
	if actor == null or target == null:
		_preview_label.text = "战斗结束"
		return
	var skill: SkillDefinition = actor.get_skill(_preview_skill)
	var cost: int = 0 if skill == null else BattleCalculator.skill_cost(actor, skill, _controller.encounter.rules)
	var load_value: int = mini(100, actor.sl + cost)
	var preview: Dictionary = BattleCalculator.attack_preview(actor, target, _controller.encounter, skill, load_value)
	_preview_label.text = "%s → %s\n\n%s\n命中 %.1f%%\n克制 ×%.2f\n等级 ×%.2f\n环境 ×%.2f\n负荷 %d → %d\n伤害负荷修正 ×%.2f\n%s" % [
		actor.definition.display_name, target.definition.display_name,
		"普通攻击" if skill == null else skill.display_name,
		preview.hit_chance, preview.modifiers.affinity, preview.modifiers.rank,
		preview.modifiers.environment, actor.sl, load_value, preview.modifiers.sl,
		"无技能冷却" if skill == null else "冷却 %d 次自身行动" % skill.cooldown]
	if _controller.encounter.rules.breakthrough_enabled:
		_preview_label.text += "\n临界槽 %d/100\n突破 %.0f%% · %s" % [actor.critical,
			BattleCalculator.breakthrough_chance(actor, _controller.encounter),
			"已生效" if actor.breakthrough_multiplier > 1.0 else "需满槽"]
		if actor.weak_actions > 0:
			_preview_label.text += "\n虚弱输出 ×%.1f" % preview.modifiers.weak


func cycle_target() -> void:
	if _controller == null or _controller.phase != BattleController.Phase.PLAYER_COMMAND:
		return
	var targets: Array[CombatantState] = _controller.living_team(false)
	for index: int in range(targets.size()):
		if targets[index].id == selected_target:
			selected_target = targets[(index + 1) % targets.size()].id
			refresh(_controller)
			target_selected.emit(selected_target)
			return


func request_skill(index: int) -> void:
	if _controller == null or _controller.phase != BattleController.Phase.PLAYER_COMMAND:
		return
	var actor: CombatantState = _controller.current_actor()
	if index < actor.definition.skills.size():
		skill_requested.emit(actor.definition.skills[index].id, selected_target)


func _on_enemy_selected(index: int) -> void:
	var enemies: Array[CombatantState] = []
	for unit: CombatantState in _controller.combatants:
		if not unit.is_player:
			enemies.append(unit)
	if index >= enemies.size() or not enemies[index].is_alive():
		return
	selected_target = enemies[index].id
	refresh(_controller)
	target_selected.emit(selected_target)


func _on_skill_pressed(index: int) -> void:
	request_skill(index)


func _on_break_pressed() -> void:
	command_requested.emit(&"breakthrough", &"")


func _on_skill_hovered(index: int) -> void:
	var actor: CombatantState = _controller.current_actor()
	if actor != null and index < actor.definition.skills.size():
		_preview_skill = actor.definition.skills[index].id
		_refresh_preview()


func _on_attack_hovered() -> void:
	_preview_skill = &""
	_refresh_preview()


func _summarize(controller: BattleController) -> String:
	var lines: PackedStringArray = []
	for event: Dictionary in controller.events:
		if event.kind != "action":
			continue
		var action: Dictionary = event.details
		var actor: String = controller.get_combatant(StringName(action.actor_id)).definition.display_name
		var prefix: String = "第%d轮 · %s" % [event.round, actor]
		if action.command == "defend":
			lines.append(prefix + "防御：HP+%d，SL-%d" % [action.healing, action.sl_relief])
		elif action.command == "breakthrough":
			lines.append(prefix + "突破%s（%.0f%%，抽样%.1f）" % [
				"成功" if action.success else "失败：SL+%d、虚弱" % controller.encounter.rules.breakthrough_failure_sl,
				action.chance, action.roll])
		else:
			var results: PackedStringArray = []
			for outcome: Dictionary in action.outcomes:
				var target: String = controller.get_combatant(StringName(outcome.target_id)).definition.display_name
				results.append("%s -%d" % [target, outcome.hp_loss] if outcome.hit else target + "未命中")
			var verb: String = String(action.get("skill_name", "攻击"))
			if action.command == "uncontrolled":
				verb = "失控攻击"
			lines.append(prefix + verb + ("【偏离】" if action.get("deviated", false) else "") + "：" + " / ".join(results))
		if action.has("ai_reason"):
			lines[lines.size() - 1] += "（%s）" % action.ai_reason
	return "Tab或点击敌人切换目标；移到技能查看命中、克制和负荷。" if lines.is_empty() else "\n".join(lines.slice(maxi(0, lines.size() - 5)))
