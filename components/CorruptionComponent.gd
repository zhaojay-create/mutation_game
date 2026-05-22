class_name CorruptionComponent
extends Node

@export var max_corruption: float = 100.0
@export var corruption_per_enemy: float = 10.0

var current_corruption: float = 0.0

# 污染变化信号
signal corruption_changed(current: float, maximum: float)
# 全部污染信号
signal fully_corrupted()

func add_corruption(amount: float = -1.0) -> void:
	var value := corruption_per_enemy if amount < 0.0 else amount
	current_corruption = min(current_corruption + value, max_corruption)
	corruption_changed.emit(current_corruption, max_corruption)
	if current_corruption >= max_corruption:
		fully_corrupted.emit()

func get_ratio() -> float:
	return current_corruption / max_corruption
