# 安裝指南

本指南將協助您完成 Gthulhu 和 Qumun 的安裝與設定。

## 系統需求

### 硬體需求

- **CPU**: x86_64 架構處理器
- **記憶體**: 至少 4GB RAM
- **儲存空間**: 至少 10GB 可用空間

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

## 針對不同發行版的安裝方式

請根據您的 Linux 發行版選擇以下詳細安裝說明。

### Ubuntu 25.04

為了節省各位的時間，我們直接跳過編譯 kernel 與安裝 kernel 的過程，使用[直接支援 sched_ext 的 Ubuntu 25.04](https://canonical.com/blog/canonical-releases-ubuntu-25-04-plucky-puffin)。

#### 安裝相依套件

```bash
sudo apt-get update
sudo apt-get install --yes bsdutils
sudo apt-get install --yes build-essential
sudo apt-get install --yes pkgconf
sudo apt-get install --yes llvm-17 clang-17 clang-format-17
sudo apt-get install --yes libbpf-dev libelf-dev libzstd-dev zlib1g-dev
sudo apt-get install --yes virtme-ng
sudo apt-get install --yes gcc-multilib
sudo apt-get install --yes systemtap-sdt-dev
sudo apt-get install --yes python3 python3-pip ninja-build
sudo apt-get install --yes libseccomp-dev protobuf-compiler
sudo apt-get install --yes meson cmake
sudo apt-get install --yes cargo
```

#### 設定 Clang

```bash
for tool in "clang" "clang-format" "llc" "llvm-strip"
do
  sudo rm -f /usr/bin/$tool
  sudo ln -s /usr/bin/$tool-17 /usr/bin/$tool
done
```

#### 安裝 Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### openSUSE Tumbleweed

openSUSE Tumbleweed 提供滾動更新，並支援 kernel 6.12+ 及 sched_ext。

#### 安裝相依套件

```bash
# 更新套件庫
sudo zypper refresh

# 安裝建置工具與編譯器
sudo zypper install -y gcc make cmake meson ninja pkg-config rust cargo

# 安裝 LLVM/Clang 18+（最低需求：17）
sudo zypper install -y llvm18 clang18 clang18-devel

# 安裝開發函式庫
sudo zypper install -y libbpf-devel libelf-devel libzstd-devel zlib-devel

# 安裝額外的建置相依套件
sudo zypper install -y systemtap-sdt-devel libseccomp-devel jq protobuf-devel

# 安裝靜態函式庫以進行靜態連結
sudo zypper install -y zlib-devel-static libzstd-devel-static
```

#### 設定 Clang

```bash
for tool in "clang" "clang-format" "llc" "llvm-strip"
do
  sudo rm -f /usr/bin/$tool
  sudo ln -s /usr/bin/$tool-18 /usr/bin/$tool
done
```

## 安裝 Go

在編譯 Gthulhu 之前，請先安裝 Golang（需求版本：1.22+）：

```bash
wget https://go.dev/dl/go1.24.2.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.24.2.linux-amd64.tar.gz
```
​
新增以下內容至 `~/.profile`：

```bash
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
```
​
新增後，記得使用 `source ~/.profile` 讓變更的內容生效。

## 編譯 Gthulhu

安裝完必要套件後，複製並編譯 Gthulhu：

```bash
git clone https://github.com/Gthulhu/Gthulhu.git
cd Gthulhu
make dep
git submodule init
git submodule sync
git submodule update
cd scx
meson setup build --prefix ~
meson compile -C build
cd ..
cd libbpfgo
make
cd ..
make
```
​
編譯完成後，Gthulhu 理應能順利執行在你的系統上：
​
![image](https://hackmd.io/_uploads/Sy0reSVige.png)
​
我們可以觀察 Gthulhu 的輸出得知目前已有多少任務是透過 Gthulhu 進行調度的。

## 常見問題排解

### 問題一：`undefined reference to eu_search_tree_init`
​
如果你遇到了類似的問題，是因為目前系統使用的是 elfutils 版的 libelf，你可以自行下載與編譯 libelf 來解決這個問題：
```sh
sudo apt remove --purge elfutils libelf-dev
cd ~
git clone https://github.com/arachsys/libelf.git
cd libelf
make
sudo make install
```
​
### 問題二：`ERROR: Program 'clang' not found or not executable`
​
如果你在執行 `meson setup build --prefix ~` 命令時遇到該問題，可以嘗試以下命令：
```sh
sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-17 100
sudo update-alternatives --install /usr/bin/llvm-strip llvm-strip /usr/bin/llvm-strip-17 100
```

## 下一步

安裝完成後，您可以：

- 📖 閱讀 [工作原理](how-it-works.md) 了解調度器運作機制
- 🎯 查看 [專案目標](project-goals.md) 了解設計理念
- 🔧 參考 [API 文檔](api-reference.md) 進行客製化開發

---

!!! success "安裝完成"
    恭喜！您已成功安裝 Gthulhu 調度器。如果遇到任何問題，請查看 [常見問題](faq.md) 或在 GitHub 提交 Issue。
