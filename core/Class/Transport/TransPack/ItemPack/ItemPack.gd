## 所有数据包基类，提供序列化、合并、版本管理等公共逻辑
extends TransPack
class_name ItemPack

var id: int
var merge_mask: int = 0
var is_full_update: bool = false
const VERSION_MAX: int = 65535
static var NULL_PACK = ItemPack.new()

func _init(init_id: int = 0) -> void:
	id = init_id

static func init_from_item(item: Item) -> ItemPack:
	return null

func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	SerializationUtil.write(buffer, id)
	SerializationUtil.write(buffer, version)
	SerializationUtil.write(buffer, merge_mask)
	SerializationUtil.write(buffer, is_full_update)

static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = ItemPack.new()) -> ItemPack:
	pack.id = SerializationUtil.read(buffer, TYPE_INT)
	pack.version = SerializationUtil.read(buffer, TYPE_INT)
	pack.merge_mask = SerializationUtil.read(buffer, TYPE_INT)
	pack.is_full_update = SerializationUtil.read(buffer, TYPE_BOOL)
	return pack

## 合并更新包。当 update_pack.version == 0 时视为相对于标准态的增量包，需先重置为标准态
func merge(update_pack: ItemPack) -> void:
	id = update_pack.id
	if update_pack.version != version + 1 and update_pack.version != 0 and merge_mask != -1:
		print("发现版本错误：id:%d,version:%d" % [id, version])
		return
	if update_pack.version == 0:
		reset_to_standard()
	version = update_pack.version

## 重置所有属性为标准态（由子类重写），版本0增量合并前调用
func reset_to_standard() -> void:
	pass

func get_id() -> int:
	return id

func get_version() -> int:
	return version

func set_version(new_version: int) -> void:
	version = new_version % VERSION_MAX

func update_merge_mask() -> void:
	if is_full_update:
		merge_mask = -1
		return
	merge_mask = 0

static func get_class_name_static() -> StringName:
	return &"ItemPack"
