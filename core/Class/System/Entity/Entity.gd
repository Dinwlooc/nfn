## 实体基类：为物品、阶段等可寻址实体提供公共身份与增量数据包缓存。
@abstract
extends RefCounted
class_name Entity

#== Properties ==
## 实体唯一 id（-1 表示未分配）
var id: int = -1
## 上次生成的增量数据包缓存
var last_pack: TransPack = null

#== Abstract Methods ==
## 按实体创建数据包（子类专有实现）
## @force_override
@abstract func _create_pack() -> TransPack

#== Public Methods ==
## 获取实体 ID
func get_id() -> int:
	return id

## 设置实体 ID（由管理器调用）
## @side_effect
func set_id(new_id: int) -> Entity:
	id = new_id
	return self

## 取增量数据包：有缓存则就地计算差值，否则新建并记录合并掩码
## @side_effect
func get_pack() -> TransPack:
	if last_pack:
		last_pack._update_and_calculate_delta(self)
		return last_pack
	last_pack = _create_pack()
	last_pack.update_merge_mask()
	return last_pack

## 生成完整数据包（不走增量缓存）
## @delegates(_create_pack)
func get_full_pack() -> TransPack:
	return _create_pack()

## 清除增量数据包缓存
## @side_effect
func clear_pack_cache() -> void:
	last_pack = null
