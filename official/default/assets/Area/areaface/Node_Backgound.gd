extends Control

func _process(_delta):
	if scale.x <= 1:
		set_process(false)
	var mouse_posistion = get_global_mouse_position()
	mouse_posistion.x = clamp(mouse_posistion.x,0,1600)
	mouse_posistion.y = clamp(mouse_posistion.y,0,900)
	position = UIAnimationUtils.smooth_move_animation(position,-mouse_posistion*(scale.x-1))
pass
