# Gthulhu

<div class="gth-hero" markdown>

## Kubernetes 決定 workload 放哪裡；Gthulhu 決定它怎麼拿到 CPU

Gthulhu 把 **Kubernetes 的 scheduling intent** 一路帶到 **Linux runtime execution**。它會在每個 Node 上把 workload 解析到真正重要的 process / thread，再利用 eBPF 與 Linux `sched_ext` 套用有邊界的 CPU scheduling policy——不用取代 `kube-scheduler`，也不用維護自己的 kernel fork。

<div class="gth-hero-actions">
<a href="k8s.md" class="md-button md-button--primary">開始使用</a>
<a href="how-it-works.md" class="md-button">了解運作方式</a>
</div>

</div>

<div class="gth-proof-grid" markdown>

<div class="gth-proof-card" markdown>
<span class="gth-proof-eyebrow">free5GC / 5G User Plane</span>

### 平均 latency 降低 97.66%

在已發表的 CPU stress case study 中，UE 平均 ping latency 從 **88.98 ms → 2.079 ms**。

最大 latency 也從 **130.95 ms → 8.45 ms**。

[閱讀 free5GC 已發表 Case Study →](https://free5gc.org/blog/20251126/20251126/)
</div>

<div class="gth-proof-card" markdown>
<span class="gth-proof-eyebrow">vLLM / host-side scheduling research</span>

### 找出 CPU scheduling 何時真的進入 inference critical path

我們的實驗觀察 CPU contention 對 vLLM engine / feeder threads 的影響，以及 host-side scheduling 在什麼 bottleneck pattern 下能恢復效能。實際結果會隨 workload 與 contention pattern 而改變。

[查看 benchmark 與方法 →](vllm-cpu-pressure.md)
</div>

</div>

<div class="gth-trust-row" markdown>
<a href="https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu" target="_blank"><img src="https://img.shields.io/badge/CNCF%20Landscape-5699C6?style=for-the-badge&logo=cncf&label=cncf" alt="cncf landscape" /></a>
<a href="https://ebpf.io/applications/" target="_blank"><img src="https://img.shields.io/badge/eBPF%20Application%20Landscape-5699C6?style=for-the-badge&logo=ebpf&label=ebpf" alt="ebpf landscape" /></a>
<a href="https://insights.linuxfoundation.org/project/gthulhu"><img src="https://insights.linuxfoundation.org/api/badge/health-score?project=gthulhu" alt="LFX Health Score" /></a>
</div>

## Kubernetes placement 之後，還有一段 execution gap

Kubernetes 可以把 workload 放到正確的 Node，也可以分配正確的資源；但這不代表 workload 裡真正重要的 Linux threads，在需要 CPU 時一定拿得到 CPU。

當系統出現 contention，GPU feeder、`EngineCore`、packet-processing workers、IRQ-related work 或其他 latency-sensitive tasks，都可能被背景 CPU workload 延遲。最後形成一個很直接的問題：**資源已經分配了，runtime SLO 還是可能沒達成。**

Gthulhu 專注處理的，就是這段 execution gap。

## 從 workload intent 一路到 CPU dispatch

![Gthulhu 從 workload intent 到每個 Node 的 sched_ext CPU dispatch 流程](assets/gthulhu-workflow.gif)

這張圖可以拆成四個步驟看：

1. **表達 intent** — 使用者或 controller 透過 Web/API 與 Kubernetes CRD 建立 scheduling strategy。
2. **解析 workload** — Manager 觀察 Kubernetes state，把 strategy 轉成要送往實際執行 workload 的 Node policy。
3. **每個 Node 自己做決策** — 每個 Node 都有自己的 Decision Maker 與 Gthulhu Scheduler，會依 node-local workload / task state 解析 policy。
4. **真正落到 CPU dispatch** — node-local scheduler 把決策套到 eBPF `sched_ext`，由它控制 dispatch queues 與 CPU placement。

這樣責任就很清楚：Kubernetes 仍然負責 **placement 與 resource allocation**；Gthulhu 負責 **這些 Linux tasks 在 runtime 到底怎麼被排到 CPU 上**。

## Observe → Target → Control

<div class="gth-flow" markdown>

**1. Observe — 看見問題**  
用 eBPF 看清楚哪些 tasks 在等待、執行、migration，以及誰正在競爭 CPU。

**2. Target — 找到真正重要的 task**  
把 Kubernetes workload intent 解析到實際影響服務的 Linux process / thread。

**3. Control — 精準控制**  
利用 `sched_ext` 套用有邊界的 runtime scheduling policy，保護關鍵 execution path。

</div>

> **Kubernetes 決定 where；Gthulhu 控制 CPU time 要 how delivered。**

## 為 workload-aware runtime scheduling 而設計

<div class="grid cards" markdown>

-   **Scheduling Observability**

    ---

    使用 eBPF 提供 Pod-level scheduling metrics，並整合 Prometheus 與 Grafana。

-   **Fine-grained Control**

    ---

    對特定 workload、process，甚至非 leader worker thread 套用 scheduling intent；支援 TID-aware matching。

-   **Cloud-native Operation**

    ---

    Manager 把 policy 分發到每個 Node 的 Decision Maker，讓 execution decision 貼近 node-local workload state。

-   **不用 kernel fork 的 kernel-level control**

    ---

    利用 Linux `sched_ext` 與 eBPF 改變 CPU dispatch 行為，同時遵守 Kubernetes 已建立的 resource boundary。

</div>

[深入了解架構](how-it-works.md){: .md-button }

## 哪些 workload 特別適合？

Gthulhu 最有價值的情境，是 **CPU scheduling 已經進入 workload critical path**，例如：

- CPU pressure 下的 packet-processing / 5G user-plane workload；
- AI / accelerator host 上，CPU-side feeder 或 engine threads 成為 bottleneck；
- noisy-neighbor contention 下的 latency-sensitive service；
- 需要可觀測、可替換 runtime policy 的 scheduler research。

如果真正的 bottleneck 在 GPU、network、storage 或 application 本身，改 CPU scheduling 未必會有明顯改善。Gthulhu 的目標不是假設所有 workload 都需要 custom scheduler，而是把這件事量測清楚，再決定是否值得介入。

## 下一步：Claim2Core

目前 Gthulhu 已能在 runtime 觀測與控制 Linux task scheduling。**Claim2Core** 的下一步，是把這個能力直接接到 Kubernetes 實際分配的資源。

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
