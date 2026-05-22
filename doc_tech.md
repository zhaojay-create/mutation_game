# Mutation 技术设计文档

> 原则：**组合优于继承**。所有能力（攻击、生命、冷却、变异）均以 Component 节点挂载，基类只提供最小接口。

---

## 一、土壤系统

### 方案选择：TileMapLayer ✅

推荐使用 **TileMapLayer**（Godot 4.x）实现土壤，原因：

| 对比项           | TileMapLayer                  | 自定义 Node2D 网格 |
| ---------------- | ----------------------------- | ------------------ |
| 渲染性能         | 批量绘制，极佳                | 逐节点，差         |
| 自定义数据       | TileData 自定义属性，天然支持 | 需手写字典         |
| 寻路集成         | 内建 NavigationRegion2D 支持  | 需额外适配         |
| 运行时修改单格   | `set_cell()` 一行搞定         | 需手动管理         |
| 玩家动态修改土壤 | ✅                            | ✅                 |

**实现要点：**

- 土壤层 = 一个专用 `TileMapLayer`（独立于地形障碍层）
- 每种土壤对应一个 TileSet 中的 Tile，附加自定义数据：
  ```
  TileData 自定义属性:
  soil_type : String   # "normal" | "fire" | "poison" | "water" | "dark"
  mutation_tags : Array[String]  # ["burn", "dot"] 等效果标签
  ```
- 查询某坐标的土壤：`TileMapLayer.get_cell_tile_data(coords).get_custom_data("soil_type")`
- 玩家修改土壤：`TileMapLayer.set_cell(coords, source_id, atlas_coords)`

---

## 二、核心基类设计

> 所有场景节点只持有**最小状态**，能力通过挂载 Component 子节点扩展。

### 2.1 HealthComponent（生命值组件）

```
Node: HealthComponent
  属性:
	max_hp     : float
	current_hp : float  (运行时)
  信号:
	damaged(amount: float)
	healed(amount: float)
	died()
  方法:
	take_damage(amount: float)
	heal(amount: float)
```

### 2.2 AttackComponent（攻击/伤害组件）

```
Node: AttackComponent
  属性:
	damage      : float
	range       : float
	cooldown    : float   # 秒
  内部:
	_timer      : float   # 运行时冷却计数
  信号:
	attack_executed(target: Node)
  方法:
	can_attack() -> bool
	do_attack(target: Node)
	reset_cooldown()
```

### 2.3 MutationComponent（变异组件）

```
Node: MutationComponent
  属性:
	soil_type        : String       # 当前所在土壤
	active_tags      : Array[String] # 已激活变异标签
  信号:
	mutated(soil_type: String, tags: Array)
  方法:
	apply_mutation(soil_type: String)  # 即时生效，读土壤→写 active_tags→发信号
	clear_mutation()
```

### 2.4 HatchComponent（孵化组件，蛋用）

```
Node: HatchComponent
  属性:
	hatch_scenes     : Dictionary   # soil_type -> PackedScene
	hatch_time       : float        # 孵化时长（秒）
	default_scene    : PackedScene
  信号:
	hatched(instance: Node)
  方法:
	start_hatch(soil_type: String)  # 启动孵化计时
	get_progress() -> float         # 返回孵化进度 0.0~1.0（供进度条用）
	_on_hatch_complete()            # 内部：按 soil_type 实例化对应场景
```

---

## 三、放置单位基类

### PlaceableBase（所有可放置单位的公共基类）

```
场景结构:
  PlaceableBase (CharacterBody2D 或 StaticBody2D)
  ├── Sprite2D / AnimatedSprite2D
  ├── CollisionShape2D      # 定义最小占地 & 碰撞
  ├── Area2D (FootprintArea) # 放置检测用，判断红/绿预览
  ├── HealthComponent
  └── MutationComponent

属性:
  footprint_size : Vector2   # 最小占地尺寸，对应隐藏吸附网格单元倍数
  placeable_on   : Array[String]  # 允许放置的土壤类型，空=全部允许

信号:
  placed(position: Vector2, soil_type: String)
  destroyed()

方法:
  on_placed(soil_type: String)   # 放置完成时调用，触发 MutationComponent
  get_footprint_rect() -> Rect2
```

### PlantBase（植物，继承 PlaceableBase）

```
额外挂载:
  AttackComponent   # 被动/范围攻击

特点: StaticBody2D，不移动
```

### AnimalBase（动物，继承 PlaceableBase）

```
额外挂载:
  AttackComponent   # 主动攻击，有寻敌逻辑

特点: CharacterBody2D，可小范围移动或旋转朝向目标
```

### EggBase（蛋，继承 PlaceableBase）

```
额外挂载:
  HatchComponent    # 孵化逻辑

特点: 放置后启动孵化计时，完成后 HatchComponent 实例化对应角色，蛋节点自毁
```

---

## 四、敌人基类

### EnemyBase

```
场景结构:
  EnemyBase (CharacterBody2D)
  ├── Sprite2D / AnimatedSprite2D
  ├── CollisionShape2D
  ├── NavigationAgent2D     # Godot 内建寻路代理
  ├── HealthComponent
  ├── AttackComponent
  └── DetectionArea (Area2D) # 检测周围的 PlaceableBase

属性:
  move_speed       : float
  target_priority  : int    # 0=PlaceableBase优先, 1=Nexus直冲（突破后切换）

信号:
  reached_target()
  target_changed(new_target: Node)

方法:
  _physics_process(delta)   # 移动逻辑：NavigationAgent2D.get_next_path_position()
  find_target()             # 优先找路径上的 Placeable，无则指向 Nexus
  _on_placeable_destroyed() # 监听 Placeable.destroyed → 重新寻路
```

**寻路流程：**

```
每帧:
  1. find_target() → 优先 DetectionArea 内的 PlaceableBase
  2. 若有目标 Placeable → NavigationAgent2D 目标设为 Placeable.position
	 否则 → 目标设为 Nexus.position
  3. NavigationAgent2D 规避地形障碍（TileMapLayer 的导航层）
  4. 到达攻击范围 → AttackComponent.do_attack(target)
```

---

## 五、Nexus（核心节点）

```
场景结构:
  Nexus (Area2D)                  # 用 Area2D 检测进入的敌人
  ├── Sprite2D
  ├── CollisionShape2D            # 触发区域（覆盖中央若干格）
  └── CorruptionComponent         # 污染度组件（见下）

特点:
  - 敌人进入 Area2D → body_entered 信号 → CorruptionComponent.add_corruption()
  - 污染度达到上限 → 触发 GameManager.game_over()
  - 不挂 AttackComponent，不挂 HealthComponent
  - 污染度越高，Sprite2D 的 modulate 颜色从白色渐变到黑紫色
```

### CorruptionComponent.gd

```gdscript
class_name CorruptionComponent
extends Node

@export var max_corruption: float = 100.0
@export var corruption_per_enemy: float = 10.0

var current_corruption: float = 0.0

signal corruption_changed(current: float, maximum: float)
signal fully_corrupted()

func add_corruption(amount: float = -1.0) -> void:
	var value := corruption_per_enemy if amount < 0.0 else amount
	current_corruption = minf(current_corruption + value, max_corruption)
	corruption_changed.emit(current_corruption, max_corruption)
	if current_corruption >= max_corruption:
		fully_corrupted.emit()

func get_ratio() -> float:
	return current_corruption / max_corruption
```

---

## 六、半自由放置系统（PlacementManager）

```
Node: PlacementManager (Node2D)
  属性:
	snap_cell_size   : Vector2   # 隐藏吸附网格单元大小，如 (32, 32)
	soil_layer       : TileMapLayer  # 引用土壤 TileMapLayer
	terrain_layer    : TileMapLayer  # 引用地形障碍 TileMapLayer

  方法:
	snap_to_grid(world_pos: Vector2) -> Vector2
	  # world_pos.snapped(snap_cell_size) + offset

	get_soil_at(world_pos: Vector2) -> String
	  # 世界坐标 → TileMapLayer 格坐标 → 读 soil_type

	can_place(scene: PackedScene, world_pos: Vector2) -> bool
	  # 1. snap_to_grid
	  # 2. 检查 terrain_layer 是否可放
	  # 3. 检查 FootprintArea 是否与已有 PlaceableBase 重叠

	place(scene: PackedScene, world_pos: Vector2)
	  # 1. can_place → false 则返回
	  # 2. 实例化 scene，设置 position = snap_to_grid(world_pos)
	  # 3. 调用 instance.on_placed(get_soil_at(world_pos))

  预览逻辑 (_process):
	- 实时调用 snap_to_grid(mouse_pos) 更新预览位置
	- can_place → true → 绿色 modulate；false → 红色 modulate
```

---

## 七、节点/场景目录结构（建议）

```
res://
├── components/
│   ├── HealthComponent.tscn  + HealthComponent.gd
│   ├── AttackComponent.tscn  + AttackComponent.gd
│   ├── MutationComponent.tscn + MutationComponent.gd
│   └── HatchComponent.tscn   + HatchComponent.gd
├── entities/
│   ├── base/
│   │   ├── PlaceableBase.tscn  + PlaceableBase.gd
│   │   ├── PlantBase.tscn      + PlantBase.gd
│   │   ├── AnimalBase.tscn     + AnimalBase.gd
│   │   ├── EggBase.tscn        + EggBase.gd
│   │   └── EnemyBase.tscn      + EnemyBase.gd
│   ├── plants/    # 每个植物：继承 PlantBase.tscn 的子场景 + 各自的 .gd
│   ├── animals/   # 每个动物：继承 AnimalBase.tscn 的子场景 + 各自的 .gd
│   ├── eggs/      # 每个蛋：继承 EggBase.tscn 的子场景 + 各自的 .gd
│   └── enemies/   # 每个敌人：继承 EnemyBase.tscn 的子场景 + 各自的 .gd
├── world/
│   ├── Nexus.tscn            + Nexus.gd
│   ├── PlacementManager.tscn + PlacementManager.gd
│   ├── MapGenerator.gd
│   └── WaveManager.gd
└── autoloads/
	└── GameManager.gd
```

> **为什么 base 用 `.tscn` + `.gd` 而不是纯 `.gd`？**
> base 场景预设好固定子节点树（CollisionShape2D、Component 等），子类在 Godot 编辑器里
> 选择「从已有场景继承」即可复用整个节点结构，无需每次手动添加。脚本本身是挂在根节点上的 `.gd`。

---

## 八、碰撞层设计（Collision Layers & Masks）

### 层编号定义

| Layer | 名称                  | 用途                                           |
| ----- | --------------------- | ---------------------------------------------- |
| 1     | `WORLD`               | 地形障碍（TileMapLayer 静态墙/水域）           |
| 2     | `PLACEABLE`           | 所有可放置单位的物理碰撞体（植物/动物/蛋）     |
| 3     | `NEXUS`               | Nexus（基地）的物理碰撞体                      |
| 4     | `ENEMY`               | 敌人的物理碰撞体                               |
| 5     | `PLACEABLE_FOOTPRINT` | 放置检测 Area2D（FootprintArea，判断红绿预览） |
| 6     | `ENEMY_DETECTION`     | 敌人感知 Area2D（DetectionArea，寻敌用）       |
| 7     | `PROJECTILE`          | 子弹/投射物                                    |

> Godot 中 Layer = 「我是谁」，Mask = 「我能感知/碰撞谁」

---

### 各节点碰撞配置

#### 地形层 TileMapLayer（物理层）

```
CollisionLayer : WORLD (1)
CollisionMask  : 无（静态体，不主动检测任何层）
```

#### PlantBase / AnimalBase / EggBase（CollisionShape2D）

```
CollisionLayer : PLACEABLE (2)
CollisionMask  : WORLD (1)          # 与地形发生物理阻挡，不穿墙
```

#### PlantBase / AnimalBase / EggBase（FootprintArea — Area2D）

```
CollisionLayer : PLACEABLE_FOOTPRINT (5)
CollisionMask  : PLACEABLE (2)      # 检测与其他已放置单位的重叠 → 红色预览
			   + WORLD (1)          # 检测地形阻挡 → 红色预览
```

#### Nexus（CollisionShape2D）

```
CollisionLayer : NEXUS (3)
CollisionMask  : 无
```

#### EnemyBase（CollisionShape2D — 物理移动体）

```
CollisionLayer : ENEMY (4)
CollisionMask  : WORLD (1)          # 被地形阻挡，走寻路绕行
			   + PLACEABLE (2)      # 被放置单位物理阻挡（撞上则停下攻击）
			   + NEXUS (3)          # 被 Nexus 物理阻挡（到达后攻击）
			   + ENEMY (4)          # 敌人之间互不穿透（可选，拥挤感）
```

#### EnemyBase（DetectionArea — Area2D，寻敌感知）

```
CollisionLayer : ENEMY_DETECTION (6)
CollisionMask  : PLACEABLE (2)      # 感知范围内的放置单位 → 切换攻击目标
			   + NEXUS (3)          # 感知 Nexus
```

#### 植物/动物 AttackComponent（攻击范围 Area2D）

```
CollisionLayer : 无（不需要被感知）
CollisionMask  : ENEMY (4)          # 感知攻击范围内的敌人
```

#### 子弹 / Projectile（物理体）

```
CollisionLayer : PROJECTILE (7)
CollisionMask  : ENEMY (4)          # 命中敌人
			   + WORLD (1)          # 撞墙消失
```

---

### 总览速查表

| 节点                              | Layer | Mask    |
| --------------------------------- | ----- | ------- |
| TileMapLayer（地形）              | 1     | —       |
| Plant/Animal/Egg（碰撞体）        | 2     | 1       |
| Plant/Animal/Egg（FootprintArea） | 5     | 1+2     |
| Nexus（碰撞体）                   | 3     | —       |
| Enemy（碰撞体）                   | 4     | 1+2+3+4 |
| Enemy（DetectionArea）            | 6     | 2+3     |
| 攻击范围 Area2D                   | —     | 4       |
| Projectile                        | 7     | 1+4     |

---

## 九、随机地图生成（MapGenerator）

每次启动游戏时由 `MapGenerator` 程序化生成地图，不使用固定关卡文件。

### 生成流程

```
游戏启动
  → MapGenerator.generate(seed: int = -1)
	  1. 生成地形层（障碍/水域/通路）
		  - 噪声算法（FastNoiseLite）生成高度图
		  - 高度 > 阈值 → 障碍 Tile；低洼 → 水域 Tile
		  - 保证地图中央区域（Nexus 周围）始终畅通
		  - 保证四方边缘有敌人可通行的入口通道
	  2. 生成土壤层
		  - 独立噪声图（不同 seed offset）采样土壤类型
		  - 每种土壤类型对应噪声区间段：
			  [-1.0, -0.4) → 暗土
			  [-0.4,  0.0) → 毒土
			  [ 0.0,  0.3) → 普通土
			  [ 0.3,  0.6) → 水土
			  [ 0.6,  1.0] → 火焰土
		  - 可配置各类型权重调整出现概率
	  3. 放置 Nexus 到地图中央格
	  4. 标记四方敌人刷新点（地图边缘固定位置）
	  5. 更新 NavigationRegion2D（基于地形层重建导航网格）
```

### MapGenerator 接口

```
Node: MapGenerator (Node)
  属性:
	map_size         : Vector2i     # 地图格子数，如 (64, 64)
	terrain_layer    : TileMapLayer
	soil_layer       : TileMapLayer
	noise_terrain    : FastNoiseLite
	noise_soil       : FastNoiseLite
	soil_type_ranges : Array        # 噪声区间 → soil_type 映射表

  方法:
	generate(seed: int = -1)        # -1 = 随机 seed，否则复现同一张地图
	get_spawn_points() -> Array[Vector2]  # 返回四方刷新点世界坐标
	_fill_terrain()
	_fill_soil()
	_ensure_nexus_clear()            # 强制清空 Nexus 周围 N 格的障碍
	_ensure_border_passages()       # 保证四边各有入口
```

### 波次系统（WaveManager）

```
Node: WaveManager (Node)
  属性:
	wave_number      : int          # 当前波次
	spawn_points     : Array[Vector2]  # 来自 MapGenerator
	enemy_scenes     : Array[PackedScene]
	wave_config      : Array[Dictionary]
	  # 示例: [{"type": "basic", "count": 5, "interval": 1.0}, ...]

  信号:
	wave_started(wave_number: int)
	wave_cleared()
	all_waves_cleared()

  方法:
	start_next_wave()
	_spawn_enemy(scene: PackedScene, spawn_point: Vector2)
	_on_enemy_died()    # 敌人死亡计数，全灭 → wave_cleared 信号
```

**波次难度扩展：** 每波结束后 `wave_config` 可动态增加敌人数量/类型，实现无限波次递增难度。

---

## 九、关键数据流

```
玩家点击放置
  → PlacementManager.place(scene, mouse_pos)
	  → snap_to_grid()
	  → can_place() 检查碰撞+地形
	  → 实例化 scene
	  → on_placed(soil_type)
		  → MutationComponent.apply_mutation(soil_type)
			  → 读 active_tags
			  → 通知 AttackComponent 修改 damage/range 等
			  → 发出 mutated 信号（用于视觉特效）

敌人寻路
  → NavigationAgent2D 目标 = 最近 PlaceableBase 或 Nexus
  → 到达攻击范围 → AttackComponent.do_attack(target)
	  → target.HealthComponent.take_damage(damage)
		  → current_hp <= 0 → died 信号
			  → PlaceableBase.destroyed 信号
				  → 敌人重新 find_target()
```

---

## 十一、Base 类 GDScript 定义

### HealthComponent.gd

```gdscript
class_name HealthComponent
extends Node

@export var max_hp: float = 100.0

var current_hp: float

signal damaged(amount: float)
signal healed(amount: float)
signal died()

func _ready() -> void:
	current_hp = max_hp

func take_damage(amount: float) -> void:
	current_hp = maxf(current_hp - amount, 0.0)
	damaged.emit(amount)
	if current_hp == 0.0:
		died.emit()

func heal(amount: float) -> void:
	current_hp = minf(current_hp + amount, max_hp)
	healed.emit(amount)

func is_alive() -> bool:
	return current_hp > 0.0
```

---

### AttackComponent.gd

```gdscript
class_name AttackComponent
extends Node

@export var damage: float = 10.0
@export var range: float = 150.0
@export var cooldown: float = 1.0

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
	attack_executed.emit(target)

func reset_cooldown() -> void:
	_timer = 0.0
```

---

### MutationComponent.gd

```gdscript
class_name MutationComponent
extends Node

var soil_type: String = "normal"
var active_tags: Array[String] = []

signal mutated(soil_type: String, tags: Array)

const SOIL_TAGS: Dictionary = {
	"normal":  [],
	"fire":    ["burn"],
	"poison":  ["dot", "poison"],
	"water":   ["slow", "heal_aura"],
	"dark":    ["stealth", "crit"],
}

func apply_mutation(new_soil_type: String) -> void:
	soil_type = new_soil_type
	active_tags = SOIL_TAGS.get(soil_type, []).duplicate()
	mutated.emit(soil_type, active_tags)

func clear_mutation() -> void:
	soil_type = "normal"
	active_tags.clear()

func has_tag(tag: String) -> bool:
	return tag in active_tags
```

---

### HatchComponent.gd

```gdscript
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
```

---

### PlaceableBase.gd

```gdscript
class_name PlaceableBase
extends StaticBody2D

@export var footprint_size: Vector2 = Vector2(32, 32)
@export var placeable_on: Array[String] = []

@onready var health: HealthComponent = $HealthComponent
@onready var mutation: MutationComponent = $MutationComponent
@onready var footprint_area: Area2D = $FootprintArea

signal placed(position: Vector2, soil_type: String)
signal destroyed()

func on_placed(soil_type: String) -> void:
	if placeable_on.size() > 0 and soil_type not in placeable_on:
		return
	mutation.apply_mutation(soil_type)
	placed.emit(global_position, soil_type)

func get_footprint_rect() -> Rect2:
	return Rect2(global_position - footprint_size * 0.5, footprint_size)

func _ready() -> void:
	health.died.connect(_on_died)

func _on_died() -> void:
	destroyed.emit()
	queue_free()
```

---

### PlantBase.gd

```gdscript
class_name PlantBase
extends PlaceableBase

@onready var attack: AttackComponent = $AttackComponent

func _ready() -> void:
	super._ready()
	mutation.mutated.connect(_on_mutated)

func _on_mutated(_soil_type: String, tags: Array) -> void:
	if "burn" in tags:
		attack.damage *= 1.5
	if "dot" in tags:
		attack.cooldown *= 0.8
```

---

### AnimalBase.gd

```gdscript
class_name AnimalBase
extends PlaceableBase

@onready var attack: AttackComponent = $AttackComponent

var _target: Node = null

func _ready() -> void:
	super._ready()
	set_physics_process(true)
	mutation.mutated.connect(_on_mutated)

func _physics_process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var dist := global_position.distance_to(_target.global_position)
	if dist <= attack.range and attack.can_attack():
		attack.do_attack(_target)

func set_target(target: Node) -> void:
	_target = target

func _on_mutated(_soil_type: String, tags: Array) -> void:
	if "slow" in tags:
		attack.range *= 1.2
	if "crit" in tags:
		attack.damage *= 2.0
```

---

### EggBase.gd

```gdscript
class_name EggBase
extends PlaceableBase

@onready var hatch: HatchComponent = $HatchComponent

func on_placed(soil_type: String) -> void:
	super.on_placed(soil_type)
	hatch.start_hatch(soil_type)
```

---

### EnemyBase.gd

```gdscript
class_name EnemyBase
extends CharacterBody2D

@export var move_speed: float = 80.0

@onready var health: HealthComponent = $HealthComponent
@onready var attack: AttackComponent = $AttackComponent
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var detection: Area2D = $DetectionArea

var _target: Node = null

signal reached_target()
signal target_changed(new_target: Node)

func _ready() -> void:
	health.died.connect(_on_died)
	detection.body_entered.connect(_on_body_entered)
	call_deferred("_find_target")

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_find_target()
		return

	var dist := global_position.distance_to(_target.global_position)
	if dist <= attack.range:
		if attack.can_attack():
			attack.do_attack(_target)
		return

	nav_agent.target_position = _target.global_position
	var next := nav_agent.get_next_path_position()
	velocity = (next - global_position).normalized() * move_speed
	move_and_slide()

func _find_target() -> void:
	var bodies := detection.get_overlapping_bodies()
	for body in bodies:
		if body is PlaceableBase:
			_set_target(body)
			return
	var nexus := get_tree().get_first_node_in_group("nexus")
	if nexus:
		_set_target(nexus)

func _set_target(t: Node) -> void:
	_target = t
	target_changed.emit(t)

func _on_body_entered(body: Node) -> void:
	if body is PlaceableBase and _target == null:
		_set_target(body)

func _on_died() -> void:
	queue_free()
```

---

## 十二、实现顺序规划

> 原则：**由内向外，由静到动，先跑通循环再填内容**。
> 每一阶段结束时应有可运行的里程碑，不堆积未验证的代码。

---

### Phase 0 — 项目骨架（½ 天）

目标：能跑起来的空场景，目录规范到位。

1. 建立目录结构（`components/` `entities/base/` `world/` `autoloads/`）
2. 创建 `GameManager.gd` autoload，只含空的 `game_start()` / `game_over()` 方法
3. 创建主场景 `main.tscn`，挂载 `GameManager` 引用

**里程碑：** 项目可启动，无报错

---

### Phase 1 — Component 层（1 天）

目标：4 个组件脚本独立可测试。

1. `HealthComponent.gd` — `take_damage` / `heal` / `died` 信号
2. `AttackComponent.gd` — cooldown 计时、`do_attack`
3. `MutationComponent.gd` — `SOIL_TAGS` 字典、`apply_mutation` 即时生效
4. `HatchComponent.gd` — 孵化计时、按 soil_type 实例化

> 每个写完后在临时场景里挂一个空 Node 测试信号是否正确触发。

**里程碑：** 4 个组件各自单元可验证

---

### Phase 2 — TileMap 地图静态版（1 天）

目标：能看到一张手绘静态地图，土壤数据可读取。

1. 在 Godot 编辑器里创建 TileSet，设置两个 TileMapLayer：
   - `terrain_layer`（障碍/地形，带物理碰撞，配 NavigationRegion2D）
   - `soil_layer`（土壤，带 TileData 自定义属性 `soil_type`）
2. 手绘一张小测试地图（不随机，先固定）
3. 写工具函数 `get_soil_at(world_pos)` 验证读取正确
4. 配置 `NavigationRegion2D`，确认寻路网格烘焙正常

**里程碑：** 点击地图任意位置能在控制台打印出正确的 `soil_type`

---

### Phase 3 — Nexus + 基础 Enemy（1–2 天）

目标：一个敌人能走到 Nexus 并上升污染度，污染度满触发失败。

1. `CorruptionComponent.gd`（`components/`，`add_corruption` / `fully_corrupted` 信号）
2. `Nexus.tscn` + `Nexus.gd`（Area2D，挂 CorruptionComponent，`body_entered` → `add_corruption()`，加入 `nexus` group）
3. `CorruptionComponent.fully_corrupted` → `GameManager.game_over()`
4. `EnemyBase.tscn` + `EnemyBase.gd`（NavigationAgent2D 寻路到 Nexus）
5. 手动在场景里放一个敌人，验证它能走到 Nexus 并触发污染

**里程碑：** 敌人进入 Nexus → 污染度达到上限 → 控制台打印 "game over"

---

### Phase 4 — PlaceableBase + 放置系统（2 天）

目标：鼠标能放置单位，红绿预览正常，单位放下后有碰撞。

1. `PlaceableBase.tscn` + `PlaceableBase.gd`（StaticBody2D，FootprintArea）
2. `PlantBase.tscn` + `PlantBase.gd`（AttackComponent，暂时攻击范围内敌人）
3. `PlacementManager.gd`：
   - `snap_to_grid()`
   - `can_place()` 检查碰撞 + 地形
   - 红/绿 modulate 预览
   - 点击放置
4. 碰撞层按第八章配置完毕
5. 验证：敌人会绕开或攻击植物

**里程碑：** 放一棵植物，敌人先攻击植物，植物死后继续冲向 Nexus

---

### Phase 5 — 变异系统（1 天）

目标：放置在不同土壤上的单位属性即时变化。

1. `PlaceableBase.on_placed()` 调用 `MutationComponent.apply_mutation(soil_type)`
2. `PlantBase` / `AnimalBase` 监听 `mutated` 信号修改 `attack.damage` 等属性
3. 在测试地图上铺几块不同土壤，验证放置后属性变化
4. 添加简单视觉反馈（modulate 颜色变化即可）

**里程碑：** 同一植物放在火焰土上伤害 ×1.5，放在毒土上冷却 ×0.8，数值可在调试面板确认

---

### Phase 6 — AnimalBase + EggBase（1 天）

1. `AnimalBase.tscn` + `AnimalBase.gd`（有攻击范围 Area2D，主动锁敌）
2. `EggBase.tscn` + `EggBase.gd`（放置后 HatchComponent 开始孵化计时）
3. 配置 `hatch_scenes` 字典，给火焰土绑一个简单的"火龙"占位场景
4. 验证：蛋放下 → 孵化 → 生成对应角色

**里程碑：** 蛋在不同土壤上孵化出不同角色

---

### Phase 7 — WaveManager 波次系统（1 天）

目标：敌人按波次自动生成，波次递增。

1. `WaveManager.gd`：读取 `spawn_points`，按 `wave_config` 定时生成敌人
2. 波次间隔计时，全灭后自动触发下一波
3. `wave_config` 每波动态增加数量/引入新类型
4. HUD 显示当前波次（临时 Label 即可）

**里程碑：** 自动跑 3 波，每波敌人数量递增，全部到达 Nexus 后 game over

---

### Phase 8 — MapGenerator 随机地图（1–2 天）

目标：每次启动生成不同地图，土壤随机分布，路径保证连通。

1. `MapGenerator.gd`：
   - `FastNoiseLite` 生成地形（`_fill_terrain`）
   - 独立噪声图生成土壤（`_fill_soil`）
   - `_ensure_nexus_clear()` + `_ensure_border_passages()`
2. 烘焙 NavigationRegion2D（地形生成后调用 `bake_navigation_polygon()`）
3. 将 `spawn_points` 传给 `WaveManager`

**里程碑：** 每次运行地图不同，土壤分布不同，敌人仍能寻路到 Nexus

---

### Phase 9 — 打磨与内容填充（持续）

在核心循环稳定后再做：

- 具体植物/动物/敌人种类（在 `plants/` `animals/` `enemies/` 目录下扩展）
- 资源系统（放置消耗/波次奖励）
- 玩家主动修改土壤的操作
- 音效、粒子特效、UI HUD 完善
- 平衡性调整
