class_name ChapterDisplay
extends Node

signal layout_changed

const WORLD_REFERENCE: Vector2 = Vector2(960, 540)
const UI_REFERENCE: Vector2 = Vector2(1920, 1080)

var world_scale: int = 1
var world_container: SubViewportContainer
var world_viewport: SubViewport
var logical_ui: Control
var _window: Window


func _ready() -> void:
	var host: Control = get_parent() as Control
	world_container = host.get_node("WorldContainer") as SubViewportContainer
	world_viewport = world_container.get_node("WorldViewport") as SubViewport
	logical_ui = host.get_node("UI/LogicalUI") as Control
	_window = get_window()
	# Render the UI at the window resolution. Only the pixel world is integer-scaled.
	# This runtime override leaves the standalone M0/M1 development scenes unchanged.
	_window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	host.clip_contents = true
	world_container.stretch = true
	world_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	world_viewport.snap_2d_transforms_to_pixel = true
	world_viewport.snap_2d_vertices_to_pixel = true
	_window.size_changed.connect(_refresh_layout)
	_refresh_layout()


func _refresh_layout() -> void:
	var window_size: Vector2 = Vector2(_window.size)
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return
	# Pick the nearest integer so framing stays close to the 960x540 reference.
	# Expand/crop the visible world instead of letterboxing the whole application.
	world_scale = maxi(1, roundi(minf(window_size.x / WORLD_REFERENCE.x, window_size.y / WORLD_REFERENCE.y)))
	var source_size: Vector2i = Vector2i(ceili(window_size.x / world_scale), ceili(window_size.y / world_scale))
	world_container.position = Vector2.ZERO
	world_container.scale = Vector2.ONE * world_scale
	world_container.size = Vector2(source_size)
	var ui_scale: float = minf(window_size.x / UI_REFERENCE.x, window_size.y / UI_REFERENCE.y)
	logical_ui.position = Vector2.ZERO
	logical_ui.scale = Vector2.ONE * ui_scale
	logical_ui.size = window_size / ui_scale
	logical_ui.call("apply_display_layout")
	layout_changed.emit()


func world_to_ui(point: Vector2) -> Vector2:
	var transform: Transform2D = logical_ui.get_global_transform_with_canvas().affine_inverse() * world_container.get_global_transform_with_canvas()
	return transform * point


func _exit_tree() -> void:
	if is_instance_valid(_window) and _window.size_changed.is_connected(_refresh_layout):
		_window.size_changed.disconnect(_refresh_layout)
