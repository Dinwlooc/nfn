## 游戏提示生成器：中央区就位后输出开局提示文本，开局即清空。
## 后续在此承接主动情景感知，为新手玩家提供分步指导。
extends CenterTextProvider

#==consts==
## 开局提示的翻译键
const HINT_KEY: StringName = &"nfn:hint_click_center_start"
## 隶属区域：中央区
const AREA_NAME: StringName = RenderArea.DefaultArea.CENTER
## 隶属玩家：公共视角的系统玩家
const AREA_PLAYER_ID: int = RenderContext.PUBLIC_PLAYER_ID

#==contract==
## 部署监听：接入区域注册与开局标志
## @override
func setup(p_context: RenderContext) -> void:
	super.setup(p_context)
	context.area_manager.render_area_registered.connect(_on_area_registered)
	context.state_manager.game_started_notified.connect(_on_game_started)

#==hooks==
## 中央区注册：推送开局提示
## @signal_listener
func _on_area_registered(area_name: StringName, _area: RenderArea, player_id: int) -> void:
	if area_name != AREA_NAME or player_id != AREA_PLAYER_ID:
		return
	context.text_manager.push_text(AREA_NAME, AREA_PLAYER_ID, provider_id, GlobalConfig.get_translation(HINT_KEY))

## 开局：清空本生成器的提示文本
## @signal_listener
func _on_game_started() -> void:
	context.text_manager.clear_text(AREA_NAME, AREA_PLAYER_ID, provider_id)
