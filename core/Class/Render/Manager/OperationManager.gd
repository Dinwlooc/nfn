## 操作请求管理器，负责创建和上传操作请求
class_name OperationManager
extends RefCounted
## 区域名称常量引用
const HAND_AREA_NAME = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.HAND]
const PLAYERS_AREA_NAME = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS]
var _transport_layer:Transport
var _context:RenderContext
## 配置必要区域（由RenderControl注入）
func _init(transport_layer:Transport, context:RenderContext) -> void:
	_transport_layer = transport_layer
	_context = context
## 发送操作请求的公共方法
func send_operation_request(request: OperationRequest) -> void:
	_transport_layer.upload_operation_request(request)
## 上传出牌操作请求
func upload_play_card() -> void:
	var hand_area: RenderArea = _context.get_render_area(HAND_AREA_NAME)
	if not hand_area:
		GlobalConsole._print("OperationManager: 无法获取手牌区")
		return
	var players_area: RenderArea = _context.get_render_area(PLAYERS_AREA_NAME)
	if not players_area:
		GlobalConsole._print("OperationManager: 无法获取玩家区")
		return
	var card_ids:PackedInt32Array = hand_area.get_selected_ids()
	var target_ids:PackedInt32Array = players_area.get_selected_ids()
	if card_ids.is_empty():
		GlobalConsole._print("OperationManager: 出牌请求失败 - 未选择卡牌")
		return
	if target_ids.is_empty():
		GlobalConsole._print("OperationManager: 出牌请求失败 - 未选择目标玩家")
		return
	var request := OperationRequest.PlayCard.new(
		card_ids[0],
		target_ids[0]
	)
	GlobalConsole._print(["OperationManager: 出牌请求正在发送。卡牌id:",request._card_id])
	send_operation_request(request)
