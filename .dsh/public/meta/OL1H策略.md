# OL1H 策略（全类型强加载；OL1H 唯一展开处）

keywords: OL1H,L席位,H席位,最多一个H,呼叫,回执,防自审,成本纪律

独立类型的唯一策略：L=自己（解析、规划、验收、落盘门禁、人类对接），H=High 推理协作者，只做高强度推理片段。其他文件提到 OL1H 一律指向本文件。

## 结构

1. 最多 1 个 H；递归最多 1 层；并行最多 1 项；可复用同一个 H。
2. **三大代码工作必经 H 审查确认**：架构、业务、算法三类任务在**收尾前**必须由 H 审查确认产出，不考虑预算、规模等任何指标；规划类呼叫时机 = 规划完成后、落盘写入前。以"改动小/已对齐/机械迁移"为由跳过 = 流程不完整。
3. 收尾回执：`H-consult: done|skipped:<原因>`；缺失即验收失败。**回执只能由真正的 H 通道产生**——用替代工具自封 `done` 等同造假。
4. **H 候选与成本纪律**（Owner 2026-10-27，按成本排序优先）：**deepseek-flash**（effort=high；L 明显不擅长的工作用 max）为首选 H；`deepseek-v4-pro` 单价约为 flash 的 **3 倍**，仅当 **flash 自身出任 L**、无其他选项时才用；（L 自己也可出任 H）。`glm-5.3` 系可作 H；`glm-4.6v` 不属候选（只能当模型测试对象）。候选表只列模型、不记额度状态——用前现探，不靠记忆。glm 系任 L 的会话不得以 pro 任 H（预算会被 3 倍价格吃掉）。
   **防自审（H 终审 2026-10-27 缺陷 7）**：若 **L 本身是 deepseek-flash**，第 2 条的架构/业务/算法终审**不得**由 flash 任 H（那是换标签的自审）——改由 `deepseek-v4-pro` 或**其他系**（如 glm-5.3）任 H；flash-as-H 只在 L 为其他模型时成立。

## 呼叫

- **指令**：压缩英文结构化（任务/输入/约束/验收），先声明返回报告字段、格式与行数。**指令中必须让 H 加载它自己的校准文件与项目规则书（`NFN-AIGC规则-*.md`），并附相关知识文件目录**——L 不替 H 消化。H 不自行检索其他元层、不改动文件。
- **封装率过高 / 注解率过低时复用 H**：复用同一个 H 子代理追加一轮代码审查，按规则书「最小封装」「原子化拆分」与注解章逐条比对；不另起新 H，不绕过。
- **首选 `subagent` 直传 `provider` + `model`**（成对，省了会继承父路由失去跨模型价值）。报 `child model selection is disabled for this tool instance`：策略只在会话组装时采样一次，老会话无补写路径——跨模型选子代理必须开新会话（老会话用 handoff 交接）。
- **呼叫失败即止损**：任何呼叫失败——route 名错、模型/额度不可用、策略拒绝、工具报错——**立即停止工作，向 Owner 报告实况**；换工具、换名字枚举、兜底方案一律禁止（`workflow` 兜底已移除，不存在后备通道）。
- **不得换工具凑 OL1H**：H 通道只认 `subagent`（`provider`+`model` 成对）与探路工具 `list_subagent_models`。二者不可用时，**禁止**改用 `subagent_fork`、`workflow`、`send_message`、同会话自问自答，或把普通子任务包装成"H 审查"——上述替代都不是 OL1H，产出不构成回执。正确动作只有一条：停止工作并报告"本会话 OL1H 通道不可用 + 缺哪个工具"。
- **route 名精确到运行时 id**（编错一律失败且不提示）：`deepseek-account`+`deepseek-flash`｜`deepseek-v4-flash`｜`deepseek-v4-pro`；`zai-coding-cn`+`glm-4.6v`。无效名：`deepseek-v41-flash`、`deepseek-v4.1-flash`、`deepseek-account-platform`。**High 默认由 Deepseek 担任**：L 为 glm 系时首呼必须显式传成对参数——省参即继承父路由被拒。
- **路由名用 `list_subagent_models` 现探**（查目录，不枚举猜名）；呼叫失败先核名字与额度，**不枚举重试**。
- 等 H 期间不阻塞，继续做简单工作；全程盯 token，必要时缩短 H 的上下文与轮次。
- **呼叫示例（照抄改内容，勿凭记忆拼参数）**：

  首呼：
  ```json
  {"description": "OL1H review of refactor plan",
   "provider": "deepseek-account",
   "model": "deepseek-flash",
   "reasoning_effort": "high",
   "prompt": "You are H ... Return EXACTLY: VERDICT:... | FINDINGS:... | NOTES:... Max N lines."}
  ```
  复用（对已存在的 H 子代理续发，`send_message` 只有 `agent_id`+`message`）：
  ```json
  {"agent_id": "<首轮返回的 subagentId>",
   "message": "Second round: review code at <路径清单>. First load your calibration + rule book <路径>. DO NOT modify files. Return EXACTLY: ..."}
  ```
  探路（发往 `list_subagent_models`，返回带路由名与 effort 档位即可用）：
  ```json
  {"model": "deepseek-flash", "provider": "deepseek-account"}
  ```

## L 开工与产出

- **开工先查既有经验**：常规任务只查同类元层——`public/<类型>/细则.md` 与本库 `<类型>/`；**边界/类型外任务必须跨库关键词检索**（`grep` 限定 `path` 至 `.dsh`；关键词命中查 `keywords:` frontmatter 行），不要只看本库本类型校准就断定"无人做过"。查到即用并标引用；查无则声明"已检索、未找到"再动手。
- **难度判断**：按难度选择多读知识 / 多请人类协作者协助 / 更自由地发挥。
- **产出与边界**：声明假设与未验证项；工作域外的发现记录上报——扩任务需 Owner 授权；测试按工作类型闸门；独立不等于自己造验收标准——该问的问一句。

## 相关

- **模型测试**属协作维度（叠加在任务类型之上，不是任务类型）：测试对象可越出单一 H，但不破坏「最多一个 H」，判据见 `public/meta/分类标准.md`。
- **改元层或规则前先读** `元层更新原则.md`：实验/测试记录不得写进入口与规则文件，入口只留指针。
