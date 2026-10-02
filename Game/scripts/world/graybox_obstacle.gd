extends StaticBody2D

@export var block_size: Vector2 = Vector2(48, 48)
@export var fill_color: Color = Color("586474")


func _ready() -> void:
	# Every instance owns its shape, so resizing one obstacle cannot resize another.
	var shape := RectangleShape2D.new()
	shape.size = block_size
	$CollisionShape2D.shape = shape
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-block_size * 0.5, block_size)
	draw_rect(rect, fill_color)
	draw_rect(rect, Color("a0a8b3"), false, 1.0)
	draw_line(rect.position, rect.position + Vector2(block_size.x, 0), Color("c5cad0"), 2.0)
