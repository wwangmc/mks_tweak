# 开发指南

[返回项目首页](../README.md) · [接口参考](api.md) · [云端编译](github-actions.md)

## 代码结构与运行方式

根目录 Makefile 将七个子项目聚合到 `com.csmk.mks` 安装包中，包名、版本和依赖由根目录 [control](../control) 描述。

| 模块 | 职责与入口 |
| --- | --- |
| pccontrol | 注入 SpringBoard；Tweak.xm 在启动后初始化屏幕信息并启动 Web 服务 |
| appdelegate | 注入 UIKit 相关进程，接收 com.csmk.keyboardcontrol 通知，操作当前键盘输入对象 |
| StoreSwitcher2 | App Store 账号页面中的切换界面及配套资源 |
| locationfaker | Hook CLLocation.coordinate，读取定位配置 plist |
| roothelp | 提升权限后执行 Shell，是 runCommand 的设备侧辅助工具 |
| keychain_clear | 直接操作设备钥匙串数据库的命令行工具 |
| appinst | 命令行 IPA 安装工具，静态链接仓库内的 libzip |

HTTP 服务在 8081 端口监听，静态页面由 `pccontrol/layout/usr/lib/mks_dist/` 提供。对应 Vue / Vite 源码位于 `ios_control/`，本地构建输出到 `ios_control/dist/`，再同步到打包目录。启动、联调、交互和同步步骤见[控制页面项目说明](../ios_control/README.md)。

前端是独立构建步骤，不是根目录 Theos Makefile 的子项目。当前 GitHub Actions 不运行 npm 构建；修改前端源码时，需要一并提交更新后的 `pccontrol/layout/usr/lib/mks_dist/` 资源。

### Web 服务关键文件

| 文件 | 维护内容 |
| --- | --- |
| [WebServer.xm](../pccontrol/WebServer.xm) | HTTP 路由、业务分组、静态资源及 WebSocket 入口 |
| [WebServerSupport.m](../pccontrol/WebServerSupport.m) | JSON 解析、参数校验、CORS、错误响应、输入队列 |
| [SocketHandler.xm](../pccontrol/SocketHandler.xm) | WebSocket 文本任务与二进制回显 |
| [Screen.xm](../pccontrol/Screen.xm) | 截图实现、屏幕参数与画面变化检测 |
| [ScreenshotStream.m](../pccontrol/ScreenshotStream.m) | 按客户端读取需求生成 MJPEG 帧，连接关闭时取消任务 |
| [SysExecutor.xm](../pccontrol/SysExecutor.xm) | 调用 roothelp、收集标准输出 / 错误、读取 plist |
| [hid/STHIDEventGenerator.m](../pccontrol/hid/STHIDEventGenerator.m) | HID 触摸及按键生成 |

输入事件在独立串行队列中执行，UI 绘制及剪贴板操作在主线程执行。修改接口时应区分“请求已接收”与“设备动作已完成”，避免在网络回调中阻塞主线程。静态资源回退路由先注册，API 后注册，以符合 GCDWebServer 的后注册优先行为。

## 本地构建

### 环境要求

下面的命令面向具备 iOS 构建环境的 macOS。Windows 用户可直接使用[云端编译](github-actions.md)。

1. 安装 Xcode 和基础构建依赖；参考 [Theos macOS 安装文档](https://theos.dev/docs/installation-macos)。
2. 使用 [RootHide Theos](https://github.com/roothide/theos)，配置 THEOS，并完整初始化子模块。普通 Theos 安装指南仅提供基础环境参考，本项目额外依赖 roothide.h。
3. 将 [theos/sdks](https://github.com/theos/sdks) 的 iPhoneOS16.5.sdk 放到 `$THEOS/sdks/`，保留其中私有框架符号。
4. 确认仓库内两份静态库存在，检查其架构是否匹配本次构建。

```sh
git clone https://github.com/wwangmc/mks_tweak.git
cd mks_tweak
test -f "$THEOS/makefiles/common.mk"
test -f "$THEOS/sdks/iPhoneOS16.5.sdk/SDKSettings.plist"
xcrun lipo -info pccontrol/libs/libGCDWebServers.a
xcrun lipo -info appinst/libs/libzip.a
```

### 构建整包

默认 `TYPE=1`，建议显式选择模式，并在切换模式前清理：

```sh
# rootless
make TYPE=1 ARCHS="arm64 arm64e" clean
make TYPE=1 ARCHS="arm64 arm64e" FINALPACKAGE=1 package

# rootfull
make TYPE=0 ARCHS=arm64 clean
make TYPE=0 ARCHS=arm64 FINALPACKAGE=1 package

# RootHide
make TYPE=2 ARCHS="arm64 arm64e" clean
make TYPE=2 ARCHS="arm64 arm64e" FINALPACKAGE=1 package
```

输出 `.deb` 位于根目录 `packages/`。需确认所有静态库能链接对应架构，失败时参见[构建排错](github-actions.md#构建失败排查)。

`build_all.sh` 会依次尝试三种模式，但不显式传入架构、会隐藏构建输出，且不能仅通过脚本退出码判断三种构建全部成功。排查问题时使用上面的逐项命令或 CI 日志。

只编译 pccontrol 的 rootless 版本：

```sh
make -C pccontrol THEOS_PACKAGE_SCHEME=rootless \
  TARGET=iphone:clang:16.5:14.0 ARCHS="arm64 arm64e"
```

该命令只验证子模块，安装整套功能仍应构建根目录聚合包。

### 设备安装

将 `.deb` 交给设备包管理器安装即可。使用 Theos 远程安装功能前，请确认设备 SSH、权限及转发配置；根目录默认 SSH 目标是 `localhost:2222`，与 HTTP 服务的 8081 端口是不同配置。pccontrol 的安装钩子会重启 SpringBoard，执行前保存设备上的工作。

## 验证

### macOS 回归检查

在仓库根目录运行：

```sh
sh pccontrol/tests/run_tests.sh
```

脚本通过 xcrun clang / clang++ 直接编译生产代码，不要求真机，覆盖：

- JSON 根节点、字段类型、数字范围和触摸参数校验。
- CORS、错误响应、MJPEG 格式、帧间隔及断开时的任务取消。
- 命令输出、非零退出时的输出保留，以及文件描述符清理。

测试为 GCDWebServer 与屏幕提供替身，为命令执行提供临时本地 helper，不调用设备上的 roothelp。这些检查依赖 macOS Foundation，不可在普通 Windows PowerShell 环境直接运行；当前 GitHub Actions 只打包，并未调用此测试脚本。

### 真机联调

修改相关功能后，针对受影响的接口检查：

- HTTP 可达，JSON 错误参数返回 400，成功响应结构符合文档。
- 截图格式与画面正确，204 被客户端正确处理，断开 MJPEG 后不再生成帧。
- 触摸坐标、Home / 电源键及获得焦点后的键盘输入。
- 空剪贴板写入、Toast / 弹窗，以及设置修改后的状态查询。

应用管理、重启、标识重置和钥匙串测试应在可恢复的测试设备上进行。不要用真实账号密码或需要保留的数据验证清理接口。

## 提交修改与问题反馈

新增或变更接口时，同步更新 [API 文档](api.md)，包括方法、路径、参数、响应及异步行为。文档应描述当前实现，避免把历史接口或尚未接入的配置写成已支持能力。

提交前检查 `git diff --check`、相对链接和示例 JSON。修改代码时运行对应回归检查和构建；改变私有 API 调用时，还需记录真机验证结果。

问题反馈建议附上：

- 系统版本、设备型号、越狱方案及包模式。
- 安装包的提交 SHA 或 Actions 运行链接。
- 请求方法 / 路径、脱敏后的请求体、HTTP 状态与响应。
- 最小复现步骤、预期和实际结果；构建失败时附对应日志。

请保留第三方作者和许可声明。appinst 的上游说明保留在其目录，HID 源文件也包含许可信息；不要为整个仓库推断或添加未经确认的统一许可证。
