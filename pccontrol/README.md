# pccontrol WebServer

`WebServer.xm` 按截图、输入、应用、设备、提示和设置分组注册接口。
`WebServerSupport.m` 集中处理 JSON 对象解析、参数校验、CORS 和响应。
`ScreenshotStream.m` 按读取需求异步生成 MJPEG 帧，并在连接关闭后停止截图。

原有 51 个接口地址和请求方法保留，并合入远端新增的 `POST /readPlist`。以下行为进行了修正：

- JSON 对象接口拒绝无效 JSON、数组根节点和字段类型错误，返回 HTTP 400。
- `POST /killAll` 的空请求体或 `[]` 仍表示关闭全部应用；无效的排除列表返回 400，不执行关闭操作。
- 截图 `quality` 范围为 0–1；`/screenshotStream` 的 `fps` 必须为 1–60 的整数。无效值返回 400。
- `/screenshot` 在屏幕没有变化时返回无响应体的 204，截图失败返回 500。更改质量或重置帧计数会触发下一次截图。
- 原图接口返回 PNG，响应类型改为 `image/png`。MJPEG 的 boundary 参数为 `frame`，帧分隔符为 `--frame`。
- `POST /setAllSetting` 支持从 JSON 对象读取 `timeZone`、`lang`、`locale`，并兼容原有查询参数；两者同时出现时查询参数优先。仅提供部分设置时只修改对应项，保存运营商配置失败时返回 500。
- `/setClip` 支持直接写入空剪贴板；`/alert` 的 `time` 支持小数秒。
- `/keychain` 仅在 `remove` 操作中要求 `key`，并按单个 shell 参数转义；未知操作返回 400。
- `/readPlist` 接收 JSON 对象中的 `path`，返回 `{"status":"success","data":{...}}`；参数错误、文件无法读取、根节点不是字典或内容无法表示为 JSON 时返回 400。
- 输入事件通过独立串行队列执行，响应成功表示事件已入队。界面绘制和剪贴板访问在主线程进行。
- 重复调用 `startWebServer()` 不会断开已运行服务的客户端。

## 验证

在 macOS 上运行回归检查：

```sh
sh pccontrol/tests/run_tests.sh
```

检查直接编译生产代码，覆盖 JSON 解析、参数边界、响应头、MJPEG 格式、帧间隔、关闭时取消任务，以及命令输出和文件描述符清理。GCDWebServer 和屏幕使用测试替身，命令执行使用临时本地 helper，不调用越狱设备的 roothelp。

使用现有 Theos 环境验证 rootless 构建（arm64 / arm64e）：

```sh
make -C pccontrol THEOS_PACKAGE_SCHEME=rootless TARGET=iphone:clang:16.5:14.0
```

以上检查不代替真机联调。安装后应检查截图画面、断开截图流、触摸与键盘输入、空剪贴板写入，以及设备设置接口；iOS 私有 API 行为取决于实际系统版本。
