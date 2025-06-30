extends Node
#管理全部rpc和数据转发。

func pack_card(card:Card) -> PackedByteArray:
	var data_dict :Dictionary= {
	"name":card.name,
	"real_name":card.real_name,
	"description":card.description,
	"type":card.type,
	"suit":card.suit,
	"basic_damage":card.basic_damage,
	"basic_cost":card.basic_cost,
	}
	return var_to_bytes(data_dict)  # Godot内置序列化方法
	
func unpack_card(bytes: PackedByteArray)->Dictionary:
	var data_dict = bytes_to_var(bytes)  # 反序列化字典
	# 验证数据有效性
	if not data_dict is Dictionary:
		push_error("Invalid data format: Expected Dictionary")
		return {}
	return data_dict

func serialize_cards(cards:Array[Card])-> PackedByteArray:
	var bytes:Array = cards.map(func(card):return pack_card(card))
	return var_to_bytes(bytes)
	
func deserialize_cards(serialized_data: PackedByteArray)->Array[Dictionary]:
	var byte:Array = bytes_to_var(serialized_data)
	var card_data_array:Array[Dictionary] = []
	card_data_array.append_array(byte.map(func(data):return unpack_card(data)))
	return card_data_array

func cards_rpc(area:Area,rpc_name:String,cards:Array[Card]):
	var data  = serialize_cards(cards)
	rpc_id(area.player.id,rpc_name,area.area_name,data)

@rpc("authority","call_local") func cards_add(area_name:String,data:PackedByteArray):
	GlobalConsole.realarea[area_name].cards_add(deserialize_cards(data))
	pass
