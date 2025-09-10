extends SerializationUtil
class_name NetworkSerializer


# 序列化网络对象到字节数组
static func serialize(obj: NetworkManager) -> PackedByteArray:
	var network_data = obj.get_network_data()
	var buffer = StreamPeerBuffer.new()
	write(buffer, obj.url)
	return buffer.data_array

# 反序列化字节数组到对象数据
static func deserialize(bytes: PackedByteArray) -> Dictionary:
	var buffer = StreamPeerBuffer.new()
	buffer.put_data(bytes)
	buffer.seek(0)
	var result = {}    
	result[&"url"] = read(buffer, TYPE_INT)
	return result
