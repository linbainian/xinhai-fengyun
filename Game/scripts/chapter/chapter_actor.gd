class_name ChapterActor
extends Sprite2D

var walking: bool = false
var facing: Vector2 = Vector2.DOWN
var walk_frames: Array[Texture2D] = []
var clock: float = 0.0


func set_character(character: String, folder: String = "res://assets/chapter1/cinematics") -> void:
	walk_frames.clear()
	for index: int in range(16):
		var path: String = "%s/%s/frames/frame_%03d.png" % [folder, character, index]
		if ResourceLoader.exists(path): walk_frames.append(load(path) as Texture2D)


func _process(delta: float) -> void:
	if walk_frames.size() != 16: return
	if walking: clock += delta
	var row: int = 0 if facing == Vector2.DOWN else 1 if facing == Vector2.LEFT else 2 if facing == Vector2.RIGHT else 3
	texture = walk_frames[row * 4 + (int(clock * 8.0) % 4 if walking else 0)]


func set_motion(direction: Vector2, moving: bool) -> void:
	walking = moving
	if direction != Vector2.ZERO:
		facing = Vector2(signf(direction.x), 0) if absf(direction.x) > absf(direction.y) else Vector2(0, signf(direction.y))
