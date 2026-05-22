class_name EnemyBase
extends CharacterBody2D

@export var move_speed: float = 80.0
# 污染度
@export var corruption: float = 100

@onready var health: HealthComponent = $HealthComponent
@onready var attack: AttackComponent = $AttackComponent

var _target: Node2D = null

func _ready() -> void:
	add_to_group("enemy")
	health.died.connect(queue_free)
	_target = get_tree().get_first_node_in_group("nexus")

func _physics_process(_delta: float) -> void:
	if _target == null:
		return

	var dist := global_position.distance_to(_target.global_position)

	if dist <= attack.range:
		if attack.can_attack():
			_do_attack(_target)
	else:
		var direction := (_target.global_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()

func _do_attack(target: Node2D) -> void:
	attack.do_attack(target)
