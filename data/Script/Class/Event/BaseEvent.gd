extends RefCounted
class_name BaseEvent

class DefaultKey:
	const EVENT_TYPE:String = "event_type"
	const PLAYER_ID:String = "player_id"
	const CARD_ID = "card_id"
	const TARGET_ID = "target_id"


var event_data:Dictionary

func _init(event_type:int) -> void:
	event_data.set(DefaultKey.EVENT_TYPE,event_type)
	event_data.set(DefaultKey.PLAYER_ID,GlobalServer.get_id())

func set_cards(cards:Array[RenderCard]) -> BaseEvent:
	event_data.set(DefaultKey.CARD_ID,[])
	for card in cards:
			event_data.get(DefaultKey.CARD_ID).append(card.get_id())
	return self
	
func add_card(card:RenderCard)-> BaseEvent:
	if !event_data.get(DefaultKey.CARD_ID):
		event_data.set(DefaultKey.CARD_ID,[])
	event_data.get(DefaultKey.CARD_ID).append(card.get_id())
	return self

func add_target(target_card:RenderCard) -> BaseEvent:
	if !event_data.get(DefaultKey.TARGET_ID):
		event_data.set(DefaultKey.TARGET_ID,[])
	event_data.get(DefaultKey.TARGET_ID).append(target_card.get_id())
	return self
	
func set_targets(target_cards:Array[RenderCard])-> BaseEvent:
	event_data.set(DefaultKey.TARGET_ID,[])
	for card in target_cards:
			event_data.get(DefaultKey.TARGET_ID).append(card.get_id())
	return self
	
func set_param(key: String, value:Variant) -> BaseEvent:
	event_data.set(key,value)
	return self
