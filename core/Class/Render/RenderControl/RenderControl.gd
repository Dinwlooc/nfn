extends Control
class_name RenderControl

var render_manager: RenderManager = RenderManager.new()
var operation_manager: OperationManager = OperationManager.new()
var render_context: RenderContext = RenderContext.new()

func _ready() -> void:
	GlobalRegistry.register_singleton(GlobalRegistry.RENDER_CONTROL_TYPE, self)
	render_manager.render_tree_init(self, render_context)  # 注入上下文
	_configure_operation_manager()
	GlobalConsole.c_play_a_card.connect(_on_play_a_card)

func _configure_operation_manager() -> void:
	var hand_area: RenderAreaHand = GlobalRegistry.get_renderarea(RenderArea.DefaultArea.HAND)
	var target_area: RenderAreaTargets = GlobalRegistry.get_renderarea(RenderArea.DefaultArea.PLAYERS)
	operation_manager.configure_areas(hand_area, target_area)

func _on_play_a_card() -> void:
	operation_manager.upload_play_card()
