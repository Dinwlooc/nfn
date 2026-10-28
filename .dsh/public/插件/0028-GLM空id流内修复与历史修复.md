# 0028 GLM 空 tool-call id：流内补 id + 历史修复

keywords: 空id,glm,toolCallId,stream-sanitizer,zstd,会话修复,seq,tool-call

**摘要**：GLM 4.6V 再次把 `id`/`name` 都发成空串，`session-9b7f69c8` 在 seq 882/883 处留下空 tool-call 并卡死。根因与 0026 一致且本轮拿到了原始行证据。处置分两半：**未来**用 `dsh-stream-sanitizer` 在 `llm/stream` 里补 id（实测 7/7 夹具；该件已于 2026-10-29 **退役**，改由 `dsh-healer` 接管，见 §6）；**过去**用两个脚本解码多帧 zstd、删掉空 tool-call 块与配对 tool/call。全库扫描 242 个会话，13 个同病，全部修复并各留 `.bak`，复扫 0 残留。

## 1. 证据（原始行，非推断）

会话 `session-9b7f69c8-06c7-4ca0-815f-f6e0ee455c8f`（项目 `D:\游戏开发\项目\工程`，provider `zai-coding-cn`，model `glm-4.6v`）：

```
seq 882 assistant/message  content[2] = {"type":"tool-call","id":"","name":""}
seq 883 tool/call          data = {"callId":"","name":"","arguments":"{}"}
（seq 884 的 tool/result 从未写成功 → 文件到 883 结束）
```

`assistant/message` 的 `content` 同时带 `reasoning` 与 `text`，说明模型在"思考 + 说了一段话"之后挤出一个**没有名字**的工具调用；provider 侧 `stopReason: "stop"`。

## 2. 为什么 0026 的处置没挡住

`dsh-session-repair` 是**读侧**修复（面板按钮 + 只读诊断工具），它救的是历史，不拦新写入；本插件的空 id 来自 provider，适配层 `dsh-llm-pi-ai` 仍然原样透传（`block-end` 的 `block.id = brandString(event.toolCall.id)`，无兜底）。于是"装完 repair 之后照样崩"是符合预期的——缺的是**写入侧兜底**，而上游补丁尚未落到这个版本。

## 3. 未来：`dsh-stream-sanitizer@0.1.0`

- 挂在 `llm/stream` 瀑布，拿 `next()` 的流做**纯变换**：`tool-call-delta` / `block-end` 的 id 为空 → 补一个本流稳定 id（同一 `index` 共用）；`name` 为空不动；其它 chunk 原样透传。
- 效果：空 name 仍会报 `unknown tool`，但**带非空 id 落盘**，回合正常失败、会话不再锁死。
- 可观测：`GET /stream-sanitizer/api/stats` → `{enabled, stats:{fixed, streams, lastFixAt, lastIndex}}`（**退役后该端点已随插件卸载，不可再访问**）。
- 回归：`node dsh-plugins/dsh-stream-sanitizer/test/run.mjs` → **7/7**（补 id、跨 chunk 同 id、正常 id 不动、空 name 不动、非工具 chunk 透传、计数、apply 接线 + 关闭透传）。

## 4. 过去：修复脚本

`dsh-plugins/dsh-stream-sanitizer/scripts/`：

- `scan-all-sessions.mjs <sessions dir>`：只读扫描，输出 `scanned / decode failures / poisoned` 与逐条 `seq + 类型`。
- `repair-empty-toolcall.mjs <session file> [--apply]`：解码多帧 → 删 `assistant/message` 里 `id===''` 的 tool-call 块、删 `id===''` 的 `tool/call` 行 → 单帧重压 → 原子替换（先 `.bak-<epoch>` 备份）→ 重解码自检。

**多帧 zstd 是硬门槛**：Node 的 `zstdDecompressSync` 只解第一帧（会静默截断）；脚本自己走帧头 + block 头算帧尾，逐帧解压。

实测（2026-10-28）：

| 项 | 值 |
|---|---|
| 扫描会话 | 242（0 解码失败） |
| 同病会话 | 13（全部是 `assistant/message` 空 tool-call + 紧邻空 `tool/call`） |
| 修复 | 13/13，各留 `.bak` |
| 复扫 | 0 残留 |
| 首个手修会话 | `session-9b7f69c8…`：885 行 → 884 行，0 空 id |

## 5. 风险与未验证

1. **重压成单帧**：修复后文件由多帧变单帧，读取路径按帧顺序读，理论等价；但"应用打开时是否会以旧帧追加"未验证。
2. **被修的会话需要重开**：应用里若仍持有旧内存态，需关闭该会话标签再打开（必要时重启）。
3. **未在真实 GLM 流上观察到 `stats.fixed > 0`**：插件刚装，尚未遇到新的空 id 响应；夹具覆盖了形状，但"provider 真实发空 id 时补得上"仍是推断。
4. **只处理 `id` 为空**：若未来出现"id 有效但 name 为空"且上游仍崩，需要另做（当前判断是该形态不致命）。
5. 备份文件留在会话目录里（`*.bak-<epoch>`），确认无误后可删。

## 6. 退役记录（2026-10-29）

Owner 判定 healer 防御可信后，**本插件的插件角色退役**，改由社区件接管：

| 项 | 状态 |
|---|---|
| `dsh-stream-sanitizer` | 已 `remove_bundle`，profile 无行；`package.json` 标 `[RETIRED]`、版本 0.1.1，仅留历史 |
| 取代者 | `dsh-healer@0.1.0`（`mode: fail-safe`；规则 `tool-call-name` / `orphan-tool-result` 开；400 自愈并重试一次） |
| 取代者的优势 | 在 **wire 层**修复、不改持久化日志，因此**已被毒化的旧会话也能救**；本插件只在写入侧补 id |
| 安装门槛 | healer peer 要求 `@deepseek-ai/dsh-llm 0.2.0-rc.2`，本机 0.2.1-rc.3 → 已按 Owner 授权落一条**精确版本豁免**（`list_version_exemptions` 可查） |
| 保留物 | `scripts/`（`scan-all-sessions` / `repair-empty-toolcall` / `analyze-session-tail` / `analyze-loop`）——不依赖插件装配，退役后实跑：245 会话、0 解码失败、0 残留 |

**残留风险（如实记）**：healer 按**空 `name`** 剔除整块；若将来出现"`id` 空、`name` 非空"的畸形响应，它不覆盖。该形态至今未实测出现（GLM 两次都是 id+name 双空）。