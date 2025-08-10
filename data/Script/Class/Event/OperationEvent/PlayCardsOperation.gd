extends OperationEvent
class_name PlayCardsOperation

func _init(cards: Array[RenderCard] = [],targets: Array[RenderCard] = []) -> void:
	super._init(OpType.PLAY_CARDS).set_cards(cards).set_targets(targets)
