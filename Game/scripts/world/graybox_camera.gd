extends Camera2D

@export var target_path: NodePath = NodePath("../Actors/Player")

@onready var target: Node2D = get_node(target_path) as Node2D


func _ready() -> void:
	global_position = target.global_position.round()
	force_update_scroll()


func _physics_process(_delta: float) -> void:
	global_position = target.global_position.round()
