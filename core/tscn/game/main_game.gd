## 主游戏场景根：按启动参数 [LaunchContext] 决定是否额外实例化系统层。
extends Node2D

## 创建游戏时额外实例化系统层（服务器在其就绪时启动）；加入游戏保持无系统层
## @side_effect
func _ready() -> void:
	if GlobalRegistry.get_launch_context().mode != LaunchContext.Mode.CREATE:
		GlobalConsole._print("加入游戏：未装载系统层，本场景为客户端")
		return
	var system: System = System.new()
	system.name = &"System"
	add_child(system)
	move_child(system, 0)
