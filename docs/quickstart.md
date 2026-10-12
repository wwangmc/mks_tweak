# 快速入门

[返回项目首页](../README.md) · [接口参考](api.md) · [编译说明](github-actions.md)

## 准备工作

- 一台已越狱、可安装 `.deb` 且支持 tweak 注入的 iOS 设备。
- 与越狱环境匹配的 MKS 安装包；rootfull、rootless、RootHide 不能混用。
- 一台电脑，以及同一可信局域网或 USB 数据线。
- 使用 USB 时，需准备 `iproxy` 和可工作的设备 USB 通信环境。

安装包声明依赖 `mobilesubstrate`。请由设备包管理器检查和处理依赖；其他注入框架是否满足该依赖，以实际越狱环境配置为准。

## 下载与安装

1. 打开仓库的 [Build Theos packages](https://github.com/wwangmc/mks_tweak/actions/workflows/build.yml) 工作流。
2. 选择目标代码版本的运行记录，确认需要的 `Package (...)` 任务成功。
3. 在运行页面的 **Artifacts** 区域下载 `mks-rootfull`、`mks-rootless` 或 `mks-roothide`。下载通常需要登录 GitHub，具体操作见 [GitHub 官方说明](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts)。
4. 解压 ZIP 后获得 `.deb`，传到手机并用越狱包管理器打开安装。
5. 按提示重新加载 SpringBoard。服务在 SpringBoard 启动时初始化；安装包不会在电脑上启动手机服务。

当前工作流产物保留 14 天。若产物已过期，可以手动重新运行构建，参见[编译说明](github-actions.md)。工作流生成下载产物，不会自动创建 GitHub Release。

## 连接方式

### 局域网连接

让电脑与手机接入同一网络，在手机 Wi-Fi 详情中查看 IP 地址，访问：

```text
http://<手机IP>:8081/
```

例如手机 IP 为 `192.168.1.100` 时，地址为 `http://192.168.1.100:8081/`。该地址是示例，请替换为实际 IP。路由器访客网络或客户端隔离可能阻止互相访问。

### USB 连接

`iproxy` 由 [libusbmuxd 项目](https://github.com/libimobiledevice/libusbmuxd) 提供。安装适合电脑系统的工具和 USB 通信依赖，将手机连接电脑、解锁并完成信任，然后在终端运行：

```sh
iproxy 8081:8081
```

保持该终端运行，浏览器访问 `http://127.0.0.1:8081/`。此时接口中的手机 IP 也替换为 `127.0.0.1`。转发停止后，本地地址会断开。

如果电脑的 8081 端口被占用，可将本地端口改为 18081：

```sh
iproxy 18081:8081
```

此时访问 `http://127.0.0.1:18081/`。多设备连接时，使用所装 `iproxy` 的设备选择参数，先查看 `iproxy --help`。USB 转发仅改变电脑访问入口，设备服务仍监听网络接口。

## 验证连接

### PowerShell

以下命令适用于 Windows PowerShell，所有请求共用 `$baseUrl`：

```powershell
$baseUrl = 'http://127.0.0.1:8081'

# 查询设备信息
Invoke-RestMethod "$baseUrl/deviceInfo?type=30"

# 保存 PNG 截图
Invoke-WebRequest "$baseUrl/screenshot_original" -OutFile screenshot.png

# 查看当前前台应用
Invoke-RestMethod "$baseUrl/currApp"
```

确认前台应用中有输入框且已获得焦点，再输入文本：

```powershell
$body = @{ text = 'Hello MKS' } | ConvertTo-Json
Invoke-RestMethod "$baseUrl/input" -Method Post `
  -ContentType 'application/json; charset=utf-8' `
  -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
```

PowerShell 下建议使用上面的命令，避免不同版本中 `curl` 别名和 JSON 引号处理差异。

### macOS / Linux

```sh
BASE_URL='http://127.0.0.1:8081'
curl "$BASE_URL/deviceInfo?type=30"
curl "$BASE_URL/screenshot_original" -o screenshot.png
curl -X POST "$BASE_URL/input" \
  -H 'Content-Type: application/json' \
  -d '{"text":"Hello MKS"}'
```

### 查看连续画面

浏览器可尝试直接打开以下 MJPEG 地址，也可将地址放进网页 `<img>` 的 `src` 中：

```text
http://127.0.0.1:8081/screenshotStream?quality=0.3&fps=15
```

`quality` 越低，JPEG 压缩越强；`fps` 为请求帧率，实际帧率取决于设备和链路。客户端断开后，服务停止对应流的截图任务。

仓库中的 `tp.py` 是可选的 Python 截图轮询示例。安装 `requests`、`opencv-python` 和 `numpy`，修改文件底部的 `SERVER_URL` 后运行 `python tp.py`，按 `q` 退出。它轮询 `/screenshot`，并非 MJPEG 客户端；初始化窗口尺寸写死为 `414 × 896`，其他设备需自行调整。

## 常见问题

| 现象 | 检查与处理 |
| --- | --- |
| 浏览器无法连接 / Connection refused | 确认包模式匹配、tweak 已注入 SpringBoard、安装后已重新加载 SpringBoard；检查实际 IP 和端口 |
| 局域网连接超时 | 检查是否同网、路由器是否开启客户端隔离，以及代理 / 防火墙是否影响访问 |
| USB 地址无法连接 | 确认设备已解锁和信任、USB 工具能识别设备、iproxy 持续运行且本地端口未被占用 |
| `/screenshot` 返回 204 | 画面没有变化，保留上一帧；需要即时画面可用 `/screenshot_original`、`/screenshot_v2?quality=0.3`，或重置帧计数后再获取 |
| 截图黑屏 / 返回 500 | 先解锁设备、确认屏幕可用，记录具体接口和系统版本；截图依赖私有 API，需要真机定位 |
| 输入成功但没有文字 | 目标应用必须有获得焦点的可编辑输入框；检查 appdelegate 是否加载，并区分通知输入与 HID 按键输入 |
| 点击位置不对 | 触摸使用物理屏幕像素，网页显示坐标须换算；检查缩放和方向，见[触摸说明](api.md#触摸坐标与动作) |
| POST 返回 400 | 检查 JSON 根节点、字段类型与必填参数；大多数接口需要对象，`/killAll` 使用字符串数组 |
| VPN 接口成功但未连接 | 接口操作当前已有 VPN 配置，不创建配置；检查系统配置及实际连接状态 |
| 设置没有立即变化 | 设置通过延迟任务执行，稍后查询 `/getAllSetting`，并观察实际界面变化 |
| 找不到构建产物 | 检查任务是否成功、产物是否超过 14 天；失败时查看[构建排错](github-actions.md#构建失败排查) |

## 使用注意

当前服务没有身份认证或 TLS，并允许跨域访问；不要在不可信网络或公网开放该端口。Shell、卸载、钥匙串及重启接口会改变设备状态，请阅读对应接口的实际行为后使用。

服务多数成功响应表示请求已接收。自动化流程应通过截图、前台应用查询或状态接口确认结果，再进行下一步。
