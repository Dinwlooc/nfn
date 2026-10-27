# 物品操作请求合并为 ItemsOperation

keywords: 操作请求,ItemsOperation,枚举分派,标准态,默认区域,玩家区,序列化标识,扩展点

基线：ece24b6+（2026-10-27）

问题：出牌 / 弃牌 / 响应声明三类**物品操作**请求各自成内部类，参数面互相重叠（卡牌 id、卡牌 id 数组、目标玩家 id）；类名同时承担线上类型标识与阶段分派键，新增一类官方操作就要加内部类、加序列化槽位、并在五个阶段的分派里加分支。**放弃响应不在其列**——它不带任何物品参数，是各阶段通用的「放弃」信号，保持独立类型 `OperationRequest.AbandonResponse`。

决策：物品操作收敛为单一 `ItemsOperation`（`OperationRequest` 的子类，基类只保留来源、生命周期、信号与分派钩子）：

- **类型即枚举**：`enum Type { CUSTOM, PLAY_CARD, DISCARD_CARDS, RESPOND_CARD }`。枚举 0 是自定义模式，额外携带 `custom_name: StringName`；官方类型不写名。
- **参数面取最广**：源区域、源 ids、目标区域、目标 ids，四个字段全部公开可写。
- **标准态范式**：字段在构造时按操作类型物化（`reset_to_standard()`），读取时不再有「空＝未指定」的隐式补全。出牌标准态：源区域 `hand`（请求者手牌区）、目标区域 `players`（玩家区）；弃牌与响应声明标准态：源区域 `hand`、无目标区域；自定义标准态：两者皆空。弃牌不设目标区域——弃置终点由弃牌命令决定，请求层不发明消费方不认的语义。
- **目标 id 的标准值是 0**：出牌请求无论是否指定目标都携带 `target_ids = [target_id]`，缺省写 0 表示无目标（沿用项目惯例，不用 -1 表示「未填」）。不需要目标的阶段**主动无视该字段**：群体攻击阶段不再把「指向他人」当作错误而取消请求。
- **工厂收口写法**：`play_card` / `discard_cards` / `respond_card` / `custom` 四个静态工厂，调用方只写业务参数。
- **分派键独立于类名**：`get_operation_name()` 返回官方固定名或 `custom_name`（`AbandonResponse` 返回 `abandon_response`）；`ItemsOperation.get_class_name_static()` 恒为 `items_operation`。阶段 `match request.get_operation_name()` 的字符串字面量保持原样，故新增自定义操作不必改枚举、不必改序列化器，只要在接住它的阶段加一条 case。

区域归属规则（请求只带区域名与 id，不带归属玩家）：私有区域（`hand` / `defence` / `ability`）解析到请求者 `source_player_id`；公共区域（`center` / `discard` / `drawing`）解析到公共玩家 id（`PUBLIC_PLAYER_ID`）；**玩家区 `players` 不是 Area**——系统层由 `PlayersManager` 承载，渲染层才是 `RenderArea`，其 id 数组即玩家 id。跨玩家区域寻址一律经「玩家区 + 玩家 id」表达。

序列化契约：来源玩家 id → 类型（int）→ 自定义名（仅 `CUSTOM` 时写）→ 源区域 → 源 ids（`PackedInt32Array`）→ 目标区域 → 目标 ids。注册表两槽：`[ItemsOperation, OperationRequest.AbandonResponse]`。网络不持久化，故标识无兼容包袱，槽位顺序只受「新类型只追加、不插队」的书写规则约束。

未采用：把区域分类做成枚举辅助（`SELF`/`PUBLIC`/`PLAYERS`）——当前没有消费方读区域字段，属冗余实现；区域规则写在本页与类注释里，等有通用区域构造方时再抽。

代价与未验证：静态类型只经解析、编辑器重载与主场景启动（`game_status=live`）验证，未跑完整对局（出牌 / 弃牌 / 群体攻击 / 濒死 / 守区攻防阶段的运行期行为未逐条实测）；序列化往返只经代码对称性核对，未做实际收发。`deserialize_with_registry` 对越界标识无守卫。另 `PlayerPack.disallowed_operations` 仍是空的扩展点，其键可直接沿用本类的操作名。
