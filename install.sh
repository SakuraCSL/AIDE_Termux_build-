#!/bin/bash
set -uo pipefail

# ============================================================
# 一键安装 Android 开发环境 (Termux)
# 支持断点续传、跳过已安装、完整性检查
# 修改点：下载显示进度条（--show-progress）+ 续传（-c）
# ============================================================

# 配置
readonly ANDROID_HOME="$HOME/android-sdk"
readonly GRADLE_HOME="$HOME/gradle-8.13/gradle-8.13"
readonly ANDROID_NDK_HOME="$ANDROID_HOME/ndk/24.0.8215888"
readonly LOCK_FILE="$HOME/.android_env_install.lock"

readonly CMDLINE_TOOLS_VERSION="11076708"
readonly GRADLE_VERSION="8.13"
readonly NDK_VERSION="24.0.8215888"

readonly CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
readonly GRADLE_URL="https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-all.zip"
readonly NDK_URL="https://github.com/jzinferno2/termux-ndk/releases/download/v1/android-ndk-r24-aarch64.zip"

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

# 检查目录是否完整（关键文件是否存在）
dir_has() {
    [ -d "$1" ] && [ -n "$(find "$1" -maxdepth 1 -type f 2>/dev/null)" ]
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
    log "[1/6] 检查基础依赖..."
    
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
    log "[2/6] 检查 Android SDK cmdline-tools..."
    local target_dir="$ANDROID_HOME/cmdline-tools/latest"
    local zip_file="$ANDROID_HOME/cmdline-tools/cmdline-tools.zip"
    
    if [ -x "$target_dir/bin/sdkmanager" ]; then
        log "  cmdline-tools 已存在 ✓"
        return 0
    fi
    
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    # 清理不完整安装（保留已下载的zip）
    rm -rf "$ANDROID_HOME/cmdline-tools/latest" "$ANDROID_HOME/cmdline-tools/cmdline-tools"
    
    cd "$ANDROID_HOME/cmdline-tools"
    log "  下载 cmdline-tools..."
    # 修改：显示进度 + 断点续传（去掉 2>/dev/null）
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
    log "[3/6] 检查 Gradle ${GRADLE_VERSION}..."
    if [ -x "$GRADLE_HOME/bin/gradle" ]; then
        log "  Gradle ${GRADLE_VERSION} 已存在 ✓"
        return 0
    fi
    
    mkdir -p "$HOME/gradle-${GRADLE_VERSION}"
    local zip_file="$HOME/gradle-${GRADLE_VERSION}/gradle-${GRADLE_VERSION}-all.zip"
    
    cd "$HOME/gradle-${GRADLE_VERSION}"
    log "  下载 Gradle ${GRADLE_VERSION}..."
    # 修改：显示进度 + 断点续传（去掉 2>/dev/null）
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
# 4. NDK r24
# ============================================================
install_ndk() {
    log "[4/6] 检查 NDK r24 (aarch64)..."
    if [ -x "$ANDROID_NDK_HOME/ndk-build" ]; then
        log "  NDK r24 已存在 ✓"
        return 0
    fi
    
    mkdir -p "$ANDROID_HOME/ndk"
    local zip_file="$ANDROID_HOME/ndk/android-ndk-r24-aarch64.zip"
    
    cd "$ANDROID_HOME/ndk"
    log "  下载 NDK r24 (aarch64)..."
    # 修改：显示进度 + 断点续传（去掉 2>/dev/null）
    wget --show-progress -c -O "$zip_file" "$NDK_URL" || \
        error_exit "下载 NDK 失败，请检查网络"
    
    if [ ! -s "$zip_file" ]; then
        error_exit "NDK 下载文件为空，请检查网络"
    fi
    
    log "  解压 NDK..."
    rm -rf "24.0.8215888" "android-ndk-r24"
    unzip -q -o "$zip_file" || error_exit "解压 NDK 失败"
    mv android-ndk-r24 "24.0.8215888"
    rm -f "$zip_file"
    
    if [ -x "$ANDROID_NDK_HOME/ndk-build" ]; then
        log "  NDK r24 安装完成 ✓"
    else
        error_exit "NDK 安装不完整"
    fi
    
    # Fix: NDK r24 uses linux-aarch64, but AGP expects linux-x86_64
    log "  修复 NDK r24 arm64 主机兼容性..."
    ln -sf linux-aarch64 "$ANDROID_NDK_HOME/prebuilt/linux-x86_64"
    ln -sf linux-aarch64 "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
    log "  NDK 符号链接修复完成 ✓"
}

# ============================================================
# 5. 环境变量
# ============================================================
configure_env() {
    log "[5/6] 配置环境变量..."
    
    local BASHRC="$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && BASHRC="$HOME/.zshrc"
    
    # 先删除旧的 Android 相关环境变量，避免重复或路径污染
    sed -i '/^export ANDROID_HOME=/d' "$BASHRC" 2>/dev/null
    sed -i '/^export GRADLE_HOME=/d' "$BASHRC" 2>/dev/null
    sed -i '/^export ANDROID_NDK_HOME=/d' "$BASHRC" 2>/dev/null
    sed -i '/^export PATH=.*android-sdk\/cmdline-tools/d' "$BASHRC" 2>/dev/null
    sed -i '/^export PATH=.*gradle/d' "$BASHRC" 2>/dev/null
    sed -i '/^export PATH=.*android-ndk/d' "$BASHRC" 2>/dev/null
    
    # 写入新变量
    local -a env_lines=(
        "export ANDROID_HOME=$HOME/android-sdk"
        "export GRADLE_HOME=$HOME/gradle-8.13/gradle-8.13"
        "export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/24.0.8215888"
        'export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH'
        'export PATH=$GRADLE_HOME/bin:$PATH'
        'export PATH=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-aarch64/bin:$PATH'
        'export PATH=$ANDROID_NDK_HOME:$PATH'
    )
    
    for line in "${env_lines[@]}"; do
        echo "$line" >> "$BASHRC"
    done
    
    # 当前会话也生效
    export ANDROID_HOME
    export GRADLE_HOME
    export ANDROID_NDK_HOME
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$GRADLE_HOME/bin:$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-aarch64/bin:$ANDROID_NDK_HOME:$PATH"
    
    # Fix: create ~/.androidide/aapt2 symlink for AGP to find aapt2 on arm64 host
    mkdir -p "$HOME/.androidide"
    ln -sf "$(command -v aapt2)" "$HOME/.androidide/aapt2"
    
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
# 6. SDK 组件
# ============================================================
install_sdk_components() {
    log "[6/6] 检查并安装 SDK 组件..."
    
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
    [ -x "$ANDROID_NDK_HOME/ndk-build" ] && log "  [OK] NDK r24" || { log "  [FAIL] NDK r24 缺失"; failed=1; }
    
    log ""
    [ "$failed" -eq 1 ] && { log "警告：部分组件未安装成功！请检查网络后重新运行此脚本"; return 1; }
    log "所有组件安装完整 ✓"
    return 0
}

# ============================================================
# 主流程
# ============================================================
main() {
    log "========================================"
    log " Android 开发环境一键安装"
    log "========================================"
    log "安装目标:"
    log "  ANDROID_HOME:    $ANDROID_HOME"
    log "  GRADLE_HOME:     $GRADLE_HOME"
    log "  ANDROID_NDK_HOME: $ANDROID_NDK_HOME"
    log ""
    
    acquire_lock
    
    if ! has_cmd pkg; then
        error_exit "此脚本仅适用于 Termux 环境"
    fi
    
    log "检查 Termux 镜像源..."
    if ! pkg update -y >/dev/null 2>&1; then
        log "镜像源不可用，尝试修复..."
        fix_termux_mirror tuna || fix_termux_mirror ustc
        pkg update -y || error_exit "pkg 更新失败，请检查网络"
    else
        log "镜像源正常 ✓"
    fi
    
    install_dependencies
    install_cmdline_tools
    install_gradle
    install_ndk
    configure_env
    install_sdk_components
    
    log ""
    integrity_check
    
    log ""
    log "========================================"
    log " 安装完成！"
    log "========================================"
    log "请执行以下命令使环境变量生效："
    log "  source ~/.bashrc"
    log "  或 source ~/.zshrc"
    log ""
    log "验证安装："
    log "  java -version"
    log "  gradle --version"
    log "  echo \$ANDROID_NDK_HOME"
    log ""
    
    release_lock
}

main "$@"