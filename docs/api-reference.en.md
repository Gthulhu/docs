# API Reference

This page provides complete API reference documentation for Gthulhu and SCX GoLand Core.

## SCX GoLand Core API

### Core Module

#### `core.LoadSched()`

Load BPF scheduler program.

```go
func LoadSched(bpfObjectFile string) *BPFModule
```

**Parameters**:
- `bpfObjectFile`: Path to BPF object file (e.g., `main.bpf.o`)

**Returns**:
- `*BPFModule`: BPF module instance

**Example**:
```go
bpfModule := core.LoadSched("main.bpf.o")
defer bpfModule.Close()
```

#### `BPFModule.AssignUserSchedPid()`

Set the PID of the user-space scheduler.

```go
func (bm *BPFModule) AssignUserSchedPid(pid int) error
```

**Parameters**:
- `pid`: Process ID of the user-space scheduler

**Example**:
```go
pid := os.Getpid()
err := bpfModule.AssignUserSchedPid(pid)
if err != nil {
    log.Printf("AssignUserSchedPid failed: %v", err)
}
```

#### `BPFModule.Attach()`

Attach BPF program to kernel.

```go
func (bm *BPFModule) Attach() error
```

**Example**:
```go
if err := bpfModule.Attach(); err != nil {
    log.Panicf("bpfModule attach failed: %v", err)
}
```

#### `BPFModule.ReceiveProcExitEvt()`

Receive process exit events.

```go
func (bm *BPFModule) ReceiveProcExitEvt() int
```

**Returns**:
- `int`: PID of exited process, or -1 if no events

**Example**:
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

### Cache Module (`util` package)

#### `cache.InitCacheDomains()`

Initialize CPU cache domains.

```go
func InitCacheDomains(bpfModule *core.BPFModule) error
```

**Parameters**:
- `bpfModule`: BPF module instance

**Example**:
```go
err := cache.InitCacheDomains(bpfModule)
if err != nil {
    log.Panicf("InitCacheDomains failed: %v", err)
}
```

### Scheduler Module (`sched` package)

#### `sched.DeletePidFromTaskInfo()`

Delete specified PID from task information.

```go
func DeletePidFromTaskInfo(pid int)
```

**Parameters**:
- `pid`: Process ID to delete

## BPF Program API

### Map Structures

#### `task_info_map`

Hash map storing task information.

```c
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, MAX_TASKS);
    __type(key, pid_t);
    __type(value, struct task_info);
} task_info_map SEC(".maps");
```

#### `struct task_info`

Task information structure.

```c
struct task_info {
    __u64 vruntime;                    // Virtual runtime
    __u32 weight;                      // Task weight
    __u32 slice_ns;                    // Time slice (nanoseconds)
    __u64 exec_start;                  // Execution start time
    __u64 sum_exec_runtime;            // Cumulative execution time
    __u32 voluntary_ctxt_switches;     // Voluntary context switches
    __u32 nonvoluntary_ctxt_switches;  // Non-voluntary context switches
};
```

### BPF Program Entry Points

#### `sched_ext_ops`

Scheduler operations structure.

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

### Core Functions

#### `gthulhu_select_cpu()`

Select appropriate CPU core.

```c
s32 BPF_STRUCT_OPS(gthulhu_select_cpu, struct task_struct *p, 
                   s32 prev_cpu, u64 wake_flags)
```

**Parameters**:
- `p`: Task structure pointer
- `prev_cpu`: Previous CPU number
- `wake_flags`: Wake-up flags

**Returns**:
- `s32`: Selected CPU number

#### `gthulhu_enqueue()`

Enqueue task.

```c
void BPF_STRUCT_OPS(gthulhu_enqueue, struct task_struct *p, u64 enq_flags)
```

#### `gthulhu_dispatch()`

Dispatch task for execution.

```c
void BPF_STRUCT_OPS(gthulhu_dispatch, s32 cpu, struct task_struct *prev)
```

## Configuration Options

### Environment Variables

| Variable | Description | Default | Type |
|----------|-------------|---------|------|
| `GTHULHU_DEBUG` | Enable debug mode | `false` | bool |
| `GTHULHU_LOG_LEVEL` | Log level | `INFO` | string |
| `GTHULHU_MAX_TASKS` | Maximum number of tasks | `4096` | int |

### Runtime Parameters

#### Time Slice Configuration

```c
// Base time slice (nanoseconds)
#define BASE_SLICE_NS    5000000ULL  // 5ms

// Minimum time slice
#define MIN_SLICE_NS     1000000ULL  // 1ms

// Maximum time slice
#define MAX_SLICE_NS    20000000ULL  // 20ms
```

#### Weight Configuration

```c
// Weight table corresponding to nice values
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

## Error Handling

### Common Error Codes

| Error Code | Description | Solution |
|------------|-------------|----------|
| `-EPERM` | Permission denied | Run with root privileges |
| `-ENOENT` | BPF file not found | Verify BPF object file path |
| `-EINVAL` | Invalid parameters | Check function parameters |
| `-ENOMEM` | Out of memory | Increase system memory |

### Error Handling Example

```go
// Error handling pattern
if err := bpfModule.Attach(); err != nil {
    switch {
    case strings.Contains(err.Error(), "permission denied"):
        log.Fatal("Root privileges required")
    case strings.Contains(err.Error(), "no such file"):
        log.Fatal("BPF file does not exist")
    default:
        log.Fatalf("Unknown error: %v", err)
    }
}
```

## Debugging API

### Statistics Information

```go
// Get scheduler statistics
type SchedulerStats struct {
    TotalTasks          uint64
    ActiveTasks         uint64
    ContextSwitches     uint64
    AverageLatency      time.Duration
    CPUUtilization      float64
}

func GetSchedulerStats() *SchedulerStats {
    // Implementation details...
}
```

### Debug Tool Functions

```c
// BPF debug macros
#define bpf_debug(fmt, args...) \
    bpf_trace_printk(fmt, sizeof(fmt), ##args)

// Trace task state changes
static void trace_task_state(struct task_struct *p, const char *event) {
    bpf_debug("Task %d: %s (vruntime=%llu)\n", 
              p->pid, event, get_task_vruntime(p));
}
```

## Performance Tuning API

### Dynamic Parameter Adjustment

```go
// Adjust scheduling parameters
type SchedulingParams struct {
    BaseSliceNs      uint64
    MinSliceNs       uint64  
    MaxSliceNs       uint64
    LatencyFactor    float64
    WeightMultiplier float64
}

func UpdateSchedulingParams(params *SchedulingParams) error {
    // Implementation details...
}
```

### Performance Monitoring

```c
// Performance counters
struct perf_counters {
    __u64 dispatch_count;
    __u64 enqueue_count;
    __u64 context_switch_count;
    __u64 total_runtime;
    __u64 idle_time;
};
```

---

!!! note "API Version"
    Current API Version: v0.1.x  
    API Stability: Alpha (may have breaking changes)

!!! tip "More Examples"
    For more usage examples, please refer to the `examples/` directory in the project source code.
