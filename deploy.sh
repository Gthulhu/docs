#!/bin/bash

# MkDocs 部署腳本
# 此腳本用於建置和部署 Gthulhu 官方文檔

set -e

echo "🚀 開始建置 Gthulhu 文檔..."

# 確保在正確的目錄
cd "$(dirname "$0")"

# 檢查 Python 和 pip
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 未安裝"
    exit 1
fi

if ! command -v pip &> /dev/null; then
    echo "❌ pip 未安裝"
    exit 1
fi

# 安裝依賴
echo "📦 安裝 MkDocs 依賴..."
pip install -q mkdocs mkdocs-material mkdocs-mermaid2-plugin

# 建置文檔
echo "🔨 建置文檔..."
mkdocs build --clean

# 檢查建置結果
if [ -d "site" ]; then
    echo "✅ 文檔建置成功！"
    echo "📁 靜態檔案位於: $(pwd)/site/"
    echo "🌐 本地預覽: mkdocs serve"
    echo "📤 GitHub Pages 部署: mkdocs gh-deploy"
else
    echo "❌ 文檔建置失敗"
    exit 1
fi

# 如果有 --serve 參數，啟動本地伺服器
if [ "$1" = "--serve" ]; then
    echo "🌐 啟動本地預覽伺服器..."
    mkdocs serve
fi

# 如果有 --deploy 參數，部署到 GitHub Pages
if [ "$1" = "--deploy" ]; then
    echo "🚀 部署到 GitHub Pages..."
    mkdocs gh-deploy
fi

echo "🎉 完成！"
