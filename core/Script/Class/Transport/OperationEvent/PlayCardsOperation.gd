extends OperationEvent
class_name PlayCardsOperation

enum SubKeys{
	CARD_ID = BaseKeys.END,
	TARGET_ID
}

func _init(cards: Array[RenderCard] = [],targets: Array[RenderCard] = []) -> void:
	super._init(EventType.PLAY_CARDS).set_cards(cards).set_targets(targets)
