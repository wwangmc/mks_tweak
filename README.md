获取截屏
GET http://192.168.31.177:8080/screenshot


写入内容至剪切板（需要剪切板中已有内容）
POST http://192.168.31.177:8080/setClip
{
  "text": "3838测试11"
}



获取剪切板内容
GET http://192.168.31.177:8080/getClip


弹窗
POST http://192.168.31.177:8080/alert
{
  "title": "success",
  "text": "nb666",
  "time": 2.5
}

悬浮窗 
POST http://192.168.31.177:8080/toast
{
	"type": "success",
	"content": "nb666",
	"duration": 2.5,
	"position": "top",  
	"fontSize": 16                  
}

获取设备信息（type可选 1屏幕大小 2屏幕处于横屏或竖屏 3screen scale 30 设备信息 型号版本等 31电池信息）
GET http://192.168.31.177:8080/deviceInfo?type=1

执行命令 （可搭配curl查询ip）
POST http://192.168.31.177:8080/runShell
{
	"cmd": "ls /var"
}

点击事件(
	#define TOUCH_UP 0
	#define TOUCH_DOWN 1
	#define TOUCH_MOVE 2
)
POST http://192.168.31.177:8080/touch
{
	"x": 119,
	"y": 871,
	"index": 1,
	"type": "down"
}

获取应用沙盒目录
GET http://192.168.31.177:8080/sandboxPath?pkgName=com.liguangming.Shadowrocket

切换app
GET http://192.168.31.177:8080/switchApp?pkgName=com.liguangming.Shadowrocket

关闭键盘
GET http://192.168.31.177:8080/hideKeyboard

输入文本
POST http://192.168.31.177:8080/input
{
    "text": "nb666"
}

移动光标(负数左移 正数右移)
GET http://192.168.31.177:8080/moveCursor?num=-2

删除文本
GET http://192.168.31.177:8080/del?num=2

home键
GET http://192.168.31.177:8080/pressHome

双击home
GET http://192.168.31.177:8080/doublePressHome
