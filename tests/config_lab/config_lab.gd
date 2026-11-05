## 配置表实验室：按端呈现 GlobalConfig 已加载的配置表，并落一份自检报告。
## 不限制段名与键名——实验室只遍历 cfg 里实际存在的内容，模组自定义大类同样呈现。
## 零用例：本实验室只读呈现、不做断言；引导（键位、实参、退出码）由 LabShell 承担。
extends LabShell

const ConfigTableScript := preload("res://core/Class/Config/ConfigTable.gd")

## 当前展示的端（system / render）
@export var scope: StringName = &"system"
#==vars==
## 只读文本区
var _body: RichTextLabel

#==hooks==
## 就绪：建界面并输出一次
## @override
func _lab_boot() -> void:
	if lab_id.is_empty():
		lab_id = &"config"
	# 壳的 scope 与实验室的端保持一致，无头提示才不误导
	lab_scope = scope
	_build_ui()
	refresh()

## 重载后重建：配置表已由壳重载，这里只重绘
## @override
func _lab_reload() -> void:
	refresh()

## 重建显示并输出到日志（判据走 logs_read(source="game")）
## @internal
func refresh() -> void:
	var lines: PackedStringArray = []
	lines.append("%s  scope=%s" % [lab_title, scope])
	var names: Array[StringName] = GlobalConfig.get_config_table_names(scope)
	if names.is_empty():
		lines.append("（该端没有配置表，检查 res://config/%s/）" % scope)
	for table_name: StringName in names:
		lines.append_array(describe_table(table_name, GlobalConfig.get_config_table(scope, table_name)))
	if scope == &"system":
		lines.append_array(describe_cards_consumer())
	_body.text = "\n".join(lines)
	push_warning("\n".join(lines))

## 把一张表展开为若干行（表头 + 每段一行键值）
## @pure
func describe_table(table_name: StringName, table: ConfigTableScript) -> PackedStringArray:
	var lines: PackedStringArray = []
	var entry_count: int = 0
	for section: StringName in table.sections:
		entry_count += table.get_section(section).size()
	lines.append("表 %s：来源 %s，段 %d，条目 %d" % [table_name, table.source_path, table.sections.size(), entry_count])
	for section: StringName in table.sections:
		var rows: Dictionary = table.get_section(section)
		var pairs: PackedStringArray = []
		for key: StringName in rows:
			pairs.append("%s=%s" % [key, str(rows[key])])
		lines.append("    [%s] %s" % [section, "  ".join(pairs)])
	return lines

## 下游消费示例：卡表按活动预设展开
## @pure
func describe_cards_consumer() -> PackedStringArray:
	var lines: PackedStringArray = []
	var paths: PackedStringArray = GlobalConfig.get_cards_list()
	var first: String = paths[0] if paths.size() > 0 else "<none>"
	lines.append("消费示例 get_cards_list()：%d 条模板，首条 %s" % [paths.size(), first])
	return lines

## 铺满窗口的只读文本区
## @internal
func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = false
	_body.scroll_active = true
	_body.add_theme_font_size_override("normal_font_size", 18)
	panel.add_child(_body)

