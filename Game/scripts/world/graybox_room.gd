extends Node2D

@export var world_size: Vector2i = Vector2i(1920, 1152)
@export var grid_size: int = 48

var debug_visible: bool = true

@onready var player: CharacterBody2D = $Actors/Player
@onready var camera: Camera2D = $FollowCamera
@onready var spawn: Marker2D = $PlayerSpawn


func reset_player() -> void:
	player.position = spawn.position
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()
	camera.position = player.position.round()
	camera.force_update_scroll()


func set_debug_visible(value: bool) -> void:
	debug_visible = value
	player.call("set_debug_visible", value)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(world_size)), Color("242e3b"))
	draw_rect(Rect2(48, 600, 1824, 240), Color("303c49"))
	draw_rect(Rect2(432, 48, 192, 1056), Color("303c49"))
	if not debug_visible:
		return
	for x in range(0, world_size.x + 1, grid_size):
		var line_color := Color(0.65, 0.72, 0.78, 0.09)
		if x % (grid_size * 5) == 0:
			line_color.a = 0.20
		draw_line(Vector2(x, 0), Vector2(x, world_size.y), line_color)
	for y in range(0, world_size.y + 1, grid_size):
		var line_color := Color(0.65, 0.72, 0.78, 0.09)
		if y % (grid_size * 5) == 0:
			line_color.a = 0.20
		draw_line(Vector2(0, y), Vector2(world_size.x, y), line_color)
	# Markers are debug geometry, not gameplay triggers.
	draw_rect(Rect2(264, 720, 48, 48), Color(0.4, 0.8, 0.65, 0.15))
	draw_rect(Rect2(264, 720, 48, 48), Color("73bcad"), false)
