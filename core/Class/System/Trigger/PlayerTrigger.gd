## 玩家添加时更新操作映射并为玩家创建区域。
extends SystemTrigger
class_name PlayerTrigger

var _system: System

func _init(system: System) -> void:
	super(system)
	_system = system
	_system.game_state.player_manager.player_added.connect(_on_player_added)

func _on_player_added(player: Player) -> void:
	GlobalConsole._print(["System: 新玩家加入,id:", player.player_id, "，peer_id:", player.peer_id])
	_system.operation_handler.update_verification_mapping(player.peer_id, player.player_id)
	_system.game_state.area_registry.create_areas_for_player(player)
