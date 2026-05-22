class_name PlaceableBase
extends StaticBody2D

@onready var health: HealthComponent = $HealthComponent

signal destroyed()

func _ready() -> void:
	health.died.connect(func(): destroyed.emit(); queue_free())

func on_placed(_soil_type: int) -> void:
	pass
