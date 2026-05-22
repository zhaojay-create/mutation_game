extends CanvasLayer

@export var placements: Array[PlacementConfig] = []

@onready var container: HBoxContainer = $HBoxContainer

func _ready() -> void:
	print("placement_ui _ready 被调用")
	print("placements 数量: ", placements.size())
	_generate_buttons()

func _generate_buttons() -> void:
	print("开始生成按钮，container=", container)
	for i in placements.size():
		var config = placements[i]
		print("生成按钮 ", i, ": name=", config.display_name, ", scene=", config.scene)
		var btn := Button.new()
		btn.text = config.display_name if config.display_name != "" else "未命名"
		if config.icon != null:
			btn.icon = config.icon
		btn.pressed.connect(func(): _on_placement_selected(config.scene))
		container.add_child(btn)
		print("按钮 ", i, " 已添加到容器")
	
	# 取消按钮
	var cancel_btn := Button.new()
	cancel_btn.text = "❌ 取消"
	cancel_btn.pressed.connect(func(): PlacementManager.select_placeable(null))
	container.add_child(cancel_btn)

func _on_placement_selected(scene: PackedScene) -> void:
	print("按钮被点击，scene=", scene)
	if scene != null:
		PlacementManager.select_placeable(scene)
		print("已调用 PlacementManager.select_placeable")
