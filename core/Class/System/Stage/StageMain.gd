## 出牌阶段主逻辑实现
## 负责处理玩家出牌流程和守区攻防逻辑
extends Stage
class_name StageMain

func _init(p_game_state: GameState) -> void:
	super._init(p_game_state)
	stage_name = &"Main"
	time_limit = 60.0

## 阶段结束处理
func end_stage_effect() -> void:
	for player: Player in game_state.player_manager.players:
		player.area_defensive.reset()
