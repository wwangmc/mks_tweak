可搭配iproxy实现usb有线传输 命令iproxy 8081:8081 以下api的ipHost可全替换localhost iproxy有依赖环境具体上网搜 一般装完爱思就有

[获取截屏] quality图片质量越低越差但会更流畅
GET http://{ip}:8081/screenshot?quality=0.3

[获取截屏流式返回]
GET http://{ip}:8081/screenshotStream?quality=0.3&fps=15


[输入文本]
POST http://{ip}:8081/input
{
    "text": "nb666"
}

[执行命令] （可搭配curl查询ip）(可搭配 uiopen命令实现打开url)
POST http://{ip}:8081/runShell
{
	"cmd": "ls /var"
}

[切换app]
GET http://{ip}:8081/switchApp?pkgName=com.liguangming.Shadowrocket

[卸载应用]
GET http://{ip}:8081/uninstall?pkgName=com.liguangming.Shadowrocket

[关闭后台应用](模拟app switcher视图滑掉应用 回到桌面再调用才能看到视图中找不到应用 不回桌面也能正常关闭)
GET http://{ip}:8081/killByBID?pkgName=com.liguangming.Shadowrocket

[关闭所有后台应用](模拟app switcher视图滑掉应用 post参数为排除在外的应用不传就全关)
POST http://{ip}:8081/killAll
["com.liguangming.Shadowrocket"]

[home键]
GET http://{ip}:8081/pressHome

[双击home](切换出应用列表视图)
GET http://{ip}:8081/doublePressHome

[获取应用信息]（可判断应用下载状态 未下载 下载中 已安装 也可获取应用沙盒目录）
GET http://{ip}:8081/appInfo?pkgName=com.liguangming.Shadowrocket

[获取获取所有应用信息 包括越狱插件 上面的也是]
GET http://{ip}:8081/apps

[获取应用商店历史登陆过的苹果账号](返回值中isActive字段为true时说明是当前登陆的)
GET http://{ip}:8081/accounts

[向当前输入框输入当前苹果账号的密码](注意需要数据库中appleinfo表中存在该账号 没有就自己加)
GET http://{ip}:8081/inputPwd

[获取剪切板内容]
GET http://{ip}:8081/getClip

[写入内容至剪切板](需要剪切板中已有内容) {没啥用要输入就用上面的input}
POST http://{ip}:8081/setClip
{
  "text": "3838测试11"
}

[关闭键盘]
GET http://{ip}:8081/hideKeyboard


[移动光标](负数左移 正数右移)
GET http://{ip}:8081/moveCursor?num=-2

[删除文本]
GET http://{ip}:8081/del?num=2

[弹窗]
POST http://{ip}:8081/alert
{
  "title": "success",
  "text": "nb666",
  "time": 2.5
}

[悬浮窗] 
POST http://{ip}:8081/toast
{
	"type": "success",
	"content": "nb666",
	"duration": 2.5,
	"position": "top",  
	"fontSize": 16                  
}

[获取设备信息]（type可选 1屏幕大小 2屏幕处于横屏或竖屏 3 screen scale 30 设备信息 型号版本等 31 电池信息）
GET http://{ip}:8081/deviceInfo?type=1


[点击事件](
	type可选 
	up 松开 
	down 按下
	move 移动
)
POST http://{ip}:8081/touch
{
	"x": 119,
	"y": 871,
	"index": 1,
	"type": "down"
}

[开启vpn]
GET http://{ip}/turnOnVPN

[关闭vpn]
GET http://{ip}/turnOffVPN

