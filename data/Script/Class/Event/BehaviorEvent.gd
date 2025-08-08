extends BaseEvent
class_name BehaviorEvent

const EVENT_TYPE_BEHAVIOR:String = "behavior"

enum EventType {
	NULL,
	DRAW_CARD,         # 行为事件：抽卡
}

func _init(event_type:EventType) -> void:
	event_data.set(DefaultKey.EVENT_CLASS,BaseEvent.EventClass.BehaviorEvent)
	event_data.set(DefaultKey.EVENT_TYPE,event_type)
	event_data.set(DefaultKey.PLAYER_ID,GlobalServer.id)
