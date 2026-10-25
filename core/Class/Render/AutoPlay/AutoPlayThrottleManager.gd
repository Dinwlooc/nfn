## 托管节流管理器：收拢稳定等待、发送冷却、in-flight 观察窗、退避与每局势发送上限；
## 以局势指纹为界重置计数，以请求代数丢弃过期回调。不含决策记忆（回合攻击标记由调用方持有）。
extends RefCounted
class_name AutoPlayThrottleManager

#== Constants ==
## 两次发送之间的最小冷却（毫秒）
const SEND_COOLDOWN_MS: int = 250
## 状态变化后的稳定等待（毫秒），覆盖网络往返与渲染请求队列延迟
const SETTLE_DELAY_MS: int = 600
## 单次请求的基础观察窗口（毫秒）
const IN_FLIGHT_TIMEOUT_MS: int = 2000
## 每次重试追加的观察时间（毫秒）
const RETRY_BACKOFF_MS: int = 500
## 同一局势下最多发送次数
const MAX_SENDS_PER_SITUATION: int = 4

#== Variables ==
## 当前局势指纹
var _situation_key: String = ""
## 当前局势最近变化时刻（毫秒）
var _situation_changed_msec: int = 0
## 是否等待已上传请求的响应
var _in_flight: bool = false
## 观察窗口起始时刻（毫秒）
var _in_flight_started_msec: int = 0
## 上次发送时刻（毫秒）
var _last_send_msec: int = 0
## 当前局势内已发送次数
var _send_count: int = 0
## 决策请求代数：丢弃线程返回的过期结果
var _serial: int = 0

#== Public Methods ==
## 取当前局势指纹
## @pure
func get_situation_key() -> String:
	return _situation_key

## 取当前请求代数
## @pure
func get_serial() -> int:
	return _serial

## 递增并取新请求代数：每次请求前调用，使旧回调过期
## @side_effect
func advance_serial() -> int:
	_serial += 1
	return _serial

## 取是否在观察窗内
## @pure
func is_in_flight() -> bool:
	return _in_flight

## 判定当前是否可发送：局势未变、不在观察窗、已过稳定等待与冷却、未达上限
## @pure
func can_send(now: int, situation_key: String) -> bool:
	if situation_key != _situation_key or _in_flight:
		return false
	if now - _situation_changed_msec < SETTLE_DELAY_MS:
		return false
	if now - _last_send_msec < SEND_COOLDOWN_MS:
		return false
	return _send_count < MAX_SENDS_PER_SITUATION

## 观察窗口：到期则放弃等待并返回 true，允许重试
## @internal
func tick_in_flight(now: int) -> bool:
	if not _in_flight:
		return false
	var timeout: int = IN_FLIGHT_TIMEOUT_MS + _send_count * RETRY_BACKOFF_MS
	if now - _in_flight_started_msec < timeout:
		return false
	_in_flight = false
	return true

## 局势变化：刷新指纹、观察窗与重试计数，并递增代数
## @side_effect
func on_situation_changed(situation_key: String) -> void:
	_situation_key = situation_key
	_situation_changed_msec = Time.get_ticks_msec()
	_in_flight = false
	_send_count = 0
	_serial += 1

## 记录一次发送：开启观察窗并计数
## @side_effect
func on_sent(now: int) -> void:
	_in_flight = true
	_in_flight_started_msec = now
	_last_send_msec = now
	_send_count += 1

## 中止观察窗口（连接或上下文不可用）
## @internal
func abort() -> void:
	_in_flight = false

## 重置节拍运行态（启停托管），并递增代数使旧回调失效
## @side_effect
func reset() -> void:
	_situation_key = ""
	_situation_changed_msec = 0
	_in_flight = false
	_in_flight_started_msec = 0
	_last_send_msec = 0
	_send_count = 0
	_serial += 1
