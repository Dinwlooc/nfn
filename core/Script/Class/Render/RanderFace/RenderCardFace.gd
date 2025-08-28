extends Control
class_name RenderCardFace
#卡面渲染的基类

@export var card:RenderCard

func data_update()->void:
	pass

func render_update(_render_event:RenderEvent = RenderEvent.new())->void:
	pass
	
func get_suit(suit:HandCard.Suit) ->int:
	return suit

func get_card_main_icon(card_name:StringName) -> Texture:
	return load(GlobalConfig.get_resource_path(&"card_main_icon",card_name)) as Texture

func get_real_name(card_name:StringName) -> String:
	return 	GlobalConfig.get_translation(card_name)

func get_description(card_name:StringName) -> String:
	return 	GlobalConfig.get_translation(StringName(String(card_name)+"_DES"))
