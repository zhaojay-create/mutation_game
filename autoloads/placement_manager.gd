extends Node2D

@export var snap_cell_size: Vector2 = Vector2(32, 32)

var _soil_layer: TileMapLayer = null
var _current_scene: PackedScene = null

func _get_soil_layer() -> TileMapLayer:
	if _soil_layer == null:
		_soil_layer = get_tree().current_scene.get_node_or_null("%SoilTileLayer")
	return _soil_layer
var _preview_node: Node2D = null
var _can_place: bool = false

func select_placeable(scene: PackedScene) -> void:
	print("select_placeable 被调用，scene=", scene)
	_current_scene = scene
	if _preview_node != null:
		_preview_node.queue_free()
	_preview_node = null
	
	if _current_scene != null:
		_preview_node = _current_scene.instantiate()
		_preview_node.modulate = Color(1, 1, 1, 0.5)
		_preview_node.process_mode = Node.PROCESS_MODE_DISABLED
		_preview_node.z_index = 100  # 高层级，确保在地形之上
		add_child(_preview_node)
		print("预览节点创建完成，位置：", _preview_node.global_position)

func is_selecting() -> bool:
	return _current_scene != null

func get_current_scene() -> PackedScene:
	return _current_scene

func _input(event: InputEvent) -> void:
	if _current_scene == null:
		return
		
	if event is InputEventMouseMotion:
		_update_preview()
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _can_place:
			_place_at()

func _update_preview() -> void:
	if _preview_node == null:
		print("_preview_node 为 null，无法更新预览")
		return
		
	var mouse_pos := get_global_mouse_position()
	var snapped_pos := _snap_to_grid(mouse_pos)
	_preview_node.global_position = snapped_pos
	
	_can_place = _can_place_at(snapped_pos)
	_preview_node.modulate = Color(0, 1, 0, 0.5) if _can_place else Color(1, 0, 0, 0.5)

func _snap_to_grid(world_pos: Vector2) -> Vector2:
	return world_pos.snapped(snap_cell_size)

func _can_place_at(pos: Vector2) -> bool:
	var soil := _get_soil_layer()
	# 1. 检查是否在土壤上
	if soil == null:
		return false
	var cell: Vector2i = soil.local_to_map(soil.to_local(pos))
	var tile_data: TileData = soil.get_cell_tile_data(cell)
	if tile_data == null:
		return false
		
	# 2. 检查是否与其他 PlaceableBase 重叠（用简单距离检测或 Area2D 投射）
	for placeable in get_tree().get_nodes_in_group("placeable"):
		if placeable is PlaceableBase:
			var dist: float = placeable.global_position.distance_to(pos)
			if dist < snap_cell_size.x * 0.9:  # 稍微小于一格，避免边缘贴合
				return false
				
	return true

func _place_at() -> void:
	var soil := _get_soil_layer()
	var mouse_pos := get_global_mouse_position()
	var pos := _snap_to_grid(mouse_pos)
	var cell: Vector2i = soil.local_to_map(soil.to_local(pos))
	var tile_data: TileData = soil.get_cell_tile_data(cell)
	var soil_type: int = tile_data.get_custom_data("type") if tile_data != null else 0
	
	var instance := _current_scene.instantiate()
	get_tree().current_scene.add_child(instance)
	instance.global_position = pos
	instance.add_to_group("placeable")
	
	# 调用放置完成回调
	if instance.has_method("on_placed"):
		instance.on_placed(soil_type)
	
	# 放置后清空选择（或保持选择连续放置）
	# select_placeable(null)
