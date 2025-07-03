extends Node2D
	
func _ready() -> void:
	GlobalConsole.register_maingame(self)
	signal_connect_tesy()#调试模式
	GlobalServer.random_create()
	multiplayer.multiplayer_peer = GlobalServer.server
	
func _connect_to(url:String):
	if GlobalServer.id == 1:
		GlobalConsole._print("c_connerct_to未执行：服务器端请先使用c_close()关闭服务器。")
		return
	if url == "0":
		GlobalServer.url_connect(GlobalConsole.server.url)
		return
	else:	
		GlobalServer.url_connect(url)
		return

func _close():
	if GlobalServer.id == 1:
		GlobalConsole._print("服务器已关闭。")
	else:
		GlobalConsole._print("客户端已关闭。")
	GlobalServer.completely_close()
	GlobalConsole.system.signal_disconnect_tesy()
	
func signal_connect_tesy():
	GlobalConsole.c_connect_to.connect(_connect_to)
	GlobalConsole.c_close.connect(_close)
