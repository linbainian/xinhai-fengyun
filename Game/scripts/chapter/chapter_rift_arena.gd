extends Node2D

var tiles: Array[Texture2D] = []


func _ready() -> void:
	for index: int in range(3): tiles.append(load("res://assets/chapter2/terrain/tile_%02d.png" % index) as Texture2D)
	get_viewport().size_changed.connect(queue_redraw)


func _draw() -> void:
	if tiles.size() != 3: return
	var area: Vector2 = get_viewport().get_visible_rect().size
	for y: int in range(ceili(area.y / 48.0)):
		for x: int in range(ceili(area.x / 48.0)):
			draw_texture(tiles[(x+y*2)%3],Vector2(x*48,y*48),Color(0.75,0.73,0.88))
