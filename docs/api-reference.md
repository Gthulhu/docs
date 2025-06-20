# API 參考

本頁面提供 Gthulhu 和 SCX GoLand Core 的完整 API 參考文檔。

## SCX GoLand Core API

### 核心模組

#### `core.LoadSched()`

載入 BPF 調度器程式。

```go
func LoadSched(bpfObjectFile string) *BPFModule
```

**參數**:
- `bpfObjectFile`: BPF 物件檔案路徑 (如: `main.bpf.o`)

**回傳值**:
- `*BPFModule`: BPF 模組實例

**範例**:
```go
bpfModule := core.LoadSched("main.bpf.o")
defer bpfModule.Close()
```

#### `BPFModule.AssignUserSchedPid()`

設定使用者空間調度器的 PID。

```go
func (bm *BPFModule) AssignUserSchedPid(pid int) error
```

**參數**:
- `pid`: 使用者空間調度器的程序 ID

**範例**:
```go
pid := os.Getpid()
err := bpfModule.AssignUserSchedPid(pid)
if err != nil {
    log.Printf("AssignUserSchedPid failed: %v", err)
}
```

#### `BPFModule.Attach()`

附加 BPF 程式到核心。

```go
func (bm *BPFModule) Attach() error
```

**範例**:
```go
if err := bpfModule.Attach(); err != nil {
    log.Panicf("bpfModule attach failed: %v", err)
}
```

#### `BPFModule.ReceiveProcExitEvt()`

接收程序退出事件。

```go
func (bm *BPFModule) ReceiveProcExitEvt() int
```

**回傳值**:
- `int`: 退出程序的 PID，如果沒有事件則回傳 -1

**範例**:
```go
go func() {
    for {
        if pid := bpfModule.ReceiveProcExitEvt(); pid != -1 {
            sched.DeletePidFromTaskInfo(pid)
        } else {
            time.Sleep(100 * time.Millisecond)
        }
    }
}()
```

### 快取模組 (`util` 套件)

#### `cache.InitCacheDomains()`

初始化 CPU 快取域。

```go
func InitCacheDomains(bpfModule *core.BPFModule) error
```

**參數**:
- `bpfModule`: BPF 模組實例

**範例**:
```go
err := cache.InitCacheDomains(bpfModule)
if err != nil {
    log.Panicf("InitCacheDomains failed: %v", err)
}
```

### 調度模組 (`sched` 套件)

#### `sched.DeletePidFromTaskInfo()`

從任務資訊中刪除指定 PID。

```go
func DeletePidFromTaskInfo(pid int)
```

**參數**:
- `pid`: 要刪除的程序 ID

## BPF 程式 API

### Map 結構

#### `task_info_map`

儲存任務資訊的 Hash Map。

```c
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, MAX_TASKS);
    __type(key, pid_t);
    __type(value, struct task_info);
} task_info_map SEC(".maps");
```

#### `struct task_info`

任務資訊結構體。

```c
struct task_info {
    __u64 vruntime;                    // 虛擬執行時間
    __u32 weight;                      // 任務權重
    __u32 slice_ns;                    // 時間片 (奈秒)
    __u64 exec_start;                  // 執行開始時間
    __u64 sum_exec_runtime;            // 累計執行時間
    __u32 voluntary_ctxt_switches;     // 自願上下文切換次數
    __u32 nonvoluntary_ctxt_switches;  // 非自願上下文切換次數
};
```

### BPF 程式進入點

#### `sched_ext_ops`

調度器操作結構體。

```c
SEC(".struct_ops.link")
struct sched_ext_ops gthulhu_ops = {
    .select_cpu         = (void *)gthulhu_select_cpu,
    .enqueue            = (void *)gthulhu_enqueue,
    .dispatch           = (void *)gthulhu_dispatch,
    .running            = (void *)gthulhu_running,
    .stopping           = (void *)gthulhu_stopping,
    .enable             = (void *)gthulhu_enable,
    .init               = (void *)gthulhu_init,
    .exit               = (void *)gthulhu_exit,
    .name               = "gthulhu",
};
```

### 核心函數

#### `gthulhu_select_cpu()`

選擇適合的 CPU 核心。

```c
s32 BPF_STRUCT_OPS(gthulhu_select_cpu, struct task_struct *p, 
                   s32 prev_cpu, u64 wake_flags)
```

**參數**:
- `p`: 任務結構體指標
- `prev_cpu`: 前一個 CPU 編號
- `wake_flags`: 喚醒標誌

**回傳值**:
- `s32`: 選中的 CPU 編號

#### `gthulhu_enqueue()`

將任務加入佇列。

```c
void BPF_STRUCT_OPS(gthulhu_enqueue, struct task_struct *p, u64 enq_flags)
```

#### `gthulhu_dispatch()`

調度任務執行。

```c
void BPF_STRUCT_OPS(gthulhu_dispatch, s32 cpu, struct task_struct *prev)
```

## 配置選項

### 環境變數

| 變數名 | 說明 | 預設值 | 類型 |
|--------|------|--------|------|
| `GTHULHU_DEBUG` | 啟用調試模式 | `false` | bool |
| `GTHULHU_LOG_LEVEL` | 日誌等級 | `INFO` | string |
| `GTHULHU_MAX_TASKS` | 最大任務數 | `4096` | int |

### 執行時參數

#### 時間片設定

```c
// 基礎時間片 (奈秒)
#define BASE_SLICE_NS    5000000ULL  // 5ms

// 最小時間片
#define MIN_SLICE_NS     1000000ULL  // 1ms

// 最大時間片
#define MAX_SLICE_NS    20000000ULL  // 20ms
```

#### 權重設定

```c
// Nice 值對應的權重表
static const int prio_to_weight[40] = {
 /* -20 */     88761,     71755,     56483,     46273,     36291,
 /* -15 */     29154,     23254,     18705,     14949,     11916,
 /* -10 */      9548,      7620,      6100,      4904,      3906,
 /*  -5 */      3121,      2501,      1991,      1586,      1277,
 /*   0 */      1024,       820,       655,       526,       423,
 /*   5 */       335,       272,       215,       172,       137,
 /*  10 */       110,        87,        70,        56,        45,
 /*  15 */        36,        29,        23,        18,        15,
};
```

## 錯誤處理

### 常見錯誤碼

| 錯誤碼 | 說明 | 解決方案 |
|--------|------|----------|
| `-EPERM` | 權限不足 | 使用 root 權限執行 |
| `-ENOENT` | BPF 檔案不存在 | 確認 BPF 物件檔案路徑 |
| `-EINVAL` | 無效參數 | 檢查函數參數 |
| `-ENOMEM` | 記憶體不足 | 增加系統記憶體 |

### 錯誤處理範例

```go
// 錯誤處理模式
if err := bpfModule.Attach(); err != nil {
    switch {
    case strings.Contains(err.Error(), "permission denied"):
        log.Fatal("需要 root 權限")
    case strings.Contains(err.Error(), "no such file"):
        log.Fatal("BPF 檔案不存在")
    default:
        log.Fatalf("未知錯誤: %v", err)
    }
}
```

## 調試 API

### 統計資訊

```go
// 獲取調度器統計資訊
type SchedulerStats struct {
    TotalTasks          uint64
    ActiveTasks         uint64
    ContextSwitches     uint64
    AverageLatency      time.Duration
    CPUUtilization      float64
}

func GetSchedulerStats() *SchedulerStats {
    // 實作細節...
}
```

### 調試工具函數

```c
// BPF 調試巨集
#define bpf_debug(fmt, args...) \
    bpf_trace_printk(fmt, sizeof(fmt), ##args)

// 追蹤任務狀態變化
static void trace_task_state(struct task_struct *p, const char *event) {
    bpf_debug("Task %d: %s (vruntime=%llu)\n", 
              p->pid, event, get_task_vruntime(p));
}
```

## 效能調優 API

### 動態參數調整

```go
// 調整調度參數
type SchedulingParams struct {
    BaseSliceNs      uint64
    MinSliceNs       uint64  
    MaxSliceNs       uint64
    LatencyFactor    float64
    WeightMultiplier float64
}

func UpdateSchedulingParams(params *SchedulingParams) error {
    // 實作細節...
}
```

### 效能監控

```c
// 效能計數器
struct perf_counters {
    __u64 dispatch_count;
    __u64 enqueue_count;
    __u64 context_switch_count;
    __u64 total_runtime;
    __u64 idle_time;
};
```

---

!!! note "API 版本"
    當前 API 版本: v0.1.x  
    API 穩定性: Alpha (可能會有破壞性變更)

!!! tip "更多範例"
    更多使用範例請參考專案原始碼中的 `examples/` 目錄。
