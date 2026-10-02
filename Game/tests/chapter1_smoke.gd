extends SceneTree

const CHAPTER: PackedScene = preload("res://scenes/chapter/chapter_one.tscn")
const TUTORIAL: PackedScene = preload("res://scenes/chapter/chapter_tutorial.tscn")
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var runs: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func expect(condition: bool, message: String) -> void:
	checks.append({"passed": condition, "message": message})
	if not condition: failures.append(message); push_error(message)


func qualify(story: ChapterStory, mentor: String) -> void:
	story.perform(mentor)
	match mentor:
		"liu": story.perform("comic"); story.perform("liu")
		"shen":
			for index: int in range(3): story.perform("shen_answer", str(index))
		"wen":
			for element: String in ["fire", "water", "earth"]: story.perform("sample_" + element)
			story.perform("wen")
		"tang": story.perform("sort", "correct"); story.perform("firstaid", "1")


func command(sandbox: ChapterTutorial) -> void:
	var controller: BattleController = sandbox.controller
	var actor: CombatantState = controller.current_actor()
	var targets: Array[CombatantState] = controller.living_team(false)
	var target: CombatantState = targets[0]
	for candidate: CombatantState in targets:
		var advantage: float = BattleCalculator.attack_preview(actor, candidate, controller.encounter).modifiers.affinity
		var current: float = BattleCalculator.attack_preview(actor, target, controller.encounter).modifiers.affinity
		if advantage > current or (advantage == current and candidate.hp < target.hp): target = candidate
	if sandbox.hud.selected_target != target.id:
		sandbox.hud.selected_target = target.id
		sandbox.hud.target_selected.emit(target.id)
	if sandbox.lesson_index > 0 and controller.can_breakthrough(actor) and actor.hp < actor.max_hp() * 0.8 and actor.weak_actions == 0:
		sandbox._on_command_requested(&"breakthrough", &"")
	elif (sandbox.lesson_index == 2 and not sandbox.observed_goals().has("defend")) or (targets.size() == 1 and actor.hp < actor.max_hp() * 0.6) or actor.sl >= 70 or actor.weak_actions > 0:
		sandbox._on_command_requested(&"defend", &"")
	elif sandbox.lesson_index > 0 and targets.size() > 1 and actor.cooldown_for(&"sweep") == 0:
		sandbox._on_skill_requested(&"sweep", target.id)
	elif sandbox.lesson_index > 0 and actor.cooldown_for(&"strike") == 0:
		sandbox._on_skill_requested(&"strike", target.id)
	else:
		sandbox._on_command_requested(&"attack", target.id)


func finish_lesson(sandbox: ChapterTutorial) -> bool:
	for step: int in range(900):
		if sandbox.flow != &"battle": return sandbox.flow == &"between" or sandbox.flow == &"complete"
		match sandbox.controller.phase:
			BattleController.Phase.PLAYER_COMMAND: command(sandbox)
			BattleController.Phase.PRESENTING: sandbox._on_presentation_timeout()
			BattleController.Phase.ENEMY_COMMAND, BattleController.Phase.AUTO_COMMAND: sandbox._on_enemy_timeout()
	return false


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.dev"))
	_check_guards()
	for affinity: String in ChapterSession.AFFINITIES:
		for mentor: String in ChapterSession.MENTORS:
			var state: ChapterSession = ChapterSession.new()
			state.affinity = affinity
			var story: ChapterStory = ChapterStory.new(state)
			story.perform("exam")
			qualify(story, mentor)
			story.perform("join", mentor)
			expect(state.mentor == mentor and state.phase == "cafe", "%s/%s qualifies and joins" % [affinity, mentor])
			story.perform("accept_su", "0")
			var sandbox: ChapterTutorial = TUTORIAL.instantiate() as ChapterTutorial
			sandbox.chapter_state = state
			sandbox.automatic_flow = false
			root.add_child(sandbox)
			expect(sandbox.flow == &"intro" and sandbox.controller.living_team(true)[0].sl == state.sl and sandbox.controller.living_team(true)[0].hp == state.hp, "Campaign state enters %s/%s tutorial" % [affinity, mentor])
			var hero_definition: CombatantDefinition = sandbox.controller.living_team(true)[0].definition
			expect(hero_definition.affinity == affinity, "Birth affinity stays separate from mentor")
			if mentor == "shen":
				var probe: SkillDefinition = SkillDefinition.new()
				probe.sl_cost = 20
				expect(BattleCalculator.skill_cost(sandbox.controller.living_team(true)[0], probe, sandbox.controller.encounter.rules) == 19, "Shen's 5 percent load reduction reaches calculator")
			if mentor == "wen": expect(hero_definition.skills[0].cooldown == 0 and hero_definition.skills[1].cooldown == 1, "Wen's CD reduction reaches skills")
			if mentor == "tang": expect(hero_definition.max_hp == 242 and hero_definition.constitution == 13, "Tang's constitution and HP bonus reach battle")
			if mentor == "liu": expect(hero_definition.agility == 13, "Liu's agility reaches combatant definition")
			sandbox.begin_tutorial()
			var won: bool = true
			for lesson: int in range(3):
				won = won and finish_lesson(sandbox)
				if not won: break
				if lesson < 2:
					var ending: CombatantState = sandbox.controller.living_team(true)[0]
					var hp_before: int = ending.hp
					var sl_before: int = ending.sl
					sandbox.advance_lesson()
					var opening: CombatantState = sandbox.controller.living_team(true)[0]
					expect(opening.hp == mini(hp_before, state.max_hp()) and opening.sl == sl_before, "Campaign HP/SL carries to lesson%d; temporary breakthrough HP cap expires" % (lesson + 2))
			expect(won and sandbox.flow == &"complete", "%s/%s completes actual three battles" % [affinity, mentor])
			if not won:
				var diagnostic: FileAccess = FileAccess.open("res://.dev/chapter1-failed-%s-%s.json" % [str(ChapterSession.AFFINITIES.find(affinity)), mentor], FileAccess.WRITE)
				diagnostic.store_string(JSON.stringify(sandbox.tutorial_snapshot(), "\t")); diagnostic.close()
			if won:
				var hero: CombatantState = sandbox.controller.living_team(true)[0]
				story.finish_battle(hero.hp, hero.sl, sandbox.tutorial_snapshot())
				story.travel("clubs")
				story.perform("clubs")
				story.perform("clubs_leave")
				state.room="dorm" # Endpoint of the separately tested clubs_to_dorm animation.
				story.perform("dorm_wen")
				state.room="corridor"
				story.perform("chuxia")
				state.room="dorm"
				story.perform("sleep")
				story.perform("accept_task")
				story.perform("reception")
				story.perform("task")
				expect(state.phase == "complete" and state.money == 3300 and state.contribution == 5 and state.hp == state.max_hp() and state.sl == 0, "Complete chapter settles reward and overnight recovery once")
				var money_before: int = state.money
				story.perform("task"); story.perform("accept_su", "0"); story.perform("join", mentor)
				expect(state.money == money_before and state.relations.su == 45 and state.mentor == mentor, "Repeated rewards and commitments are idempotent")
				runs.append({"affinity": affinity, "mentor": mentor, "snapshot": state.snapshot()})
			sandbox.free()
	await _check_scene()
	var report: FileAccess = FileAccess.open("res://.dev/chapter1-smoke-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "runs": runs}, "\t"))
	report.close()
	print("[CHAPTER1 SMOKE] %d/%d checks passed; %d complete chapter branches" % [checks.size() - failures.size(), checks.size(), runs.size()])
	quit(0 if failures.is_empty() else 1)


func _check_guards() -> void:
	var state: ChapterSession = ChapterSession.new()
	var story: ChapterStory = ChapterStory.new(state)
	story.perform("join", "liu"); story.perform("accept_task"); story.perform("reception"); story.perform("sleep")
	expect(state.phase == "arrival" and state.money == 3000 and state.flags.is_empty(), "Unavailable actions cannot skip chapter gates")
	story.perform("exam")
	for mentor: String in ChapterSession.MENTORS: qualify(story, mentor)
	expect(state.mentor.is_empty() and state.flags.get("tang_done", false) and state.flags.get("shen_done", false), "All four tasks can be tried before confirmation")
	story.perform("join", "wen"); story.perform("join", "tang")
	expect(state.mentor == "wen" and state.max_hp() == 220, "Only one formal mentor can be chosen")
	var cabinet_state: ChapterSession = ChapterSession.new()
	var cabinet_story: ChapterStory = ChapterStory.new(cabinet_state)
	cabinet_story.perform("exam"); cabinet_story.perform("tang"); cabinet_story.perform("sort", "wrong")
	expect(not cabinet_state.flags.get("cabinet_sorted", false), "Wrong cabinet sorting does not qualify")
	cabinet_story.perform("sort", "correct"); cabinet_story.perform("firstaid", "0")
	expect(not cabinet_state.flags.get("tang_done", false), "Wrong first-aid answer can be retried")
	cabinet_story.perform("firstaid", "1")
	expect(cabinet_state.flags.get("tang_done", false), "Correct retry qualifies Tang")
	var remarks: Array[String] = []
	for answers: Array in [["0", "0", "0"], ["0", "1", "1"], ["0", "1", "2"]]:
		var question_state: ChapterSession = ChapterSession.new()
		var question_story: ChapterStory = ChapterStory.new(question_state)
		question_story.perform("exam"); question_story.perform("shen")
		var answer_response: Dictionary = {}
		for answer: String in answers: answer_response = question_story.perform("shen_answer", answer)
		remarks.append(String(answer_response.remark))
		expect(question_state.flags.get("shen_done", false) and answer_response.choices.size() == 2, "All Shen answer tendencies allow mentor confirmation")
	expect(remarks[0] != remarks[1] and remarks[1] != remarks[2], "Later Shen answers affect the remark and tied tendencies use the last answer")
	for attitude: String in ["0", "1", "2"]:
		var choice_state: ChapterSession = ChapterSession.new()
		var choice_story: ChapterStory = ChapterStory.new(choice_state)
		choice_story.perform("exam"); qualify(choice_story, "liu"); choice_story.perform("join", "liu"); choice_story.perform("accept_su", attitude)
		expect(int(choice_state.relations.su) == (45 if attitude == "0" else 43 if attitude == "1" else 40), "Su response %s applies specified relationship change" % attitude)
		expect(bool(choice_state.flags.invite_wen) == (attitude == "2"), "Wen invitation is recorded independently")
	var before: Dictionary = state.snapshot()
	var broken: Dictionary = before.duplicate(true)
	broken.hp = -1
	expect(not state.restore(broken) and state.snapshot() == before, "Invalid save is rejected without partial mutation")
	var save_file: String = "user://saves/test_chapter1_roundtrip.json"
	expect(state.save_to(save_file) == OK and state.save_to(save_file) == OK, "Atomic save supports repeated writes and backup")
	var restored: ChapterSession = ChapterSession.new()
	var loaded: bool = restored.load_from(save_file)
	var diagnostic: FileAccess = FileAccess.open("res://.dev/chapter1-save-comparison.json", FileAccess.WRITE)
	diagnostic.store_string(JSON.stringify({"loaded": loaded, "before": before, "after": restored.snapshot()}, "\t")); diagnostic.close()
	expect(loaded and JSON.parse_string(JSON.stringify(restored.snapshot())) == JSON.parse_string(JSON.stringify(before)), "Save roundtrip preserves chapter state and numeric values")
	var damaged: FileAccess = FileAccess.open(save_file, FileAccess.WRITE)
	damaged.store_string("{broken primary save"); damaged.close()
	var recovered: ChapterSession = ChapterSession.new()
	expect(recovered.load_from(save_file) and recovered.loaded_backup and JSON.parse_string(JSON.stringify(recovered.snapshot())) == JSON.parse_string(JSON.stringify(before)), "Damaged primary save recovers the validated backup")
	expect(recovered.save_to(save_file) == OK, "Recovered save can replace the corrupt primary")
	damaged = FileAccess.open(save_file, FileAccess.WRITE)
	damaged.store_string("{broken primary again"); damaged.close()
	var recovered_again: ChapterSession = ChapterSession.new()
	expect(recovered_again.load_from(save_file) and recovered_again.loaded_backup, "Saving after recovery retains a valid backup rather than backing up corruption")


func _check_scene() -> void:
	var app: ChapterOne = CHAPTER.instantiate() as ChapterOne
	app.save_path = "user://saves/test_chapter1_scene.json"
	root.add_child(app)
	await process_frame
	expect(app.mode == "title" and app.world.player.blocked and app.hud.title_layer.visible, "Chapter opens at title with world controls blocked")
	app.hud.affinity_select.select(1)
	app.hud.new_game_requested.emit("元素")
	expect(app.mode == "cinematic" and app.state.affinity == "元素" and app.state.room == "gate", "New game uses selected birth affinity and gate arrival")
	app.cinematics.skip()
	while app.mode == "dialogue": app.advance_dialogue()
	app.cinematics.skip()
	expect(app.mode == "world" and not app.world.player.blocked, "Dialogue returns control to exploration")
	app.open_map()
	expect(app.mode == "menu" and app.world.player.blocked, "Map menu locks walking")
	app.close_menu()
	expect(app.mode == "world" and not app.world.player.blocked, "Menu close returns walking")
	expect(app.world.ground is TileMapLayer and app.world.ground.get_used_cells().size() == 540 and app.world.player.frames.size() == 16, "Godot tilemap and processed character frames are integrated")
	app.interact("exam")
	while not app.hud.advance_button.disabled and app.mode == "dialogue": app.advance_dialogue()
	expect(app.hud.advance_button.disabled, "Reading delay blocks accidental skipping")
	app.return_to_title()
	app.start_new_game("强化")
	await create_timer(0.6).timeout
	expect(app._line_index == 0 and app.state.affinity == "强化", "Old reading timer cannot advance a new game")
	app.free()
