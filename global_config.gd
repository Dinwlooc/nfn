extends Node

var config:ConfigFile = ConfigFile.new()

func _ready():
	config.set_value("Player1", "player_name", "Steve")
	config.set_value("Player1", "best_score", 10)
	config.set_value("Player2", "player_name", "V3geta")
	config.set_value("Player2", "best_score", 9001)
	print(config)
	# 将其保存到文件中（如果已存在则覆盖）。
	config.save("user://scores.cfg")
