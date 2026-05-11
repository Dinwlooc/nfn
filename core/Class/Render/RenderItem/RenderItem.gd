##卡牌
extends Control
class_name RenderItem

var area_name:StringName = &""
var player_id:int = -1
var render_context:RenderContext
enum DraggingState {
	READY,          # 0 - 准备就绪
	CHECKING,       # 1 - 长按检测中
	DRAGGING,       # 2 - 长按中
	FAILED          # 3 - 长按检测失败
}
var pool_id:int
var selected:bool = false
var dragged:bool = false
var dragging:DraggingState = DraggingState.READY
var hovering:bool = false
var data:TransPack
signal render_requested(render_event:RenderEvent)
signal reset_requested(item:RenderItem)
signal data_requested(item:RenderItem,render_event:RenderEvent)
signal request_select(item:RenderItem)
signal request_drag(item:RenderItem)
signal request_cancel_dragged(item:RenderItem)
signal request_face(item:RenderItem)
## 选择状态变化信号，参数为新状态
signal selected_changed(selected: bool)

func _init(new_data:TransPack = TransPack.NULL_PACK) -> void:
	name = &"RenderItem"
	data = new_data

func _ready() -> void:
	request_face.emit(self)
	data_requested.emit(self)

func data_update(new_card_data:TransPack,render_event:RenderEvent = RenderEvent.NULL_EVENT)-> void:
	data = new_card_data
	if is_inside_tree():
		data_requested.emit(self,render_event)
		render_update(render_event)
	else :
		request_ready()

func render_update(render_event:RenderEvent = RenderEvent.NULL_EVENT)->void:
	render_requested.emit(render_event)

func apply_pack(pack: ItemPack) -> void:
	if data and data is ItemPack:
		data.merge(pack)
		data_requested.emit(self)
		render_update(RenderEvent.new(RenderEvent.DefaultType.CARD_UPDATE))
	else:
		data_update(pack)

func reset() -> void:
	selected = false
	dragged = false
	dragging = DraggingState.READY
	hovering = false
	data = TransPack.NULL_PACK
	area_name = &""
	render_context = null
	pool_id = -1
	player_id = -1
	position = Vector2.ZERO
	rotation = 0
	scale = Vector2.ONE
	reset_requested.emit(self)

func get_item_size()->Vector2:
	return Vector2(size.x * scale.x,size.y * scale.y)

func get_centered_offset(scale_overriding:Vector2 = scale)->Vector2:
	return - Vector2(size.x * scale_overriding.x,size.y * scale_overriding.y)/2

func set_item_size(new_size:Vector2):
	size = new_size

func set_hovering(new_hovering: bool) -> void:
	if hovering == new_hovering:
		return
	hovering = new_hovering
	render_update()

func set_selected(new_selected: bool) -> void:
	if selected == new_selected:
		return
	selected = new_selected
	selected_changed.emit(selected)
	render_update()

func request_selecting():
	request_select.emit(self)

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

func request_cancel_dragging():
	dragging = DraggingState.READY
	request_cancel_dragged.emit(self)

func is_hovering(mouse_pos):
	return Rect2(position,size).has_point(mouse_pos)

func get_id()->int:
	if data:
		return data.get_id()
	else :
		return -1
