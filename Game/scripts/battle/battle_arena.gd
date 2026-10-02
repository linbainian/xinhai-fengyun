extends Node2D


func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0.035, 0.047, 0.063))
	draw_rect(Rect2(24, 100, 912, 228), Color(0.10, 0.14, 0.18))
	for x: int in range(24, 937, 48):
		draw_line(Vector2(x, 100), Vector2(x, 328), Color(0.16, 0.20, 0.23), 1.0)
	for y: int in range(100, 329, 48):
		draw_line(Vector2(24, y), Vector2(936, y), Color(0.16, 0.20, 0.23), 1.0)
	draw_rect(Rect2(264, 284, 80, 12), Color(0.20, 0.35, 0.34))
	draw_rect(Rect2(616, 284, 80, 12), Color(0.37, 0.25, 0.25))
	draw_line(Vector2(480, 126), Vector2(480, 304), Color(0.24, 0.28, 0.3), 2.0)
