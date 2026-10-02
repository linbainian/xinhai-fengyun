extends Node2D


func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0.035, 0.047, 0.055))
	draw_rect(Rect2(24, 100, 912, 228), Color(0.11, 0.17, 0.14))
	for x: int in range(24, 937, 48):
		draw_line(Vector2(x, 100), Vector2(x, 328), Color(0.18, 0.24, 0.18), 1.0)
	for y: int in range(100, 329, 48):
		draw_line(Vector2(24, y), Vector2(936, y), Color(0.18, 0.24, 0.18), 1.0)
	# The guide stays at the entrance and has no battle state or turn.
	draw_rect(Rect2(264, 116, 28, 28), Color(0.54, 0.76, 0.86))
	draw_rect(Rect2(270, 108, 16, 8), Color(0.19, 0.23, 0.27))
	draw_rect(Rect2(294, 132, 6, 10), Color(0.87, 0.80, 0.62))
	draw_line(Vector2(260, 148), Vector2(302, 148), Color(0.40, 0.50, 0.45), 2.0)
	for x: int in range(362, 594, 24):
		draw_rect(Rect2(x, 302, 4, 6), Color(0.26, 0.39, 0.25))
