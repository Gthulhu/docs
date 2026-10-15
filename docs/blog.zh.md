# 文章

Gthulhu 社群的技術文章、實驗紀錄與專案筆記。

<div class="grid cards" markdown>

-   :material-brain:{ .lg .middle } **什麼情況下 CPU 排程能改善 AI 推論？**

    ---

    整理 vLLM 與 DGX Spark 實驗，分析 CPU contention、static pinning、`sched_ext`，以及 host scheduling 何時會真正進入 AI inference critical path。

    [:octicons-arrow-right-24: 閱讀文章](vllm-cpu-pressure.md)

-   :material-shield-lock:{ .lg .middle } **使用 Istio Ambient Mode 強化 Gthulhu 網路安全**

    ---

    使用 Kubernetes NetworkPolicy、Istio Ambient、Waypoint、Gateway API 與 L7 Authorization 降低高權限 scheduler 元件的 blast radius。

    [:octicons-arrow-right-24: 閱讀文章](istio.md)

-   :material-network:{ .lg .middle } **使用自訂 eBPF Scheduler 改善網路效能**

    ---

    Gthulhu 早期案例：以 eBPF CPU scheduling 改善 networking workload。文章發布於 free5GC 社群 Blog。

    [:octicons-arrow-right-24: 前往 free5GC](https://free5gc.org/blog/20250726/index.en/)

-   :material-access-point-network:{ .lg .middle } **使用 GTP 訊號自動最佳化 eBPF 排程**

    ---

    探討如何利用 GTP-aware signals 動態調整 5G packet-processing workload 的 runtime scheduling。

    [:octicons-arrow-right-24: 前往 free5GC](https://free5gc.org/blog/20251126/20251126/)

</div>

## 我們會寫什麼

Gthulhu 位於 Kubernetes resource allocation 與 Linux task execution 之間，因此文章主要聚焦在：

- Linux `sched_ext` 與 eBPF scheduling；
- Kubernetes workload / topology awareness；
- AI / GPU inference 的 host-side scheduling；
- networking 與 packet-processing workload；
- runtime observability 與 scheduling policy；
- security 與 production hardening。

後續的新實驗與專案筆記都會集中到這個 Blog index，而不是讓頂層 **Blog** 直接跳到某一篇外部文章。
