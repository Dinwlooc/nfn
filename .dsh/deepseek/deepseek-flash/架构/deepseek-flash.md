# 架构 · 我的经验

keywords: 架构,扩展点,数据类广播,signal范式,指标口径,读代码优先

- **公共知识**（初始化读）：`public/架构/`——0003 架构说明、0007 指标定义与评估框架、0009 指标基线、0010 判读（正文已无版号与状态，改动看伴生 `.revlog.md` 的印章）。
- **偏好档案**：Dinwlooc 的人类库已移出 `.dsh`；选型偏好来源待 Owner 重建档案。
- **教训**：歧义解决后才写入；一般不用跑测试；理解错误或选型失误时才更新知识。
- **数据类广播携带自身**（法 v1.0.4 §4.3）：数据类（*Data / *Pack / *Request 等）发出的广播信号应携带该类自身对象；监听方用未绑定方法连接，使连接与断开使用同一 Callable。用 bind 把数据对象藏进 Callable 会破坏 @signal_listener / @signal_mediator 的成对管理。
- **孤立野生范式**：CONNECT_ONE_SHOT 已有 @signal_once 范式；发现使用未按范式书写时，评价为"孤立野生范式"，风险源于缺乏一致性检验（范式声明与实现不一致），不得用"若去掉该标志则同类"推演。
- **改 .gd 的验证链**：`scan` 注册 class_name → `find_symbols` 逐文件验解析 → `project_run` 看 `status="live"` → `stop`。编辑器日志源含历史条目，不能凭它判当前错误。
- **按名字 grep 不到 ≠ 不存在**：`.gitignore` 的目录（`Unused/`、`addons/`）rg 不进；序列化原语在 C#（`SerializationUtil`），先 `glob` 定位再读 `.cs`。
