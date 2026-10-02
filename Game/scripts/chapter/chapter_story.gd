class_name ChapterStory
extends RefCounted

const MENTOR_NAMES: Dictionary = {"liu": "柳无眠 · 摸鱼会", "shen": "沈听澜 · 幻影阁", "wen": "温若水 · 论道斋", "tang": "唐半夏 · 百草堂"}
const BONUSES: Dictionary = {"liu": "AGI +3 · 连携伤害 +5%", "shen": "WIL +3 · SL增幅 -5%", "wen": "SPI +3 · 技能CD -1", "tang": "CON +3 · HP上限 +10%"}
const ROOM_NAMES: Dictionary = {"gate": "学院校门", "assembly_stage": "学院大会场·主席台", "auditorium": "报到礼堂", "plaza": "学院大会场展区", "training": "训练场", "lab": "试验区", "infirmary": "医务室", "cafe": "商业街奶茶店", "hill": "后山灵草圃", "clubs": "操场·社团招新", "dorm": "男生宿舍·寝室", "corridor":"宿舍楼·共用走廊", "cult_library":"学院图书馆", "cult_ice_shop":"老街·苏家冰品店", "hall": "学院任务大厅", "cbd": "管理局服务大厅", "c2_dorm": "男生宿舍·寝室与课表", "c2_infirmary": "医务室·复筛室", "c2_classroom": "教学楼", "c2_training": "训练场", "c2_clubs": "社团活动室", "c2_port": "港口执勤点", "c2_rift": "小裂隙·浅层", "c2_bar": "裂隙猎人酒吧"}
var state: ChapterSession
var choice_text: Dictionary = {}


func _init(source: ChapterSession) -> void:
	state = source
	choice_text = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter1/choices.json")) as Dictionary


func objective() -> String:
	match state.phase:
		"arrival": return "和温让进入报到礼堂" if state.room == "gate" else "到考官面前，完成入学测试"
		"mentors": return "体验四山头任务，确认拜入一位导师"
		"cafe": return "拜师登记完成，苏挽颜来找你"
		"hill": return "到后山入口，完成三段野兔清剿"
		"clubs": return "逛完可找温让一起回宿舍" if state.flags.get("clubs_seen",false) else "沿操场看招新摊，和温让拿几张传单"
		"dorm":
			if not state.flags.get("ling_seen", false): return "和温让夜谈，接凌未央的视频"
			if not state.flags.get("chuxia_seen", false): return "到楼道，和林初夏说话"
			return "回床铺休息，明早去任务大厅"
		"hall": return "刷学生证，接首个★帮忙任务"
		"delivery": return "回任务大厅结算送件任务" if state.flags.get("delivered", false) else "用城市地图去管理局前台送文件"
		_: return "第1章·入学日已完成"


func locations() -> Array[String]:
	match state.phase:
		"arrival": return ["auditorium"]
		"mentors": return ["plaza", "training", "lab", "infirmary"]
		"cafe": return [state.room if state.room != "cafe" else "plaza"]
		"hill": return ["hill"]
		"clubs": return ["hill", "clubs"]
		"dorm":
			if state.flags.get("ling_seen",false): return ["dorm","corridor"]
			return ["dorm"]
		"hall": return ["hall"]
		"delivery": return ["hall", "cbd"]
		_: return ["hall", "cbd"]


func travel(room: String) -> bool:
	if not locations().has(room):
		return false
	state.room = room
	state.record("travel", {"room": room})
	return true


func _line(id: String, choices: Array = []) -> Dictionary:
	return {"dialogue": id, "choices": choices}


func _choice(label: String, action: String, value: String = "") -> Dictionary:
	return {"label": label, "action": action, "value": value}


func _text(key: String, index: int = -1) -> String:
	return String(choice_text[key][index]) if index >= 0 else String(choice_text[key])


func _offer(mentor: String) -> Dictionary:
	if not state.mentor.is_empty():
		return _line("mentor_locked")
	return _line(mentor + "_ready", [_choice(_text("join").format({"mentor": MENTOR_NAMES[mentor]}), "join", mentor), _choice(_text("look_around"), "close")])


func _shen_question() -> Dictionary:
	var answers: Array = state.flags.get("shen_answers", [])
	if answers.size() >= 3:
		state.mark("shen_done", "完成沈听澜的三道情境题。")
		var result: Dictionary = _offer("shen")
		var counts: Array[int] = [0, 0, 0]
		for answer: Variant in answers: counts[int(answer)] += 1
		var preferred: int = int(answers.back())
		for index: int in range(3):
			if counts[index] > counts[preferred]: preferred = index
		result["remark"] = _text("shen_remarks", preferred)
		return result
	var options: Array[Dictionary] = []
	var texts: Array = choice_text.shen_options
	for index: int in range(3):
		options.append(_choice(String(texts[answers.size()][index]), "shen_answer", str(index)))
	return _line("shen_q%d" % answers.size(), options)


func _firstaid() -> Dictionary:
	return _line("cabinet_right", [_choice(_text("firstaid", 0), "firstaid", "0"), _choice(_text("firstaid", 1), "firstaid", "1"), _choice(_text("firstaid", 2), "firstaid", "2")])


func perform(action: String, value: String = "") -> Dictionary:
	if action == "close": return {}
	state.record("interaction", {"action": action, "value": value})
	match action:
		"wen_rang": return _line("wen_arrival")
		"exam":
			if state.phase != "arrival": return _line("tested")
			state.mark("tested", "入学测试：D级，污染筛查通过。")
			state.sl = int(state.settings.get("test_sl", 5))
			state.phase = "mentors"
			return _line("exam")
		"liu", "shen", "wen", "tang":
			if state.phase != "mentors": return _line("mentor_locked")
			if state.flags.get(action + "_done", false): return _offer(action)
			if action == "liu" and state.flags.get("comic_found", false):
				state.mark("liu_done", "找回限量版漫画。")
				return _offer("liu")
			if action == "wen" and state.flags.get("sample_fire", false) and state.flags.get("sample_water", false) and state.flags.get("sample_earth", false):
				state.mark("wen_done", "交齐火、水、土三份样本。")
				return _offer("wen")
			if action == "shen" and state.flags.get("shen_started", false): return _shen_question()
			if action == "tang" and state.flags.get("cabinet_sorted", false): return _firstaid()
			if state.mark(action + "_started"):
				return _line(action, [_choice(_text("shen_begin"), "shen_question")] if action == "shen" else [])
			return _line(action + "_wait" if action in ["liu", "wen"] else action)
		"shen_question":
			if state.phase != "mentors" or not state.flags.get("shen_started", false): return _line("not_ready")
			return _shen_question()
		"shen_answer":
			if state.phase != "mentors" or not state.flags.get("shen_started", false): return _line("not_ready")
			var answers: Array = state.flags.get("shen_answers", [])
			if answers.size() < 3 and value in ["0", "1", "2"]:
				answers.append(int(value))
				state.flags["shen_answers"] = answers
			return _shen_question()
		"comic":
			if state.phase != "mentors" or not state.flags.get("liu_started", false): return _line("item_wait")
			return _line("comic" if state.mark("comic_found") else "item_done")
		"sample_fire", "sample_water", "sample_earth":
			if state.phase != "mentors" or not state.flags.get("wen_started", false): return _line("item_wait")
			return _line(action if state.mark(action) else "item_done")
		"cabinet":
			if state.phase != "mentors" or not state.flags.get("tang_started", false): return _line("item_wait")
			if state.flags.get("tang_done", false): return _line("item_done")
			if state.flags.get("cabinet_sorted", false): return _firstaid()
			return _line("cabinet", [_choice(_text("sort", 0), "sort", "correct"), _choice(_text("sort", 1), "sort", "wrong"), _choice(_text("sort", 2), "sort", "wrong")])
		"sort":
			if state.phase != "mentors" or not state.flags.get("tang_started", false): return _line("not_ready")
			if value != "correct": return _line("cabinet_wrong", [_choice(_text("retry_sort"), "cabinet")])
			state.mark("cabinet_sorted")
			return _firstaid()
		"firstaid":
			if state.phase != "mentors" or not state.flags.get("cabinet_sorted", false): return _line("not_ready")
			if value != "1": return _line("firstaid_wrong", [_choice(_text("retry_firstaid"), "cabinet")])
			state.mark("tang_done", "整理药柜，完成急救问答。")
			return _offer("tang")
		"join":
			if state.phase != "mentors" or not state.mentor.is_empty() or not ChapterSession.MENTORS.has(value) or not state.flags.get(value + "_done", false): return _line("not_ready")
			state.mentor = value
			state.mark("apprenticed", "拜入" + String(MENTOR_NAMES[value]) + "。" + String(BONUSES[value]))
			if value == "tang": state.hp = state.max_hp()
			state.phase = "cafe"
			return _line("joined_" + value)
		"su_cafe":
			if state.phase != "cafe": return _line("not_ready")
			state.mark("su_visit_seen", "拜师结束，苏挽颜主动来到展区。")
			return _line("su_cafe", [_choice(_text("su", 0), "accept_su", "0"), _choice(_text("su", 1), "accept_su", "1"), _choice(_text("su", 2), "accept_su", "2")])
		"accept_su":
			if state.phase != "cafe" or not value in ["0", "1", "2"]: return _line("not_ready")
			if state.mark("hill_accepted", "苏挽颜委托：明早清后山野兔。获得两张冰品店半价券。"):
				state.relations.su = int(state.relations.su) + (5 if value == "0" else 3 if value == "1" else 0)
				state.flags["invite_wen"] = value == "2"
			state.phase = "hill"
			state.room = "hill"
			var result: Dictionary = _line("su_accept" + value)
			result["extra"] = "day_one_close"
			return result
		"hill":
			if state.phase != "hill": return _line("hill_return")
			var result: Dictionary = _line("hill_intro", [_choice(_text("hill", 0), "battle"), _choice(_text("hill", 1), "close")])
			result["extra"] = "hill_wen" if state.flags.get("invite_wen", false) else ""
			return result
		"battle":
			return {"battle": true} if state.phase == "hill" else _line("not_ready")
		"clubs":
			if state.phase != "clubs" or state.room!="clubs": return _line("not_ready")
			state.mark("clubs_seen", "拿到社团活动传单；正式报名在1月4日起开放。")
			return _line("clubs",[_choice(_text("clubs_exit",0),"close"),_choice(_text("clubs_exit",1),"clubs_leave")])
		"club_sword", "club_element", "club_healing":
			if state.phase!="clubs" or state.room!="clubs": return _line("not_ready")
			state.mark(action+"_visited")
			return _line(action)
		"clubs_leave":
			if state.phase!="clubs" or state.room!="clubs" or not state.flags.get("clubs_seen",false): return _line("not_ready")
			state.phase="dorm"
			return {"dialogue":"clubs_depart", "after_dialogue_cinematic":"clubs_to_dorm", "after_dialogue_response":{"dialogue":"dorm_arrive"}}
		"dorm_exit":
			if state.phase!="dorm" or state.room!="dorm" or not state.flags.get("ling_seen",false): return _line("not_ready")
			return {"cinematic":"dorm_to_corridor"}
		"dorm_enter":
			if state.phase!="dorm" or state.room!="corridor": return _line("not_ready")
			return {"cinematic":"corridor_to_dorm"}
		"dorm_wen":
			if state.phase != "dorm" or state.room!="dorm": return _line("not_ready")
			state.mark("dorm_talk", "和温让同寝。")
			state.mark("ling_seen", "接到凌未央的视频。")
			var result: Dictionary = _line("dorm")
			result["extra"] = "ling"
			return result
		"chuxia":
			if state.phase != "dorm" or state.room!="corridor" or not state.flags.get("ling_seen",false): return _line("not_ready")
			if state.flags.get("chuxia_seen",false): return _line("chuxia_repeat")
			state.mark("chuxia_seen", "楼道初见林初夏。")
			return {"cinematic":"chuxia_corridor", "dialogue":"chuxia", "after_dialogue_cinematic":"chuxia_leave"}
		"sleep":
			if state.phase != "dorm" or state.room!="dorm" or not state.flags.get("ling_seen", false) or not state.flags.get("chuxia_seen", false): return _line("not_ready")
			state.mark("slept", "01-03：任务大厅开放。")
			if bool(state.settings.sleep.get("restore_hp", true)): state.hp = state.max_hp()
			state.sl = int(state.settings.sleep.sl)
			state.phase = "hall"
			state.room = "hall"
			return _line("sleep")
		"task":
			if state.phase == "delivery":
				if state.flags.get("delivered", false):
					if state.mark("task_rewarded", "完成★送件任务：%d元，贡献%d。" % [int(state.settings.delivery_reward.money), int(state.settings.delivery_reward.contribution)]):
						state.money += int(state.settings.delivery_reward.money)
						state.contribution += int(state.settings.delivery_reward.contribution)
					state.phase = "complete"
					return _line("task_report")
				return _line("task_accepted")
			if state.phase == "complete": return _line("item_done")
			if state.phase != "hall": return _line("not_ready")
			return _line("task", [_choice(_text("task", 0), "accept_task"), _choice(_text("task", 1), "close")])
		"accept_task":
			if state.phase != "hall": return _line("not_ready")
			state.mark("task_accepted", "接取★送件任务，城市地图解锁。")
			state.phase = "delivery"
			return _line("task_accepted")
		"reception":
			if state.phase != "delivery": return _line("not_ready")
			return _line("reception" if state.mark("delivered", "管理局前台已签收。回学院任务大厅结算。") else "delivered")
	if action.begins_with("academy_"): return _line("c2_venue_academy")
	if action.begins_with("recruit_"): return _line("clubs_crowd")
	if action.begins_with("bureau_"): return _line("c2_venue_bureau")
	return _line("not_ready")


func finish_battle(hp_value: int, sl_value: int, log_data: Dictionary) -> bool:
	if state.phase != "hill" or hp_value <= 0 or not log_data.get("flow", "") == "complete":
		return false
	state.hp = clampi(hp_value, 1, state.max_hp())
	state.sl = clampi(sl_value, 0, 100)
	state.tutorial_log = log_data.duplicate(true)
	state.mark("hill_done", "完成后山野兔清剿三段。")
	state.phase = "clubs"
	return true
