class_name PlantBase
extends PlaceableBase

@onready var shooter: ShootComponent = $ShootComponent
@onready var detection: Area2D = $DetectionArea

var _target: Node2D = null

func _ready() -> void:
	super._ready()
	detection.body_entered.connect(_on_body_entered)
	detection.body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_target = null
		return
	if shooter.can_shoot():
		shooter.shoot(self, _target)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and _target == null:
		_target = body

func _on_body_exited(body: Node2D) -> void:
	if body == _target:
		_target = null
