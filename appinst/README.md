> **MKS 集成说明**：本目录是随 MKS 聚合构建的 IPA 安装工具。下面保留的是上游项目说明，其系统版本范围、独立安装渠道与构建路径不能直接视为本仓库整包的兼容性承诺。
>
> 本仓库已经包含 `libs/libzip.a`，当前 Makefile 从此目录链接，不需要按下文复制到 `$THEOS/libs/`。构建 MKS 请使用[项目开发指南](../docs/development.md)，安装整包请使用[快速入门](../docs/quickstart.md)。
>
> 工具基本用法为 `appinst <IPA文件路径>`；对未签名或特殊签名 IPA 的安装依赖仍需按设备实际环境配置。

# appinst (App Installer)
###### A command-line IPA app installer for iOS 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, and 18.

## What is appinst?

appinst is a command-line utility that allows you to install IPA packages.

AppSync Unified is required as a dependency in order to install ad-hoc signed, fakesigned, unsigned, or expired apps.

**Usage:** `appinst <path to IPA file>`

---

## How do I install appinst on my jailbroken iOS device?

appinst is available from **Karen/あけみ's Repo: https://cydia.akemi.ai/** ([Tap here on your device to automatically add the repo!](https://cydia.akemi.ai/add.php))

If you do not see appinst listed in Karen/あけみ's Repo, then that just means you have another repository added that is also hosting a copy of appinst under the same package ID.

**_Please_ only ever install the official, unmodified release from Karen/あけみ's Repo for your own safety, and to ensure proper operation!**

---

## How do I build appinst?

First, make sure you have [Theos](https://github.com/theos/theos) installed. If you don't, [please refer to the official documentation](https://theos.dev/docs/installation) on how to set up Theos on your operating system of choice.

Once you've confirmed that you have Theos installed, you'll need to acquire a copy of `libzip.a` to statically link against.

To do this, download the `libzip` package available from the BigBoss repository. The latest version as of the writing of this documentation is 0.11.2, and [the URL to the deb file can be found here](http://apt.thebigboss.org/repofiles/cydia/debs2.0/libzip_0.11.2.deb).

Extract the deb using whatever method you like. ([`dpkg -x`](https://formulae.brew.sh/formula/dpkg), [`unar`](https://formulae.brew.sh/formula/unar) ([also available without using Homebrew](https://theunarchiver.com/command-line)), [The Unarchiver](https://theunarchiver.com/), etc.)

Locate the `libzip.a` file, and copy it to `$THEOS/libs/`.

After you've done that, open up Terminal and run the following commands:

```shell
git clone https://github.com/akemin-dayo/AppSync.git
cd AppSync/appinst/
make
make package
```

And you should have a freshly built *.deb package file of appinst!

### … Wait, why are you _statically_ linking against libzip, instead of dynamically linking it and listing `libzip` as an APT dependency?

Ah. Yeah. About that.

It turns out that the different packages of `libzip` that are found on BigBoss (arm64, armv7s, armv7, armv6), Bingner/Elucubratus (arm64 only), and Procursus (arm64 only) all install to different locations and are all under different names.

This pretty much makes it impossible to support, so statically linking against `libzip` is the only option.

---

## License

Licensed under [GPLv3](http://www.gnu.org/copyleft/gpl.html).
