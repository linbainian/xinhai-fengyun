class_name ChapterHUD
extends Control

signal new_game_requested(affinity: String)
signal continue_requested
signal advance_requested
signal choice_requested(index: int)
signal travel_requested(room: String)
signal map_requested
signal journal_requested
signal pause_requested
signal save_requested
signal load_requested
signal title_requested
signal close_requested
signal next_chapter_requested
signal cultivation_requested
signal cultivation_action_requested(action: String, value: String)
signal first_completion_requested

const INK: Color = Color(0.04, 0.085, 0.105, 0.96)
const GOLD: Color = Color(0.9, 0.77, 0.49)
var title_layer: ColorRect
var dialog_panel: Panel
var choice_layer: ColorRect
var menu_layer: ColorRect
var ending_layer: ColorRect
var advance_button: Button
var affinity_select: OptionButton
var continue_button: Button
var first_completion_button: Button
var top_panel: Panel
var prompt_label: Label
var date_label: Label
var objective_label: Label
var stats_label: Label
var toast_label: Label
var toast_panel: Panel
var speaker_label: Label
var body_label: Label
var portrait: TextureRect
var menu_card: Panel
var ending_label: Label
var ending_title: Label
var ending_date: Label
var next_chapter_button: Button
var nameplate_layer: Control
var cultivation_panel: ChapterCultivationPanel
var cultivation_button: Button
var _title_content: Control
var _ending_card: Panel
var _top_buttons: Array[Button] = []
var _nameplate_room: String = ""
var _toast_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1920, 1080)
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	var skin: Theme = Theme.new()
	skin.default_font = font
	skin.default_font_size = 28
	skin.set_color("font_color", "Label", Color(0.91, 0.93, 0.89))
	skin.set_color("font_color", "Button", Color(0.94, 0.92, 0.83))
	skin.set_color("font_hover_color", "Button", Color.WHITE)
	skin.set_stylebox("normal", "Button", _style(Color(0.09, 0.17, 0.2), Color(0.3, 0.43, 0.44)))
	skin.set_stylebox("hover", "Button", _style(Color(0.15, 0.28, 0.3), GOLD))
	skin.set_stylebox("pressed", "Button", _style(Color(0.18, 0.3, 0.3), GOLD))
	skin.set_stylebox("focus", "Button", _style(Color.TRANSPARENT, GOLD))
	skin.set_stylebox("disabled", "Button", _style(Color(0.08, 0.11, 0.12), Color(0.15, 0.2, 0.2)))
	theme = skin
	nameplate_layer = Control.new()
	nameplate_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nameplate_layer)
	top_panel = _panel(self, Rect2(24, 18, 1872, 134))
	date_label = _label(top_panel, "", Rect2(24, 12, 1020, 40), 28)
	date_label.add_theme_color_override("font_color", GOLD)
	objective_label = _label(top_panel, "", Rect2(24, 61, 1250, 48), 28)
	stats_label = _label(top_panel, "", Rect2(1130, 12, 720, 40), 25)
	var map_button: Button = _button(top_panel, "地图 [M]", Rect2(1280, 65, 172, 48), 23)
	var journal_button: Button = _button(top_panel, "档案 [J]", Rect2(1464, 65, 172, 48), 23)
	var pause_button: Button = _button(top_panel, "菜单 [Esc]", Rect2(1648, 65, 178, 48), 23)
	_top_buttons = [map_button, journal_button, pause_button]
	map_button.pressed.connect(func() -> void: map_requested.emit())
	journal_button.pressed.connect(func() -> void: journal_requested.emit())
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	prompt_label = _label(self, "WASD / 方向键移动 · E交互", Rect2(48, 1006, 1320, 52), 28)
	prompt_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	prompt_label.add_theme_constant_override("shadow_outline_size", 8)
	cultivation_button = _button(self,"日程与养成 [C]",Rect2(1480,1006,392,52),27)
	cultivation_button.pressed.connect(func() -> void: cultivation_requested.emit())
	toast_panel = _panel(self, Rect2(420, 160, 1080, 64))
	toast_label = _label(toast_panel, "", Rect2(16, 8, 1048, 48), 26)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_color", GOLD)
	_build_title()
	_build_dialog()
	choice_layer = _overlay()
	menu_layer = _overlay()
	menu_card = _panel(menu_layer, Rect2(420, 170, 1080, 750))
	ending_layer = _overlay()
	_ending_card = _panel(ending_layer, Rect2(330, 170, 1260, 740))
	var end_card: Panel = _ending_card
	ending_title = _label(end_card, "第 1 章 · 入学日", Rect2(48, 38, 1164, 70), 50)
	ending_title.add_theme_color_override("font_color", GOLD)
	ending_date = _label(end_card, "觉醒历22年 · 01-01 — 01-03", Rect2(48, 124, 1164, 50), 28)
	ending_label = _label(end_card, "", Rect2(48, 215, 1164, 320), 30)
	ending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_chapter_button = _button(end_card, "进入自由养成 · 1月4日", Rect2(48, 526, 1164, 60), 30)
	next_chapter_button.pressed.connect(func() -> void: next_chapter_requested.emit())
	_button(end_card, "回到标题", Rect2(48, 606, 550, 70), 30).pressed.connect(func() -> void: title_requested.emit())
	_button(end_card, "查看章节档案", Rect2(646, 606, 566, 70), 30).pressed.connect(func() -> void: journal_requested.emit())
	cultivation_panel = ChapterCultivationPanel.new()
	add_child(cultivation_panel)
	cultivation_panel.action_requested.connect(func(action: String, value: String) -> void: cultivation_action_requested.emit(action,value))
	cultivation_panel.close_requested.connect(func() -> void: close_requested.emit())
	show_title()
	move_child(toast_panel, get_child_count() - 1)
	toast_panel.hide()


func apply_display_layout() -> void:
	nameplate_layer.size = size
	top_panel.size.x = size.x - 48.0
	stats_label.position.x = top_panel.size.x - 742.0
	objective_label.size.x = top_panel.size.x - 622.0
	for index: int in range(_top_buttons.size()):
		_top_buttons[index].position.x = top_panel.size.x - [592.0, 408.0, 224.0][index]
	prompt_label.position.y = size.y - 74.0
	prompt_label.size.x = size.x - 520.0
	cultivation_button.position = Vector2(size.x-440,size.y-74)
	cultivation_panel.layout(size)
	toast_panel.position.x = (size.x - toast_panel.size.x) / 2.0
	dialog_panel.position.y = size.y - 350.0
	dialog_panel.size.x = size.x - 68.0
	_layout_dialogue()
	for overlay: ColorRect in [title_layer, choice_layer, menu_layer, ending_layer]:
		overlay.size = size
	_title_content.position = (size - Vector2(1920, 1080)) / 2.0
	menu_card.position = (size - menu_card.size) / 2.0
	_ending_card.position = (size - _ending_card.size) / 2.0
	for child: Node in choice_layer.get_children():
		if child is Panel:
			child.position = (size - child.size) / 2.0


func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	return box


func _panel(parent: Node, rect: Rect2) -> Panel:
	var panel: Panel = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(INK, Color(0.34, 0.46, 0.46)))
	parent.add_child(panel)
	return panel


func _label(parent: Node, text_value: String, rect: Rect2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Node, text_value: String, rect: Rect2, font_size: int = 28) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", font_size)
	button.focus_mode = Control.FOCUS_ALL
	parent.add_child(button)
	return button


func _overlay() -> ColorRect:
	var overlay: ColorRect = ColorRect.new()
	overlay.size = Vector2(1920, 1080)
	overlay.color = Color(0.015, 0.045, 0.06, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.hide()
	return overlay


func _build_title() -> void:
	title_layer = _overlay()
	title_layer.color.a = 0.9
	_title_content = Control.new()
	_title_content.size = Vector2(1920, 1080)
	_title_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.add_child(_title_content)
	_label(_title_content, "觉醒者档案", Rect2(170, 185, 1070, 80), 64).add_theme_color_override("font_color", GOLD)
	_label(_title_content, "新海风云", Rect2(170, 280, 1050, 116), 88)
	_label(_title_content, "第1章 · 入学日 → 第2章 · 复筛\n新海异能学院，新生报到。", Rect2(178, 432, 1090, 110), 32)
	_label(_title_content, "林大 · D级新生   /   选择出生系别", Rect2(180, 572, 910, 44), 27)
	affinity_select = OptionButton.new()
	affinity_select.position = Vector2(180, 624)
	affinity_select.size = Vector2(450, 62)
	for affinity: String in ChapterSession.AFFINITIES:
		affinity_select.add_item(affinity + ("（空间方向）" if affinity == "特殊" else ""))
	_title_content.add_child(affinity_select)
	_button(_title_content, "开始游戏", Rect2(180, 724, 450, 74), 34).pressed.connect(func() -> void: new_game_requested.emit(ChapterSession.AFFINITIES[affinity_select.selected]))
	continue_button = _button(_title_content, "继续游戏", Rect2(654, 724, 450, 74), 34)
	continue_button.pressed.connect(func() -> void: continue_requested.emit())
	first_completion_button = _button(_title_content,"首章完成档 · 从1月4日养成",Rect2(1128,724,560,74),27)
	first_completion_button.pressed.connect(func() -> void: first_completion_requested.emit())
	var hero: TextureRect = TextureRect.new()
	hero.position = Vector2(1370, 346)
	hero.size = Vector2(288, 288)
	hero.texture = load("res://assets/chapter1/refined/lin_da/frames/frame_000.png") as Texture2D
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_content.add_child(hero)
	_label(_title_content, "WASD移动 · E交互 · M地图 · J档案\nF5快速存档 · F9读档 · F11全屏", Rect2(180, 860, 1500, 110), 26)
	_label(_title_content, "觉醒历22年 · 新海市", Rect2(180, 988, 1560, 44), 21)


func _build_dialog() -> void:
	dialog_panel = _panel(self, Rect2(34, 730, 1852, 326))
	portrait = TextureRect.new()
	portrait.name = "DialoguePortrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.hide()
	dialog_panel.add_child(portrait)
	speaker_label = _label(dialog_panel, "", Rect2(48, 18, 1300, 54), 34)
	speaker_label.add_theme_color_override("font_color", GOLD)
	body_label = _label(dialog_panel, "", Rect2(48, 90, 1512, 158), 31)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	advance_button = _button(dialog_panel, "继续 [Enter / 空格]", Rect2(1380, 256, 420, 48), 24)
	advance_button.pressed.connect(func() -> void: advance_requested.emit())
	_layout_dialogue()
	dialog_panel.hide()


func _layout_dialogue() -> void:
	# Portraits belong to the UI layer; world sprites retain nearest integer scaling.
	var portrait_height: float = minf(720.0, maxf(360.0, size.y - 300.0))
	portrait.size = Vector2(portrait_height * 2.0 / 3.0, portrait_height)
	portrait.position = Vector2(dialog_panel.size.x - portrait.size.x - 18.0,
		dialog_panel.size.y - portrait.size.y)
	var portrait_space: float = portrait.size.x + 52.0 if portrait.visible else 0.0
	var text_width: float = dialog_panel.size.x - 96.0 - portrait_space
	speaker_label.size.x = text_width
	body_label.size.x = text_width
	advance_button.position.x = body_label.position.x + text_width - advance_button.size.x


func show_title(save_path: String = "user://saves/chapter1.json") -> void:
	clear_toast()
	title_layer.show()
	dialog_panel.hide()
	choice_layer.hide()
	menu_layer.hide()
	ending_layer.hide()
	top_panel.hide()
	prompt_label.hide()
	cultivation_button.hide()
	cultivation_panel.hide()
	var probe: ChapterSession = ChapterSession.new()
	continue_button.disabled = not probe.load_from(save_path)
	continue_button.text = "继续游戏" if not continue_button.disabled else "暂无存档"
	var archive: ChapterSession = ChapterSession.new()
	first_completion_button.visible = archive.load_from(save_path.get_basename()+"-chapter1-cleared.json") and archive.phase=="complete"


func show_world() -> void:
	title_layer.hide()
	dialog_panel.hide()
	choice_layer.hide()
	menu_layer.hide()
	ending_layer.hide()
	cultivation_panel.hide()
	top_panel.show()
	prompt_label.show()


func refresh(state: ChapterSession, story: ChapterStory, closest: Dictionary) -> void:
	date_label.text = state.date_text() + "  /  " + String(ChapterStory.ROOM_NAMES.get(state.room, "学院"))
	objective_label.text = "当前目标  ·  " + story.objective()
	stats_label.text = "%s · HP %d/%d · SL %d · %d元" % [state.affinity, state.hp, state.max_hp(), state.sl, state.money]
	cultivation_button.visible = state.phase in ["chapter_two","cultivation"] and not dialog_panel.visible and not ending_layer.visible and not menu_layer.visible
	if state.phase in ["chapter_two","cultivation"]:
		objective_label.text += "   /   日间%d · 夜间%d" % [maxi(0,2-int(state.chapter_two.slot)),0 if bool(state.chapter_two.night_used) else 1]
	prompt_label.text = "[E / 空格] " + String(closest.get("name", "")) if not closest.is_empty() else "WASD / 方向键移动 · 靠近人物或物件后按E"


func update_nameplates(world: ChapterMap) -> void:
	var room_name: String = String(world.definition.get("name", ""))
	if room_name != _nameplate_room or nameplate_layer.get_child_count() != world.interactions.size():
		_nameplate_room = room_name
		for child: Node in nameplate_layer.get_children(): child.free()
		for entry: Dictionary in world.interactions:
			var text_value: String = String(entry.name).split(" · ")[0]
			var label: Label = _label(nameplate_layer, text_value, Rect2(0, 0, 300, 42), 23)
			var frame_height: float = float(entry.get("size", [48, 48])[1])
			var texture: Texture2D = load(String(entry.asset)) as Texture2D
			var head_height: float = frame_height
			if texture != null:
				var used: Rect2i = texture.get_image().get_used_rect()
				head_height *= 1.0 - float(used.position.y) / texture.get_height()
			label.set_meta("head_height", head_height)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_color_override("font_shadow_color", Color(0.01, 0.025, 0.03))
			label.add_theme_constant_override("shadow_outline_size", 6)
	for index: int in range(world.interactions.size()):
		var entry: Dictionary = world.interactions[index]
		var point: Vector2 = Vector2(float(entry.position[0]), float(entry.position[1]))
		var canvas_point: Vector2 = world.get_viewport().get_canvas_transform() * point
		var label: Label = nameplate_layer.get_child(index) as Label
		var head_height: float = float(label.get_meta("head_height", 48.0))
		var container: SubViewportContainer = world.get_viewport().get_parent() as SubViewportContainer
		var world_to_ui: Transform2D = get_global_transform_with_canvas().affine_inverse() * container.get_global_transform_with_canvas()
		label.position = world_to_ui * (canvas_point - Vector2(0, head_height * world.camera.zoom.y)) - Vector2(150, 44)
		var actor: Node2D = world.actor_for(String(entry.id))
		label.visible = actor != null and actor.is_visible_in_tree() and label.position.y > 148 and label.position.y < size.y - 96 and label.position.x > -300 and label.position.x < size.x


func show_line(line: Dictionary, texture: Texture2D) -> void:
	clear_toast()
	dialog_panel.show()
	prompt_label.hide()
	cultivation_button.hide()
	speaker_label.text = String(line.get("speaker", ""))
	body_label.text = String(line.get("text", ""))
	portrait.texture = texture
	portrait.visible = texture != null
	_layout_dialogue()
	advance_button.disabled = false


func show_choices(choices: Array) -> void:
	clear_toast()
	for child: Node in choice_layer.get_children(): child.free()
	choice_layer.show()
	dialog_panel.hide()
	var height: int = 140 + choices.size() * 88
	var card_size: Vector2 = Vector2(1120, height)
	var card: Panel = _panel(choice_layer, Rect2((size - card_size) / 2.0, card_size))
	_label(card, "你的选择", Rect2(32, 18, 1056, 58), 34).add_theme_color_override("font_color", GOLD)
	for index: int in range(choices.size()):
		var button: Button = _button(card, str(index + 1) + " · " + String(choices[index].label), Rect2(32, 94 + index * 88, 1056, 72), 29)
		button.pressed.connect(func() -> void: choice_requested.emit(index))


func _clear_menu(title_text: String) -> void:
	clear_toast()
	for child: Node in menu_card.get_children(): child.free()
	menu_layer.show()
	_label(menu_card, title_text, Rect2(36, 22, 1008, 64), 40).add_theme_color_override("font_color", GOLD)
	_button(menu_card, "关闭 [Esc]", Rect2(720, 654, 324, 60), 27).pressed.connect(func() -> void: close_requested.emit())


func show_map(story: ChapterStory) -> void:
	_clear_menu("城市地图" if story.state.flags.get("task_accepted", false) else "学生证 · 校园地图")
	var rooms: Array[String] = story.locations()
	var spacing: int = 60 if rooms.size()>12 else 72 if rooms.size()>10 else 82
	var height: int = spacing-10
	for index: int in range(rooms.size()):
		var room: String = rooms[index]
		var button: Button = _button(menu_card, String(ChapterStory.ROOM_NAMES[room]) + ("  · 当前" if room == story.state.room else ""), Rect2(36 + (index % 2) * 516, 110 + floori(index / 2.0) * spacing, 490, height), 26)
		button.pressed.connect(func() -> void: travel_requested.emit(room))
	_label(menu_card, "已开放地点随当前目标更新。", Rect2(36, 600, 1008, 44), 25)


func show_journal(state: ChapterSession) -> void:
	_clear_menu("觉醒者档案 · 林大")
	if state.phase in ["chapter_two","cultivation"]:
		_show_second_journal(state)
		return
	var mentor_name: String = String(ChapterStory.MENTOR_NAMES.get(state.mentor, "尚未拜师"))
	var bonus: String = String(ChapterStory.BONUSES.get(state.mentor, "完成拜山任务后开启入门节点"))
	var text_value: String = "D级 · %s  /  %s\n入门节点：%s\n同伴档：温让%d · 凌未央%d · 苏挽颜%d\n资金 %d元 · 贡献 %d\n\n" % [state.affinity, mentor_name, bonus, int(state.relations.wen_rang), int(state.relations.ling), int(state.relations.su), state.money, state.contribution]
	var first: int = maxi(0, state.journal.size() - 7)
	for index: int in range(first, state.journal.size()): text_value += "· " + state.journal[index] + "\n"
	var label: Label = _label(menu_card, text_value, Rect2(36, 116, 1008, 520), 25)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _show_second_journal(state: ChapterSession) -> void:
	var data: Dictionary = state.chapter_two
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter2/settings.json")) as Dictionary
	var party: Array[String] = []
	for id: String in data.party:
		var vitals: Dictionary = data.party_vitals[id]
		party.append("%s（HP%d SL%d）" % [String(config.party[id].name),int(vitals.hp),int(vitals.sl)])
	var text_value: String = "%s\n导师：%s  /  %s\n同行：%s\n好感：温让%d · 江北辰%d · 林初夏%d\n课业%d · 修炼%d · 社团%d · 已结算%d周\n声望：管理局%d · 互助会%d   /   %d元 · 贡献%d\n线索去向：%s   /   任务评价：%s\n\n" % [
		state.date_text(), String(ChapterStory.MENTOR_NAMES[state.mentor]), String(ChapterTwoCalendar.CLUBS.get(String(data.club),"尚未登记社团")),
		"、".join(party) if not party.is_empty() else "尚未邀请", int(state.relations.wen_rang), int(state.relations.jiang), int(state.relations.chuxia),
		int(data.classes),int(data.training),int(data.club_visits),int(data.week),int(data.reputation.bureau),int(data.reputation.mutual),state.money,state.contribution,
		String({"bureau":"管理局回执","bar":"猎人风闻","keep":"个人保留"}.get(String(data.clue_destination),"尚未发现")),String(data.grade) if not String(data.grade).is_empty() else "进行中"]
	for index: int in range(maxi(0,state.journal.size()-4),state.journal.size()): text_value += "· " + state.journal[index] + "\n"
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(36,112)
	scroll.size = Vector2(1008,522)
	menu_card.add_child(scroll)
	var label: Label = _label(scroll,text_value,Rect2(0,0,960,0),25)
	label.custom_minimum_size.x = 960
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func show_pause() -> void:
	_clear_menu("学生证 · 菜单")
	_button(menu_card, "存档 [F5]", Rect2(36, 142, 1008, 80), 32).pressed.connect(func() -> void: save_requested.emit())
	_button(menu_card, "读档 [F9]", Rect2(36, 242, 1008, 80), 32).pressed.connect(func() -> void: load_requested.emit())
	_button(menu_card, "返回标题", Rect2(36, 342, 1008, 80), 32).pressed.connect(func() -> void: title_requested.emit())
	_label(menu_card, "存档记录章节、地图、任务、关系和HP/SL。\n战斗中按Esc可回入口；重试从本段检查点开始。", Rect2(36, 474, 1008, 110), 25)


func show_ending(state: ChapterSession) -> void:
	clear_toast()
	ending_layer.show()
	dialog_panel.hide()
	choice_layer.hide()
	prompt_label.hide()
	cultivation_button.hide()
	ending_title.text = "第 1 章 · 入学日"
	ending_date.text = "觉醒历22年 · 01-01 — 01-03"
	next_chapter_button.text = "进入自由养成 · 1月4日"
	ending_label.text = "已完成：入学测试、拜师、后山三战、社团首逛、宿舍夜谈和★送件。\n\n导师：%s\n同伴档：温让%d · 凌未央%d · 苏挽颜%d\n结算：%d元 · 贡献%d\n\n1月4日起自由安排修炼、闲逛与委托；15日参加复筛。" % [String(ChapterStory.MENTOR_NAMES[state.mentor]), int(state.relations.wen_rang), int(state.relations.ling), int(state.relations.su), state.money, state.contribution]


func show_second_ending(state: ChapterSession) -> void:
	show_ending(state)
	ending_title.text = "第 2 章 · 复筛"
	ending_date.text = "异常复筛 → 校园日程 → 港口小裂隙"
	next_chapter_button.text = "继续校园活动"
	var data: Dictionary = state.chapter_two
	ending_label.text = "港口★★清剿完成 · 评价%s\n协作：%s\n切口线索：%s\n资金%d元 · 贡献%d\n管理局声望%d · 互助会声望%d\n\n章节与队伍已保存。" % [String(data.grade),"管理局 · 韩烛" if String(data.route)=="bureau" else "互助会 · 秦妖妖", String({"bureau":"已取得管理局回执","bar":"获得老猎人的风闻","keep":"原图保存在个人档案"}[String(data.clue_destination)]),state.money,state.contribution,int(data.reputation.bureau),int(data.reputation.mutual)]


func toast(message: String) -> void:
	toast_label.text = message
	toast_panel.show()
	_toast_time = 3.5


func clear_toast() -> void:
	toast_panel.hide()
	_toast_time = 0.0


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0: toast_panel.hide()
