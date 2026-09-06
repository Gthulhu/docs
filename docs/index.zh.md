# Gthulhu

<div class="gth-hero" markdown>

## CPU 忙起來時，讓關鍵工作負載仍然跑得快

Gthulhu 是一個以 eBPF 與 Linux `sched_ext` 建構的 cloud-native runtime scheduling 平台。當 CPU contention 開始拖慢 Kubernetes workload 時，Gthulhu 會保護真正影響 latency 與 throughput 的 Linux tasks。

<div class="gth-hero-actions">
<a href="k8s.md" class="md-button md-button--primary">開始使用</a>
<a href="https://github.com/Gthulhu/Gthulhu" class="md-button">GitHub</a>
</div>

</div>

<div class="gth-proof-grid" markdown>

<div class="gth-proof-card" markdown>
<span class="gth-proof-eyebrow">free5GC / 5G User Plane</span>

### 平均 latency 降低 97.66%

CPU stress 下，UE 平均 ping latency **88.98 ms → 2.079 ms**。

最大 latency 也從 **130.95 ms → 8.45 ms**。

[閱讀 free5GC 已發表 Case Study →](https://free5gc.org/blog/20251126/20251126/)
</div>

<div class="gth-proof-card" markdown>
<span class="gth-proof-eyebrow">vLLM / GPU Inference</span>

### Decode throughput 約提升 3.2×

CPU pressure 下，`tg128` 從 **~6.7 t/s → ~21.3 t/s**，使用 Gthulhu + tiered scheduling policy。

*此為可重現的 community benchmark，目前仍在 vLLM upstream blog review 中。*

[查看 benchmark 與實驗方法 →](https://github.com/vllm-project/vllm-project.github.io/pull/300)
</div>

</div>

<div class="gth-trust-row" markdown>
<a href="https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu" target="_blank"><img src="https://img.shields.io/badge/CNCF%20Landscape-5699C6?style=for-the-badge&logo=cncf&label=cncf" alt="cncf landscape" /></a>
<a href="https://ebpf.io/applications/" target="_blank"><img src="https://img.shields.io/badge/eBPF%20Application%20Landscape-5699C6?style=for-the-badge&logo=ebpf&label=ebpf" alt="ebpf landscape" /></a>
<a href="https://insights.linuxfoundation.org/project/gthulhu"><img src="https://insights.linuxfoundation.org/api/badge/health-score?project=gthulhu" alt="LFX Health Score" /></a>
</div>

## Gthulhu 解決什麼問題？

Kubernetes 可以把 workload 放到正確的 Node，也可以分配正確的資源；但這不代表 workload 裡真正重要的 Linux threads，在需要 CPU 時一定拿得到 CPU。

當系統出現 contention，GPU feeder、`EngineCore`、packet-processing workers、IRQ-related work 或其他 latency-sensitive tasks，都可能被背景 CPU workload 延遲。最後形成一個很直接的問題：**資源已經分配了，SLO 還是沒達成。**

Gthulhu 專注處理這個 execution gap。

<div class="gth-flow" markdown>

**1. Observe — 看見問題**  
用 eBPF 看清楚哪些 tasks 在等待、執行、migration，以及誰正在競爭 CPU。

**2. Target — 找到真正重要的 task**  
把 Kubernetes workload intent 解析到實際影響服務的 Linux process / thread。

**3. Control — 精準控制**  
利用 `sched_ext` 套用有邊界的 runtime scheduling policy，保護關鍵 execution path。

</div>

> **DRA chooses what and where. Gthulhu controls how it actually runs.**

## 為 workload-aware runtime scheduling 而設計

<div class="grid cards" markdown>

-   :material-eye-outline:{ .lg .middle } **Scheduling Observability**

    ---

    使用 eBPF 提供 Pod-level scheduling metrics，並整合 Prometheus 與 Grafana。

-   :material-tune-variant:{ .lg .middle } **Fine-grained Control**

    ---

    對特定 workload、process，甚至非 leader worker thread 套用 scheduling intent；支援 TID-aware matching。

-   :material-server-network:{ .lg .middle } **Cloud-native Operation**

    ---

    透過 Manager 與每節點 Decision Maker，把 scheduling intent 分散到 Kubernetes nodes。

-   :material-chart-line:{ .lg .middle } **SLO-oriented Automation**

    ---

    將 scheduler signals 接到 Prometheus、Grafana 與 KEDA，支援 runtime-aware operations 與 scaling。

</div>

[了解 Gthulhu 如何運作](how-it-works.md){: .md-button }

## 下一步：Claim2Core

目前 Gthulhu 已能在 runtime 觀測與控制 Linux task scheduling。下一步，是把這個能力直接接到 Kubernetes **實際分配的資源**。

```text
Kueue / Workload API
        ↓
kube-scheduler / DRA
        ↓  ResourceClaim + topology
Gthulhu Runtime Plane
        ↓  Pod / cgroup / TGID / TID
sched_ext + eBPF
        ↓
Delivered workload SLO
```

核心原則很簡單：

- `ResourceSlice` 告訴我們有哪些資源。
- `ResourceClaim.status.allocation` 告訴我們 workload 實際拿到了什麼。
- Gthulhu 把 allocation 轉成可驗證的 runtime execution policy，並且**不突破 Kubernetes 已建立的 CPU / resource boundary**。

[查看 Claim2Core Roadmap](claim2core.md){: .md-button }
[追蹤 Roadmap Issue #141](https://github.com/Gthulhu/Gthulhu/issues/141){: .md-button }

## 從真實 workload 開始

<div class="gth-cta" markdown>

### 先看 CPU scheduling 到底怎麼影響你的服務

在 Kubernetes 部署 Gthulhu、觀察 scheduler behavior，再只對數據證明有影響的 execution path 套用 policy。

[部署 Gthulhu](k8s.md){: .md-button .md-button--primary }
[閱讀 free5GC Case Study](https://free5gc.org/blog/20251126/20251126/){: .md-button }
[參與貢獻](contributing.md){: .md-button }

</div>
