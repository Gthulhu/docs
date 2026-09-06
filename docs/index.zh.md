<a href="https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu" target="_blank"><img src="https://img.shields.io/badge/CNCF%20Landscape-5699C6?style=for-the-badge&logo=cncf&label=cncf" alt="cncf landscape" /></a>
<a href="https://ebpf.io/applications/" target="_blank"><img src="https://img.shields.io/badge/eBPF%20Application%20Landscape-5699C6?style=for-the-badge&logo=ebpf&label=ebpf" alt="ebpf landscape" /></a>

[![LFX Health Score](https://insights.linuxfoundation.org/api/badge/health-score?project=gthulhu)](https://insights.linuxfoundation.org/project/gthulhu)

# Gthulhu

## 在 CPU contention 下保護關鍵工作負載

Gthulhu 使用 eBPF 與 Linux `sched_ext`，讓 Kubernetes 節點上的 workload scheduling 可以被觀測、控制與驗證。

**CPU contention 下的實測結果：**

| Workload | Baseline | 使用 Gthulhu | 結果 |
|---|---:|---:|---:|
| free5GC / GTP data path — UE 平均 ping latency | **88.98 ms** | **2.079 ms** | **降低 97.66%** |
| free5GC / GTP data path — UE 最大 ping latency | **130.95 ms** | **8.45 ms** | **降低 93.55%** |
| vLLM Qwen2.5-0.5B decode (`tg128`) under CPU pressure | **~6.7 t/s** | **~21.3 t/s**（tiered policy） | **約 3.2× throughput** |

free5GC 數據已發表於 free5GC 社群部落格。vLLM 數據來自可重現的 community benchmark，目前正在 vLLM 官方 blog PR 審核中，因此應視為 upstream-reviewing experiment，而不是適用所有環境的效能保證。

[閱讀 free5GC Case Study](https://free5gc.org/blog/20251126/20251126/){: .md-button .md-button--primary }
[vLLM Benchmark PR](https://github.com/vllm-project/vllm-project.github.io/pull/300){: .md-button }
[開始使用](k8s.md){: .md-button }

> **DRA chooses what and where; Gthulhu controls how it actually runs.**

## 為什麼這件事重要

Workload 即使已經取得 GPU、NIC、CPU set 或 Kubernetes placement，也可能因 host-side Linux tasks 在 CPU contention 下被延遲，而無法達成 latency / throughput SLO。

Gthulhu 專注於這個 execution gap：

```text
Kubernetes admission / placement / allocation
                    │
                    ▼
             Gthulhu runtime plane
                    │
       Pod / cgroup / TGID / TID resolution
                    │
                    ▼
               sched_ext + eBPF
                    │
                    ▼
       latency / throughput / jitter / SLO
```

## 已驗證的使用案例

### 5G User Plane latency

free5GC 社群已發表 GTP-driven scheduling 實驗，將 `gtp5g-tracer`、userspace operator 與 Gthulhu 串起來。在相同 CPU stress 下，UE 平均 ping latency 從 **88.98 ms 降到 2.079 ms**，最大 latency 從 **130.95 ms 降到 8.45 ms**。

[閱讀：Implementing GTP-driven Automatic Scheduling Optimization with eBPF-based Scheduler](https://free5gc.org/blog/20251126/20251126/)

另一篇較早的 free5GC case study 也展示如何利用 network-domain knowledge 搭配 Gthulhu 的 `sched_ext` policy 降低 RTT。

[閱讀：利用 Custom eBPF-based Schedulers 改善網路效能](https://free5gc.org/blog/20250726/)

### vLLM 在 CPU pressure 下的 inference

另一個可重現實驗使用 DGX Spark / GB10、MicroK8s、vLLM、`stress-ng` 與 Gthulhu，刻意隔離 CPU scheduling 對 GPU inference 的影響。在目前提交給 vLLM blog 的 benchmark 中，default scheduler 在 CPU pressure 下 decode throughput 約為 **6–7 t/s**；使用 Gthulhu 並對 GPU-related work 與 vLLM `EngineCore` 套用 tiered policy 後，`tg128` 約可達 **21 t/s**。

這裡將它標示為 **upstream 審核中的 community benchmark**，而不是廣泛化的 performance guarantee。

[查看 vLLM blog PR #300 的 benchmark 與方法](https://github.com/vllm-project/vllm-project.github.io/pull/300)

## Gthulhu 目前已具備的能力

- **Pod 層級 scheduling observability**：使用 eBPF 收集 scheduler signals。
- **Prometheus / Grafana / KEDA 整合**：支援 scheduler-aware operations 與 scaling。
- **分散式 scheduling intent**：Manager 搭配每節點 Decision Maker。
- **自訂 CPU scheduling**：Linux 6.12+ 可使用 `sched_ext`。
- **TID-aware node policy matching**：可以直接命中非 leader worker thread。
- **明確的 priority semantics**：user-space 與 kernel mode 都有清楚的 boosting 行為。

[了解運作原理](how-it-works.md){: .md-button }
[Claim2Core Roadmap](claim2core.md){: .md-button }

## Claim2Core：從 allocation 到 delivered performance

下一個架構階段，是把 Kubernetes 的實際 allocation 接到 runtime task scheduling：

```text
Kueue / Workload API
        │ admission / quota
        ▼
kube-scheduler / DRA
        │ Node + device + topology allocation
        ▼
Gthulhu Runtime Plane
        │ ResourceClaim → Pod/cgroup → TGID/TID
        ▼
sched_ext + eBPF
        │ runtime policy + verification
        ▼
Delivered workload SLO
```

最重要的 correctness 原則是：

- `ResourceSlice` 是 **inventory**。
- `ResourceClaim.status.allocation` 才是 workload 的 **actual allocation**。

Gthulhu 不重新實作 kube-scheduler、DRA 或 Kueue，而是在 Kubernetes/cgroup 建立的 resource envelope 內，控制 workload 真正取得 CPU service 的方式。

完整 implementation phases 與安全邊界請看 [Claim2Core](claim2core.md)。

## 架構一覽

```text
User / Web UI / CRD
        │
        ▼
Manager API ───────▶ MongoDB / Kubernetes API
        │
        ▼
Decision Maker DaemonSet
        │
        ├── eBPF scheduling metrics collector ──▶ Prometheus / Grafana / KEDA
        │
        └── task resolution / scheduling intent
                         │
                         ▼
                   Gthulhu daemon
                         │
                         ▼
                    sched_ext / BPF
                         │
                         ▼
                   Linux scheduler
```

## 參與 Gthulhu

- [在 Kubernetes 部署 Gthulhu](k8s.md)
- [理解系統架構與 scheduler semantics](how-it-works.md)
- [閱讀 Claim2Core roadmap](claim2core.md)
- [參與貢獻](contributing.md)
- [GitHub repository](https://github.com/Gthulhu/Gthulhu)
- [Roadmap issue #141](https://github.com/Gthulhu/Gthulhu/issues/141)
