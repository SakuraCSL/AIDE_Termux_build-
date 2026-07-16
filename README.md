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
| 📦 **离线安装** | 提供本地安装脚本，无需网络即可部署 |
| 🎯 **NDK 可选** | 支持选择 NDK r24 或 r29，或两者都装 |

## 📦 环境要求

- **设备**：Android 6.0+ arm64 设备
- **存储**：至少 10GB 可用空间（建议 15GB+）
- **网络**：在线安装需要联网，或使用本地离线包
- **Termux**：最新版（建议从 F-Droid 安装）

## 🚀 快速开始

### 方式一：一行命令安装（推荐）

无需克隆仓库，直接通过 bash 远程执行安装脚本：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/SakuraCSL/AIDE_Termux_build-/main/install.sh)
```

或使用 wget：

```bash
bash <(wget -qO- https://raw.githubusercontent.com/SakuraCSL/AIDE_Termux_build-/main/install.sh)
```

### 方式二：克隆仓库后安装

```bash
# 1. 克隆仓库
git clone https://github.com/SakuraCSL/AIDE_Termux_build-.git
cd AIDE_Termux_build-

# 2. 运行安装脚本
bash install.sh

# 3. 使环境变量生效
source ~/.bashrc  # 或 source ~/.zshrc
```

### 方式三：网络安装（使用 Release 资产）

如果在线安装失败，可使用此脚本从 Release Assets 下载所有组件：

```bash
# 1. 克隆仓库
git clone https://github.com/SakuraCSL/AIDE_Termux_build-.git
cd AIDE_Termux_build-

# 2. 运行网络安装脚本
bash local_install.sh

# 3. 使环境变量生效
source ~/.bashrc  # 或 source ~/.zshrc
```

## 📁 仓库文件说明

```
AIDE_Termux_build-/
├── README.md                # 项目说明文档
├── install.sh               # 在线安装脚本（从网络下载）
├── local_install.sh         # 网络安装脚本（从 Release Assets 下载）
├── test-project/            # 示例 Android 项目源码
├── test-project.zip         # 示例项目压缩包
├── JDK_21.tar.gz            # OpenJDK 21 离线包（Release 资产）
├── gradle.tar.gz            # Gradle 8.13 离线包（Release 资产）
├── android-sdk.tar.gz       # Android SDK 离线包（Release 资产）
├── android-ndk-r24-aarch64.zip # NDK r24 离线包（Release 资产）
└── android-ndk-r29-aarch64.tar.gz # NDK r29 离线包（Release 资产）
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

## 🎯 安装流程

### 在线安装（install.sh）

1. **检查基础依赖** - 安装 OpenJDK 21、wget、unzip、xz-utils、aapt2
2. **安装 cmdline-tools** - Android SDK 命令行工具
3. **安装 Gradle** - 项目构建工具
4. **配置环境变量** - 自动写入 `~/.bashrc` 或 `~/.zshrc`
5. **安装 SDK 组件** - platform-tools、platforms、build-tools
6. **选择 NDK** - 可选择 r24、r29 或两者都安装

### 网络安装（local_install.sh）

从 Release Assets 下载所有离线包并安装：

1. **下载 JDK** - 从 Release v2.0 下载 `JDK_21.tar.gz` 并解压到 `~/jdk`
2. **下载 Gradle** - 从 Release v2.0 下载 `gradle.tar.gz` 并解压到 `~/gradle`
3. **下载 Android SDK** - 从 Release v2.0 下载 `android-sdk.tar.gz` 并解压到 `~/android-sdk`
4. **配置环境变量** - 自动写入 `~/.bashrc` 或 `~/.zshrc`
5. **修复 aapt2** - 确保 AGP 使用 arm64 原生 aapt2
6. **选择 NDK** - 可选择下载安装 r24、r29 或跳过

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

### 下载测试项目

直接下载示例项目（无需克隆仓库）：

```bash
# 从 Release v2.0 下载
wget https://github.com/SakuraCSL/AIDE_Termux_build-/releases/download/v2.0/test-project.zip

# 或使用 curl
curl -L -o test-project.zip https://github.com/SakuraCSL/AIDE_Termux_build-/releases/download/v2.0/test-project.zip
```

### 构建验证

```bash
# 解压测试项目
unzip test-project.zip
cd test-project

# 构建 APK
gradle assembleDebug

# 安装到设备
adb install app/build/outputs/apk/debug/app-debug.apk
```

## ❓ 常见问题

### 1. 下载失败怎么办？

在线脚本已内置：
- `wget --show-progress -c` 断点续传
- 自动切换清华/中科大镜像
- 完整性检查（空文件检测）

若仍失败，可：
- 更换网络环境（建议使用 WiFi）
- 使用方式二的本地离线安装

### 2. 提示 "Permission denied"

确保脚本有执行权限：
```bash
chmod +x install.sh local_install.sh
```

### 3. 如何卸载？

#### 在线安装卸载
```bash
bash install.sh
# 选择 2) 卸载
```

#### 本地安装卸载
```bash
bash local_install.sh
# 选择 2) 卸载
```

或手动清理：
```bash
# 删除环境目录
rm -rf ~/android-sdk
rm -rf ~/gradle
rm -rf ~/jdk

# 清理环境变量（手动编辑 ~/.bashrc 或 ~/.zshrc）
sed -i '/ANDROID_HOME/d' ~/.bashrc
sed -i '/GRADLE_HOME/d' ~/.bashrc
sed -i '/ANDROID_NDK_HOME/d' ~/.bashrc
```

### 4. NDK 符号链接修复

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
- **本地安装**：确保所有 `.tar.gz` 和 `.zip` 文件完整且未损坏

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 开源协议

MIT License
