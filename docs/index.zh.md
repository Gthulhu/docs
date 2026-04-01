<a href="https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu" target="_blank"><img src="https://img.shields.io/badge/CNCF%20Landscape-5699C6?style=for-the-badge&logo=cncf&label=cncf" alt="cncf landscape" /></a>

<a href="https://ebpf.io/applications/" target="_blank"><img src="https://img.shields.io/badge/eBPF%20Application%20Landscape-5699C6?style=for-the-badge&logo=ebpf&label=ebpf" alt="ebpf landscape" /></a>

[![LFX Health Score](https://insights.linuxfoundation.org/api/badge/health-score?project=gthulhu)](https://insights.linuxfoundation.org/project/gthulhu)


歡迎來到 Gthulhu 的官方網站。Gthulhu 是一個雲原生工作負載編排平台，透過 eBPF 提供細粒度的 Pod 層級排程可觀測性，並為 Kubernetes 工作負載提供自動擴縮容能力。使用者透過直覺的 Web GUI 即可監控 eBPF 收集的精細排程指標，並配置由 KEDA 驅動的自動擴縮策略。對於運行 Linux 6.12+ 且支援 `sched_ext` 的叢集，Gthulhu 更進一步支援核心層級的自訂 CPU 排程。

[📝 分享你如何使用 Gthulhu](https://docs.google.com/forms/d/e/1FAIpQLSeT9Ia1iigu45DDbPgfqijWIN7-Ewkm6-AbTc-HsjyHMvBjCA/viewform?usp=publish-editor){: .md-button .md-button--primary }

## 📰 Latest News

!!! success "Gthulhu 加入 CNCF Landscape"
    Gthulhu 現已成為 [CNCF (Cloud Native Computing Foundation) Landscape](https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu) 的一部分，加入雲原生技術生態系統。

!!! success "Gthulhu 加入 eBPF Application Landscape"
    Gthulhu 已被納入 [eBPF Application Landscape](https://ebpf.io/applications/)，被認可為創新的基於 eBPF 的調度解決方案。

## 概覽

Gthulhu 是一個雲原生工作負載編排平台，提供細粒度的 Pod 層級排程可觀測性與自動擴縮容能力，無需修改核心或應用程式碼。

<iframe width="560" height="315" src="https://www.youtube.com/embed/0n7i4RDSy90?si=r2kAHvF8e7WGTDEY" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

### 核心功能

- **Pod 層級排程指標** — Gthulhu 使用 eBPF 掛鉤核心排程事件（`fentry`/`fexit`），收集每個 Process 的指標，包括自願/非自願上下文切換、CPU 時間、等待時間、運行次數和 CPU 遷移。這些指標在 Pod 層級聚合並透過 REST API 公開。
- **宣告式配置** — 使用者透過 Web GUI 或 `PodSchedulingMetrics` CRD，使用 Kubernetes 標籤選擇器和命名空間定義要監控的工作負載。
- **KEDA 自動擴縮整合** — Gthulhu 提供與 [KEDA](https://keda.sh/) 的開箱即用整合，基於實際排程行為而非通用資源使用率來驅動自動擴縮決策。
- **進階功能：排程策略與意圖** *（需要 Linux 6.12+ 且支援 `sched_ext`）* — 使用者可透過 Web GUI 或 REST API 為特定工作負載定義排程策略（優先級、時間片、CPU 親和性）。Manager 將策略轉換為排程意圖並分發至各節點的 Decision Maker，實現跨節點協調排程策略執行。
- **進階功能：自訂 CPU 排程** *（需要 Linux 6.12+ 且支援 `sched_ext`）* — 在支援的核心上，Gthulhu 透過 `sched_ext` 機制掛載自訂的 eBPF CPU 排程器，在核心層級執行排程意圖——包括基於優先級的派發、動態時間片調整和搶佔控制——無需修改核心本身。

### 為什麼選擇 Gthulhu？

預設的 Linux 核心排程器強調公平性，無法針對個別應用程式的特定需求進行最佳化。雲原生工作負載——交易系統、大數據分析、機器學習訓練——都有不同的排程需求。Gthulhu 透過以下方式彌合這一差距：

1. **讓排程可見** — 將核心層級的排程行為轉化為可操作的指標
2. **讓擴縮更智慧** — 基於實際排程壓力而非僅 CPU/記憶體平均值來驅動自動擴縮
3. **讓排程可調** （進階）— 在支援的核心上允許按工作負載設定 CPU 排程策略

### 架構說明

為了讓使用者能夠輕鬆地定義監控與排程策略，Gthulhu 提供了直覺的 Web GUI 和 REST API。在這些介面的背後，有幾個關鍵組件協同工作：

#### 1\. Gthulhu API Server (Manager Mode)

Manager 接受使用者的策略請求，並將其轉換為具體的排程意圖。
```bash
$ curl -X POST http://localhost:8080/api/v1/strategies \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{            
    "strategyNamespace": "default",
    "labelSelectors": [
      {"key": "app.kubernetes.io/name", "value": "prometheus"}
    ],
    "k8sNamespace": ["default"],
    "priority": 10,
    "executionTime": 20000000
  }'
```
上方的範例展示了如何使用 curl 命令向 Gthulhu API Server 發送一個排程策略請求，Manager 收到該請求後會嘗試從 Kubernetes 叢集中選取符合標籤選擇器的 Pod，並根據指定的優先級和執行時間來調整這些 Pod 的排程策略。

#### 2\. Gthulhu API Server (Decision Maker Mode)

Decision Maker 以 DaemonSet 的形式部署在叢集中的每個節點上。它透過 eBPF 程式掛鉤核心排程事件，即時收集每個 Process 的排程指標，並根據 Manager 發送的排程意圖尋找出目標 Process(es)。

#### 3\. eBPF 指標收集器

每個 Decision Maker 包含一個 eBPF 指標收集器，掛鉤核心排程事件（`fentry`/`fexit`）以收集細粒度的 Process 排程指標。這些指標在 Pod 層級聚合並匯出至 Prometheus，支援 Grafana 儀表板和 KEDA 驅動的自動擴縮。

#### 4\. Gthulhu Scheduler *（進階功能 — 需要 Linux 6.12+ 且支援 sched_ext）*

在支援的核心上，可以啟用 Gthulhu Scheduler 在核心層級應用自訂 CPU 排程策略。它可再細分為兩個部分：

- **Gthulhu Agent**：負責與 Linux Kernel 的 sched_ext 框架進行互動，並應用排程決策（基於優先級的派發、動態時間片調整和搶佔控制）。
- **Qumun Framework**：提供底層的 eBPF 程式碼和相關工具，確保 Gthulhu Agent 能夠高效地與 Linux 核心進行溝通。

下方的圖示展示了 Gthulhu 的整體架構：

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             Gthulhu Architecture                                 │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   ┌──────────────┐        ┌──────────────────────┐        ┌─────────────────┐    │
│   │    User      │──────▶ │      Manager         │──────▶ │    MongoDB      │    │
│   │  (Web GUI)   │        │ (Central Management) │        │  (Persistence)  │    │
│   └──────────────┘        └──────────┬───────────┘        └─────────────────┘    │
│                                      │                                           │
│                      ┌───────────────┼───────────────┐                           │
│                      │               │               │                           │
│                      ▼               ▼               ▼                           │
│           ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                     │
│           │Decision Maker│ │Decision Maker│ │Decision Maker│  (DaemonSet)        │
│           │   (Node 1)   │ │   (Node 2)   │ │   (Node N)   │                     │
│           └──────┬───────┘ └──────┬───────┘ └──────┬───────┘                     │
│                  │                │                │                              │
│          ┌───────┴───────┐ ┌──────┴───────┐ ┌─────┴────────┐                     │
│          ▼               ▼ ▼              ▼ ▼              ▼                      │
│   ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐                    │
│   │eBPF Metrics│ │ sched_ext  │ │eBPF Metrics│ │ sched_ext  │                    │
│   │ Collector  │ │ Scheduler* │ │ Collector  │ │ Scheduler* │                    │
│   └──────┬─────┘ └────────────┘ └──────┬─────┘ └────────────┘                    │
│          │                              │                                        │
│          ▼                              ▼               ┌─────────────────┐       │
│   ┌────────────────────────────────────────────┐        │      KEDA       │       │
│   │       Prometheus / Grafana Dashboards      │───────▶│  (Auto-Scaler)  │       │
│   └────────────────────────────────────────────┘        └─────────────────┘       │
│                                                                                  │
│   * sched_ext scheduler 需要 Linux 6.12+（進階功能）                               │
└──────────────────────────────────────────────────────────────────────────────────┘
```

**運作流程：**

1. 使用者透過 **Web GUI**（或 `PodSchedulingMetrics` CRD）選擇 Kubernetes 工作負載，定義監控/排程策略。
2. **Manager** 持久化配置，透過 Kubernetes API（Informer）查詢 Pod，並將意圖分發至各節點的 Decision Maker。
3. 每個 **Decision Maker**（以 DaemonSet 部署）在每個節點上運行，掛載 eBPF 程式到核心排程鉤子以即時收集 Process 指標。
4. 指標在 Pod 層級聚合並匯出至 **Prometheus**，支援 Grafana 儀表板和 **KEDA** 驅動的自動擴縮。
5. 在支援 Linux 6.12+ 和 `sched_ext` 的節點上，可啟用進階 **自訂排程器** 進行基於優先級的派發和時間片調整。

## DEMO

點擊下方連結觀看我們在 YouTube 上的 DEMO！

<iframe width="560" height="315" src="https://www.youtube.com/embed/Cyjrh9cW1a8?si=0TL20Cd084wEoEVv" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

<iframe width="560" height="315" src="https://www.youtube.com/embed/MfU64idQcHg?si=HAdQLQU1NaoQEbkf" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## 開源授權

本專案採用 **Apache License 2.0** 授權。

## 社群與支援

- **GitHub**: [Gthulhu](https://github.com/Gthulhu/Gthulhu) | [Qumun](https://github.com/Gthulhu/scx_goland_core)
- **問題回報**: 請在 GitHub Issues 中回報問題
- **功能請求**: 歡迎提交 Pull Request 或開啟 Issue 討論
- **媒體報導**: 查看 [媒體報導與提及](mentioned.md) 了解專案的影響力

---

## 下一步

- 📖 查看 [工作原理](how-it-works.md) 了解技術細節
- 🎯 閱讀 [專案目標](project-goals.md) 了解發展方向
- 📜 瀏覽 [開發歷程](development-history.md) 了解技術挑戰與解決方案
- 🛠️ 參考 [API 文檔](api-reference.md) 進行開發
