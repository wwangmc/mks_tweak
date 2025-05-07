
{
	"taskType": "input",
	"content": "xxx"
}
写入内容至剪切板（需要剪切板中已有内容）
{
	"taskType": "setClip",
	"content": "nb666"
}

{
	"taskType": "getClip",
	"content": ""
}
悬浮窗
{
    "taskType": "toast",
    "content": {
        "type": "success",
        "content": "nb666",
        "duration": 2.5,
        "position": "top",  
        "fontSize": 16                 
    }
}
获取设备信息（cotent可选 1屏幕大小 2屏幕处于横屏或竖屏 3screen scale 30 设备信息 型号版本等 31电池信息）
{
	"taskType": "deviceInfo",
	"content": "30"
}
执行命令
{
	"taskType":"runShell",
	"content": "ls /var/root"
}
获取应用沙盒目录
{
	"taskType":"sandboxPath",
	"content": "com.liguangming.Shadowrocket"
}
点击事件
{
	"taskType":"touch",
	"content": {
		  "x": 119,
		  "y": 871,
		  "index": 1,
		  "type": "down"
	}

}

查ip
{
	"taskType":"runShell",
	"content": "curl -s http://ip-api.com/json"
}
切换app
{
	"taskType":"switchApp",
	"content":"com.liguangming.Shadowrocket"
}
关闭键盘
{
    "taskType": "hideKeyboard",
    "content": ""
}
输入文本
{
    "taskType": "input",
    "content": "nb666"
}
左移光标
{
    "taskType": "moveCursor",
    "content": "-2"
}
右移光标
{
    "taskType": "moveCursor",
    "content": "2"
}