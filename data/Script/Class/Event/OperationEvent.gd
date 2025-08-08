extends BaseEvent
class_name OperationEvent

enum EventType {
	NULL,
	PLAY_CARDS,         # 操作事件：打出手牌
}

func _init(event_type:EventType) -> void:
	event_data.set(DefaultKey.EVENT_CLASS,BaseEvent.EventClass.OperationEvent)
	event_data.set(DefaultKey.EVENT_TYPE,event_type)
	event_data.set(DefaultKey.PLAYER_ID,GlobalServer.id)
