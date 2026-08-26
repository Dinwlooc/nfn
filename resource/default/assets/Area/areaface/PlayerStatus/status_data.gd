## 玩家状态数据管理器：缓存所有数值，发出数据变化信号。
extends RefCounted

signal hp_changed(old_hp, new_hp, old_max, new_max)
signal mp_changed(old_mp, new_mp, old_max, new_max)
signal ap_changed(old_ap, new_ap, old_init_ap, new_init_ap)
signal morale_changed(old_level, new_level, old_attack, new_attack, old_defense, new_defense, old_required, new_required)

var hp_max: int = 0
var hp_current: int = 0
var mp_max: int = 0
var mp_current: int = 0
var ap_current: int = 0
var ap_init_max: int = 0
var morale_level: int = 0
var morale_attack: int = 0
var morale_defense: int = 0
var morale_required: int = 0

## 从 PlayerPack 更新数据
func update_from_pack(pack: PlayerPack, initial: bool = false) -> void:
	var old_hp = hp_current
	var old_hp_max = hp_max
	var old_mp = mp_current
	var old_mp_max = mp_max
	var old_ap = ap_current
	var old_init_ap = ap_init_max
	var old_level = morale_level
	var old_attack = morale_attack
	var old_defense = morale_defense
	var old_required = morale_required
	hp_max = pack.modified_HP_max
	hp_current = pack.HP
	mp_max = pack.modified_MP_max
	mp_current = pack.MP
	ap_current = pack.AP
	ap_init_max = pack.modified_init_AP
	morale_level = pack.morale_level
	morale_attack = pack.morale_attack
	morale_defense = pack.morale_defense
	morale_required = _get_morale_required(morale_level)
	if not initial:
		if hp_current != old_hp or hp_max != old_hp_max:
			hp_changed.emit(old_hp, hp_current, old_hp_max, hp_max)
		if mp_current != old_mp or mp_max != old_mp_max:
			mp_changed.emit(old_mp, mp_current, old_mp_max, mp_max)
		if ap_current != old_ap or ap_init_max != old_init_ap:
			ap_changed.emit(old_ap, ap_current, old_init_ap, ap_init_max)
		if morale_level != old_level or morale_attack != old_attack or morale_defense != old_defense or morale_required != old_required:
			morale_changed.emit(old_level, morale_level, old_attack, morale_attack, old_defense, morale_defense, old_required, morale_required)
		return
	hp_changed.emit(0, hp_current, 0, hp_max)
	mp_changed.emit(0, mp_current, 0, mp_max)
	ap_changed.emit(0, ap_current, 0, ap_init_max)
	morale_changed.emit(0, morale_level, 0, morale_attack, 0, morale_defense, 0, morale_required)

func _get_morale_required(level: int) -> int:
	const C = preload("status_constants.gd")
	if level < C.UPGRADE_REQUIREMENTS.size():
		return C.UPGRADE_REQUIREMENTS[level]
	return 0
