class_name DamageCommand
extends BehaviorCommand

## 伤害来源机制枚举
enum SourceMechanism {
	GENERAL,        # 一般伤害
	NEGATIVE_STATE, # 负面状态伤害
	DRAIN,          # 流失伤害
}

## 伤害命令上下文（内部类）
class Context extends CommandContext:
	## 命令参数
	var target_player: Player
	var health_damage: int
	var mental_damage: int
	var source_mechanism: int
	var source_player_id:int
	## 伤害修饰类型
	var damage_modifiers: PackedInt32Array = PackedInt32Array()
	## 缓存值
	var cached_health_damage: int
	var cached_mental_damage: int

	## 伤害修饰接口
	func modify_health_damage(new_value: int) -> void:
		if phase == 1:  # 只能在阶段0后修改
			cached_health_damage = max(0, new_value)

	func modify_mental_damage(new_value: int) -> void:
		if phase == 1:  # 只能在阶段0后修改
			cached_mental_damage = max(0, new_value)

	func add_damage_modifier(modifier_id: int) -> void:
		damage_modifiers.append(modifier_id)

	func remove_damage_modifier(modifier_id: int) -> void:
		var index = damage_modifiers.find(modifier_id)
		if index != -1:
			damage_modifiers.remove_at(index)

func _init(
	target_player: Player,
	health_dmg: int,
	mental_dmg: int,
	mechanism: int = SourceMechanism.GENERAL,
	source_id: int = -1,
	name_overriding = &"DamageCommand",
	context_overriding:Context = Context.new()
) -> void:
	super._init(source_id,name_overriding,context_overriding)
	_context.target_player = target_player
	_context.health_damage = max(0, health_dmg)
	_context.mental_damage = max(0, mental_dmg)
	_context.source_mechanism = mechanism
	_context.source_player_id = source_id

func execute(game_state: GameState) -> void:
	match _context.phase:
		0:
			_context.cached_health_damage = _context.health_damage
			_context.cached_mental_damage = _context.mental_damage
			_context.phase = 1
		1:
			if _context.target_player:
				if _context.cached_health_damage > 0:
					_context.target_player.apply_health_damage(
						_context.cached_health_damage,
						_context.source_mechanism,
						_context.source_player_id,
						_context.damage_modifiers
					)
				if _context.cached_mental_damage > 0:
					_context.target_player.apply_mental_damage(
						_context.cached_mental_damage,
						_context.source_mechanism,
						_context.source_player_id,
						_context.damage_modifiers
					)
				_context.target_player.send_pack()
			complete()
