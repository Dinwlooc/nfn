extends BaseSerializer
class_name NetworkSerializer

enum NetworkKeys {
	URL,
	END
}

static func obj_to_byte(obj:NetworkManager) -> Data:
	if not obj.has_method("get_network_data"):
		printerr("Error: Object does not implement network serialization interface")
		return null
	var data = Data.new(NetworkKeys.END)
	var network_data = obj.get_network_data()
	serialize_write(NetworkKeys.URL, network_data.url, data)
	return data

static func data_array_to_obj(data_array: Array):
	var result = {}
	result.url = data_array[NetworkKeys.URL]
	return result

static func serialize(obj: Node) -> PackedByteArray:
	return data_to_byte(obj_to_byte(obj))

static func deserialize(bytes: PackedByteArray):
	return data_array_to_obj(byte_to_data_array(bytes))
