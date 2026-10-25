extends Timer
class_name GameTimer

## 就绪：把自己注册为全局计时器单例
func _ready() -> void:
	GlobalRegistry.register_singleton(GlobalRegistry.TIMER_TYPE, self)

## 退出场景树时注销，防止注册表残留悬空引用
func _exit_tree() -> void:
	GlobalRegistry.unregister_singleton(GlobalRegistry.TIMER_TYPE)

## 服务器端创建计时器（仅服务器调用）
func timer_create(time: float) -> void:
	if not multiplayer.is_server():
		push_error("Only server can call timer_create")
		return
	_update_timer_state(time, false)
	_sync_create.rpc(time)
## 服务器端暂停计时器（仅服务器调用）
func timer_stop() -> void:
	if not multiplayer.is_server():
		push_error("Only server can call timer_stop")
		return
	_update_paused(true)
	_sync_stop.rpc()
## 服务器端继续计时器（仅服务器调用）
func timer_continue() -> void:
	if not multiplayer.is_server():
		push_error("Only server can call timer_continue")
		return
	_update_paused(false)
	_sync_continue.rpc()
## 服务器本地更新计时器状态
func _update_timer_state(time: float, paused_state: bool) -> void:
	paused = paused_state
	wait_time = time
	#paused = true #手动调试用，需要锁定计时时取消该注释。
	start()
## 服务器本地更新暂停状态
func _update_paused(paused_state: bool) -> void:
	paused = paused_state
## RPC：客户端接收创建计时器同步
@rpc("authority","call_remote", "unreliable_ordered")
func _sync_create(time: float) -> void:
	if multiplayer.is_server():
		return
	_update_timer_state(time, false)
## RPC：客户端接收暂停同步
@rpc("authority","call_remote", "unreliable_ordered")
func _sync_stop() -> void:
	if multiplayer.is_server():
		return
	_update_paused(true)
## RPC：客户端接收继续同步
@rpc("authority","call_remote", "unreliable_ordered")
func _sync_continue() -> void:
	if multiplayer.is_server():
		return
	_update_paused(false)
