extends "res://tests/cultivation_smoke.gd"


func event_story(id: String, day: int) -> ChapterTwoStory:
	var story: ChapterTwoStory = free_story()
	while int(story.state.chapter_two.day)<day: story.calendar.sleep()
	if id=="training_lunch": story.growth.data().seen.append("training_spar")
	for entry: Dictionary in story.growth.events:
		if String(entry.id)==id: return story
	assert(false,"Unknown encounter fixture")
	return story


func _run() -> void:
	var source: ChapterTwoStory = free_story()
	var new_events: Array[Dictionary] = []
	for entry: Dictionary in source.growth.events:
		if entry.get("character_event",false): new_events.append(entry)
	expect(new_events.size()==5 and source.growth.events.size()==11,"Five character events append to the original six without replacing IDs")
	for event: Dictionary in new_events:
		var early: ChapterTwoStory = event_story(String(event.id),int(event.min_day)-1)
		expect(not early.growth.eligible(event),"Date window does not open early: "+String(event.id))
		var late: ChapterTwoStory = event_story(String(event.id),15)
		expect(not late.growth.eligible(event),"Character event expires at January 15 without forcing a scene: "+String(event.id))
		for choice: int in range(2):
			var story: ChapterTwoStory = event_story(String(event.id),int(event.min_day))
			var state: ChapterSession = story.state
			var before: Dictionary = state.snapshot()
			var offer: Dictionary = story.perform("growth_roam",String(event.area))
			expect(String(story.growth.data().active_event)==String(event.id) and state.room==String(event.room),"Dated character event routes to its own physical room: %s/%d" % [event.id,choice])
			expect(int(state.chapter_two.slot)==1,"Departure spends exactly one day action: "+String(event.id))
			expect(offer.choices.size()==3 and offer.get("cinematic")==event.cinematic,"Departure automatically opens the scene and its choices: "+String(event.id))
			expect(not story.perform("growth_event").has("cinematic"),"Reopening pending choice does not replay its entrance scene")
			var saved: ChapterSession = ChapterSession.new()
			expect(saved.restore(JSON.parse_string(JSON.stringify(state.snapshot()))),"Save and reload preserves pending encounter and intro mark: "+String(event.id))
			var sl: int = state.sl
			var money: int = state.money
			var outcome: Dictionary = event.options[choice]
			story.perform("growth_event_choice",str(choice))
			expect(int(state.chapter_two.slot)==1 and state.sl==sl,"Choice rewards do not charge another action or alter unlisted SL")
			expect(state.money==money+int(outcome.get("money",0)),"Choice pays exactly the planned money change")
			for key: String in outcome.get("relations",{}):
				expect(int(state.relations[key])==int(before.relations.get(key,0))+int(outcome.relations[key]),"Exact planned relationship change: "+key)
			for key: String in outcome.get("stats",{}):
				expect(int(state.chapter_two.cultivation.attributes[key])==int(before.chapter_two.cultivation.attributes[key])+int(outcome.stats[key]),"Exact planned attribute change: "+key)
			expect(int(state.chapter_two.cultivation.life.study)==int(outcome.get("study",0)),"Exact planned study change")
			expect(int(state.chapter_two.cultivation.awakening)==int(outcome.get("awakening",0)),"Exact planned awakening change")
			expect(state.chapter_two.cultivation.seen.has(String(event.id)) and saved.restore(state.snapshot()),"Outcome is permanent and accepted by save validation")
			var completed: String = JSON.stringify(state.chapter_two.cultivation)
			var paid: int = state.money
			story.perform("growth_event_choice",str(choice))
			expect(JSON.stringify(state.chapter_two.cultivation)==completed and state.money==paid,"Resolved event cannot pay twice")
			if String(event.id)=="street_ice":
				expect(int(state.chapter_two.cultivation.inventory.coupon)==(1 if choice==0 else 2),"Eating uses the actual first-chapter voucher; cash takeaway preserves it")
			if String(event.id)=="training_spar":
				expect(not state.flags.has("bai_personal") and not state.flags.has("su_personal"),"Spar only introduces characters and does not unlock a personal line")
			if choice==0: runs.append({"event":event.id,"snapshot":state.snapshot()})
	var locked: ChapterTwoStory = event_story("training_spar",12)
	var lunch: Dictionary = locked.growth.events[9]
	expect(String(lunch.id)=="training_lunch" and not locked.growth.eligible(lunch),"Lunch practice requires a completed ice/lightning encounter")
	locked.growth.data().seen.append("training_spar")
	expect(locked.growth.eligible(lunch),"Completed spar unlocks lunch practice in its date window")
	var callback: ChapterTwoStory = event_story("training_spar",10)
	callback.growth.data().seen.append("campus_library")
	callback.growth.data().rank="C"; callback.growth.data().level=3
	callback.perform("growth_roam","training")
	expect(callback.perform("growth_event").dialogue=="c2_event_spar_known","Library callback follows actual prior encounter, including a C-rank player")
	callback.state.relations.bai_muyao=19; callback.state.relations.su_wantang=19
	callback.perform("growth_event_choice","0")
	expect(callback.state.relations.bai_muyao==20 and callback.state.relations.su_wantang==20,"Initial acquaintance rewards stop at 20 without starting C-rank personal lines")
	var poor: ChapterTwoStory = event_story("street_ice",6)
	poor.state.money=0; poor.growth.data().inventory.coupon=0
	poor.perform("growth_roam","street")
	var no_coupon: Dictionary = poor.perform("growth_event_choice","0")
	var no_money: Dictionary = poor.perform("growth_event_choice","1")
	expect(no_coupon.choices.size()==3 and no_money.choices.size()==3 and not no_money.get("open_cultivation",false),"Rejected payment stays at the event choices, without a walk back to the actor")
	expect(poor.growth.data().active_event=="street_ice" and poor.state.money==0 and not poor.growth.data().seen.has("street_ice"),"Insufficient voucher or money keeps the choice pending and grants no rewards")
	poor.perform("growth_event_choice","leave")
	expect(poor.growth.data().active_event=="" and not poor.growth.data().seen.has("street_ice"),"Leaving is free and permits a later encounter inside the date window")
	poor.perform("growth_roam","street")
	expect(poor.growth.data().active_event=="street_ice","Leaving does not consume the once-only story event")
	var legacy: Dictionary = source.state.snapshot()
	legacy.chapter_two.cultivation.inventory.erase("coupon")
	legacy.chapter_two.cultivation.erase("event_started")
	legacy.relations.erase("bai_muyao"); legacy.relations.erase("su_wantang")
	legacy.chapter_two.cultivation.active_event="hill_herbs"; legacy.chapter_two.cultivation.event_area="hill"
	var restored: ChapterSession = ChapterSession.new()
	expect(restored.restore(legacy) and restored.chapter_two.cultivation.active_event=="hill_herbs" and int(restored.chapter_two.cultivation.inventory.coupon)==2,"Existing cultivation.1 saves gain only optional defaults and keep a pending original encounter")
	for mutation: String in ["early","expired","requires","relation","coupon","started"]:
		var broken: Dictionary = callback.state.snapshot()
		match mutation:
			"early": broken.chapter_two.cultivation.active_event="training_spar"; broken.chapter_two.cultivation.event_area="training"; broken.chapter_two.cultivation.seen=[]; broken.chapter_two.day=5
			"expired": broken.chapter_two.cultivation.active_event="training_spar"; broken.chapter_two.cultivation.event_area="training"; broken.chapter_two.cultivation.seen=[]; broken.chapter_two.day=15
			"requires": broken.chapter_two.cultivation.active_event="training_lunch"; broken.chapter_two.cultivation.event_area="training"; broken.chapter_two.cultivation.seen=[]; broken.chapter_two.day=12; broken.chapter_two.week=1; broken.chapter_two.weeks=[{"week":1,"stats":{}}]
			"relation": broken.relations.bai_muyao=21
			"coupon": broken.chapter_two.cultivation.inventory.coupon=-1
			"started": broken.chapter_two.cultivation.event_started=true
		var original: String = JSON.stringify(restored.snapshot())
		expect(not restored.restore(broken) and JSON.stringify(restored.snapshot())==original,"Malformed event save rejected atomically: "+mutation)
	var first: ChapterSession = completed_first()
	first.phase="clubs";first.room="clubs"
	var first_story: ChapterStory = ChapterStory.new(first)
	first_story.perform("clubs")
	expect(first.phase=="clubs" and first.room=="clubs","Recruit dialogue no longer teleports to dorm")
	first_story.perform("clubs_leave")
	expect(first.phase=="dorm" and first.room=="clubs","Departure dialogue stays at stalls until the animated room transition")
	first.room="dorm"
	first_story.perform("chuxia")
	expect(not first.flags.get("chuxia_seen",false),"Chuxia initial meeting cannot trigger from a bedroom")
	first_story.perform("dorm_wen"); first.room="corridor"
	var rooms: Array[String]=first_story.locations()
	expect(rooms.has("corridor") and rooms.has("dorm"),"Video call releases the typed bedroom/corridor locations for normal progression")
	expect(first_story.perform("chuxia").get("cinematic")=="chuxia_corridor","Chuxia enters the shared corridor after the video call")
	expect(first_story.perform("chuxia").dialogue=="chuxia_repeat","Initial corridor meeting cannot replay its plot")
	var report: FileAccess = FileAccess.open("res://.dev/encounters-smoke-report.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"runs":runs},"\t"));report.close()
	print("[ENCOUNTERS SMOKE] %d/%d checks passed" % [checks.size()-failures.size(),checks.size()])
	quit(0 if failures.is_empty() else 1)
