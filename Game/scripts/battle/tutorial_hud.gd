class_name TutorialHUD
extends AdvancedBattleHUD

signal primary_requested
signal secondary_requested
signal hints_requested
signal replay_requested

var primary_button: Button
var secondary_button: Button
var modal_back_button: Button
var hints_button: Button
var replay_button: Button
var command_locked: bool = true
var _subtitle: Label
var _coach_name: Label
var _coach_identity: Label
var _coach_text: Label
var _goals_label: Label
var _overlay: ColorRect
var _modal_title: Label
var _modal_body: Label
var _checkpoint_label: Label


func _ready() -> void:
	super._ready()
	for child: Node in get_children():
		if child is Label and child.position == Vector2(48, 96):
			child.hide()
	_subtitle = _label(self, "", Rect2(48, 96, 1260, 44), 24)
	hints_button = _button(self, "跳过提示 [H]", Rect2(1436, 94, 208, 46), 21)
	replay_button = _button(self, "重玩教程 [T]", Rect2(1660, 94, 212, 46), 21)
	hints_button.pressed.connect(func() -> void: hints_requested.emit())
	replay_button.pressed.connect(func() -> void: replay_requested.emit())
	_goals_label = _label(self, "", Rect2(72, 386, 376, 30), 18)
	var coach: Panel = _panel("Coach", Rect2(72, 426, 376, 210))
	_coach_name = _label(coach, "", Rect2(16, 10, 344, 28), 22)
	_coach_identity = _label(coach, "", Rect2(16, 40, 344, 28), 17)
	_coach_text = _label(coach, "", Rect2(16, 76, 344, 118), 20)
	_coach_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	retry_button.text = "重试本段 [R]"
	_overlay = ColorRect.new()
	_overlay.name = "TutorialModal"
	_overlay.size = Vector2(1920, 1080)
	_overlay.color = Color(0.015, 0.025, 0.035, 0.82)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	var modal: Panel = _panel("TutorialCard", Rect2(480, 250, 960, 580))
	modal.reparent(_overlay, false)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_title = _label(modal, "", Rect2(32, 26, 896, 58), 36)
	_modal_body = _label(modal, "", Rect2(32, 106, 896, 246), 26)
	_modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_checkpoint_label = _label(modal, "", Rect2(32, 368, 896, 40), 22)
	primary_button = _button(modal, "", Rect2(32, 432, 432, 64), 26)
	secondary_button = _button(modal, "", Rect2(496, 432, 432, 64), 26)
	modal_back_button = _button(modal, "返回 M0 [Esc]", Rect2(340, 522, 280, 42), 22)
	primary_button.pressed.connect(func() -> void: primary_requested.emit())
	secondary_button.pressed.connect(func() -> void: secondary_requested.emit())
	modal_back_button.pressed.connect(_on_back_pressed)


func refresh(controller: BattleController) -> void:
	super.refresh(controller)
	_result_panel.hide()
	_lock_commands()


func present_lesson(definition: TutorialDefinition, index: int, flow: StringName,
		hints: bool, hint_text: String, goal_text: String, modal_body: String,
		checkpoint_text: String) -> void:
	var lesson: TutorialLesson = definition.lessons[index]
	_heading.text = definition.title + " · M1-D"
	_subtitle.text = "第%d/3段 · %s · HP/SL连续携带" % [index + 1, lesson.title]
	_coach_name.text = definition.guide_name + " · 入口旁观"
	_coach_identity.text = definition.guide_identity
	_coach_text.text = hint_text if hints else "提示已隐藏。\n专心看状态与预览；H可恢复。"
	_goals_label.text = goal_text if hints else ""
	hints_button.text = "跳过提示 [H]" if hints else "显示提示 [H]"
	command_locked = flow != &"battle"
	_overlay.visible = command_locked
	_lock_commands()
	_checkpoint_label.text = checkpoint_text
	_modal_body.text = modal_body
	primary_button.disabled = false
	secondary_button.disabled = false
	match flow:
		&"intro":
			_modal_title.text = definition.guide_name + "的后山委托"
			primary_button.text = "开始教程 [Enter]"
			secondary_button.text = "跳过提示开始"
		&"between":
			_modal_title.text = "第%d段完成 · %s" % [index + 1, lesson.title]
			primary_button.text = "进入下一段 [Enter]"
			secondary_button.text = "重试本段"
		&"complete":
			_modal_title.text = "野兔王已退去 · 教程完成"
			primary_button.text = "重玩教程 [Enter]"
			secondary_button.text = "无提示重玩"
		&"failed":
			_modal_title.text = "暂退入口 · 本段未完成"
			primary_button.text = "重试本段 [Enter]"
			secondary_button.text = "从头重玩"
		&"error":
			_modal_title.text = "无法开始教程"
			primary_button.disabled = true
			secondary_button.disabled = true


func _lock_commands() -> void:
	if not command_locked:
		return
	attack_button.disabled = true
	defense_button.disabled = true
	break_button.disabled = true
	for button: Button in skill_buttons:
		button.disabled = true
	for button: Button in enemy_buttons:
		button.disabled = true


func show_error(message: String) -> void:
	command_locked = true
	_overlay.show()
	_lock_commands()
	_modal_title.text = "无法开始教程"
	_modal_body.text = message
	_checkpoint_label.text = "返回后可检查教程配表"
	primary_button.disabled = true
	secondary_button.disabled = true


func cycle_target() -> void:
	if not command_locked:
		super.cycle_target()


func request_skill(index: int) -> void:
	if not command_locked:
		super.request_skill(index)


func _on_enemy_selected(index: int) -> void:
	if not command_locked:
		super._on_enemy_selected(index)
