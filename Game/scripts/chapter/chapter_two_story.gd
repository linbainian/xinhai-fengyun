class_name ChapterTwoStory
extends ChapterStory

var calendar: ChapterTwoCalendar
var config: Dictionary
var chapter_choices: Dictionary
var growth: ChapterCultivation


func _init(source: ChapterSession) -> void:
	super(source)
	calendar = ChapterTwoCalendar.new(source)
	config = calendar.config
	growth = ChapterCultivation.new(source,calendar)
	chapter_choices = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter2/choices.json")) as Dictionary


func objective() -> String:
	var data: Dictionary = state.chapter_two
	if not String(data.cultivation.active_event).is_empty(): return "奇遇进行中，观看场景后选择"
	match String(data.stage):
		"interlude":
			if String(data.cultivation.job)=="courier": return "送件委托：去管理局大厅交件；1月15日参加复筛"
			return "自由安排修炼、闲逛和委托 [C]；1月15日参加复筛"
		"rescreen":
			if not state.flags.get("c2_notice_seen", false): return "和温让看看学生证上的复筛通知"
			if not state.flags.get("c2_exam_done", false): return "到医务室，找唐半夏完成复筛"
			return "看看同批名单和封存箱，再和唐半夏确认归档"
		"campus":
			if String(data.club).is_empty(): return "到社团活动室，选社团或暂不参加"
			if calendar.ready_for_port(): return "港口★★委托开放，去学院任务大厅选择协作路线"
			return "安排上课、修炼与社交；02-01后去任务大厅接港口委托"
		"port": return "前往港口，找协作联系人登记进入裂隙"
		"rift":
			if not data.cleared.has("entry"): return "清理入口异兽，确保撤离通道"
			if String(data.storm).is_empty(): return "灵能风暴将至，找到掩体应对"
			return "前往残骸区，清理剩余异兽"
		"clue": return "检查异兽尸体的切口，拍照并决定线索去向"
		"report":
			if String(data.clue_destination) == "bureau" and not state.flags.get("c2_clue_delivered", false): return "到管理局服务大厅，上交切口照片"
			if String(data.clue_destination) == "bar" and not state.flags.get("c2_clue_delivered", false): return "去裂隙猎人酒吧，向老猎人问切口的事"
			return "回学院任务大厅，交回记录并结算★★任务"
		_: return "第2章·复筛已完成，可以继续校园活动"


func locations() -> Array[String]:
	if String(state.chapter_two.stage) == "rescreen": return ["c2_dorm", "c2_infirmary"]
	if String(state.chapter_two.stage) in ["rift", "clue"]: return ["c2_rift", "c2_port"]
	var result: Array[String] = ["c2_dorm", "c2_classroom", "c2_training", "c2_clubs", "hall", "c2_infirmary"]
	if String(state.chapter_two.stage) in ["interlude", "campus", "complete"]:
		result.append("hill")
		result.append("cafe")
		result.append("cbd")
		for room: String in ["corridor","cult_library","cult_ice_shop"]: result.append(room)
	if not String(state.chapter_two.route).is_empty(): result.append("c2_port")
	if String(state.chapter_two.stage) in ["report", "complete"]:
		if not result.has("cbd"): result.append("cbd")
		if String(state.chapter_two.clue_destination) == "bar": result.append("c2_bar")
	return result


func _options(key: String) -> Array:
	return chapter_choices.get(key, []).duplicate(true)


func _reply(id: String, key: String = "") -> Dictionary:
	return {"dialogue": "c2_" + id, "choices": _options(key)}


func _unavailable() -> Dictionary:
	return _reply("night_full" if int(state.chapter_two.slot) == 2 else "not_ready")


func perform(action: String, value: String = "") -> Dictionary:
	var data: Dictionary = state.chapter_two
	if action == "close": return {}
	state.record("interaction", {"action": action, "value": value, "chapter": 2})
	if action.begins_with("growth_"): return growth.perform(action,value)
	match action:
		"dorm_exit": return {"cinematic":"c2_dorm_to_corridor"} if state.room=="c2_dorm" else _reply("not_ready")
		"dorm_enter": return {"cinematic":"c2_corridor_to_dorm"} if state.room=="corridor" else _reply("not_ready")
		"corridor_daily": return _reply("grow_corridor_daily")
		"library_daily": return _reply("grow_library_daily")
		"ice_shop_daily": return _reply("grow_ice_daily")
		"chuxia": return _reply("grow_corridor_daily")
		"c2_notice":
			if int(data.day)<int(config.rescreen_day): return {"dialogue":"c2_grow_intro","open_cultivation":true}
			state.mark("c2_notice_seen", "01-15：收到异常复筛通知，前往医务室。")
			return _reply("notice")
		"c2_exam":
			if String(data.stage) != "rescreen": return _reply("doctor_daily")
			if not state.flags.get("c2_notice_seen", false): return _reply("not_ready")
			if not state.flags.get("c2_exam_done", false):
				state.mark("c2_exam_done", "完成异常复筛；统计学观察对象，污染筛查通过。")
				state.relations.jiang = maxi(15, int(state.relations.jiang))
				state.relations.chuxia = maxi(20, int(state.relations.chuxia))
				var result: Dictionary = _reply("rescreen")
				result["cinematic"] = "c2_rescreen"
				return result
			if not state.flags.get("c2_list_seen", false) or not state.flags.get("c2_box_seen", false): return _reply("doctor_wait")
			state.mark("c2_rescreen_done", "复筛名单同框：林大、林初夏、江北辰；记录封箱归档。")
			data.stage = "campus"
			return _reply("rescreen_done")
		"c2_list":
			if not state.flags.get("c2_exam_done", false): return _reply("not_ready")
			state.mark("c2_list_seen")
			return _reply("list")
		"c2_box":
			if not state.flags.get("c2_exam_done", false): return _reply("not_ready")
			state.mark("c2_box_seen")
			var result: Dictionary = _reply("box")
			result["cinematic"] = "c2_seal"
			return result
		"c2_club_signup":
			return _reply("club_repeat", "campus") if not String(data.club).is_empty() else _reply("club_signup", "clubs")
		"c2_join_club":
			if not String(data.stage) in ["interlude","campus"] or not String(data.club).is_empty() or not ChapterTwoCalendar.CLUBS.has(value): return _reply("not_ready")
			data.club = value
			state.journal.append("社团登记：" + String(ChapterTwoCalendar.CLUBS[value]) + "。")
			return _reply("club_none" if value == "none" else "club_joined")
		"c2_class", "c2_training", "c2_club_activity", "c2_rest":
			if String(data.stage) in ["rescreen", "port", "rift", "clue", "report"] or not calendar.can_act(): return _unavailable()
			if not String(data.cultivation.active_event).is_empty(): return growth._reply("先处理这次闲逛发现。")
			if action == "c2_training":
				var response: Dictionary = growth.perform("growth_train","force")
				response.open_cultivation = false
				return response
			if action == "c2_club_activity" and String(data.club) in ["", "none"]: return _reply("club_no_membership")
			var kind: String = {"c2_class": "class", "c2_training": "training", "c2_club_activity": "club", "c2_rest": "rest"}[action]
			calendar.spend(kind)
			if kind == "class":
				data.classes = int(data.classes) + 1
				growth._record("上课："+growth._apply({"study":5,"awakening":2}))
			elif kind == "training": data.training = int(data.training) + 1; state.sl = mini(100, state.sl + 5)
			elif kind == "club":
				data.club_visits = int(data.club_visits) + 1
				growth._record("社团活动："+growth._apply({"awakening":3,"skills":{"sweep":2},"relations":{"wen_rang":1}}))
			else: state.hp = state.max_hp(); state.sl = maxi(0, state.sl-int(config.rest_sl_recovery))
			return _reply(kind)
		"c2_schedule": return _reply("schedule", "campus")
		"c2_sleep": return _reply("sleep_offer", "sleep")
		"c2_sleep_now":
			if String(data.stage) in ["rescreen", "rift", "clue"]: return _reply("not_ready")
			if not String(data.cultivation.active_event).is_empty(): return growth._reply("先处理闲逛发现，或选择离开这次事件。")
			if int(data.day)>=365: return _reply("calendar_end")
			var result: Dictionary = calendar.sleep()
			state.room = "c2_dorm"
			var response: Dictionary = _reply("week" if result.has("week") else "sleep")
			response["cinematic"] = "c2_sleep"
			return response
		"c2_repeat_week":
			if not String(data.stage) in ["interlude", "campus", "complete"]: return _reply("not_ready")
			if not String(data.cultivation.active_event).is_empty(): return growth._reply("先处理这次闲逛发现。")
			if int(data.day)>358: return _reply("calendar_end")
			var start_day: int = int(data.day)
			# A preset uses the normal daytime actions and skips optional evening socializing.
			for day: int in range(7):
				while calendar.can_act():
					var kind: String = "class" if int(data.slot) == 0 else "training" if String(data.club) in ["","none"] or day % 2 == 0 else "club"
					perform({"class":"c2_class", "training":"c2_training", "club":"c2_club_activity"}[kind])
				calendar.sleep()
				if String(data.stage) == "rescreen": break
			state.room = "c2_dorm"
			var response: Dictionary = _reply("routine")
			response["remark"] = "已预排%d天。" % (int(data.day)-start_day) + ("复筛已到期，先参加本次检查。" if String(data.stage)=="rescreen" else "成长与周记录已保存。")
			response["remark_speaker"] = "日程记录"
			response["cinematic"] = "c2_sleep"
			return response
		"c2_wen", "c2_jiang", "c2_chuxia":
			var id: String = {"c2_wen": "wen_rang", "c2_jiang": "jiang", "c2_chuxia": "chuxia"}[action]
			if id=="jiang" and String(data.stage)=="interlude": return _reply("not_ready")
			var result: Dictionary = _reply(id, "social")
			for option: Dictionary in result.choices: option.value = id
			return result
		"c2_social":
			if not ChapterTwoCalendar.COMPANIONS.has(value) or not String(data.stage) in ["interlude", "campus", "complete"]: return _reply("not_ready")
			if String(data.stage)=="interlude" and value=="jiang": return _reply("not_ready")
			if not calendar.spend("social", true): return _reply("social_time")
			data.social_visits = int(data.social_visits)+1
			state.relations[value] = mini(100,int(state.relations.get(value,0))+5)
			return _reply("social_" + value)
		"c2_invite":
			if not String(data.stage) in ["campus","complete"]: return _reply("not_ready")
			var reason: String = calendar.recruit_reason(value)
			if not reason.is_empty(): return {"remark": reason, "remark_speaker": String(config.party.get(value, {}).get("name", "系统提示"))}
			data.party.append(value)
			state.journal.append(String(config.party[value].name) + "加入同行队伍。")
			return _reply("invited_" + value)
		"c2_dismiss":
			if data.party.has(value):
				data.party.erase(value)
				return _reply("dismissed_" + value)
			return _reply("dismissed")
		"task", "c2_board":
			if String(data.stage)=="interlude": return {"dialogue":"c2_grow_board","open_cultivation":true}
			if String(data.stage) == "report": return _report()
			if String(data.stage) in ["port", "rift", "clue"]: return _reply("task_active")
			if String(data.stage) == "complete": return _reply("task_done", "help")
			return _reply("tasks_ready", "routes") if calendar.ready_for_port() else _reply("tasks_wait", "help")
		"c2_help":
			if not value in ["campus","files"]: return _reply("not_ready")
			var response: Dictionary = growth.perform("growth_job","equipment" if value=="campus" else "files")
			response.open_cultivation = false
			return response
		"c2_accept_route":
			if String(data.stage) != "campus" or not calendar.ready_for_port() or not value in ["bureau", "mutual"]: return _reply("not_ready")
			if not calendar.can_act(): return _reply("port_tomorrow")
			data.route = value
			data.stage = "port"
			state.mark("c2_task_accepted", "接取港口★★小裂隙清剿：" + ("管理局协作。" if value == "bureau" else "互助会协作。"))
			return _reply("route_"+value)
		"c2_contact":
			if not String(data.stage) in ["port", "rift", "clue"]: return _reply("contact_repeat")
			return _reply("contact_"+String(data.route), "port")
		"c2_enter_rift":
			if not String(data.stage) in ["port", "rift", "clue"]: return _reply("not_ready")
			if String(data.stage) == "port":
				if not calendar.can_act(): return _reply("port_tomorrow")
				while calendar.can_act(): calendar.spend("rift")
				data.stage = "rift"
			var first: bool = state.mark("c2_rift_entered", "进入港口小裂隙浅层，撤离通道已登记。")
			state.room = "c2_rift"
			var result: Dictionary = _reply("rift_entry" if first else "rift_return")
			result["cinematic"] = "c2_rift_entry"
			return result
		"c2_entry", "c2_final":
			var encounter: String = "entry" if action == "c2_entry" else "final"
			if String(data.stage) != "rift" or data.cleared.has(encounter): return _reply("battle_done")
			if encounter == "final" and (not data.cleared.has("entry") or String(data.storm).is_empty()): return _reply("rift_locked")
			return {"battle": true, "encounter": encounter}
		"c2_storm":
			if not data.cleared.has("entry"): return _reply("rift_locked")
			return _reply("storm_done") if not String(data.storm).is_empty() else _reply("storm", "storm")
		"c2_storm_choice":
			if not data.cleared.has("entry") or not String(data.storm).is_empty() or not value in ["shelter", "push"]: return _reply("not_ready")
			data.storm = value
			if value == "push":
				state.hp = maxi(1,state.hp-int(config.storm_hp)); state.sl = mini(100,state.sl+int(config.storm_sl))
				for id: String in data.party:
					if int(data.party_vitals[id].hp)>0:
						data.party_vitals[id].hp = maxi(1,int(data.party_vitals[id].hp)-int(config.storm_hp))
					data.party_vitals[id].sl = mini(100,int(data.party_vitals[id].sl)+int(config.storm_sl))
			var result: Dictionary = _reply("storm_" + value)
			result["cinematic"] = "c2_storm_" + value
			return result
		"c2_deep": return _reply("deep")
		"c2_corpse":
			if not data.cleared.has("final"): return _reply("rift_locked")
			state.mark("c2_cuts_seen", "异兽尸体上有三道等间距的平行采集切口。")
			return _reply("cuts", "photo") if not state.flags.get("c2_photo", false) else _reply("photo_done", "clues")
		"c2_photo":
			if not state.flags.get("c2_cuts_seen", false): return _reply("not_ready")
			state.mark("c2_photo", "拍下切口、标尺与周围残骸，保存原始照片。")
			return _reply("photo", "clues")
		"c2_clue_choice":
			if String(data.stage) != "clue" or not state.flags.get("c2_photo", false) or not value in ["bureau", "bar", "keep"]: return _reply("not_ready")
			data.clue_destination = value
			data.stage = "report"
			if value == "keep": state.mark("c2_clue_delivered")
			state.room = "c2_port"
			var result: Dictionary = _reply("clue_"+value)
			result["cinematic"] = "c2_leave_rift"
			return result
		"c2_retreat":
			if not String(data.stage) in ["rift", "clue"]: return _reply("not_ready")
			data.retreats = int(data.retreats)+1
			state.room = "c2_port"
			return _reply("retreat")
		"c2_resupply":
			if not String(data.stage) in ["port", "rift", "clue"]: return _reply("not_ready")
			state.hp = state.max_hp(); state.sl = 0
			for id: String in ChapterTwoCalendar.COMPANIONS:
				data.party_vitals[id] = {"hp": int(config.party[id].max_hp), "sl": 0}
			return _reply("resupply")
		"reception":
			if String(data.cultivation.job)=="courier": return growth.perform("growth_deliver")
			if String(data.stage) != "report" or String(data.clue_destination) != "bureau": return _reply("bureau_daily")
			if state.mark("c2_clue_delivered", "切口照片已提交管理局，取得回执号。"):
				data.reputation.bureau = int(data.reputation.bureau)+int(config.reputation.clue)
			return _reply("clue_bureau_delivered")
		"c2_bar":
			if String(data.clue_destination) != "bar": return _reply("bar_daily")
			state.mark("c2_bar_greeted")
			return _reply("bar")
		"c2_old_hunter":
			if String(data.stage) != "report" or String(data.clue_destination) != "bar" or not state.flags.get("c2_bar_greeted",false): return _reply("bar_daily")
			if state.mark("c2_clue_delivered", "老猎人：这半年见过不止一次这样的切口。"):
				data.reputation.mutual = int(data.reputation.mutual)+int(config.reputation.clue)
			return _reply("old_hunter")
		"c2_han", "c2_qin":
			var result: Dictionary = _reply("han" if action == "c2_han" else "qin", "hunter")
			for option: Dictionary in result.choices: option.value = "han" if action == "c2_han" else "qin"
			return result
	return _reply("venue_academy" if action.begins_with("academy_") else "venue_bureau" if action.begins_with("bureau_") else "bar_daily" if action.begins_with("c2_bar_guest") else "not_ready")


func _report() -> Dictionary:
	var data: Dictionary = state.chapter_two
	if not state.flags.get("c2_clue_delivered",false): return _reply("report_wait")
	if not state.mark("c2_rewarded", "港口★★清剿任务已结算，切口线索去向存入档案。"):
		return _reply("task_done")
	data.grade = "S" if String(data.storm) == "shelter" and state.flags.get("c2_photo",false) and not bool(data.fallen) and int(data.retreats) == 0 else "A"
	state.money += int(config.rift_reward.money) + (int(config.rift_reward.s_bonus_money) if String(data.grade) == "S" else 0)
	state.contribution += int(config.rift_reward.contribution) + (int(config.rift_reward.s_bonus_contribution) if String(data.grade) == "S" else 0)
	data.reputation[String(data.route)] = int(data.reputation[String(data.route)])+int(config.reputation.route)
	data.stage = "complete"
	return _reply("report_s" if String(data.grade) == "S" else "report_a")


func finish_rift_battle(encounter: String, vitals: Dictionary, log_data: Dictionary) -> bool:
	var data: Dictionary = state.chapter_two
	if String(data.stage) != "rift" or data.cleared.has(encounter) or not config.encounters.has(encounter) or String(log_data.get("result","")) != "victory" or not vitals.has("lin_da"): return false
	if encounter == "final" and (not data.cleared.has("entry") or String(data.storm).is_empty()): return false
	for id: String in ["lin_da"] + data.party:
		if not vitals.get(id) is Dictionary: return false
		var maximum: int = state.max_hp() if id == "lin_da" else int(config.party[id].max_hp)
		var battle_maximum: int = ceili(maximum*BattleRules.new().breakthrough_success_multiplier)
		if not ChapterTwoCalendar._integer(vitals[id].get("hp"),0,battle_maximum) or not ChapterTwoCalendar._integer(vitals[id].get("sl"),0,100): return false
	state.hp = clampi(int(vitals.lin_da.hp), 1, state.max_hp())
	state.sl = clampi(int(vitals.lin_da.sl), 0, 100)
	for id: String in data.party:
		if not vitals.has(id): return false
		data.party_vitals[id] = {"hp": clampi(int(vitals[id].hp),0,int(config.party[id].max_hp)), "sl": clampi(int(vitals[id].sl),0,100)}
		if int(vitals[id].hp) == 0: data.fallen = true
	if int(vitals.lin_da.hp) <= 0: data.fallen = true
	data.cleared.append(encounter)
	data.battle_logs[encounter] = log_data.duplicate(true)
	state.record("rift_victory", {"encounter": encounter})
	if encounter == "final": data.stage = "clue"
	return true
