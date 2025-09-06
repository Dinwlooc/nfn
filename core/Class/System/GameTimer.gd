extends Timer
class_name GameTimer

func _ready() -> void:
	GlobalRegistry.register_timer(self)
	
func timer_create(time:float):
	paused = false
	wait_time = time
	start()
	pass

func timer_stop():
	paused = true
	pass
	
func timer_continue():
	paused = false
