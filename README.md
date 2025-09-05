
# 游戏项目简介
本项目使用 [Godot 引擎](https://godotengine.org/) 开发，目标为实现多人卡牌对战游戏。目前仍在开发阶段。开发者属于业余爱好者，项目结构不具有参考价值。
## 项目结构概览
- **core/Script**: 定义游戏运行所需的类与场景文件。只列出已实现的类。
  - `Class/`: 类定义。
	- `Render/`: 渲染层类
		- `RenderArea/`: 渲染区域类
		- `RenderCard/`: 渲染卡牌类
		- `RenderEvent/`: 渲染事件类
		- `RenderFace/`: 渲染表面类，实际是RenderAreaFace与RenderCardFace
		- `Utils/`: (渲染)工具类
		- `/`: 渲染数据容器、指示器箭头渲染器等。
	- `System/`: 系统层类
		- `Area/`: 区域类及其子类
		- `Card/`: 卡牌类及其子类
		- `Event/`: 事件类及其子类
		- `Stage/`: 阶段类及其子类
		- `/`: 系统、属性修饰符、卡牌管理器、计时器、玩家、用户等
	- `Transport/`: 通信层类
		- `OperationRequest/`: 操作请求及其子类
		- `Serializer/`: 序列化器及其子类
  - `Global/`: 全局单例脚本。
	- `GlobalConfig/`: 全局配置
	- `GlobalConsole/`: 全局控制
	- `GlobalRegistry/`: 全局引用注册
	- `GlobalTransport/`: 全局传输
	- `GlobalTransistion/`: 全局转场
  - `Node/`: 场景节点脚本，包括菜单和游戏界面
- **official/**: 官方资源包文件夹。
  - `Area/`: 区域渲染资源。
  - `Backgound/`: 背景图资源。
  - `Card/`: 卡牌及其渲染资源。
  - `Character/`: 角色及其渲染资源。
  - `Shader/`: 着色器资源。
- **mods/**: 外部资源包文件夹。
- **addons/godot-git-plugin/**: Git 插件。
## 主要功能模块
- **系统**：由且仅由服务器端运行System类实例实现。System储存并管理游戏数据，创建Stage类数组和EventProcessor。BehaviorEvent由Stage或事件修饰器(未实现)置入EventProcessor堆栈，执行时创建RuntimeEvent，RuntimeEvent执行时对System进行操作。Area和Player等数据类提供事件修饰并通知传输层同步。
- **渲染**：由Render*类和Render*Face类共同实现。RenderArea、RenderCard等类及其子类储存传入数据、基本逻辑和信号，Face及其子类则监听信号并操作其指向的Render*类。
- **全局控制**： 全局单例GlobalConsole管理调试指令。GlobalRegistry提供引用注册接口，为传输层GlobalServer定位目标节点。
- **配置与资源文件**：全局单例GlobalConfig提供游戏配置与资源包加载。资源包内置resource_config.cfg以声明渲染资源。
- **通信**：全局单例GlobalServer处理网络连接与调用RPC，BaseSerializer及其子类负责数据打包与解包，数据容器RenderDataContainer及其子类封装客户端需要接收的数据结构。客户端通过OperationRequest上传操作请求。
- **其他**：全局单例GlobalTransition提供场景文件切换时的转场方案，工具类UIAnimationUtils预备了动画控制函数。
## 开发环境与依赖
- **Godot 引擎**：项目使用 Godot 4.4.1 开发，请确保使用兼容版本打开。
- **Git 插件**：项目中集成了 `godot-git-plugin`，用于版本控制。
## 如何运行项目
1. 安装 [Godot 4.x](https://godotengine.org/download/)。
2. 克隆本仓库到本地。
3. 使用 Godot 打开项目目录并运行。
## 贡献指南
欢迎提交 Issue 和 Pull Request。请遵循项目现有代码风格，并确保新增功能通过基本测试。
## 许可证
本项目遵循 MIT License，请参阅 `LICENSE` 文件获取详细信息。
--- 
如需进一步了解某个模块的功能或实现细节，可查阅对应 `.gd` 脚本或 `.tscn` 场景文件。
