extends Control

@onready var room: Node2D = $WorldContainer/WorldViewport/AcademyGraybox
@onready var player: CharacterBody2D = room.get_node("Actors/Player")
@onready var world_viewport: SubViewport = $WorldContainer/WorldViewport
@onready var diagnostics: Label = $UI/LogicalUI/Diagnostics/Margin/Readout
@onready var diagnostics_panel: PanelContainer = $UI/LogicalUI/Diagnostics

var debug_visible: bool = true
var _readout_elapsed: float = 0.0


func _ready() -> void:
	_update_readout()
	print("[M0] Ready | world=960x540 | UI=1920x1080 | grid=48 | four-direction movement")


func _process(delta: float) -> void:
	_readout_elapsed += delta
	if debug_visible and _readout_elapsed >= 0.1:
		_readout_elapsed = 0.0
		_update_readout()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_position"):
		room.call("reset_player")
	elif event.is_action_pressed("toggle_debug"):
		debug_visible = not debug_visible
		diagnostics_panel.visible = debug_visible
		room.call("set_debug_visible", debug_visible)
	elif event.is_action_pressed("toggle_fullscreen"):
		var window := get_window()
		if window.mode == Window.MODE_FULLSCREEN:
			window.mode = Window.MODE_WINDOWED
		else:
			window.mode = Window.MODE_FULLSCREEN
	else:
		return
	get_viewport().set_input_as_handled()


func _update_readout() -> void:
	var display_scale := get_viewport().get_final_transform().get_scale().x
	diagnostics.text = (
		"M0  工程诊断\n"
		+ "世界  %d × %d  ·  nearest\n" % [world_viewport.size.x, world_viewport.size.y]
		+ "UI  1920 × 1080  ·  独立层\n"
		+ "世界放大  ×%.0f  ·  像素吸附\n" % display_scale
		+ "网格 / 角色  48 × 48\n"
		+ "位置  (%.0f, %.0f)\n" % [player.position.x, player.position.y]
		+ "运动  (%.0f, %.0f)\n" % [player.velocity.x, player.velocity.y]
		+ "碰撞  World → Player"
	)
