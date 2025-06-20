# Frequently Asked Questions

This page collects common questions and answers encountered when using Gthulhu and SCX GoLand Core.

## Installation Related Questions

### Q: How can I confirm my kernel supports sched_ext?

A: You can check using the following methods:

```bash
# Method 1: Check kernel configuration
grep -r "CONFIG_SCHED_CLASS_EXT" /boot/config-$(uname -r)

# Method 2: Check /proc/config.gz
zcat /proc/config.gz | grep "CONFIG_SCHED_CLASS_EXT"

# Method 3: Check sched_ext directory
ls /sys/kernel/sched_ext/ 2>/dev/null || echo "sched_ext not supported"
```

If the output contains `CONFIG_SCHED_CLASS_EXT=y`, your kernel supports sched_ext.

### Q: What should I do when getting "libbpf not found" error during compilation?

A: This is usually because libbpf is not properly installed. Please follow these steps to resolve:

```bash
# Ubuntu/Debian
sudo apt install libbpf-dev

# CentOS/RHEL/Fedora
sudo dnf install libbpf-devel

# Or manually compile libbpf
git clone https://github.com/libbpf/libbpf.git
cd libbpf/src
make
sudo make install
```

### Q: Why is Clang 17+ required?

A: Clang 17+ provides more complete BPF support, including:

- Better BPF CO-RE (Compile Once, Run Everywhere) support
- Latest BPF instruction set support
- More stable BPF program compilation

If your system doesn't have Clang 17+, you can install it like this:

```bash
# Ubuntu/Debian
sudo apt install clang-17

# Set environment variables
export CC=clang-17
export CXX=clang++-17
```

## Runtime Related Questions

### Q: Getting "Operation not permitted" error when running

A: This is a permission issue. BPF program loading requires root privileges:

```bash
# Correct way to run
sudo ./main

# Or use Docker
docker run --privileged=true --pid host --rm gthulhu:latest /gthulhu/main
```

### Q: What to do if the system becomes slow after starting the scheduler?

A: This might be due to the following reasons:

1. **Scheduling parameters not suitable for your workload**:
```bash
# Check system load
top
htop

# Check context switch frequency
vmstat 1
```

2. **Insufficient memory**:
```bash
# Check memory usage
free -h
cat /proc/meminfo
```

3. **BPF program performance issues**:
```bash
# Check BPF program statistics
sudo bpftool prog show
sudo bpftool prog profile
```

**Solutions**:
- Stop the scheduler: `sudo pkill -f "./main"`  
- Check system logs: `dmesg | tail -50`
- Adjust scheduling parameters or report the issue

### Q: How to stop the scheduler?

A: You can stop the scheduler using the following methods:

```bash
# Method 1: Ctrl+C (if running in foreground)
^C

# Method 2: Send SIGTERM signal
sudo pkill -TERM -f "./main"

# Method 3: Send SIGINT signal
sudo pkill -INT -f "./main"

# Method 4: Force kill (not recommended)
sudo pkill -KILL -f "./main"
```

## Performance Related Questions

### Q: How to monitor scheduler performance?

A: You can use various tools to monitor scheduler performance:

1. **System tools**:
```bash
# Monitor CPU usage
htop

# Monitor context switches
vmstat 1

# Monitor scheduling latency
perf sched record -- sleep 10
perf sched latency
```

2. **BPF tools**:
```bash
# Check BPF program status
sudo bpftool prog list | grep sched

# Check BPF map contents
sudo bpftool map dump name task_info_map
```

3. **Built-in scheduler monitoring**:
```bash
# View scheduler logs
journalctl -f -u gthulhu

# View BPF trace messages
sudo cat /sys/kernel/debug/tracing/trace_pipe
```

### Q: What advantages does the scheduler have compared to CFS?

A: Main advantages of Gthulhu scheduler:

| Feature | CFS | Gthulhu |
|---------|-----|---------|
| Latency Optimization | Basic | Specialized |
| Task Classification | Unified processing | Automatic classification |
| CPU Topology Awareness | Limited | Complete support |
| Dynamic Adjustment | Static parameters | Real-time adjustment |
| User-space Extension | Not supported | Fully supported |

### Q: How to adjust scheduler parameters?

A: Currently supported adjustment methods:

1. **Environment variables**:
```bash
export GTHULHU_DEBUG=true
export GTHULHU_LOG_LEVEL=DEBUG
sudo -E ./main
```

2. **Compile-time parameters** (modify `main.bpf.c`):
```c
// Adjust base time slice
#define BASE_SLICE_NS    3000000ULL  // 3ms instead of 5ms
```

3. **Runtime API** (planned):
```go
// Future support for dynamic adjustment
params := &SchedulingParams{
    BaseSliceNs: 3000000,
    LatencyFactor: 1.5,
}
UpdateSchedulingParams(params)
```

## Debugging Related Questions

### Q: How to enable debug mode?

A: You can enable debugging through the following methods:

1. **Environment variables**:
```bash
export GTHULHU_DEBUG=true
export GTHULHU_LOG_LEVEL=DEBUG
sudo -E ./main
```

2. **BPF tracing**:
```bash
# Terminal 1: Start scheduler
sudo ./main

# Terminal 2: View BPF traces
sudo cat /sys/kernel/debug/tracing/trace_pipe
```

3. **System logs**:
```bash
# View kernel logs
dmesg -w

# View systemd logs
journalctl -f
```

### Q: What to do when encountering BPF verifier errors?

A: BPF verifier errors usually indicate program issues:

1. **Check error messages**:
```bash
# View detailed errors
dmesg | grep -i bpf
```

2. **Common issues**:
   - **Unbounded loops**: Ensure all loops have clear exit conditions
   - **Memory out of bounds**: Check array accesses are within range
   - **Pointer usage**: Ensure pointers are NULL-checked before use

3. **Verify BPF program**:
```bash
# Use bpftool to verify
sudo bpftool prog load main.bpf.o /sys/fs/bpf/test_prog
```

### Q: How to report issues?

A: If you encounter problems, please follow these steps:

1. **Collect system information**:
```bash
# System information
uname -a
cat /etc/os-release

# Kernel version and configuration
uname -r
grep CONFIG_SCHED_CLASS_EXT /boot/config-$(uname -r)

# Go version
go version

# Clang version
clang --version
```

2. **Collect error logs**:
```bash
# Scheduler logs
sudo ./main 2>&1 | tee gthulhu.log

# System logs
dmesg > dmesg.log
journalctl --since "1 hour ago" > journal.log
```

3. **Submit GitHub Issue**:
   - Go to [Gthulhu Issues](https://github.com/Gthulhu/Gthulhu/issues)
   - Choose appropriate issue template
   - Attach system information and error logs
   - Describe reproduction steps

## Development Related Questions

### Q: How to participate in development?

A: Welcome to participate in development! Please refer to:

1. **View contributing guide**: [contributing.en.md](contributing.en.md)
2. **Understand code structure**:
```
Gthulhu/
├── main.go              # Main program
├── main.bpf.c          # BPF program
├── internal/sched/     # Scheduling logic
└── api/               # API services
```

3. **Set up development environment**:
```bash
git clone https://github.com/Gthulhu/Gthulhu.git
cd Gthulhu
make dep
make build
make test
```

### Q: How to add custom scheduling policies?

A: You can customize through the following methods:

1. **Modify BPF program** (`main.bpf.c`):
```c
// Add custom CPU selection logic
s32 custom_select_cpu(struct task_struct *p, s32 prev_cpu, u64 wake_flags) {
    // Your logic
    return selected_cpu;
}
```

2. **Modify Go program** (`main.go`):
```go
// Add custom task handling logic
func handleCustomTask(taskInfo *TaskInfo) {
    // Your logic
}
```

3. **Use SCX GoLand Core API**:
```go
// Implement CustomScheduler interface
type MyScheduler struct{}

func (s *MyScheduler) ScheduleTask(task *Task) *ScheduleDecision {
    // Your scheduling logic
    return decision
}
```

## Compatibility Issues

### Q: Which Linux distributions are supported?

A: Theoretically supports all distributions with the following conditions:

- **Kernel version**: 6.12+
- **sched_ext support**: Enabled
- **Architecture**: x86_64

**Tested distributions**:
- Ubuntu 24.04+
- Fedora 39+
- Arch Linux (latest)

**Planned support**:
- CentOS/RHEL 9+
- openSUSE Tumbleweed
- Debian 13+

### Q: Can it run in containers?

A: Yes, but requires special permissions:

```bash
# Docker execution
docker run --privileged=true --pid host --rm gthulhu:latest

# Podman execution
podman run --privileged --pid host --rm gthulhu:latest

# Kubernetes execution (requires special configuration)
# Please refer to examples/kubernetes/ directory
```

### Q: Does it conflict with other schedulers?

A: Gthulhu will replace the system default scheduler, therefore:

- **Cannot** run simultaneously with other sched_ext schedulers
- **Will not** affect real-time scheduling classes (SCHED_FIFO, SCHED_RR)
- **Will** replace CFS scheduler functionality

---

!!! question "Problem not resolved?"
    If your problem is not answered here, please:
    
    1. Check [GitHub Issues](https://github.com/Gthulhu/Gthulhu/issues)
    2. Search existing problems and solutions
    3. If not found, please create a new issue
