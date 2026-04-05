extends TransPack
class_name ItemPack

# 公共属性
var id: int
var merge_mask: int = 0
var is_full_update: bool = false      # 是否为全量更新包
const VERSION_MAX: int = 65535

# 初始化
func _init(init_id: int = 0) -> void:
	id = init_id

# 序列化实现（公共部分）
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	SerializationUtil.write(buffer, id)
	SerializationUtil.write(buffer, version)
	SerializationUtil.write(buffer, merge_mask)
	SerializationUtil.write(buffer, is_full_update)   # 总是写入

# 反序列化公共部分
static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = NULL_PACK) -> ItemPack:
	if pack == NULL_PACK:
		pack = ItemPack.new()
	pack.id = SerializationUtil.read(buffer, TYPE_INT)
	pack.version = SerializationUtil.read(buffer, TYPE_INT)
	pack.merge_mask = SerializationUtil.read(buffer, TYPE_INT)
	pack.is_full_update = SerializationUtil.read(buffer, TYPE_BOOL)   # 读取
	return pack

# 公共合并逻辑
func merge(update_pack: ItemPack) -> void:
	id = update_pack.id
	if update_pack.version != version + 1:
		print("发现版本错误：id:%d,version:%d",[id,version])
	version = update_pack.version
	# 具体属性合并由子类实现，全量更新包因掩码全1会覆盖所有属性
# 获取ID
func get_id() -> int:
	return id
# 获取版本号
func get_version() -> int:
	return version
# 设置版本号（带回绕检查）
func set_version(new_version: int) -> void:
	version = new_version % VERSION_MAX
# 更新合并掩码（基础部分）
func update_merge_mask() -> void:
	if is_full_update:
		merge_mask = -1          # 全量包：所有位为1
		return
	merge_mask = 0               # 增量包：仅标记与标准态不同的属性
	# 注意：基类本身没有属性需要掩码，故留空。子类会调用 super 后添加自己的掩码位
# 获取类名（静态）
static func get_class_name_static() -> StringName:
	return &"ItemPack"
