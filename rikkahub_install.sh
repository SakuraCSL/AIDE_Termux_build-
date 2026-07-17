#!/bin/bash

set -euo pipefail


############################################
# Android 开发环境安装脚本
# RikkaHub / Debian / Ubuntu / Termux proot
############################################


readonly RELEASE_TAG="v2.0"
readonly REPO="SakuraCSL/AIDE_Termux_build-"

readonly BASE_URL="https://github.com/${REPO}/releases/download/${RELEASE_TAG}"


readonly JDK_URL="${BASE_URL}/JDK_21.tar.gz"
readonly GRADLE_URL="${BASE_URL}/gradle.tar.gz"
readonly SDK_URL="${BASE_URL}/android-sdk.tar.gz"

readonly NDK_R24_URL="${BASE_URL}/android-ndk-r24-aarch64.zip"
readonly NDK_R29_URL="${BASE_URL}/android-ndk-r29-aarch64.tar.gz"



HOME_DIR="$HOME"

JDK_DIR="$HOME_DIR/jdk"
GRADLE_DIR="$HOME_DIR/gradle"
SDK_DIR="$HOME_DIR/android-sdk"

NDK_DIR="$SDK_DIR/ndk"

NDK_R24_DIR="$NDK_DIR/24.0.8215888"
NDK_R29_DIR="$NDK_DIR/29.0.13113456"



############################################
# 日志
############################################


日志()
{
    echo
    echo "[+] $*"
}


错误()
{
    echo
    echo "[错误] $*"
    exit 1
}



############################################
# 检测架构
############################################


检测架构()
{

    ARCH=$(uname -m)


    case "$ARCH" in

        aarch64|arm64)

            日志 "检测到 ARM64 架构"

        ;;


        x86_64)

            日志 "检测到 x86_64 架构"

        ;;


        *)

            错误 "不支持的架构: $ARCH"

        ;;

    esac

}



############################################
# 安装依赖
############################################


安装依赖()
{

日志 "安装系统依赖..."


apt-get update -qq || true


apt-get install -y \
wget \
curl \
tar \
unzip \
xz-utils \
aapt2 \
|| 错误 "依赖安装失败"



日志 "依赖安装完成"

}




############################################
# 下载函数
############################################


下载()
{

URL="$1"
FILE="$2"
NAME="$3"



日志 "下载 $NAME"



wget \
--continue \
--tries=5 \
--timeout=30 \
--show-progress \
-o /dev/stdout \
-O "$FILE" \
"$URL" \
|| 错误 "$NAME 下载失败"



if [ ! -s "$FILE" ]
then

错误 "$NAME 文件为空"

fi



日志 "$NAME 下载完成"

}




############################################
# 安装 JDK
############################################


安装JDK()
{


日志 "安装 JDK 21"



rm -rf "$JDK_DIR"



下载 \
"$JDK_URL" \
"$HOME/jdk.tar.gz" \
"JDK 21"



tar xf \
"$HOME/jdk.tar.gz" \
-C "$HOME"



rm "$HOME/jdk.tar.gz"



[ -d "$JDK_DIR" ] \
|| 错误 "JDK目录不存在"



日志 "JDK安装完成"

}




############################################
# 安装 Gradle
############################################


安装Gradle()
{


日志 "安装 Gradle"



rm -rf "$GRADLE_DIR"



下载 \
"$GRADLE_URL" \
"$HOME/gradle.tar.gz" \
"Gradle"



tar xf \
"$HOME/gradle.tar.gz" \
-C "$HOME"



rm "$HOME/gradle.tar.gz"



[ -d "$GRADLE_DIR" ] \
|| 错误 "Gradle目录不存在"



日志 "Gradle安装完成"

}




############################################
# 安装 Android SDK
############################################


修复SDK目录()
{


if [ -d "$SDK_DIR/cmdline-tools/bin" ]
then


日志 "修复 cmdline-tools 目录"



mkdir -p \
"$SDK_DIR/cmdline-tools/latest"



mv \
"$SDK_DIR/cmdline-tools/bin" \
"$SDK_DIR/cmdline-tools/latest/"



fi


}




安装SDK()
{


日志 "安装 Android SDK"



rm -rf "$SDK_DIR"



下载 \
"$SDK_URL" \
"$HOME/android-sdk.tar.gz" \
"Android SDK"



tar xf \
"$HOME/android-sdk.tar.gz" \
-C "$HOME"



rm "$HOME/android-sdk.tar.gz"



修复SDK目录



日志 "Android SDK安装完成"

}





############################################
# NDK
############################################


安装NDK_r24()
{


if [ -d "$NDK_R24_DIR" ]
then

日志 "NDK r24 已存在"

return

fi



mkdir -p "$NDK_DIR"



下载 \
"$NDK_R24_URL" \
"$HOME/ndk-r24.zip" \
"NDK r24"



unzip -q \
"$HOME/ndk-r24.zip" \
-d "$NDK_DIR"



rm "$HOME/ndk-r24.zip"



SRC=$(find "$NDK_DIR" \
-maxdepth 1 \
-type d \
-name "android-ndk*" \
| head -1)



if [ -n "$SRC" ]
then

mv "$SRC" "$NDK_R24_DIR"

fi



日志 "NDK r24 安装完成"


}





安装NDK_r29()
{


if [ -d "$NDK_R29_DIR" ]
then

日志 "NDK r29 已存在"

return

fi



mkdir -p "$NDK_DIR"



下载 \
"$NDK_R29_URL" \
"$HOME/ndk-r29.tar.gz" \
"NDK r29"



tar xf \
"$HOME/ndk-r29.tar.gz" \
-C "$NDK_DIR"



rm "$HOME/ndk-r29.tar.gz"



SRC=$(find "$NDK_DIR" \
-maxdepth 1 \
-type d \
-name "android-ndk*" \
| head -1)



if [ -n "$SRC" ]
then

mv "$SRC" "$NDK_R29_DIR"

fi



日志 "NDK r29 安装完成"

}





选择NDK()
{


echo

echo "================================"
echo "选择 NDK 版本"
echo "================================"

echo "1) NDK r24"
echo "2) NDK r29"
echo "3) 两个都安装"
echo "4) 跳过"

echo


read -p "请输入 [1-4]: " CHOICE



case "$CHOICE" in


1)

安装NDK_r24

echo "export ANDROID_NDK_HOME=$NDK_R24_DIR" >> "$HOME/.bashrc"

;;


2)

安装NDK_r29

echo "export ANDROID_NDK_HOME=$NDK_R29_DIR" >> "$HOME/.bashrc"

;;


3)

安装NDK_r24

安装NDK_r29


echo "export ANDROID_NDK_HOME=$NDK_R29_DIR" >> "$HOME/.bashrc"

;;


4)

日志 "跳过NDK"

;;


*)

错误 "错误选择"

;;


esac


}



############################################
# 修复 Gradle
############################################


修复Gradle()
{


日志 "修复 Gradle 配置"



mkdir -p "$HOME/.gradle"



FILE="$HOME/.gradle/gradle.properties"



touch "$FILE"



AAPT=$(which aapt2 || true)



if [ -n "$AAPT" ]
then


grep -q \
"aapt2FromMavenOverride" \
"$FILE" \
|| echo \
"android.aapt2FromMavenOverride=$AAPT" >> "$FILE"



fi



日志 "Gradle配置完成"


}





############################################
# 环境变量
############################################


配置环境()
{


RC="$HOME/.bashrc"



sed -i \
'/Android Build Environment/,+8d' \
"$RC" 2>/dev/null || true




cat >> "$RC" <<EOF

# Android Build Environment

export JAVA_HOME=$JDK_DIR
export ANDROID_HOME=$SDK_DIR
export GRADLE_HOME=$GRADLE_DIR

export PATH=\$JAVA_HOME/bin:\$GRADLE_HOME/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/cmdline-tools/latest/bin:\$PATH

EOF



source "$RC" || true



日志 "环境变量配置完成"


}





############################################
# 验证
############################################


验证()
{


echo

echo "=============================="
echo "安装验证"
echo "=============================="


java -version


echo


gradle -v


echo


echo "ANDROID_HOME=$ANDROID_HOME"



if [ -n "${ANDROID_NDK_HOME:-}" ]
then

echo "ANDROID_NDK_HOME=$ANDROID_NDK_HOME"

fi


}





############################################
# 主程序
############################################


main()
{


检测架构


安装依赖


安装JDK


安装Gradle


安装SDK


选择NDK


修复Gradle


配置环境


验证



echo

echo "================================="
echo " Android环境安装完成"
echo " 请重新打开终端或执行 source ~/.bashrc"
echo "================================="


}



main