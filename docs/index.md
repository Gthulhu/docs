<a href="https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu" target="_blank"><img src="https://img.shields.io/badge/CNCF%20Landscape-5699C6?style=for-the-badge&logo=cncf&label=cncf" alt="cncf landscape" /></a>
<a href="https://ebpf.io/applications/" target="_blank"><img src="https://img.shields.io/badge/eBPF%20Application%20Landscape-5699C6?style=for-the-badge&logo=ebpf&label=ebpf" alt="ebpf landscape" /></a>

[![LFX Health Score](https://insights.linuxfoundation.org/api/badge/health-score?project=gthulhu)](https://insights.linuxfoundation.org/project/gthulhu)

# Gthulhu

## Protect critical workloads from CPU contention

Gthulhu uses eBPF and Linux `sched_ext` to make workload scheduling observable and controllable across Kubernetes nodes.

**Measured results under CPU contention:**

| Workload | Baseline | With Gthulhu | Result |
|---|---:|---:|---:|
| free5GC / GTP data path — average UE ping latency | **88.98 ms** | **2.079 ms** | **97.66% lower** |
| free5GC / GTP data path — maximum UE ping latency | **130.95 ms** | **8.45 ms** | **93.55% lower** |
| vLLM Qwen2.5-0.5B decode (`tg128`) under CPU pressure | **~6.7 t/s** | **~21.3 t/s** with tiered policy | **~3.2× throughput** |

The free5GC numbers are published in the free5GC community blog. The vLLM result comes from a reproducible community benchmark currently proposed to the vLLM project blog; treat it as an experiment under upstream review rather than a project-wide guarantee.

[Read the free5GC case study](https://free5gc.org/blog/20251126/20251126/){: .md-button .md-button--primary }
[vLLM benchmark PR](https://github.com/vllm-project/vllm-project.github.io/pull/300){: .md-button }
[Get Started](k8s.md){: .md-button }

> **DRA chooses what and where; Gthulhu controls how it actually runs.**

## Why this matters

A workload can already own a GPU, NIC, CPU set, or Kubernetes placement and still miss its latency or throughput target because its host-side Linux tasks are delayed by CPU contention.

Gthulhu focuses on that execution gap:

```text
Kubernetes admission / placement / allocation
                    │
                    ▼
             Gthulhu runtime plane
                    │
       Pod / cgroup / TGID / TID resolution
                    │
                    ▼
               sched_ext + eBPF
                    │
                    ▼
       latency / throughput / jitter / SLO
```

## Proven use cases

### 5G user-plane latency

The free5GC community published a GTP-driven scheduling experiment that combines `gtp5g-tracer`, a userspace operator, and Gthulhu. Under the same CPU stress, average UE ping latency dropped from **88.98 ms to 2.079 ms**, while maximum latency dropped from **130.95 ms to 8.45 ms**.

[Read: Implementing GTP-driven Automatic Scheduling Optimization with eBPF-based Scheduler](https://free5gc.org/blog/20251126/20251126/)

A separate earlier free5GC case study also documents using Gthulhu to reduce RTT by combining application/domain knowledge with custom `sched_ext` policy.

[Read: Improving Network Performance with Custom eBPF-based Schedulers](https://free5gc.org/blog/20250726/index.en/)

### vLLM inference under CPU pressure

A reproducible DGX Spark / GB10 experiment uses MicroK8s, vLLM, `stress-ng`, and Gthulhu to isolate the effect of CPU scheduling on GPU inference. In the submitted benchmark, decode throughput under CPU pressure is around **6–7 t/s** with the default scheduler and reaches roughly **21 t/s** on `tg128` with Gthulhu plus tiered policies targeting GPU-related work and vLLM's `EngineCore` thread.

This result is linked here as an **upstream-reviewing community benchmark**, not as a generalized performance guarantee.

[Review the benchmark and methodology in vLLM blog PR #300](https://github.com/vllm-project/vllm-project.github.io/pull/300)

## What Gthulhu provides today

- **Pod-level scheduling observability** with eBPF.
- **Prometheus / Grafana / KEDA integration** for scheduler-aware operations and scaling.
- **Distributed scheduling intent** through a Manager and per-node Decision Makers.
- **Custom CPU scheduling** on Linux 6.12+ with `sched_ext`.
- **TID-aware node-policy matching** so non-leader worker threads can be targeted directly.
- **Explicit priority semantics** across user-space and kernel scheduler modes.

[How It Works](how-it-works.md){: .md-button }
[Claim2Core Roadmap](claim2core.md){: .md-button }

## Claim2Core: from allocation to delivered performance

The next architecture step is to connect actual Kubernetes allocation to runtime task scheduling:

```text
Kueue / Workload API
        │ admission / quota
        ▼
kube-scheduler / DRA
        │ Node + device + topology allocation
        ▼
Gthulhu Runtime Plane
        │ ResourceClaim → Pod/cgroup → TGID/TID
        ▼
sched_ext + eBPF
        │ runtime policy + verification
        ▼
Delivered workload SLO
```

The critical correctness rule is:

- `ResourceSlice` is **inventory**.
- `ResourceClaim.status.allocation` is the workload's **actual allocation**.

Gthulhu should not reimplement kube-scheduler, DRA, or Kueue. It should consume their decisions and control Linux CPU execution **inside** the resource envelope established by Kubernetes/cgroups.

Read [Claim2Core](claim2core.md) for the implementation phases and safety boundaries.

## Architecture at a glance

```text
User / Web UI / CRD
        │
        ▼
Manager API ───────▶ MongoDB / Kubernetes API
        │
        ▼
Decision Maker DaemonSet
        │
        ├── eBPF scheduling metrics collector ──▶ Prometheus / Grafana / KEDA
        │
        └── task resolution / scheduling intent
                         │
                         ▼
                   Gthulhu daemon
                         │
                         ▼
                    sched_ext / BPF
                         │
                         ▼
                   Linux scheduler
```

## Get involved

- [Deploy Gthulhu with Kubernetes](k8s.md)
- [Understand the architecture and scheduler semantics](how-it-works.md)
- [Read the Claim2Core roadmap](claim2core.md)
- [Contribute](contributing.md)
- [GitHub repository](https://github.com/Gthulhu/Gthulhu)
- [Roadmap issue #141](https://github.com/Gthulhu/Gthulhu/issues/141)
