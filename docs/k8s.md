# Deploying Gthulhu with Kubernetes

This document explains how to deploy the Gthulhu scheduler and API server in a Kubernetes environment.

## Prerequisites

- Complete the installation and setup of Microk8s, and ensure `kubectl` works properly.
- Enable Microk8s' built-in container registry. For details, see: [How to use the built-in registry](https://microk8s.io/docs/registry-built-in).
- Enable Microk8s RBAC functionality using `microk8s enable rbac`

## Building Gthulhu Docker Images

First, obtain the Gthulhu project source code:
```sh
$ git clone --recursive https://github.com/Gthulhu/Gthulhu.git
```

Next, refer to the [Gthulhu Installation Guide](https://gthulhu.github.io/docs/installation.en/) to complete the Gthulhu compilation.
After completion, use the following commands to build and push Docker images to the local Microk8s registry:

```sh
$ make image
$ cd api
$ make image
$ cd ..
$ docker push 127.0.0.1:32000/gthulhu-api:latest
$ docker push 127.0.0.1:32000/gthulhu:latest
```

## Deploying Gthulhu to Kubernetes

Next, use the following commands to deploy Gthulhu to the Kubernetes cluster:

```sh
$ cd chart
$ helm install gthulhu gthulhu
```

To use the official Gthulhu Docker images instead of the locally built ones, run:

```sh
helm install gthulhu gthulhu -f ./gthulhu/values-production.yaml
```

If no errors occur, you should be able to see that the Gthulhu pods have started successfully:

```sh
$ kubectl get po | grep gthulhu
gthulhu-manager-776784fcd9-sv79b                            2/2     Running   2 (32m ago)      33m
gthulhu-mongodb-0                                           2/2     Running   0                33m
gthulhu-scheduler-bb2qv                                     3/3     Running   1 (32m ago)      33m
```

Check the scheduler logs to confirm it's working properly:

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

If you can see logs similar to the above, it means Gthulhu is successfully running in the Kubernetes cluster.

!!! info "Learn More"
    The Helm chart provided by Gthulhu uses DaemonSet as the pod generator to ensure that each node runs a Gthulhu scheduler service.