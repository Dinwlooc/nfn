extends ColorRect

var transition:bool = false
signal OK

func _ready():
	visible = true
	var tween = create_tween()
	tween.tween_property(self,"color",Color(0,0,0,0),1)

func outto():
		var tween = create_tween()
		tween.tween_property(self,"color",Color(0,0,0,1),0.5)
		tween.tween_callback(emit_signal.bind("OK"))
