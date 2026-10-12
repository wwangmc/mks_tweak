# pccontrol

MKS 的 SpringBoard 控制服务，提供 HTTP、WebSocket、截图与 HID 输入。安装整套功能请从[项目首页](../README.md)开始。

## 文档入口

- [安装、连接与常见问题](../docs/quickstart.md)
- [完整 HTTP API / WebSocket 参考](../docs/api.md)
- [模块结构、本地构建与回归检查](../docs/development.md)
- [GitHub Actions 打包与日志](../docs/github-actions.md)

## 实现概览

`Tweak.xm` 在 SpringBoard 启动时初始化屏幕信息，并启动 8081 服务。`WebServer.xm` 按截图、输入、应用、设备、提示和设置分组注册路由，静态页面位于 `layout/usr/lib/mks_dist/`。

`WebServerSupport.m` 集中处理 JSON 对象解析、参数校验、CORS 和响应。`ScreenshotStream.m` 按读取需求异步生成 MJPEG 帧，并在连接关闭后停止截图。`SocketHandler.xm` 接收输入任务，`SysExecutor.xm` 调用设备侧 roothelp。

## 接入时需要注意

- JSON 对象接口拒绝无效 JSON、数组根节点和字段类型错误，返回 HTTP 400。
- `/killAll` 使用字符串数组，空请求体或 `[]` 表示关闭全部；无效排除列表不会触发关闭。
- 截图 quality 范围为 0–1；截图流 fps 必须为 1–60 的整数。
- `/screenshot` 画面没有变化时返回无响应体的 204；更改质量或重置帧计数会触发下一次截图。
- 原图接口返回 image/png；MJPEG 的 boundary 参数为 frame，帧分隔符为 --frame。
- HID 输入通过独立串行队列执行，成功响应表示已入队；剪贴板访问在主线程执行。
- 重复启动已运行的服务不会断开现有客户端。
- 服务监听所有网络接口，未配置认证；完整参数、实际动作限制与使用边界见 API 文档。

## 验证

在 macOS 上从仓库根目录运行：

```sh
sh pccontrol/tests/run_tests.sh
```

检查直接编译生产代码，使用 GCDWebServer / 屏幕替身及临时命令 helper，不调用越狱设备的 roothelp。覆盖公共参数校验、响应头、MJPEG 格式、取消行为、命令输出及资源清理；不代替路由和私有 API 的真机联调。

使用已配置的 RootHide Theos 和 iOS 16.5 SDK 验证子模块 rootless 构建：

```sh
make -C pccontrol THEOS_PACKAGE_SCHEME=rootless \
  TARGET=iphone:clang:16.5:14.0 ARCHS="arm64 arm64e"
```

完整包需从根目录构建，以同时包含键盘输入及其他配套模块。
