# Node-Level Scheduling Policies

Gthulhu 可以直接對指定節點上的 Linux task 套用排程策略，而不要求該 workload 必須先被 Kubernetes Pod 管理。

這特別適合：

- 直接在主機或 Docker 中執行的 vLLM；
- systemd service 與 host daemon；
- DGX Spark / GB10 上的本地 inference runtime；
- 其他不在 Kubernetes 中、但仍希望使用 workload-aware CPU scheduling 的程序。

Node-level policy 會先選出一個或多個節點，再依 Linux task 的 `comm` 名稱比對程序或執行緒，最後把 Gthulhu scheduling strategy 套用到實際匹配到的 task。

!!! tip "試用 live mock"
    Web GUI mock 已包含 Node Policies 頁面：[gthulhu.github.io/Gthulhu/#/node-policies](https://gthulhu.github.io/Gthulhu/#/node-policies)。

## Node Policies 與 Kubernetes Scheduling Policies 的差異

兩種 policy 主要差在 workload 的選取方式：

| Policy 類型 | Workload 選取方式 | 適用場景 |
| --- | --- | --- |
| Kubernetes scheduling policy | Namespace、labels、Pod/container identity | Kubernetes 管理的 workload |
| Node-level scheduling policy | Node identity + Linux task name | Host process、Docker workload、standalone vLLM、system service |

兩條路徑最後都會把 workload intent 轉成 node-local Linux task scheduling；差異在於目標 task 是怎麼被找到的。

## 前提條件

若要實際改變 CPU 排程行為，目標節點需要在 Linux 6.12+ 上啟用 `sched_ext`，並執行 Gthulhu scheduler path。

Manager 與該節點的 Decision Maker 也需要正常連線，Manager 才能產生 node scheduling intent 並傳送到目標節點。

Scheduler 設定可參考[安裝](installation.zh.md)與[載入 sched_ext 排程器](scx-loader.zh.md)。

## 透過 Web GUI 建立 Node Policy

在 Web GUI 中開啟 **Node Policies**，點選 **New Node Policy**。

表單包含：

- **Node Names**：以逗號分隔的精確 node name。對 standalone inference host 而言通常是最直接的選法。
- **Node Label Selectors**：當多個已註冊節點具有相同 role 或 hardware class 時，可依 label 選取。
- **DRA Selectors**：Kubernetes / DRA 環境可用的 device-based selection。Standalone vLLM 通常可以留空。
- **Command Regex**：用正規表示式比對 Linux task name，也就是 `comm`。
- **Priority**：控制匹配到的 task 是否套用 Gthulhu 的 boosting 行為。
- **Execution Time**：自訂 scheduling time slice，單位為 nanoseconds。

儲存 policy 後，Manager 會為符合條件的節點產生一筆或多筆 **Node Scheduling Intents**。

## Task Matching 是 TID-aware 的

Linux scheduler 排的是 task/thread，不只是 process leader。Gthulhu 因此會掃描：

```text
/proc/<tgid>/task/<tid>/comm
```

並對每一個 thread 的名稱獨立套用 `Command Regex`。

例如，一個 vLLM process 可能長這樣：

```text
/proc/3785998/comm               = python3.12
/proc/3785998/task/3786004/comm = EngineCore_DP0
/proc/3785998/task/3786005/comm = EngineCore_DP1
```

此時可以使用：

```regex
^EngineCore(_DP[0-9]+)?$
```

直接選到 latency-sensitive 的 vLLM worker threads，即使 process leader 的名稱只是 `python3.12`。

解析後的 strategy 會以匹配到的 **TID** 為 key。在 user-space scheduling 中，Gthulhu 會先找 exact TID strategy；找不到時才 fallback 到 TGID strategy。

!!! note
    請比對 `/proc/.../comm` 的值，不要直接拿 `ps` 顯示的完整 command line 或 `/proc/.../cmdline` 當作 regex 依據。

## Priority 與 Time Slice 語意

目前 Gthulhu 的語意是：

- `Priority > 0`：屬於 **boosting strategy**，匹配到的 task 在 user-space scheduler 中會獲得優先處理。
- `Priority == 0`：屬於 **non-boosting strategy**。在 user-space mode 下仍可設定 custom time slice，但不會因 policy 而跳到 run queue 前面。
- `Execution Time`：custom time slice，單位為 nanoseconds；實際效果取決於目前使用的 scheduler path。

例如：

```text
2,000,000 ns = 2 ms
20,000,000 ns = 20 ms
```

不要把 `Priority` 的數值直接理解成 Linux `nice` level。目前 user-space policy path 最重要的差異是 priority 是否大於 0。

!!! warning "Kernel mode 的 slice-only 行為"
    Kernel mode 目前沒有獨立的「normal priority + custom slice」狀態，因此 `Priority == 0` 的 slice-only policy 在 kernel mode 下不會產生排程效果。如果需要 slice-only 行為，請使用 Gthulhu user-space scheduler。

## 範例：DGX Spark 上的 Standalone vLLM

假設 vLLM 直接跑在名為 `dgx-spark-gb10` 的主機上，沒有放進 Kubernetes。

先確認實際 task name：

```bash
ps -eT -o pid,tid,comm,args | grep -E 'vllm|EngineCore'
```

也可以直接檢查特定 process：

```bash
for task in /proc/<PID>/task/*; do
  printf '%s ' "${task##*/}"
  cat "$task/comm"
done
```

接著建立例如以下 node policy：

| 欄位 | 範例 |
| --- | --- |
| Node Names | `dgx-spark-gb10` |
| Command Regex | `^EngineCore(_DP[0-9]+)?$` |
| Priority | `1` |
| Execution Time | `2000000` |

這個範例會 boost 匹配到的 EngineCore task，並套用 2 ms custom slice。

以上數值只是示例，不是所有 vLLM workload 都適用的固定最佳值。正式使用前應量測 throughput、TTFT/TPOT、scheduler wait time 與整體 CPU contention，再決定實際策略。

### 為什麼這對 vLLM 很重要

即使完全沒有 Kubernetes，Linux 仍然決定 vLLM CPU-side threads 什麼時候能取得 CPU。當主機有 CPU contention 時，engine、request-processing、tokenizer、networking 或 feeder thread 都可能被延遲，即使 GPU 本身仍有可用資源。

Node policy 讓 Gthulhu 可以直接保護特定 host thread，不需要為了取得 workload-aware scheduling 能力，先把 inference server 包進 Kubernetes。

## 透過 REST API 建立相同 Policy

Manager 提供 `/api/v1` 下的 node-policy API。

例如：

```bash
curl -X POST http://<manager>:8080/api/v1/node-scheduling-policies \
  -H 'Authorization: Bearer <token>' \
  -H 'Content-Type: application/json' \
  -d '{
    "nodeNames": ["dgx-spark-gb10"],
    "commandRegex": "^EngineCore(_DP[0-9]+)?$",
    "priority": 1,
    "executionTime": 2000000
  }'
```

常用的查詢 endpoint：

```text
GET /api/v1/node-scheduling-policies/self
GET /api/v1/node-scheduling-intents/self
```

Policy API 也支援 `nodeSelectors` 與 `draSelectors`，適合需要依 node label 或 device inventory 選節點，而不是直接指定 node name 的環境。

## 驗證 Policy 是否生效

儲存 policy 後，可在 Web GUI 的 **Node Scheduling Intents** 表格查看狀態。

Intent state 包含：

- **Pending**：已建立，但尚未送出；
- **Sent**：已送往目標節點；
- **Applied**：node-side path 已接受；
- **Failed**：policy 傳送或套用失敗。

對 vLLM policy 而言，也應確認 regex 真的匹配到預期的 TID。Policy 即使成功送到 node，如果 task name 沒有匹配，仍可能看不到預期的排程效果。

## Troubleshooting

### 沒有產生 Node Intent

請確認：

- node name 與 Gthulhu 註冊到的名稱完全一致；
- node label selector 至少能解析到一個節點；
- Decision Maker 已註冊且可連線。

### Intent 顯示 Applied，但 vLLM 行為沒有變化

請確認：

- `Command Regex` 是否真的匹配 `/proc/<tgid>/task/<tid>/comm`；
- 該節點是否已啟用 Gthulhu scheduler；
- workload 是否真的受到 CPU contention 影響；
- 目前使用的是預期的 user-space / kernel scheduler mode；
- kernel mode 下是否誤用了 `Priority == 0` 的 slice-only policy。

### Policy 匹配到太多 task

請盡可能縮小 regex 範圍。Node-level policy 可以直接影響任意 host process，因此像 `.*` 這種過寬的規則可能連其他系統服務一起匹配。

建議先從一組明確可辨識的 vLLM worker thread 開始，驗證結果後再逐步擴大範圍。

## 相關文件

- [運作原理](how-it-works.zh.md) — TID-aware matching、TID-first lookup、priority semantics 與 scheduler internals。
- [載入 sched_ext 排程器](scx-loader.zh.md) — 設定 node scheduler runtime。
- [透過 Web GUI 設定 Scheduling Policies](gui.zh.md) — Kubernetes-oriented scheduling policies。
- [Keeping vLLM Fast Under CPU Pressure](https://vllm-project-github-9ojnpu1yg-simon-mos-projects.vercel.app/2026/08/07/vllm-gthulhu.html) — Gthulhu 在 vLLM CPU contention 情境下的實驗案例。
