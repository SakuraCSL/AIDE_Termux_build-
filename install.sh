#!/bin/bash
set -uo pipefail

# ============================================================
# Android 开发环境一键安装 (Termux)
# 支持断点续传、跳过已安装、完整性检查
# 修改：增加互动菜单、支持卸载、NDK r24/r29选择
# ============================================================

# 配置
ANDROID_HOME="$HOME/android-sdk"
GRADLE_HOME="$HOME/gradle-8.13/gradle-8.13"
ANDROID_NDK_HOME_R24="$ANDROID_HOME/ndk/24.0.8215888"
ANDROID_NDK_HOME_R29="$ANDROID_HOME/ndk/29.0.13113456"
LOCK_FILE="$HOME/.android_env_install.lock"

CMDLINE_TOOLS_VERSION="11076708"
GRADLE_VERSION="8.13"
NDK_R24_VERSION="24.0.8215888"

readonly CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
readonly GRADLE_URL="https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-all.zip"
readonly NDK_R24_URL="https://github.com/jzinferno2/termux-ndk/releases/download/v1/android-ndk-r24-aarch64.zip"
readonly NDK_R29_URL="https://github.com/AndroidIDE-CN/resource/releases/download/aidepro/ndk.tar.xz"

# 日志
log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

error_exit() {
    log "ERROR: $*"
    rm -f "$LOCK_FILE"
    exit 1
}

# 锁文件（防止并发/重复运行）
acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
            error_exit "另一个安装进程正在运行 (PID: $pid)，请稍候或删除 $LOCK_FILE"
        else
            log "检测到残留锁文件，清理中..."
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

release_lock() {
    rm -f "$LOCK_FILE"
}

# 检查命令是否存在
has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# 修复 Termux 镜像源
fix_termux_mirror() {
    local mirror="${1:-tuna}"
    local sources_file="$PREFIX/etc/apt/sources.list"
    
    if [ ! -f "$sources_file" ]; then
        log "  无法找到 Termux sources.list: $sources_file"
        return 1
    fi
    
    case "$mirror" in
        tuna)
            log "  切换至清华镜像..."
            cat > "$sources_file" << 'EOF'
deb https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main stable main
deb https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-x11/ x11 main
EOF
            ;;
        ustc)
            log "  切换至中科大镜像..."
            cat > "$sources_file" << 'EOF'
deb https://mirrors.ustc.edu.cn/termux/apt/termux-main stable main
deb https://mirrors.ustc.edu.cn/termux/apt/termux-x11/ x11 main
EOF
            ;;
        *)
            log "  未知镜像: $mirror"
            return 1
            ;;
    esac
    
    pkg update -y >/dev/null 2>&1
    log "  镜像已切换，pkg update 完成"
    return 0
}

# ============================================================
# 1. 基础依赖
# ============================================================
install_dependencies() {
    log "[1/5] 检查基础依赖..."
    
    if ! has_cmd pkg; then
        error_exit "pkg 命令不存在，请确保在 Termux 环境中运行此脚本"
    fi
    
    # OpenJDK 21
    if has_cmd java && java -version 2>&1 | grep -q "21"; then
        log "  OpenJDK 21 已安装 ✓"
    else
        log "  安装 OpenJDK 21..."
        if ! pkg install -y openjdk-21; then
            log "  安装失败，尝试修复镜像..."
            fix_termux_mirror tuna || fix_termux_mirror ustc
            pkg update -y
            pkg install -y openjdk-21 || error_exit "安装 OpenJDK 21 失败"
        fi
    fi
    
    # wget
    if has_cmd wget; then
        log "  wget 已安装 ✓"
    else
        log "  安装 wget..."
        if ! pkg install -y wget; then
            log "  安装失败，尝试修复镜像..."
            fix_termux_mirror tuna || fix_termux_mirror ustc
            pkg update -y
            pkg install -y wget || error_exit "安装 wget 失败"
        fi
    fi
    
    # unzip
    if has_cmd unzip; then
        log "  unzip 已安装 ✓"
    else
        log "  安装 unzip..."
        if ! pkg install -y unzip; then
            log "  安装失败，尝试修复镜像..."
            fix_termux_mirror tuna || fix_termux_mirror ustc
            pkg update -y
            pkg install -y unzip || error_exit "安装 unzip 失败"
        fi
    fi
    
    # xz-utils (用于解压 tar.xz)
    if has_cmd xz; then
        log "  xz-utils 已安装 ✓"
    else
        log "  安装 xz-utils..."
        if ! pkg install -y xz-utils; then
            log "  安装失败，尝试修复镜像..."
            fix_termux_mirror tuna || fix_termux_mirror ustc
            pkg update -y
            pkg install -y xz-utils || error_exit "安装 xz-utils 失败"
        fi
    fi
    
    # 额外依赖：确保 SDK 工具二进制能运行
    if ! pkg list-installed libc++ 2>/dev/null | grep -q libc++; then
        log "  安装 libc++..."
        pkg install -y libc++ || log "  警告：libc++ 安装失败，部分工具可能无法运行"
    fi
    
    # aapt2: Termux 原生 arm64 版本，避免 AGP 使用 x86_64 二进制导致 Daemon 启动失败
    if ! pkg list-installed aapt2 2>/dev/null | grep -q aapt2; then
        log "  安装 aapt2 (Termux 原生 arm64)..."
        pkg install -y aapt2 || log "  警告：aapt2 安装失败，资源编译可能异常"
    else
        log "  aapt2 已安装 ✓"
    fi
}

# ============================================================
# 2. cmdline-tools
# ============================================================
install_cmdline_tools() {
    log "[2/5] 检查 Android SDK cmdline-tools..."
    local target_dir="$ANDROID_HOME/cmdline-tools/latest"
    local zip_file="$ANDROID_HOME/cmdline-tools/cmdline-tools.zip"
    
    if [ -x "$target_dir/bin/sdkmanager" ]; then
        log "  cmdline-tools 已存在 ✓"
        return 0
    fi
    
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    rm -rf "$ANDROID_HOME/cmdline-tools/latest" "$ANDROID_HOME/cmdline-tools/cmdline-tools"
    
    cd "$ANDROID_HOME/cmdline-tools"
    log "  下载 cmdline-tools..."
    wget --show-progress -c -O "$zip_file" "$CMDLINE_URL" || \
        error_exit "下载 cmdline-tools 失败，请检查网络"
    
    if [ ! -s "$zip_file" ]; then
        error_exit "cmdline-tools 下载文件为空，请检查网络"
    fi
    
    log "  解压 cmdline-tools..."
    unzip -q -o "$zip_file" || error_exit "解压 cmdline-tools 失败"
    mv cmdline-tools latest
    rm -f "$zip_file"
    
    if [ -x "$target_dir/bin/sdkmanager" ]; then
        log "  cmdline-tools 安装完成 ✓"
    else
        error_exit "cmdline-tools 安装不完整"
    fi
}

# ============================================================
# 3. Gradle
# ============================================================
install_gradle() {
    log "[3/5] 检查 Gradle ${GRADLE_VERSION}..."
    if [ -x "$GRADLE_HOME/bin/gradle" ]; then
        log "  Gradle ${GRADLE_VERSION} 已存在 ✓"
        return 0
    fi
    
    mkdir -p "$HOME/gradle-${GRADLE_VERSION}"
    local zip_file="$HOME/gradle-${GRADLE_VERSION}/gradle-${GRADLE_VERSION}-all.zip"
    
    cd "$HOME/gradle-${GRADLE_VERSION}"
    log "  下载 Gradle ${GRADLE_VERSION}..."
    wget --show-progress -c -O "$zip_file" "$GRADLE_URL" || \
        error_exit "下载 Gradle 失败，请检查网络"
    
    if [ ! -s "$zip_file" ]; then
        error_exit "Gradle 下载文件为空，请检查网络"
    fi
    
    log "  解压 Gradle..."
    rm -rf "gradle-${GRADLE_VERSION}"
    unzip -q -o "$zip_file" || error_exit "解压 Gradle 失败"
    rm -f "$zip_file"
    
    if [ -x "$GRADLE_HOME/bin/gradle" ]; then
        log "  Gradle ${GRADLE_VERSION} 安装完成 ✓"
    else
        error_exit "Gradle 安装不完整"
    fi
}

# ============================================================
# 4. 环境变量
# ============================================================
configure_env() {
    log "[4/5] 配置环境变量..."
    
    local BASHRC="$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && BASHRC="$HOME/.zshrc"
    
    # 先删除旧的 Android 相关环境变量，避免重复或路径污染
    sed -i '/^export ANDROID_HOME=/d' "$BASHRC" 2>/dev/null || true
    sed -i '/^export GRADLE_HOME=/d' "$BASHRC" 2>/dev/null || true
    sed -i '/^export ANDROID_NDK_HOME=/d' "$BASHRC" 2>/dev/null || true
    sed -i '/^export PATH=.*android-sdk\/cmdline-tools/d' "$BASHRC" 2>/dev/null || true
    sed -i '/^export PATH=.*gradle/d' "$BASHRC" 2>/dev/null || true
    sed -i '/^export PATH=.*android-ndk/d' "$BASHRC" 2>/dev/null || true
    
    # 写入新变量（不指定具体 NDK 版本，由外部设置）
    local -a env_lines=(
        "export ANDROID_HOME=$HOME/android-sdk"
        "export GRADLE_HOME=$HOME/gradle-8.13/gradle-8.13"
        'export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH'
        'export PATH=$GRADLE_HOME/bin:$PATH'
    )
    
    for line in "${env_lines[@]}"; do
        echo "$line" >> "$BASHRC"
    done
    
    # 当前会话也生效
    export ANDROID_HOME
    export GRADLE_HOME
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$GRADLE_HOME/bin:$PATH"
    
    # Fix: create ~/.androidide/aapt2 symlink for AGP to find aapt2 on arm64 host
    mkdir -p "$HOME/.androidide"
    ln -sf "$(command -v aapt2)" "$HOME/.androidide/aapt2" 2>/dev/null || true
    
    # Fix: ensure ~/.gradle/gradle.properties points to the arm64 aapt2
    mkdir -p "$HOME/.gradle"
    if ! grep -q "^android.aapt2FromMavenOverride=" "$HOME/.gradle/gradle.properties" 2>/dev/null; then
        echo "android.aapt2FromMavenOverride=$HOME/.androidide/aapt2" >> "$HOME/.gradle/gradle.properties"
    else
        sed -i "s|^android.aapt2FromMavenOverride=.*|android.aapt2FromMavenOverride=$HOME/.androidide/aapt2|" "$HOME/.gradle/gradle.properties"
    fi
    
    log "  环境变量已写入 $BASHRC ✓"
}

# ============================================================
# 5. SDK 组件
# ============================================================
install_sdk_components() {
    log "[5/5] 检查并安装 SDK 组件..."
    
    local sdkmanager="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
    
    if [ ! -x "$sdkmanager" ]; then
        error_exit "sdkmanager 不存在，请先安装 cmdline-tools"
    fi
    
    local to_install=()
    [ ! -d "$ANDROID_HOME/platform-tools" ] && to_install+=("platform-tools")
    [ ! -d "$ANDROID_HOME/platforms/android-34" ] && to_install+=("platforms;android-34")
    [ ! -d "$ANDROID_HOME/build-tools/34.0.0" ] && to_install+=("build-tools;34.0.0")
    
    if [ ${#to_install[@]} -eq 0 ]; then
        log "  SDK 组件已完整，跳过 ✓"
        return 0
    fi
    
    log "  需要安装: ${to_install[*]}"
    
    # 先接受 license（忽略错误，有些镜像已经预接受）
    log "  接受 SDK license..."
    yes | "$sdkmanager" --sdk_root="$ANDROID_HOME" --licenses >/dev/null 2>&1 || true
    
    # 安装组件，忽略 license 相关的非零退出码
    log "  安装 SDK 组件..."
    if ! yes | "$sdkmanager" --sdk_root="$ANDROID_HOME" "${to_install[@]}"; then
        log "  警告：sdkmanager 返回非零，但可能已安装成功，正在验证..."
    fi
    
    # 验证实际文件是否存在
    local failed=0
    for comp in "${to_install[@]}"; do
        if [ "$comp" = "platform-tools" ]; then
            [ -x "$ANDROID_HOME/platform-tools/adb" ] || failed=1
        elif [ "$comp" = "platforms;android-34" ]; then
            [ -d "$ANDROID_HOME/platforms/android-34" ] || failed=1
        elif [ "$comp" = "build-tools;34.0.0" ]; then
            [ -x "$ANDROID_HOME/build-tools/34.0.0/aapt" ] || failed=1
        fi
    done
    
    if [ "$failed" -eq 0 ]; then
        log "  SDK 组件安装完成 ✓"
    else
        error_exit "SDK 组件安装不完整"
    fi
}

# ============================================================
# 6. NDK（最后一步，用户选择）
# ============================================================
install_ndk_r24() {
    log "[6/6] 检查 NDK r24 (aarch64)..."
    if [ -x "$ANDROID_NDK_HOME_R24/ndk-build" ]; then
        log "  NDK r24 已存在 ✓"
        return 0
    fi
    
    mkdir -p "$ANDROID_HOME/ndk"
    local zip_file="$ANDROID_HOME/ndk/android-ndk-r24-aarch64.zip"
    
    cd "$ANDROID_HOME/ndk"
    log "  下载 NDK r24 (aarch64)..."
    wget --show-progress -c -O "$zip_file" "$NDK_R24_URL" || \
        error_exit "下载 NDK r24 失败，请检查网络"
    
    if [ ! -s "$zip_file" ]; then
        error_exit "NDK r24 下载文件为空，请检查网络"
    fi
    
    log "  解压 NDK r24..."
    rm -rf "$NDK_R24_VERSION" "android-ndk-r24"
    unzip -q -o "$zip_file" || error_exit "解压 NDK r24 失败"
    mv android-ndk-r24 "$NDK_R24_VERSION"
    rm -f "$zip_file"
    
    if [ -x "$ANDROID_NDK_HOME_R24/ndk-build" ]; then
        log "  NDK r24 安装完成 ✓"
    else
        error_exit "NDK r24 安装不完整"
    fi
    
    # Fix: NDK r24 uses linux-aarch64, but AGP expects linux-x86_64
    log "  修复 NDK r24 arm64 主机兼容性..."
    ln -sf linux-aarch64 "$ANDROID_NDK_HOME_R24/prebuilt/linux-x86_64"
    ln -sf linux-aarch64 "$ANDROID_NDK_HOME_R24/toolchains/llvm/prebuilt/linux-x86_64"
    log "  NDK r24 符号链接修复完成 ✓"
}

install_ndk_r29() {
    log "[6/6] 检查 NDK r29 (aarch64)..."
    if [ -x "$ANDROID_NDK_HOME_R29/ndk-build" ]; then
        log "  NDK r29 已存在 ✓"
        return 0
    fi
    
    mkdir -p "$HOME"
    mkdir -p "$ANDROID_HOME/ndk"
    local tar_file="$HOME/android-ndk-r29-aarch64.tar.gz"
    
    cd "$HOME"
    log "  下载 NDK r29 (aarch64)..."
    wget --show-progress -c -O "$tar_file" "$NDK_R29_URL" || \
        error_exit "下载 NDK r29 失败，请检查网络"
    
    if [ ! -s "$tar_file" ]; then
        error_exit "NDK r29 下载文件为空，请检查网络"
    fi
    
    log "  解压 NDK r29..."
    rm -rf "$ANDROID_NDK_HOME_R29" "ndk"
    tar -xzf "$tar_file" || error_exit "解压 NDK r29 失败"
    mv ndk "$ANDROID_NDK_HOME_R29"
    rm -f "$tar_file"
    
    if [ -x "$ANDROID_NDK_HOME_R29/ndk-build" ]; then
        log "  NDK r29 安装完成 ✓"
    else
        error_exit "NDK r29 安装不完整"
    fi
}

select_ndk() {
    echo ""
    echo "========================================"
    echo "  选择 NDK 版本"
    echo "========================================"
    echo ""
    echo "1) 下载并安装 NDK r24 (aarch64)"
    echo "   路径: $ANDROID_NDK_HOME_R24"
    echo ""
    echo "2) 下载并安装 NDK r29 (aarch64)"
    echo "   路径: $ANDROID_NDK_HOME_R29"
    echo "   链接: $NDK_R29_URL"
    echo ""
    echo "3) 全部下载并安装 (r24 + r29)"
    echo ""
    echo "4) 跳过 NDK 安装"
    echo ""
    read -p "请选择 [1-4]: " ndk_choice
    case "$ndk_choice" in
        1)
            install_ndk_r24
            export ANDROID_NDK_HOME="$ANDROID_NDK_HOME_R24"
            ;;
        2)
            install_ndk_r29
            export ANDROID_NDK_HOME="$ANDROID_NDK_HOME_R29"
            ;;
        3)
            install_ndk_r24
            install_ndk_r29
            export ANDROID_NDK_HOME="$ANDROID_NDK_HOME_R29"
            ;;
        4)
            log "跳过 NDK 安装"
            if [ -x "$ANDROID_NDK_HOME_R24/ndk-build" ]; then
                export ANDROID_NDK_HOME="$ANDROID_NDK_HOME_R24"
            elif [ -x "$ANDROID_NDK_HOME_R29/ndk-build" ]; then
                export ANDROID_NDK_HOME="$ANDROID_NDK_HOME_R29"
            fi
            ;;
        *)
            log "无效选择，跳过 NDK 安装"
            ;;
    esac
    
    # 将 ANDROID_NDK_HOME 写入 shell rc
    local BASHRC="$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && BASHRC="$HOME/.zshrc"
    if [ -n "${ANDROID_NDK_HOME:-}" ]; then
        if ! grep -q "^export ANDROID_NDK_HOME=" "$BASHRC" 2>/dev/null; then
            echo "export ANDROID_NDK_HOME=$ANDROID_NDK_HOME" >> "$BASHRC"
        else
            sed -i "s|^export ANDROID_NDK_HOME=.*|export ANDROID_NDK_HOME=$ANDROID_NDK_HOME|" "$BASHRC"
        fi
        export PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-aarch64/bin:$ANDROID_NDK_HOME:$PATH"
    fi
}

# ============================================================
# 完整性检查
# ============================================================
integrity_check() {
    log ""
    log "=== 完整性检查 ==="
    local failed=0
    
    [ -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ] && log "  [OK] cmdline-tools" || { log "  [FAIL] cmdline-tools 缺失"; failed=1; }
    [ -x "$ANDROID_HOME/platform-tools/adb" ] && log "  [OK] platform-tools" || { log "  [FAIL] platform-tools 缺失"; failed=1; }
    [ -d "$ANDROID_HOME/platforms/android-34" ] && log "  [OK] platforms;android-34" || { log "  [FAIL] platforms;android-34 缺失"; failed=1; }
    [ -x "$ANDROID_HOME/build-tools/34.0.0/aapt" ] && log "  [OK] build-tools;34.0.0" || { log "  [FAIL] build-tools;34.0.0 缺失"; failed=1; }
    [ -x "$GRADLE_HOME/bin/gradle" ] && log "  [OK] Gradle ${GRADLE_VERSION}" || { log "  [FAIL] Gradle ${GRADLE_VERSION} 缺失"; failed=1; }
    
    if [ -n "${ANDROID_NDK_HOME:-}" ] && [ -x "$ANDROID_NDK_HOME/ndk-build" ]; then
        log "  [OK] NDK ($ANDROID_NDK_HOME)"
    else
        log "  [INFO] NDK 未安装或未选择"
    fi
    
    log ""
    [ "$failed" -eq 1 ] && { log "警告：部分组件未安装成功！请检查网络后重新运行此脚本"; return 1; }
    log "核心组件安装完整 ✓"
    return 0
}

# ============================================================
# 卸载
# ============================================================
uninstall_all() {
    log "=== 开始卸载 Android 开发环境 ==="
    
    local BASHRC="$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && BASHRC="$HOME/.zshrc"
    
    # 清理环境变量
    log "清理环境变量配置..."
    sed -i '/^export ANDROID_HOME=/d' "$BASHRC" 2>/dev/null || true
    sed -i '/^export GRADLE_HOME=/d' "$BASHRC" 2>/dev/null || true
    sed -i '/^export ANDROID_NDK_HOME=/d' "$BASHRC" 2>/dev/null || true
    sed -i '/^export PATH=.*android-sdk\/cmdline-tools/d' "$BASHRC" 2>/dev/null || true
    sed -i '/^export PATH=.*gradle/d' "$BASHRC" 2>/dev/null || true
    sed -i '/^export PATH=.*android-ndk/d' "$BASHRC" 2>/dev/null || true
    
    # 取消当前会话环境变量
    unset ANDROID_HOME
    unset GRADLE_HOME
    unset ANDROID_NDK_HOME
    export PATH="$(echo "$PATH" | tr ':' '\n' | grep -v -E '(android-sdk/cmdline-tools|gradle/bin|android-ndk|jdk/bin)' | tr '\n' ':' | sed 's/:$//')"
    
    log "环境变量已清理 ✓"
    
    # 删除目录
    log "删除安装目录..."
    for d in "$ANDROID_NDK_HOME_R24" "$ANDROID_NDK_HOME_R29" "$ANDROID_HOME" "$GRADLE_HOME" "$HOME/jdk"; do
        if [ -d "$d" ]; then
            log "  删除 $d"
            rm -rf "$d"
        else
            log "  $d 不存在，跳过"
        fi
    done
    
    # 清理 gradle.properties 中的 aapt2 配置
    if [ -f "$HOME/.gradle/gradle.properties" ]; then
        sed -i '/^android.aapt2FromMavenOverride=/d' "$HOME/.gradle/gradle.properties" 2>/dev/null || true
    fi
    
    log ""
    log "卸载完成！"
    log "请执行 'source $BASHRC' 或重新打开终端以使环境变量完全清除。"
}

# ============================================================
# 菜单
# ============================================================
menu() {
    clear
    echo "========================================"
    echo "  Android 开发环境管理脚本"
    echo "========================================"
    echo ""
    echo "脚本目录: $HOME/android-sdk (若已安装)"
    echo ""
    echo "1) 安装 (在线下载)"
    echo "2) 卸载"
    echo "3) 退出"
    echo ""
    read -p "请选择操作 [1-3]: " choice
    case "$choice" in
        1)
            main_install
            ;;
        2)
            uninstall_all
            ;;
        3)
            exit 0
            ;;
        *)
            log "无效选择"
            sleep 2
            menu
            ;;
    esac
}

menu
