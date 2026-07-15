#!/bin/bash
set -uo pipefail

# ============================================================
# Android 开发环境网络安装脚本（基于 Release Assets）
# 从 GitHub Releases v2.0 下载所有离线包并安装
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

readonly RELEASE_TAG="v2.0"
readonly REPO="SakuraCSL/AIDE_Termux_build-"
readonly BASE_URL="https://github.com/${REPO}/releases/download/${RELEASE_TAG}"

readonly JDK_URL="${BASE_URL}/JDK_21.tar.gz"
readonly GRADLE_URL="${BASE_URL}/gradle.tar.gz"
readonly SDK_URL="${BASE_URL}/android-sdk.tar.gz"
readonly NDK_R24_URL="${BASE_URL}/android-ndk-r24-aarch64.zip"
readonly NDK_R29_URL="${BASE_URL}/android-ndk-r29-aarch64.tar.gz"

readonly HOME_DIR="$HOME"
readonly JDK_DIR="$HOME_DIR/jdk"
readonly GRADLE_DIR="$HOME_DIR/gradle"
readonly SDK_DIR="$HOME_DIR/android-sdk"
readonly NDK_R24_DIR="$SDK_DIR/ndk/24.0.8215888"
readonly NDK_R29_DIR="$SDK_DIR/ndk/29.0.13113456"

readonly BASHRC="$HOME/.bashrc"
readonly ZSHRC="$HOME/.zshrc"

# ============================================================
# 工具函数
# ============================================================
detect_shell_rc() {
    if [ -f "$ZSHRC" ]; then
        echo "$ZSHRC"
    else
        echo "$BASHRC"
    fi
}

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

error_exit() {
    log "ERROR: $*"
    exit 1
}

# ============================================================
# 下载文件（断点续传）
# ============================================================
download_file() {
    local url="$1"
    local output="$2"
    local desc="$3"
    
    log "  下载 ${desc}..."
    wget --show-progress -c -O "$output" "$url" || \
        error_exit "下载 ${desc} 失败，请检查网络"
    
    if [ ! -s "$output" ]; then
        error_exit "${desc} 下载文件为空，请检查网络"
    fi
    
    log "  ${desc} 下载完成 ✓"
}

# ============================================================
# NDK 网络安装
# ============================================================
install_ndk_r24() {
    log "安装 NDK r24 (aarch64)..."
    
    # 检查是否已安装
    if [ -x "$NDK_R24_DIR/ndk-build" ]; then
        log "  NDK r24 已存在 ✓"
        return 0
    fi
    
    mkdir -p "$SDK_DIR/ndk"
    # 清理不完整安装
    rm -rf "$NDK_R24_DIR" "$SDK_DIR/ndk/android-ndk-r24"
    
    local zip_file="$HOME/android-ndk-r24-aarch64.zip"
    download_file "$NDK_R24_URL" "$zip_file" "NDK r24"
    
    log "  解压 NDK r24..."
    cd "$SDK_DIR/ndk"
    unzip -q -o "$zip_file" || error_exit "NDK r24 解压失败"
    mv android-ndk-r24 "$NDK_R24_DIR" 2>/dev/null || true
    rm -f "$zip_file"
    
    if [ -x "$NDK_R24_DIR/ndk-build" ]; then
        log "  NDK r24 安装完成 ✓"
    else
        error_exit "NDK r24 安装不完整"
    fi
    
    # 修复 NDK r24 arm64 主机兼容性
    log "  修复 NDK r24 arm64 主机兼容性..."
    ln -sf linux-aarch64 "$NDK_R24_DIR/prebuilt/linux-x86_64"
    ln -sf linux-aarch64 "$NDK_R24_DIR/toolchains/llvm/prebuilt/linux-x86_64"
    log "  NDK r24 符号链接修复完成 ✓"
}

install_ndk_r29() {
    log "安装 NDK r29 (aarch64)..."
    
    # 检查是否已安装
    if [ -x "$NDK_R29_DIR/ndk-build" ]; then
        log "  NDK r29 已存在 ✓"
        return 0
    fi
    
    mkdir -p "$SDK_DIR/ndk"
    # 清理不完整安装
    rm -rf "$NDK_R29_DIR" "$SDK_DIR/ndk/ndk"
    
    local tar_file="$HOME/android-ndk-r29-aarch64.tar.gz"
    download_file "$NDK_R29_URL" "$tar_file" "NDK r29"
    
    log "  解压 NDK r29..."
    tar -xzf "$tar_file" -C "$SDK_DIR/ndk" || error_exit "NDK r29 解压失败"
    
    # tar 内层目录是 ndk/，移动到版本目录
    if [ -d "$SDK_DIR/ndk/ndk" ]; then
        mv "$SDK_DIR/ndk/ndk" "$NDK_R29_DIR"
    fi
    
    rm -f "$tar_file"
    
    if [ -x "$NDK_R29_DIR/ndk-build" ]; then
        log "  NDK r29 安装完成 ✓"
    else
        error_exit "NDK r29 安装不完整"
    fi
}

select_ndk() {
    echo ""
    echo "========================================="
    echo "  选择 NDK 版本"
    echo "========================================="
    echo ""
    echo "1) 下载并安装 NDK r24 (aarch64)"
    echo "   路径: $NDK_R24_DIR"
    echo ""
    echo "2) 下载并安装 NDK r29 (aarch64)"
    echo "   路径: $NDK_R29_DIR"
    echo ""
    echo "3) 全部下载并安装 (r24 + r29)"
    echo ""
    echo "4) 跳过 NDK 安装"
    echo ""
    read -p "请选择 [1-4]: " ndk_choice
    case "$ndk_choice" in
        1)
            install_ndk_r24
            export ANDROID_NDK_HOME="$NDK_R24_DIR"
            ;;
        2)
            install_ndk_r29
            export ANDROID_NDK_HOME="$NDK_R29_DIR"
            ;;
        3)
            install_ndk_r24
            install_ndk_r29
            export ANDROID_NDK_HOME="$NDK_R29_DIR"
            ;;
        4)
            log "跳过 NDK 安装"
            if [ -x "$NDK_R24_DIR/ndk-build" ]; then
                export ANDROID_NDK_HOME="$NDK_R24_DIR"
            elif [ -x "$NDK_R29_DIR/ndk-build" ]; then
                export ANDROID_NDK_HOME="$NDK_R29_DIR"
            fi
            ;;
        *)
            log "无效选择，跳过 NDK 安装"
            ;;
    esac
    
    # 将 ANDROID_NDK_HOME 写入 shell rc
    local RC_FILE
    RC_FILE=$(detect_shell_rc)
    if [ -n "${ANDROID_NDK_HOME:-}" ]; then
        if ! grep -q "^export ANDROID_NDK_HOME=" "$RC_FILE" 2>/dev/null; then
            echo "export ANDROID_NDK_HOME=$ANDROID_NDK_HOME" >> "$RC_FILE"
        else
            sed -i "s|^export ANDROID_NDK_HOME=.*|export ANDROID_NDK_HOME=$ANDROID_NDK_HOME|" "$RC_FILE"
        fi
        export PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-aarch64/bin:$ANDROID_NDK_HOME:$PATH"
    fi
}

# ============================================================
# 修复 aapt2（让 AGP 使用 arm64 原生 aapt2）
# ============================================================
fix_aapt2() {
    log "修复 aapt2 兼容性..."
    
    # 安装 Termux 原生 aapt2
    if ! command -v aapt2 >/dev/null 2>&1; then
        log "  安装 aapt2 (Termux 原生 arm64)..."
        pkg install -y aapt2 || { log "  警告：aapt2 安装失败，资源编译可能异常"; return 1; }
    else
        log "  aapt2 已安装 ✓"
    fi
    
    # 创建符号链接
    mkdir -p "$HOME/.androidide"
    ln -sf "$(command -v aapt2)" "$HOME/.androidide/aapt2" 2>/dev/null || true
    
    # 配置 gradle.properties
    mkdir -p "$HOME/.gradle"
    if ! grep -q "^android.aapt2FromMavenOverride=" "$HOME/.gradle/gradle.properties" 2>/dev/null; then
        echo "android.aapt2FromMavenOverride=$HOME/.androidide/aapt2" >> "$HOME/.gradle/gradle.properties"
    else
        sed -i "s|^android.aapt2FromMavenOverride=.*|android.aapt2FromMavenOverride=$HOME/.androidide/aapt2|" "$HOME/.gradle/gradle.properties"
    fi
    
    log "  aapt2 修复完成 ✓"
}

# ============================================================
# 网络安装
# ============================================================
network_install() {
    log "=== 开始网络安装 Android 开发环境 ==="
    log "Release: ${RELEASE_TAG}"
    
    # 检查必要工具
    for cmd in wget unzip tar xz; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log "  安装 $cmd..."
            pkg install -y "$cmd" || error_exit "安装 $cmd 失败"
        fi
    done
    
    # 下载并解压 JDK
    if [ -d "$JDK_DIR" ]; then
        log "检测到已存在的 $JDK_DIR，将覆盖..."
        rm -rf "$JDK_DIR"
    fi
    local jdk_file="$HOME/jdk.tar.gz"
    download_file "$JDK_URL" "$jdk_file" "JDK 21"
    log "解压 JDK..."
    tar -xzf "$jdk_file" -C "$HOME_DIR" || error_exit "JDK 解压失败"
    [ -d "$JDK_DIR" ] || error_exit "JDK 目录未创建"
    log "JDK 已安装到 $JDK_DIR ✓"
    rm -f "$jdk_file"
    
    # 下载并解压 Gradle
    if [ -d "$GRADLE_DIR" ]; then
        log "检测到已存在的 $GRADLE_DIR，将覆盖..."
        rm -rf "$GRADLE_DIR"
    fi
    local gradle_file="$HOME/gradle.tar.gz"
    download_file "$GRADLE_URL" "$gradle_file" "Gradle 8.13"
    log "解压 Gradle..."
    tar -xzf "$gradle_file" -C "$HOME_DIR" || error_exit "Gradle 解压失败"
    [ -d "$GRADLE_DIR" ] || error_exit "Gradle 目录未创建"
    log "Gradle 已安装到 $GRADLE_DIR ✓"
    rm -f "$gradle_file"
    
    # 下载并解压 Android SDK
    if [ -d "$SDK_DIR" ]; then
        log "检测到已存在的 $SDK_DIR，将覆盖..."
        rm -rf "$SDK_DIR"
    fi
    local sdk_file="$HOME/android-sdk.tar.gz"
    download_file "$SDK_URL" "$sdk_file" "Android SDK"
    log "解压 Android SDK..."
    tar -xzf "$sdk_file" -C "$HOME_DIR" || error_exit "Android SDK 解压失败"
    [ -d "$SDK_DIR" ] || error_exit "Android SDK 目录未创建"
    log "Android SDK 已安装到 $SDK_DIR ✓"
    rm -f "$sdk_file"
    
    # 配置环境变量
    log "配置环境变量..."
    local RC_FILE
    RC_FILE=$(detect_shell_rc)
    
    # 清理旧配置
    sed -i '/^export ANDROID_HOME=/d' "$RC_FILE" 2>/dev/null || true
    sed -i '/^export GRADLE_HOME=/d' "$RC_FILE" 2>/dev/null || true
    sed -i '/^export ANDROID_NDK_HOME=/d' "$RC_FILE" 2>/dev/null || true
    sed -i '/^export PATH=.*jdk\/bin/d' "$RC_FILE" 2>/dev/null || true
    sed -i '/^export PATH=.*gradle\/bin/d' "$RC_FILE" 2>/dev/null || true
    sed -i '/^export PATH=.*android-sdk\/cmdline-tools/d' "$RC_FILE" 2>/dev/null || true
    sed -i '/^export PATH=.*android-sdk\/platform-tools/d' "$RC_FILE" 2>/dev/null || true
    sed -i '/^export PATH=.*android-ndk/d' "$RC_FILE" 2>/dev/null || true
    
    # 写入新配置
    cat >> "$RC_FILE" << 'EOF'
# Android Development Environment (Network Install)
export ANDROID_HOME="$HOME/android-sdk"
export GRADLE_HOME="$HOME/gradle"
export PATH="$HOME/jdk/bin:$GRADLE_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
EOF
    
    # 当前会话生效
    export ANDROID_HOME="$SDK_DIR"
    export GRADLE_HOME="$GRADLE_DIR"
    export PATH="$JDK_DIR/bin:$GRADLE_HOME/bin:$SDK_DIR/cmdline-tools/latest/bin:$SDK_DIR/platform-tools:$PATH"
    
    log "环境变量已写入 $RC_FILE ✓"
    
    # 修复 aapt2 兼容性
    fix_aapt2
    
    # NDK 选择
    select_ndk
    
    # 验证
    log ""
    log "=== 验证安装 ==="
    [ -x "$JDK_DIR/bin/java" ] && log "[OK] JDK" || log "[FAIL] JDK"
    [ -x "$GRADLE_DIR/bin/gradle" ] && log "[OK] Gradle" || log "[FAIL] Gradle"
    [ -x "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ] && log "[OK] Android SDK cmdline-tools" || log "[FAIL] Android SDK cmdline-tools"
    [ -x "$SDK_DIR/platform-tools/adb" ] && log "[OK] Android SDK platform-tools" || log "[FAIL] Android SDK platform-tools"
    
    if [ -n "${ANDROID_NDK_HOME:-}" ] && [ -x "$ANDROID_NDK_HOME/ndk-build" ]; then
        log "[OK] Android NDK ($ANDROID_NDK_HOME)"
    else
        log "[INFO] Android NDK 未安装或未选择"
    fi
    
    log ""
    log "安装完成！请执行 'source $RC_FILE' 使环境变量生效，或重新打开终端。"
}

# ============================================================
# 卸载
# ============================================================
local_uninstall() {
    log "=== 开始卸载本地安装的 Android 开发环境 ==="
    
    local RC_FILE
    RC_FILE=$(detect_shell_rc)
    
    # 清理环境变量
    log "清理环境变量配置..."
    sed -i '/^export ANDROID_HOME=/d' "$RC_FILE" 2>/dev/null || true
    sed -i '/^export GRADLE_HOME=/d' "$RC_FILE" 2>/dev/null || true
    sed -i '/^export ANDROID_NDK_HOME=/d' "$RC_FILE" 2>/dev/null || true
    sed -i '/^export PATH=.*jdk\/bin/d' "$RC_FILE" 2>/dev/null || true
    sed -i '/^export PATH=.*gradle\/bin/d' "$RC_FILE" 2>/dev/null || true
    sed -i '/^export PATH=.*android-sdk\/cmdline-tools/d' "$RC_FILE" 2>/dev/null || true
    sed -i '/^export PATH=.*android-sdk\/platform-tools/d' "$RC_FILE" 2>/dev/null || true
    sed -i '/^export PATH=.*android-ndk/d' "$RC_FILE" 2>/dev/null || true
    
    # 取消当前会话环境变量
    unset ANDROID_HOME
    unset GRADLE_HOME
    unset ANDROID_NDK_HOME
    export PATH="$(echo "$PATH" | tr ':' '\n' | grep -v -E '(jdk/bin|gradle/bin|android-sdk/cmdline-tools|android-sdk/platform-tools|android-ndk)' | tr '\n' ':' | sed 's/:$//')"
    
    log "环境变量已清理 ✓"
    
    # 删除目录
    log "删除安装目录..."
    for d in "$NDK_R24_DIR" "$NDK_R29_DIR" "$SDK_DIR" "$GRADLE_DIR" "$JDK_DIR"; do
        if [ -d "$d" ]; then
            log "  删除 $d"
            rm -rf "$d"
        else
            log "  $d 不存在，跳过"
        fi
    done
    
    log ""
    log "卸载完成！"
    log "请执行 'source $RC_FILE' 或重新打开终端以使环境变量完全清除。"
}

# ============================================================
# 菜单
# ============================================================
menu() {
    clear
    echo "========================================="
    echo "  Android 开发环境网络管理脚本"
    echo "========================================="
    echo ""
    echo "Release: ${RELEASE_TAG}"
    echo "仓库: ${REPO}"
    echo ""
    echo "1) 网络安装 (从 Release Assets 下载)"
    echo "2) 卸载"
    echo "3) 退出"
    echo ""
    read -p "请选择操作 [1-3]: " choice
    case "$choice" in
        1) network_install ;;
        2) local_uninstall ;;
        3) exit 0 ;;
        *) log "无效选择"; sleep 2; menu ;;
    esac
}

menu
