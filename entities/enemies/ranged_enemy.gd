class_name RangedEnemy
extends EnemyBase

@export var projectile_scene: PackedScene

# 远程：在攻击范围内停下，发射抛射物
func _do_attack(target: Node2D) -> void:
	attack.do_attack(target)
	if projectile_scene == null:
		return
	var proj := projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position
	if proj.has_method("launch"):
		proj.launch(target)
