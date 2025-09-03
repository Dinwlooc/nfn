extends Node

var maingame:Node
var	renderarea:Dictionary[StringName,RenderArea]
var console:Node
var timer:GameTimer
var system:System
var render_control:RenderControl


func register_console(console_instance:Node)->void:
	console = console_instance
func register_maingame(maingame_instance:Node)->void:
	maingame = maingame_instance
func register_system(system_instance:System)->void:
	system = system_instance
func register_timer(timer_instance:GameTimer)->void:
	timer = timer_instance

func register_control(render_control_instance:RenderControl)->void:
	render_control = render_control_instance
	
func register_renderarea(renderarea_name:StringName,renderarea_instance:RenderArea)->void:
	renderarea[renderarea_name] = renderarea_instance

func get_renderarea(renderarea_name:StringName)->RenderArea:
	if renderarea.has(renderarea_name):
		return renderarea[renderarea_name]
	return null
	
func get_render_control()->RenderControl:
	return render_control
