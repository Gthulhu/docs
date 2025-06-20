#!/bin/bash

# MkDocs 部署腳本
# 此腳本用於建置和部署 Gthulhu 官方文檔

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函數定義
print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_help() {
    echo "Gthulhu 文檔部署腳本"
    echo ""
    echo "使用方法:"
    echo "  $0 [選項]"
    echo ""
    echo "選項:"
    echo "  --build, -b      僅建置文檔"
    echo "  --serve, -s      建置並啟動本地伺服器"
    echo "  --deploy, -d     建置並部署到 GitHub Pages"
    echo "  --clean, -c      清理建置檔案"
    echo "  --check, -k      檢查文檔品質"
    echo "  --help, -h       顯示此幫助訊息"
    echo ""
    echo "範例:"
    echo "  $0 --build       # 僅建置文檔"
    echo "  $0 --serve       # 建置並啟動本地伺服器"
    echo "  $0 --deploy      # 部署到 GitHub Pages"
}

check_dependencies() {
    print_status "檢查相依套件..."
    
    # 檢查 Python 和 pip
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 未安裝"
        exit 1
    fi

    if ! command -v pip &> /dev/null; then
        print_error "pip 未安裝"
        exit 1
    fi
    
    print_success "Python 和 pip 已安裝"
}

install_dependencies() {
    print_status "安裝 MkDocs 依賴..."
    
    # 創建 requirements.txt 如果不存在
    if [ ! -f "requirements.txt" ]; then
        cat > requirements.txt << EOF
mkdocs>=1.5.0
mkdocs-material>=9.0.0
mkdocs-mermaid2-plugin>=1.1.0
pillow>=9.0.0
cairosvg>=2.5.0
EOF
    fi
    
    pip install -q -r requirements.txt
    print_success "相依套件安裝完成"
}

build_docs() {
    print_status "建置文檔..."
    
    # 驗證配置
    if ! mkdocs config &> /dev/null; then
        print_error "MkDocs 配置檔案無效"
        exit 1
    fi
    
    # 建置文檔
    mkdocs build --clean --strict
    
    # 檢查建置結果
    if [ -d "site" ]; then
        local size=$(du -sh site/ | cut -f1)
        local html_count=$(find site/ -name "*.html" | wc -l)
        print_success "文檔建置成功！"
        print_status "建置統計:"
        echo "  📁 靜態檔案位於: $(pwd)/site/"
        echo "  📊 網站大小: $size"
        echo "  📄 HTML 檔案數量: $html_count"
    else
        print_error "文檔建置失敗"
        exit 1
    fi
}

serve_docs() {
    print_status "啟動本地預覽伺服器..."
    print_success "伺服器已啟動，請訪問 http://127.0.0.1:8000"
    print_warning "按 Ctrl+C 停止伺服器"
    mkdocs serve
}

deploy_docs() {
    print_status "部署到 GitHub Pages..."
    
    # 檢查是否為 git 儲存庫
    if [ ! -d ".git" ]; then
        print_error "當前目錄不是 Git 儲存庫"
        exit 1
    fi
    
    # 檢查是否有 GitHub remote
    if ! git remote get-url origin &> /dev/null; then
        print_error "未設定 GitHub remote origin"
        exit 1
    fi
    
    mkdocs gh-deploy --clean
    print_success "部署完成！"
    
    # 獲取 GitHub Pages URL
    local repo_url=$(git remote get-url origin)
    local repo_name=$(basename "$repo_url" .git)
    local username=$(dirname "$repo_url" | xargs basename)
    print_status "您的文檔將在幾分鐘後可在以下網址訪問:"
    echo "  🌐 https://$username.github.io/$repo_name"
}

clean_docs() {
    print_status "清理建置檔案..."
    
    if [ -d "site" ]; then
        rm -rf site/
        print_success "site/ 目錄已刪除"
    fi
    
    if [ -f "requirements.txt" ]; then
        rm -f requirements.txt
        print_success "requirements.txt 已刪除"
    fi
    
    print_success "清理完成"
}

check_docs() {
    print_status "檢查文檔品質..."
    
    # 檢查 Markdown 檔案
    local zh_files=$(find docs/ -name "*.md" ! -name "*.en.md" | wc -l)
    local en_files=$(find docs/ -name "*.en.md" | wc -l)
    
    print_status "文檔統計:"
    echo "  📄 中文檔案: $zh_files"
    echo "  📄 英文檔案: $en_files"
    
    # 檢查是否有遺失的英文版本
    local missing_en=0
    for file in docs/*.md; do
        if [[ "$file" != *".en.md" ]]; then
            base=$(basename "$file" .md)
            if [[ ! -f "docs/$base.en.md" ]]; then
                print_warning "遺失英文版本: $file"
                ((missing_en++))
            fi
        fi
    done
    
    if [ $missing_en -eq 0 ]; then
        print_success "所有檔案都有對應的英文版本"
    else
        print_warning "有 $missing_en 個檔案遺失英文版本"
    fi
    
    # 驗證建置
    mkdocs build --clean --strict
    print_success "文檔結構驗證通過"
}

show_help() {
    cat << EOF
🚀 Gthulhu 文檔部署腳本

用法: $0 [選項]

選項:
  build     建置文檔 (預設)
  serve     建置並啟動本地預覽伺服器
  deploy    建置並部署到 GitHub Pages
  clean     清理建置檔案
  check     檢查文檔品質和完整性
  install   安裝必要相依套件
  help      顯示此說明訊息

範例:
  $0 build     # 僅建置文檔
  $0 serve     # 建置並啟動預覽伺服器
  $0 deploy    # 建置並部署到 GitHub Pages
  $0 clean     # 清理所有建置檔案
  $0 check     # 檢查文檔品質
  
GitHub Actions:
  此專案已設定 GitHub Actions 自動部署
  推送至 main/master 分支時會自動觸發部署

EOF
}

# 主程式邏輯
main() {
    print_status "🚀 Gthulhu 文檔部署腳本"
    
    # 確保在正確的目錄
    cd "$(dirname "$0")"
    
    # 檢查 mkdocs.yml 是否存在
    if [ ! -f "mkdocs.yml" ]; then
        print_error "找不到 mkdocs.yml 檔案，請確認在正確的目錄下執行此腳本"
        exit 1
    fi
    
    # 解析命令列參數
    case "${1:-build}" in
        "build")
            check_dependencies
            install_dependencies
            build_docs
            ;;
        "serve")
            check_dependencies
            install_dependencies
            build_docs
            serve_docs
            ;;
        "deploy")
            check_dependencies
            install_dependencies
            build_docs
            deploy_docs
            ;;
        "clean")
            clean_docs
            ;;
        "check")
            check_dependencies
            install_dependencies
            check_docs
            ;;
        "install")
            check_dependencies
            install_dependencies
            ;;
        "help"|"-h"|"--help")
            show_help
            exit 0
            ;;
        *)
            print_error "未知的選項: $1"
            show_help
            exit 1
            ;;
    esac
    
    print_success "🎉 操作完成！"
}

# 執行主程式
main "$@"
