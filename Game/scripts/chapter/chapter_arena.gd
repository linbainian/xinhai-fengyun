extends Node2D

var tiles: Array[Texture2D] = []
var _guide: Sprite2D


func _ready() -> void:
	for index: int in range(16):
		tiles.append(load("res://assets/chapter1/terrain/tile_%02d.png" % index) as Texture2D)
	var guide: Sprite2D = Sprite2D.new()
	_guide = guide
	guide.texture = load("res://assets/chapter1/refined/npcs/frames/frame_001.png") as Texture2D
	guide.position = Vector2(125, 166)
	guide.scale = Vector2(96, 96) / Vector2(guide.texture.get_size())
	guide.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(guide)
	get_viewport().size_changed.connect(_resize_field)
	_resize_field()


func _resize_field() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_guide.position = (Vector2(125, 166) * viewport_size / Vector2(960, 540)).round()
	queue_redraw()


func _draw() -> void:
	if tiles.size() != 16: return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	for y: int in range(ceili(viewport_size.y / 48.0)):
		for x: int in range(ceili(viewport_size.x / 48.0)):
			var family: int = 3 if y * 48.0 >= viewport_size.y * 0.35 and y * 48.0 < viewport_size.y * 0.8 else 2
			draw_texture(tiles[family * 4 + (x + y) % 4], Vector2(x * 48, y * 48), Color(0.72, 0.76, 0.72))
