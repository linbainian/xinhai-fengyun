extends SceneTree

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var runs: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func expect(condition: bool, message: String) -> void:
	checks.append({"passed":condition,"message":message})
	if not condition: failures.append(message); push_error(message)


func completed_first() -> ChapterSession:
	var state: ChapterSession = ChapterSession.new()
	state.phase = "complete"
	state.room = "hall"
	state.mentor = "shen"
	state.money = 3300
	state.contribution = 5
	for id: String in ["tested","apprenticed","hill_accepted","hill_done","clubs_seen","slept","task_accepted","delivered","task_rewarded"]: state.flags[id] = true
	return state


func rescreen(story: ChapterTwoStory) -> void:
	while int(story.state.chapter_two.day)<15: story.calendar.sleep()
	story.perform("c2_notice")
	story.perform("c2_exam")
	story.perform("c2_list")
	story.perform("c2_box")
	story.perform("c2_exam")


func fight(story: ChapterTwoStory, id: String) -> Dictionary:
	var builder: ChapterRiftBattle = ChapterRiftBattle.new()
	builder.chapter_state = story.state
	builder.config = story.config
	builder.encounter_id = id
	var controller: BattleController = BattleController.new()
	expect(controller.start_battle(builder.build_encounter()), "Real encounter starts: "+id)
	var turns: Dictionary = {}
	for tick: int in range(1000):
		match controller.phase:
			BattleController.Phase.FINISHED: break
			BattleController.Phase.PRESENTING: controller.complete_presentation()
			BattleController.Phase.ENEMY_COMMAND, BattleController.Phase.AUTO_COMMAND: controller.submit_enemy_command()
			BattleController.Phase.PLAYER_COMMAND:
				var actor: CombatantState = controller.current_actor()
				turns[String(actor.id)] = int(turns.get(String(actor.id),0))+1
				var enemies: Array[CombatantState] = controller.living_team(false)
				var target: CombatantState = enemies[0]
				for candidate: CombatantState in enemies:
					if candidate.hp < target.hp: target = candidate
				var selected: SkillDefinition = null
				for skill: SkillDefinition in actor.definition.skills:
					if actor.cooldown_for(skill.id)==0 and actor.sl<65: selected = skill
				if actor.hp < actor.max_hp()*.4 and controller.can_breakthrough(actor) and actor.weak_actions==0:
					controller.submit_player_command(&"breakthrough")
				elif actor.sl>=65 or actor.weak_actions>0:
					controller.submit_player_command(&"defend")
				elif selected!=null: controller.submit_player_command(&"skill",target.id,selected.id)
				else: controller.submit_player_command(&"attack",target.id)
	expect(controller.result==&"victory", "Playable battle wins: %s/%s, result %s" % [story.state.affinity,id,controller.result])
	var vitals: Dictionary = story.state.chapter_two.party_vitals.duplicate(true)
	for unit: CombatantState in controller.combatants:
		if unit.is_player: vitals[String(unit.id)]={"hp":unit.hp,"sl":unit.sl}
	var result: Dictionary = {"vitals":vitals,"log":controller.log_snapshot(),"turns":turns}
	controller.free()
	builder.free()
	return result


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.dev"))
	var old: ChapterSession = completed_first()
	var snapshot: Dictionary = old.snapshot()
	snapshot.erase("chapter_two")
	var loaded: ChapterSession = ChapterSession.new()
	expect(loaded.restore(snapshot), "Existing Chapter 1 save migrates with empty Chapter 2 data")
	ChapterTwoCalendar.new(loaded).begin()
	var guard: ChapterTwoStory = ChapterTwoStory.new(loaded)
	expect(not guard.calendar.ready_for_port(), "Port task is locked before rescreen and February")
	guard.perform("c2_exam")
	expect(not loaded.flags.get("c2_exam_done",false), "Notice precedes examination")
	rescreen(guard)
	expect(loaded.chapter_two.stage=="campus" and loaded.relations.jiang==15 and loaded.relations.chuxia==20, "Rescreen, classmates and sealed archive connect")
	guard.perform("c2_join_club","element")
	guard.perform("c2_class")
	expect(loaded.chapter_two.slot==1, "One lesson spends exactly one daytime action")
	guard.perform("c2_training")
	expect(loaded.chapter_two.slot==2, "Second action reaches evening")
	var prior: Dictionary = loaded.snapshot()
	guard.perform("c2_class")
	expect(loaded.chapter_two.classes==prior.chapter_two.classes and loaded.chapter_two.slot==2, "Third daytime action is rejected")
	guard.perform("c2_social","jiang")
	expect(loaded.relations.jiang==20 and loaded.chapter_two.night_used, "Evening social spends its free slot and raises relationship")
	guard.perform("c2_social","jiang")
	expect(loaded.relations.jiang==20, "Evening slot cannot be spent twice")
	guard.perform("c2_invite","jiang")
	expect(loaded.chapter_two.party.has("jiang"), "Relationship threshold recruits Jiang")
	loaded.relations.han=30
	guard.perform("c2_invite","han")
	expect(not loaded.chapter_two.party.has("han"), "Rank B contact fails level difference gate")
	guard.perform("c2_sleep_now")
	expect(loaded.chapter_two.day==16 and loaded.chapter_two.slot==0 and not loaded.chapter_two.night_used, "Sleep advances one date and restores slots")
	guard.perform("c2_invite","jiang")
	expect(loaded.chapter_two.party.count("jiang")==1, "Repeat invitation cannot duplicate a party member")
	guard.perform("c2_help","campus")
	var reward: int = loaded.money
	guard.perform("c2_help","campus")
	expect(loaded.money==reward, "Weekly help reward is paid once")
	guard.perform("c2_repeat_week")
	expect(loaded.chapter_two.day==23 and loaded.chapter_two.weeks.size()==2, "Preset uses real daily actions and preserves the pre-rescreen weekly settlement")
	guard.perform("c2_help","campus")
	expect(loaded.money==reward+80, "Week rollover refreshes the same help task")
	for number: int in range(40):
		var state: ChapterSession = completed_first()
		state.affinity=ChapterSession.AFFINITIES[number%5]
		state.mentor=ChapterSession.MENTORS[number%4]
		state.hp=state.max_hp()
		ChapterTwoCalendar.new(state).begin()
		var story: ChapterTwoStory = ChapterTwoStory.new(state)
		rescreen(story)
		story.perform("c2_join_club",["sword","element","healing","none"][number%4])
		story.perform("c2_repeat_week")
		story.perform("c2_repeat_week")
		for day: int in range(3):
			story.perform("c2_class")
			story.perform("c2_training")
			if day==0: story.perform("c2_social","jiang")
			story.perform("c2_sleep_now")
		expect(state.chapter_two.day==32 and story.calendar.ready_for_port(), "February 1 opens the port task")
		if number%2==1:
			story.perform("c2_class")
			story.perform("c2_training")
			for id: String in ChapterTwoCalendar.COMPANIONS: story.perform("c2_invite",id)
			expect(state.chapter_two.party.size()==3, "Four-member party obeys relationships and schedules")
			story.perform("c2_sleep_now")
		var route: String = "bureau" if number%4<2 else "mutual"
		story.perform("c2_accept_route",route)
		story.perform("c2_enter_rift")
		expect(state.chapter_two.stage=="rift" and state.chapter_two.slot==2, "Rift registration reserves remaining daytime slots")
		var bad_vitals: Dictionary = {"lin_da":{"hp":99,"sl":0}}
		var hp_before: int = state.hp
		if not state.chapter_two.party.is_empty():
			expect(not story.finish_rift_battle("entry",bad_vitals,{"result":"victory"}) and state.hp==hp_before,"Incomplete party result is rejected atomically")
		var first: Dictionary = fight(story,"entry")
		expect(story.finish_rift_battle("entry",first.vitals,first.log), "Victory carries party HP and SL into exploration")
		expect(ChapterSession.new().restore(state.snapshot()), "Save restores between the two rift encounters")
		expect(not story.finish_rift_battle("entry",first.vitals,first.log), "Cleared encounter cannot settle twice")
		var storm: String = "shelter" if number%8<4 else "push"
		story.perform("c2_storm_choice",storm)
		var second: Dictionary = fight(story,"final")
		expect(story.finish_rift_battle("final",second.vitals,second.log), "Final victory enters corpse investigation")
		story.perform("c2_corpse")
		story.perform("c2_photo")
		var clue: String = ["bureau","bar","keep"][number%3]
		story.perform("c2_clue_choice",clue)
		if clue=="bureau": story.perform("reception")
		elif clue=="bar": story.perform("c2_bar"); story.perform("c2_old_hunter")
		var before_money: int = state.money
		story.perform("task")
		expect(state.chapter_two.stage=="complete" and state.money>=before_money+900, "Route and clue choices reach Chapter 2 settlement")
		before_money=state.money
		story.perform("task")
		expect(state.money==before_money, "Rift reward cannot be duplicated")
		var restored: ChapterSession = ChapterSession.new()
		expect(restored.restore(state.snapshot()), "Chapter 2 final save restores all route, party, vitals and date fields")
		var invalid: Dictionary = state.snapshot()
		invalid.chapter_two.party=["han"]
		expect(not restored.restore(invalid), "Malformed party save is rejected")
		runs.append({"affinity":state.affinity,"mentor":state.mentor,"party":state.chapter_two.party.duplicate(),"route":route,"storm":storm,"clue":clue,"grade":state.chapter_two.grade,"hp":state.hp,"sl":state.sl,"ally_turns":first.turns})
	var boundary: ChapterSession = completed_first()
	ChapterTwoCalendar.new(boundary).begin()
	var boundary_story: ChapterTwoStory = ChapterTwoStory.new(boundary)
	rescreen(boundary_story)
	boundary.chapter_two.party=ChapterTwoCalendar.COMPANIONS.duplicate()
	boundary.chapter_two.route="bureau";boundary.chapter_two.stage="rift"
	boundary.flags["c2_task_accepted"]=true
	var boosted: Dictionary = boundary.chapter_two.party_vitals.duplicate(true)
	boosted.lin_da={"hp":ceili(boundary.max_hp()*1.3),"sl":50}
	boosted.wen_rang.hp=325
	boosted.jiang.hp=0
	expect(boundary_story.finish_rift_battle("entry",boosted,{"result":"victory"}), "Breakthrough HP above base maximum is accepted at settlement")
	expect(boundary.hp==boundary.max_hp() and boundary.chapter_two.party_vitals.wen_rang.hp==250, "Temporary breakthrough HP is clamped to the persistent base maxima")
	expect(boundary.chapter_two.fallen and boundary.chapter_two.party_vitals.jiang.hp==0, "A downed companion remains down and affects the mission grade")
	boundary_story.perform("c2_storm_choice","push")
	expect(boundary.chapter_two.party_vitals.jiang.hp==0, "Passing the storm cannot revive a downed companion")
	var builder: ChapterRiftBattle = ChapterRiftBattle.new()
	builder.chapter_state=boundary;builder.config=boundary_story.config;builder.encounter_id="final"
	expect(builder.build_encounter().allies.size()==3, "Only living members enter the next encounter")
	builder.free()
	expect(ChapterSession.new().restore(boundary.snapshot()), "Mid-rift save preserves downed companions and storm outcome")
	boundary_story.perform("c2_retreat")
	boundary_story.perform("c2_resupply")
	expect(boundary.chapter_two.party_vitals.jiang.hp==175, "Port first aid restores a downed companion")
	boundary.chapter_two.stage="campus";boundary.chapter_two.club="none"
	for day: int in range(350): boundary_story.calendar.sleep()
	expect(boundary.chapter_two.day==365 and ChapterSession.new().restore(boundary.snapshot()), "December 31 remains a valid saved calendar date")
	var money_at_end: int = boundary.money
	var contribution_at_end: int = boundary.contribution
	boundary_story.perform("c2_sleep_now");boundary_story.perform("c2_repeat_week")
	expect(boundary.chapter_two.day==365 and boundary.money==money_at_end and boundary.contribution==contribution_at_end, "Year-end sleep and weekly preset stop without duplicate rewards or invalid dates")
	var file: FileAccess = FileAccess.open("res://.dev/chapter2-smoke-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"runs":runs},"\t"));file.close()
	print("[CHAPTER2 SMOKE] %d/%d checks passed; %d complete branches" % [checks.size()-failures.size(),checks.size(),runs.size()])
	quit(0 if failures.is_empty() else 1)
