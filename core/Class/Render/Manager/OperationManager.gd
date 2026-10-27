class_name OperationManager
extends RefCounted

## 区域名称常量引用
const HAND_AREA_NAME = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.HAND]
## 玩家区名称常量
const PLAYERS_AREA_NAME = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS]

## 操作请求错误码枚举
enum RequestError {
	OK,                # 无错误
	HAND_AREA_MISSING,   # 手牌区不存在
	PLAYERS_AREA_MISSING, # 玩家区不存在
	NO_CARD_SELECTED,    # 未选择卡牌
	NO_TARGET_SELECTED,  # 未选择目标
	COOLDOWN,            # 操作冷却中
	INVALID_CARD_INDEX,  # 手牌索引无效
	INVALID_TARGET_ID,   # 目标玩家id无效
	# 后续可扩展其他失败原因
}
## 请求错误码到中文说明的映射
const ERROR_MESSAGES: Dictionary[RequestError, String] = {
	RequestError.OK: "无错误",
	RequestError.HAND_AREA_MISSING: "手牌区不存在",
	RequestError.PLAYERS_AREA_MISSING: "玩家区不存在",
	RequestError.NO_CARD_SELECTED: "未选择卡牌",
	RequestError.NO_TARGET_SELECTED: "未选择目标，请先选择一名玩家单位或传入目标玩家id",
	RequestError.COOLDOWN: "操作冷却中",
	RequestError.INVALID_CARD_INDEX: "手牌索引无效",
	RequestError.INVALID_TARGET_ID: "目标玩家id无效",
}
## 传输层
var _transport_layer: Transport
## 渲染上下文
var _context: RenderContext
## 上次请求的时间戳（毫秒）
var _last_request_time: int = 0
## 操作冷却时间 0.2 秒
const COOLDOWN_MS: int = 200

## 构造打出请求。
## @factory @delegates(ItemsOperation.play_card)
static func create_play_card_request(player_id: int, card_id: int, target_id: int) -> ItemsOperation:
	return ItemsOperation.play_card(player_id, card_id, target_id)
## 构造弃置请求，牌 id 集合数量决定弃置张数。
## @factory @delegates(ItemsOperation.discard_cards)
static func create_discard_cards_request(player_id: int, card_ids: PackedInt32Array) -> ItemsOperation:
	return ItemsOperation.discard_cards(player_id, card_ids)
## 构造放弃响应请求。
## @factory
static func create_abandon_response_request(player_id: int) -> OperationRequest.AbandonResponse:
	return OperationRequest.AbandonResponse.new(player_id)
## 从渲染区域的对象池中取出指定索引的渲染项，索引无效时返回 null。
## @nullable_pure
static func get_item_by_index(area: RenderArea, index: int) -> RenderItem:
	if area is ItemRenderArea:
		return area.get_item_by_index(index)
	return null
## 构造：绑定传输层与渲染上下文
func _init(transport_layer: Transport, context: RenderContext) -> void:
	_transport_layer = transport_layer
	_context = context
## 以指定卡牌发送打出请求，目标玩家 id 为 0 时回退到玩家区当前选中的目标。
func play_card_by_id(card_id: int, target_player_id: int = 0) -> RequestError:
	var now: int = Time.get_ticks_msec()
	if now - _last_request_time < COOLDOWN_MS:
		return RequestError.COOLDOWN
	var resolved_target_id: int = target_player_id
	if resolved_target_id == 0:
		var players_area: RenderArea = _context.get_render_area(PLAYERS_AREA_NAME)
		if not players_area:
			return RequestError.PLAYERS_AREA_MISSING
		var target_ids: PackedInt32Array = players_area.get_selected_ids()
		if target_ids.is_empty():
			return RequestError.NO_TARGET_SELECTED
		resolved_target_id = target_ids[0]
	_send_play_card(card_id, resolved_target_id, now)
	return RequestError.OK
## 以指定卡牌发送弃置请求，无视其他卡牌的选中状态。
func discard_card_by_id(card_id: int) -> RequestError:
	var now: int = Time.get_ticks_msec()
	if now - _last_request_time < COOLDOWN_MS:
		return RequestError.COOLDOWN
	_send_discard_cards(PackedInt32Array([card_id]), now)
	return RequestError.OK
## 从手牌区指定索引发送打出请求。
func play_card_by_index(card_index: int, target_player_id: int = 0) -> RequestError:
	var hand_area: RenderArea = _context.get_render_area(HAND_AREA_NAME)
	if not hand_area:
		return RequestError.HAND_AREA_MISSING
	var card_item: RenderItem = get_item_by_index(hand_area, card_index)
	if not card_item:
		return RequestError.INVALID_CARD_INDEX
	return play_card_by_id(card_item.get_id(), target_player_id)
## 从手牌区指定索引发送弃置请求，沿途错误由本方法负责播报。
func discard_card_by_index(card_index: int) -> RequestError:
	var hand_area: RenderArea = _context.get_render_area(HAND_AREA_NAME)
	if not hand_area:
		return RequestError.HAND_AREA_MISSING
	var card_item: RenderItem = get_item_by_index(hand_area, card_index)
	if not card_item:
		return RequestError.INVALID_CARD_INDEX
	return discard_card_by_id(card_item.get_id())
## 发送操作请求的公共方法（仅内部调用）
## @external
func _send_operation_request(request: OperationRequest) -> void:
	_transport_layer.upload_operation_request(request)
## 上传出牌操作请求，返回对应的渲染事件
func upload_play_card() -> RenderEvent:
	var now: int = Time.get_ticks_msec()
	if now - _last_request_time < COOLDOWN_MS:
		return _build_play_card_event(0, 0, RequestError.COOLDOWN)
	var hand_area: RenderArea = _context.get_render_area(HAND_AREA_NAME)
	if not hand_area:
		return _build_play_card_event(0, 0, RequestError.HAND_AREA_MISSING)
	var players_area: RenderArea = _context.get_render_area(PLAYERS_AREA_NAME)
	if not players_area:
		return _build_play_card_event(0, 0, RequestError.PLAYERS_AREA_MISSING)
	var card_ids: PackedInt32Array = hand_area.get_selected_ids()
	if card_ids.is_empty():
		return _build_play_card_event(0, 0, RequestError.NO_CARD_SELECTED)
	var target_ids: PackedInt32Array = players_area.get_selected_ids()
	if target_ids.is_empty():
		return _build_play_card_event(card_ids[0], 0, RequestError.NO_TARGET_SELECTED)
	return _send_play_card(card_ids[0], target_ids[0], now)
## 上传弃牌操作请求
func upload_discard_cards() -> RenderEvent:
	var now: int = Time.get_ticks_msec()
	if now - _last_request_time < COOLDOWN_MS:
		return _build_discard_cards_event(PackedInt32Array(), RequestError.COOLDOWN)
	var hand_area: RenderArea = _context.get_render_area(HAND_AREA_NAME)
	if not hand_area:
		return _build_discard_cards_event(PackedInt32Array(), RequestError.HAND_AREA_MISSING)
	var selected_ids: PackedInt32Array = hand_area.get_selected_ids()
	if selected_ids.is_empty():
		return _build_discard_cards_event(PackedInt32Array(), RequestError.NO_CARD_SELECTED)
	return _send_discard_cards(selected_ids, now)
## 上传放弃响应操作请求（用于守区攻防阶段等）
func upload_abandon_response() -> RenderEvent:
	var now: int = Time.get_ticks_msec()
	if now - _last_request_time < COOLDOWN_MS:
		return _build_abandon_response_event(RequestError.COOLDOWN)
	var request: OperationRequest.AbandonResponse = create_abandon_response_request(_context.area_manager.local_player_id)
	_send_operation_request(request)
	_last_request_time = now
	return _build_abandon_response_event(RequestError.OK)
## 发送打出请求并构建渲染事件。
## @internal
func _send_play_card(card_id: int, target_id: int, now: int) -> RenderEvent:
	var request: ItemsOperation = create_play_card_request(_context.area_manager.local_player_id, card_id, target_id)
	_send_operation_request(request)
	_last_request_time = now
	return _build_play_card_event(card_id, target_id, RequestError.OK)
## 发送弃置请求并构建渲染事件。
## @internal
func _send_discard_cards(card_ids: PackedInt32Array, now: int) -> RenderEvent:
	var request: ItemsOperation = create_discard_cards_request(_context.area_manager.local_player_id, card_ids)
	_send_operation_request(request)
	_last_request_time = now
	return _build_discard_cards_event(card_ids, RequestError.OK)
## 构建“打出请求”渲染事件的辅助方法
func _build_play_card_event(card_id: int, target_id: int, error: RequestError) -> RenderEvent:
	var event := RenderEvent.new(RenderEvent.DefaultType.OPERATION_PLAY_CARD)
	event.merge_config({
		&"card_id": card_id,
		&"target_id": target_id,
		&"status": error
	})
	return event
## 构建弃牌渲染事件的辅助方法
func _build_discard_cards_event(card_ids: PackedInt32Array, error: RequestError) -> RenderEvent:
	var event := RenderEvent.new(RenderEvent.DefaultType.OPERATION_DISCARD_CARDS)
	event.merge_config({
		&"card_ids": card_ids,
		&"status": error
	})
	return event
## 构建放弃响应渲染事件的辅助方法
func _build_abandon_response_event(error: RequestError) -> RenderEvent:
	var event := RenderEvent.new(RenderEvent.DefaultType.OPERATION_ABANDON_RESPONSE)
	event.merge_config({
		&"status": error
	})
	return event
