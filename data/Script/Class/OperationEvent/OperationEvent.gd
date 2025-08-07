extends RefCounted
class_name OperationEvent

class DefulatKey:
	const EVENT_TYPE:String = "event_type"
	const PLAYER_ID:String = "player_id"
class CardKey:
	const CARD_ID = "card_id"
class TargetKey:
	const TARGET_ID = "target_id"
class DefulatType:
	const PLAY_CARDS = "play_cards"


var event_data:Dictionary = { }

func _init(type:String = "") -> void:
	event_data.set(DefulatKey.EVENT_TYPE,type)
	event_data.set(DefulatKey.PLAYER_ID,GlobalServer.id)

func set_cards(cards:Array[RenderCard]) -> OperationEvent:
	event_data.set(CardKey.CARD_ID,[])
	for card in cards:
			event_data.get(CardKey.CARD_ID).append(card.get_id())
	return self
	
func add_card(card:RenderCard)-> OperationEvent:
	if !event_data.get(CardKey.CARD_ID):
		event_data.set(CardKey.CARD_ID,[])
	event_data.get(CardKey.CARD_ID).append(card.get_id())
	return self

func add_target(target_card:RenderCard) -> OperationEvent:
	if !event_data.get(TargetKey.TARGET_ID):
		event_data.set(TargetKey.TARGET_ID,[])
	event_data.get(TargetKey.TARGET_ID).append(target_card.get_id())
	return self
	
func set_targets(target_cards:Array[RenderCard])-> OperationEvent:
	event_data.set(TargetKey.TARGET_ID,[])
	for card in target_cards:
			event_data.get(TargetKey.TARGET_ID).append(card.get_id())
	return self
func set_param(key: String, value:Variant) -> OperationEvent:
	event_data.set(key,value)
	return self

func create_playcards_event(cards:Array[RenderCard],target_cards:Array[RenderCard])-> OperationEvent:
	set_cards(cards)
	set_targets(target_cards)
	event_data.set(DefulatKey.EVENT_TYPE,DefulatType.PLAY_CARDS)
	return self
