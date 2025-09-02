extends Node2D

func _ready() -> void:
	signal_connect_test()#调试模式
	GlobalTransport.random_create()
	multiplayer.multiplayer_peer = GlobalTransport.server

func _connect_to(url:String):
	if GlobalTransport.id == 1:
		GlobalConsole._print("c_connerct_to未执行：服务器端请先使用c_close()关闭服务器。")
		return
	if url == "0":
		GlobalTransport.url_connect(GlobalRegistry.server.url)
		return
	else:
		GlobalTransport.url_connect(url)
		return

func _close():
	if GlobalTransport.id == 1:
		GlobalConsole._print("服务器已关闭。")
	else:
		GlobalConsole._print("客户端已关闭。")
	GlobalTransport.close()
	GlobalRegistry.system.signal_disconnect_test()
	
func signal_connect_test():
	GlobalConsole.c_connect_to.connect(_connect_to)
	GlobalConsole.c_close.connect(_close)
