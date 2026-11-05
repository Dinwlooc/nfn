# 实验室内核（Lab Core）

## 用途

所有实验室共用的**数据驱动**骨架：用例写在全局配置表里，交互（人）与无头（AI）跑同一份用例，代码里不出现任何用例内容。

- `LabShell`：引导壳（实参与键位、上报、退出码、配置表重载）；不认识用例语义，零用例合法。
- `LabSpec`：按实验室标识从 `GlobalConfig` 的配置表读出用例（含实验室默认值段）。
- `LabCase`：一条用例的值对象（场景 / 参数 / 步骤 / 期望 / 超时）。
- `LabRunner`：在舞台上实例化场景、施加参数、派发步骤并判定；参数只写资源副本。
- `LabStage`：通用舞台（用例列表、键盘、读数、无头引导）；每个实验室继承它。

## 用例写在配置表里

表位置由实验室场景的导出项决定（`lab_scope` / `lab_table` / `lab_id`）。两类段：

```
[lab:<实验室标识>]              ; 该实验室默认值：scene / timeout
[case:<实验室标识>:<用例标识>]   ; 单条用例，缺省键从 [lab:*] 继承
```

| 键 | 必填 | 含义 |
|---|---|---|
| `scene` | 默认段必填 | 用例场景的 res:// 路径；用例可覆盖 |
| `params` | 否 | 属性路径 → 值；路径以 . 分隔，根为场景实例；**入树前施加**，故 `_ready` 能读到；途经资源自动复制，不写回 .tres |
| `steps` | 否 | **单个数组值**，顺序稳定（不要把步骤拆成多个键，键序会随编辑漂移） |
| `expect` | 否 | 运行后的期望值，同样用属性路径 |
| `timeout` | 否 | 秒，既折算等待帧预算也作为墙钟上限，默认 5 |

步骤每项的 `kind`：

| kind | 参数 | 含义 |
|---|---|---|
| `call` | `method`、`args`、`target` | 在实例（或 `target` 指到的子节点）上调用方法 |
| `set` | `path`、`value` | 按属性路径写值 |
| `wait` | `frames` | 等若干帧并消耗帧预算 |

新增动作 = 在 `LabRunner._init` 注册一个新处理器；内核其余部分不用改。

## 引导壳契约（LabShell）

实验室与查看器都继承它；三处重复（黑幕隐藏、键位、无头退出）只此一份。

| 成员 | 角色 |
|---|---|
| 导出 `lab_id` / `lab_scope` / `lab_table` / `lab_title` / `headless_timeout` | 实验室身份与墙钟上限 |
| `case_ids() -> Array[StringName]` | 可用用例；返回空数组即零用例实验室 |
| `run_case(id) -> {tag, ok, failures, lines}` | 执行一条用例；`failures` 缺省按 `ok` 折算 |
| `_lab_boot` / `_lab_reload` / `_lab_input` | 建界面、重载后重建、自定义键位 |
| `reload_config()`（`@seam`） | 默认重载两端配置表 |
| `report_line` / `report_result` | 同时进标准输出与日志 |

- 键位：`Esc` 退出 0，`R` 先 `reload_config()` 再 `_lab_reload()`；其余键交给子类。
- 无头墙钟上限默认 30 秒，超时 `quit(2)`——把「解析错误挂死」变成可判定的失败。

## 两种运行方式

- **人**：打开实验室场景，`1-9`/`0`（第 10 条）选用例并执行，`↑`/`↓` 移动、`Enter` 执行，`R` 重跑，`Esc` 退出；结果同时写进读数区与日志。
- **AI/回归**：无头直接跑同一场景，用实参挑用例：

```
godot --headless --path project res://tests/face_lab/face_lab.tscn -- --all
godot --headless --path project res://tests/face_lab/face_lab.tscn -- --case=hit_normal
godot --headless --path project res://tests/face_lab/face_lab.tscn -- --reload --all
```

`--reload` 先重载配置表再跑（改表后一条命令验证）；无头进程本就重新读表，故它主要用于同进程复用。

判定：每条用例打印 `RESULT <lab>/<case>: PASS|FAIL`，进程退出码 = 失败用例数。判据不含观感，只看“跑得完、不炸、期望值成立”。

## 新实验室三件套

1. `tests/<名字>_lab/<名字>_lab.gd`：`extends LabStage`，只声明 `lab_id` 与标题。
2. `tests/<名字>_lab/<名字>_lab.tscn`：根 `Control` 挂上述脚本，填导出项。
3. 配置表里加 `[lab:<lab_id>]` 与 `[case:<lab_id>:*]` 段；表名/端与场景导出项一致。

## 边界

- 内核不认任何具体游戏类、场景名或用例，业务知识只在实验室自己的场景与配置表里。
- `params` 与 `set` 只改运行期副本；外部 .tres 会被 `duplicate(true)` 后 `resource_path` 置空。
- 交互模式不自动退出；无头模式跑完即退出，退出码上限为失败数。
- 超时是墙钟时间：卡在 `call` 里或没有 `wait` 的用例同样会超时。
