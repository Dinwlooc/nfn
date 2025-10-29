## 操作请求管理器，负责创建和上传操作请求
## 当前仅处理"出牌"操作业务
class_name OperationManager
extends RefCounted

# 区域引用（通过外部注入）
var _hand_area: RenderArea
var _target_area: RenderArea
var _transport_layer:Transport = GlobalTransport

## 配置必要区域（由RenderControl注入）
func configure_areas(hand_area: RenderAreaHand, target_area: RenderAreaTargets) -> void:
	_hand_area = hand_area
	_target_area = target_area

## 上传出牌操作请求
func upload_play_card() -> void:
	# 验证区域配置
	if not _hand_area or not _target_area:
		GlobalConsole._print("操作管理器: 未配置必要区域")
		return
	# 获取选中项
	var card_ids = _hand_area.get_selected_ids()
	var target_ids = _target_area.get_selected_ids()
	# 验证选择状态
	if card_ids.is_empty() or target_ids.is_empty():
		GlobalConsole._print("操作管理器: 出牌请求失败 - 需要选中卡牌和目标")
		return
	# 创建并发送请求
	var request := OperationRequest.PlayCard.new(
		card_ids[0],
		target_ids[0]
	)
	GlobalConsole._print("操作管理器: 出牌请求已发送")
	_transport_layer.upload_operation_request(request)
