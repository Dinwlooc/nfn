extends Control
class_name ItemFace
#卡面渲染的基类

@export var item:RenderItem
var item_type:StringName

func data_update(item:RenderItem,render_event:RenderEvent = RenderEvent.NULL_EVENT)->void:
	pass

func render_update(_render_event:RenderEvent = RenderEvent.NULL_EVENT)->void:
	pass

func get_suit(suit:Card.Suit) ->int:
	return suit

func get_item_main_icon(item_name:StringName) -> Texture:
	return load(GlobalConfig.get_resource_path(&"card_main_icon",item_name)) as Texture

func get_real_name(item_name:StringName) -> String:
	return 	GlobalConfig.get_translation(item_name)

func get_description(item_name:StringName) -> String:
	return 	GlobalConfig.get_translation(StringName(String(item_name)+"_DES"))
## 重置卡面到初始状态（用于回收复用）
func reset() -> void:
	pass
