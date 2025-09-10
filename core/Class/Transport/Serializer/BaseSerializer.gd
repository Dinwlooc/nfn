extends RefCounted
class_name BaseSerializer

static func write(buffer: StreamPeerBuffer, value) -> void:
	SerializationUtil.write(buffer,value)
	
static func read(buffer: StreamPeerBuffer, type: int)->Variant:
	return SerializationUtil.read(buffer,type)
