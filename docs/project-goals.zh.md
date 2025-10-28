# 專案目標

本頁面介紹 Gthulhu 和 Qumun 專案的設計理念、發展目標與未來願景。

## 專案願景

受到 scx_rustland 的啟發，[Ian](https://github.com/ianchen0119) 使用 Golang 重造了這款 eBPF-based scheduler，並命名為 Gthulhu。
Gthulhu 的目標是成為一個靈活且高效的 CPU 調度器，一般使用者能夠藉由配置 Configuration 的方式來最佳化應用程式的延遲表現或是吞吐量。對於進階開發者來說，Gthulhu 提供 plugin 機制，讓開發者能夠在 User-Space 實作自訂的調度策略，並且透過 eBPF 程式將決策傳遞給 Linux Kernel。使 Linux 調度器能夠更好地適應現代化的工作負載需求。

## 開發原則

1. 保持與 scx 的同步：scx 是 Linux Kernel 中的排程器擴展框架，Gthulhu 將持續跟進 scx 的發展，確保與最新的 Kernel 版本相容。不僅如此，Gthulhu 也會利用社群的力量，讓排程器實作能夠更容易地被分享與重用。
2. 盡可能寬鬆的授權方式：Gthulhu 僅在必要的部分使用 GPL 授權，其他部分則使用更寬鬆的 Apache 授權，讓開發者能夠更自由地使用和修改程式碼。
3. 易於擴展與客製化：Gthulhu 的設計考量到不同應用場景的需求，提供多種配置選項和 plugin 機制，讓使用者能夠根據自己的需求排程策略。
4. 雲原生為導向：Gthulhu 專注於支援雲原生應用程式，特別是容器化工作負載，並且與 Kubernetes 等容器編排平台無縫整合。


## 目標應用場景

1. 低延遲應用程式：Gthulhu 能夠最佳化低延遲應用程式的效能，例如通訊系統 [[1]](https://www.youtube.com/watch?v=MfU64idQcHg)、遊戲和金融交易系統。
2. 高吞吐量工作負載：Gthulhu 支援高吞吐量的工作負載，例如大數據處理和機器學習任務，確保這些應用程式能夠充分利用系統資源。
3. 多節點分散式系統：Gthulhu 能夠在多節點的分散式系統中協調資源分配，提升整體系統的效能和穩定性。

---

!!! quote "專案使命"
    我們相信，通過持續的技術創新和開放的社群協作，Gthulhu 將成為 Linux 調度器領域的重要力量，為現代應用提供更好的效能和體驗。

!!! tip "參與貢獻"
    如果您認同我們的目標和願景，歡迎加入我們的開發者社群！查看 [貢獻指南](contributing.md) 了解如何參與專案開發。
