extends BaseSerializer
class_name CardSerializer

enum CardKeys {
	ID ,
	CLASS,
	NAME ,
	TYPE ,
	END #用于调整子类枚举的标识符
}

enum CardClass{
	NULL,
	HAND,
	CHARACTER,
	END
}

enum HandCardKeys {
	POWER = CardKeys.END ,
	COST ,
	SUIT ,
	MODIFIED_POWER ,
	MODIFIED_COST ,
	END
}

const CardData = RenderPack.CardData

static func obj_to_byte(obj)->Data:
	var data:Data
	if obj is not Card:
		printerr("Error:")
		return null
	data = Data.new(CardKeys.END)
	serialize_write(CardKeys.ID,obj.id,data)
	serialize_write(CardKeys.NAME,obj.name,data)
	serialize_write(CardKeys.TYPE,obj.type,data)
	if obj is HandCard:
		data.main_data.resize(HandCardKeys.END)
		serialize_write(CardKeys.CLASS,CardClass.HAND,data)
		serialize_write(HandCardKeys.POWER,obj.power,data)
		serialize_write(HandCardKeys.COST,obj.cost,data)
		serialize_write(HandCardKeys.SUIT,obj.suit,data)
		serialize_write(HandCardKeys.MODIFIED_POWER,obj.get_attribute(&"power",obj.power),data)
		serialize_write(HandCardKeys.MODIFIED_COST,obj.get_attribute(&"cost",obj.cost),data)
	#elif ... 其他Card子类
	else:
		serialize_write(CardKeys.CLASS,CardClass.NULL,data)
	return data

static func data_array_to_obj(data_array:Array)->CardData:
	var data:CardData
	match data_array[CardKeys.CLASS]:
		CardClass.HAND:
			var hand_data = RenderPack.HandCardData.new()
			hand_data.id = data_array[CardKeys.ID]
			hand_data.name = data_array[CardKeys.NAME]
			hand_data.type = data_array[CardKeys.TYPE]
			hand_data.power = data_array[HandCardKeys.POWER]
			hand_data.cost = data_array[HandCardKeys.COST]
			hand_data.suit = data_array[HandCardKeys.SUIT]
			hand_data.modified_power = data_array[HandCardKeys.MODIFIED_POWER]
			hand_data.modified_cost = data_array[HandCardKeys.MODIFIED_COST]
			data = hand_data
		_: # 默认处理基类
			var card_data = RenderPack.CardData.new()
			card_data.id = data_array[CardKeys.ID]
			card_data.name = data_array[CardKeys.NAME]
			card_data.type = data_array[CardKeys.TYPE]
			data = card_data
	return data

static func serialize(obj:Card)->PackedByteArray:
	return data_to_byte(obj_to_byte(obj))

static func deserialize(data:PackedByteArray)->CardData:
	return data_array_to_obj(byte_to_data_array(data))
