# AIDE_Termux_build

> 📱 在 Termux 中一键安装完整的 Android 开发环境，支持手机端直接打包 APK。

## 📋 项目简介

本项目提供了一套完整的 Termux 环境配置方案，让你可以在 Android 手机上通过命令行编译、构建 Android 应用。无需电脑，无需 Root，仅需一台 Android 设备即可完成 APK 打包。

## ✨ 功能特性

| 特性 | 说明 |
|------|------|
| 🚀 **一键安装** | 运行单个脚本自动完成所有环境配置 |
| 🔄 **断点续传** | 下载中断后可继续，无需重新下载大文件 |
| ✅ **完整性检查** | 自动验证所有组件是否正确安装 |
| 🔒 **防重复运行** | 锁文件机制避免并发/重复执行 |
| 🛠️ **镜像修复** | 自动切换清华/中科大镜像解决网络问题 |
| 📦 **离线包支持** | 提供预编译压缩包，加速部署 |

## 📦 环境要求

- **设备**：Android 6.0+ arm64 设备
- **存储**：至少 10GB 可用空间（建议 15GB+）
- **网络**：需要联网下载组件（或使用本地离线包）
- **Termux**：最新版（建议从 F-Droid 安装）

## 🚀 快速开始

### 方式一：在线安装（推荐）

```bash
# 1. 克隆仓库
git clone https://github.com/SakuraCSL/AIDE_Termux_build-.git
cd AIDE_Termux_build-

# 2. 运行安装脚本
bash install.sh

# 3. 使环境变量生效
source ~/.bashrc  # 或 source ~/.zshrc
```

### 方式二：离线安装

如果网络不佳，可直接使用仓库中的预编译包：

```bash
# 确保以下文件已存在于仓库目录：
# - android-ndk-r24-aarch64.zip
# - android-ndk-r29-aarch64.tar.xz
# - android-sdk.tar.xz
# - gradle.tar.xz
# - JDK_21.tar.xz

bash install.sh
```

## 🔧 安装内容

脚本会自动安装以下组件：

| 组件 | 版本 | 用途 |
|------|------|------|
| OpenJDK | 21 | Java 编译环境 |
| Android SDK | latest | Android 平台工具和构建工具 |
| Android NDK | r24 / r29 | 原生代码 (C/C++) 编译 |
| Gradle | 8.13 | 项目构建自动化工具 |
| aapt2 | 原生 arm64 | 资源编译 |
| platform-tools | 34.0.0 | adb 等调试工具 |
| build-tools | 34.0.0 | aapt、dx、zipalign 等 |
| platforms | android-34 | Android 14 编译目标 |

## 📁 仓库文件说明

```
AIDE_Termux_build-/
├── README.md          # 项目说明文档
├── install.sh         # 一键安装脚本（主程序）
├── android-ndk-r24-aarch64.zip   # NDK r24 离线包
├── android-ndk-r29-aarch64.tar.xz # NDK r29 离线包
├── android-sdk.tar.xz            # Android SDK 离线包
├── gradle.tar.xz                 # Gradle 8.13 离线包
└── JDK_21.tar.xz                 # OpenJDK 21 离线包
```

## 🎯 安装流程

脚本按以下步骤自动执行：

1. **检查基础依赖** - 安装 OpenJDK 21、wget、unzip、aapt2
2. **安装 cmdline-tools** - Android SDK 命令行工具
3. **安装 Gradle** - 项目构建工具
4. **安装 NDK** - 原生开发工具包（含 arm64 兼容性修复）
5. **配置环境变量** - 自动写入 `~/.bashrc` 或 `~/.zshrc`
6. **安装 SDK 组件** - platform-tools、platforms、build-tools

## ✅ 验证安装

```bash
# 检查 Java
java -version

# 检查 Gradle
gradle --version

# 检查 NDK
echo $ANDROID_NDK_HOME

# 检查环境变量
echo $ANDROID_HOME
echo $GRADLE_HOME
```

## 🛠️ 使用已安装环境

安装完成后，你可以：

```bash
# 克隆一个 Android 项目
git clone https://github.com/username/project.git
cd project

# 构建 APK
gradle assembleDebug

# 安装到设备
adb install app/build/outputs/apk/debug/app-debug.apk
```

## ❓ 常见问题

### 1. 下载失败怎么办？

脚本已内置：
- `wget --show-progress -c` 断点续传
- 自动切换清华/中科大镜像
- 完整性检查（空文件检测）

若仍失败，可：
- 更换网络环境（建议使用 WiFi）
- 使用方式二的离线包

### 2. 提示 "Permission denied"

确保脚本有执行权限：
```bash
chmod +x install.sh
```

### 3. 如何卸载？

```bash
# 删除环境目录
rm -rf ~/android-sdk
rm -rf ~/gradle-8.13
rm -rf ~/android-ndk

# 清理环境变量（手动编辑 ~/.bashrc 或 ~/.zshrc）
sed -i '/ANDROID_HOME/d' ~/.bashrc
sed -i '/GRADLE_HOME/d' ~/.bashrc
sed -i '/ANDROID_NDK_HOME/d' ~/.bashrc
```

### 4. NDK r24 符号链接修复

脚本已自动创建以下符号链接，解决 AGP 在 arm64 主机上找不到预编译工具的问题：
- `ndk/prebuilt/linux-x86_64` → `linux-aarch64`
- `toolchains/llvm/prebuilt/linux-x86_64` → `linux-aarch64`

### 5. aapt2 兼容性

脚本会创建 `~/.androidide/aapt2` 符号链接，并配置 `~/.gradle/gradle.properties` 确保 AGP 使用 Termux 原生 arm64 版本的 aapt2。

## 📝 注意事项

- **存储空间**：完整安装约占用 5-8GB，建议预留足够空间
- **内存要求**：编译时需要足够 RAM，建议 4GB+ 内存设备
- **Termux 版本**：请从 F-Droid 安装最新版，避免 Play 商店旧版问题
- **镜像源**：国内用户建议配置清华或中科大镜像加速下载

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 开源协议

MIT License
