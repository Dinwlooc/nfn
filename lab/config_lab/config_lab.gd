## 配置表实验室：按端呈现 GlobalConfig 已加载的配置表，并落一份自检报告。
## 不限制段名与键名——实验室只遍历 cfg 里实际存在的内容，模组自定义大类同样呈现。
## 零用例：只读呈现、不做断言；键位、实参与退出码由 FaceLab 承担。
extends FaceLab

#==导出==
## 当前展示的端（system / render）
@export var scope: StringName = &"system"

#==字段==
## 只读文本区
var body_text: RichTextLabel = null

#==钩子==
## 建界面并输出一次
## @override
func _build_gui() -> void:
	_build_ui()
	refresh()

## 重载后重绘：配置表已由基类重载
## @override
func _on_reload() -> void:
	refresh()

#==显示==
## 重建显示并输出到日志
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
	body_text.text = "\n".join(lines)
	push_warning("\n".join(lines))

## 把一张表展开为若干行（表头 + 每段一行键值）
## @pure
func describe_table(table_name: StringName, table: ConfigTable) -> PackedStringArray:
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
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	body_text = RichTextLabel.new()
	body_text.bbcode_enabled = false
	body_text.scroll_active = true
	body_text.add_theme_font_size_override("normal_font_size", 18)
	panel.add_child(body_text)
