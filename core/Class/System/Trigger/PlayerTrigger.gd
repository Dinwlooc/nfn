## 玩家添加时更新操作映射并为玩家创建区域。
extends SystemTrigger
class_name PlayerTrigger

var _operation_handler: OperationHandler

func _init(system: System) -> void:
	super(system)
	_operation_handler = system.operation_handler
	system.game_state.player_manager.player_added.connect(_on_player_added)
	system.game_state.player_manager.player_added.connect(system.game_state.area_registry.create_areas_for_player)

func _on_player_added(player: Player) -> void:
	GlobalConsole._print(["System: 新玩家加入,id:", player.player_id, "，peer_id:", player.peer_id])
	_operation_handler.update_verification_mapping(player.peer_id, player.player_id)
