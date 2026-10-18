## 渲染事件：以 [member config] 携带本次渲染/补间的类型与参数，类型取自 [DefaultType]。
## 只描述"要渲染成什么样"，不携带业务状态。
extends RefCounted
class_name RenderEvent

#==vars==
## 事件参数（[code]type[/code] 为事件类型，其余键由具体事件约定）
var config: Dictionary[StringName, Variant]
## 空事件单例，用作可选事件参数的默认值
## @zero_instance
static var NULL_EVENT = RenderEvent.new()

#==types==
## 渲染事件默认类型常量
class DefaultType:
	## 空事件
	const NULL = &"null"
	## 进入区域
	const INTO_AREA = &"into_area"
	## 离开区域
	const OUTTO_AREA = &"outto_area"
	## 选中
	const SELECT = &"select"
	## 受击
	const DAMAGED = &"damaged"
	## 交换卡牌
	const SWAP_CARD = &"swap_card"
	## 卡牌添加
	const CARD_ADD = &"card_add"
	## 卡牌移除
	const CARD_REMOVE = &"card_remove"
	## 卡牌选中状态变化
	const CARD_SELECTION_CHANGED = &"card_selection_changed"
	## 卡牌开始拖拽
	const CARD_START_DRAGGING = &"card_start_dragging"
	## 卡牌取消拖拽
	const CARD_CANCEL_DRAGGING = &"card_cancel_dragging"
	## 卡牌数据更新
	const CARD_UPDATE = &"card_update"
	## 出牌操作请求
	const OPERATION_PLAY_CARD = &"operation_play_card"
	## 弃牌操作请求
	const OPERATION_DISCARD_CARDS = &"operation_discard_cards"
	## 放弃响应操作请求
	const OPERATION_ABANDON_RESPONSE = &"operation_abandon_response"


## 构造：设定初始类型与附加配置
func _init(initial_data: Variant = null) -> void:
	config = {}
	if initial_data is Dictionary:
		config = initial_data.duplicate()
	elif initial_data is StringName:
		config[&"type"] = initial_data
# 获取事件类型（从 config 中读取）
## 取事件类型
func get_type() -> StringName:
	return config.get(&"type", DefaultType.NULL)
# 设置事件类型（链式调用）
## 设置事件类型（返回自身便于链式调用）
func set_type(new_type: StringName) -> RenderEvent:
	config[&"type"] = new_type
	return self

## 合并附加配置（返回自身便于链式调用）
func merge_config(new_config:Dictionary[StringName,Variant])->RenderEvent:
	config.merge(new_config,true)
	return self
