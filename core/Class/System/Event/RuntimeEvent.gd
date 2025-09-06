extends BaseEvent
class_name RuntimeEvent
# 所有运行事件都需要实现的处理器接口
func execute(processor: EventProcessor) -> void:
	pass
