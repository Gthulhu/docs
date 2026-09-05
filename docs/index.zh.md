<a href="https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu" target="_blank"><img src="https://img.shields.io/badge/CNCF%20Landscape-5699C6?style=for-the-badge&logo=cncf&label=cncf" alt="cncf landscape" /></a>
<a href="https://ebpf.io/applications/" target="_blank"><img src="https://img.shields.io/badge/eBPF%20Application%20Landscape-5699C6?style=for-the-badge&logo=ebpf&label=ebpf" alt="ebpf landscape" /></a>

[![LFX Health Score](https://insights.linuxfoundation.org/api/badge/health-score?project=gthulhu)](https://insights.linuxfoundation.org/project/gthulhu)

# Gthulhu

> **DRA chooses what and where; Gthulhu controls how it actually runs.**

Gthulhu 是一個雲原生 runtime scheduling 平台，透過 eBPF 與 Linux `sched_ext`，把 Kubernetes 工作負載意圖連接到真正的 Linux task scheduling。

Kubernetes 可以決定 Workload 是否能開始、放在哪個 Node，以及取得哪些裝置或 topology。Gthulhu 專注於 allocation 之後的 execution gap：找出真正屬於該工作負載的 Linux tasks、套用有邊界的 CPU 排程策略，並驗證 allocation 是否真的轉化成 workload SLO。

[開始使用](k8s.md){: .md-button .md-button--primary }
[了解運作原理](how-it-works.md){: .md-button }
[Claim2Core Roadmap](claim2core.md){: .md-button }

## 目前已具備的能力

- **Pod 層級排程可觀測性**：使用 eBPF 收集 scheduler signals。
- **Prometheus / Grafana / KEDA 整合**：讓操作與 autoscaling 能看見真實 scheduler pressure。
- **分散式 scheduling intent**：Manager 搭配每節點 Decision Maker。
- **自訂 CPU scheduling**：Linux 6.12+ 可使用 `sched_ext`。
- **TID-aware node policy matching**：可以直接命中非 leader 的 worker thread。
- **明確的 priority semantics**：user-space 與 kernel mode 不再把 non-boosting rule 誤解成最高優先級。

## Claim2Core 方向

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

Gthulhu 不應重新實作 kube-scheduler、DRA 或 Kueue，而是消費它們的決策，並且只在 Kubernetes/cgroup 已允許的 resource envelope 內控制 CPU execution。

完整 implementation phases 與安全邊界請看 [Claim2Core](claim2core.md)。

## 為什麼重要

Allocated resource 不等於 delivered performance。Workload 即使已拿到 GPU 或 NIC，host-side 的 feeder、tokenizer、NCCL/RDMA progress、DPDK 或 packet-processing threads 仍可能因 CPU contention 被延遲。

Gthulhu 的價值就是讓這個落差可以被觀測、控制與驗證。

近期最值得驗證的兩條路線：

- **CPU DRA × Gthulhu × free5GC/UPF**：觀察 p99/p99.9 latency 與 jitter；
- **GPU + RDMA + CPU DRA × phase-aware LLM scheduling**：觀察 TTFT、ITL、GPU idle 與 communication progress。

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
        ├── eBPF 排程指標收集器 ──▶ Prometheus / Grafana / KEDA
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

## 最近已合併的 scheduler semantics

Node policy 已經是 thread-aware。Decision Maker 會掃描 `/proc/<tgid>/task/<tid>`，因此策略可以直接命中具名的非 leader worker thread，而不是只能命中 process leader。

Priority semantics 也已明確化：

- `Priority > 0` 代表 boost；
- `Priority == 0` 是 non-boosting；
- user-space mode 使用 TID-first lookup，必要時 fallback 到 TGID；
- kernel mode 不會把 non-boosting strategy 塞進 priority BPF map，避免 priority 0 被誤當成最高 preemptive priority。

詳細行為與目前限制請看 [運作原理](how-it-works.md)。

## Demo

<iframe width="560" height="315" src="https://www.youtube.com/embed/Cyjrh9cW1a8?si=0TL20Cd084wEoEVv" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## 下一步

- [在 Kubernetes 部署 Gthulhu](k8s.md)
- [理解系統架構與目前 scheduler semantics](how-it-works.md)
- [閱讀 Claim2Core roadmap](claim2core.md)
- [配置 Pod 排程指標](pod-metrics.md)
- [參與貢獻](contributing.md)

## 社群

- **GitHub**: [Gthulhu/Gthulhu](https://github.com/Gthulhu/Gthulhu)
- **Roadmap**: [Issue #141](https://github.com/Gthulhu/Gthulhu/issues/141)
- **Framework**: [Gthulhu/qumun](https://github.com/Gthulhu/qumun)
- **授權**: Apache License 2.0
