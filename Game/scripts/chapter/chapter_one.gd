class_name ChapterOne
extends Control

const BATTLE_SCENE: PackedScene = preload("res://scenes/chapter/chapter_tutorial.tscn")
const DISPLAY_SCRIPT: Script = preload("res://scripts/chapter/chapter_display.gd")
const CINEMATICS_SCRIPT: Script = preload("res://scripts/chapter/chapter_cinematics.gd")
const RIFT_SCENE: PackedScene = preload("res://scenes/chapter/chapter_rift_battle.tscn")
const PORTRAITS: Dictionary = {"林大": -1, "温让": 0, "苏挽颜": 1, "柳无眠": 2, "沈听澜": 3, "温若水": 4, "唐半夏": 5, "凌未央": 6, "林初夏": 7, "考官": 8, "任务管理员": 8, "管理局职员": 8}
var state: ChapterSession
var story: ChapterStory
var maps: Dictionary = {}
var dialogues: Dictionary = {}
var mode: String = "title"
var battle: ChapterTutorial
var rift_battle: ChapterRiftBattle
var display: ChapterDisplay
var cinematics: ChapterCinematics
var save_path: String = "user://saves/chapter1.json"
var _lines: Array[Dictionary] = []
var _line_index: int = 0
var _choices: Array = []
var _generation: int = 0
var _menu_origin: String = "world"
var _return_to_cultivation: bool = false
var _after_dialogue: Dictionary = {}
var _refresh_after_dialogue: bool = false
@onready var world: ChapterMap = $WorldContainer/WorldViewport/Map
@onready var hud: ChapterHUD = $UI/LogicalUI


func _ready() -> void:
	get_window().title = "觉醒者档案：新海风云 · 入学与复筛"
	maps = _read_data("maps")
	dialogues = _read_data("dialogues")
	maps.merge(_read_second_data("maps"))
	dialogues.merge(_read_second_data("dialogues"))
	var encounters: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cultivation/dialogues.json"))
	if encounters is Dictionary: dialogues.merge(encounters)
	state = ChapterSession.new()
	story = ChapterStory.new(state)
	world.load_room(maps.auditorium)
	hud.new_game_requested.connect(start_new_game)
	hud.continue_requested.connect(load_game)
	hud.advance_requested.connect(advance_dialogue)
	hud.choice_requested.connect(select_choice)
	hud.travel_requested.connect(travel)
	hud.map_requested.connect(open_map)
	hud.journal_requested.connect(open_journal)
	hud.pause_requested.connect(open_pause)
	hud.save_requested.connect(save_game)
	hud.load_requested.connect(load_game)
	hud.title_requested.connect(return_to_title)
	hud.close_requested.connect(close_menu)
	hud.next_chapter_requested.connect(begin_chapter_two)
	hud.cultivation_requested.connect(open_cultivation)
	hud.cultivation_action_requested.connect(perform_cultivation)
	hud.first_completion_requested.connect(func() -> void: load_game(true))
	hud.show_title(save_path)
	display = DISPLAY_SCRIPT.new() as ChapterDisplay
	display.name = "AdaptiveDisplay"
	add_child(display)
	cinematics = CINEMATICS_SCRIPT.new() as ChapterCinematics
	cinematics.name = "ChapterCinematics"
	add_child(cinematics)
	cinematics.configure(self, world, hud, display)
	print("[Chapter1] Ready | generated art | adaptive window | world reference=960x540 | UI reference=1920x1080")


func _read_data(name_value: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter1/%s.json" % name_value))
	return parsed as Dictionary if parsed is Dictionary else {}


func _read_second_data(name_value: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter2/%s.json" % name_value))
	return parsed as Dictionary if parsed is Dictionary else {}


func begin_chapter_two() -> void:
	if mode != "complete": return
	if state.phase == "chapter_two":
		state.mark("c2_ending_seen")
		_settle()
		return
	if state.phase != "complete": return
	# Keep the completed first chapter when the shared campaign slot advances.
	var archive_error: Error = state.save_to(save_path.get_basename()+"-chapter1-cleared.json")
	if archive_error != OK:
		hud.toast("首章归档失败：" + error_string(archive_error))
		return
	_cancel_visit()
	_generation += 1
	ChapterTwoCalendar.new(state).begin()
	story = ChapterTwoStory.new(state)
	_load_room()
	hud.show_world()
	_auto_save()
	mode = "world"
	present({"cinematic":"c2_sleep","dialogue":"c2_grow_intro","open_cultivation":true})


func start_new_game(affinity: String = "念动力") -> void:
	if not ChapterSession.AFFINITIES.has(affinity) or battle != null or rift_battle != null: return
	_cancel_visit()
	_generation += 1
	_lines.clear()
	_choices.clear()
	_after_dialogue.clear()
	_refresh_after_dialogue = false
	_return_to_cultivation = false
	_line_index = 0
	hud.advance_button.disabled = false
	state = ChapterSession.new()
	state.affinity = affinity
	story = ChapterStory.new(state)
	_load_room()
	hud.show_world()
	_auto_save()
	_begin_arrival()


func _play_scene(id: String, done: Callable) -> void:
	mode = "cinematic"
	world.player.blocked = true
	world.dialogue_framing = false
	cinematics.play(id, done)


func _begin_arrival() -> void:
	_play_scene("gate_arrival", func() -> void:
		state.mark("gate_arrival_seen")
		present({"dialogue": "arrival"}))


func interact(id: String = "") -> void:
	if mode != "world": return
	var target: String = id
	if target.is_empty(): target = String(world.closest_interaction().get("id", ""))
	if target.is_empty(): return
	if target.begins_with("growth_partner_"): target="growth_event"
	if target == "hill_wen":
		present({"dialogue": "hill_wen"})
	else:
		present(story.perform(target))


func present(response: Dictionary) -> void:
	_return_to_cultivation = bool(response.get("open_cultivation",false))
	hud.cultivation_panel.hide()
	if response.has("cinematic"):
		var continuation: Dictionary = response.duplicate(true)
		continuation.erase("cinematic")
		if state.room != String(world.definition.get("roomId",state.room)):
			_load_room()
		_play_scene(String(response.cinematic), func() -> void:
			if String(response.cinematic).begins_with("c2_hunter_"): state.mark("c2_hunter_seen")
			if String(response.cinematic).begins_with("event_") and state.phase in ["cultivation","chapter_two"] and not String(state.chapter_two.cultivation.active_event).is_empty():
				_auto_save()
			present(continuation))
		return
	if response.get("battle", false):
		if state.phase == "chapter_two": _start_rift_battle(String(response.get("encounter","")))
		else: start_battle()
		return
	if state.room != String(world.definition.get("roomId",state.room)): _load_room()
	if String(response.get("dialogue", "")).begins_with("joined_") and state.room != "plaza":
		state.room = "plaza"
		_load_room()
		for entry: Dictionary in world.interactions:
			if String(entry.id) == state.mentor:
				world.player.position = Vector2(float(entry.position[0]), float(entry.position[1]) + 58.0)
				break
	_lines.clear()
	_line_index = 0
	_after_dialogue = {"cinematic":response.after_dialogue_cinematic,"response":response.get("after_dialogue_response",{})} if response.has("after_dialogue_cinematic") else {}
	_choices = response.get("choices", [])
	var remark_after_dialogue: bool = bool(response.get("remark_after_dialogue", false))
	if response.has("remark") and not remark_after_dialogue:
		_lines.append({"speaker": String(response.get("remark_speaker","沈听澜")), "text": String(response.remark)})
	for key: String in ["dialogue", "extra"]:
		var id: String = String(response.get(key, ""))
		for line: Dictionary in dialogues.get(id, []): _lines.append(line.duplicate(true))
	if response.has("remark") and remark_after_dialogue:
		_lines.append({"speaker": String(response.get("remark_speaker","沈听澜")), "text": String(response.remark)})
	if String(response.get("dialogue", "")) == "hill_return" and state.hp < state.max_hp() * 0.3:
		world.player.resting = true
		for index: int in range(_lines.size() - 1, 0, -1):
			if _lines[index].speaker == "林大": _lines.remove_at(index)
	elif String(response.get("dialogue", "")) == "hill_abort":
		world.player.resting = true
	hud.menu_layer.hide()
	hud.choice_layer.hide()
	if _lines.is_empty():
		if not _choices.is_empty():
			mode = "choice"
			world.dialogue_framing = true
			world.player.blocked = true
			hud.dialog_panel.hide()
			hud.show_choices(_choices)
		else:
			_settle()
		return
	mode = "dialogue"
	world.dialogue_framing = true
	world.player.blocked = true
	_show_line()


func _show_line() -> void:
	var line: Dictionary = _lines[_line_index].duplicate(true)
	if line.get("event", "") == "afternoon_transition":
		_lines[_line_index].erase("event")
		if not state.flags.get("mentor_ceremony_seen", false):
			_play_scene("test_to_assembly", func() -> void:
				state.mark("mentor_ceremony_seen")
				var entrance: Array = dialogues.get("mentor_entrance", [])
				for index: int in range(entrance.size()-1, -1, -1):
					_lines.insert(_line_index, entrance[index].duplicate(true))
				mode = "dialogue"
				world.dialogue_framing = true
				_show_line())
			return
	line["text"] = String(line.get("text", "")).format({"delivery_money": int(state.settings.delivery_reward.money), "delivery_contribution": int(state.settings.delivery_reward.contribution)})
	var speaker: String = String(line.get("speaker", ""))
	if state.room == "assembly_stage":
		world.cinematic_camera = true
		world.cinematic_focus = Vector2(720, 590 if speaker in ["温让", "林大"] else 410)
	var portrait_texture: Texture2D
	var new_portraits: Dictionary = {"任务管理员":"res://assets/venues/academy_people/frames/frame_000.png", "管理局职员":"res://assets/venues/bureau_people/frames/frame_000.png", "江北辰":"res://assets/chapter2/actors/jiang/frames/frame_000.png", "韩烛":"res://assets/chapter2/actors/han/frames/frame_000.png", "秦妖妖":"res://assets/chapter2/actors/qin/frames/frame_000.png", "林初夏":"res://assets/encounters/actors/chuxia/frames/frame_000.png", "白沐瑶":"res://assets/encounters/actors/bai_muyao/frames/frame_000.png", "苏晚棠":"res://assets/encounters/actors/su_wantang/frames/frame_000.png", "苏父":"res://assets/encounters/encounter_people/frames/frame_000.png", "图书管理员":"res://assets/encounters/encounter_people/frames/frame_001.png", "剑道社学长":"res://assets/encounters/encounter_people/frames/frame_002.png", "元素研究社学姐":"res://assets/encounters/encounter_people/frames/frame_003.png", "治愈社学姐":"res://assets/venues/academy_people/frames/frame_002.png"}
	if new_portraits.has(speaker): portrait_texture = load(String(new_portraits[speaker])) as Texture2D
	elif PORTRAITS.has(speaker):
		var index: int = int(PORTRAITS[speaker])
		portrait_texture = load("res://assets/chapter1/refined/lin_da/frames/frame_000.png" if index < 0 else "res://assets/chapter1/refined/npcs/frames/frame_%03d.png" % index) as Texture2D
	hud.refresh(state, story, world.closest_interaction())
	hud.show_line(line, portrait_texture)
	if line.get("event", "") == "reading_delay":
		world.present_test_release(state.affinity)
		hud.advance_button.disabled = true
		_unlock_reading(_generation)


func _unlock_reading(generation: int) -> void:
	await get_tree().create_timer(0.5).timeout
	if generation != _generation or mode != "dialogue": return
	hud.advance_button.disabled = false
	advance_dialogue()


func advance_dialogue() -> void:
	if mode != "dialogue" or hud.advance_button.disabled: return
	if _line_index>=_lines.size():
		_settle()
		return
	if _lines[_line_index].get("after_event", "") == "hill_route_received":
		state.mark("hill_route_received", "学生证已收到后山入口位置。")
	_line_index += 1
	if _line_index < _lines.size():
		_show_line()
	elif not _choices.is_empty():
		mode = "choice"
		hud.show_choices(_choices)
	else:
		_settle()


func select_choice(index: int) -> void:
	if mode != "choice" or index < 0 or index >= _choices.size(): return
	var choice: Dictionary = _choices[index]
	var response: Dictionary = story.perform(String(choice.action), String(choice.get("value", "")))
	if String(choice.action)=="growth_event_choice": _refresh_after_dialogue=true
	present(response)


func _settle() -> void:
	if not _after_dialogue.is_empty():
		var pending: Dictionary = _after_dialogue.duplicate(true)
		_after_dialogue.clear()
		_play_scene(String(pending.cinematic),func() -> void: present(pending.response))
		return
	world.dialogue_framing = false
	world.cinematic_camera = false
	if state.phase in ["chapter_two","cultivation"]:
		_settle_second()
		return
	if state.phase == "arrival" and state.room == "gate":
		if not state.flags.get("gate_arrival_seen", false):
			_begin_arrival()
		else:
			_play_scene("enter_auditorium", func() -> void:
				state.mark("gate_entered")
				_settle())
		return
	if state.phase == "mentors" and state.room == "assembly_stage":
		_play_scene("assembly_to_exhibits", _settle)
		return
	if state.phase=="clubs" and state.room=="hill" and not state.flags.get("clubs_arrived",false):
		_play_scene("hill_to_clubs",func() -> void:
			state.mark("clubs_arrived")
			present({"dialogue":"clubs_arrive"}))
		return
	var rooms: Array[String] = story.locations()
	if not rooms.has(state.room): state.room = rooms[0]
	if String(world.definition.get("name", "")) != String(maps[state.room].name):
		_load_room()
	hud.show_world()
	mode = "complete" if state.phase == "complete" else "world"
	world.player.blocked = mode != "world"
	hud.refresh(state, story, world.closest_interaction())
	_auto_save()
	if state.phase == "cafe":
		_begin_su_visit()
		return
	if mode == "complete": hud.show_ending(state)


func _settle_second() -> void:
	if _refresh_after_dialogue:
		_refresh_after_dialogue=false
		_refresh_cultivation_room()
	var rooms: Array[String] = story.locations()
	if not rooms.has(state.room): state.room = rooms[0]
	if String(world.definition.get("roomId","")) != state.room: _load_room()
	hud.show_world()
	mode = "complete" if String(state.chapter_two.stage)=="complete" and not state.flags.get("c2_ending_seen",false) else "world"
	world.player.blocked = mode != "world"
	hud.refresh(state,story,world.closest_interaction())
	_auto_save()
	if String(state.chapter_two.stage)=="rescreen" and not state.flags.get("c2_notice_seen",false):
		_return_to_cultivation = false
		_play_scene("c2_notice",func() -> void: present(story.perform("c2_notice")))
	elif String(state.chapter_two.stage)=="clue" and not state.flags.get("c2_hunter_seen",false):
		state.room="c2_rift"
		_load_room()
		present({"cinematic":"c2_hunter_"+String(state.chapter_two.route),"dialogue":"c2_final_victory_"+String(state.chapter_two.route)})
	elif (story as ChapterTwoStory).growth.available() and not String(state.chapter_two.cultivation.active_event).is_empty():
		_return_to_cultivation = false
		_resume_encounter()
	elif mode == "complete": hud.show_second_ending(state)
	elif _return_to_cultivation and (story as ChapterTwoStory).growth.available():
		_return_to_cultivation = false
		open_cultivation()


func _begin_su_visit() -> void:
	if world.actor_for("wen_rang") == null:
		world.add_visitor("WenRangCompanion", 0, world.player.position + Vector2(-54, 8))
	var visitor: Sprite2D = world.add_visitor("SuWanyanVisitor", 1, Vector2(1360, 830))
	visitor.hide()
	_play_scene("su_arrival", func() -> void: present(story.perform("su_cafe")))


func _cancel_visit() -> void:
	if cinematics != null: cinematics.cancel()


func _load_room() -> void:
	var data: Dictionary = maps[state.room].duplicate(true)
	data["roomId"] = state.room
	if state.phase in ["chapter_two","cultivation"]:
		var entries: Array = data.get("actors",[])
		for index: int in range(entries.size()-1,-1,-1):
			var actor: Dictionary = entries[index]
			if actor.has("route") and String(actor.route) != String(state.chapter_two.route): entries.remove_at(index)
			elif actor.has("encounter") and state.chapter_two.cleared.has(String(actor.encounter)): entries.remove_at(index)
			elif actor.get("after_final",false) and not state.chapter_two.cleared.has("final"): entries.remove_at(index)
			elif actor.get("after_final",false) and actor.has("character") and state.flags.get("c2_hunter_seen",false):
				actor.hidden=false
				actor.position=[1080,550]
			elif String(actor.get("id","")) in ["hill","su_cafe"] or (state.phase=="cultivation" and String(actor.get("id",""))=="c2_jiang"):
				entries.remove_at(index)
			elif String(actor.get("id","")) in ["hill_wen","wen_rang"]: actor.id="c2_wen"
			elif state.phase=="cultivation" and String(actor.get("id",""))=="c2_notice": actor.name="新生日程 · 1月15日复筛"
		var growth: ChapterCultivation = (story as ChapterTwoStory).growth
		var event: Dictionary = growth.event_definition()
		if not event.is_empty() and state.room==growth.event_room(event):
			var encounter: Dictionary = {"id":"growth_event","nodeName":"GrowthEncounter","name":String(event.name),"asset":String(event.asset),"position":event.position.duplicate(),"size":[48,48],"renderLayer":"actors","occlusionClass":"low"}
			for key: String in ["character","characterFolder","face"]:
				if event.has(key): encounter[key]=event[key]
			entries.append(encounter)
			for partner: Dictionary in event.get("partners",[]): entries.append(partner.duplicate(true))
			for prop: Dictionary in event.get("props",[]): data.props.append(prop.duplicate(true))
			var remove: Array = event.get("remove_actors",[])
			for index: int in range(entries.size()-1,-1,-1):
				if remove.has(String(entries[index].id)): entries.remove_at(index)
	if state.phase=="dorm" and state.room=="corridor":
		for actor: Dictionary in data.actors:
			if String(actor.id)=="chuxia" and state.flags.get("chuxia_seen",false): actor.position=[950,600]
	elif state.phase in ["chapter_two","cultivation"] and state.room=="corridor":
		var event: Dictionary = (story as ChapterTwoStory).growth.event_definition()
		for index: int in range(data.actors.size()-1,-1,-1):
			if String(data.actors[index].id)=="chuxia":
				if not event.is_empty() and String(event.id)=="dormitory_flyers": data.actors.remove_at(index)
				else:
					data.actors[index].id="c2_chuxia"
					data.actors[index].name="林初夏 · 楼道 / 同行与夜谈"
	if state.room == "hill" and not state.flags.get("invite_wen", false):
		var actors: Array = data.actors
		for index: int in range(actors.size() - 1, -1, -1):
			if actors[index].id == "hill_wen": actors.remove_at(index)
	world.load_room(data)
	if state.phase in ["arrival", "mentors", "cafe"] and world.actor_for("wen_rang") == null:
		var point: Vector2 = world.player.position
		for offset: Vector2 in [Vector2(-54,8), Vector2(-48,48), Vector2(48,48), Vector2(0,54)]:
			if world.can_stand(world.player.position+offset):
				point = world.player.position+offset
				break
		world.add_visitor("WenRangCompanion", 0, point)
	world.reset_follow()


func _refresh_cultivation_room() -> void:
	var point: Vector2 = world.player.position
	_load_room()
	if world.can_stand(point): world.player.position=point


func _resume_encounter() -> void:
	var growth: ChapterCultivation = (story as ChapterTwoStory).growth
	var event: Dictionary = growth.event_definition()
	if event.is_empty(): return
	if state.room != growth.event_room(event):
		state.room = growth.event_room(event)
		state.player_position = Vector2.ZERO
		_load_room()
	var started: bool = bool(growth.data().event_started)
	var response: Dictionary = growth.perform("growth_event")
	if started:
		cinematics.restore_endpoint(growth.event_entrance(event))
		response.erase("dialogue")
	present(response)


func travel(room: String) -> void:
	if not mode in ["world", "menu"] or not story.travel(room): return
	if state.phase == "chapter_two" and room == "c2_port" and String(state.chapter_two.stage) in ["rift","clue"]:
		state.chapter_two.retreats = int(state.chapter_two.retreats)+1
	state.player_position = Vector2.ZERO
	_load_room()
	_settle()


func open_map() -> void:
	if mode != "world": return
	_menu_origin = mode
	mode = "menu"
	world.player.blocked = true
	hud.show_map(story)
	hud.cultivation_button.hide()


func open_cultivation() -> void:
	if mode=="menu" and hud.cultivation_panel.visible:
		close_menu()
		return
	if mode!="world" or not state.phase in ["cultivation","chapter_two"]: return
	if not (story as ChapterTwoStory).growth.available():
		hud.toast("先完成当前复筛或裂隙任务。")
		return
	_menu_origin="world"
	mode="menu"
	world.player.blocked=true
	hud.cultivation_button.hide()
	hud.cultivation_panel.show_session(state,story as ChapterTwoStory)


func perform_cultivation(action: String, value: String) -> void:
	if mode!="menu" or not hud.cultivation_panel.visible: return
	var response: Dictionary = story.perform(action,value)
	if action == "growth_roam" and response.has("choices"):
		_load_room()
	if action=="growth_event_choice": _refresh_after_dialogue=true
	if not action=="growth_roam": response["open_cultivation"]=true
	present(response)


func open_journal() -> void:
	if not mode in ["world", "complete"]: return
	_menu_origin = mode
	if mode == "complete": hud.ending_layer.hide()
	mode = "menu"
	world.player.blocked = true
	hud.show_journal(state)


func open_pause() -> void:
	if mode == "menu":
		close_menu()
		return
	if mode != "world": return
	_menu_origin = mode
	mode = "menu"
	world.player.blocked = true
	hud.show_pause()


func close_menu() -> void:
	if mode != "menu": return
	hud.menu_layer.hide()
	hud.cultivation_panel.hide()
	mode = _menu_origin
	world.player.blocked = mode != "world"
	if mode == "complete": hud.ending_layer.show()


func _auto_save() -> void:
	state.player_position = world.player.position.round()
	var error: Error = state.save_to(save_path)
	if error != OK: hud.toast("存档失败：" + error_string(error))


func save_game() -> void:
	if not mode in ["world", "menu", "complete"]: return
	state.player_position = world.player.position.round()
	var error: Error = state.save_to(save_path)
	hud.toast("学生证记录已保存" if error == OK else "存档失败：" + error_string(error))


func load_game(from_first_completion: bool = false) -> void:
	if not mode in ["title", "world", "menu", "complete"]: return
	var loaded: ChapterSession = ChapterSession.new()
	var source_path: String = save_path.get_basename()+"-chapter1-cleared.json" if from_first_completion else save_path
	if not loaded.load_from(source_path) or not maps.has(loaded.room) or (from_first_completion and loaded.phase!="complete"):
		hud.toast("存档无法读取，当前进度保留")
		return
	if from_first_completion:
		var prior: ChapterSession = ChapterSession.new()
		if prior.load_from(save_path) and prior.phase in ["cultivation","chapter_two"]:
			var archive_error: Error = prior.save_to(save_path.get_basename()+"-before-cultivation-replay.json")
			if archive_error!=OK:
				hud.toast("当前进度归档失败："+error_string(archive_error))
				return
	_generation += 1
	state = loaded
	_after_dialogue.clear()
	_refresh_after_dialogue=false
	_return_to_cultivation=false
	_cancel_visit()
	if state.phase == "cafe" and state.room == "cafe":
		state.room = "plaza"
		state.player_position = Vector2.ZERO
	story = ChapterTwoStory.new(state) if state.phase in ["chapter_two","cultivation"] else ChapterStory.new(state)
	_load_room()
	var relocated: bool = state.player_position != Vector2.ZERO and not world.can_stand(state.player_position)
	if state.player_position != Vector2.ZERO and not relocated: world.player.position = state.player_position
	_settle()
	hud.toast("主存档损坏，已恢复上一次备份" if state.loaded_backup else "已读取章节记录，已调整到安全入口" if relocated else "已读取章节记录")


func return_to_title() -> void:
	if battle != null or rift_battle != null: return
	_generation += 1
	_cancel_visit()
	_lines.clear()
	_choices.clear()
	_return_to_cultivation=false
	_after_dialogue.clear()
	_refresh_after_dialogue=false
	mode = "title"
	world.dialogue_framing = false
	world.player.blocked = true
	hud.show_title(save_path)


func start_battle() -> void:
	if battle != null or state.phase != "hill": return
	_generation += 1
	_auto_save()
	mode = "battle"
	world.player.blocked = true
	$WorldContainer.hide()
	$UI.hide()
	battle = BATTLE_SCENE.instantiate() as ChapterTutorial
	battle.chapter_state = state
	battle.chapter_finished.connect(_battle_finished)
	battle.chapter_aborted.connect(_battle_aborted)
	add_child(battle)


func _remove_battle() -> void:
	if battle != null:
		battle.queue_free()
		battle = null
	$WorldContainer.show()
	$UI.show()
	mode = "world"


func _battle_finished(hp_value: int, sl_value: int, log_data: Dictionary) -> void:
	if not story.finish_battle(hp_value, sl_value, log_data): return
	_remove_battle()
	present({"dialogue": "hill_return"})


func _battle_aborted() -> void:
	_remove_battle()
	present({"dialogue": "hill_abort"})


func _start_rift_battle(encounter: String) -> void:
	if rift_battle != null or battle != null or state.phase != "chapter_two" or not (story as ChapterTwoStory).config.encounters.has(encounter): return
	_generation += 1
	_auto_save()
	mode = "battle"
	world.player.blocked = true
	$WorldContainer.hide()
	$UI.hide()
	rift_battle = RIFT_SCENE.instantiate() as ChapterRiftBattle
	rift_battle.chapter_state = state
	rift_battle.encounter_id = encounter
	rift_battle.rift_finished.connect(_rift_finished)
	rift_battle.rift_aborted.connect(_rift_aborted)
	add_child(rift_battle)


func _remove_rift() -> void:
	if rift_battle != null: rift_battle.queue_free(); rift_battle = null
	$WorldContainer.show()
	$UI.show()
	mode = "world"


func _rift_finished(encounter: String, vitals: Dictionary, log_data: Dictionary) -> void:
	if not (story as ChapterTwoStory).finish_rift_battle(encounter,vitals,log_data): return
	_remove_rift()
	var point: Vector2 = world.player.position
	_load_room()
	if world.can_stand(point): world.player.position = point
	if encounter == "final":
		present({"cinematic":"c2_hunter_" + String(state.chapter_two.route), "dialogue":"c2_final_victory_" + String(state.chapter_two.route)})
	else: present({"dialogue":"c2_entry_victory"})


func _rift_aborted() -> void:
	_remove_rift()
	present({"dialogue":"c2_battle_abort"})


func _process(_delta: float) -> void:
	hud.nameplate_layer.visible = mode == "world"
	if mode == "world":
		hud.refresh(state, story, world.closest_interaction())
		hud.update_nameplates(world)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or mode == "battle": return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_F11:
		get_window().mode = Window.MODE_WINDOWED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
	elif mode == "cinematic" and key == KEY_ESCAPE:
		cinematics.skip()
	elif mode == "dialogue" and key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
		advance_dialogue()
	elif mode == "choice" and key >= KEY_1 and key <= KEY_4:
		select_choice(key - KEY_1)
	elif mode in ["world", "menu", "complete"]:
		match key:
			KEY_E, KEY_SPACE:
				interact()
			KEY_M:
				open_map()
			KEY_J:
				open_journal()
			KEY_C:
				open_cultivation()
			KEY_ESCAPE:
				open_pause()
			KEY_F5:
				save_game()
			KEY_F9:
				load_game()
			_:
				return
	else:
		return
	get_viewport().set_input_as_handled()
