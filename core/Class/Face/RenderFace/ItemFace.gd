extends Control
class_name ItemFace
#卡面渲染的基类

## 关联的渲染卡牌
@export var item:RenderItem
## 卡面类型标识
var item_type:StringName

## 数据更新回调，子类重写以刷新表现
## @hook
func data_update(item:RenderItem,render_event:RenderEvent = RenderEvent.NULL_EVENT)->void:
	pass

## 渲染更新回调，子类重写以响应事件
## @hook
func render_update(_render_event:RenderEvent = RenderEvent.NULL_EVENT)->void:
	pass

## 花色映射，子类可覆盖为图集索引
## @hook
func get_suit(suit:Card.Suit) ->int:
	return suit

## 取卡牌主图标资源（按资源表键名查表）
func get_item_main_icon(item_name:StringName) -> Texture:
	return load(GlobalConfig.get_resource_path(&"card_main_icon",item_name)) as Texture

## 取本地化后的卡牌名
func get_real_name(item_name:StringName) -> String:
	return 	GlobalConfig.get_translation(item_name)

## 取本地化后的卡牌描述（键名后缀 _DES）
func get_description(item_name:StringName) -> String:
	return 	GlobalConfig.get_translation(StringName(String(item_name)+"_DES"))
## 重置卡面到初始状态（用于回收复用）
func reset() -> void:
	pass
