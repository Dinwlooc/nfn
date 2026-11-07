## 阶段数据包：阶段身份、自定义数据与群体攻击扩展字段的增量载体。
extends TransPack
class_name StagePack

#== Constants ==
## 可增量传输的字段掩码位
## @end_marker
enum Field {
	STAGE_NAME,
	CURRENT_PLAYER_ID,
	TEMPORARY_STAGE_PLAYER_ID,
	CUSTOM_PARAMS,
	ATTACK_STATE,
	SOURCE_CARD_ID,
	ATTACKER_ID,
	TARGET_IDS,
	PENDING_IDS,
	POWER,
	END
}
## 群体攻击通知时机（合并自原 GroupAttackNotify）
enum GroupAttackState {
	START,
	UPDATE,
	RESOLVED,
	FINISHED
}
## 群体攻击字段掩码（更新合并掩码时保留，由阶段子类写入）
const ATTACK_FIELDS_MASK: int = (
	(1 << Field.ATTACK_STATE)
	| (1 << Field.SOURCE_CARD_ID)
	| (1 << Field.ATTACKER_ID)
	| (1 << Field.TARGET_IDS)
	| (1 << Field.PENDING_IDS)
	| (1 << Field.POWER)
)
## 标准阶段名
const STANDARD_STAGE_NAME: StringName = &"Null"
## 标准当前行动玩家 id
const STANDARD_CURRENT_PLAYER_ID: int = 0
## 标准临时阶段归属玩家 id（0 表示主阶段）
const STANDARD_TEMPORARY_STAGE_PLAYER_ID: int = 0
## 标准群体攻击时机
const STANDARD_ATTACK_STATE: int = GroupAttackState.START
## 标准来源卡 id（-1 表示无）
const STANDARD_SOURCE_CARD_ID: int = -1
## 标准攻击方玩家 id
const STANDARD_ATTACKER_ID: int = 0
## 标准威力
const STANDARD_POWER: int = 0
## 版本号取模上限
const VERSION_MAX: int = 65535
## @zero_instance
static var NULL_PACK = StagePack.new()

#== Properties ==
## 阶段实体 id（地址 id，-1 表示未分配）
var id: int = -1
## 合并掩码，标记哪些字段需要传输
var merge_mask: int = 0
## 是否为全量更新包
var is_full_update: bool = false
## 阶段名
var stage_name: StringName = STANDARD_STAGE_NAME
## 当前行动玩家 id
var current_player_id: int = STANDARD_CURRENT_PLAYER_ID
## 临时阶段归属玩家 id
var temporary_stage_player_id: int = STANDARD_TEMPORARY_STAGE_PLAYER_ID
## 自定义数据的完整态（一级键值非空约定：默认值不保留）
var custom_params: Dictionary[StringName, Variant] = {}
## 自定义数据的增量传输体（删除的键以默认值表达）
var custom_params_delta: Dictionary[StringName, Variant] = {}
## 群体攻击时机
var attack_state: int = STANDARD_ATTACK_STATE
## 来源卡 id
var source_card_id: int = STANDARD_SOURCE_CARD_ID
## 攻击方玩家 id
var attacker_id: int = STANDARD_ATTACKER_ID
## 目标玩家 id（结算顺序）
var target_ids: PackedInt32Array = PackedInt32Array()
## 尚未表态的目标玩家 id
var pending_ids: PackedInt32Array = PackedInt32Array()
## 当前威力
var power: int = STANDARD_POWER

#== Constructor ==
## 构造器，仅设置 id
func _init(init_id: int = 0) -> void:
	id = init_id

#== Factory ==
## 按阶段实例创建全量数据包（子类通过 _fill_pack 扩展字段）
## @factory
static func init_from_stage(stage: Stage) -> StagePack:
	var pack := StagePack.new(stage.get_id())
	pack.stage_name = stage.stage_name
	pack.temporary_stage_player_id = stage.temporary_stage_player_id
	pack.custom_params = stage.custom_params.duplicate()
	pack.custom_params_delta = stage.custom_params.duplicate()
	stage._fill_pack(pack)
	pack.update_merge_mask()
	return pack

#== Serialization ==
## 序列化基础字段与掩码命中字段
## @override @side_effect
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	SerializationUtil.write(buffer, id)
	SerializationUtil.write(buffer, version)
	SerializationUtil.write(buffer, merge_mask)
	SerializationUtil.write(buffer, is_full_update)
	var mask: int = -1 if is_full_update else merge_mask
	if mask & (1 << Field.STAGE_NAME):
		SerializationUtil.write(buffer, stage_name)
	if mask & (1 << Field.CURRENT_PLAYER_ID):
		SerializationUtil.write(buffer, current_player_id)
	if mask & (1 << Field.TEMPORARY_STAGE_PLAYER_ID):
		SerializationUtil.write(buffer, temporary_stage_player_id)
	if mask & (1 << Field.CUSTOM_PARAMS):
		# 全量包以完整态为线上体，增量包以差量体为线上体
		var wire_params: Dictionary[StringName, Variant] = custom_params if is_full_update else custom_params_delta
		SerializationUtil.write(buffer, wire_params)
	if mask & (1 << Field.ATTACK_STATE):
		SerializationUtil.write(buffer, attack_state)
	if mask & (1 << Field.SOURCE_CARD_ID):
		SerializationUtil.write(buffer, source_card_id)
	if mask & (1 << Field.ATTACKER_ID):
		SerializationUtil.write(buffer, attacker_id)
	if mask & (1 << Field.TARGET_IDS):
		SerializationUtil.write(buffer, target_ids.size())
		for target_id: int in target_ids:
			SerializationUtil.write(buffer, target_id)
	if mask & (1 << Field.PENDING_IDS):
		SerializationUtil.write(buffer, pending_ids.size())
		for pending_id: int in pending_ids:
			SerializationUtil.write(buffer, pending_id)
	if mask & (1 << Field.POWER):
		SerializationUtil.write(buffer, power)

## 反序列化基础字段与掩码命中字段
## @override
static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack_overriding: TransPack = StagePack.new()) -> StagePack:
	var pack := pack_overriding as StagePack
	pack.id = SerializationUtil.read(buffer, TYPE_INT)
	pack.version = SerializationUtil.read(buffer, TYPE_INT)
	pack.merge_mask = SerializationUtil.read(buffer, TYPE_INT)
	pack.is_full_update = SerializationUtil.read(buffer, TYPE_BOOL)
	var mask: int = -1 if pack.is_full_update else pack.merge_mask
	if mask & (1 << Field.STAGE_NAME):
		pack.stage_name = SerializationUtil.read(buffer, TYPE_STRING_NAME)
	if mask & (1 << Field.CURRENT_PLAYER_ID):
		pack.current_player_id = SerializationUtil.read(buffer, TYPE_INT)
	if mask & (1 << Field.TEMPORARY_STAGE_PLAYER_ID):
		pack.temporary_stage_player_id = SerializationUtil.read(buffer, TYPE_INT)
	if mask & (1 << Field.CUSTOM_PARAMS):
		var dic: Dictionary[StringName, Variant] = SerializationUtil.read(buffer, TYPE_DICTIONARY)
		pack.custom_params_delta = dic
	if mask & (1 << Field.ATTACK_STATE):
		pack.attack_state = SerializationUtil.read(buffer, TYPE_INT)
	if mask & (1 << Field.SOURCE_CARD_ID):
		pack.source_card_id = SerializationUtil.read(buffer, TYPE_INT)
	if mask & (1 << Field.ATTACKER_ID):
		pack.attacker_id = SerializationUtil.read(buffer, TYPE_INT)
	if mask & (1 << Field.TARGET_IDS):
		var target_count: int = SerializationUtil.read(buffer, TYPE_INT)
		var targets: PackedInt32Array = PackedInt32Array()
		for _i in target_count:
			targets.append(SerializationUtil.read(buffer, TYPE_INT))
		pack.target_ids = targets
	if mask & (1 << Field.PENDING_IDS):
		var pending_count: int = SerializationUtil.read(buffer, TYPE_INT)
		var pending: PackedInt32Array = PackedInt32Array()
		for _j in pending_count:
			pending.append(SerializationUtil.read(buffer, TYPE_INT))
		pack.pending_ids = pending
	if mask & (1 << Field.POWER):
		pack.power = SerializationUtil.read(buffer, TYPE_INT)
	return pack

#== Merge ==
## 合并更新包：版本 0 视为相对标准态的增量，先重置为标准态
## @side_effect
func merge(update_pack: StagePack) -> void:
	id = update_pack.id
	if update_pack.version != version + 1 and update_pack.version != 0 and not update_pack.is_full_update:
		print("发现版本错误：id:%d,version:%d" % [id, version])
		return
	if update_pack.version == 0:
		reset_to_standard()
	version = update_pack.version
	if update_pack.is_full_update:
		_merge_all(update_pack)
		return
	if update_pack.merge_mask & (1 << Field.STAGE_NAME):
		stage_name = update_pack.stage_name
	if update_pack.merge_mask & (1 << Field.CURRENT_PLAYER_ID):
		current_player_id = update_pack.current_player_id
	if update_pack.merge_mask & (1 << Field.TEMPORARY_STAGE_PLAYER_ID):
		temporary_stage_player_id = update_pack.temporary_stage_player_id
	if update_pack.merge_mask & (1 << Field.CUSTOM_PARAMS):
		_merge_custom_params(update_pack.custom_params_delta)
	if update_pack.merge_mask & (1 << Field.ATTACK_STATE):
		attack_state = update_pack.attack_state
	if update_pack.merge_mask & (1 << Field.SOURCE_CARD_ID):
		source_card_id = update_pack.source_card_id
	if update_pack.merge_mask & (1 << Field.ATTACKER_ID):
		attacker_id = update_pack.attacker_id
	if update_pack.merge_mask & (1 << Field.TARGET_IDS):
		target_ids = update_pack.target_ids.duplicate()
	if update_pack.merge_mask & (1 << Field.PENDING_IDS):
		pending_ids = update_pack.pending_ids.duplicate()
	if update_pack.merge_mask & (1 << Field.POWER):
		power = update_pack.power

## 重置所有属性为标准态
## @side_effect
func reset_to_standard() -> void:
	stage_name = STANDARD_STAGE_NAME
	current_player_id = STANDARD_CURRENT_PLAYER_ID
	temporary_stage_player_id = STANDARD_TEMPORARY_STAGE_PLAYER_ID
	custom_params = {}
	custom_params_delta = {}
	attack_state = STANDARD_ATTACK_STATE
	source_card_id = STANDARD_SOURCE_CARD_ID
	attacker_id = STANDARD_ATTACKER_ID
	target_ids = PackedInt32Array()
	pending_ids = PackedInt32Array()
	power = STANDARD_POWER

## 更新合并掩码：标记与标准值不同的基础字段；群体攻击字段位由阶段子类写入后保留
## @side_effect
func update_merge_mask() -> void:
	if is_full_update:
		merge_mask = -1
		custom_params_delta = custom_params.duplicate()
		return
	# 保留 _fill_pack 与发送端已写入的字段位（群体攻击、当前行动玩家）
	merge_mask &= ATTACK_FIELDS_MASK | (1 << Field.CURRENT_PLAYER_ID)
	if stage_name != STANDARD_STAGE_NAME:
		merge_mask |= 1 << Field.STAGE_NAME
	if current_player_id != STANDARD_CURRENT_PLAYER_ID:
		merge_mask |= 1 << Field.CURRENT_PLAYER_ID
	if temporary_stage_player_id != STANDARD_TEMPORARY_STAGE_PLAYER_ID:
		merge_mask |= 1 << Field.TEMPORARY_STAGE_PLAYER_ID
	if not custom_params.is_empty():
		merge_mask |= 1 << Field.CUSTOM_PARAMS

#== Accessors ==
## 取自定义数据；不存在的键返回调用方给定的默认值
## @nullable_pure
func get_custom_param(key: StringName, default_value: Variant = null) -> Variant:
	return custom_params.get(key, default_value)

## 判断一个值是否属于"一级键值非空约定"中的默认值（视为擦除）
## @pure
static func is_erasing_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL:
			return true
		TYPE_INT:
			return value == 0
		TYPE_FLOAT:
			return value == 0.0
		TYPE_BOOL:
			return value == false
		TYPE_STRING, TYPE_STRING_NAME:
			return value == "" or value == &""
		TYPE_ARRAY:
			return (value as Array).is_empty()
		TYPE_DICTIONARY:
			return (value as Dictionary).is_empty()
	return false

## 取与给定值同类型的默认值（用于把删除的键表达为擦除）
## @pure
static func default_for(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return 0
		TYPE_FLOAT:
			return 0.0
		TYPE_BOOL:
			return false
		TYPE_STRING, TYPE_STRING_NAME:
			return ""
		TYPE_ARRAY:
			return []
		TYPE_DICTIONARY:
			return {}
	return null

## 包类名标识
## @override @pure
static func get_class_name_static() -> StringName:
	return &"StagePack"

#== Private Methods ==
## 更新并计算基础字段的增量掩码
## @side_effect
func _update_and_calculate_delta(stage: Stage) -> void:
	is_full_update = false
	merge_mask = 0
	if stage_name != stage.stage_name:
		merge_mask |= 1 << Field.STAGE_NAME
		stage_name = stage.stage_name
	if temporary_stage_player_id != stage.temporary_stage_player_id:
		merge_mask |= 1 << Field.TEMPORARY_STAGE_PLAYER_ID
		temporary_stage_player_id = stage.temporary_stage_player_id
	_update_custom_params(stage.custom_params)
	stage._fill_pack(self)
	version = (version + 1) % VERSION_MAX

## 计算自定义数据增量：变更/新增键传新值，删除键传同类型默认值
## @side_effect
func _update_custom_params(source: Dictionary[StringName, Variant]) -> void:
	var delta: Dictionary[StringName, Variant] = {}
	for key: StringName in source.keys():
		if not custom_params.has(key) or custom_params[key] != source[key]:
			delta[key] = source[key]
	for key: StringName in custom_params.keys():
		if not source.has(key):
			delta[key] = default_for(custom_params[key])
	if delta.is_empty():
		custom_params_delta = {}
		return
	merge_mask |= 1 << Field.CUSTOM_PARAMS
	custom_params_delta = delta
	custom_params = source.duplicate()

## 应用自定义数据增量：默认值擦除一级键名
## @side_effect
func _merge_custom_params(delta: Dictionary[StringName, Variant]) -> void:
	for key: StringName in delta.keys():
		var value: Variant = delta[key]
		if is_erasing_value(value):
			custom_params.erase(key)
			continue
		custom_params[key] = value

## 全量覆盖所有字段
## @side_effect
func _merge_all(update_pack: StagePack) -> void:
	stage_name = update_pack.stage_name
	current_player_id = update_pack.current_player_id
	temporary_stage_player_id = update_pack.temporary_stage_player_id
	custom_params = update_pack.custom_params_delta.duplicate()
	custom_params_delta = {}
	attack_state = update_pack.attack_state
	source_card_id = update_pack.source_card_id
	attacker_id = update_pack.attacker_id
	target_ids = update_pack.target_ids.duplicate()
	pending_ids = update_pack.pending_ids.duplicate()
	power = update_pack.power