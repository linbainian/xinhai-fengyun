class_name ChapterMap
extends Node2D

const CELL: int = 48
var definition: Dictionary = {}
var interactions: Array[Dictionary] = []
var tiles: Array[Texture2D] = []
var actors: Node2D
var player: ChapterPlayer
var camera: Camera2D
var props: Array[Sprite2D] = []
var ground: TileMapLayer
var background_props: Node2D
var ground_props: Node2D
var foreground_props: Node2D
var _test_sprite: Sprite2D
var _test_age: float = 0.0
var dialogue_framing: bool = false
var cinematic_camera: bool = false
var cinematic_focus: Vector2 = Vector2.ZERO
var follow_enabled: bool = false
var _trail: Array[Vector2] = []


func _ready() -> void:
	for index: int in range(16):
		var path: String = "res://assets/chapter1/terrain/tile_%02d.png" % index
		if ResourceLoader.exists(path):
			tiles.append(load(path) as Texture2D)
	for index: int in range(6):
		tiles.append(load("res://assets/chapter1/refined/hall_v2/tile_%02d.png" % index) as Texture2D)
	for index: int in range(6):
		var path: String = "res://assets/chapter2/terrain/tile_%02d.png" % index
		if ResourceLoader.exists(path): tiles.append(load(path) as Texture2D)
	ground = TileMapLayer.new()
	ground.name = "Ground"
	ground.z_index = -20
	ground.tile_set = TileSet.new()
	ground.tile_set.tile_size = Vector2i(CELL, CELL)
	for index: int in range(tiles.size()):
		var source: TileSetAtlasSource = TileSetAtlasSource.new()
		source.texture = tiles[index]
		source.texture_region_size = Vector2i(CELL, CELL)
		source.create_tile(Vector2i.ZERO)
		ground.tile_set.add_source(source, index)
	add_child(ground)
	background_props = Node2D.new()
	background_props.name = "Architecture"
	background_props.z_index = -10
	add_child(background_props)
	ground_props = Node2D.new()
	ground_props.name = "WalkableProps"
	add_child(ground_props)
	actors = Node2D.new()
	actors.name = "ActorsAndProps"
	actors.y_sort_enabled = true
	add_child(actors)
	foreground_props = Node2D.new()
	foreground_props.name = "Foreground"
	foreground_props.z_index = 10
	add_child(foreground_props)
	player = ChapterPlayer.new()
	player.name = "Player"
	player.collision_layer = 2
	player.collision_mask = 1
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(18, 12)
	shape.shape = rectangle
	shape.position = Vector2(0, -5)
	player.add_child(shape)
	actors.add_child(player)
	camera = Camera2D.new()
	camera.zoom = Vector2(2.0, 2.0)
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()


func load_room(data: Dictionary) -> void:
	if is_instance_valid(_test_sprite): _test_sprite.free()
	definition = data.duplicate(true)
	interactions.clear()
	props.clear()
	for layer: Node2D in [background_props, ground_props, foreground_props]:
		for child: Node in layer.get_children(): child.free()
	for child: Node in actors.get_children():
		if child != player:
			child.free()
	for child: Node in get_children():
		if child is StaticBody2D:
			child.free()
	var width: int = int(data.get("width", 30)) * CELL
	var height: int = int(data.get("height", 18)) * CELL
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = width
	camera.limit_bottom = height
	var camera_region: Array = data.get("cameraRegion",[])
	if camera_region.size()==4:
		camera.limit_left=int(camera_region[0])
		camera.limit_top=int(camera_region[1])
		camera.limit_right=int(camera_region[0]+camera_region[2])
		camera.limit_bottom=int(camera_region[1]+camera_region[3])
	_blocker(Rect2(0, 0, width, 24))
	_blocker(Rect2(0, height - 24, width, 24))
	_blocker(Rect2(0, 0, 24, height))
	_blocker(Rect2(width - 24, 0, 24, height))
	for values: Array in data.get("blockers",[]):
		_blocker(Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3])))
	for entry: Dictionary in data.get("props", []):
		var sprite: Sprite2D = _sprite(entry)
		if sprite != null:
			props.append(sprite)
		if entry.has("collision"):
			var values: Array = entry.collision
			_blocker(Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3])))
	for entry: Dictionary in data.get("actors", []):
		_sprite(entry)
		interactions.append(entry.duplicate(true))
		if entry.has("collision"):
			var values: Array = entry.collision
			_blocker(Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3])))
	var spawn: Array = data.get("spawn", [720, 660])
	player.position = Vector2(float(spawn[0]), float(spawn[1]))
	player.facing = Vector2.UP
	camera.position = (player.position + _camera_offset()).round()
	_paint_tiles()
	player.resting = false
	player.scripted_velocity = Vector2.ZERO
	_trail.clear()


func add_visitor(visitor_name: String, index: int, point: Vector2) -> Sprite2D:
	var existing: Node = actors.get_node_or_null(NodePath(visitor_name))
	if existing != null: existing.free()
	var names: Array[String] = ["wen_rang", "su_wanyan", "liu", "shen", "wen", "tang"]
	return _sprite({"id": "wen_rang" if index == 0 else visitor_name, "character": names[index] if index < 6 else "",
		"nodeName": visitor_name, "asset": "res://assets/chapter1/refined/npcs/frames/frame_%03d.png" % index,
		"position": [point.x, point.y], "size": [48, 48]})


func present_test_release(affinity: String) -> void:
	if is_instance_valid(_test_sprite): _test_sprite.free()
	_test_age = 0.0
	_test_sprite = Sprite2D.new()
	_test_sprite.name = "EntranceTestRelease"
	_test_sprite.position = player.position + Vector2(0, -24)
	_test_sprite.scale = Vector2(0.8, 0.8)
	_test_sprite.z_index = 20
	_test_sprite.texture = load("res://assets/chapter1/refined/fx/frames/frame_016.png") as Texture2D
	_test_sprite.modulate = {"念动力": Color(0.56, 1.0, 0.72), "元素": Color(0.55, 0.9, 1.0),
		"强化": Color(1.0, 0.62, 0.38), "精神": Color(0.85, 0.6, 1.0), "特殊": Color(1.0, 0.86, 0.5)}.get(affinity, Color.WHITE)
	add_child(_test_sprite)


func _sprite(entry: Dictionary) -> Sprite2D:
	var path: String = String(entry.get("asset", ""))
	if not ResourceLoader.exists(path):
		return null
	var sprite: Sprite2D = ChapterActor.new() if entry.has("character") else Sprite2D.new()
	sprite.texture = load(path) as Texture2D
	sprite.name = String(entry.get("nodeName", "Prop"))
	sprite.centered = false
	var target: Array = entry.get("size", [48, 48])
	var dimensions: Vector2 = Vector2(float(target[0]), float(target[1]))
	sprite.scale = dimensions / Vector2(sprite.texture.get_size())
	sprite.offset = Vector2(-sprite.texture.get_width() / 2.0, -sprite.texture.get_height())
	var anchor: Array = entry.get("anchor", [])
	if anchor.size() == 2:
		sprite.offset = -Vector2(float(anchor[0]), float(anchor[1]))
	var point: Array = entry.get("position", [720, 400])
	sprite.position = Vector2(float(point[0]), float(point[1]))
	sprite.set_meta("occlusion", entry.get("occlusionClass", "low"))
	sprite.set_meta("occupant_policy", entry.get("occupantPolicy", {"mode": "fade", "alpha": 0.45}))
	sprite.set_meta("actor_safe_area", entry.get("actorSafeArea", []))
	var layer: String = String(entry.get("renderLayer", "actors"))
	var parent: Node2D = {"background": background_props, "ground": ground_props, "foreground": foreground_props}.get(layer, actors)
	parent.add_child(sprite)
	if entry.has("materialShader"):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = load(String(entry.materialShader)) as Shader
		sprite.material = material
	if entry.has("modulate"): sprite.modulate = Color(String(entry.modulate))
	sprite.set_meta("actor_id", String(entry.get("id", sprite.name)))
	if sprite is ChapterActor: (sprite as ChapterActor).set_character(String(entry.character), String(entry.get("characterFolder", "res://assets/chapter1/cinematics")))
	if sprite is ChapterActor and entry.has("face"):
		(sprite as ChapterActor).facing = Vector2(float(entry.face[0]), float(entry.face[1]))
	sprite.visible = not bool(entry.get("hidden", false))
	return sprite


func actor_for(id: String) -> Node2D:
	if id == "player": return player
	for child: Node in actors.get_children():
		if String(child.get_meta("actor_id", "")) == id or String(child.name) == id: return child as Node2D
	return null


func object_for(id: String) -> Node2D:
	var actor: Node2D = actor_for(id)
	if actor != null: return actor
	for sprite: Sprite2D in props:
		if String(sprite.get_meta("actor_id",""))==id or String(sprite.name)==id: return sprite
	return null


func reset_follow() -> void:
	_trail.clear()
	follow_enabled = actor_for("wen_rang") != null


func _follow(delta: float) -> void:
	var companion: ChapterActor = actor_for("wen_rang") as ChapterActor
	if companion == null or not follow_enabled or player.blocked or cinematic_camera:
		if companion != null: companion.walking = false
		return
	if _trail.is_empty() or _trail.back().distance_to(player.position) >= 10: _trail.append(player.position)
	if _trail.size() > 5:
		var direction: Vector2 = _trail[0] - companion.position
		var previous: Vector2 = companion.position
		var step: float = player.move_speed * delta
		var next: Vector2 = previous.move_toward(_trail[0], step)
		if not can_stand(next):
			# Keep the follower's feet out of a corner when two trail samples bend.
			var horizontal: Vector2 = previous.move_toward(Vector2(_trail[0].x, previous.y), step)
			var vertical: Vector2 = previous.move_toward(Vector2(previous.x, _trail[0].y), step)
			next = horizontal if can_stand(horizontal) and absf(direction.x) > 0.1 else vertical if can_stand(vertical) else previous
		companion.position = next
		companion.set_motion(next-previous, next != previous)
		if companion.position.distance_to(_trail[0]) < 2: _trail.pop_front()
	else: companion.walking = false
	for entry: Dictionary in interactions:
		if entry.id == "wen_rang": entry.position = [companion.position.x,companion.position.y]


func _blocker(rect: Rect2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	body.position = rect.get_center()
	body.add_child(collider)
	add_child(body)


func closest_interaction() -> Dictionary:
	var best: Dictionary = {}
	var companion: Dictionary = {}
	var distance: float = 86.0
	for entry: Dictionary in interactions:
		var point: Array = entry.get("interactionPosition",entry.position)
		var candidate: float = player.position.distance_to(Vector2(float(point[0]), float(point[1])))
		if entry.id == "wen_rang" and follow_enabled:
			if candidate < 86.0: companion = entry
			continue
		if candidate < distance:
			distance = candidate
			best = entry
	return companion if best.is_empty() else best


func can_stand(point: Vector2) -> bool:
	var footprint: Rect2 = Rect2(point + Vector2(-9, -11), Vector2(18, 12))
	var interior: Rect2 = Rect2(24, 24, float(definition.width) * CELL - 48, float(definition.height) * CELL - 48)
	if not interior.encloses(footprint): return false
	for values: Array in definition.get("blockers",[]):
		if Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3])).intersects(footprint): return false
	for entry: Dictionary in definition.get("props", []) + definition.get("actors", []):
		if not entry.has("collision"): continue
		var box: Array = entry.collision
		if Rect2(float(box[0]), float(box[1]), float(box[2]), float(box[3])).intersects(footprint): return false
	return true


func _process(_delta: float) -> void:
	if player == null:
		return
	var camera_region: Array = definition.get("cameraRegion",[])
	if camera_region.size()==4:
		# The dialogue covers the lower viewport, so leave room to frame a
		# southern table while keeping the speakers above the dialogue panel.
		var lower_space: float = get_viewport_rect().size.y/(camera.zoom.y*2.0) if dialogue_framing else 0.0
		camera.limit_bottom=int(float(camera_region[1])+float(camera_region[3])+lower_space)
	camera.position = cinematic_focus.round() if cinematic_camera else (player.position + _camera_offset()).round()
	_follow(_delta)
	for entry: Dictionary in interactions:
		var actor: Node2D = actor_for(String(entry.id))
		if actor != null: entry.position = [actor.position.x,actor.position.y]
	if is_instance_valid(_test_sprite):
		_test_age += _delta
		if _test_age >= 0.5:
			_test_sprite.free()
		else:
			_test_sprite.texture = load("res://assets/chapter1/refined/fx/frames/frame_%03d.png" % (16 + mini(3, floori(_test_age * 8.0)))) as Texture2D
	for sprite: Sprite2D in props:
		if String(sprite.get_meta("occlusion", "low")) != "tall":
			continue
		var rect: Rect2 = Rect2(sprite.position + sprite.offset * sprite.scale, sprite.texture.get_size() * sprite.scale)
		var area: Array = sprite.get_meta("actor_safe_area", [])
		if area.size() == 4: rect = Rect2(float(area[0]), float(area[1]), float(area[2]), float(area[3]))
		var policy: Dictionary = sprite.get_meta("occupant_policy", {})
		sprite.modulate.a = float(policy.get("alpha", 0.45)) if String(policy.get("mode", "fade")) == "fade" and rect.has_point(player.position) and player.position.y < sprite.position.y - 12 else 1.0


func _camera_offset() -> Vector2:
	if dialogue_framing:
		var dialogue_offset: Array = definition.get("dialogueOffset",[0,0])
		return Vector2(float(dialogue_offset[0]),float(dialogue_offset[1]))
	var values: Array = definition.get("cameraOffset", [0, 0])
	return Vector2(float(values[0]), float(values[1]))


func _paint_tiles() -> void:
	if tiles.size() < 16 or definition.is_empty():
		return
	ground.clear()
	var family: int = int(definition.get("floor", 0))
	for y: int in range(int(definition.get("height", 18))):
		for x: int in range(int(definition.get("width", 30))):
			var floor_values: Array = definition.get("floorRect",[])
			if floor_values.size()==4:
				var floor_rect: Rect2 = Rect2(float(floor_values[0]),float(floor_values[1]),float(floor_values[2]),float(floor_values[3]))
				if not floor_rect.intersects(Rect2(x*CELL,y*CELL,CELL,CELL)): continue
			var row: int = family
			if family == 2 and (x in range(13, 17) or y in range(12, 15)):
				row = 3
			var source_id: int = row * 4 + (x + y * 3) % 4
			var terrain: Dictionary = definition.get("terrain", {})
			if not terrain.is_empty():
				var variants: Array = terrain.base
				for zone: Dictionary in terrain.get("zones", []):
					var box: Array = zone.rect
					if Rect2i(int(box[0]), int(box[1]), int(box[2]), int(box[3])).has_point(Vector2i(x, y)):
						variants = zone.tiles
				source_id = int(variants[(x + y * 3) % variants.size()])
			ground.set_cell(Vector2i(x, y), source_id, Vector2i.ZERO)
