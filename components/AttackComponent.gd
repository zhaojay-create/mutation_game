class_name AttackComponent
extends Node

@export var damage: float = 10.0
@export var range: float = 150.0
# 它的用途是让外部（植物/动物/敌人）读取这个值来判断目标是否在攻击距离内，组件本身不做距离检测，因为距离检测需要知道自己和目标的世界坐标，那是父节点的事。
# 用法示意（在 AnimalBase / EnemyBase 的 _physics_process 里）：
# gdscript
# var dist := global_position.distance_to(_target.global_position)
# if dist <= attack.range and attack.can_attack():
#     attack.do_attack(_target)
# 所以 range 是数据放在组件里统一管理（方便变异时 attack.range *= 1.2），但逻辑在使用者那边。
@export var cooldown: float = 1.0

var on_hit_tags: Array[String] = []
var _timer: float = 0.0

signal attack_executed(target: Node)

func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta

func can_attack() -> bool:
	return _timer <= 0.0

func do_attack(target: Node) -> void:
	if not can_attack():
		return
	_timer = cooldown
	if target.has_node("HealthComponent"):
		target.get_node("HealthComponent").take_damage(damage)
	if not on_hit_tags.is_empty() and target.has_node("StatusComponent"):
		target.get_node("StatusComponent").apply_tags(on_hit_tags)
	attack_executed.emit(target)

func reset_cooldown() -> void:
	_timer = 0.0
