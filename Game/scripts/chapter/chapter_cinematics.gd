class_name ChapterCinematics
extends Node

var active: bool = false
var sequence_id: String = ""
var step_index: int = -1
var completed: Array[String] = []
var trace: Array[Dictionary] = []
var _app: Node
var _world: ChapterMap
var _hud: ChapterHUD
var _display: ChapterDisplay
var _data: Dictionary = {}
var _steps: Array = []
var _step: Dictionary = {}
var _age: float = 0.0
var _duration: float = 0.0
var _moves: Array[Dictionary] = []
var _done: Callable
var _camera_from: Vector2
var _camera_to: Vector2
var _fade_from: float = 0.0
var _fade_to: float = 0.0
var _ui: Control
var _top: ColorRect
var _bottom: ColorRect
var _fade: ColorRect
var _caption: Label
var _card: Panel
var _name: Label
var _role: Label
var _portrait: TextureRect
var _skip: Button
var _effects: Dictionary = {}


func configure(app: Node, world: ChapterMap, hud: ChapterHUD, display: ChapterDisplay) -> void:
	_app = app
	_world = world
	_hud = hud
	_display = display
	_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter1/cutscenes.json")) as Dictionary
	var second: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter2/cutscenes.json"))
	if second is Dictionary: _data.merge(second)
	var encounters: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cultivation/cutscenes.json"))
	if encounters is Dictionary: _data.merge(encounters)
	_ui = Control.new()
	_ui.name = "CinematicOverlay"
	_ui.z_index = 100
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_ui)
	_top = _band()
	_bottom = _band()
	_caption = hud._label(_top, "", Rect2(40, 14, 1300, 42), 27)
	_card = hud._panel(_ui, Rect2(70, 740, 650, 190))
	_portrait = TextureRect.new()
	_portrait.position = Vector2(12, 8)
	_portrait.size = Vector2(172, 172)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_card.add_child(_portrait)
	_name = hud._label(_card, "", Rect2(192, 28, 430, 60), 42)
	_name.add_theme_color_override("font_color", ChapterHUD.GOLD)
	_role = hud._label(_card, "", Rect2(192, 100, 430, 58), 26)
	_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skip = hud._button(_bottom, "跳过演出 [Esc]", Rect2(1500, 20, 340, 56), 25)
	_skip.pressed.connect(skip)
	_fade = _band()
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.hide()
	set_process(false)


func _band() -> ColorRect:
	var band: ColorRect = ColorRect.new()
	band.color = Color(0.015, 0.027, 0.035)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(band)
	return band


func play(id: String, done: Callable) -> void:
	cancel()
	assert(_data.has(id), "Missing cinematic: " + id)
	sequence_id = id
	_steps = _data[id].duplicate(true)
	_done = done
	step_index = -1
	active = true
	# A wider integer camera establishes architecture and the actors' route.
	_world.camera.zoom = Vector2.ONE * float(_world.definition.get("cinematicZoom",1))
	_world.cinematic_camera = true
	_world.cinematic_focus = _world.camera.position
	_world.follow_enabled = false
	_hud.dialog_panel.hide()
	_hud.top_panel.hide()
	_hud.prompt_label.hide()
	_hud.toast_panel.hide()
	_hud.nameplate_layer.hide()
	_hud.menu_layer.hide()
	_hud.choice_layer.hide()
	_fade.modulate.a = 0.0
	_card.hide()
	_ui.show()
	_layout()
	set_process(true)
	_next()


func _next() -> void:
	_stop_motion()
	step_index += 1
	if step_index >= _steps.size():
		var callback: Callable = _done
		completed.append(sequence_id)
		cancel()
		if callback.is_valid(): callback.call()
		return
	_step = _steps[step_index]
	_age = 0.0
	_duration = maxf(0.0, float(_step.get("seconds", 0.0)))
	trace.append({"sequence": sequence_id, "step": step_index, "kind": _step.kind, "room": _app.state.room})
	_card.visible = _step.has("name")
	if _step.has("caption"): _caption.text = String(_step.caption)
	if _step.has("name"):
		_name.text = String(_step.name)
		_role.text = String(_step.get("role", ""))
		_portrait.texture = load(String(_step.get("portrait", "res://assets/chapter1/cinematics/%s/frames/frame_000.png" % _step.get("character","wen_rang")))) as Texture2D
	_camera_from = _world.cinematic_focus
	var focus: Array = _step.get("camera", [_camera_from.x, _camera_from.y])
	_camera_to = Vector2(float(focus[0]), float(focus[1]))
	_fade_from = _fade.modulate.a
	_fade_to = float(_step.get("alpha", _fade_from))
	match String(_step.kind):
		"prop":
			var object: Node2D = _world.object_for(String(_step.id))
			if object != null: object.visible=bool(_step.visible)
		"effect":
			var sprite: Sprite2D = _effects.get(String(_step.id)) as Sprite2D
			if sprite == null:
				sprite=Sprite2D.new()
				sprite.centered=false
				sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.z_index=3
				_world.actors.add_child(sprite)
				_effects[String(_step.id)]=sprite
			sprite.position=Vector2(float(_step.position[0]),float(_step.position[1]))
		"scene":
			_app.state.room = String(_step.room)
			_app._load_room()
			_world.camera.zoom=Vector2.ONE * float(_world.definition.get("cinematicZoom",1))
			_world.cinematic_camera = true
			_world.cinematic_focus = _camera_to
			for id: String in _step.get("positions", {}):
				var actor: Node2D = _world.actor_for(id)
				var point: Array = _step.positions[id]
				if actor != null: actor.position = Vector2(float(point[0]), float(point[1]))
		"move":
			for entry: Dictionary in _step.get("actors", []):
				var actor: Node2D = _world.actor_for(String(entry.id))
				assert(actor != null, "Missing cinematic actor: " + String(entry.id))
				actor.show()
				var path: PackedVector2Array = [actor.position]
				for values: Array in entry.path: path.append(Vector2(float(values[0]), float(values[1])))
				var distance: float = 0.0
				for index: int in range(1, path.size()): distance += path[index-1].distance_to(path[index])
				_moves.append({"actor": actor, "path": path, "length": distance, "face": entry.get("face", [0,1])})
		"face":
			for id: String in _step.actors:
				var actor: Node2D = _world.actor_for(id)
				var values: Array = _step.actors[id]
				_motion(actor, Vector2(float(values[0]), float(values[1])), false)
	if _duration == 0.0: _tick(1.0); _next()


func _process(delta: float) -> void:
	if not active: return
	_layout()
	_age += delta
	_tick(clampf(_age / maxf(_duration, 0.001), 0.0, 1.0))
	if _age >= _duration: _next()


func _tick(progress: float) -> void:
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	_world.cinematic_focus = _camera_from.lerp(_camera_to, eased).round()
	_fade.modulate.a = lerpf(_fade_from, _fade_to, progress)
	_card.position.x = 70.0 - 44.0 * (1.0 - minf(progress * 5.0, 1.0))
	_card.modulate.a = minf(progress * 5.0, 1.0)
	if String(_step.get("kind",""))=="effect":
		var sprite: Sprite2D = _effects.get(String(_step.id)) as Sprite2D
		var frames: Array = _step.frames
		var frame: int = int(frames[mini(frames.size()-1,floori(progress*frames.size()))])
		sprite.texture=load("%s/frame_%03d.png" % [String(_step.folder),frame]) as Texture2D
		var target: Array = _step.get("size",[128,128])
		sprite.scale=Vector2(float(target[0]),float(target[1]))/Vector2(sprite.texture.get_size())
		sprite.offset=Vector2(-sprite.texture.get_width()/2.0,-sprite.texture.get_height())
	for move: Dictionary in _moves:
		var remaining: float = float(move.length) * progress
		var path: PackedVector2Array = move.path
		for index: int in range(1, path.size()):
			var segment: float = path[index-1].distance_to(path[index])
			if remaining <= segment or index == path.size()-1:
				var actor: Node2D = move.actor
				actor.position = path[index-1].lerp(path[index], clampf(remaining / maxf(segment,0.001),0,1)).round()
				_motion(actor, path[index]-path[index-1], progress < 1.0)
				if progress >= 1.0:
					var face: Array = move.face
					_motion(actor, Vector2(float(face[0]),float(face[1])), false)
				break
			remaining -= segment


func _motion(actor: Node2D, direction: Vector2, moving: bool) -> void:
	if actor is ChapterActor: (actor as ChapterActor).set_motion(direction, moving)
	elif actor is ChapterPlayer:
		(actor as ChapterPlayer).scripted_velocity = direction.normalized() if moving else Vector2.ZERO
		if direction != Vector2.ZERO:
			(actor as ChapterPlayer).facing = Vector2(signf(direction.x),0) if absf(direction.x) > absf(direction.y) else Vector2(0,signf(direction.y))


func _stop_motion() -> void:
	for move: Dictionary in _moves:
		if is_instance_valid(move.actor): _motion(move.actor, Vector2.ZERO, false)
	_moves.clear()


func _layout() -> void:
	_ui.size = _hud.size
	_top.size = Vector2(_ui.size.x, 72)
	_bottom.position = Vector2(0, _ui.size.y-92)
	_bottom.size = Vector2(_ui.size.x, 92)
	_skip.position.x = _ui.size.x - 380
	_fade.size = _ui.size
	_card.position.y = _ui.size.y-300


func skip() -> void:
	# Apply the same endpoints and scene changes; gameplay commits only in done once.
	while active:
		_tick(1.0)
		_next()


func restore_endpoint(id: String) -> void:
	# A saved choice restores its staging without replaying the entrance.
	assert(_data.has(id), "Missing saved encounter scene: " + id)
	for step: Dictionary in _data[id]:
		match String(step.kind):
			"scene":
				if _app.state.room != String(step.room):
					_app.state.room = String(step.room)
					_app._load_room()
				for actor_id: String in step.get("positions", {}):
					var actor: Node2D = _world.actor_for(actor_id)
					var point: Array = step.positions[actor_id]
					if actor != null: actor.position = Vector2(float(point[0]), float(point[1])).round()
			"move":
				for entry: Dictionary in step.get("actors", []):
					var actor: Node2D = _world.actor_for(String(entry.id))
					if actor == null or entry.path.is_empty(): continue
					var point: Array = entry.path.back()
					var face: Array = entry.get("face", [0, 1])
					actor.position = Vector2(float(point[0]), float(point[1])).round()
					_motion(actor, Vector2(float(face[0]), float(face[1])), false)
			"face":
				for actor_id: String in step.actors:
					var actor: Node2D = _world.actor_for(actor_id)
					var face: Array = step.actors[actor_id]
					if actor != null: _motion(actor, Vector2(float(face[0]), float(face[1])), false)
			"prop":
				var object: Node2D = _world.object_for(String(step.id))
				if object != null: object.visible = bool(step.visible)


func cancel() -> void:
	active = false
	set_process(false)
	_stop_motion()
	for sprite: Sprite2D in _effects.values():
		if is_instance_valid(sprite): sprite.free()
	_effects.clear()
	_done = Callable()
	if _ui == null: return
	_ui.hide()
	_fade.modulate.a = 0.0
	_world.cinematic_camera = false
	_world.camera.zoom = Vector2(2, 2)
	_world.reset_follow()
	_hud.top_panel.show()
	_hud.prompt_label.show()
