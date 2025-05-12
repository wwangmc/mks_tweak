获取截屏
GET http://{ip}:8081/screenshot


写入内容至剪切板（需要剪切板中已有内容）
POST http://{ip}:8081/setClip
{
  "text": "3838测试11"
}



获取剪切板内容
GET http://{ip}:8081/getClip


弹窗
POST http://{ip}:8081/alert
{
  "title": "success",
  "text": "nb666",
  "time": 2.5
}

悬浮窗 
POST http://{ip}:8081/toast
{
	"type": "success",
	"content": "nb666",
	"duration": 2.5,
	"position": "top",  
	"fontSize": 16                  
}

获取设备信息（type可选 1屏幕大小 2屏幕处于横屏或竖屏 3screen scale 30 设备信息 型号版本等 31电池信息）
GET http://{ip}:8081/deviceInfo?type=1

执行命令 （可搭配curl查询ip）(可搭配 uiopen命令实现打开url)
POST http://{ip}:8081/runShell
{
	"cmd": "ls /var"
}

点击事件(
	#define TOUCH_UP 0
	#define TOUCH_DOWN 1
	#define TOUCH_MOVE 2
)
POST http://{ip}:8081/touch
{
	"x": 119,
	"y": 871,
	"index": 1,
	"type": "down"
}

获取应用沙盒目录
GET http://{ip}:8081/sandboxPath?pkgName=com.liguangming.Shadowrocket

切换app
GET http://{ip}:8081/switchApp?pkgName=com.liguangming.Shadowrocket

关闭键盘
GET http://{ip}:8081/hideKeyboard

输入文本
POST http://{ip}:8081/input
{
    "text": "nb666"
}

移动光标(负数左移 正数右移)
GET http://{ip}:8081/moveCursor?num=-2

删除文本
GET http://{ip}:8081/del?num=2

home键
GET http://{ip}:8081/pressHome

双击home
GET http://{ip}:8081/doublePressHome
