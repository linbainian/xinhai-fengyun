class_name ChapterBattleEffects
extends Node2D

const FRAME_ROOT: String = "res://assets/chapter1/refined/fx/frames/frame_%03d.png"
var frames: Array[Texture2D] = []
var last_feedback: Array[Dictionary] = []
var _records: Array[Dictionary] = []
var _floating_layer: Control
var _display: ChapterDisplay
var _affected: Array[CombatantView] = []


func _ready() -> void:
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for index: int in range(20):
		frames.append(load(FRAME_ROOT % index) as Texture2D)
	set_process(false)


func configure(hud: Control, display_value: ChapterDisplay) -> void:
	_display = display_value
	_floating_layer = Control.new()
	_floating_layer.name = "BattleFeedback"
	_floating_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floating_layer.z_index = 20
	hud.add_child(_floating_layer)


func present(action: Dictionary, views: Dictionary, duration: float) -> void:
	clear()
	var actor: CombatantView = views.get(StringName(action.actor_id)) as CombatantView
	if actor == null: return
	var command: String = String(action.command)
	var origin: Vector2 = _center(actor)
	if command == "defend":
		_effect(3, origin, origin, Vector2(132, 142), 0.0, duration, Color.WHITE)
		_float("防御  SL−%d\nHP＋%d" % [int(action.sl_relief), int(action.healing)], origin, 0.1 * duration, 0.9 * duration, Color(0.5, 0.95, 0.87))
	elif command == "breakthrough":
		var success: bool = bool(action.success)
		_effect(4, origin, origin, Vector2(156, 172), 0.0, duration, Color.WHITE if success else Color(1.0, 0.35, 0.65))
		_float("突破成功" if success else "突破受阻", origin, 0.1 * duration, 0.9 * duration, Color(1.0, 0.9, 0.45) if success else Color(1.0, 0.48, 0.65))
	else:
		# Top-level target_id is only the first target. Always present every actual outcome,
		# including redirected/uncontrolled hits, without changing battle state or RNG.
		for outcome: Dictionary in action.get("outcomes", []):
			var target: CombatantView = views.get(StringName(outcome.target_id)) as CombatantView
			if target == null: continue
			var destination: Vector2 = _center(target)
			var hit: bool = bool(outcome.hit)
			var color: Color = _affinity_color(actor.unit.definition.affinity) if command == "skill" else Color.WHITE
			if command == "skill":
				_effect(2, origin, destination, Vector2(108, 80), 0.0, 0.38 * duration, color)
			else:
				_effect(0, destination, destination, Vector2(118, 118), 0.15 * duration, 0.65 * duration, Color.WHITE)
			if hit:
				_effect(1, destination, destination, Vector2(104, 104), 0.38 * duration, 0.62 * duration, color)
				_affected.append(target)
				_records.append({"kind": "reaction", "view": target, "direction": 1.0 if target.position.x >= actor.position.x else -1.0,
					"age": 0.0, "delay": 0.38 * duration, "life": 0.62 * duration, "started": false})
			var text_value: String = str(int(outcome.damage)) if hit else "未命中"
			if hit and float(outcome.get("modifiers", {}).get("affinity", 1.0)) > 1.0:
				text_value += " · 克制"
			_float(text_value, destination, 0.38 * duration, 0.62 * duration,
				Color(1.0, 0.58, 0.38) if target.unit.is_player and hit else Color(1.0, 0.94, 0.68) if hit else Color(0.78, 0.86, 0.88))
			last_feedback.append({"target_id": String(outcome.target_id), "hit": hit, "damage": int(outcome.damage), "command": command})
	set_process(not _records.is_empty())


func _center(view: CombatantView) -> Vector2:
	return view._rest_position + view._art_rect.get_center() * view.scale


func _affinity_color(affinity: String) -> Color:
	return {"强化": Color(1.0, 0.62, 0.38), "元素": Color(0.55, 0.9, 1.0), "精神": Color(0.85, 0.6, 1.0),
		"念动力": Color(0.56, 1.0, 0.72), "特殊": Color(1.0, 0.86, 0.5)}.get(affinity, Color.WHITE)


func _effect(row: int, from: Vector2, to: Vector2, dimensions: Vector2, delay: float, life: float, tint: Color) -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = frames[row * 4]
	sprite.scale = dimensions / Vector2(96, 96)
	sprite.modulate = tint
	sprite.flip_h = row == 2 and to.x < from.x
	sprite.visible = false
	add_child(sprite)
	_records.append({"kind": "effect", "node": sprite, "row": row, "from": from, "to": to,
		"age": 0.0, "delay": delay, "life": life})


func _float(text_value: String, point: Vector2, delay: float, life: float, tint: Color) -> void:
	var label: Label = Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(340, 110)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.07))
	label.add_theme_constant_override("outline_size", 6)
	label.visible = false
	_floating_layer.add_child(label)
	_records.append({"kind": "float", "node": label, "point": point, "age": 0.0, "delay": delay, "life": life})


func _process(delta: float) -> void:
	for record: Dictionary in _records:
		record.age += delta
		var elapsed: float = float(record.age) - float(record.delay)
		if elapsed < 0.0: continue
		var progress: float = clampf(elapsed / maxf(float(record.life), 0.001), 0.0, 1.0)
		match record.kind:
			"reaction":
				if not record.started and is_instance_valid(record.view):
					record.started = true
					(record.view as CombatantView).animate_hit(float(record.direction), float(record.life))
			"effect":
				var sprite: Sprite2D = record.node as Sprite2D
				sprite.visible = progress < 1.0
				sprite.texture = frames[int(record.row) * 4 + mini(3, floori(progress * 4.0))]
				sprite.position = (record.from as Vector2).lerp(record.to as Vector2, progress).round()
			"float":
				var label: Label = record.node as Label
				label.visible = progress < 1.0
				label.position = _display.world_to_ui(record.point as Vector2) - Vector2(170, 102 + progress * 56)
				var field: Rect2 = (_floating_layer.get_parent() as ChapterBattleHUD).battlefield_rect()
				label.position.x = clampf(label.position.x, field.position.x + 8.0, field.end.x - label.size.x - 8.0)
				label.position.y = clampf(label.position.y, field.position.y + 8.0, field.end.y - label.size.y - 8.0)
				label.modulate.a = minf(1.0, (1.0 - progress) * 4.0)


func clear() -> void:
	set_process(false)
	for record: Dictionary in _records:
		if record.has("node") and is_instance_valid(record.node):
			(record.node as Node).free()
	for view: CombatantView in _affected:
		if is_instance_valid(view): view.finish_hit()
	_records.clear()
	_affected.clear()
	last_feedback.clear()
