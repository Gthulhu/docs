# 使用 Kubernetes 部署 Gthulhu

本篇文件介紹如何在 Kubernetes 環境中部署 Gthulhu 排程器以及 API server。

## 前提條件

- 完成 Microk8s 的安裝與設定，並確保 `kubectl` 可正常使用。
- 啟用 Microk8s 內建的 container registry，詳情請參考：[How to use the built-in registry](https://microk8s.io/docs/registry-built-in)。
- 使用 `microk8s enable rbac` 啟用 Microk8s 的 RBAC 功能

## 建立 Gthulhu Docker 映像檔

首先，取得 Gthluhu 專案的原始程式碼：
```sh
$ git clone --recursive https://github.com/Gthulhu/Gthulhu.git
```

接著，參考 [Gthulhu 安裝文件](https://gthulhu.github.io/docs/installation.en/) 完成 Gthulhu 的編譯。
完成後，使用以下命令編譯並推送 Docker 映像檔到本地的 Microk8s registry：

```sh
$ make image
$ cd api
$ make image
$ cd ..
$ docker push 127.0.0.1:32000/gthulhu-api:latest
$ docker push 127.0.0.1:32000/gthulhu:latest
```

## 部署 Gthulhu 到 Kubernetes

接下來，使用以下命令將 Gthulhu 部署到 Kubernetes 叢集：

```sh
$ cd chart
$ helm install gthulhu gthulhu
```

若沒有出現任何錯誤，使用以下命令理應可以看到 Gthulhu 的 Pod 已成功啟動：

```sh
$ kubectl get po | grep gthulhu
gthulhu-api-72ts9                              1/1     Running   0              9s
gthulhu-scheduler-lph8h                        1/1     Running   0              9s
```

查看 scheduler 的日誌，確認其運作正常：

```sh
$ kubectl logs gthulhu-scheduler-lph8h
2025/09/22 13:15:09 Scheduler config: SLICE_NS_DEFAULT=5000000, SLICE_NS_MIN=500000
2025/09/22 13:15:09 Debug mode enabled
2025/09/22 13:15:09 Early processing disabled
libbpf: struct_ops goland: member priv not found in kernel, skipping it as it's set to zero
map: cpu_ctx_stor, type: BPF_MAP_TYPE_PERCPU_ARRAY, fd: 3
map: task_ctx_stor, type: BPF_MAP_TYPE_TASK_STORAGE, fd: 7
map: queued, type: BPF_MAP_TYPE_RINGBUF, fd: 8
map: dispatched, type: BPF_MAP_TYPE_USER_RINGBUF, fd: 9
map: priority_tasks, type: BPF_MAP_TYPE_HASH, fd: 10
map: running_task, type: BPF_MAP_TYPE_HASH, fd: 11
map: usersched_timer, type: BPF_MAP_TYPE_ARRAY, fd: 12
map: main_bpf.rodata, type: BPF_MAP_TYPE_ARRAY, fd: 13
map: .data.uei_dump, type: BPF_MAP_TYPE_ARRAY, fd: 14
map: main_bpf.data, type: BPF_MAP_TYPE_ARRAY, fd: 15
map: main_bpf.bss, type: BPF_MAP_TYPE_ARRAY, fd: 16
map: goland, type: BPF_MAP_TYPE_STRUCT_OPS, fd: 17
2025/09/22 13:15:09 Topology: map[L2:map[0-1:[0 1] 10-11:[10 11] 12-13:[12 13] 14-15:[14 15] 16-19:[16 17 18 19] 2-3:[2 3] 4-5:[4 5] 6-7:[6 7] 8-9:[8 9]] L3:map[0-19:[0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19]]]
2025/09/22 13:15:09 UserSched's Pid: 2716543
2025/09/22 13:15:09 API config: URL=http://gthulhu-api:80/api/v1/scheduling/strategies, Interval=5 seconds
2025/09/22 13:15:09 Started scheduling strategy fetcher with JWT authentication, interval 5 seconds
2025/09/22 13:15:09 scheduler started
2025/09/22 13:15:09 Failed to fetch initial scheduling strategies: failed to obtain JWT token: failed to send token request: Post "http://gthulhu-api:80/api/v1/auth/token": dial tcp 10.152.183.54:80: connect: connection refused
2025/09/22 13:15:14 Failed to fetch scheduling strategies: failed to obtain JWT token: failed to send token request: Post "http://gthulhu-api:80/api/v1/auth/token": dial tcp 10.152.183.54:80: connect: connection refused
2025/09/22 13:15:19 Failed to fetch scheduling strategies: failed to obtain JWT token: failed to send token request: Post "http://gthulhu-api:80/api/v1/auth/token": dial tcp 10.152.183.54:80: connect: connection refused
2025/09/22 13:15:19 bss data: {"usersched_last_run_at":3212826452599740,"nr_queued":0,"nr_scheduled":0,"nr_running":1,"nr_online_cpus":20,"nr_user_dispatches":90846,"nr_kernel_dispatches":5,"nr_cancel_dispatches":0,"nr_bounce_dispatches":0,"nr_failed_dispatches":0,"nr_sched_congested":0}
2025/09/22 13:15:19 Failed to send metrics: failed to send metrics request: failed to obtain JWT token: failed to send token request: Post "http://gthulhu-api:80/api/v1/auth/token": dial tcp 10.152.183.54:80: connect: connection refused
2025/09/22 13:15:24 Failed to fetch scheduling strategies: failed to obtain JWT token: failed to send token request: Post "http://gthulhu-api:80/api/v1/auth/token": dial tcp 10.152.183.54:80: connect: connection refused
2025/09/22 13:15:29 Failed to fetch scheduling strategies: failed to obtain JWT token: failed to send token request: Post "http://gthulhu-api:80/api/v1/auth/token": dial tcp 10.152.183.54:80: connect: connection refused
2025/09/22 13:15:29 bss data: {"usersched_last_run_at":3212826452599740,"nr_queued":1,"nr_scheduled":0,"nr_running":2,"nr_online_cpus":20,"nr_user_dispatches":174142,"nr_kernel_dispatches":9,"nr_cancel_dispatches":0,"nr_bounce_dispatches":0,"nr_failed_dispatches":0,"nr_sched_congested":0}
2025/09/22 13:15:29 Failed to send metrics: failed to send metrics request: failed to obtain JWT token: failed to send token request: Post "http://gthulhu-api:80/api/v1/auth/token": dial tcp 10.152.183.54:80: connect: connection refused
2025/09/22 13:15:34 Failed to fetch scheduling strategies: failed to obtain JWT token: failed to send token request: Post "http://gthulhu-api:80/api/v1/auth/token": dial tcp 10.152.183.54:80: connect: connection refused
2025/09/22 13:15:39 bss data: {"usersched_last_run_at":3212826452599740,"nr_queued":0,"nr_scheduled":0,"nr_running":2,"nr_online_cpus":20,"nr_user_dispatches":263151,"nr_kernel_dispatches":11,"nr_cancel_dispatches":0,"nr_bounce_dispatches":0,"nr_failed_dispatches":0,"nr_sched_congested":0}
2025/09/22 13:15:39 Successfully sent metrics to API server
2025/09/22 13:15:45 Scheduling strategies updated: 4 strategies
2025/09/22 13:15:45 Updated strategy map with 4 strategies
2025/09/22 13:15:45 Scheduling strategies updated: 4 strategies
2025/09/22 13:15:45 Updated strategy map with 4 strategies
2025/09/22 13:15:49 bss data: {"usersched_last_run_at":3212826452599740,"nr_queued":0,"nr_scheduled":0,"nr_running":9,"nr_online_cpus":20,"nr_user_dispatches":367610,"nr_kernel_dispatches":15,"nr_cancel_dispatches":0,"nr_bounce_dispatches":0,"nr_failed_dispatches":0,"nr_sched_congested":0}
2025/09/22 13:15:49 Successfully sent metrics to API server
2025/09/22 13:15:49 Scheduling strategies updated: 4 strategies
```

若能夠看到類似上述的日誌，表示 Gthulhu 已成功運行於 Kubernetes 叢集之中。

!!! info "深入了解"
    Gthulhu 提供的 helm chart 皆使用 DaemonSet 作為 pod generator，以此確保每個節點皆會運行一個 Gthulhu 排程器服務。