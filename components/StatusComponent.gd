class_name StatusComponent
extends Node

const BURN_DPS: float = 5.0
const BURN_DURATION: float = 3.0
const FREEZE_SLOW: float = 0.5
const FREEZE_DURATION: float = 2.0

var _burn_timer: float = 0.0
var _freeze_timer: float = 0.0

var speed_multiplier: float = 1.0

signal burn_started()
signal burn_ended()
signal freeze_started()
signal freeze_ended()

func _process(delta: float) -> void:
	_tick_burn(delta)
	_tick_freeze(delta)

func apply_tags(tags: Array[String]) -> void:
	for tag in tags:
		match tag:
			"burn":   _apply_burn()
			"freeze": _apply_freeze()

func _apply_burn() -> void:
	var was_burning := _burn_timer > 0.0
	_burn_timer = BURN_DURATION
	if not was_burning:
		burn_started.emit()

func _apply_freeze() -> void:
	var was_frozen := _freeze_timer > 0.0
	_freeze_timer = FREEZE_DURATION
	speed_multiplier = FREEZE_SLOW
	if not was_frozen:
		freeze_started.emit()

func _tick_burn(delta: float) -> void:
	if _burn_timer <= 0.0:
		return
	_burn_timer -= delta
	if owner.has_node("HealthComponent"):
		owner.get_node("HealthComponent").take_damage(BURN_DPS * delta)
	if _burn_timer <= 0.0:
		burn_ended.emit()

func _tick_freeze(delta: float) -> void:
	if _freeze_timer <= 0.0:
		return
	_freeze_timer -= delta
	if _freeze_timer <= 0.0:
		speed_multiplier = 1.0
		freeze_ended.emit()

func is_burning() -> bool:
	return _burn_timer > 0.0

func is_frozen() -> bool:
	return _freeze_timer > 0.0
