extends "res://tests/chapter2_smoke.gd"


func free_story() -> ChapterTwoStory:
	var state: ChapterSession = completed_first()
	ChapterTwoCalendar.new(state).begin()
	return ChapterTwoStory.new(state)


func _run() -> void:
	var story: ChapterTwoStory = free_story()
	var state: ChapterSession = story.state
	expect(state.phase=="cultivation" and int(state.chapter_two.day)==4,"Chapter 1 leads to playable January 4 instead of January 15")
	story.perform("c2_notice"); story.perform("c2_exam")
	expect(not state.flags.get("c2_notice_seen",false) and not state.flags.get("c2_exam_done",false),"Rescreen cannot be completed before its date")
	var growth: ChapterCultivation = story.growth
	story.perform("growth_train","force")
	expect(int(growth.data().attributes.strength)==11 and int(growth.data().proficiency.strike)==4 and int(growth.data().awakening)==3 and int(state.chapter_two.slot)==1,"Training grants permanent attributes, skill practice and awakening for one action")
	story.perform("growth_train","body")
	expect(state.max_hp()==223 and int(growth.data().attributes.agility)==11 and int(state.chapter_two.slot)==2,"Constitution raises the persistent HP maximum")
	story.perform("growth_train","ability")
	expect(int(growth.data().attributes.spirit)==10 and int(state.chapter_two.slot)==2,"Exhausted daytime budget cannot grant a third training reward")
	story.perform("growth_night","read")
	var study: int = int(growth.data().life.study)
	story.perform("growth_night","wen")
	expect(study==5 and bool(state.chapter_two.night_used) and state.relations.wen_rang==80,"Night activities share a single opportunity")
	story.perform("c2_sleep_now")
	expect(int(state.chapter_two.day)==5 and state.hp==223 and int(state.chapter_two.slot)==0 and not bool(state.chapter_two.night_used),"Sleep restores vitals and action opportunities while retaining growth")
	story.perform("growth_train","ability")
	story.perform("growth_train","focus")
	expect(int(growth.data().attributes.spirit)==11 and int(growth.data().attributes.willpower)==11 and int(growth.data().attributes.perception)==13,"Ability and focus training affect different attributes")
	var builder: ChapterRiftBattle = ChapterRiftBattle.new()
	builder.chapter_state=state; builder.config=story.config
	var hero: CombatantDefinition = builder.build_encounter().allies[0].definition
	expect(hero.max_hp==223 and hero.attack>float(state.settings.hero.attack) and hero.defense>float(state.settings.hero.defense),"Actual battle definition uses trained HP, attack and defense")
	expect(hero.spirit==11 and hero.perception==13 and hero.willpower==14 and hero.skill_sl_multiplier<.95,"Actual battle attributes retain mentor bonuses and reduce skill load")
	expect(hero.skills[0].multiplier>float(state.settings.skill_values[0].multiplier),"Trained spirit increases actual skill power")
	for milestone: int in [19,20,49,50,79,80,100]:
		growth.data().proficiency.strike=milestone
		hero=builder.build_encounter().allies[0].definition
		var expected: float = float(state.settings.skill_values[0].multiplier)*1.01*ChapterCultivation.proficiency_bonus(milestone)
		expect(is_equal_approx(hero.skills[0].multiplier,expected),"Skill proficiency threshold applies in battle: %d" % milestone)
	builder.free()
	var restored: ChapterSession = ChapterSession.new()
	expect(restored.restore(JSON.parse_string(JSON.stringify(state.snapshot()))),"Grown stats, inventory and calendar survive serialized save restoration")
	for mutation: String in ["attribute","skill","rank","seen","area","week","phase","hp"]:
		var invalid: Dictionary = state.snapshot()
		match mutation:
			"attribute": invalid.chapter_two.cultivation.attributes.strength=99
			"skill": invalid.chapter_two.cultivation.proficiency.strike=-1
			"rank": invalid.chapter_two.cultivation.rank="S"
			"seen": invalid.chapter_two.cultivation.seen=["campus_notes","campus_notes"]
			"area": invalid.chapter_two.cultivation.active_event="hill_herbs"; invalid.chapter_two.cultivation.event_area="campus"
			"week": invalid.chapter_two.cultivation.jobs_done.files=99
			"phase": invalid.phase="chapter_two"
			"hp": invalid.hp=999
		var prior: String = JSON.stringify(restored.snapshot())
		expect(not restored.restore(invalid) and JSON.stringify(restored.snapshot())==prior,"Malformed growth save rejected atomically: "+mutation)
	var legacy_story: ChapterTwoStory = free_story()
	rescreen(legacy_story)
	legacy_story.perform("c2_join_club","none")
	legacy_story.perform("c2_repeat_week")
	var legacy: Dictionary = legacy_story.state.snapshot()
	legacy.chapter_two.version="chapter2-prototype.1"
	legacy.chapter_two.erase("cultivation"); legacy.chapter_two.erase("calendar_epoch")
	legacy.chapter_two.week=1; legacy.chapter_two.weeks=[legacy.chapter_two.weeks.back()]
	legacy.chapter_two.weeks[0].week=1
	legacy.chapter_two.weekly_tasks.files=1
	expect(restored.restore(legacy) and int(restored.chapter_two.day)==22 and int(restored.chapter_two.calendar_epoch)==15,"Existing Chapter 2 saves migrate without rewinding date or replaying Chapter 1")
	var migrated: ChapterTwoStory = ChapterTwoStory.new(restored)
	var legacy_money: int = restored.money
	migrated.perform("growth_job","files")
	expect(restored.money==legacy_money,"Legacy weekly work records migrate without paying the same task again")
	var pending_story: ChapterTwoStory = free_story()
	pending_story.perform("growth_roam","hill")
	var pending_state: ChapterSession = pending_story.state
	expect(pending_state.room=="hill" and pending_story.growth.data().active_event=="hill_herbs","Wandering spends an action and creates an encounter in its real map")
	var pending_snapshot: Dictionary = pending_state.snapshot()
	var money: int = pending_state.money
	pending_story.perform("growth_train","force"); pending_story.perform("c2_sleep_now"); pending_story.perform("c2_repeat_week")
	expect(int(pending_state.chapter_two.day)==4 and int(pending_state.chapter_two.slot)==1,"Unresolved map encounter blocks conflicting training and date advancement")
	expect(restored.restore(pending_snapshot) and restored.chapter_two.cultivation.active_event=="hill_herbs","Reload preserves the exact unresolved encounter")
	pending_story=ChapterTwoStory.new(restored)
	pending_story.perform("growth_event_choice","0")
	expect(int(restored.chapter_two.cultivation.inventory.herb)==2 and restored.chapter_two.cultivation.seen.has("hill_herbs"),"Map choice gives herbs and permanently marks its event")
	pending_story.perform("growth_event_choice","0")
	expect(int(restored.chapter_two.cultivation.inventory.herb)==2,"Resolved encounter cannot pay its reward twice")
	for branch: int in range(12):
		var run: ChapterTwoStory = free_story()
		while int(run.state.chapter_two.day)<8: run.calendar.sleep()
		var target_event: Dictionary = run.growth.events[branch/2]
		# Remove the new character encounters from this original-six regression;
		# their priorities and all date windows have dedicated encounter tests.
		for entry: Dictionary in run.growth.events:
			if entry.get("character_event",false): run.growth.data().seen.append(String(entry.id))
		var area: String = String(target_event.area)
		run.perform("growth_roam",area)
		if String(run.growth.data().active_event)!=String(target_event.id):
			run.perform("growth_event_choice","0")
			run.perform("growth_roam",area)
		var event: Dictionary = run.growth.event_definition()
		expect(String(event.get("id",""))==String(target_event.id) and run.perform("growth_event").choices.size()==3,"Each automatic encounter preserves two outcomes and a leave option: "+String(target_event.id))
		run.perform("growth_event_choice",str(branch%2))
		expect(run.growth.data().active_event=="" and run.growth.data().seen.has(String(target_event.id)) and ChapterSession.new().restore(run.state.snapshot()),"All six encounters and both outcomes settle and save: %d" % branch)
	var poor: ChapterTwoStory = free_story()
	poor.state.money=0
	poor.perform("growth_roam","street")
	poor.perform("growth_event_choice","0")
	expect(poor.state.money==0 and poor.growth.data().active_event=="street_books","Unaffordable book purchase keeps the choice pending and cannot make money negative")
	poor.perform("growth_event_choice","1")
	expect(poor.growth.data().active_event=="" and int(poor.growth.data().life.study)==3,"Free alternative resolves the book encounter")
	pending_story.perform("growth_sell")
	expect(restored.money==money+60 and int(restored.chapter_two.cultivation.inventory.herb)==0,"Only owned herbs can be sold")
	pending_story.perform("growth_sell")
	expect(restored.money==money+60,"Selling an empty inventory cannot pay twice")
	var worker: ChapterTwoStory = free_story()
	worker.perform("growth_job","courier")
	var before: int = worker.state.money
	worker.perform("growth_deliver")
	expect(worker.state.money==before and worker.growth.data().job=="courier","Courier acceptance and remote completion do not issue money")
	worker.state.room="cbd"
	worker.perform("reception")
	expect(worker.state.money==before+150 and worker.growth.data().job=="","Physical service-hall handover pays the courier reward")
	worker.perform("reception")
	worker.perform("growth_job","courier")
	expect(worker.state.money==before+150 and worker.growth.data().job=="","Courier reward cannot repeat during the same week")
	worker.perform("growth_job","files")
	before=worker.state.money
	worker.perform("c2_help","files")
	expect(worker.state.money==before,"World task board and growth panel share the same weekly reward ledger")
	worker.perform("c2_repeat_week")
	worker.perform("growth_job","files")
	expect(worker.state.money==before+80,"Weekly refresh makes an already completed work order available again")
	var transition: ChapterTwoStory = free_story()
	transition.perform("c2_repeat_week")
	expect(int(transition.state.chapter_two.day)==11 and transition.state.phase=="cultivation","One preset still leaves several free cultivation days")
	var trained: int = int(transition.growth.data().attributes.strength)
	transition.perform("c2_repeat_week")
	expect(int(transition.state.chapter_two.day)==15 and transition.state.phase=="chapter_two" and transition.state.chapter_two.stage=="rescreen","Preset stops exactly at the mandatory January 15 story date")
	transition.perform("c2_repeat_week"); transition.calendar.sleep()
	expect(int(transition.state.chapter_two.day)==15,"Unfinished rescreen cannot be skipped by sleep or another preset")
	rescreen(transition)
	expect(int(transition.growth.data().attributes.strength)>trained and transition.state.chapter_two.stage=="campus","Rescreen resumes the calendar while retaining pre-chapter training")
	for success: bool in [true,false]:
		var breakthrough: ChapterTwoStory = free_story()
		breakthrough.growth.data().awakening=100
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		for attempt: int in range(1,1000):
			rng.seed=int(breakthrough.growth.config.seed)+attempt*101
			if (rng.randi_range(1,100)<=95)==success:
				breakthrough.growth.data().attempts=attempt-1
				break
		breakthrough.perform("growth_breakthrough")
		if success:
			expect(breakthrough.growth.data().rank=="C" and int(breakthrough.growth.data().level)==3,"Safe breakthrough permanently promotes the character and action level")
			builder=ChapterRiftBattle.new(); builder.chapter_state=breakthrough.state; builder.config=breakthrough.config
			expect(builder.build_encounter().allies[0].definition.awakening_rank=="C","Persistent rank carries into the actual rift encounter")
			builder.free()
		else:
			expect(breakthrough.growth.data().rank=="D" and int(breakthrough.growth.data().awakening)==65 and int(breakthrough.growth.data().inventory.insight)==1,"Failed breakthrough retains D rank and grants the documented recovery state and insight")
		expect(ChapterSession.new().restore(breakthrough.state.snapshot()),"Both safe breakthrough outcomes can be saved")
	var campaign: ChapterTwoStory = free_story()
	for day: int in range(11):
		campaign.perform("growth_train","ability")
		campaign.perform("growth_train","body" if day%2==0 else "force")
		campaign.perform("growth_night","read")
		campaign.perform("c2_sleep_now")
	expect(int(campaign.state.chapter_two.day)==15 and campaign.growth.data().attributes.spirit==21,"Eleven individually chosen days reach Chapter 2 with accumulated growth")
	rescreen(campaign)
	while int(campaign.state.chapter_two.day)<32: campaign.calendar.sleep()
	campaign.perform("c2_accept_route","bureau"); campaign.perform("c2_enter_rift")
	var battle: Dictionary = fight(campaign,"entry")
	expect(campaign.finish_rift_battle("entry",battle.vitals,battle.log),"Trained hero completes and settles a real Chapter 2 battle")
	expect(ChapterSession.new().restore(campaign.state.snapshot()),"Post-battle save retains pre-chapter growth and carried vitals")
	var file: FileAccess = FileAccess.open("res://.dev/cultivation-smoke-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures},"\t")); file.close()
	print("[CULTIVATION SMOKE] %d/%d checks passed" % [checks.size()-failures.size(),checks.size()])
	quit(0 if failures.is_empty() else 1)
