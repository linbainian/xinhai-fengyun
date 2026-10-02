class_name ChapterPlayer
extends "res://scripts/actors/player.gd"

var blocked: bool = true
var animation_clock: float = 0.0
var frames: Array[Texture2D] = []
var resting: bool = false
var rest_texture: Texture2D
var scripted_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	debug_visible = false
	rest_texture = load("res://assets/chapter1/refined/lin_da/rest.png") as Texture2D
	for index: int in range(16):
		var path: String = "res://assets/chapter1/refined/lin_da/frames/frame_%03d.png" % index
		if ResourceLoader.exists(path):
			frames.append(load(path) as Texture2D)


func _physics_process(delta: float) -> void:
	if blocked:
		velocity = Vector2.ZERO
	else:
		super._physics_process(delta)
		if velocity != Vector2.ZERO: resting = false
	animation_clock += delta if velocity != Vector2.ZERO or scripted_velocity != Vector2.ZERO else 0.0
	queue_redraw()


func _draw() -> void:
	if frames.size() != 16:
		return
	if resting and rest_texture != null:
		draw_texture_rect(rest_texture, Rect2(-24, -48, 48, 48), false)
		return
	var row: int = 0
	if facing == Vector2.LEFT:
		row = 1
	elif facing == Vector2.RIGHT:
		row = 2
	elif facing == Vector2.UP:
		row = 3
	var frame: int = int(animation_clock * 8.0) % 4 if velocity != Vector2.ZERO or scripted_velocity != Vector2.ZERO else 0
	draw_texture_rect(frames[row * 4 + frame], Rect2(-24, -48, 48, 48), false)
