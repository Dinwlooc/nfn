## 卡面表现基类：绑定一张 [RenderItem]，把数据更新与渲染请求分发到子类钩子，并提供回收用的重置契约。
extends Control
class_name ItemFace

#==vars==
## 关联的渲染卡牌
@export var item: RenderItem
## 卡面类型标识
var item_type: StringName

#==hooks==
## 数据更新钩子：把 [RenderItem] 的数据归约为静态表现（文本、贴图、花色、底色）。
## @hook
func data_update(item: RenderItem, render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	pass
## 渲染更新钩子：由卡牌的渲染请求触发，默认委派给补间更新。
## @hook @delegates(tween_update)
func render_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	tween_update(render_event)
## 补间更新钩子：子类在此采集目标状态、判定差量并提交补间。信号可重复触发，故须幂等。
## @hook
func tween_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	pass
## 花色映射钩子，子类可覆盖为图集索引。
## @hook
func get_suit(suit: Card.Suit) -> int:
	return suit
## 重置卡面到初始状态：清空补间槽位与已提交状态，供对象池回收复用。
## 实现方禁止在 reset 内创建补间：回收路径上新建动画会覆盖刚清空的槽位。
## @hook
func reset() -> void:
	pass

#==query==
## 取卡牌主图标资源（按资源表键名查表）
func get_item_main_icon(item_name: StringName) -> Texture:
	return load(GlobalConfig.get_resource_path(&"card_main_icon", item_name)) as Texture
## 取本地化后的卡牌名
func get_real_name(item_name: StringName) -> String:
	return GlobalConfig.get_translation(item_name)
## 取本地化后的卡牌描述（键名后缀 _DES）
func get_description(item_name: StringName) -> String:
	return GlobalConfig.get_translation(StringName(String(item_name) + "_DES"))
