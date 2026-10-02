extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]

var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _main: Control
var _room: Node2D
var _player: CharacterBody2D
var _camera: Camera2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = MAIN_SCENE.instantiate()
	root.add_child(_main)
	_room = _main.get_node("WorldContainer/WorldViewport/AcademyGraybox")
	_player = _room.get_node("Actors/Player")
	_camera = _room.get_node("FollowCamera")
	await _frames(4)
	var world: SubViewport = _main.get_node("WorldContainer/WorldViewport")
	var container: SubViewportContainer = _main.get_node("WorldContainer")
	var ui: Control = _main.get_node("UI/LogicalUI")
	_expect(world.size == Vector2i(960, 540), "World viewport is fixed at 960x540")
	_expect(world.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST, "World uses nearest filtering")
	_expect(container.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "World texture is presented with nearest filtering")
	_expect(world.snap_2d_transforms_to_pixel and world.snap_2d_vertices_to_pixel, "World transform and vertex pixel snapping enabled")
	_expect(ui.size == Vector2(1920, 1080) and ui.scale == Vector2(0.5, 0.5), "UI has its own 1920x1080 coordinate space")
	_expect(root.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER, "Window uses integer scaling")
	_expect(_player.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "Player uses top-down physics")
	_expect(_player.get_node("CollisionShape2D").shape.size == Vector2(48, 48), "Player collision matches the 48x48 greybox")
	_check_input_map()
	_check_unique_shapes()

	var directions: Dictionary = {
		&"move_left": Vector2.LEFT,
		&"move_right": Vector2.RIGHT,
		&"move_up": Vector2.UP,
		&"move_down": Vector2.DOWN,
	}
	for action: StringName in directions:
		await _place(Vector2(288, 816))
		var start := _player.position
		await _move(action, 60)
		var displacement := _player.position - start
		var expected: Vector2 = directions[action] * 192.0
		_expect(displacement.distance_to(expected) < 6.5, "%s: actual movement matches 192px/sec (%s)" % [action, displacement])
		_expect(_camera.position == _player.position.round(), "%s: camera follows rounded player position" % action)

	await _place(Vector2(288, 816))
	var diagonal_start := _player.position
	Input.action_press("move_right")
	Input.action_press("move_up")
	await _frames(60)
	_release_movement()
	await _frames(2)
	var diagonal_delta := _player.position - diagonal_start
	_expect(is_zero_approx(diagonal_delta.x) or is_zero_approx(diagonal_delta.y), "Two keys preserve cardinal movement")
	_expect(absf(diagonal_delta.length() - 192.0) < 6.5, "Two keys do not increase movement speed")

	await _check_stop(Vector2(160, 960), &"move_left", 0, 72.0, "West boundary")
	await _check_stop(Vector2(1800, 1008), &"move_right", 0, 1848.0, "East boundary")
	await _check_stop(Vector2(192, 160), &"move_up", 1, 96.0, "North boundary")
	await _check_stop(Vector2(288, 1020), &"move_down", 1, 1104.0, "South boundary")
	await _check_stop(Vector2(480, 696), &"move_right", 0, 552.0, "Planter west face")
	await _check_stop(Vector2(960, 696), &"move_left", 0, 888.0, "Planter east face")
	await _check_stop(Vector2(720, 600), &"move_down", 1, 648.0, "Planter north face")
	await _check_stop(Vector2(720, 864), &"move_up", 1, 792.0, "Planter south face")

	await _place(Vector2(960, 864))
	await _move(&"move_right", 30)
	_expect(_camera.get_screen_center_position().distance_to(_player.position.round()) < 0.1, "Camera centers on player away from map edges")
	await _tap_key(KEY_R)
	_expect(_player.position.distance_to(Vector2(288, 768)) < 0.1, "R key resets player to scene spawn")
	await _tap_key(KEY_F3)
	_expect(not _main.get_node("UI/LogicalUI/Diagnostics").visible and not _room.get("debug_visible"), "F3 hides diagnostics and grid")
	await _tap_key(KEY_F3)
	_expect(_main.get_node("UI/LogicalUI/Diagnostics").visible and _room.get("debug_visible"), "F3 restores diagnostics and grid")

	var report := {
		"stage": "M0",
		"engine": Engine.get_version_info().string,
		"checks": _checks,
		"passed": _failures.is_empty(),
		"failures": _failures,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.dev"))
	var report_file := FileAccess.open("res://.dev/m0-smoke-report.json", FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	report_file.close()
	print("[M0 SMOKE] %d/%d checks passed" % [_checks.size() - _failures.size(), _checks.size()])
	_main.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)


func _check_input_map() -> void:
	var keys: Dictionary = {
		&"move_left": [KEY_A, KEY_LEFT], &"move_right": [KEY_D, KEY_RIGHT],
		&"move_up": [KEY_W, KEY_UP], &"move_down": [KEY_S, KEY_DOWN],
	}
	for action: StringName in keys:
		var actual: Array[int] = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				actual.append(event.physical_keycode)
		_expect(actual.has(keys[action][0]) and actual.has(keys[action][1]), "%s: WASD and arrow key bindings exist" % action)


func _check_unique_shapes() -> void:
	var shape_ids: Array[int] = []
	for block in _room.get_node("Blockers").get_children():
		var shape: RectangleShape2D = block.get_node("CollisionShape2D").shape
		_expect(shape.size == block.get("block_size"), "%s: visual size matches collision" % block.name)
		shape_ids.append(shape.get_instance_id())
	var unique: Dictionary = {}
	for shape_id in shape_ids:
		unique[shape_id] = true
	_expect(unique.size() == shape_ids.size(), "Obstacle instances do not share mutable shapes")


func _check_stop(start: Vector2, action: StringName, axis: int, expected: float, label: String) -> void:
	await _place(start)
	await _move(action, 100)
	_expect(absf(_player.position[axis] - expected) < 0.2, "%s: collision stops at %.0f (actual %.3f)" % [label, expected, _player.position[axis]])
	var center := _camera.get_screen_center_position()
	_expect(center.x >= 479.9 and center.x <= 1440.1 and center.y >= 269.9 and center.y <= 882.1, "%s: camera remains inside map bounds" % label)


func _place(position_value: Vector2) -> void:
	_release_movement()
	_player.position = position_value
	_player.velocity = Vector2.ZERO
	_player.reset_physics_interpolation()
	await _frames(3)


func _move(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	await _frames(2)


func _release_movement() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _tap_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)


func _frames(count: int) -> void:
	for _index in range(count):
		await physics_frame
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks.append({"passed": condition, "description": message})
	if not condition:
		_failures.append(message)
		push_error("[M0 SMOKE] " + message)
