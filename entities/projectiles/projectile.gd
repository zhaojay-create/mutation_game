class_name Projectile
extends Area2D

@export var speed: float = 200.0

@export var damage: float = 10.0

var _target: Node2D = null

func launch(target: Node2D) -> void:
	_target = target

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	var dir := (_target.global_position - global_position).normalized()
	global_position += dir * speed * delta
	if global_position.distance_to(_target.global_position) < 8.0:
		_on_hit()

func _on_hit() -> void:
	if _target.has_node("HealthComponent"):
		_target.get_node("HealthComponent").take_damage(damage)
	queue_free()
