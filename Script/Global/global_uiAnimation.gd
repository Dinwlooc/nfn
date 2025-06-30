extends Node

func smooth_move_animation(current_position:Vector2,target_position:Vector2,smooth_move_speed:float = 4):
	if  !is_equal_approx(current_position.x,target_position.x):
		current_position.x = current_position.x + (target_position.x-current_position.x)*smooth_move_speed/12
	if  !is_equal_approx(current_position.y,target_position.y):
		current_position.y = current_position.y + (target_position.y-current_position.y)*smooth_move_speed/12
	return current_position

func tween_animations(node:Node,list:Dictionary,time = 0.5,trans_type = Tween.TRANS_CUBIC,ease_type = Tween.EASE_OUT)->Tween:
	var tween:Tween = node.create_tween()
	if list:
		for key in list:
			tween.tween_property(node,key,list[key],time).set_trans(trans_type).set_ease(ease_type)
	return tween
	
func generate_coordinates(card_container_position:Vector2,card_container_size:Vector2,card_count:int = 1) -> Array:
	if card_count == 0:
		return []
	# 获取区域尺寸
	var width = card_container_size.x
	var height = card_container_size.y
	# 计算垂直居中y坐标
	var y_center = height / 2
	# 处理单张卡牌特殊情况
	if card_count == 1:
		return [Vector2(width / 2, y_center)+card_container_position]
	# 计算等间距分布
	var coordinates = []
	for i in range(card_count):
		# 使用线性插值计算位置 (0到width的等比位置)
		var x = ((i as float + 1) / (card_count + 1)) * width
		coordinates.append(Vector2(x, y_center)+card_container_position)
	return coordinates 
