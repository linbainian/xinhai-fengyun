class_name ChapterCultivation
extends RefCounted

const ATTRIBUTE_NAMES: Dictionary = {"strength":"力量", "agility":"敏捷", "constitution":"体质", "spirit":"精神", "perception":"感知", "willpower":"意志"}
const ITEM_NAMES: Dictionary = {"herb":"灵草", "notes":"异能笔记", "insight":"感悟笔记", "coupon":"冰品店半价券"}
const RELATION_NAMES: Dictionary = {"wen_rang":"温让", "su":"苏挽颜", "chuxia":"林初夏", "bai_muyao":"白沐瑶", "su_wantang":"苏晚棠"}
const EVENT_AREAS: Dictionary = {"campus_notes":"campus", "campus_practice":"campus", "hill_herbs":"hill", "hill_supply":"hill", "street_books":"street", "street_work":"street", "street_ice":"street", "campus_library":"campus", "training_spar":"training", "training_lunch":"training", "dormitory_flyers":"dormitory"}
var state: ChapterSession
var calendar: ChapterTwoCalendar
var config: Dictionary
var events: Array


func _init(source: ChapterSession, schedule: ChapterTwoCalendar = null) -> void:
	state = source
	calendar = schedule if schedule != null else ChapterTwoCalendar.new(source)
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/cultivation/settings.json")) as Dictionary
	events = JSON.parse_string(FileAccess.get_file_as_string("res://data/cultivation/events.json")) as Array


static func fresh() -> Dictionary:
	return {"version":"cultivation.1", "rank":"D", "level":2, "awakening":0, "attempts":0,
		"attributes":{"strength":10,"agility":10,"constitution":10,"spirit":10,"perception":12,"willpower":10},
		"proficiency":{"strike":0,"sweep":0}, "life":{"gathering":0,"study":0},
		"inventory":{"herb":0,"notes":0,"insight":0,"coupon":2}, "explorations":0, "seen":[],
		"active_event":"", "event_area":"", "event_started":false, "job":"", "job_week":0, "jobs_done":{},
		"history":[], "last_result":"新生自由安排已开放。"}


func data() -> Dictionary:
	return state.chapter_two.cultivation


func available() -> bool:
	return String(state.chapter_two.stage) in ["interlude", "campus", "complete"]


func attributes() -> Dictionary:
	var result: Dictionary = data().attributes.duplicate()
	var bonus: Dictionary = state.settings.mentor.get(state.mentor, {})
	if bonus.has("attribute"):
		result[String(bonus.attribute)] = int(result[String(bonus.attribute)]) + int(bonus.attribute_bonus)
	return result


func combat_stats() -> Dictionary:
	var raw: Dictionary = data().attributes
	var baseline: Dictionary = config.base_attributes
	return {"attack":float(state.settings.hero.attack) + mini(int(calendar.config.training_attack_cap),int(state.chapter_two.training)) + (int(raw.strength)-int(baseline.strength))*float(config.derived.attack_per_strength),
		"defense":float(state.settings.hero.defense)+(int(raw.constitution)-int(baseline.constitution))*float(config.derived.defense_per_constitution),
		"speed":int(state.settings.hero.speed)+floori((int(raw.agility)-int(baseline.agility))*float(config.derived.speed_per_agility)),
		"power":1.0+(int(raw.spirit)-int(baseline.spirit))*float(config.derived.power_per_spirit),
		"load":maxf(0.7,1.0-(int(raw.willpower)-int(baseline.willpower))*float(config.derived.load_per_willpower))}


static func proficiency_bonus(value: int) -> float:
	return 1.15 if value >= 80 else 1.1 if value >= 50 else 1.05 if value >= 20 else 1.0


func event_definition() -> Dictionary:
	for entry: Dictionary in events:
		if String(entry.id) == String(data().active_event): return entry
	return {}


func event_room(event: Dictionary) -> String:
	return String(event.get("room", config.places[String(event.area)].room))


func event_entrance(event: Dictionary) -> String:
	return String(event.get("cinematic", "event_" + String(event.id)))


func _event_choices(event: Dictionary) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for index: int in range(event.options.size()):
		choices.append({"label":event.options[index].label,"action":"growth_event_choice","value":str(index)})
	choices.append({"label":"先离开，日后再来","action":"growth_event_choice","value":"leave"})
	return choices


func _event_problem(event: Dictionary, message: String) -> Dictionary:
	return {"remark":message,"remark_speaker":"系统提示","choices":_event_choices(event)}


func eligible(event: Dictionary) -> bool:
	var day: int = int(state.chapter_two.day)
	if day < int(event.min_day) or day > int(event.get("max_day",365)) or data().seen.has(String(event.id)): return false
	if event.get("interlude_only",false) and String(state.chapter_two.stage)!="interlude": return false
	for id: String in event.get("requires",[]):
		if not data().seen.has(id): return false
	return true


func _record(text_value: String) -> void:
	data().last_result = text_value
	data().history.append("%s  %s" % [calendar.date_text(), text_value])
	if data().history.size() > 20: data().history.pop_front()
	state.record("cultivation", {"result":text_value})


func _reply(text_value: String, dialogue: String = "c2_grow_result") -> Dictionary:
	return {"dialogue":dialogue, "remark":text_value, "remark_speaker":"成长记录", "remark_after_dialogue":true, "open_cultivation":true}


func _apply(change: Dictionary) -> String:
	var records: Array[String] = []
	for key: String in change.get("stats", {}):
		var before: int = int(data().attributes[key])
		data().attributes[key] = mini(int(config.attribute_cap), before+int(change.stats[key]))
		records.append("%s+%d" % [String(ATTRIBUTE_NAMES[key]),int(data().attributes[key])-before])
	for key: String in change.get("skills", {}):
		var before: int = int(data().proficiency[key])
		data().proficiency[key] = mini(100,int(data().proficiency[key])+int(change.skills[key]))
		records.append("%s熟练+%d" % [String(state.settings.skills[state.affinity][0 if key=="strike" else 1]),int(data().proficiency[key])-before])
	for key: String in change.get("items", {}):
		data().inventory[key] = int(data().inventory[key])+int(change.items[key])
		records.append("%s%s%d" % [String(ITEM_NAMES[key]),"+" if int(change.items[key])>=0 else "",int(change.items[key])])
	for key: String in change.get("life", {}):
		data().life[key] = mini(100,int(data().life[key])+int(change.life[key]))
		records.append("%s+%d" % ["采集" if key=="gathering" else "学业",int(change.life[key])])
	for key: String in change.get("relations", {}):
		var before: int = int(state.relations.get(key,0))
		state.relations[key] = mini(20 if key in ["bai_muyao","su_wantang"] else 100,before+int(change.relations[key]))
		records.append("%s好感+%d" % [String(RELATION_NAMES.get(key,key)),int(state.relations[key])-before])
	if change.has("study"): data().life.study = mini(100,int(data().life.study)+int(change.study)); records.append("学业+%d" % int(change.study))
	if change.has("money"): state.money += int(change.money); records.append("资金%s%d" % ["+" if int(change.money)>=0 else "",int(change.money)])
	if change.has("contribution"): state.contribution += int(change.contribution); records.append("贡献+%d" % int(change.contribution))
	if change.has("awakening"): data().awakening = mini(100,int(data().awakening)+int(change.awakening)); records.append("觉醒度+%d" % int(change.awakening))
	if change.has("sl"): state.sl = clampi(state.sl+int(change.sl),0,100); records.append("SL%s%d" % ["+" if int(change.sl)>=0 else "",int(change.sl)])
	state.hp = mini(state.hp,state.max_hp())
	return " · ".join(records)


func perform(action: String, value: String = "") -> Dictionary:
	if action == "growth_event":
		if not available(): return _reply("先处理当前剧情。")
		var event: Dictionary = event_definition()
		if event.is_empty(): return _reply("这次闲逛已经结束。")
		if state.room!=event_room(event): return _reply("这次奇遇还没处理完。继续事件后再安排行动。")
		var response: Dictionary = {"dialogue":event.dialogue,"choices":_event_choices(event)}
		if event.has("callback") and data().seen.has(String(event.callback.requires)):
			response.dialogue = String(event.callback.dialogue)
		if not bool(data().event_started): response.cinematic=event_entrance(event)
		data().event_started=true
		return response
	if action == "growth_event_choice":
		if not available(): return _reply("先处理当前剧情。")
		var event: Dictionary = event_definition()
		if event.is_empty(): return _reply("这次事件已处理。")
		if value == "leave":
			data().active_event = ""
			data().event_started = false
			_record("结束闲逛；这次发现可在日后的闲逛中再遇见。")
			return _reply(String(data().last_result))
		if state.room!=event_room(event): return _reply("这次奇遇还没处理完。继续事件后再安排行动。")
		if not value.is_valid_int() or int(value)<0 or int(value)>=event.options.size(): return _event_problem(event,"选择无效，请重新选择。")
		var result: Dictionary = event.options[int(value)]
		if state.money+int(result.get("money",0))<0: return _event_problem(event,"钱不够。可以换一个选项，或先离开。")
		for key: String in result.get("items",{}):
			if int(data().inventory.get(key,0))+int(result.items[key])<0: return _event_problem(event,"行囊里没有半价券。可以换一个选项，或先离开。")
		var text_value: String = String(event.name) + "：" + _apply(result)
		data().seen.append(String(event.id))
		data().active_event = ""
		data().event_started = false
		_record(text_value)
		state.journal.append(calendar.date_text()+" · "+String(event.name)+"："+String(result.label))
		var response: Dictionary = _reply(text_value,String(result.get("dialogue","c2_grow_result")))
		if result.has("cinematic"): response.cinematic=String(result.cinematic)
		return response
	if action == "growth_deliver":
		if state.room!="cbd": return _reply("需要前往管理局服务大厅实际交件。")
		if String(data().job)!="courier": return _reply("当前没有待交接的送件委托。")
		var job: Dictionary = config.jobs.courier
		data().jobs_done.courier = int(data().job_week)
		data().job = ""
		var text_value: String = "送件完成：" + _apply(job)
		_record(text_value)
		return _reply(text_value,"c2_grow_delivery")
	if not available(): return _reply("先处理学生证上正在进行的剧情或任务。")
	if action == "growth_herb":
		if int(data().inventory.herb)<=0: return _reply("行囊里没有灵草。")
		data().inventory.herb = int(data().inventory.herb)-1
		state.hp = mini(state.max_hp(),state.hp+45); state.sl = maxi(0,state.sl-10)
		_record("服用灵草：HP恢复45，SL降低10（不超过上限）。")
		return _reply(String(data().last_result))
	if action == "growth_sell":
		var count: int = int(data().inventory.herb)
		if count<=0: return _reply("还没有可出售的灵草。")
		data().inventory.herb = 0
		state.money += count*30
		_record("交售灵草%d份：资金+%d。" % [count,count*30])
		return _reply(String(data().last_result))
	if not String(data().active_event).is_empty(): return _reply("先做完这次奇遇的选择，或选择离开。")
	if action == "growth_night":
		if not value in ["read","wen"] or not calendar.spend("social",true): return _reply("夜间需要先完成两次日间行动；每晚可安排一次。")
		var text_value: String = "夜读："+_apply({"study":5,"sl":-10}) if value=="read" else "和温让夜谈："+_apply({"relations":{"wen_rang":5},"sl":-5})
		state.chapter_two.social_visits = int(state.chapter_two.social_visits)+1
		_record(text_value)
		return _reply(text_value,"c2_grow_night")
	if not calendar.can_act(): return _reply("白天行动已用完；夜间可社交，休息到明天再安排。")
	match action:
		"growth_notes":
			if not value in ["notes","insight"] or int(data().inventory[value])<=0: return _reply("行囊里没有这份笔记。")
			calendar.spend("training")
			data().inventory[value] = int(data().inventory[value])-1
			var text_value: String = "研读笔记："+_apply({"awakening":10 if value=="notes" else 20,"skills":{"strike":8},"study":4})
			_record(text_value)
			return _reply(text_value)
		"growth_train":
			if not config.training.has(value): return _reply("这项修炼尚未开放。")
			calendar.spend("training")
			state.chapter_two.training = int(state.chapter_two.training)+1
			var training: Dictionary = config.training[value]
			var text_value: String = String(training.name) + "：" + _apply(training)
			_record(text_value)
			return _reply(text_value,"c2_grow_training")
		"growth_roam":
			if not config.places.has(value): return _reply("地点尚未开放。")
			calendar.spend("roam")
			data().explorations = int(data().explorations)+1
			var candidates: Array[Dictionary] = []
			var characters: Array[Dictionary] = []
			for event: Dictionary in events:
				if String(event.area)==value and eligible(event):
					candidates.append(event)
					if event.get("character_event",false): characters.append(event)
			if not characters.is_empty(): candidates=characters
			state.room = String(config.places[value].room)
			state.player_position = Vector2.ZERO
			data().event_area = value
			data().event_started = false
			if candidates.is_empty():
				var text_value: String = "闲逛归来：" + _apply({"awakening":1,"study":2})
				_record(text_value)
				return {"dialogue":"c2_grow_quiet","remark":text_value,"remark_speaker":"成长记录"}
			var index: int = posmod(int(state.chapter_two.day)*17+int(data().explorations)*23,candidates.size())
			data().active_event = String(candidates[index].id)
			state.room = event_room(candidates[index])
			_record("闲逛遇见："+String(candidates[index].name)+"。")
			return perform("growth_event")
		"growth_job":
			if not config.jobs.has(value): return _reply("委托尚未开放。")
			if int(data().jobs_done.get(value,-1))==int(state.chapter_two.week): return _reply("这项委托本周已经完成，等任务板刷新。")
			if value=="courier" and not String(data().job).is_empty(): return _reply("先送完已接的文件。")
			calendar.spend("help")
			var job: Dictionary = config.jobs[value]
			if value=="courier":
				data().job = value; data().job_week = int(state.chapter_two.week)
				_record("接取送件：前往管理局服务大厅，找受理员交件。")
				return _reply(String(data().last_result),"c2_grow_courier")
			data().jobs_done[value] = int(state.chapter_two.week)
			var text_value: String = String(job.name)+"："+_apply(job)
			_record(text_value)
			return _reply(text_value,"c2_grow_job")
		"growth_breakthrough":
			if String(data().rank)!="D" or int(data().awakening)<100: return _reply("觉醒度达到100后，可在安全环境尝试D→C突破。")
			calendar.spend("training")
			data().attempts = int(data().attempts)+1
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = int(config.seed)+int(data().attempts)*101
			var success: bool = rng.randi_range(1,100)<=int(config.breakthrough_chance)
			if success:
				data().rank = "C"; data().level = 3; data().awakening = 0
				state.sl = 0; state.hp = state.max_hp()
				_record("安全突破成功：觉醒等级C，行动等级3；HP恢复，SL清零。")
			else:
				data().awakening = 65; state.sl = mini(100,state.sl+20); state.hp = maxi(1,state.hp-10)
				data().inventory.insight = int(data().inventory.insight)+1
				_record("突破未成：觉醒度回到65，SL+20；记下灵能收束的感悟，继续静心与训练。")
			return _reply(String(data().last_result),"c2_grow_breakthrough")
	return _reply("从修炼、闲逛、任务或生活栏选择今天的安排。")


static func validate(profile: Dictionary) -> bool:
	if profile.get("version")!="cultivation.1" or not profile.get("rank") in ["D","C"]: return false
	for key: String in ["level","awakening","attempts","explorations","job_week"]:
		if not ChapterTwoCalendar._integer(profile.get(key),0,100000): return false
	if int(profile.level)!=(2 if String(profile.rank)=="D" else 3) or int(profile.awakening)>100: return false
	for key: String in ["attributes","proficiency","life","inventory","jobs_done"]:
		if not profile.get(key) is Dictionary: return false
	for key: String in ATTRIBUTE_NAMES:
		if not ChapterTwoCalendar._integer(profile.attributes.get(key),10,40): return false
	for key: String in ["strike","sweep"]:
		if not ChapterTwoCalendar._integer(profile.proficiency.get(key),0,100): return false
	for key: String in ["gathering","study"]:
		if not ChapterTwoCalendar._integer(profile.life.get(key),0,100): return false
	for key: String in ITEM_NAMES:
		if not ChapterTwoCalendar._integer(profile.inventory.get(key),0,100000): return false
	for key: Variant in profile.jobs_done:
		if not String(key) in ["equipment","files","courier"] or not ChapterTwoCalendar._integer(profile.jobs_done[key],0,52): return false
	for key: String in ["seen","history"]:
		if not profile.get(key) is Array: return false
		for value: Variant in profile[key]:
			if not value is String: return false
	if profile.history.size()>20: return false
	for key: String in ["active_event","event_area","job","last_result"]:
		if not profile.get(key) is String: return false
	if not profile.get("event_started") is bool: return false
	if not String(profile.job) in ["","courier"] or not String(profile.event_area) in ["","campus","hill","street","training","dormitory"]: return false
	if not String(profile.active_event).is_empty() and not EVENT_AREAS.has(String(profile.active_event)): return false
	var seen: Array = []
	for id: String in profile.seen:
		if not EVENT_AREAS.has(id) or seen.has(id): return false
		seen.append(id)
	if String(profile.active_event).is_empty() and bool(profile.event_started): return false
	if not String(profile.active_event).is_empty() and EVENT_AREAS[String(profile.active_event)] != String(profile.event_area): return false
	return not seen.has(String(profile.active_event))
