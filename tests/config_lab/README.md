# 配置表实验室（Config Lab）

## 用途

按**端**展示 `GlobalConfig` 实际加载到的配置表：系统端、渲染端各一个场景。实验室不识别任何具体表名、段名或键名，只把 `.cfg` 里实际存在的内容照原样列出，因此模组自定义的大类可以直接在这里自测。

启动：

```
res://tests/config_lab/config_lab_system.tscn
res://tests/config_lab/config_lab_render.tscn
```

按键：`R` 重载配置表并刷新，`Esc` 退出。

## 显示内容

| 行 | 含义 |
|---|---|
| `scope=` | 当前实验端 |
| `表 <名>：来源 <路径>，段 <数>，条目 <数>` | 一张 cfg 表的规模与出处 |
| `[段] 键=值 …` | 该段的全部键值，按 cfg 原序 |
| `消费示例 get_cards_list()` | 系统端专有：卡表按活动预设展开的模板条数与首条路径 |

## 目录与叠加

| 端 | 本地根 | 用户根（可选叠加） |
|---|---|---|
| 系统端 | `res://config/system/` | `user://config/system/` |
| 渲染端 | `res://config/render/` | `user://config/render/` |

叠加开关在 `res://config/bootstrap.cfg` 的 `[config_paths] use_user_config`：为 `true` 时用户根后加载、覆盖本地同名键；默认 `false`，只用本地根。资源包清单是另一个 tier-0 文件 `res://config/packs.cfg`。

输出走 `push_warning`，判据读 `logs_read(source="game")`，不再落盘。

## 与模组

- 配置表不限制段名：模组可以新增自己的大类段，只要下游对象按自己的语义去取。
- 系统端根为 `res://config/system/`，渲染端根为 `res://config/render/`；文件名即表名（`cards.cfg` → 表 `cards`）。
- 顶层段与键不加命名空间；作为**资源标识**的值（如卡表预设 `nfn:default`）才带命名空间。
- 资源路径仍走资源包注册表（`resource_config.cfg`），配置表只放非资源数据。

## 边界

- 实验室只读、只呈现，不做断言，也不修改任何表。
- 实验室不写盘；输出只进日志，日志文本可能被引擎截断。

## 实现约束

- 全部变量显式类型；面板用 `RichTextLabel` 纯文本呈现，不引入主题依赖。
- 通过 `GlobalConfig.get_config_table_names()` 遍历，避免把表名单写死在场景里。