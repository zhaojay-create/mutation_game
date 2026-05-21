extends Node

@onready var hcom := $HealthComponent

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#_test_health()
	#_test_attack()
	_test_mutation()


# ── HealthComponent ──────────────────────────────
func _test_health() -> void:
	hcom.died.connect(func(): print("[Health] ✓ died 触发"))
	hcom.hp_changed.connect(func(cur, max_val): print("[Health] hp_changed: %s / %s" % [cur, max_val]))
 
	hcom.take_damage(30)   # 期望: hp_changed 70/100
	hcom.heal(10)          # 期望: hp_changed 80/100
	hcom.take_damage(999)  # 期望: hp_changed 0/100, died 触发

# ── AttackComponent ──────────────────────────────
func _test_attack() -> void:
	var a := AttackComponent.new()
	add_child(a)
 
	print("[Attack] can_attack (应为 true): ", a.can_attack())
	a._timer = 1.0  # 模拟冷却中
	print("[Attack] can_attack (应为 false): ", a.can_attack())
	a.reset_cooldown()
	print("[Attack] can_attack after reset (应为 true): ", a.can_attack())
	
	
# ── MutationComponent ────────────────────────────
func _test_mutation() -> void:
	var m := MutationComponent.new()
	add_child(m)
	m.mutated.connect(func(soil, tags): print("[Mutation] soil=%s tags=%s" % [MutationComponent.SoilType.keys()[soil], tags]))
 
	m.apply_mutation(MutationComponent.SoilType.FIRE)   # 期望: tags=["burn"]
	print("[Mutation] has_tag burn: ", m.has_tag("burn"))
	m.apply_mutation(MutationComponent.SoilType.ICE)    # 期望: tags=["freeze"]
	m.clear_mutation()                                   # 期望: tags=[]
