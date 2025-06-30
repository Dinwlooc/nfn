#extends Control
#
#var server_status:int
#var client_status:int
#var game_status:String
#var server_players:Array
#var packet
#var data_test:bool = false
#
#func _process(_delta)-> void:
#	if Engine.get_process_frames() % 2 == 0:
#		pass
#	areaHand_animation()
#
#func players_panel_update()-> void:
#	var text:String = "PlayersList:\n"
#	if server_players:
#		for i in range(0,server_players.size()):
#			text = text+server_players[i].name+str(server_players[i].id)+"\n"
#	pass
#
#
#func server_connect_status():
#		if server_status == MultiplayerPeer.CONNECTION_DISCONNECTED:
#			return("Server:Missing\n")
#		if server_status == MultiplayerPeer.CONNECTION_CONNECTING:
#			return("Server:Connecting\n")
#		if server_status == MultiplayerPeer.CONNECTION_CONNECTED:
#			return("Server:OK\n")
#
#func areaHand_animation():
#
#	pass
####
#func deserialize_cards(serialized_data: Array):
#	var byte = bytes_to_var(serialized_data)
#	var card_array = byte.map(func(data):return Card.new().unpack_from_bytes(data))
#	return card_array
#
#@rpc("authority","call_local")func get_areaHand_update(cardpoolbyte:PackedByteArray)-> void:
#	var card_pool = deserialize_cards(cardpoolbyte)
#	$AreaHand.card_update(card_pool)
#	pass
	

	#print("RPC received! Status:", server_status) 
	
