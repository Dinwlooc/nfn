# custom_tools · 可复用脚本工具库

**定位**：厂商中立的**机器判据**。工具是共用的度量衡，不是知识、也不是某模型的私产——**任何模型都用这里的版本，不要往自己库里拷贝**。
**位置变更**（2026-10-26 格式重构）：原 `public/tools/` 迁入 `.dsh/custom_tools/`（public 只放任务类型知识，不再收脚本）；依附旧路由（route.py）的校验器随之退役归档。

## 目录

| 类别 | 工具 | 用途 | 退出码 |
|---|---|---|---|
| **audit/ 审计** | `audit/cache-audit.mjs` | 按步统计前缀缓存命中率，定位工具集/系统提示变更造成的缓存断裂（读 DSH 会话日志，不写项目） | 0 信息性 |
| | `audit/header-audit.mjs` | 每会话请求头工具集：桥接是否生效、工具数、变更分类 | 0 信息性 |
| | `audit/net-audit.mjs` | 桥接稳态会话的净收益（token 当量）与断裂代价分位 | 0 信息性 |
| | `audit/bridge-audit.mjs` | 桥接会话专项：可见工具集、注入式断裂、断裂代价 vs 节省 | 0 信息性 |
| **measure/ 测量** | `measure/_tool_shape.py` | 形状雷达：改动是否只碰注释与顺序？三档 `SAME` / `COMMENTS-ONLY` / `CODE-DIFF`（含暂存区与**未跟踪新文件**）；`--self-test` 五条夹具（注释/节标题改名、代码改动、未跟踪、SAME、非 .gd） | 0 无 CODE-DIFF |
| | `measure/_tool_ground.py` | 信号接地：发射 / 监听 / 调用站点，给判定当证据；有声明与发射但**零 connect 点**时打印 `WARN ground: no_connect_site`（= 当前没有消费方）；`--self-test` 八条夹具（含词边界、跳过 addons、字符串提及） | 0 有命中 / 1 未找到 |
| | `measure/_tool_arch_*.py` | 架构指标工具族（扫描 / 依赖 / 调用图 / 报告），产出架构指标基线 | 0 信息性 |
| | `measure/_tool_arch_drift.py` | 基线漂移巡检：把 `0009`「已知漂移」行与当前扫描结果比对，`DRIFT <键> 文档= 实测=`；`--update` 就地改写该行；`--self-test` 验证"解析—渲染—再解析" | 0 一致 / 1 有漂移 / 2 解析失败 |
| **check/ 校验** | `check/_tool_all.py` | 一键收尾：串跑 `papers` / `refs` / `arch_drift`，逐条打印 `OK|FAIL` 与各自 RESULT，末行总账；`--fast` 跳过漂移（漂移要跑扫描）；`--self-test` 两条夹具 | 0 全绿 / 1 有失败 / 2 用法 |
| | `check/_tool_papers.py` | 知识库校验（论文 + 根层知识文件 + `meta/`）：标题 / `keywords` / 旧头部字段 / 文内修订段 / `基线：<sha8>` 可解析 / **编码损坏特征**（U+FFFD、`ðŸ`、`â€`、`Ã--`）/ 索引与磁盘一致；`--self-test` 五条坏样本必须 FAIL | 0 通过 / 1 违规 / 2 用法 |
| | `check/_tool_refs.py` | 死指针校验：①命令行里 `python/node/git` 引用的文件；②**`public/` 知识库里反引号互引的 `.md`**（多基准解析：仓库根 / `.dsh` / `.dsh/public` / 本文目录 / 默认模型库）。私人记忆与 `experiments/` 属历史记录不追改；`--self-test` 五条夹具 | 0 无死指针 / 1 有 / 2 用法 |
| **market/ 市场** | `market/market.mjs` | 插件市场检索：合并 profile 的 index.json（dshopen / vlln / jsdelivr catalog），本地缓存 12h，打印 name@version·星数·分类·摘要；`show <name>` 看引擎约束与仓库 | 0 信息性 |
| | `measure/burn-report.mjs` | 按模型汇总 token 消耗习惯：budget-watch 账本 × projcache（metaToolsModelMap+tokenUsage）；`--model <前缀>` 过滤、`--last <N>` 取尾、`--rates` 按类型单价折算成本（deepseek 分价计费必须折算，glm 总量口径） | 0 信息性 |
| **tools/ 通用** | `tools/_tool_budget.py` | budget-watch 分账汇总（纯 Python，不依赖 node）：按模型汇总 hit/miss/out 与折价 ¥、按会话排行、`--match <子串>` 只看某会话或子代理、`--prices <json>` 覆盖单价、`--json` 机读、`--self-test` 两夹具 | 0 通过 / 1 夹具失败 / 2 用法 |
| **godot/ 引擎** | `godot/_run_scene.py` | 把"Godot 场景当判据"跑成一条命令：`--timeout` 兜住 Parse Error 导致的挂死（`quit()` 不执行），只回显 `SCRIPT ERROR`/`Parse Error`/`RESULT` + 结论行；Godot 路径可 `--godot` 或 `GODOT_BIN` 指定 | 0 退出0且命中 / 1 未命中 / 2 超时或找不到引擎 |

> 注意：godot-creator 插件注册的模型面工具（`usage_report`、`project_files`）与 dsh-meta-tools（`meta_route`、`meta_sign`、`meta_tasktype`、`meta_theme`）**不在本表**——它们是插件层产物；本表只收可复制的脚本工具。
> 旧工具清理（Owner 指令 2026-10-27）：`legacy-route/`（route.py + memory/layers/route/layers/papers 校验器与夹具）已整体删除——route 被 meta_route 插件替代，读账校验被签发制 sha8 审计替代；论文格式检查如需重建，按本表输出规范新写。

用法（仓库根执行）：`python .dsh/custom_tools/<类别>/<工具>`；审计脚本用 `node .dsh/custom_tools/audit/<脚本>`；会话日志目录由 `DSH_HOME` 决定（缺省 `~/.dsh/sessions`）。

> **本机无 node**（2026-10-27 实测：`node` 不在 PATH，`.mjs` 工具全部跑不了）。凡 `.mjs` 行的能力，当前要么改用 Python 版（如 `tools/_tool_budget.py` 替代 `measure/burn-report.mjs`），要么先装 node。新写工具前仍须先查本表——`_tool_budget.py` 是在确认 burn-report 不可跑之后才写的，不是重复实现。

## 相关知识（公共论文）

audit×4 → `public/插件/0015`；measure×6 → `public/架构/0007/0009/0010`。新写任何工具前先查本表与 `.dsh/experiments/README.md`，防止重复实现。

## 校验器纪律

1. **判据必须能被证伪**：每个校验器都要有"坏样本 → FAIL"的夹具；只报 PASS 的校验器等于没有。
2. **标签不许歧义**：`CLEAN` 已拆成三档；新判据先想"最容易被读成什么"。
3. **工具不做裁决**；路径以仓库根为基准。

## 输出规范

- **结论行**：`<VERDICT> <目标> <键=值…>`。校验器用 `PASS` / `FAIL`；形状雷达用 `SAME` / `COMMENTS-ONLY` / `CODE-DIFF` / `SKIP` / `ERROR`。
- **末行**：`RESULT <工具>: <键=值…>` 汇总计数，缺省也要打印。
- **用法错误**：只打印一行 `USAGE <工具>: <一行用法>`，退出码 2。
- **退出码**：0 通过、1 有违规、2 用法错误。

## 夹具总览（工具自己被证伪过几次）

判据工具一错，引用它的结论全错；所以"有没有夹具"比"工具写得多漂亮"重要。

| 工具 | `--self-test` | 夹具覆盖的关键边界 |
|---|---|---|
| `check/_tool_papers.py` | 6 条 | 旧头部字段、**补充/追加署名**、缺 keywords、索引缺行、基线 sha 不可解析、编码损坏 |
| `check/_tool_refs.py` | 5 条 | 死脚本、活脚本、`res://` 死路径、知识库互引死/活 |
| `check/_tool_all.py` | 2 条 | 脚本缺失要判 FAIL、自测链接可跑 |
| `measure/_tool_shape.py` | 5 条 | 注释与节标题改名、代码改动、未跟踪新文件、SAME、非 `.gd` |
| `measure/_tool_ground.py` | 8 条 | 词边界、四类站点、字符串提及、跳过 `addons/`、退出码 |
| `measure/_tool_arch_drift.py` | 3 条 | 解析、渲染、再解析（含双括号回归） |
| `tools/_tool_budget.py` | 2 条 | 两模型分账求和、`--match` 过滤 |
| `godot/_run_scene.py` | 7 条 | 输出过滤（噪声/SCRIPT ERROR/RESULT）、grep 命中与未命中、`--all-output`、引擎缺失判定；**超时分支**用死循环场景实测过（`TIMEOUT`、退出码 2、子进程被杀） |

新增工具必须同时交夹具；没有夹具的工具不接受进表。

## 署名

本文件的修订历史见伴生 `README.md.revlog.md`（印章签发），正文不写署名。
