#!/bin/bash

set -euo pipefail


############################################
# Android Build Environment Installer
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




log()
{
    echo
    echo "[+] $*"
}



error()
{
    echo
    echo "[ERROR] $*"
    exit 1
}



check_arch()
{

    ARCH=$(uname -m)

    case "$ARCH" in

        aarch64|arm64)
            log "ARM64 detected"
            ;;

        x86_64)
            log "x86_64 detected"
            ;;

        *)
            error "Unsupported arch: $ARCH"
            ;;

    esac

}




install_dep()
{

    log "Checking dependencies"


    apt-get update -qq || true


    apt-get install -y \
        wget \
        curl \
        tar \
        unzip \
        xz-utils \
        aapt2 || true


}




download()
{

    URL="$1"
    OUT="$2"
    NAME="$3"


    log "Downloading $NAME"


    wget \
        --continue \
        --tries=5 \
        --timeout=30 \
        --show-progress \
        -O "$OUT" \
        "$URL" \
        || error "$NAME download failed"


}




install_jdk()
{

    rm -rf "$JDK_DIR"


    download \
        "$JDK_URL" \
        "$HOME/jdk.tar.gz" \
        "JDK"


    tar xf "$HOME/jdk.tar.gz" -C "$HOME"


    rm "$HOME/jdk.tar.gz"



}



install_gradle()
{

    rm -rf "$GRADLE_DIR"


    download \
        "$GRADLE_URL" \
        "$HOME/gradle.tar.gz" \
        "Gradle"


    tar xf "$HOME/gradle.tar.gz" -C "$HOME"


    rm "$HOME/gradle.tar.gz"

}



install_sdk()
{

    rm -rf "$SDK_DIR"


    download \
        "$SDK_URL" \
        "$HOME/android-sdk.tar.gz" \
        "Android SDK"


    tar xf "$HOME/android-sdk.tar.gz" -C "$HOME"


    rm "$HOME/android-sdk.tar.gz"



    fix_sdk_tools

}



fix_sdk_tools()
{

    if [ -d "$SDK_DIR/cmdline-tools/bin" ]
    then

        mkdir -p "$SDK_DIR/cmdline-tools/latest"

        mv \
        "$SDK_DIR/cmdline-tools/bin" \
        "$SDK_DIR/cmdline-tools/latest/"


    fi


}



install_ndk()
{

mkdir -p "$NDK_DIR"


echo

echo "Select NDK:"
echo "1) r24"
echo "2) r29"
echo "3) both"
echo "4) skip"


read -p "> " CHOICE



case "$CHOICE" in


1)

download \
"$NDK_R24_URL" \
"$HOME/ndk.zip" \
"NDK r24"


unzip -q "$HOME/ndk.zip" -d "$NDK_DIR"


;;


2)

download \
"$NDK_R29_URL" \
"$HOME/ndk.tar.gz" \
"NDK r29"


tar xf "$HOME/ndk.tar.gz" -C "$NDK_DIR"


;;



3)

echo "Install both"

;;


4)

return


;;


esac



}



setup_env()
{


RC="$HOME/.bashrc"



cat >> "$RC" <<EOF

# Android Build Environment

export JAVA_HOME=$JDK_DIR
export ANDROID_HOME=$SDK_DIR
export GRADLE_HOME=$GRADLE_DIR

export PATH=\$JAVA_HOME/bin:\$GRADLE_HOME/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/cmdline-tools/latest/bin:\$PATH

EOF



source "$RC" || true



}



main()
{


check_arch

install_dep

install_jdk

install_gradle

install_sdk

install_ndk

setup_env


echo

echo "================================="
echo " Android environment installed"
echo "================================="

java -version
gradle -v



}



main