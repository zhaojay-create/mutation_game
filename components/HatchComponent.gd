class_name HatchComponent
extends Node

@export var hatch_time: float = 5.0
@export var default_scene: PackedScene
@export var hatch_scenes: Dictionary = {}

var _soil_type: String = "normal"
var _timer: float = 0.0
var _hatching: bool = false

signal hatched(instance: Node)

func start_hatch(soil_type: String) -> void:
	_soil_type = soil_type
	_timer = hatch_time
	_hatching = true

func _process(delta: float) -> void:
	if not _hatching:
		return
	_timer -= delta
	if _timer <= 0.0:
		_hatching = false
		_on_hatch_complete()

func get_progress() -> float:
	if not _hatching:
		return 0.0
	return 1.0 - (_timer / hatch_time)

func _on_hatch_complete() -> void:
	var scene: PackedScene = hatch_scenes.get(_soil_type, default_scene)
	if scene == null:
		return
	var instance := scene.instantiate()
	get_tree().current_scene.add_child(instance)
	instance.global_position = owner.global_position
	hatched.emit(instance)
	owner.queue_free()
