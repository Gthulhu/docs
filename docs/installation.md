# 安裝指南

本指南將協助您完成 Gthulhu 和 SCX GoLand Core 的安裝與設定。

## 系統需求

### 硬體需求

- **CPU**: x86_64 架構處理器
- **記憶體**: 至少 2GB RAM
- **儲存空間**: 至少 1GB 可用空間

### 軟體需求

!!! warning "核心版本需求"
    **Linux 核心 6.12+ 且支援 sched_ext** 是必要條件。請確認您的核心版本符合需求。

#### 必要套件

| 套件 | 版本需求 | 用途 |
|------|----------|------|
| Go | 1.22+ | 使用者空間調度器開發 |
| LLVM/Clang | 17+ | BPF 程式編譯 |
| libbpf | 最新版本 | BPF 程式庫 |
| make | - | 建置工具 |
| git | - | 版本控制 |

#### 檢查核心支援

```bash
# 檢查核心版本
uname -r

# 檢查 sched_ext 支援
grep -r "CONFIG_SCHED_CLASS_EXT" /boot/config-$(uname -r) || \
cat /proc/config.gz | gunzip | grep "CONFIG_SCHED_CLASS_EXT"

# 檢查 BPF 支援
grep -r "CONFIG_BPF" /boot/config-$(uname -r) | head -5
```

## 安裝步驟

### 步驟 1: 安裝依賴套件

=== "Ubuntu/Debian"
    ```bash
    # 更新套件清單
    sudo apt update
    
    # 安裝編譯工具
    sudo apt install -y build-essential git make
    
    # 安裝 LLVM/Clang
    sudo apt install -y llvm-17 clang-17 libbpf-dev
    
    # 安裝 Go (如果尚未安裝)
    wget https://go.dev/dl/go1.22.6.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.22.6.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
    source ~/.zshrc
    ```

=== "CentOS/RHEL/Fedora"
    ```bash
    # Fedora
    sudo dnf install -y gcc make git
    sudo dnf install -y llvm clang libbpf-devel
    
    # CentOS/RHEL (需要 EPEL)
    sudo yum install -y epel-release
    sudo yum install -y gcc make git
    sudo yum install -y llvm clang libbpf-devel
    
    # 安裝 Go
    wget https://go.dev/dl/go1.22.6.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.22.6.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
    source ~/.zshrc
    ```

=== "Arch Linux"
    ```bash
    # 安裝基本工具
    sudo pacman -S base-devel git
    
    # 安裝 LLVM/Clang 和 libbpf
    sudo pacman -S llvm clang libbpf
    
    # 安裝 Go
    sudo pacman -S go
    ```

### 步驟 2: 克隆專案

```bash
# 克隆主要專案
git clone https://github.com/Gthulhu/Gthulhu.git
cd Gthulhu

# 或者，如果您要單獨使用 SCX GoLand Core
git clone https://github.com/Gthulhu/scx_goland_core.git
cd scx_goland_core
```

### 步驟 3: 設定相依套件

```bash
# 設定相依套件
make dep

# 初始化並更新 git submodules
git submodule init
git submodule sync
git submodule update

# 進入 scx 目錄並編譯
cd scx
meson setup build --prefix ~
meson compile -C build
cd ..
```

!!! tip "Submodule 說明"
    專案使用 git submodules 來管理 libbpf 和自訂的 libbpfgo fork。這些是專案正常運作的必要組件。

### 步驟 4: 建置專案

```bash
# 執行完整建置
make build
```

建置過程包含：

1. **編譯 BPF 程式** (`main.bpf.c` → `main.bpf.o`)
2. **建置 libbpf 函式庫**
3. **產生 BPF skeleton** (`main.skeleton.h`)
4. **編譯 Go 應用程式**

### 步驟 5: 驗證安裝

```bash
# 檢查編譯結果
ls -la main
file main

# 檢查 BPF 物件檔
ls -la main.bpf.o
file main.bpf.o

# 檢查 Go 模組
go version
go mod verify
```

## 測試安裝

### 虛擬環境測試

如果您想在虛擬環境中測試調度器：

```bash
# 使用 vng (Virtual Kernel Playground) 測試
make test
```

### 基本功能測試

```bash
# 在當前系統上測試（需要 root 權限）
sudo ./main &

# 檢查調度器是否正常運行
ps aux | grep main

# 檢查 BPF 程式是否載入
sudo bpftool prog list | grep sched

# 停止調度器
sudo pkill -f "./main"
```

## Docker 安裝

如果您偏好使用 Docker：

```bash
# 建置 Docker 映像檔
make image

# 執行調度器容器
docker run --privileged=true --pid host --rm gthulhu:latest /gthulhu/main
```

!!! warning "權限需求"
    由於調度器需要載入 BPF 程式並修改核心調度行為，因此需要 `--privileged=true` 和 `--pid host` 權限。

## 常見問題排解

### 編譯錯誤

??? question "libbpf 找不到"
    ```bash
    # 確認 libbpf 路徑
    find /usr -name "libbpf.so*" 2>/dev/null
    
    # 設定環境變數
    export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
    export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
    ```

??? question "Clang 版本不符"
    ```bash
    # 檢查 Clang 版本
    clang --version
    
    # 如果有多個版本，指定使用 clang-17
    export CC=clang-17
    export CXX=clang++-17
    ```

??? question "BPF 程式載入失敗"
    ```bash
    # 檢查核心 BPF 支援
    cat /proc/sys/kernel/unprivileged_bpf_disabled
    
    # 檢查 sched_ext 支援
    ls /sys/kernel/sched_ext/ 2>/dev/null || echo "sched_ext not supported"
    
    # 查看詳細錯誤訊息
    sudo dmesg | tail -20
    ```

### 執行時問題

??? question "權限不足"
    調度器需要 root 權限才能載入 BPF 程式：
    ```bash
    sudo ./main
    ```

??? question "核心不支援 sched_ext"
    請確保您的核心版本為 6.12+ 且編譯時啟用了 `CONFIG_SCHED_CLASS_EXT`。

## 下一步

安裝完成後，您可以：

- 📖 閱讀 [工作原理](how-it-works.md) 了解調度器運作機制
- 🎯 查看 [專案目標](project-goals.md) 了解設計理念
- 🔧 參考 [API 文檔](api-reference.md) 進行客製化開發

---

!!! success "安裝完成"
    恭喜！您已成功安裝 Gthulhu 調度器。如果遇到任何問題，請查看 [常見問題](faq.md) 或在 GitHub 提交 Issue。
