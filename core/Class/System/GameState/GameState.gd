extends RefCounted
class_name GameState

## 游戏状态数据容器
var area_center := AreaCenter.new()
var area_drawing := AreaDrawing.new()
var current_player_index := 0
var cardsmanager := CardsManager.new()
var player_manager := PlayersManager.new()
var timer: GameTimer
var network_manager:NetworkManager
var _process_active := false
signal start_round(player_id:int)
signal new_behavior_with_callback(command:BehaviorCommand,callback:Callable)

func load_cards() -> void:
	area_drawing.cards_add(cardsmanager.load_all_cards())
	area_drawing.shuffle_card_pool()

func start_new_round(player_id:int):
	call_deferred(&"_start_round_emitter",player_id)

func _start_round_emitter(player_id:int):
	start_round.emit(player_id)

func queue_behavior_with_callback(command:BehaviorCommand,callback:Callable):
	new_behavior_with_callback.emit(command,callback)
