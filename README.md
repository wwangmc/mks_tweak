# MKS Tweak

[![Build Theos packages](https://github.com/wwangmc/mks_tweak/actions/workflows/build.yml/badge.svg)](https://github.com/wwangmc/mks_tweak/actions/workflows/build.yml)

通过电脑控制越狱 iOS 设备的工具集。插件在 SpringBoard 中启动端口为 **8081** 的服务，提供浏览器控制页面、HTTP API 和 WebSocket 输入接口，适用于设备调试、屏幕查看和自动化操作。

支持 rootfull（有根）、rootless（无根）和 RootHide 三种打包模式。Windows 用户可以通过 GitHub Actions 构建 `.deb`，无需在本机配置 iOS 编译环境。

## 文档导航

| 想做什么 | 从这里开始 |
| --- | --- |
| 下载、安装并连接手机 | [快速入门](docs/quickstart.md) |
| 在 Windows 上编译并下载安装包 | [GitHub Actions 编译说明](docs/github-actions.md) |
| 接入截图、触摸、应用管理等能力 | [HTTP API 与 WebSocket 参考](docs/api.md) |
| 本地构建、理解代码结构、参与维护 | [开发指南](docs/development.md) |
| 排查无法连接、黑屏、输入失败等问题 | [常见问题](docs/quickstart.md#常见问题) |

## 功能概览

| 能力 | 说明 |
| --- | --- |
| 屏幕查看 | JPEG / PNG 截图、画面变化检测、MJPEG 截图流 |
| 远程操作 | 单点触摸、Home / 电源键、文本输入、光标移动与删除 |
| 应用管理 | 获取应用列表和沙盒路径、切换前台应用、关闭后台、卸载 |
| 设备设置 | 查询设备与电池信息、切换语言 / 地区 / 时区、控制现有 VPN |
| 调试辅助 | 剪贴板、弹窗 / Toast、Shell 执行、读取字典型 plist |
| 配套模块 | 虚拟定位、App Store 账号切换界面、IPA 安装、钥匙串清理 |

各项能力依赖 iOS 私有 API 和越狱环境。构建目标中的最低 iOS 版本不等于所有功能都已在该版本真机验证；请按设备实际环境选择安装包并联调。

## 快速开始

1. 在 [Actions](https://github.com/wwangmc/mks_tweak/actions/workflows/build.yml) 中选择目标代码版本的成功构建，下载适合越狱环境的产物。
2. 解压 ZIP，将 `.deb` 传到手机，通过越狱包管理器安装，并按提示重新加载 SpringBoard。
3. 将电脑与手机接入同一可信局域网，浏览器访问 `http://<手机IP>:8081/`。
4. 也可以通过 USB 转发端口，再访问 `http://127.0.0.1:8081/`：

   ```sh
   iproxy 8081:8081
   ```

`iproxy` 需单独安装；设备信任、USB 驱动及多设备选择见[连接说明](docs/quickstart.md#连接方式)。

用 PowerShell 检查服务并保存一张截图：

```powershell
$baseUrl = 'http://127.0.0.1:8081' # 局域网连接时改成手机 IP
Invoke-RestMethod "$baseUrl/deviceInfo?type=30"
Invoke-WebRequest "$baseUrl/screenshot_original" -OutFile screenshot.png
```

## 安装包选择

下表描述仓库当前 GitHub Actions 的构建配置：

| 越狱环境 | 下载产物 | 构建参数 | 架构 | 部署目标 |
| --- | --- | --- | --- | --- |
| rootfull（有根） | `mks-rootfull` | `TYPE=0` | arm64 | iOS 13.0+ |
| rootless（无根） | `mks-rootless` | `TYPE=1` | arm64、arm64e | iOS 14.0+ |
| RootHide | `mks-roothide` | `TYPE=2` | arm64、arm64e | iOS 14.0+ |

以越狱环境选择模式，不要仅根据系统版本选择。根目录 `Makefile` 默认使用 `TYPE=1`；完整参数、架构例外和构建依赖见[编译说明](docs/github-actions.md)。

## 使用边界

当前服务监听所有网络接口，HTTP / WebSocket 没有配置身份认证，CORS 允许任意来源。接口可执行高权限命令、卸载应用、读取设备数据并清理钥匙串。请只在自己管理的设备和可信网络中使用，避免将 8081 端口映射到公网；USB 转发不会关闭设备本身的局域网监听。

部分修改通过异步任务或跨进程通知执行，`{"status":"success"}` 通常表示请求已接收，不保证目标应用已完成操作。钥匙串清理、卸载和重启等操作请先阅读[对应接口说明](docs/api.md)。

## 项目结构

```text
mks_tweak/
├── pccontrol/       # SpringBoard HTTP / WebSocket 服务、截图和输入
├── appdelegate/     # 应用内键盘通知接收与文本操作
├── StoreSwitcher2/  # App Store 账号切换界面
├── locationfaker/   # CLLocation 坐标替换
├── roothelp/        # 高权限 Shell 执行辅助工具
├── keychain_clear/  # 钥匙串数据库操作工具
├── appinst/         # IPA 命令行安装工具
├── docs/            # 使用、接口、构建与开发文档
├── .github/workflows/build.yml
├── Makefile         # 聚合构建入口
└── tp.py            # Python 截图轮询示例
```

## 反馈与第三方代码

提交问题时请附上 iOS 版本、越狱类型、安装包对应的提交或 Actions 运行链接、复现步骤及错误响应，并去除账号、设备标识等个人信息。维护说明见[开发指南](docs/development.md#提交修改与问题反馈)。

仓库包含第三方组件，请保留各目录和源文件中的作者、版权及许可声明。`appinst` 的上游说明见 [appinst/README.md](appinst/README.md)，HID 源码也保留了原有许可声明；当前仓库没有统一的顶层 LICENSE 文件。
