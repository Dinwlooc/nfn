# 0019 dsh-meta-tools v3：去登记表、签发制与路径直出

keywords: meta-tools,v3,签发,meta_sign,tasktypes,墓碑,registry,路径直出,meta_file退役

**摘要**：v2 的三处结构性负担被移除——模型登记表（registry.json + 字符常量 + turn/end 钩子）、meta_file 自定义读写（原生工具更好）、路由内联正文（压缩后即失真）。替代物：签发制（meta_sign 只记账不写文件，sha8 事后可审计）、项目任务类型注册表（模型自助、墓碑语义）、路由只发路径。

## 主张

1. **登记表（models[]）是负债不是资产**：身份以会话存储为准（0012 主张 1），登记表与磁盘/会话态三处漂移；v3 删除 registry.json、字符常量、meta.md 存根与全部注册钩子，库目录由 meta_route 首跳按会话根补建。实测佐证：v2 的 agent/created 钩子用静态 cwd，把一套库误建进 `~\.dsh\profiles\desktop\.dsh`（scaffold 记录 04:57Z 为证）——建库动作移进工具后此类错误按构造消失。
2. **原生 read/write/edit 全面优于 meta_file 自定义读写**：省 schema token、无 NOT_READ/STALE 误报路径、行号语义与模型直觉一致。护栏从"事前拦截"降级为"事后审计"是接受的成本：revlog 行内 sha8 使"改了没签"成为机器可判定不变量（签发时哈希=上一条即 unchanged 警告，不拒签——重申签是合法行为）。
3. **路由内联正文在压缩/裁剪会话里是伪造事实**：模型看到的"正文"可能来自被压缩的早期轮次。v3 只发工作区相对路径（含 `.dsh/` 前缀，模型无需拼前缀）+ 行数，上限 routeMaxFiles（40，不开放给模型配置文件——防自断路由）。
4. **墓碑（tombstone）是可逆下线的最小机制**：`.dsh/meta/tasktypes.json {active, removed}`；removed 胜过主题预设与 public/ 扫描；目录保留、路由即排除；inventory 显式列 removed 防静默去路由（0012 主张 8：弃用必须留痕并清扫引用）。
5. **检索/删除回归现成轮子**：元层检索 = `grep` 限定 `path` 至 `.dsh`（根级 grep 不下钻 `.dsh`，实测确认）；删除 = `project_files delete`（依赖编辑器会话，仅主会话可用——子代理内不做元层删除）。
6. **实测双 bug 入档**：v2 profile 目录误建库（主张 1）；node 不在 pwsh PATH，回归须用 harness 自带 node（`…\runtime\primary-runtime\dependencies\node\bin\node.exe`）。

## 适用范围

dsh-meta-tools v2→v3 迁移与后续元层工具设计；跨工作区通用。**不适用**：v2 之前的历史路由（route.py 已退役归档）。

## 复核方式

- 回归：`& <bundled node> .dsh/meta-tools/plugin/test/run.mjs`（15/15）。
- 真库干跑：composeTaskTypes 与磁盘 public/ 目录一致；tasktypes.json removed=[协作]。
- 在途会话烟测（新会话）：inventory → route 路径 → 原生 read → 真实编辑 → meta_sign → 读 .revlog.md。
