# Claim2Core

> **DRA chooses what and where; Gthulhu controls how it actually runs.**

Claim2Core 是 Gthulhu 用來連接 Kubernetes resource allocation 與 Linux task scheduling 的核心 roadmap。

最重要的問題是：**allocated resource 不等於 delivered performance**。

Workload 即使已經取得 GPU、NIC、CPU set、NUMA domain 或其他 device，仍可能因為 host-side Linux tasks 被 CPU contention 延遲、locality 不佳或 starvation，而無法達成 latency / throughput SLO。

## 責任邊界

```text
Kueue / Workload API
  admission, quota, fair sharing
            │
            ▼
kube-scheduler / DRA
  Node + device + topology allocation
            │
            ▼
Gthulhu Runtime Plane
  Claim → Pod/cgroup → TGID/TID
            │
            ▼
sched_ext + eBPF
  runtime policy + verification
            │
            ▼
Delivered workload SLO
```

| 層級 | 典型時間尺度 | 核心問題 |
|---|---:|---|
| Kueue / workload admission | 秒 → 分鐘 | 這個 Workload 現在能不能開始？ |
| kube-scheduler / DRA | 毫秒 → 秒 | 要用哪個 Node/device/topology？ |
| Gthulhu / `sched_ext` | 微秒 → 毫秒 | Workload 裡哪些 threads 何時、在哪些 CPU 上執行？ |

## Source of Truth

最重要的 correctness 區分：

- `ResourceSlice` = **inventory**；
- `ResourceClaim.status.allocation` = **actual allocation**。

目標 lineage：

```text
Workload / PodGroup UID
  → Pod UID
  → ResourceClaim UID + generation
  → allocated driver / pool / device
  → NUMA / PCIe / network topology
  → Pod cgroup
  → TGID / TID / starttime
  → sched_ext DSQ / BPF-map entry
  → runtime metrics
  → workload SLO
```

## 實作順序

### 1. 修正 DRA 基礎語意

- 使用現代 `resource.k8s.io/v1` semantics；
- 支援 ResourceSlice 的各種 node-selection forms；
- 分清 DeviceClass 與 driver identity；
- 明確分離 inventory 與 allocation code paths。

Tracking: [Gthulhu/Gthulhu#133](https://github.com/Gthulhu/Gthulhu/issues/133)

### 2. Read-only ResourceClaim observer

先建立 workload-to-device binding，不改 scheduler 行為。

```go
type ClaimDeviceBinding struct {
    ClaimUID        types.UID
    ClaimGeneration int64
    PodUID          types.UID
    NodeName        string
    Driver          string
    Pool            string
    Device          string
    NUMANodes       []int
    PCIeRoot        string
    PCIBusID        string
}
```

Kubernetes API state 應存在 control/update path；微秒級 scheduling 必須使用 node-local cached state。

### 3. Claim-to-Task preview / provenance

在寫入 scheduler state 前，Gthulhu 應先能解釋：

```text
Claim → Pod → cgroup → TGID/TID/starttime → proposed runtime policy
```

Preview 必須 read-only，並回傳 matched tasks、conflicts、warnings、policy generation，以及 intended-vs-actual runtime state。

Tracking: [Gthulhu/Gthulhu#134](https://github.com/Gthulhu/Gthulhu/issues/134)

TID-aware groundwork 已由 [Gthulhu/Gthulhu#135](https://github.com/Gthulhu/Gthulhu/pull/135) 合併完成。

### 4. Static DRAExecutionPolicy

使用者應表達 portable intent，而不是直接填 scheduler internals。

```yaml
apiVersion: scheduling.gthulhu.io/v1alpha1
kind: DRAExecutionPolicy
metadata:
  name: llm-decode
spec:
  workloadSelector:
    matchLabels:
      llm-d.ai/role: decode
  resourceClaims:
    - gpu
    - rdma
    - cpu
  topology:
    respectAllocatedCPUSet: true
    preferSameNUMA: true
    preferSamePCIeRoot: true
  taskRoles:
    - name: decode
      selector:
        registeredRole: decode
      executionClass: latency-critical
  safety:
    requirePreview: true
    maxBoostDuration: 30s
    failClosedOnStaleClaim: true
    fallback: default-scheduler
```

Controller 再依 allocated cpuset、NUMA/LLC/topology 等條件，編譯成 DSQ / slice / weight / locality decisions。

### 5. 先做一個 workload adapter

先證明整個模型可行，再做 generic automatic classification。

兩條高價值路線：

- **CPU DRA × Gthulhu × free5GC/UPF**：最快建立可信 end-to-end demo；
- **GPU + RDMA + CPU DRA × LLM phase-aware scheduling**：研究影響力最高。

Task-role discovery 建議依序演進：

1. explicit role hint；
2. workload-specific adapter；
3. eBPF/uprobes/activity-based classification + confidence。

### 6. Closed-loop runtime controller

只有 static policy + provenance 已可信後，才讓 Gthulhu 根據 runtime signal 自動調整 policy。

第一版應使用有上下界、可解釋的 rule，不要直接上 unconstrained ML/RL。

## Correctness Invariants

Claim2Core 不只需要 benchmark，也需要可驗證的 correctness：

- Claim deallocation 後不能留下會影響新 task 的 stale policy；
- TID reuse 不得讓舊 `(TID, starttime)` policy 套到新 task；
- generation rollback 不得 resurrect invalid execution state；
- policy generation 必須 monotonic；
- actual BPF state 不得存在無法解釋的額外 entry；
- DRA/cgroup cpuset 是 hard boundary；
- Decision Maker restart 只能重建目前仍有效的 state。

## 實驗方法

不要只做 `default scheduler vs Gthulhu`。

應採 2×2：

| 組別 | DRA topology-aware allocation | Gthulhu runtime scheduling |
|---|---|---|
| A | off | off |
| B | on | off |
| C | off | on |
| D | on | on |

這樣才能分離 allocation benefit、runtime scheduling benefit，以及兩者的 interaction。

### KPI 範例

**LLM**：TTFT、ITL、tokens/s、GPU idle gap。

**5G/UPF**：p50/p95/p99/p99.9 RTT、jitter、packet loss。

**Runtime**：runnable-to-running latency、context switches、CPU/NUMA migrations、device-local CPU time、scheduler apply latency。

**Safety**：background slowdown、starvation duration、stale BPF entries、task reuse correctness、restart recovery、rollback latency。

## Hard Boundaries

- Gthulhu **不是 GPU scheduler**；它排 Linux CPU task，不直接排 CUDA kernel、GPU SM、MIG 或 NIC hardware queue。
- ResourceClaim/ResourceSlice API call 不能放進微秒級 scheduler hot path。
- CPU DRA/cgroup/kubelet 決定可用 CPU envelope，Gthulhu 只能在這個範圍內最佳化。
- Multi-tenant policy 必須 bounded、scoped、auditable、deterministic。

## Roadmap 討論

Living roadmap 在 [Gthulhu/Gthulhu#141](https://github.com/Gthulhu/Gthulhu/issues/141)。
