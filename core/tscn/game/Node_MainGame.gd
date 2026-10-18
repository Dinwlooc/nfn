extends Node2D

## 就绪时用全局网络管理器的对等体初始化 multiplayer
func _ready() -> void:
	multiplayer.multiplayer_peer = GlobalRegistry.get_network_manager().server
