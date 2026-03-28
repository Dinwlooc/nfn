extends NPCPeer
class_name AutoNPCPeer

## 可选的初始化方法
func _init(game_state: GameState, player_id: int) -> void:
	super._init(game_state, player_id)

## 返回操作请求：若在守区攻防阶段且为防守方，则随机打出一张防御牌
func get_operation_request() -> OperationRequest:
	var stage_name: StringName = _game_state.get_current_active_stage_name()
	if stage_name != &"DefenseBattle":
		return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()
	# 获取当前守区攻防阶段实例
	var defense_stage: StageDefense = _get_defense_stage()
	if defense_stage == null:
		return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()
	# 检查当前响应玩家是否为自己
	if defense_stage.current_responsive_player_id != _player_id:
		return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()
	# 获取自己的玩家对象
	var self_player: Player = _game_state.player_manager.get_player_by_id(_player_id)
	if self_player == null:
		return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()
	# 寻找手牌中的防御牌
	var defense_card: Card = _find_defense_card(self_player)
	if defense_card == null:
		return OperationRequest.AbandonResponse.new(_player_id).use_npc_peer_id()
	return OperationRequest.PlayCard.new(_player_id,defense_card.id, _player_id).use_npc_peer_id()

## 可选：重写 cleanup 进行资源释放
func cleanup() -> void:
	pass

# ========== 辅助函数 ==========
## 获取当前守区攻防阶段实例（若存在）
func _get_defense_stage() -> StageDefense:
	if not _game_state.stage_context:
		return null
	var cur_stage: Stage = _game_state.stage_context.current_stage
	if cur_stage is StageDefense:
		return cur_stage as StageDefense
	return null

## 从玩家手牌中寻找一张防御牌（type == "defence"）
func _find_defense_card(player: Player) -> Card:
	var hand_area: AreaHand = player.area_hand
	if hand_area == null:
		return null
	for card in hand_area.get_all_cards():
		if card.type == &"defence":
			return card
	return null

func await_npc_ready():
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not scene_tree:
		return
	await scene_tree.create_timer(1.0).timeout
