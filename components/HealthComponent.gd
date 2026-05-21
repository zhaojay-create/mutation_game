class_name HealthComponent
extends Node

@export var max_hp: float = 100.0

var current_hp: float

signal damaged(amount: float)
signal healed(amount: float)
signal died()
signal hp_changed(current: float, maximum: float)

func _ready() -> void:
	current_hp = max_hp

func take_damage(amount: float) -> void:
	current_hp = maxf(current_hp - amount, 0.0)
	damaged.emit(amount)
	hp_changed.emit(current_hp, max_hp)
	if current_hp == 0.0:
		died.emit()

func heal(amount: float) -> void:
	current_hp = minf(current_hp + amount, max_hp)
	healed.emit(amount)
	hp_changed.emit(current_hp, max_hp)

func is_alive() -> bool:
	return current_hp > 0.0
