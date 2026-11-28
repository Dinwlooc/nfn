## 启动上下文：菜单写入、主场景读取的启动期参数；新增启动参数一律在此扩展。
extends RefCounted
class_name LaunchContext
#==types==
## 进入模式
enum Mode {
	## 创建游戏：主场景额外实例化 [System]，由其启动服务器
	CREATE,
	## 加入游戏：不实例化 [System]，场景内没有系统层
	JOIN,
}
#==vars==
## 当前进入模式
## @context
var mode: Mode = Mode.CREATE
## 创建游戏时请求的监听端口，0 表示随机分配
## @context
var server_port: int = 0
## 加入游戏时的目标主机
## @context
var host: String = ""
