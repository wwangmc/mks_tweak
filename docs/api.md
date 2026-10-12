# HTTP API 与 WebSocket 参考

[返回项目首页](../README.md) · [安装与连接](quickstart.md) · [开发指南](development.md)

本文按当前 [WebServer.xm](../pccontrol/WebServer.xm)、[WebServerSupport.m](../pccontrol/WebServerSupport.m) 和 [SocketHandler.xm](../pccontrol/SocketHandler.xm) 整理。路径、方法和参数区分大小写，历史说明与源码不一致时以当前实现为准。

## 目录

- [请求与响应约定](#请求与响应约定)
- [截图与屏幕](#截图与屏幕)
- [输入与剪贴板](#输入与剪贴板)
- [应用管理](#应用管理)
- [设备信息与账号](#设备信息与账号)
- [语言、地区与时区](#语言地区与时区)
- [VPN](#vpn)
- [提示与弹窗](#提示与弹窗)
- [Shell 与文件](#shell-与文件)
- [定位与其他配置](#定位与其他配置)
- [广告标识与钥匙串](#广告标识与钥匙串)
- [WebSocket](#websocket)

## 请求与响应约定

基础地址：

```text
局域网：http://<手机IP>:8081
USB：http://127.0.0.1:8081（或 iproxy 指定的本地端口）
```

- GET 参数位于查询字符串，包含空格或特殊字符的值应进行 URL 编码。
- POST 使用 `Content-Type: application/json`。除 `/killAll` 外，本文 POST 接口要求根节点为 JSON 对象，空请求体、数组根节点或无效 JSON 返回 400。
- 数字字段由公共校验器校验，通常接受 JSON 数字或数字字符串，拒绝布尔值、非有限数和越界值。示例优先使用数字类型。
- 多数操作成功返回 `{"status":"success"}`；查询结果的字段并不完全统一，可能是 `data`、`info` 或 `applications`，请按下表解析。
- HID 输入、跨进程键盘通知和延迟设置的成功响应表示请求已接收或入队。客户端应通过查询或截图确认最终状态。
- 当前没有认证或 TLS。CORS 允许来源 `*`、方法 `GET, POST, OPTIONS` 和请求头 `Content-Type`；`OPTIONS` 预检返回 204。

| HTTP 状态 | 含义与处理 |
| --- | --- |
| 200 | 请求已处理；仍需按接口解析响应体，部分接口可能返回 `status: fail` |
| 204 | `/screenshot` 画面未变化或 OPTIONS 预检成功；没有响应体，不要解码为图片或 JSON |
| 302 | `GET /` 重定向至 `index.html` |
| 400 | JSON、参数或不支持的操作错误；`/readPlist` 读取失败也使用 400 |
| 500 | 截图、配置保存或辅助工具启动等服务端错误 |

错误由 GCDWebServer 错误响应生成，不保证采用统一 JSON 格式。客户端应先检查 HTTP 状态和 Content-Type，再决定如何解析。

## 截图与屏幕

| 方法 | 路径 | 参数 | 响应 / 行为 |
| --- | --- | --- | --- |
| GET | `/` | 无 | 跳转至浏览器控制页面 `index.html` |
| GET | `/screenshot` | `quality` 必填，0–1 | 有新画面时返回 JPEG；无变化返回 204 |
| GET | `/screenshot_v2` | `quality` 必填，0–1 | JPEG 截图，不使用 `/screenshot` 的变化检测 |
| GET | `/screenshot_original` | 无 | PNG 截图 |
| GET | `/screenshot_original_old` | 无 | 旧截图实现，返回 PNG |
| GET | `/screenshotStream` | `quality` 必填，0–1；`fps` 必填，整数 1–60 | MJPEG 流 |
| GET | `/resetDirtyFrameCount` | 无 | 重置变化检测，使下一次 `/screenshot` 重新捕获 |
| GET | `/pressPowerBtn` | 无 | 模拟电源键按下并松开；成功表示已入队 |

`/screenshot` 更改质量或重置帧计数会触发下一次捕获，客户端在 204 时应保留上一帧。JPEG / PNG 截图响应及 MJPEG 流使用 `Cache-Control: no-store`。

MJPEG 的 Content-Type 为 `multipart/x-mixed-replace; boundary=frame`，每帧以 `--frame` 分隔，包含 `Content-Type: image/jpeg` 和 `Content-Length`。连接关闭后停止对应流的截图任务；流开始后截图失败可能中断流，客户端应处理断开并按需重连。

```text
GET /screenshot?quality=0.3
GET /screenshotStream?quality=0.3&fps=15
```

`quality` 越低压缩越强，`fps` 是目标值，实际帧率受截图耗时和客户端读取速度影响。

## 输入与剪贴板

| 方法 | 路径 | 参数或 JSON 请求体 | 行为 |
| --- | --- | --- | --- |
| POST | `/touch` | `x`、`y` 非负数；`type` 为 down / move / up / tap | 单点触摸；见下文动作限制 |
| POST | `/input` | `{"text":"Hello MKS"}` | 通知当前应用向获得焦点的输入对象插入文本 |
| POST | `/keypress` | `{"text":"abc"}` | 按组合字符分段发送 HID 按键，间隔约 0.1 秒；系统能否输入该字符需真机验证 |
| GET | `/hideKeyboard` | 无 | 通知应用隐藏键盘 |
| GET | `/moveCursor` | `num` 必填，有符号整数 | 负数向左、正数向右 |
| GET | `/del` | `num` 必填，非负整数 | 向后删除指定次数 |
| GET | `/pressHome` | 无 | 模拟一次 Home 键 |
| GET | `/doublePressHome` | 无 | 模拟双击 Home，打开应用切换视图 |
| GET | `/getClip` | 无 | `data` 为文本；无字符串内容时为 `获取失败` |
| POST | `/setClip` | `{"text":"待写入文本"}` | 写入剪贴板，支持空剪贴板及空字符串 |

### 触摸坐标与动作

坐标基于物理屏幕像素，原点在左上角。`/deviceInfo?type=1` 返回初始化时记录的竖屏像素宽高，`type=3` 返回 scale。网页把截图缩小显示时，应将显示坐标换算回设备像素，并根据实际屏幕方向验证映射。

```json
{"x":119,"y":871,"type":"tap"}
```

当前接口只处理单点，没有使用旧示例中的 `index` 字段。`tap` 执行按下与松开；`down` 按下，`up` 松开。虽然参数校验接受 `move`，HTTP 和 WebSocket 当前都将其交给 `touchDown`，没有调用专门的移动方法；不要据此假定支持连续拖动或多点手势。

输入前先让目标输入框获得焦点。`/input` 与 `/keypress` 的实现不同，前者依赖应用内 `appdelegate` 通知接收，后者依赖 HID 键盘事件。

## 应用管理

`pkgName` 是应用 Bundle ID，例如 `com.example.demo`，不是显示名称。

| 方法 | 路径 | 参数 / 请求体 | 响应 / 行为 |
| --- | --- | --- | --- |
| GET | `/apps` | 无 | `applications` 为系统返回的已安装应用信息数组 |
| GET | `/appInfo` | `pkgName` 必填 | `info` 为应用信息；无可用信息时可能是 `{}` |
| GET | `/switchApp` | `pkgName` 必填 | 将应用切换到前台 |
| GET | `/killByBID` | `pkgName` 必填 | 从应用切换器关闭指定应用 |
| POST | `/killAll` | 可选字符串数组，如 `["com.example.keep"]` | 关闭后台应用，数组中的 Bundle ID 被排除；响应含 `receivedItems` |
| GET | `/uninstall` | `pkgName` 必填 | 卸载应用，响应为 `status: success` 或 `fail` |

`/killAll` 的空请求体和 `[]` 都表示关闭全部；对象、非字符串元素或空字符串元素返回 400，不执行关闭操作。`receivedItems` 是排除列表长度，不是实际关闭数量。

应用信息可能包含 `applicationIdentifier`、`localizedName`、`bundleVersion`、`shortVersionString`、`vendorName`、`applicationType`、`isInstalled`、`bundleURL`、`dataContainerURL`、`itemID`、`idfa`、`idfv`。当前实现中的 `bundleVersion` 取自系统的 `shortVersionString`，`shortVersionString` 取自系统的 `bundleVersion`，两者语义与常见命名相反，客户端需留意。

`/apps` 不是 dpkg 插件包清单。`/appInfo` 的字段受系统私有 API 影响，不应把缺失字段视为固定的下载状态协议。卸载未安装应用也可能返回成功，可再次查询应用状态确认结果。

## 设备信息与账号

| 方法 | 路径 | 参数 | 响应 / 行为 |
| --- | --- | --- | --- |
| GET | `/deviceInfo` | `type` 必填，见下表 | `data` 为字符串，复合值用 `;;` 分隔 |
| GET | `/currApp` | 无 | `data` 为前台应用 Bundle ID，无法取得时为空字符串 |
| GET | `/accounts` | 无 | `data` 为系统保存的 App Store 账号信息数组 |
| GET | `/rebootUserspace` | 无 | iOS 15.0+ 尝试重启用户空间，服务连接会中断 |

| type | data 格式 |
| --- | --- |
| 1 | `像素宽;;像素高`，初始化时按竖屏方向记录 |
| 2 | 前台应用方向枚举值，未知时可能为 -1 |
| 3 | 屏幕 scale 字符串 |
| 30 | `设备名称;;系统名称;;系统版本;;机型标识;;identifierForVendor` |
| 31 | `电池状态;;剩余百分比` |

其他 type 返回 400。以上响应是字符串，不是嵌套 JSON 对象。

`/accounts` 每项包含 `isActive`、`isLocalAccount`、`firstName`、`lastName`、`accountName`、`storeFrontIdentifier`；`isActive: true` 表示当前活跃账号。接口不返回密码。

`/rebootUserspace` 仅在 iOS 15.0+ 调用 launchctl，旧系统不会执行重启；接口没有检查启动返回值，成功响应不保证重启成功。当前路由没有 `/inputPwd`，也没有旧文档所述的“拨动静音键触发重启”入口。

## 语言、地区与时区

| 方法 | 路径 | 参数 / 请求体 | 响应 / 行为 |
| --- | --- | --- | --- |
| GET | `/getAllSetting` | 无 | 顶层字段 `timeZone`、`lang`、`locale` 及 `status` |
| GET | `/currentTimeZone` | 无 | `data` 为时区名称 |
| GET | `/currentLanguage` | 无 | `data` 为当前首选语言 |
| GET | `/currentLocale` | 无 | `data` 为 locale 标识 |
| GET | `/setCurrentTimeZone` | `timeZone` 必填，如 `Asia/Shanghai` | 校验时区名称后设置 |
| GET | `/setLanguage` | `lang` 必填，如 `en-US` | 设置首选语言 |
| GET | `/setLocale` | `locale` 必填，如 `en_US` | 设置地区 |
| POST | `/setAllSetting` | JSON 对象，至少提供 timeZone / lang / locale 之一 | 只修改提供的设置，兼容查询参数 |

```json
{"timeZone":"America/New_York","lang":"en-US","locale":"en_US"}
```

`/setAllSetting` 中，查询参数与 JSON 同名字段同时存在时，查询参数优先。即便使用查询参数，仍须发送合法 JSON 对象，例如 `{}`。语言和地区只校验非空字符串，是否受系统支持需真机确认；时区由 `NSTimeZone` 校验。

设置通过约 1 秒后的主线程任务执行。成功响应不保证设置已生效，稍后查询 `/getAllSetting` 并检查设备状态。

该接口还支持附加 `opts`、`country`、`country_code`、`country_name`、`ios` 运营商配置，其中 `opts` 必须是字典数组，条目可含 `mcc`、`mnc`、`name`、`network`。当请求包含 `opts`、`country` 或 `country_name` 时，服务将配置写入 `jbroot("/var/mobile/Library/Preferences/GptXinjiParamsData")` 的 `autoOprData`，保存失败返回 500。运营商字段不能替代至少一个设置参数，此配置写入也不等于已经修改系统运营商状态。

## VPN

| 方法 | 路径 | 参数 | 响应 / 行为 |
| --- | --- | --- | --- |
| GET | `/vpnStatus` | 无 | `data` 为 `open` 或 `close` |
| GET | `/turnOnVPN` | 无 | 请求连接系统当前 VPN 配置 |
| GET | `/turnOffVPN` | 无 | 请求断开当前 VPN |

接口通过系统 VPN 设置私有 API 操作已有配置，不创建 VPN 配置。实际连接结果需再次查询状态。

## 提示与弹窗

| 方法 | 路径 | JSON 请求体 | 行为 |
| --- | --- | --- | --- |
| POST | `/alert` | `title`、`text` 字符串；`time` 为大于 0 的秒数 | 显示弹窗，支持小数秒 |
| POST | `/toast` | `type`、`content`、`duration` 必填；`position`、`fontSize` 可选 | 显示或隐藏 Toast |
| GET | `/hideToast` | 无 | 隐藏 Toast |
| POST | `/toast_V2` | `text` 字符串、`color` 非空字符串 | 发送 `com.csmk.toast` 分布式通知，需接收方实现 |

```json
{"title":"完成","text":"任务已完成","time":2.5}
```

```json
{"type":"success","content":"连接成功","duration":2.5,"position":"top","fontSize":16}
```

Toast 类型为 `hide`、`error`、`warning`、`message`、`success`。显示时 `duration` 必须大于 0；隐藏时允许 0，但仍须提供 `content` 和 `duration`。位置支持 `top`、`bottom`、`left`、`right`，未提供或未匹配的位置按 top 处理。`fontSize` 为正整数，默认 14。

`/toast_V2` 仅发通知，当前仓库没有对应接收处理器；不要把它视为与 `/toast` 等价的内置显示接口。

## Shell 与文件

| 方法 | 路径 | JSON 请求体 | 响应 / 行为 |
| --- | --- | --- | --- |
| POST | `/runShell` | `{"cmd":"ls /var"}`，cmd 非空 | 调用 roothelp，`data` 为合并后的标准输出与标准错误 |
| POST | `/readPlist` | `{"path":"/absolute/path/to/file.plist"}`，path 非空 | `data` 为字典型 plist 转换得到的 JSON 对象 |

`/runShell` 通过设备 roothelp 执行 Shell，并等待命令结束。空行和包含 `SubstituteLog` 的行会被过滤，响应不包含退出码；命令非零退出仍可能返回 `status: success` 和输出，不能把它当作命令成功的保证。接口未设置独立命令超时，不适合长期驻留任务。

`/readPlist` 不自动对传入路径调用 `jbroot`；rootless / RootHide 下须传可实际读取的路径。文件无法读取、根节点不是字典、或含 JSON 无法表示的值（例如日期或二进制数据）时返回 400。

请求示例：

```json
{"path":"/var/mobile/Library/Preferences/com.example.demo.plist"}
```

响应形状示例（具体内容取决于文件）：

```json
{"status":"success","data":{"Enabled":true}}
```

## 定位与其他配置

| 方法 | 路径 | 参数 | 响应 / 行为 |
| --- | --- | --- | --- |
| GET | `/setLocation` | `Latitude` 必填，-90–90；`Longitude` 必填，-180–180 | 写入虚拟定位配置并重启 locationd |
| GET | `/setAFIP` | `ip` 必填，非空字符串 | 写入 `com.csmk.afIP.plist` 的 `afIP` 值 |
| GET | `/GPT_PATH` | 无 | `data` 为经 jbroot 映射的 `/var/jb/var/mobile/gptdata/` 路径 |

```text
GET /setLocation?Latitude=28.9050&Longitude=118.5270
```

定位配置写入 `jbroot("/var/mobile/com.csmk.locationfaker.plist")`，由 `locationfaker` 读取。接口没有“恢复真实定位”开关；当前 hook 支持配置中的 `Enabled: false`，但 `/setLocation` 会重写文件且不保留该字段。实际定位结果应在目标应用中确认。

`/setAFIP` 只保存字符串，不校验 IP 格式，也不直接更改系统网络地址。`/GPT_PATH` 仅返回路径，不创建目录或保证目录存在。

## 广告标识与钥匙串

这些接口会改变设备标识、权限或凭据数据，请使用可恢复的测试设备。

| 方法 | 路径 | 参数 / 请求体 | 响应 / 行为 |
| --- | --- | --- | --- |
| GET | `/resetAV` | `pkgName` 必填 | 清理设备 IDFA 并重置指定应用的 IDFV；直接返回应用信息对象，没有统一 status 包装 |
| GET | `/resetAuth` | `pkgName` 必填 | 重置应用的用户跟踪授权 |
| GET | `/setADAuth` | `pkgName` 必填 | 为应用设置用户跟踪授权 |
| POST | `/keychain` | `type` 为 query / remove / removeAll；remove 时 key 必填 | 调用 keychain_clear 辅助工具 |

只查询钥匙串分组：

```json
{"type":"query"}
```

返回 `{"status":"success","data":"group1,group2"}`，`data` 为工具输出字符串。`remove` 使用 `{"type":"remove","key":"目标分组关键字"}`，`removeAll` 使用 `{"type":"removeAll"}`；未知类型返回 400。

清理工具按 `agrp LIKE '%关键字%'` 匹配 genp / cert / keys，**不是精确匹配**，并会清空整个 inet 表和 sqlite_sequence；即使 remove 单个分组也存在这些全局副作用。removeAll 只保留代码中指定的部分分组，不是完整保留 Apple 凭据。API 成功仅说明辅助工具调用返回，不能据此保证每条数据库操作成功。详见 [keychain_clear/main.m](../keychain_clear/main.m)。

`/resetAuth` 和 `/setADAuth` 在找不到应用 bundle 时返回 400。这些能力依赖私有 API，不应据接口返回成功推断所有系统版本都会按预期改变授权。

## WebSocket

连接地址为 `ws://<手机IP>:8081/`，USB 连接时替换为本地地址。发送 UTF-8 JSON 文本消息，根节点必须是对象：

| type | data | 行为 |
| --- | --- | --- |
| `touch` | `{"x":119,"y":871,"type":"tap"}` | 与 HTTP 单点触摸相同的校验和动作限制 |
| `home` | 可省略 | **双击 Home**，对应应用切换视图 |
| `inputText` | 字符串 | 通知应用插入文本 |
| `moveCursor` | 有符号整数 | 移动光标 |
| `backspace` | 非负整数 | 向后删除指定次数 |

```json
{"type":"touch","data":{"x":119,"y":871,"type":"tap"}}
```

```json
{"type":"inputText","data":"Hello MKS"}
```

无效 JSON / 非对象消息返回文本 `反序列化失败`，不支持的类型或参数错误返回 `调用失败`。成功任务没有统一确认消息，客户端需自行观察结果；二进制消息会原样以二进制消息回显，不能通过该通道获取截图。
