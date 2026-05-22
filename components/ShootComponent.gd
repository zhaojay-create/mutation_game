class_name ShootComponent
extends Node

@export var projectile_scene: PackedScene
@export var cooldown: float = 1.0

var _timer: float = 0.0

func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta

func can_shoot() -> bool:
	return _timer <= 0.0 and projectile_scene != null

func shoot(from: Node2D, target: Node2D) -> void:
	if not can_shoot():
		return
	_timer = cooldown
	var proj := projectile_scene.instantiate()
	from.get_tree().current_scene.add_child(proj)
	proj.global_position = from.global_position
	if proj.has_method("launch"):
		proj.launch(target)
