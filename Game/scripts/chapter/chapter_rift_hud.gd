class_name ChapterRiftHUD
extends ChapterBattleHUD


func _ready() -> void:
	super._ready()
	command_locked = false
	hints_button.hide()
	replay_button.hide()
	_overlay.hide()
	back_button.text = "撤回 [Esc]"
	modal_back_button.text = "退出遭遇 [Esc]"


func refresh(controller: BattleController) -> void:
	super.refresh(controller)
	if controller.encounter == null: return
	_heading.text = controller.encounter.title
	_subtitle.text = "第2章 · 裂隙浅层   /   指令作用于当前出手人物"
	var lines: Array[String] = []
	for unit: CombatantState in controller.combatants:
		if unit.is_player: lines.append("%s HP%d/%d SL%d" % [unit.definition.display_name,unit.hp,unit.max_hp(),unit.sl])
	_coach_text.text = "队伍  ·  " + "   /   ".join(lines)
	var actor: CombatantState = controller.current_actor()
	if actor != null and actor.is_player:
		_ally_labels[0].text = "%s · 当前出手    HP %d/%d    SL %d" % [actor.definition.display_name,actor.hp,actor.max_hp(),actor.sl]
		_hero_hp.max_value = actor.max_hp()
		_hero_hp.value = actor.hp
		_hero_sl.value = actor.sl
		_hero_gauge.text = "临界槽 %d" % actor.critical
		for index: int in range(skill_buttons.size()): skill_buttons[index].visible = index<actor.definition.skills.size()


func show_result(victory: bool) -> void:
	_overlay.show()
	_modal_title.text = "清剿完成" if victory else "队伍失去战斗能力"
	_modal_body.text = "带着当前HP与精神负荷返回浅层，继续调查通道。" if victory else "可从这一处遭遇开始前的检查点重试，也可退出整备。已完成的遭遇保留。"
	_checkpoint_label.text = "每个遭遇有独立检查点，重试恢复本次开战状态。"
	primary_button.text = "返回浅层 [Enter]" if victory else "重试本次遭遇 [Enter]"
	secondary_button.text = "再战一次" if victory else "退出遭遇"
	secondary_button.visible = not victory
