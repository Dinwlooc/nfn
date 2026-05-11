class_name OperationManager
extends RefCounted

## 区域名称常量引用
const HAND_AREA_NAME = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.HAND]
const PLAYERS_AREA_NAME = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS]

## 操作请求状态枚举
enum RequestStatus {
	SUCCESS = 0,                # 成功
	FAIL_HAND_AREA_MISSING = 1,  # 手牌区不存在
	FAIL_PLAYERS_AREA_MISSING = 2, # 玩家区不存在
	FAIL_NO_CARD_SELECTED = 3,   # 未选择卡牌
	FAIL_NO_TARGET_SELECTED = 4, # 未选择目标
	FAIL_COOLDOWN = 5,           # 操作冷却中
	# 后续可扩展其他失败原因
}

var _transport_layer: Transport
var _context: RenderContext
var _last_request_time: int = 0  # 上次请求的时间戳（毫秒）
const COOLDOWN_MS: int = 200      # 冷却时间 0.2 秒

func _init(transport_layer: Transport, context: RenderContext) -> void:
	_transport_layer = transport_layer
	_context = context
## 发送操作请求的公共方法（仅内部调用）
func _send_operation_request(request: OperationRequest) -> void:
	_transport_layer.upload_operation_request(request)
## 上传出牌操作请求，返回对应的渲染事件
func upload_play_card() -> RenderEvent:
	var now: int = Time.get_ticks_msec()
	if now - _last_request_time < COOLDOWN_MS:
		return _build_play_card_event(0, 0, RequestStatus.FAIL_COOLDOWN)
	var hand_area: RenderArea = _context.get_render_area(HAND_AREA_NAME)
	if not hand_area:
		return _build_play_card_event(0, 0, RequestStatus.FAIL_HAND_AREA_MISSING)
	var players_area: RenderArea = _context.get_render_area(PLAYERS_AREA_NAME)
	if not players_area:
		return _build_play_card_event(0, 0, RequestStatus.FAIL_PLAYERS_AREA_MISSING)
	var card_ids: PackedInt32Array = hand_area.get_selected_ids()
	var target_ids: PackedInt32Array = players_area.get_selected_ids()
	if card_ids.is_empty():
		return _build_play_card_event(0, 0, RequestStatus.FAIL_NO_CARD_SELECTED)
	if target_ids.is_empty():
		return _build_play_card_event(card_ids[0], 0, RequestStatus.FAIL_NO_TARGET_SELECTED)
	var card_id: int = card_ids[0]
	var target_id: int = target_ids[0]
	var request := OperationRequest.PlayCard.new(_context.area_manager.local_player_id,card_id, target_id)
	_send_operation_request(request)
	_last_request_time = now
	return _build_play_card_event(card_id, target_id, RequestStatus.SUCCESS)
## 构建“打出请求”渲染事件的辅助方法
func _build_play_card_event(card_id: int, target_id: int, status: RequestStatus) -> RenderEvent:
	var event := RenderEvent.new(RenderEvent.DefaultType.OPERATION_PLAY_CARD)
	event.merge_config({
		&"card_id": card_id,
		&"target_id": target_id,
		&"status": status
	})
	return event
## 上传弃牌操作请求
func upload_discard_cards() -> RenderEvent:
	var now: int = Time.get_ticks_msec()
	if now - _last_request_time < COOLDOWN_MS:
		return _build_discard_cards_event(PackedInt32Array(), RequestStatus.FAIL_COOLDOWN)
	var hand_area: RenderArea = _context.get_render_area(HAND_AREA_NAME)
	if not hand_area:
		return _build_discard_cards_event(PackedInt32Array(), RequestStatus.FAIL_HAND_AREA_MISSING)
	var selected_ids: PackedInt32Array = hand_area.get_selected_ids()
	if selected_ids.is_empty():
		return _build_discard_cards_event(PackedInt32Array(), RequestStatus.FAIL_NO_CARD_SELECTED)
	var request := OperationRequest.DiscardCards.new(_context.area_manager.local_player_id, selected_ids)
	_send_operation_request(request)
	_last_request_time = now
	return _build_discard_cards_event(selected_ids, RequestStatus.SUCCESS)
## 上传放弃响应操作请求（用于守区攻防阶段等）
func upload_abandon_response() -> RenderEvent:
	var now: int = Time.get_ticks_msec()
	if now - _last_request_time < COOLDOWN_MS:
		return _build_abandon_response_event(RequestStatus.FAIL_COOLDOWN)
	var request := OperationRequest.AbandonResponse.new(_context.area_manager.local_player_id)
	_send_operation_request(request)
	_last_request_time = now
	return _build_abandon_response_event(RequestStatus.SUCCESS)
## 构建弃牌渲染事件的辅助方法
func _build_discard_cards_event(card_ids: PackedInt32Array, status: RequestStatus) -> RenderEvent:
	var event := RenderEvent.new(RenderEvent.DefaultType.OPERATION_DISCARD_CARDS)
	event.merge_config({
		&"card_ids": card_ids,
		&"status": status
	})
	return event
## 构建放弃响应渲染事件的辅助方法
func _build_abandon_response_event(status: RequestStatus) -> RenderEvent:
	var event := RenderEvent.new(RenderEvent.DefaultType.OPERATION_ABANDON_RESPONSE)
	event.merge_config({
		&"status": status
	})
	return event
