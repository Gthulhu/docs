<a href="https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu" target="_blank"><img src="https://img.shields.io/badge/CNCF%20Landscape-5699C6?style=for-the-badge&logo=cncf&label=cncf" alt="cncf landscape" /></a>

<a href="https://ebpf.io/applications/" target="_blank"><img src="https://img.shields.io/badge/eBPF%20Application%20Landscape-5699C6?style=for-the-badge&logo=ebpf&label=ebpf" alt="ebpf landscape" /></a>

[![LFX Health Score](https://insights.linuxfoundation.org/api/badge/health-score?project=gthulhu)](https://insights.linuxfoundation.org/project/gthulhu)

# Gthulhu

Gthulhu 協助平台團隊看懂、自動化並調整 Kubernetes 工作負載背後的 Linux 排程行為。

它先從安全的 Pod 層級排程可觀測性開始：透過 eBPF 收集核心排程訊號，交給 Prometheus、Grafana 與 KEDA，讓擴縮容決策反映真實的排程壓力。若叢集運行 Linux 6.12+ 且支援 `sched_ext`，Gthulhu 也能在核心排程邊界套用工作負載感知的 CPU 排程策略。

[開始使用](k8s.md){: .md-button .md-button--primary }
[了解運作原理](how-it-works.md){: .md-button }
[分享你的使用案例](https://docs.google.com/forms/d/e/1FAIpQLSeT9Ia1iigu45DDbPgfqijWIN7-Ewkm6-AbTc-HsjyHMvBjCA/viewform?usp=publish-editor){: .md-button }

## 為什麼需要 Gthulhu？

Kubernetes 負責把 Pod 放到節點上，但每個 Process 何時真正取得 CPU，仍由 Linux 核心排程器決定。這段最後一哩通常很難觀察，卻可能正是工作負載等待、遷移或延遲不穩的原因。

Gthulhu 補上這個缺口：

- **看見排程壓力** — 收集每個 Process 的排程訊號，並彙整成 Pod 層級指標。
- **用真實排程狀態擴縮** — 將等待時間、執行時間、上下文切換與 CPU 遷移等訊號送入 Prometheus 與 KEDA，而不只依賴 CPU 平均使用率。
- **用宣告式方式選擇工作負載** — 透過 Web UI、REST API 或 `PodSchedulingMetrics` CRD 指定要觀測的 Pod。
- **調整關鍵工作負載** — 在支援 `sched_ext` 的節點上套用優先級與時間片策略。
- **跨節點落實意圖** — 由 Manager 與各節點 Decision Maker 將工作負載意圖轉成節點本地行動。

## 你可以用 Gthulhu 做什麼？

### 觀測每個工作負載

Gthulhu 將 eBPF 程式掛到 Linux 排程事件，並把原始 Process 活動轉成 Kubernetes 可理解的指標。你可以知道 Pod 是否在等待 CPU、是否頻繁跨 CPU 遷移，或是否受到排程競爭影響。

### 讓擴縮容更貼近現況

排程行為通常比粗略的資源使用率更能反映工作負載壓力。Gthulhu 將指標匯出到 Prometheus，讓 KEDA 能依核心層級觀察到的壓力進行擴縮。

### 套用排程意圖

在進階環境中，團隊可以為特定工作負載定義排程策略。Manager 解析 Kubernetes 層級的意圖，Decision Maker 對應到節點本地 Process，排程器再套用優先級、自訂時間片等策略。

### 不需要維護自訂核心

基礎監控功能只需要 BTF-enabled Linux 核心即可透過 eBPF 運作，不需修補核心。選用的進階排程器則基於 Linux `sched_ext`，讓團隊能實驗自訂排程策略，而不必維護客製化核心。

## 架構一覽

```
User / Web UI / CRD
        │
        ▼
Manager API ───────▶ MongoDB
        │
        ▼
Decision Maker DaemonSet
        │
        ├── eBPF 排程指標收集器 ──▶ Prometheus / Grafana / KEDA
        │
        └── sched_ext 排程整合 ───▶ Linux 核心排程路徑
```

Manager 負責使用者、RBAC、策略 API 與叢集層級意圖。Decision Maker 在每個節點上執行，尋找符合條件的 Pod Process、提供節點本地 PID 策略、收集指標，並把 runtime configuration 轉送給本地 Gthulhu daemon。daemon 可以只執行 monitor-only 模式，也可以在配置後啟用進階排程器。

完整資料流請參考 [運作原理](how-it-works.md)。

## Demo

<iframe width="560" height="315" src="https://www.youtube.com/embed/0n7i4RDSy90?si=r2kAHvF8e7WGTDEY" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

<iframe width="560" height="315" src="https://www.youtube.com/embed/Cyjrh9cW1a8?si=0TL20Cd084wEoEVv" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

<iframe width="560" height="315" src="https://www.youtube.com/embed/MfU64idQcHg?si=HAdQLQU1NaoQEbkf" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## 最新消息

!!! success "Gthulhu 加入 CNCF Landscape"
    Gthulhu 已列入 [CNCF Landscape](https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu)，成為雲原生基礎設施生態的一員。

!!! success "Gthulhu 加入 eBPF Application Landscape"
    Gthulhu 已列入 [eBPF Application Landscape](https://ebpf.io/applications/)，作為基於 eBPF 的排程與可觀測性專案。

## 下一步

- [在 Kubernetes 部署 Gthulhu](k8s.md)
- [理解系統架構](how-it-works.md)
- [配置 Pod 排程指標](pod-metrics.md)
- [查看 API 文件](api-reference.md)

## 社群

- **GitHub**: [Gthulhu](https://github.com/Gthulhu/Gthulhu) | [Qumun](https://github.com/Gthulhu/scx_goland_core)
- **Issue**: 請透過 GitHub Issues 回報問題或提出功能需求。
- **授權**: Apache License 2.0。
