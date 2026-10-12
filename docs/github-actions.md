## 在 Windows 上通过 GitHub Actions 编译

已添加 [自动编译流程](../.github/workflows/build.yml)。Windows 只负责编辑和上传代码，编译在 GitHub 的 macOS 云端执行，不需要本机安装 Theos、Xcode 或配置苹果开发者证书。

1. 项目仓库为 [wwangmc/mks_tweak](https://github.com/wwangmc/mks_tweak)，完整项目包括 `.github/workflows/build.yml`、`pccontrol/libs/libGCDWebServers.a` 和 `appinst/libs/libzip.a`。
2. 向 `main` 或 `master` 分支推送代码会自动触发编译；向这两个分支提交 Pull Request 也会触发。也可以在仓库的 **Actions → Build Theos packages → Run workflow** 手动运行；手动运行入口需要该流程已提交到默认分支。
3. 等待对应任务成功，在本次运行页面底部的 **Artifacts** 下载 `mks-rootfull`、`mks-rootless` 或 `mks-roothide`，解压 ZIP 后获得 `.deb` 安装包。
4. 编译失败时，展开失败步骤查看错误；如果已经进入编译步骤，还可以下载对应的 `build-log-*` 日志。

| 安装包 | Makefile 参数 | 架构 | 最低 iOS 版本 |
| --- | --- | --- | --- |
| rootfull（有根） | `TYPE=0` | arm64 | 13.0 |
| rootless（无根） | `TYPE=1` | arm64、arm64e | 14.0 |
| roothide | `TYPE=2` | arm64、arm64e | 14.0 |

流程使用 macOS 15、Xcode 16.4、RootHide 版 Theos，以及带私有框架符号的 iOS 16.5 SDK。三种模式分别编译，某一种失败不会取消其他模式。rootfull 使用 arm64，因为现代 Xcode 无法生成适用于 iOS 13 的旧版 arm64e ABI。产物和编译日志保留 14 天。

项目的 `origin` 指向 GitHub。在 Windows PowerShell 中上传后续修改：

```powershell
git add .
git commit -m "Update project"
git push origin master
```

以上命令按当前本地分支 `master` 编写。上传时确保 GitHub 仓库的默认分支也设为 `master`，或将代码推送到 `main`。本流程只编译并上传下载产物，不会向手机安装或自动发布 Release。Theos 和 SDK 从各自的 `master` 分支获取，具体提交版本会输出到运行日志。实际编译结果需要首次 GitHub Actions 运行确认。

环境说明参考：[Theos 的 macOS 安装文档](https://theos.dev/docs/installation-macos)、[RootHide Theos](https://github.com/roothide/theos)、[Theos SDK](https://github.com/theos/sdks)、[GitHub 产物下载说明](https://docs.github.com/en/actions/tutorials/store-and-share-data)。

