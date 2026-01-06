##卡牌
extends Control
class_name RenderItem

var area_name:StringName
var render_context:RenderContext
enum DraggingState {
	READY,          # 0 - 准备就绪
	CHECKING,       # 1 - 长按检测中
	DRAGGING,       # 2 - 长按中
	FAILED          # 3 - 长按检测失败
}
var move_state:bool = false
var pool_id:int
var selected:bool = false
var dragged:bool = false
var dragging:DraggingState = DraggingState.READY
var hovering:bool = false
var data:TransPack
var item_size = Vector2(58,88)
signal select
signal drag
signal face_update()
signal render_requested(render_event:RenderEvent)
signal data_requested(item:RenderItem)
signal request_select(item:RenderItem)
signal request_drag(pool_id:int)

func _init(new_data:TransPack = TransPack.new()) -> void:
	data = new_data

func _ready()-> void:
	name = &"RenderItem"
	data_requested.emit(self)

func data_update(new_card_data:TransPack)-> void:
	data = new_card_data
	data_requested.emit(self)

func render_update(render_event:RenderEvent)->void:
	render_requested.emit(render_event)

func get_item_size()->Vector2:
	return item_size

func set_item_size(new_size:Vector2):
	item_size = new_size

func request_selecting():
	request_select.emit(self)
	pass

func request_dragging():
	match dragging:
		DraggingState.READY:
			dragging = DraggingState.CHECKING
			await get_tree().create_timer(0.1).timeout
			if dragging == DraggingState.CHECKING:
				request_drag.emit(pool_id)
				if not selected:
					request_selecting()
				dragging = DraggingState.DRAGGING
			elif dragging == DraggingState.FAILED:
				dragging = DraggingState.READY
		DraggingState.CHECKING:
			dragging = DraggingState.FAILED
		DraggingState.DRAGGING:
			request_drag.emit(pool_id)
			dragging = DraggingState.READY

func is_hovering(mouse_pos):
	return Rect2(position,position+item_size).has_point(mouse_pos)

func get_id()->int:
	if data:
		return data.get_id()
	else :
		return -1
