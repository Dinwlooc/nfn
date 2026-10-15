##卡牌
extends Control
class_name RenderItem

#==enums==
enum DraggingState {
	READY,          # 0 - 准备就绪
	CHECKING,       # 1 - 长按检测中
	DRAGGING,       # 2 - 长按中
	FAILED          # 3 - 长按检测失败
}

#==vars==
var area_name:StringName = &""
var player_id:int = -1
var render_context:RenderContext
var pool_id:int
var selected:bool = false
var dragged:bool = false
var dragging:DraggingState = DraggingState.READY
var hovering:bool = false
var data:ItemPack
## 视觉中心坐标。
## Get 返回当前 position + size*scale/2，Set 调整 position 使中心落在给定值。
var center_position: Vector2:
	get():
		return position - get_centered_offset()
	set(value):
		position = value + get_centered_offset()

#==signals==
## 请求外部执行渲染
## @requester
signal render_requested(render_event:RenderEvent)
## 请求外部执行重置
## @requester
signal reset_requested(item:RenderItem)
## 请求外部提供数据
## @requester
signal data_requested(item:RenderItem,render_event:RenderEvent)
## 请求外部执行选择
## @requester
signal request_select(item:RenderItem)
## 请求外部执行拖拽
## @requester
signal request_drag(item:RenderItem)
## 请求外部取消拖拽
## @requester
signal request_cancel_dragged(item:RenderItem)
## 请求外部处理牌面
## @requester
signal request_face(item:RenderItem)
## 选择状态变化广播
## @emitter
signal selected_changed(selected: bool)
## 鼠标进入广播，携带自身引用
## @emitter
signal mouse_entered_item(item: RenderItem)
## 鼠标离开广播，携带自身引用
## @emitter
signal mouse_exited_item(item: RenderItem)

func _init(new_data:ItemPack = ItemPack.NULL_PACK) -> void:
	name = &"RenderItem"
	data = new_data

func _ready() -> void:
	request_face.emit(self)
	data_requested.emit(self)
	mouse_entered.connect(_emit_mouse_entered_item)
	mouse_exited.connect(_emit_mouse_exited_item)
## 更新数据并请求刷新
## @side_effect
func data_update(new_card_data:ItemPack,render_event:RenderEvent = RenderEvent.NULL_EVENT)-> void:
	data = new_card_data
	if not is_inside_tree():
		request_ready()
		return
	data_requested.emit(self,render_event)
	render_update(render_event)
## 请求外部执行渲染
## @requester
func render_update(render_event:RenderEvent = RenderEvent.NULL_EVENT)->void:
	render_requested.emit(render_event)
## 合并数据包并刷新
## @side_effect
func apply_pack(pack: ItemPack) -> void:
	if not data:
		data_update(pack)
		return
	data.merge(pack)
	data_requested.emit(self)
	render_update(RenderEvent.new(RenderEvent.DefaultType.CARD_UPDATE))
## 重置卡牌状态
## @side_effect
func reset() -> void:
	selected = false
	dragged = false
	dragging = DraggingState.READY
	hovering = false
	data = null
	area_name = &""
	render_context = null
	pool_id = -1
	player_id = -1
	position = Vector2.ZERO
	rotation = 0
	scale = Vector2.ONE
	mouse_entered.disconnect(_emit_mouse_entered_item)
	mouse_exited.disconnect(_emit_mouse_exited_item)
	reset_requested.emit(self)

func get_item_size()->Vector2:
	return Vector2(size.x * scale.x,size.y * scale.y)

func get_centered_offset(scale_overriding:Vector2 = scale)->Vector2:
	return - Vector2(size.x * scale_overriding.x,size.y * scale_overriding.y)/2

func set_item_size(new_size:Vector2):
	size = new_size
## 设置悬停状态并请求刷新
func set_hovering(new_hovering: bool) -> void:
	if hovering == new_hovering:
		return
	hovering = new_hovering
	render_update()
## 设置选择状态并广播
func set_selected(new_selected: bool) -> void:
	if selected == new_selected:
		return
	selected = new_selected
	selected_changed.emit(selected)
	render_update()
## 请求外部执行选择
## @requester
func request_selecting():
	request_select.emit(self)
## 请求拖拽（含长按检测）
## @side_effect
func request_dragging():
	match dragging:
		DraggingState.READY:
			dragging = DraggingState.CHECKING
			await get_tree().create_timer(0.1).timeout
			if dragging == DraggingState.CHECKING:
				request_drag.emit(self)
				if not selected:
					request_selecting()
				dragging = DraggingState.DRAGGING
			elif dragging == DraggingState.FAILED:
				dragging = DraggingState.READY
		DraggingState.CHECKING:
			dragging = DraggingState.FAILED
		DraggingState.DRAGGING:
			dragging = DraggingState.READY
## 请求取消拖拽
## @side_effect
func request_cancel_dragging():
	dragging = DraggingState.READY
	request_cancel_dragged.emit(self)

func is_hovering(mouse_pos):
	return Rect2(position,size).has_point(mouse_pos)

func get_id()->int:
	if data:
		return data.get_id()
	return -1
## 内置鼠标进入信号转发为携带自身引用的广播
## @emitter
func _emit_mouse_entered_item() -> void:
	mouse_entered_item.emit(self)
## 内置鼠标离开信号转发为携带自身引用的广播
## @emitter
func _emit_mouse_exited_item() -> void:
	mouse_exited_item.emit(self)
