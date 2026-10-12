# iOS 控制页面

MKS 的浏览器控制页面源码，使用 Vue 3、Vite 和 Canvas。页面通过 HTTP 轮询截图，通过 WebSocket 发送触摸和键盘任务。它与 [pccontrol 服务](../pccontrol/README.md) 配合使用，不是独立的 iOS 控制服务。

[项目首页](../README.md) · [设备安装与连接](../docs/quickstart.md) · [接口参考](../docs/api.md)

## 与安装包的关系

| 目录 | 用途 |
| --- | --- |
| `ios_control/src/` | 本目录中的可编辑页面源码 |
| `ios_control/dist/` | Vite 构建输出，本地生成且被 Git 忽略 |
| `pccontrol/layout/usr/lib/mks_dist/` | 随 `.deb` 打包的页面资源，提交到 Git |

设备上的 pccontrol 从 `jbroot("/usr/lib/mks_dist")` 提供静态页面。修改源码后，需要重新构建并把输出同步到打包目录，再构建和安装 `.deb`。当前 GitHub Actions 只编译 Theos，**不会自动运行前端构建或同步 dist**。

## 环境与安装依赖

当前锁文件使用 Vue 3.5.17、Vite 7.0.5 和 @vitejs/plugin-vue 6.0.0。按锁文件中的 engines 要求，Node.js 版本需满足 `^20.19.0 || >=22.12.0`；先检查本机版本。

```sh
node --version
npm --version
cd ios_control
npm ci
```

上述命令从仓库根目录开始执行。`npm ci` 按 package-lock.json 安装依赖，适用于已有锁文件的项目；具体行为见 [npm 文档](https://docs.npmjs.com/cli/v11/commands/npm-ci/)。锁文件目前使用 registry.npmmirror.com 的下载地址，安装需要能访问该源。

```sh
npm run dev      # 启动开发服务器
npm run build    # 构建到 dist/
npm run preview  # 本地预览构建结果
```

开发服务一般从 `http://localhost:5173/` 启动，预览一般从 4173 启动；以终端实际输出为准。命令说明可参考 [Vite 文档](https://vite.dev/guide/)。preview 只提供静态页面，不提供设备 API。

## 连接设备

### 使用设备上已打包的页面

先安装 MKS，并按[快速入门](../docs/quickstart.md#连接方式)连接局域网或 USB，浏览器访问：

```text
http://<手机IP>:8081/
http://127.0.0.1:8081/（USB 转发已启动时）
```

当前源码默认 `baseUrl = ""`，HTTP 请求使用页面的同源地址；WebSocket 使用 `ws://${window.location.host}`。因此页面部署到设备服务上后，两者都会连接提供页面的设备。

### 本地开发联调

当前 vite.config.js 的 `server.proxy` 为空，直接打开开发页面时，HTTP 和 WebSocket 都会指向 Vite 端口，而不是设备。仅修改 mksApi.js 中的 `host` 没有效果，该变量尚未被组件使用。

本地联调可以临时修改两个实际使用的地址。以下以 USB 转发到电脑 8081 为例：

1. 保持 `iproxy 8081:8081` 运行，先确认 `http://127.0.0.1:8081/deviceInfo?type=30` 能访问。
2. 在 [src/apis/mksApi.js](src/apis/mksApi.js) 中设置 HTTP 地址：

   ```js
   let baseUrl = "http://127.0.0.1:8081"
   ```

3. 在 [src/components/DeviceScreen.vue](src/components/DeviceScreen.vue) 的 connectWebSocket 中，把 currentHost 临时改为设备入口：

   ```js
   const currentHost = "127.0.0.1:8081"
   const wsUrl = `ws://${currentHost}`
   ```

4. 运行 `npm run dev`，打开终端显示的地址，通过浏览器开发者工具检查截图请求和 WebSocket 连接。

局域网联调时，把两处地址替换为手机 IP 和 8081；不同的 USB 本地端口也要同时修改。设备 HTTP 接口支持 CORS。当前 WebSocket 地址使用 ws，请通过 HTTP 页面联调。

**构建设备页面前恢复同源配置**：mksApi.js 中恢复 `baseUrl = ""`，组件中恢复 `const currentHost = window.location.host`。不要把电脑的 localhost 或固定手机 IP 打包给其他设备。

## 页面操作

先点击 **开始** 获取画面，再操作画布。截图默认 quality 为 0.1，刷新间隔默认 100ms；滑块支持 10–1000ms。停止按钮只停止截图轮询，不会关闭 WebSocket 或禁用键盘事件。

| 操作 | 当前行为 |
| --- | --- |
| 左键按下 / 松开 | 发送 down / up 单点触摸 |
| 按住左键移动 | 每约 50ms 最多发送一次 move；服务端当前没有独立拖动实现，实际限制见[接口文档](../docs/api.md#触摸坐标与动作) |
| 在画布上按右键 | 发送 home 任务，服务端实际执行双击 Home，打开应用切换视图 |
| 普通单字符按键 | 通过 inputText 发送到设备当前输入框 |
| Backspace | 向后删除一次 |
| 左 / 右方向键 | 移动光标 -1 / +1 |
| Ctrl+V / Cmd+V | 通过临时 textarea 接收粘贴文本后发送，效果取决于浏览器粘贴事件 |

目标设备输入框需先获得焦点。中文输入法组合输入、Enter 等特殊键没有专门的处理，不能按完整远程键盘能力理解。

坐标按截图原始像素换算，截图返回 204 时保留上一帧。刷新间隔不等于实际帧率；当前轮询使用 setInterval，网络慢时请求可能重叠，建议适当增大间隔。

## 构建并更新打包页面

从仓库根目录执行以下 PowerShell 命令。先确认已恢复同源配置：

```powershell
Push-Location ios_control
npm run build
$buildExitCode = $LASTEXITCODE
Pop-Location
if ($buildExitCode -ne 0) { throw '前端构建失败，停止同步' }

Copy-Item -Path 'ios_control/dist/*' `
  -Destination 'pccontrol/layout/usr/lib/mks_dist' -Recurse -Force

git status --short
git diff --stat -- pccontrol/layout/usr/lib/mks_dist
```

复制整个 dist 的内容，包括 index.html、assets 和 favicon.ico，不要把 dist 目录本身嵌套进 mks_dist。此复制不会删除旧哈希资源；需要清理旧文件时，核对新 index.html 引用，并仅删除该打包目录中确认不再使用的旧资源。

更新后的打包资源也需提交：

```sh
git add ios_control pccontrol/layout/usr/lib/mks_dist
git commit -m "Update device control page"
git push origin master
```

再按 [Theos 构建指南](../docs/development.md#构建整包)或 [GitHub Actions 说明](../docs/github-actions.md)生成 `.deb`，安装到设备后刷新浏览器。不要直接打开 dist/index.html 的 file 地址验证连接。

## 代码结构

```text
ios_control/
├── src/
│   ├── main.js                    # Vue 应用入口
│   ├── App.vue                    # 页面根组件
│   ├── apis/mksApi.js              # HTTP 地址变量
│   └── components/DeviceScreen.vue # 截图、Canvas、WebSocket、鼠标和键盘
├── public/favicon.ico
├── index.html
├── vite.config.js                 # Vue / DevTools 插件与别名
├── package.json
└── package-lock.json
```

当前没有单独的测试或 lint 脚本，`npm run build` 用于验证打包。改动交互后还应真机检查截图、点击、右键、输入和粘贴，并查看浏览器控制台及网络请求。

## 常见问题

| 现象 | 检查方向 |
| --- | --- |
| 本地页面能打开，但没有设备画面 | 确认修改了实际使用的 baseUrl 和 currentHost；默认空代理不会连接设备 |
| 修改 host 后没有变化 | host 当前未被组件使用，按本地联调步骤设置两个实际地址 |
| 截图正常，点击无效 | 检查 WebSocket 是否连接；当前发送前没有 readyState 检查，断线时可能抛异常 |
| 断线后无法控制 | 当前没有自动重连，确认服务恢复后刷新页面 |
| 文字没有进入手机 | 设备输入框需获得焦点；检查 appdelegate 是否加载，组合输入和粘贴需实际验证 |
| 页面仍显示旧版本 | 检查是否同步了 dist、提交打包目录、重新安装对应 .deb，并强制刷新浏览器缓存 |
| Node 版本不兼容 | 对照锁文件 engines，使用符合要求的 Node.js |

设备接口没有认证，请在可信网络和自己管理的设备上使用。服务端参数、异步行为和操作范围以[接口参考](../docs/api.md)为准。
