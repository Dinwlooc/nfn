extends RefCounted
class_name OperationEvent
#操作事件，客户端渲染层向服务器端逻辑层单向通信的媒介。
#需要重建对象。
enum BaseKeys {
	EVENT_TYPE,
	END,#扩展标识符
}
enum EventType {
	   PLAY_CARDS,
	}
var event_data:Dictionary = {}

func _init(init_type:int) -> void:
	event_data.set( BaseKey.EVENT_TYPE,init_type)

func set_cards(cards:Array[RenderCard]) -> OperationEvent:
	event_data.set( BaseKey.CARD_ID,[])
	for card in cards:
			event_data.get( BaseKey.CARD_ID).append(card.get_id())
	return self
	
func add_card(card:RenderCard)-> OperationEvent:
	if !event_data.get( BaseKey.CARD_ID):
		event_data.set( BaseKey.CARD_ID,[])
	event_data.get( BaseKey.CARD_ID).append(card.get_id())
	return self

func add_target(target_card:RenderCard) -> OperationEvent:
	if !event_data.get( BaseKey.TARGET_ID):
		event_data.set( BaseKey.TARGET_ID,[])
	event_data.get( BaseKey.TARGET_ID).append(target_card.get_id())
	return self
	
func set_targets(target_cards:Array[RenderCard])-> OperationEvent:
	event_data.set( BaseKey.TARGET_ID,[])
	for card in target_cards:
			event_data.get( BaseKey.TARGET_ID).append(card.get_id())
	return self
	
func set_params(key:String,value:Variant)-> OperationEvent:
	#需要传输非官方参数时可用的额外接口。可能弃用。
	event_data.set(key,value)
	return self
	
func serialize() -> PackedByteArray:
	return var_to_bytes(event_data)

static func deserialize(serialized_data: PackedByteArray) -> Dictionary:
	var data = bytes_to_var(serialized_data)
	if data is Dictionary:
		return data
	push_error("OperationEvent deserialize failed: data is not a dictionary")
	return {}
