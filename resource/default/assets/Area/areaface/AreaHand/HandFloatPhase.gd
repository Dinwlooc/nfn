## 手牌浮动相位：逐帧正弦偏移通道。不创建 Tween、不持有槽位、不参与排布装配。
extends RefCounted

#==vars==
## 正弦表
var _sine_table: PackedFloat64Array = PackedFloat64Array()
## 全局相位索引
var _global_phase_index: int = 0

#==consts==
## 正弦表长度
const TABLE_SIZE: int = 64
## 每帧全局相位递增量
const PHASE_INCREMENT: int = 1
## 相位取模掩码（TABLE_SIZE-1）
const MASK: int = TABLE_SIZE - 1
## 相邻卡牌之间的相位差
const CARD_PHASE_OFFSET: int = 4
## 浮动振幅
const AMPLITUDE: float = 0.3

#==frame==
## 构造：生成正弦表
func _init() -> void:
	_generate_sine_table()
## 生成浮动用正弦表
## @internal
func _generate_sine_table() -> void:
	_sine_table = MathUtils.generate_sine_table(TABLE_SIZE)
## 卡牌浮动扩展效果（逐帧通道：不建补间、不占槽位）
## @internal
func card_move_expand(cards: Array[RenderItem]) -> void:
	_global_phase_index = (_global_phase_index + PHASE_INCREMENT) % TABLE_SIZE
	var card_count: int = cards.size()
	for i in card_count:
		var phase_index: int = (_global_phase_index + i * CARD_PHASE_OFFSET) & MASK
		var card: RenderItem = cards[i]
		if not card:
			continue
		card.position.y += AMPLITUDE * _sine_table[phase_index]
