## 进入模式：菜单选定「创建游戏 / 加入游戏」后写入，主游戏场景根据此决定是否额外装载系统层。
## 创建游戏时本机同时作为服务器；加入游戏时不装载系统层，客户端只保留渲染与传输。
class_name EntryMode
extends RefCounted

## 进入模式
enum Mode {
	## 创建游戏：主游戏场景额外实例化 [System]，由其启动服务器
	CREATE,
	## 加入游戏：不实例化 [System]，场景内没有系统层
	JOIN,
}

## 当前进入模式（菜单写入，主场景根节点就绪时读取）
## @context
static var current: Mode = Mode.CREATE

## 创建游戏时请求的监听端口（0 表示随机分配）
## @context
static var server_port: int = 0
