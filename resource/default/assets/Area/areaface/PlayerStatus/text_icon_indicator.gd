## 图文指示器：管理一个标签和一个图标，更新文本和图标状态。
extends Control

## 文本格式，默认显示“当前 / 最大值”。
@export var text_format: String = "%d / %d"
## 数值标签。
@onready var label: Label = $Label
## 图标控件（可选，若不存在则忽略）。
@onready var icon: Control = $Icon

## 更新标签文本。
func update_text(current: int, max: int) -> void:
	if label:
		label.text = text_format % [current, max]

## 更新图标（例如改变纹理或颜色），可根据需要扩展。
func update_icon(new_texture: Texture2D = null, new_color: Color = Color.WHITE) -> void:
	if icon and icon is TextureRect:
		if new_texture:
			(icon as TextureRect).texture = new_texture
		(icon as TextureRect).modulate = new_color
