# 常見問題

本頁面收集了 Gthulhu 和 SCX GoLand Core 使用過程中的常見問題與解答。

## 安裝相關問題

### Q: 如何確認我的核心支援 sched_ext？

A: 您可以通過以下方式檢查：

```bash
# 方法 1: 檢查核心配置
grep -r "CONFIG_SCHED_CLASS_EXT" /boot/config-$(uname -r)

# 方法 2: 檢查 /proc/config.gz
zcat /proc/config.gz | grep "CONFIG_SCHED_CLASS_EXT"

# 方法 3: 檢查 sched_ext 目錄
ls /sys/kernel/sched_ext/ 2>/dev/null
```

如果輸出包含 `CONFIG_SCHED_CLASS_EXT=y`，表示您的核心支援 sched_ext。

### Q: 編譯時出現 "libbpf not found" 錯誤該怎麼辦？

A: 這通常是因為 libbpf 沒有正確安裝。請按照以下步驟解決：

```bash
# Ubuntu/Debian
sudo apt install libbpf-dev

# CentOS/RHEL/Fedora
sudo dnf install libbpf-devel

# 或者手動編譯 libbpf
git clone https://github.com/libbpf/libbpf.git
cd libbpf/src
make
sudo make install
```

### Q: 為什麼需要 Clang 17+？

A: Clang 17+ 提供了更完整的 BPF 支援，包括：

- 更好的 BPF CO-RE (Compile Once, Run Everywhere) 支援
- 最新的 BPF 指令集支援
- 更穩定的 BPF 程式編譯

如果您的系統沒有 Clang 17+，可以這樣安裝：

```bash
# Ubuntu/Debian
sudo apt install clang-17

# 設定環境變數
export CC=clang-17
export CXX=clang++-17
```

## 執行相關問題

### Q: 執行時提示 "Operation not permitted" 錯誤

A: 這是權限問題，BPF 程式載入需要 root 權限：

```bash
# 正確的執行方式
sudo ./main

# 或者使用 Docker
docker run --privileged=true --pid host --rm gthulhu:latest /gthulhu/main
```

### Q: 調度器啟動後系統變慢了怎麼辦？

A: 這可能是由於以下原因：

1. **調度參數不適合您的工作負載**：
```bash
# 檢查系統負載
top
htop

# 檢查上下文切換頻率
vmstat 1
```

2. **記憶體不足**：
```bash
# 檢查記憶體使用
free -h
cat /proc/meminfo
```

3. **BPF 程式性能問題**：
```bash
# 檢查 BPF 程式統計
sudo bpftool prog show
sudo bpftool prog profile
```

**解決方案**：
- 暫停調度器：`sudo pkill -f "./main"`  
- 檢查系統日誌：`dmesg | tail -50`
- 調整調度參數或回報問題

### Q: 如何停止調度器？

A: 您可以使用以下方式停止調度器：

```bash
# 方法 1: Ctrl+C (如果在前景執行)
^C

# 方法 2: 發送 SIGTERM 信號
sudo pkill -TERM -f "./main"

# 方法 3: 發送 SIGINT 信號
sudo pkill -INT -f "./main"

# 方法 4: 強制終止 (不推薦)
sudo pkill -KILL -f "./main"
```

## 性能相關問題

### Q: 如何監控調度器性能？

A: 您可以使用多種工具監控調度器性能：

1. **系統工具**：
```bash
# 監控 CPU 使用率
htop

# 監控上下文切換
vmstat 1

# 監控調度延遲
perf sched record -- sleep 10
perf sched latency
```

2. **BPF 工具**：
```bash
# 檢查 BPF 程式狀態
sudo bpftool prog list | grep sched

# 檢查 BPF map 內容
sudo bpftool map dump name task_info_map
```

3. **調度器內建監控**：
```bash
# 查看調度器日誌
journalctl -f -u gthulhu

# 查看 BPF 追蹤訊息
sudo cat /sys/kernel/debug/tracing/trace_pipe
```

### Q: 調度器相比 CFS 有什麼優勢？

A: Gthulhu 調度器的主要優勢：

| 特性 | CFS | Gthulhu |
|------|-----|---------|
| 延遲最佳化 | 基本 | 專業化 |
| 任務分類 | 統一處理 | 自動分類 |
| CPU 拓撲感知 | 有限 | 完整支援 |
| 動態調整 | 靜態參數 | 即時調整 |
| 使用者空間擴展 | 不支援 | 完全支援 |

### Q: 如何調整調度器參數？

A: 目前支援的調整方式：

1. **環境變數**：
```bash
export GTHULHU_DEBUG=true
export GTHULHU_LOG_LEVEL=DEBUG
sudo -E ./main
```

2. **編譯時參數** (修改 `main.bpf.c`)：
```c
// 調整基礎時間片
#define BASE_SLICE_NS    3000000ULL  // 3ms 而不是 5ms
```

3. **執行時 API** (計劃中)：
```go
// 未來將支援動態調整
params := &SchedulingParams{
    BaseSliceNs: 3000000,
    LatencyFactor: 1.5,
}
UpdateSchedulingParams(params)
```

## 除錯相關問題

### Q: 如何開啟調試模式？

A: 您可以通過以下方式開啟調試：

1. **環境變數**：
```bash
export GTHULHU_DEBUG=true
export GTHULHU_LOG_LEVEL=DEBUG
sudo -E ./main
```

2. **BPF 追蹤**：
```bash
# 終端 1: 啟動調度器
sudo ./main

# 終端 2: 查看 BPF 追蹤
sudo cat /sys/kernel/debug/tracing/trace_pipe
```

3. **系統日誌**：
```bash
# 查看核心日誌
dmesg -w

# 查看 systemd 日誌
journalctl -f
```

### Q: 遇到 BPF 驗證器錯誤怎麼辦？

A: BPF 驗證器錯誤通常表示程式有問題：

1. **檢查錯誤訊息**：
```bash
# 查看詳細錯誤
dmesg | grep -i bpf
```

2. **常見問題**：
   - **無界迴圈**：確保所有迴圈都有明確的退出條件
   - **記憶體越界**：檢查陣列存取是否在範圍內
   - **指標使用**：確保指標在使用前經過 NULL 檢查

3. **驗證 BPF 程式**：
```bash
# 使用 bpftool 驗證
sudo bpftool prog load main.bpf.o /sys/fs/bpf/test_prog
```

### Q: 如何回報問題？

A: 如果遇到問題，請按照以下步驟：

1. **收集系統資訊**：
```bash
# 系統資訊
uname -a
cat /etc/os-release

# 核心版本和配置
uname -r
grep CONFIG_SCHED_CLASS_EXT /boot/config-$(uname -r)

# Go 版本
go version

# Clang 版本
clang --version
```

2. **收集錯誤日誌**：
```bash
# 調度器日誌
sudo ./main 2>&1 | tee gthulhu.log

# 系統日誌
dmesg > dmesg.log
journalctl --since "1 hour ago" > journal.log
```

3. **在 GitHub 提交 Issue**：
   - 前往 [Gthulhu Issues](https://github.com/Gthulhu/Gthulhu/issues)
   - 選擇適合的 Issue 模板
   - 附上系統資訊和錯誤日誌
   - 描述重現步驟

## 開發相關問題

### Q: 如何參與開發？

A: 歡迎參與開發！請參考：

1. **查看貢獻指南**：[contributing.md](contributing.md)
2. **了解程式碼結構**：
```
Gthulhu/
├── main.go              # 主程式
├── main.bpf.c          # BPF 程式
├── internal/sched/     # 調度邏輯
└── api/               # API 服務
```

3. **設定開發環境**：
```bash
git clone https://github.com/Gthulhu/Gthulhu.git
cd Gthulhu
make dep
make build
make test
```

### Q: 如何新增自訂的調度策略？

A: 您可以通過以下方式客製化：

1. **修改 BPF 程式** (`main.bpf.c`)：
```c
// 新增自訂的 CPU 選擇邏輯
s32 custom_select_cpu(struct task_struct *p, s32 prev_cpu, u64 wake_flags) {
    // 您的邏輯
    return selected_cpu;
}
```

2. **修改 Go 程式** (`main.go`)：
```go
// 新增自訂的任務處理邏輯
func handleCustomTask(taskInfo *TaskInfo) {
    // 您的邏輯
}
```

3. **使用 SCX GoLand Core API**：
```go
// 實作 CustomScheduler 介面
type MyScheduler struct{}

func (s *MyScheduler) ScheduleTask(task *Task) *ScheduleDecision {
    // 您的調度邏輯
    return decision
}
```

## 兼容性問題

### Q: 支援哪些 Linux 發行版？

A: 理論上支援所有具備以下條件的發行版：

- **核心版本**: 6.12+
- **sched_ext 支援**: 已啟用
- **架構**: x86_64

**已測試的發行版**：
- Ubuntu 24.04+
- Fedora 39+
- Arch Linux (最新)

**計劃支援**：
- CentOS/RHEL 9+
- openSUSE Tumbleweed
- Debian 13+

### Q: 能在容器中執行嗎？

A: 可以，但需要特殊權限：

```bash
# Docker 執行
docker run --privileged=true --pid host --rm gthulhu:latest

# Podman 執行
podman run --privileged --pid host --rm gthulhu:latest

# Kubernetes 執行 (需要特殊配置)
# 請參考 examples/kubernetes/ 目錄
```

### Q: 與其他調度器衝突嗎？

A: Gthulhu 會替換系統預設調度器，因此：

- **不能**與其他 sched_ext 調度器同時執行
- **不會**影響即時調度類別 (SCHED_FIFO, SCHED_RR)
- **會**替換 CFS 調度器的功能

---

!!! question "問題沒有解決？"
    如果您的問題沒有在這裡找到答案，請：
    
    1. 查看 [GitHub Issues](https://github.com/Gthulhu/Gthulhu/issues)
    2. 搜尋現有的問題和解答
    3. 如果沒有找到，請建立新的 Issue
