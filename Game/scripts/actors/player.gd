extends CharacterBody2D

@export var move_speed: float = 192.0

var facing: Vector2 = Vector2.DOWN
var debug_visible: bool = true
var _prefer_horizontal: bool = false


func _physics_process(_delta: float) -> void:
	var direction := _read_direction()
	velocity = direction * move_speed
	if direction != Vector2.ZERO and direction != facing:
		facing = direction
		queue_redraw()
	move_and_slide()


func _read_direction() -> Vector2:
	var horizontal := Input.get_axis("move_left", "move_right")
	var vertical := Input.get_axis("move_up", "move_down")
	if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
		_prefer_horizontal = true
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
		_prefer_horizontal = false
	if horizontal != 0.0 and vertical != 0.0:
		if _prefer_horizontal:
			return Vector2(signf(horizontal), 0.0)
		return Vector2(0.0, signf(vertical))
	return Vector2(signf(horizontal), signf(vertical))


func set_debug_visible(value: bool) -> void:
	debug_visible = value
	queue_redraw()


func _draw() -> void:
	# Deliberately simple M0 geometry; replace with a 48px sprite in M1.5.
	draw_rect(Rect2(-24, -48, 48, 48), Color("73bcad"))
	draw_rect(Rect2(-20, -44, 40, 40), Color("405f60"))
	var facing_marker := Vector2(-4, -28) + facing * 14.0
	draw_rect(Rect2(facing_marker, Vector2(8, 8)), Color("eff4ea"))
	if debug_visible:
		draw_rect(Rect2(-24, -48, 48, 48), Color("c9eedc"), false, 1.0)
		draw_line(Vector2(-6, 0), Vector2(6, 0), Color("eff4ea"), 1.0)
		draw_line(Vector2(0, -4), Vector2(0, 4), Color("eff4ea"), 1.0)
