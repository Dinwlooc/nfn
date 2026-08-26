## 所有具体数据包的基类，提供 ID、合并掩码、全量标志、版本管理等公共逻辑。
extends TransPack
class_name ItemPack
## 数据包 ID
var id: int
## 合并掩码，标记哪些属性需要传输（增量包使用）。
var merge_mask: int = 0
## 是否为全量更新包（若为 true，merge_mask 将被置为 -1）。
var is_full_update: bool = false
const VERSION_MAX: int = 65535
static var NULL_PACK = ItemPack.new()
## 构造器，仅设置 ID。
## @factory
func _init(init_id: int = 0) -> void:
	id = init_id
## 根据物品实例创建全量数据包（工厂方法，子类必须重写）。
static func init_from_item(item: Item) -> ItemPack:
	return null
## 序列化 ID、版本、合并掩码及全量标志到缓冲区。
## @flow-override @side-effect
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	SerializationUtil.write(buffer, id)
	SerializationUtil.write(buffer, version)
	SerializationUtil.write(buffer, merge_mask)
	SerializationUtil.write(buffer, is_full_update)
## 反序列化基础字段，子类应在重写中调用 super。
## @flow-override @side-effect
static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = ItemPack.new()) -> ItemPack:
	pack.id = SerializationUtil.read(buffer, TYPE_INT)
	pack.version = SerializationUtil.read(buffer, TYPE_INT)
	pack.merge_mask = SerializationUtil.read(buffer, TYPE_INT)
	pack.is_full_update = SerializationUtil.read(buffer, TYPE_BOOL)
	return pack
## 合并更新包。若 update_pack.version == 0 则视为相对于标准态的增量，先重置为标准态。
## @flow-override @side-effect
func merge(update_pack: ItemPack) -> void:
	id = update_pack.id
	if update_pack.version != version + 1 and update_pack.version != 0 and merge_mask != -1:
		print("发现版本错误：id:%d,version:%d" % [id, version])
		return
	if update_pack.version == 0:
		reset_to_standard()
	version = update_pack.version
## 重置所有属性为标准态，由子类重写（空实现）。
## @template
func reset_to_standard() -> void:
	pass
## 获取 ID。
## @pure
func get_id() -> int:
	return id
## 获取版本号。
## @pure
func get_version() -> int:
	return version
## 设置版本号（取模）。
## @side-effect
func set_version(new_version: int) -> void:
	version = new_version % VERSION_MAX
## 更新合并掩码，标记与标准值不同的属性（子类应调用 super 并扩展）。
## @flow-override @side-effect @template
func update_merge_mask() -> void:
	if is_full_update:
		merge_mask = -1
		return
	merge_mask = 0
## 返回类名的静态方法，子类必须重写。
## @override @pure
static func get_class_name_static() -> StringName:
	return &"ItemPack"
