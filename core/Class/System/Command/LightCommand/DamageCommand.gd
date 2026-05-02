extends BehaviorCommand
class_name DamageCommand

## 伤害标签掩码枚举（最低位表示存在自定义标签）
enum DamageTag {
	CUSTOM = 1 << 0,   # 自定义标签（实际标签字符串存储在custom_damage_tags中）
	# 以下为内置标签示例（可按需扩展，每个标签独占一个bit位）
	FIRE = 1 << 1,
	ICE = 1 << 2,
	LIGHTNING = 1 << 3,
	POISON = 1 << 4,
	BLEED = 1 << 5,
	HOLY = 1 << 6,
	SHADOW = 1 << 7,
}

## 伤害来源机制枚举（增加自定义标识）
enum SourceMechanism {
	GENERAL = 0,         # 一般伤害
	NEGATIVE_STATE = 1,  # 负面状态伤害
	DRAIN = 2,           # 流失伤害
	CUSTOM = 3,          # 自定义来源（需配合custom_source_name使用）
}

## 伤害命令上下文（内部类）
class Context extends CommandContext:
	## 命令参数
	var target_player: Player
	var health_damage: int          # 可为负数（负数代表治疗）
	var mental_damage: int          # 可为负数（负数代表治疗）
	var source_mechanism: int
	var source_player_id: int
	var source_custom_name: StringName          ## 自定义来源名称（仅当source_mechanism == CUSTOM时有效）
	var damage_tags_mask: int = 0               ## 伤害标签掩码
	var custom_damage_tags: PackedStringArray = PackedStringArray()   ## 自定义伤害标签字符串数组
	## 缓存值（预先处理后的最终伤害/治疗数值）
	var cached_health_damage: int
	var cached_mental_damage: int

	## 修改生命伤害/治疗值（只能在阶段1调用，允许负数）
	func modify_health_damage(new_value: int) -> void:
		if phase == 1:
			cached_health_damage = new_value

	## 修改精神伤害/治疗值（只能在阶段1调用，允许负数）
	func modify_mental_damage(new_value: int) -> void:
		if phase == 1:
			cached_mental_damage = new_value

	## 添加伤害标签
	func add_damage_tag(tag: DamageTag, custom_name: StringName = &"") -> void:
		if tag == DamageTag.CUSTOM:
			if custom_name.is_empty():
				return
			## 避免重复添加相同的自定义标签
			var tag_str = String(custom_name)
			if custom_damage_tags.has(tag_str):
				return
			custom_damage_tags.append(tag_str)
			damage_tags_mask |= DamageTag.CUSTOM
		else:
			damage_tags_mask |= tag

	## 移除伤害标签
	func remove_damage_tag(tag: DamageTag, custom_name: StringName = &"") -> void:
		if tag == DamageTag.CUSTOM:
			if custom_name.is_empty():
				return
			var tag_str = String(custom_name)
			var idx = custom_damage_tags.find(tag_str)
			if idx != -1:
				custom_damage_tags.remove_at(idx)
				if custom_damage_tags.is_empty():
					damage_tags_mask &= ~DamageTag.CUSTOM
		else:
			damage_tags_mask &= ~tag

	## 清空所有伤害标签
	func clear_damage_tags() -> void:
		damage_tags_mask = 0
		custom_damage_tags.clear()

func _init(
	target_player: Player,
	health_dmg: int,
	mental_dmg: int,
	mechanism: int = SourceMechanism.GENERAL,
	source_id: int = 0,
	source_custom: StringName = &"",
	damage_tags_mask: int = 0,
	custom_tags: PackedStringArray = PackedStringArray(),
	name_overriding: StringName = &"DamageCommand",
	context_overriding: Context = Context.new()
) -> void:
	super._init(source_id, name_overriding, context_overriding)
	_context.target_player = target_player
	_context.health_damage = health_dmg            # 保留负数以支持治疗
	_context.mental_damage = mental_dmg
	_context.source_mechanism = mechanism
	_context.source_player_id = source_id
	_context.source_custom_name = source_custom
	_context.damage_tags_mask = damage_tags_mask
	_context.custom_damage_tags = custom_tags

func execute(game_state: GameState) -> void:
	_context = _context as Context
	match _context.phase:
		0:
			## 阶段0：缓存原始伤害/治疗值（不做钳位）
			_context.cached_health_damage = _context.health_damage
			_context.cached_mental_damage = _context.mental_damage
			_context.phase = 1
		1:
			if not _context.target_player:
				complete()
				return
			## 应用生命伤害/治疗（负数代表治疗）
			if _context.cached_health_damage != 0:
				_context.target_player.apply_health_damage(
					_context.cached_health_damage,
				)
			## 应用精神伤害/治疗（负数代表治疗）
			if _context.cached_mental_damage != 0:
				_context.target_player.apply_mental_damage(
					_context.cached_mental_damage,
				)
			RuleTrans.send_player_delta_updates([_context.target_player], RenderRequest.ItemSet.EventType.ATTACK, _context.source_player_id)
			complete()
