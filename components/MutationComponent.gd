class_name MutationComponent
extends Node

enum SoilType {
	NORMAL,
	FIRE,
	ICE,
}

var soil_type: SoilType = SoilType.NORMAL
var active_tags: Array[String] = []

signal mutated(soil_type: SoilType, tags: Array)

const SOIL_TAGS: Dictionary = {
	SoilType.NORMAL: [],
	SoilType.FIRE:   ["burn"],
	SoilType.ICE:    ["freeze"],
}

func apply_mutation(new_soil_type: SoilType) -> void:
	soil_type = new_soil_type
	var raw: Array = SOIL_TAGS.get(soil_type, [])
	active_tags.assign(raw)
	mutated.emit(soil_type, active_tags)

func clear_mutation() -> void:
	soil_type = SoilType.NORMAL
	active_tags.clear()
	mutated.emit(soil_type, active_tags)

func has_tag(tag: String) -> bool:
	return tag in active_tags
