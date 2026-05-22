class_name Nexus
extends Area2D

@onready var corruption: CorruptionComponent = $CorruptionComponent

func _ready() -> void:
	add_to_group("nexus")
	corruption.corruption_changed.connect(_on_corruption_changed)
	corruption.fully_corrupted.connect(_on_fully_corrupted)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		corruption.add_corruption()

func _on_corruption_changed(_current: float, _maximum: float) -> void:
	modulate = Color.WHITE.lerp(Color(0.2, 0.0, 0.3), corruption.get_ratio())

func _on_fully_corrupted() -> void:
	GameManager.game_over()
