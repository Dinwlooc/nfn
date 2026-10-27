---
keywords: Agent桥接, AutoPlayManager, NPCPeerManager, AgentManager, 架构实例, 门面语义
---

# 架构实例归档：Agent 桥接重构（AutoPlayManager/NPCPeerManager → AgentManager）
性质：记忆（细节教训史；方法论结论在 `glm/glm-5.3-flash/架构/校准.md`，此处只留实例与过程）。
**署名**：glm-5.3-flash ｜ 2026-10-25

## 一、门面语义层级与瘦身三步（2026-10-24）

- 渲染层与系统层管理器体积差的根因是**门面语义层级**：NPCPeerManager 走 GameState 语义门面（`get_hand_area` 等）一句取数；AutoPlayManager 走 RenderContext 结构门面，深链加空值检查放大 3-5 倍。解法是先给 RenderContext 补齐与 GameState 对位的门面方法，再迁快照构造——先立语义层，后搬逻辑，行为零变化。
- 规则镜像（响应权判定、手牌上限）与取数分离：取数进门面，规则留决策域，日后系统层经同步暴露答案时可整行删除镜像。
- 迁移时守规则书「严格复现原逻辑」：`get_player_speed` 由 `RenderAreaPlayers.local_player` 改为按 id 扫描，属等价改写，需向 owner 点名报告而非静默。
- 第 2 步落地：快照构造器独立为 `RenderDecisionSnapshot`（静态 build + 规则镜像），AutoPlayManager 减至 19 个方法，与 NPCPeerManager 快照构造形成对称对；空守区归属按项目约定返回字面量 0，不设哨兵常量。
- 第 3 步落地与 H 复核：节拍状态机独立为 `AutoPlayGate`（can_send/advance_serial/is_in_flight/tick_in_flight/on_situation_changed/on_sent/abort/reset），AutoPlayManager 减至 16 个方法、仅剩编排与回合攻击标记。
- **H 复核的实际收益（owner 提醒后补做）**：deepseek-H 对拆分做行为等价复核，抓到 2 处我真漏掉的漂移——①请求代数只在局势变化时递增，abort 后重发与滞留旧回调同代数，会双重上传（修复：每次请求前 advance_serial）；②观察窗过期后提前 return，丢失旧代码"当帧顺落到发送判定"的语义（修复：is_in_flight 且未过期才拦截）。
- 呼叫 H 的流程当时参数：subagent 须 provider+model 成对（deepseek-account / deepseek-v4-pro / high）；指令为压缩英文结构体——任务、三文件清单、**逐字复述的旧语义**、点名边缘情形、限定返回报告字段与行数、禁改文件。旧代码已不在盘上时，复述旧语义是指令的核心载荷。（model 取值是当次记录非配方，见 `public/0002-OL1H卡.md`。）
- 命名对齐（owner 反馈）：新类名须先扫全库 `class_name` 词表——纯数据 `*Data`/`*Pack`，有状态协调者 `*Manager`，静态构造者 `*Factory`/`*Builder`（先例 SimpleAttributeBuffBuilder、RenderAreaFactory），环境参数 `*Context`。据此更名 RenderDecisionSnapshot→RenderDecisionBuilder、AutoPlayGate→AutoPlayThrottleManager；Snapshot/Gate 在词表中无先例，不采用。

## 二、合并为 AgentManager（2026-10-25）与工作缺陷（Owner 点名）

- 任务：两管理器合并为 AgentManager（薄壳 + 两层各自模块），注册进 GlobalRegistry（新 `AGENT_MANAGER_TYPE`），系统层由新 AgentTrigger 从注册表接线，渲染层由 RenderControl 直接部署；System 去 `@export` 计时器，由 TimerTimeoutTrigger 从注册表取得并注入。
- 首轮交付缺陷（Owner 逐条点名后修正）：
  - **过度封装**：两层逻辑全部内联进 414 行单类，而非壳 + 模块。违反规则书 4.1「最小封装」。修正后壳 55 行。
  - **缺乏能力化**：逐行照搬旧代码，把原 AutoPlayManager 的网络就绪检查（`_is_connection_ready`）带进决策模块——Owner 质询"Agent 为什么关心网络"后删除。该检查还实际有害：离线场景托管被哑掉。
  - **H 用法偏差**：H 只在落盘前复核，抓行为漂移有效；结构组织错了它拦不住。Owner 裁定：结构选型有犹豫时提前抛给 H 讨论。
- 过程中修的自引入错误：`set_unhandled_input` 笔误（Node 正确 API 为 `set_process_unhandled_input`，两处漏改其一曾在运行期卡 pre-live break）；`AgentRenderModule` 是 RefCounted 无 `multiplayer` 属性，经 `_render_control.multiplayer` 取。
- 注册表时序坑：AgentManager 作为根末子节点，其 `_ready` 晚于 RenderControl——`connect_singleton` 走注册表信号延迟回调，会在 `register_singleton` 发射的同一调用栈里同步执行 `initialize_render`。`_ready` 里若先注册后禁用 `set_process(_unhandled_input)`，禁用会覆盖初始化开启的状态。**禁用必须先于注册**。
- 通道事实（同日复验）：shell 的 Move/Remove 对项目树被沙箱拒；`filesystem_manage` 的 move/remove 因无关超大 tres（LineEdit_theme.tres）发现失败被拦。可行链路：write 新位 → `project_fs remove` 旧位入回收站（.uid 伴生文件一并）→ `filesystem_manage scan` 让编辑器重载外部改动。空目录删除无工具可用，留 Owner。
- 遗留：`core/Class/Render/AutoPlay/` 空目录待 Owner 手动删；架构说明 0003 未同步本次重构。

---
**署名**：glm-5.3-flash ｜ 2026-10-25（自 meta/架构 校准文件迁入：一节为原"首例"全文，二节为合并任务与缺陷记录全文）

 