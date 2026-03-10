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
$ cd chart/gthulhu
$ helm install gthulhu . --set mtls.enabled=true --set-file mtls.ca.cert=certs/ca.crt --set-file mtls.dm.cert=certs/dm.crt --set-file mtls.dm.key=certs/dm.key --set-file mtls.manager.cert=certs/manager.crt --set-file mtls.manager.key=certs/manager.key
```

若要使用官方的 Gthulhu Docker 映像檔，而非本地編譯的版本，請執行：

```sh
$ helm install gthulhu . -f ./values-production.yaml --set mtls.enabled=true --set-file mtls.ca.cert=certs/ca.crt --set-file mtls.dm.cert=certs/dm.crt --set-file mtls.dm.key=certs/dm.key --set-file mtls.manager.cert=certs/manager.crt --set-file mtls.manager.key=certs/manager.key
```

若沒有出現任何錯誤，使用以下命令理應可以看到 Gthulhu 的 Pod 已成功啟動：

```sh
$ kubectl get po | grep gthulhu
gthulhu-manager-776784fcd9-sv79b                            2/2     Running   2 (32m ago)      33m
gthulhu-mongodb-0                                           2/2     Running   0                33m
gthulhu-scheduler-bb2qv                                     3/3     Running   1 (32m ago)      33m
```

查看 scheduler 的日誌，確認其運作正常：

```sh
$ kubectl logs gthulhu-scheduler-bb2qv
time=2026-01-28T04:16:13.992Z level=INFO msg="Scheduler configuration" SliceNsDefault=5000000 SliceNsMin=500000
time=2026-01-28T04:16:13.994Z level=INFO msg="Debug mode enabled"
time=2026-01-28T04:16:13.994Z level=INFO msg="Early processing disabled"
time=2026-01-28T04:16:14.040Z level=INFO msg="Failed to fetch initial scheduling strategies: failed to obtain JWT token: failed to send token request: Post \"http://localhost:8080/api/v1/auth/token\": dial tcp [::1]:8080: connect: connection refused"
libbpf: struct_ops goland: member cgroup_set_bandwidth not found in kernel, skipping it as it's set to zero
libbpf: struct_ops goland: member priv not found in kernel, skipping it as it's set to zero
map: cpu_ctx_stor, type: BPF_MAP_TYPE_PERCPU_ARRAY, fd: 6
map: task_ctx_stor, type: BPF_MAP_TYPE_TASK_STORAGE, fd: 7
map: queued, type: BPF_MAP_TYPE_RINGBUF, fd: 8
map: dispatched, type: BPF_MAP_TYPE_USER_RINGBUF, fd: 9
map: priority_tasks, type: BPF_MAP_TYPE_HASH, fd: 10
map: running_task, type: BPF_MAP_TYPE_HASH, fd: 11
map: usersched_timer, type: BPF_MAP_TYPE_ARRAY, fd: 12
map: main_bpf.rodata, type: BPF_MAP_TYPE_ARRAY, fd: 13
map: main_bpf.bss, type: BPF_MAP_TYPE_ARRAY, fd: 14
map: .data.uei_dump, type: BPF_MAP_TYPE_ARRAY, fd: 15
map: main_bpf.data, type: BPF_MAP_TYPE_ARRAY, fd: 16
map: goland, type: BPF_MAP_TYPE_STRUCT_OPS, fd: 17
time=2026-01-28T04:16:14.460Z level=INFO msg=Topology topology="map[L2:map[0-1:[0 1] 2-3:[2 3]] L3:map[0-3:[0 1 2 3]]]"
time=2026-01-28T04:16:14.491Z level=INFO msg="UserSched's Pid" pid=413219
time=2026-01-28T04:16:14.495Z level=INFO msg="scheduler started"
time=2026-01-28T04:16:14.495Z level=INFO msg="scheduler loop started"
time=2026-01-28T04:16:19.011Z level=INFO msg="Scheduling strategies updated: 0 strategies"
time=2026-01-28T04:16:19.498Z level=INFO msg="bss data" data="{\"nr_running\":52796,\"nr_queued\":1,\"nr_scheduled\":0,\"nr_online_cpus\":4,\"usersched_last_run_at\":4050881978519621,\"nr_user_dispatches\":15001,\"nr_kernel_dispatches\":0,\"nr_cancel_dispatches\":0,\"nr_bounce_dispatches\":0,\"nr_failed_dispatches\":0,\"nr_sched_congested\":0}"
time=2026-01-28T04:16:19.504Z level=INFO msg="Successfully sent metrics to API server"
time=2026-01-28T04:16:23.996Z level=INFO msg="Scheduling strategies updated: 0 strategies"
time=2026-01-28T04:16:24.495Z level=INFO msg="bss data" data="{\"nr_running\":112288,\"nr_queued\":1,\"nr_scheduled\":0,\"nr_online_cpus\":4,\"usersched_last_run_at\":4050881978519621,\"nr_user_dispatches\":31369,\"nr_kernel_dispatches\":5,\"nr_cancel_dispatches\":0,\"nr_bounce_dispatches\":0,\"nr_failed_dispatches\":0,\"nr_sched_congested\":0}"
time=2026-01-28T04:16:28.994Z level=INFO msg="Scheduling strategies updated: 0 strategies"
time=2026-01-28T04:16:29.495Z level=INFO msg="bss data" data="{\"nr_running\":169593,\"nr_queued\":3,\"nr_scheduled\":0,\"nr_online_cpus\":4,\"usersched_last_run_at\":4050881978519621,\"nr_user_dispatches\":46949,\"nr_kernel_dispatches\":5,\"nr_cancel_dispatches\":0,\"nr_bounce_dispatches\":0,\"nr_failed_dispatches\":0,\"nr_sched_congested\":0}"
time=2026-01-28T04:16:29.498Z level=INFO msg="Successfully sent metrics to API server"
time=2026-01-28T04:16:33.995Z level=INFO msg="Scheduling strategies updated: 0 strategies"
time=2026-01-28T04:16:34.495Z level=INFO msg="bss data" data="{\"nr_running\":227568,\"nr_queued\":1,\"nr_scheduled\":0,\"nr_online_cpus\":4,\"usersched_last_run_at\":4050881978519621,\"nr_user_dispatches\":63273,\"nr_kernel_dispatches\":7,\"nr_cancel_dispatches\":0,\"nr_bounce_dispatches\":0,\"nr_failed_dispatches\":0,\"nr_sched_congested\":0}"
```

若能夠看到類似上述的日誌，表示 Gthulhu 已成功運行於 Kubernetes 叢集之中。

!!! info "深入了解"
    Gthulhu 提供的 helm chart 皆使用 DaemonSet 作為 pod generator，以此確保每個節點皆會運行一個 Gthulhu 排程器服務。

## 檢查 Policy 與 Intent

![Static Badge](https://img.shields.io/badge/version-v1.0.0+-blue)

當你完成 Gthulhu 的部署，並且根據[使用 Web GUI 設定 scheduling policies](./gui.zh.md)順利設定 Scheduling Strategy 之後，你應該能夠透過 kubectl 查看 Gthulhu 所定義的 Custom Resource：
```
$ kubectl get schedulingstrategies.gthulhu.io -n gthulhu-system
NAME                       PRIORITY   CREATOR                    AGE
69afe18156b0ab11513bd8f2   10         696f39d9b12be8ecfe9a6dc5   40s
$ kubectl get schedulingintents.gthulhu.io -n gthulhu-system
NAME                       STRATEGY                   POD                                                         NODE    STATE   AGE
69afe18156b0ab11513bd8f3   69afe18156b0ab11513bd8f2   kube-prometheus-stack-grafana-567d665788-6k48v              myvm    2       51s
69afe18156b0ab11513bd8f4   69afe18156b0ab11513bd8f2   kube-prometheus-stack-prometheus-node-exporter-fdc7l        myvm    2       51s
69afe18156b0ab11513bd8f5   69afe18156b0ab11513bd8f2   kube-prometheus-stack-operator-9d4d68854-bfzzt              myvm    2       51s
69afe18156b0ab11513bd8f6   69afe18156b0ab11513bd8f2   kube-prometheus-stack-kube-state-metrics-7846957b5b-lllwj   myvm    2       51s
69afe18156b0ab11513bd8f7   69afe18156b0ab11513bd8f2   kube-prometheus-stack-prometheus-node-exporter-k8gg4        d11nn   2       51s
```

Gthulhu API Manager 利用 K8s 的 CRD 定義了 `schedulingstrategies.gthulhu.io` 與 `schedulingintents.gthulhu.io` 兩種資源，並且根據 `schedulingstrategies.gthulhu.io` 生成對應的 `schedulingintents.gthulhu.io`，使 Gthulhu Scheduler 能夠與 sidecar（Gthulhu decision maker）溝通，取得 Pod 背後對應的 PID(s) 與相關策略。