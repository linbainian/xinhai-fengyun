class_name CombatantView
extends Node2D

var unit: CombatantState
var active: bool = false
var selected: bool = false
var art_texture: Texture2D:
	set(value):
		if art_texture == value: return
		art_texture = value
		_art_rect = Rect2(-24, -48, 48, 48)
		if value != null:
			var bounds: Rect2i = value.get_image().get_used_rect()
			var source_to_world: Vector2 = Vector2(48, 48) / Vector2(value.get_size())
			_art_rect = Rect2(Vector2(bounds.position) * source_to_world - Vector2(24, 48), Vector2(bounds.size) * source_to_world)
var _art_rect: Rect2 = Rect2(-24, -48, 48, 48)
var _rest_position: Vector2
var _tween: Tween
var _hit_tween: Tween
var _hit_offset: Vector2 = Vector2.ZERO:
	set(value):
		_hit_offset = value
		queue_redraw()
var _hit_tint: Color = Color.WHITE:
	set(value):
		_hit_tint = value
		queue_redraw()


func animate_hit(direction: float, duration: float) -> void:
	finish_hit()
	_hit_tween = create_tween().set_parallel(true)
	_hit_tween.tween_property(self, "_hit_offset", Vector2(5.0 * direction, 0), duration * 0.2)
	_hit_tween.tween_property(self, "_hit_tint", Color(1.8, 1.8, 1.8), duration * 0.2)
	_hit_tween.chain().tween_property(self, "_hit_offset", Vector2.ZERO, duration * 0.8)
	_hit_tween.parallel().tween_property(self, "_hit_tint", Color.WHITE, duration * 0.8)


func finish_hit() -> void:
	if _hit_tween != null and _hit_tween.is_valid(): _hit_tween.kill()
	_hit_offset = Vector2.ZERO
	_hit_tint = Color.WHITE


func _ready() -> void:
	_rest_position = position


func update_state(source: CombatantState, acting: bool, targeted: bool) -> void:
	unit = source
	active = acting
	selected = targeted
	queue_redraw()


func set_home(position_value: Vector2) -> void:
	finish_animation()
	_rest_position = position_value
	position = position_value


func animate_action(command: StringName, duration: float) -> void:
	finish_animation()
	_tween = create_tween()
	if command == &"attack" or command == &"skill" or command == &"uncontrolled":
		var direction: float = 1.0 if unit.is_player else -1.0
		_tween.tween_property(self, "position", _rest_position + Vector2(20.0 * direction, -6.0), duration * 0.4)
		_tween.tween_property(self, "position", _rest_position, duration * 0.6)
	else:
		_tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.5), duration * 0.4)
		_tween.tween_property(self, "modulate", Color.WHITE, duration * 0.6)


func finish_animation() -> void:
	finish_hit()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	position = _rest_position
	modulate = Color.WHITE


func _draw() -> void:
	if unit == null:
		return
	draw_set_transform(_hit_offset)
	var shadow: Rect2 = Rect2(_art_rect.position.x - 4, -4, _art_rect.size.x + 8, 8) if art_texture != null else Rect2(-36, -4, 72, 12)
	if art_texture != null:
		var ellipse: PackedVector2Array = []
		for point: int in range(24):
			var angle: float = TAU * point / 24.0
			ellipse.append(shadow.get_center() + Vector2(cos(angle) * shadow.size.x / 2.0, sin(angle) * shadow.size.y / 2.0))
		draw_colored_polygon(ellipse, Color(0.02, 0.03, 0.04, 0.3))
	else:
		draw_rect(shadow, Color(0.02, 0.03, 0.04, 0.55))
	var body: Color = unit.definition.body_color if unit.is_alive() else Color(0.24, 0.26, 0.29)
	if art_texture != null:
		draw_texture_rect(art_texture, Rect2(-24, -48, 48, 48), false, _hit_tint if unit.is_alive() else Color(0.4, 0.4, 0.4) * _hit_tint)
	else:
		draw_rect(Rect2(-24, -48, 48, 48), body)
		draw_rect(Rect2(-16, -38, 32, 8), body.lightened(0.22))
		draw_rect(Rect2(-12, -18, 24, 12), body.darkened(0.2))
	if unit.breakthrough_multiplier > 1.0:
		draw_rect(Rect2(-6, -62, 12, 8), Color(0.4, 0.86, 0.93))
	if active and unit.is_alive():
		draw_rect(_art_rect.grow(3), Color(0.94, 0.82, 0.48), false, 1.0 if art_texture != null else 2.0)
	if selected and unit.is_alive():
		if art_texture != null:
			var frame: Rect2 = _art_rect.grow(5)
			for corner: Vector2 in [frame.position, Vector2(frame.end.x - 3, frame.position.y), Vector2(frame.position.x, frame.end.y - 3), frame.end - Vector2(3, 3)]:
				draw_rect(Rect2(corner, Vector2(3, 3)), Color(0.92, 0.64, 0.35))
		else:
			for corner: Vector2 in [Vector2(-36, -60), Vector2(28, -60), Vector2(-36, 4), Vector2(28, 4)]:
				draw_rect(Rect2(corner, Vector2(8, 8)), Color(0.89, 0.58, 0.45))
	if not unit.is_alive():
		draw_line(Vector2(-16, -40), Vector2(16, -8), Color(0.7, 0.7, 0.7), 3.0)
		draw_line(Vector2(16, -40), Vector2(-16, -8), Color(0.7, 0.7, 0.7), 3.0)
