class_name ChapterSession
extends RefCounted

const VERSION: String = "chapter1.1"
const PHASES: Array[String] = ["arrival", "mentors", "cafe", "hill", "clubs", "dorm", "hall", "delivery", "complete", "chapter_two", "cultivation"]
const AFFINITIES: Array[String] = ["念动力", "元素", "强化", "精神", "特殊"]
const MENTORS: Array[String] = ["liu", "shen", "wen", "tang"]
var phase: String = "arrival"
var room: String = "gate"
var affinity: String = "念动力"
var mentor: String = ""
var hp: int = 220
var sl: int = 0
var money: int = 3000
var contribution: int = 0
var flags: Dictionary = {}
var relations: Dictionary = {"wen_rang": 80, "ling": 40, "su": 40}
var journal: Array[String] = []
var events: Array[Dictionary] = []
var tutorial_log: Dictionary = {}
var settings: Dictionary = {}
var growth_settings: Dictionary = {}
var chapter_two: Dictionary = {}
var player_position: Vector2 = Vector2.ZERO
var loaded_backup: bool = false


func _init() -> void:
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter1/settings.json")) as Dictionary
	growth_settings = JSON.parse_string(FileAccess.get_file_as_string("res://data/cultivation/settings.json")) as Dictionary
	hp = int(settings.hero.max_hp)
	money = int(settings.get("initial_money", 3000))
	relations = settings.initial_relations.duplicate(true)


func max_hp() -> int:
	return _maximum_hp(mentor, chapter_two)


func _maximum_hp(target_mentor: String, campaign: Dictionary) -> int:
	var extra: int = 0
	if not campaign.is_empty():
		extra = (int(campaign.cultivation.attributes.constitution)-int(growth_settings.base_attributes.constitution))*int(growth_settings.derived.hp_per_constitution)
	return roundi(int(settings.hero.max_hp) * float(settings.mentor.get(target_mentor, {}).get("max_hp_multiplier", 1.0))) + extra


func record(kind: String, details: Dictionary = {}) -> void:
	events.append({"sequence": events.size(), "phase": phase, "kind": kind, "details": details.duplicate(true)})


func mark(flag: String, text: String = "") -> bool:
	if bool(flags.get(flag, false)):
		return false
	flags[flag] = true
	if not text.is_empty():
		journal.append(text)
	record("flag", {"id": flag})
	return true


func date_text() -> String:
	if phase in ["chapter_two", "cultivation"]: return ChapterTwoCalendar.format_date(chapter_two)
	if phase in ["arrival", "mentors", "cafe"]:
		return "觉醒历22年 · 01-01 · 入学日"
	if phase in ["hill", "clubs", "dorm"]:
		return "觉醒历22年 · 01-02 · 校园新生活"
	return "觉醒历22年 · 01-03 · 任务大厅开放"


func snapshot() -> Dictionary:
	return {"version": VERSION, "phase": phase, "room": room, "affinity": affinity,
		"player_position": [player_position.x, player_position.y],
		"mentor": mentor, "hp": hp, "sl": sl, "money": money, "contribution": contribution,
		"flags": flags.duplicate(true), "relations": relations.duplicate(true),
		"journal": journal.duplicate(), "events": events.duplicate(true), "tutorial_log": tutorial_log.duplicate(true),
		"chapter_two": chapter_two.duplicate(true)}


func restore(data: Dictionary) -> bool:
	for key: String in ["version", "phase", "room", "affinity", "mentor"]:
		if not data.get(key) is String: return false
	if String(data.get("version", "")) != VERSION or not PHASES.has(String(data.get("phase", ""))):
		return false
	if not AFFINITIES.has(String(data.get("affinity", ""))) or (not String(data.get("mentor", "")).is_empty() and not MENTORS.has(String(data.mentor))):
		return false
	for key: String in ["flags", "relations", "tutorial_log"]:
		if not data.get(key) is Dictionary:
			return false
	for key: String in ["journal", "events"]:
		if not data.get(key) is Array:
			return false
	var parsed_maps: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter1/maps.json"))
	var second_maps: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter2/maps.json"))
	if parsed_maps is Dictionary and second_maps is Dictionary: parsed_maps.merge(second_maps)
	if not parsed_maps is Dictionary or not parsed_maps.has(String(data.room)): return false
	var room_definition: Dictionary = parsed_maps[String(data.room)] as Dictionary
	for key: String in ["hp", "sl", "money", "contribution"]:
		if not typeof(data.get(key)) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data[key])): return false
		if float(data[key]) != floor(float(data[key])) or float(data[key]) < 0.0: return false
	for key: String in ["wen_rang", "ling", "su"]:
		var number: Variant = data.relations.get(key)
		if not typeof(number) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)): return false
		if float(number) < 0.0 or float(number) > 100.0: return false
	for key: Variant in data.flags:
		if not key is String: return false
		if key == "shen_answers":
			if not data.flags[key] is Array or data.flags[key].size() > 3: return false
			for answer: Variant in data.flags[key]:
				if not typeof(answer) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(answer)): return false
				if float(answer) != floor(float(answer)) or not int(answer) in [0, 1, 2]: return false
		elif not data.flags[key] is bool: return false
	var requirements: Array = [["mentors", "tested"], ["cafe", "apprenticed"], ["hill", "hill_accepted"], ["clubs", "hill_done"], ["dorm", "clubs_seen"], ["hall", "slept"], ["delivery", "task_accepted"], ["complete", "task_rewarded"]]
	for required: Array in requirements:
		if PHASES.find(String(data.phase)) >= PHASES.find(String(required[0])) and not data.flags.get(required[1], false): return false
	if PHASES.find(String(data.phase)) >= 2 and String(data.mentor).is_empty(): return false
	if String(data.phase) in ["complete", "chapter_two", "cultivation"] and not data.flags.get("delivered", false): return false
	var second: Variant = data.get("chapter_two", {})
	if not second is Dictionary: return false
	second = ChapterTwoCalendar.normalize(second)
	if not ChapterTwoCalendar.validate(second, data.relations): return false
	if String(data.phase) == "chapter_two":
		if second.is_empty() or String(second.stage) == "interlude": return false
		var stage: int = ChapterTwoCalendar.STAGES.find(String(second.stage))
		if stage >= ChapterTwoCalendar.STAGES.find("campus") and not data.flags.get("c2_rescreen_done", false): return false
		if stage >= ChapterTwoCalendar.STAGES.find("port") and not data.flags.get("c2_task_accepted", false): return false
		if stage >= ChapterTwoCalendar.STAGES.find("report") and not data.flags.get("c2_photo", false): return false
		if stage == ChapterTwoCalendar.STAGES.find("complete") and not data.flags.get("c2_rewarded", false): return false
	elif String(data.phase) == "cultivation":
		if second.is_empty() or String(second.stage) != "interlude" or data.flags.get("c2_notice_seen",false): return false
	elif not second.is_empty(): return false
	for item: Variant in data.journal:
		if not item is String: return false
	for item: Variant in data.events:
		if not item is Dictionary: return false
	var point: Variant = data.get("player_position", [0.0, 0.0])
	if not point is Array or point.size() != 2: return false
	for coordinate: Variant in point:
		if not typeof(coordinate) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(coordinate)) or float(coordinate) < 0.0: return false
	if float(point[0]) > float(room_definition.width) * 48.0 or float(point[1]) > float(room_definition.height) * 48.0: return false
	var target_mentor: String = String(data.get("mentor", ""))
	var upper: int = _maximum_hp(target_mentor, second)
	if int(data.get("hp", -1)) < 1 or int(data.hp) > upper or int(data.get("sl", -1)) < 0 or int(data.sl) > 100:
		return false
	phase = String(data.phase)
	room = String(data.get("room", "auditorium"))
	affinity = String(data.affinity)
	mentor = target_mentor
	hp = int(data.hp)
	sl = int(data.sl)
	money = maxi(0, int(data.get("money", 3000)))
	contribution = maxi(0, int(data.get("contribution", 0)))
	player_position = Vector2(float(point[0]), float(point[1]))
	flags = data.flags.duplicate(true)
	relations = data.relations.duplicate(true)
	if not second.is_empty():
		for id: String in ["bai_muyao","su_wantang"]:
			if not relations.has(id): relations[id]=0
	journal.clear()
	for item: Variant in data.journal:
		journal.append(String(item))
	events.clear()
	for item: Variant in data.events:
		if item is Dictionary:
			events.append(item.duplicate(true))
	tutorial_log = data.tutorial_log.duplicate(true)
	chapter_two = second.duplicate(true)
	return true


func save_to(path: String = "user://saves/chapter1.json") -> Error:
	var absolute: String = ProjectSettings.globalize_path(path)
	var error: Error = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK:
		return error
	var temporary: String = absolute + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(snapshot(), "\t"))
	file.close()
	if FileAccess.file_exists(absolute):
		var prior: Variant = _read_snapshot(absolute)
		var validator: ChapterSession = ChapterSession.new()
		if prior is Dictionary and validator.restore(prior):
			error = DirAccess.copy_absolute(absolute, absolute + ".bak")
			if error != OK: return error
	return DirAccess.rename_absolute(temporary, absolute)


func _read_snapshot(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: return null
	var parser: JSON = JSON.new()
	var error: Error = parser.parse(file.get_as_text())
	file.close()
	return parser.data if error == OK else null


func load_from(path: String = "user://saves/chapter1.json") -> bool:
	loaded_backup = false
	for candidate: String in [path, path + ".bak"]:
		var parsed: Variant = _read_snapshot(candidate)
		if parsed is Dictionary and restore(parsed):
			loaded_backup = candidate != path
			return true
	return false
