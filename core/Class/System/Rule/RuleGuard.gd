## 规则守卫静态工具类
## 提供一套通用的 has_* 纯函数，用于卫语句中集中检查并收集错误信息。
## 使用 and 利用短路机制来书写。
@abstract
extends Object
class_name RuleGuard

## 错误信息包装类，用于在卫语句中传递错误文本（引用方式）
## @record
class ErrorMessage:
	var text: String = ""
	## @internal
	func set_text(msg: String) -> ErrorMessage:
		text = msg
		return self
	## @internal
	func clear() -> void:
		text = ""

# === 通用有效性检查 ===
## @external
static func has_non_null(obj: Object, error: ErrorMessage, msg: String = "对象为空") -> bool:
	if obj == null:
		error.text = msg
		return false
	return true

# === 针对 Player 和 Area 的检查 ===
## @external
static func has_valid_player(player: Player, error: ErrorMessage, msg: String = "玩家无效") -> bool:
	return has_non_null(player, error, msg)
## @external
static func has_valid_area(area: Area, error: ErrorMessage, msg: String = "区域无效") -> bool:
	return has_non_null(area, error, msg)

# === 针对卡牌 ID 数组的快捷检查 ===
## @external
static func has_valid_card_ids(ids: PackedInt32Array, error: ErrorMessage, msg: String = "卡牌ID数组为空") -> bool:
	if ids.is_empty():
		error.text = msg
		return false
	return true
