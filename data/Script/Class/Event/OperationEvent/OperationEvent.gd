extends BaseEvent
class_name OperationEvent
#操作事件，客户端渲染层与服务器端逻辑层通信的媒介。在构建时即使用可序列化的字典
const EVENT_TYPE:StringName = &"event_type"
const PLAYER_ID:StringName = &"player_id"
const CARD_ID:StringName = &"card_id"
const TARGET_ID:StringName = &"target_id"
enum OpType {
	   PLAY_CARDS,
	}
var event_data:Dictionary = {}

func _init(init_type:int,init_player_id:int = GlobalServer.get_id()) -> void:
	super._init(init_type,init_player_id)
	event_data.set(EVENT_TYPE,init_type)
	event_data.set(PLAYER_ID,init_player_id)

func set_cards(cards:Array[RenderCard]) -> OperationEvent:
	event_data.set(CARD_ID,[])
	for card in cards:
			event_data.get(CARD_ID).append(card.get_id())
	return self
	
func add_card(card:RenderCard)-> OperationEvent:
	if !event_data.get(CARD_ID):
		event_data.set(CARD_ID,[])
	event_data.get(CARD_ID).append(card.get_id())
	return self

func add_target(target_card:RenderCard) -> OperationEvent:
	if !event_data.get(TARGET_ID):
		event_data.set(TARGET_ID,[])
	event_data.get(TARGET_ID).append(target_card.get_id())
	return self
	
func set_targets(target_cards:Array[RenderCard])-> OperationEvent:
	event_data.set(TARGET_ID,[])
	for card in target_cards:
			event_data.get(TARGET_ID).append(card.get_id())
	return self
	
func set_params(key:StringName,value)-> OperationEvent:
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
