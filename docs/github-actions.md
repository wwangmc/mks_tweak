# GitHub Actions 编译与下载

[返回项目首页](../README.md) · [安装与连接](quickstart.md) · [本地开发](development.md)

Windows 只负责编辑和上传代码，编译在 GitHub 的 macOS runner 中执行。本机无需安装 Theos、Xcode 或配置苹果开发者证书。构建配置以 [build.yml](../.github/workflows/build.yml) 为准。

## 触发编译

当前工作流名为 **Build Theos packages**，支持三种触发方式：

- 向 `main` 或 `master` 推送提交，包括文档提交。
- 创建或更新以 `main` / `master` 为目标的 Pull Request。
- 打开 [Actions 工作流页面](https://github.com/wwangmc/mks_tweak/actions/workflows/build.yml)，选择 **Run workflow** 手动运行。手动入口要求工作流已存在于默认分支；使用自己的 fork 时，请在该仓库查看并启用 Actions。

同一工作流、同一 Git ref 的新运行会取消旧运行。矩阵任务各自编译一种模式，其中一个失败不会取消另外两个。

## 选择与下载产物

| 越狱环境 | 产物名 | 参数 | CI 架构 | 最低部署目标 |
| --- | --- | --- | --- | --- |
| rootfull（有根） | `mks-rootfull` | `TYPE=0` | arm64 | iOS 13.0 |
| rootless（无根） | `mks-rootless` | `TYPE=1` | arm64、arm64e | iOS 14.0 |
| RootHide | `mks-roothide` | `TYPE=2` | arm64、arm64e | iOS 14.0 |

表格描述 CI 参数，并非所有子工具的默认配置都相同：`appinst/Makefile` 默认限定 arm64，而 CI 显式通过命令行传递 `ARCHS`。兼容性最终取决于设备、注入环境、工具和静态库。

1. 在 Actions 中找到所需提交的运行记录。
2. 检查对应 `Package (rootfull/rootless/roothide)` 任务成功。
3. 在运行页面的 **Artifacts** 下载对应 `mks-*` ZIP。
4. 解压后获取 `.deb`，按[快速入门](quickstart.md)安装。

构建包和 `build-log-*` 日志均保留 **14 天**。产物过期后需重新构建。下载入口及权限见 [GitHub 官方产物下载说明](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts)。流程不会自动安装到手机或发布 Release。

## 当前构建环境

| 项目 | 配置 |
| --- | --- |
| Runner | `macos-15` |
| Xcode 路径 | `/Applications/Xcode_16.4.app/Contents/Developer` |
| Theos | [RootHide Theos](https://github.com/roothide/theos)，递归克隆 master |
| SDK | [theos/sdks](https://github.com/theos/sdks) 中的 iPhoneOS16.5.sdk，包含私有框架符号 |
| 构建工具 | GNU make、ldid、xz |
| 静态库 | pccontrol/libs/libGCDWebServers.a、appinst/libs/libzip.a |
| 打包方式 | 先 clean，再并行执行 FINALPACKAGE=1 package |
| 单任务超时 | 30 分钟 |

项目在各模式中都使用 `roothide.h`，因此统一使用 RootHide 版 Theos。rootfull 任务只编译 arm64，避免现代 Xcode 与 iOS 13 旧版 arm64e ABI 的组合问题。

Theos 和 SDK 当前跟随各自 master，工作流会输出所用提交 SHA；排查不同运行结果时应同时记录这两个 SHA。Runner 镜像和外部依赖会更新，构建成功应以具体提交的任务结果为准。

## 在 Windows 上传修改

本仓库当前使用 `master`。在项目目录中检查变更、提交并上传：

```powershell
git status
git diff
git add README.md docs pccontrol/README.md
git commit -m "docs: improve project documentation"
git push origin master
```

上面的暂存路径针对文档修改；修改其他文件时按实际范围添加。若使用其他分支，请替换分支名，或通过 Pull Request 合入 main / master 来触发构建。身份认证和仓库写权限由本机 Git / GitHub 配置提供。

## 构建失败排查

先查看失败的具体步骤，再决定是否需要重新构建：

| 失败阶段或提示 | 检查方向 |
| --- | --- |
| Install build tools / Xcode 路径不存在 | 检查 runner 镜像是否仍提供指定 Xcode，以及工具安装日志 |
| 克隆 Theos / SDK 失败 | 检查网络和上游仓库状态；临时失败可重试 |
| 找不到 roothide.h | 确认使用 RootHide Theos，子模块完整，并检查 THEOS 路径 |
| 私有框架符号缺失 | 确认使用带私有框架符号的 iOS 16.5 SDK，检查 TARGET 是否被覆盖 |
| 找不到静态库 | 确认仓库包含两份 libs/*.a；工作流有单独的库检查步骤 |
| 架构链接错误 | 查看 xcrun lipo -info 输出和报错架构，核对 ARCHS 与静态库实际切片 |
| 编译步骤失败 | 展开 Build deb package，下载对应 build-log-*，从第一条编译 / 链接错误开始排查 |
| 产物上传提示没有 .deb | 检查前面的 package 是否成功，以及 packages/*.deb 是否生成 |

日志只有在进入构建步骤后才会生成；早期失败可能没有日志产物。CI 成功说明完成打包，设备功能仍需真机验证。
