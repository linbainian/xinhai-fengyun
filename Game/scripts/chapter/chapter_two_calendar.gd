class_name ChapterTwoCalendar
extends RefCounted

const STAGES: Array[String] = ["interlude", "rescreen", "campus", "port", "rift", "clue", "report", "complete"]
const CLUBS: Dictionary = {"sword": "剑道社", "element": "元素研究社", "healing": "治愈社", "none": "暂不入社"}
const COMPANIONS: Array[String] = ["wen_rang", "jiang", "chuxia"]
var state: ChapterSession
var config: Dictionary


func _init(source: ChapterSession) -> void:
	state = source
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter2/settings.json")) as Dictionary


func begin() -> void:
	if not state.chapter_two.is_empty(): return
	state.chapter_two = {"version": String(config.version), "stage": "interlude", "day": int(config.start_day), "calendar_epoch": int(config.start_day),
		"slot": 0, "night_used": false, "club": "", "route": "", "clue_destination": "",
		"week": 0, "week_stats": {"class": 0, "training": 0, "club": 0, "help": 0}, "weeks": [],
		"classes": 0, "training": 0, "club_visits": 0, "social_visits": 0, "weekly_tasks": {},
		"party": [], "party_vitals": {}, "cleared": [], "battle_logs": {}, "storm": "",
		"grade": "", "reputation": {"bureau": 0, "mutual": 0}, "retreats": 0, "fallen": false, "cultivation": ChapterCultivation.fresh()}
	for id: String in ["jiang", "chuxia", "han", "qin", "bai_muyao", "su_wantang"]:
		if not state.relations.has(id): state.relations[id] = 0
	for id: String in COMPANIONS:
		state.chapter_two.party_vitals[id] = {"hp": int(config.party[id].max_hp), "sl": 0}
	state.phase = "cultivation"
	state.room = "c2_dorm"
	state.player_position = Vector2.ZERO
	state.record("cultivation_begin", {"day": int(config.start_day), "rescreen_day": int(config.rescreen_day)})
	state.journal.append("01-04：新生自由安排开始，每日两次日间行动、一次夜间社交；01-15参加复筛。")


static func normalize(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	if result.get("version") == "chapter2-prototype.1":
		result.version = "chapter2-prototype.2"
		result.calendar_epoch = 15
		result.cultivation = ChapterCultivation.fresh()
		var prior_tasks: Variant = result.get("weekly_tasks",{})
		if prior_tasks is Dictionary:
			for key: String in ["campus","files"]:
				if prior_tasks.has(key): result.cultivation.jobs_done["equipment" if key=="campus" else "files"] = prior_tasks[key]
	if result.get("cultivation") is Dictionary:
		var profile: Dictionary = result.cultivation
		if not profile.has("event_started"): profile.event_started=false
		if profile.get("inventory") is Dictionary and not profile.inventory.has("coupon"): profile.inventory.coupon=2
	return result


func date_text() -> String:
	return format_date(state.chapter_two)


static func format_date(data: Dictionary) -> String:
	var date: int = int(data.get("day", 15))
	var month: int = 1
	for days: int in [31,28,31,30,31,30,31,31,30,31,30,31]:
		if date <= days: break
		date -= days
		month += 1
	return "觉醒历22年 · %02d-%02d · %s" % [month, date, ["上午", "下午", "夜间"][int(data.get("slot", 0))]]


func can_act(night: bool = false) -> bool:
	return int(state.chapter_two.slot) == 2 and not bool(state.chapter_two.night_used) if night else int(state.chapter_two.slot) < 2


func spend(kind: String, night: bool = false) -> bool:
	if not can_act(night): return false
	if night: state.chapter_two.night_used = true
	else: state.chapter_two.slot = int(state.chapter_two.slot) + 1
	if state.chapter_two.week_stats.has(kind):
		state.chapter_two.week_stats[kind] = int(state.chapter_two.week_stats[kind]) + 1
	state.record("calendar_action", {"day": int(state.chapter_two.day), "kind": kind, "night": night})
	return true


func sleep() -> Dictionary:
	var data: Dictionary = state.chapter_two
	if int(data.day)>=365 or String(data.stage) == "rescreen" or not String(data.cultivation.active_event).is_empty(): return {"blocked":true}
	data.day = int(data.day) + 1
	data.slot = 0
	data.night_used = false
	state.hp = state.max_hp()
	state.sl = maxi(0, state.sl - int(config.sleep_sl_recovery))
	for id: String in COMPANIONS:
		data.party_vitals[id].hp = int(config.party[id].max_hp)
		data.party_vitals[id].sl = maxi(0, int(data.party_vitals[id].sl) - int(config.sleep_sl_recovery))
	var week: int = floori((int(data.day) - int(data.calendar_epoch)) / 7.0)
	var result: Dictionary = {}
	if week > int(data.week):
		result = {"week": week, "stats": data.week_stats.duplicate(), "contribution": int(config.weekly_reward.contribution)}
		data.weeks.append(result.duplicate(true))
		data.week = week
		data.week_stats = {"class": 0, "training": 0, "club": 0, "help": 0}
		state.contribution += int(config.weekly_reward.contribution)
		state.journal.append("第%d周结算：课业%d、修炼%d、社团%d；任务板已刷新。" % [week, int(result.stats["class"]), int(result.stats.training), int(result.stats.club)])
		state.record("week_settlement", result)
	if String(data.stage) == "interlude" and int(data.day) >= int(config.rescreen_day):
		data.stage = "rescreen"
		state.phase = "chapter_two"
		state.room = "c2_dorm"
		state.player_position = Vector2.ZERO
		result["rescreen"] = true
		state.record("chapter_begin", {"chapter":2,"day":int(data.day)})
	return result


func ready_for_port() -> bool:
	return state.flags.get("c2_rescreen_done", false) and int(state.chapter_two.day) >= int(config.port_unlock_day) and int(state.chapter_two.week) >= 1


func recruit_reason(id: String) -> String:
	if not config.party.has(id): return "这位人物目前没有同行档案。"
	if state.chapter_two.party.has(id): return "已经在同行队伍中。"
	if int(state.relations.get(id, 0)) < 20: return "先多说几句话吧。同行需要好感达到20。"
	if absi(int(config.party[id].level) - int(state.chapter_two.cultivation.level)) > 2: return "行动等级差超过2，暂时无法同行。"
	if state.chapter_two.party.size() >= 3: return "队伍已满，先请一位同伴回去休息。"
	if not COMPANIONS.has(id): return "对方还有驻守任务，这次只能在任务现场协作。"
	if id == "jiang" and int(state.chapter_two.slot) == 0: return "江北辰上午在档案室勤工，可以下午或夜间再约。"
	if id == "chuxia" and int(state.chapter_two.slot) == 1: return "林初夏下午有社团排班，可以上午或夜间再约。"
	return ""


static func validate(data: Dictionary, relations: Dictionary) -> bool:
	if data.is_empty(): return true
	if data.get("version") != "chapter2-prototype.2" or not STAGES.has(String(data.get("stage", ""))): return false
	if not _integer(data.get("calendar_epoch"),4,15) or not int(data.calendar_epoch) in [4,15]: return false
	if not data.get("cultivation") is Dictionary or not ChapterCultivation.validate(data.cultivation): return false
	for key: String in ["day", "slot", "week", "classes", "training", "club_visits", "social_visits", "retreats"]:
		if not _integer(data.get(key), 0, 100000): return false
	if int(data.day) < int(data.calendar_epoch) or int(data.day) > 365 or int(data.slot) > 2 or int(data.week) != floori((int(data.day)-int(data.calendar_epoch))/7.0): return false
	if String(data.stage) == "interlude" and int(data.day) >= 15: return false
	if String(data.stage) != "interlude" and int(data.day) < 15: return false
	if int(data.cultivation.job_week)>int(data.week): return false
	var active: String = String(data.cultivation.active_event)
	var character_dates: Dictionary = {"street_ice":6,"campus_library":5,"training_spar":10,"training_lunch":12,"dormitory_flyers":9}
	if character_dates.has(active):
		if String(data.stage)!="interlude" or int(data.day)<int(character_dates[active]) or int(data.day)>14: return false
		if active=="training_lunch" and not data.cultivation.seen.has("training_spar"): return false
	for value: Variant in data.cultivation.jobs_done.values():
		if int(value)>int(data.week): return false
	for key: String in ["night_used", "fallen"]:
		if not data.get(key) is bool: return false
	if bool(data.night_used) and int(data.slot) != 2: return false
	for key: String in ["club", "route", "clue_destination", "storm", "grade"]:
		if not data.get(key) is String: return false
	if not String(data.club) in ["", "sword", "element", "healing", "none"]: return false
	if not String(data.route) in ["", "bureau", "mutual"] or not String(data.clue_destination) in ["", "bureau", "bar", "keep"]: return false
	if not String(data.storm) in ["", "shelter", "push"] or not String(data.grade) in ["", "A", "S"]: return false
	for key: String in ["week_stats", "weekly_tasks", "party_vitals", "battle_logs", "reputation"]:
		if not data.get(key) is Dictionary: return false
	for key: String in ["weeks", "party", "cleared"]:
		if not data.get(key) is Array: return false
	for key: String in ["class", "training", "club", "help"]:
		if not _integer(data.week_stats.get(key), 0, 14): return false
	if data.weeks.size() != int(data.week): return false
	for entry: Variant in data.weeks:
		if not entry is Dictionary or not entry.get("stats") is Dictionary or not _integer(entry.get("week"), 1, 52): return false
	for value: Variant in data.weekly_tasks.values():
		if not _integer(value, 0, int(data.week)): return false
	for id: String in ["bureau", "mutual"]:
		if not _integer(data.reputation.get(id), 0, 100): return false
	var seen: Array = []
	for id: Variant in data.party:
		if not id is String or not COMPANIONS.has(id) or seen.has(id): return false
		seen.append(id)
	if seen.size() > 3: return false
	var maxima: Dictionary = {"wen_rang": 250, "jiang": 175, "chuxia": 180}
	for id: String in COMPANIONS:
		var vitals: Variant = data.party_vitals.get(id)
		if not vitals is Dictionary or not _integer(vitals.get("hp"), 0, int(maxima[id])) or not _integer(vitals.get("sl"), 0, 100): return false
	for id: String in ["jiang", "chuxia", "han", "qin"]:
		if not _integer(relations.get(id), 0, 100): return false
	for id: String in ["bai_muyao","su_wantang"]:
		if not _integer(relations.get(id,0),0,20): return false
	seen.clear()
	for id: Variant in data.cleared:
		if not id is String or not id in ["entry", "final"] or seen.has(id): return false
		seen.append(id)
	if data.cleared.has("final") and (not data.cleared.has("entry") or String(data.storm).is_empty()): return false
	var stage: int = STAGES.find(String(data.stage))
	if stage >= STAGES.find("port") and String(data.route).is_empty(): return false
	if stage >= STAGES.find("clue") and not data.cleared.has("final"): return false
	if stage >= STAGES.find("report") and String(data.clue_destination).is_empty(): return false
	if stage == STAGES.find("complete") and String(data.grade).is_empty(): return false
	return true


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum
