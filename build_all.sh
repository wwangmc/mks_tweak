#!/bin/bash

# 定义模式常量
ROOTFULL=0
ROOTLESS=1
ROOTHIDE=2

# 遍历所有模式并打包
for TYPE in $ROOTFULL $ROOTLESS $ROOTHIDE; do
    case $TYPE in
        $ROOTFULL)  MODE="rootfull" ;;
        $ROOTLESS)  MODE="rootless" ;;
        $ROOTHIDE)  MODE="roothide" ;;
    esac

    echo "🚀 Building $MODE (TYPE=$TYPE)..."
    make TYPE=$TYPE clean package >/dev/null 2>&1  # 关键变更：直接 clean + package

    if [ $? -eq 0 ]; then
        echo "✅  Successfully built $MODE!"
    else
        echo "❌  Failed to build $MODE!"
    fi
done

# 列出所有生成的 .deb 文件
echo -e "\n📦 Generated .deb files:"
find ./packages -name "*.deb" -ls