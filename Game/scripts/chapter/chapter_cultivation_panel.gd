class_name ChapterCultivationPanel
extends ColorRect

signal action_requested(action: String, value: String)
signal close_requested

const GOLD: Color = Color("d8bc7c")
const MUTED: Color = Color("a9b8b6")
const JADE: Color = Color("69c4bb")
var card: Panel
var content: Control
var state: ChapterSession
var story: ChapterTwoStory
var selected_tab: String = "train"
var buttons: Dictionary = {}


func _ready() -> void:
	color = Color(0.015,0.035,0.045,0.94)
	mouse_filter = Control.MOUSE_FILTER_STOP
	card = _panel(self,Rect2(0,0,1840,988),Color("10262b"))
	hide()


func layout(area: Vector2) -> void:
	size = area
	card.position = (area-card.size)/2.0


func show_session(source: ChapterSession, narrative: ChapterTwoStory) -> void:
	state = source
	story = narrative
	_rebuild()
	show()


func _panel(parent: Node, rect: Rect2, fill: Color = Color("163237")) -> Panel:
	var result: Panel = Panel.new()
	result.position = rect.position
	result.size = rect.size
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("466568")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	result.add_theme_stylebox_override("panel",style)
	parent.add_child(result)
	return result


func _text(parent: Node, value: String, rect: Rect2, font: int = 26, tint: Color = Color("edf0e4")) -> Label:
	var label: Label = Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font)
	label.add_theme_color_override("font_color",tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Node, label: String, rect: Rect2, action: String, value: String = "", enabled: bool = true) -> Button:
	var button: Button = Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = label
	button.add_theme_font_size_override("font_size",26)
	button.disabled = not enabled
	button.set_meta("action",action)
	button.set_meta("value",value)
	parent.add_child(button)
	buttons[action+":"+value] = button
	button.pressed.connect(func() -> void:
		if action=="tab":
			selected_tab=value
			_rebuild.call_deferred()
		elif action=="close": close_requested.emit()
		else: action_requested.emit(action,value))
	return button


func _bar(parent: Node, rect: Rect2, value: float, maximum: float, tint: Color) -> void:
	var back: ColorRect = ColorRect.new()
	back.position = rect.position
	back.size = rect.size
	back.color = Color("091c21")
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(back)
	var fill: ColorRect = ColorRect.new()
	fill.size = Vector2(rect.size.x*clampf(value/maximum,0,1),rect.size.y)
	fill.color = tint
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)


func _action(index: int, title: String, description: String, action: String, value: String, enabled: bool, caption: String = "安排 · 1行动") -> void:
	var slot: Panel = _panel(content,Rect2((index%2)*436,82+floori(index/2.0)*182,420,170))
	_text(slot,title,Rect2(20,8,380,42),28,GOLD)
	_text(slot,description,Rect2(20,54,380,64),22,MUTED)
	_button(slot,caption,Rect2(20,122,380,42),action,value,enabled)


func _roam_action(index: int, title: String, description: String, action: String, value: String, enabled: bool, caption: String = "出发 · 1行动") -> void:
	var slot: Panel = _panel(content,Rect2((index%2)*436,82+floori(index/2.0)*154,420,148))
	_text(slot,title,Rect2(18,7,384,34),27,GOLD)
	_text(slot,description,Rect2(18,45,384,54),21,MUTED)
	_button(slot,caption,Rect2(18,106,384,34),action,value,enabled)


func _rebuild() -> void:
	buttons.clear()
	for child: Node in card.get_children(): child.free()
	var data: Dictionary = state.chapter_two
	var profile: Dictionary = data.cultivation
	var growth: ChapterCultivation = story.growth
	var pending: bool = not String(profile.active_event).is_empty()
	var daytime: bool = growth.available() and story.calendar.can_act() and not pending
	_text(card,"新生养成",Rect2(28,18,370,64),44,GOLD)
	_text(card,state.date_text(),Rect2(428,20,864,48),32)
	_text(card,"日间 %d/2    夜间 %d/1    资金 %d元    贡献 %d" % [2-int(data.slot),0 if bool(data.night_used) else 1,state.money,state.contribution],Rect2(428,72,980,40),26,JADE)
	_button(card,"回到地图 [C / Esc]",Rect2(1432,24,380,60),"close")
	var left: Panel = _panel(card,Rect2(28,128,384,830),Color("112a30"))
	_text(left,"林 大   /   %s级 · %s" % [String(profile.rank),state.affinity],Rect2(20,16,344,42),30,GOLD)
	var portrait: TextureRect = TextureRect.new()
	portrait.position = Vector2(108,68)
	portrait.size = Vector2(168,168)
	portrait.texture = load("res://assets/chapter1/refined/lin_da/frames/frame_000.png") as Texture2D
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	left.add_child(portrait)
	_text(left,"导师 · "+String(ChapterStory.MENTOR_NAMES[state.mentor]),Rect2(20,248,344,36),25,MUTED)
	_text(left,"HP %d / %d     SL %d / 100" % [state.hp,state.max_hp(),state.sl],Rect2(20,292,344,36),25)
	_bar(left,Rect2(20,334,344,10),state.hp,state.max_hp(),JADE)
	_text(left,"觉醒度 %d / 100" % int(profile.awakening),Rect2(20,356,344,36),26,GOLD)
	_bar(left,Rect2(20,398,344,10),float(profile.awakening),100,GOLD)
	var attributes: Dictionary = growth.attributes()
	var index: int = 0
	for key: String in ChapterCultivation.ATTRIBUTE_NAMES:
		_text(left,String(ChapterCultivation.ATTRIBUTE_NAMES[key]),Rect2(20,430+index*46,184,38),27,MUTED)
		_text(left,str(int(attributes[key])),Rect2(244,430+index*46,100,38),29)
		index+=1
	var stats: Dictionary = growth.combat_stats()
	var mentor_load: float = float(state.settings.mentor.get(state.mentor,{}).get("skill_sl_multiplier",1.0))
	_text(left,"攻击 %.1f   防御 %.1f   速度 %d\n技能威力 ×%.2f   负荷 ×%.2f\n行动等级 %d · 属性含导师加成" % [float(stats.attack),float(stats.defense),int(stats.speed),float(stats.power),float(stats.load)*mentor_load,int(profile.level)],Rect2(20,724,344,96),22,MUTED)
	content = Control.new()
	content.position = Vector2(428,128)
	content.size = Vector2(856,830)
	card.add_child(content)
	var tabs: Dictionary = {"train":"修 炼","roam":"闲 逛","jobs":"委 托","life":"生 活"}
	index=0
	for key: String in tabs:
		var tab: Button = _button(content,("● " if key==selected_tab else "")+String(tabs[key]),Rect2(index*218,0,202,60),"tab",key)
		if key==selected_tab: tab.add_theme_color_override("font_color",GOLD)
		index+=1
	match selected_tab:
		"train":
			_action(0,"实战基本功","力量+1 · 主攻熟练+4\n觉醒度+3 · SL+5","growth_train","force",daytime)
			_action(1,"灵能运用","精神+1 · 两招熟练各+3\n觉醒度+6 · SL+8","growth_train","ability",daytime)
			_action(2,"体能锻炼","体质/敏捷各+1 · 提升HP上限\n觉醒度+2 · SL+3","growth_train","body",daytime)
			_action(3,"静心观息","意志/感知各+1\n觉醒度+2 · SL−10","growth_train","focus",daytime)
			_button(content,"安全突破 D→C · 觉醒度100 · 1行动",Rect2(0,444,856,58),"growth_breakthrough","",daytime and String(profile.rank)=="D" and int(profile.awakening)>=100)
			_text(content,"技能熟练达到20 / 50 / 80：伤害+5% / +10% / +15%。",Rect2(0,514,856,36),24,MUTED)
		"roam":
			_roam_action(0,"学院区 / 图书馆","看看同学和借阅台\n遗落物与人物事件随日期开放","growth_roam","campus",daytime)
			_roam_action(1,"训练场","旁观冰雷对练、看看午休场地\n有些相遇需要先认识对方","growth_roam","training",daytime)
			_roam_action(2,"后山草圃","采集灵草、查看维护点\n原有后山奇遇保留","growth_roam","hill",daytime)
			_roam_action(3,"商业街 / 老街","旧书摊、临时工作、回家方向\n冰品店半价券：%d张" % int(profile.inventory.coupon),"growth_roam","street",daytime)
			_roam_action(4,"宿舍共用楼道","回寝室前，到楼梯口看看\n林初夏有自己的社团排班","growth_roam","dormitory",daytime)
			_roam_action(5,"本次奇遇",String(growth.event_definition().get("name","暂无待处理事件"))+"\n遇见后自动演出，再做选择","growth_event","",pending,"继续这次奇遇")
			_text(content,"人物奇遇至1月14日结束。出发1行动；选择不额外耗时；可错过。",Rect2(0,544,856,32),20,MUTED)
		"jobs":
			_action(0,"器材整理","资金+80 · 贡献+1\n每周可完成一次","growth_job","equipment",daytime and int(profile.jobs_done.get("equipment",-1))!=int(data.week))
			_action(1,"档案誊抄","资金+80 · 贡献+1 · 学业+3\n每周可完成一次","growth_job","files",daytime and int(profile.jobs_done.get("files",-1))!=int(data.week))
			_action(2,"城区送件","去管理局大厅找受理员交件\n完成后资金+150 · 贡献+2","growth_job","courier",daytime and String(profile.job).is_empty() and int(profile.jobs_done.get("courier",-1))!=int(data.week),"接取 · 1行动")
			_action(3,"交售灵草","每份30元 · 不消耗行动\n行囊数量：%d" % int(profile.inventory.herb),"growth_sell","",int(profile.inventory.herb)>0,"交售全部")
			_text(content,"委托每7天刷新。送件需实际交接，接取时不发报酬。2月1日开放港口★★任务。",Rect2(0,444,856,82),27,MUTED)
		"life":
			_action(0,"学院课程","学业+5 · 觉醒度+2\n计入本周课业记录","c2_class","",daytime)
			_action(1,"调息休整","HP恢复 · SL降低20\n适合连续修炼之后","c2_rest","",daytime)
			var night: bool = growth.available() and story.calendar.can_act(true) and not pending
			_action(2,"宿舍夜读","学业+5 · SL降低10\n消耗夜间机会","growth_night","read",night,"安排 · 1夜间")
			_action(3,"和温让夜谈","温让好感+5 · SL降低5\n消耗夜间机会","growth_night","wen",night,"安排 · 1夜间")
			_button(content,"服用灵草 (%d)" % int(profile.inventory.herb),Rect2(0,444,268,54),"growth_herb","",int(profile.inventory.herb)>0)
			_button(content,"研读异能笔记 (%d)" % int(profile.inventory.notes),Rect2(286,444,276,54),"growth_notes","notes",daytime and int(profile.inventory.notes)>0)
			_button(content,"研读感悟 (%d)" % int(profile.inventory.insight),Rect2(580,444,276,54),"growth_notes","insight",daytime and int(profile.inventory.insight)>0)
			_text(content,"灵草：HP+45 / SL−10，无行动消耗。笔记：熟练+8，觉醒度+10（感悟+20），1行动。",Rect2(0,508,856,52),23,MUTED)
	for skill: int in range(2):
		var x: int = skill*436
		var key: String = "strike" if skill==0 else "sweep"
		_text(content,"%s  %d/100" % [String(state.settings.skills[state.affinity][skill]),int(profile.proficiency[key])],Rect2(x,580,420,36),26,GOLD)
		_bar(content,Rect2(x,626,420,8),float(profile.proficiency[key]),100,JADE)
	var record: Panel = _panel(content,Rect2(0,656,856,174),Color("0c2228"))
	_text(record,"最近成长",Rect2(20,12,816,36),26,GOLD)
	var recent: Array[String] = []
	for cursor: int in range(maxi(0,profile.history.size()-2),profile.history.size()):
		var entry: String = String(profile.history[cursor])
		recent.append(entry.substr(entry.find("  ")+2))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position=Vector2(20,56)
	scroll.size=Vector2(816,106)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	record.add_child(scroll)
	var record_text: Label = _text(scroll,"\n".join(recent) if not recent.is_empty() else "选择今天的行动，逐步建立自己的战斗与生活能力。",Rect2(0,0,788,100),23,MUTED)
	record_text.custom_minimum_size.x=788
	_build_calendar(profile,pending)


func _build_calendar(profile: Dictionary, pending: bool) -> void:
	var right: Panel = _panel(card,Rect2(1300,128,512,830),Color("112a30"))
	var ordinal: int = int(state.chapter_two.day)
	var month: int = 1
	var day: int = ordinal
	var month_days: int = 31
	for count: int in [31,28,31,30,31,30,31,31,30,31,30,31]:
		month_days=count
		if day<=count: break
		day-=count
		month+=1
	_text(right,"%02d月 · 第%d周日程" % [month,int(state.chapter_two.week)+1],Rect2(20,16,472,40),30,GOLD)
	_text(right,"高亮为今天 · 金色框为剧情日期",Rect2(20,64,472,34),23,MUTED)
	for number: int in range(1,month_days+1):
		var cell: Panel = _panel(right,Rect2(20+((number-1)%7)*68,110+floori((number-1)/7.0)*52,62,46),Color("365852") if number==day else Color("0a2026"))
		if (month==1 and number==15) or (month==2 and number==1):
			var style: StyleBoxFlat = cell.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
			style.border_color=GOLD
			cell.add_theme_stylebox_override("panel",style)
		var label: Label = _text(cell,str(number),Rect2(0,2,62,38),25,GOLD if number==day else MUTED)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var upcoming: String = "01-15  异常复筛（还有%d天）" % (15-ordinal) if ordinal<15 else "01-15  异常复筛 · 已到期" if String(state.chapter_two.stage)=="rescreen" else "01-15  异常复筛 · 已完成"
	_text(right,upcoming+"\n02-01  港口★★委托开放",Rect2(20,376,472,74),26,GOLD)
	var ongoing: String = "本次发现："+String(story.growth.event_definition().get("name","无"))+"\n委托："+("待交件 · 管理局受理员" if String(profile.job)=="courier" else "暂无待交件")
	_text(right,ongoing,Rect2(20,454,472,74),25,JADE)
	var jiang: String = str(int(state.relations.jiang)) if state.flags.get("c2_exam_done",false) else "未相识"
	_text(right,"好感：温让%d · 初夏%d · 江北辰%s\n苏挽颜%d · 半价券%d张\n白沐瑶%d / 苏晚棠%d（初识）\n采集%d · 学业%d · 灵草%d" % [int(state.relations.wen_rang),int(state.relations.chuxia),jiang,int(state.relations.su),int(profile.inventory.coupon),int(state.relations.get("bai_muyao",0)),int(state.relations.get("su_wantang",0)),int(profile.life.gathering),int(profile.life.study),int(profile.inventory.herb)],Rect2(20,530,472,128),21,MUTED)
	_button(right,"结束今天 · 休息到明天",Rect2(20,660,472,58),"c2_sleep_now","",not pending)
	_button(right,"课业 / 修炼预排七天",Rect2(20,730,472,58),"c2_repeat_week","",not pending)
	_text(right,"可提前休息；未用行动放弃。预排遇剧情日会停下。",Rect2(20,796,472,30),20,MUTED)
