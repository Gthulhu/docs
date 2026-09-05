<a href="https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu" target="_blank"><img src="https://img.shields.io/badge/CNCF%20Landscape-5699C6?style=for-the-badge&logo=cncf&label=cncf" alt="cncf landscape" /></a>
<a href="https://ebpf.io/applications/" target="_blank"><img src="https://img.shields.io/badge/eBPF%20Application%20Landscape-5699C6?style=for-the-badge&logo=ebpf&label=ebpf" alt="ebpf landscape" /></a>

[![LFX Health Score](https://insights.linuxfoundation.org/api/badge/health-score?project=gthulhu)](https://insights.linuxfoundation.org/project/gthulhu)

# Gthulhu

> **DRA chooses what and where; Gthulhu controls how it actually runs.**

Gthulhu is a cloud-native runtime scheduling platform that connects Kubernetes workload intent to Linux task scheduling with eBPF and `sched_ext`.

Kubernetes can admit a workload, place it on a node, and allocate devices/topology. Gthulhu focuses on the execution gap that follows: identify the Linux tasks that belong to the workload, apply bounded CPU scheduling policy, and verify whether the allocation is actually delivering the workload SLO.

[Get Started](k8s.md){: .md-button .md-button--primary }
[How It Works](how-it-works.md){: .md-button }
[Claim2Core Roadmap](claim2core.md){: .md-button }

## Current Capabilities

- **Pod-level scheduling observability** with eBPF.
- **Prometheus / Grafana / KEDA integration** for scheduler-aware operations and scaling.
- **Distributed scheduling intent** through a Manager and per-node Decision Makers.
- **Custom CPU scheduling** on Linux 6.12+ with `sched_ext`.
- **TID-aware node-policy matching** so non-leader worker threads can be targeted directly.
- **Explicit priority semantics** across user-space and kernel scheduler modes.

## Claim2Core Direction

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

## Why This Matters

Allocated resources do not automatically become delivered performance. A workload may own a GPU or NIC while its host-side feeder, tokenizer, NCCL/RDMA progress, DPDK, or packet-processing threads are still delayed by CPU contention.

Gthulhu makes this gap observable and controllable.

Immediate validation paths include:

- **CPU DRA × Gthulhu × free5GC/UPF** for p99/p99.9 latency and jitter;
- **GPU + RDMA + CPU DRA × phase-aware LLM scheduling** for TTFT, ITL, GPU idle, and communication progress.

## Architecture at a Glance

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

## Recent Scheduler Semantics

Node-policy matching is thread-aware. The Decision Maker scans `/proc/<tgid>/task/<tid>` so a policy can target a named non-leader worker thread rather than only the process leader.

Priority handling is also explicit:

- `Priority > 0` means boost;
- `Priority == 0` is non-boosting;
- user-space mode supports TID-first lookup with TGID fallback;
- kernel mode does not insert non-boosting strategies into the priority BPF map, avoiding accidental priority-0 promotion.

See [How It Works](how-it-works.md) for the details and current limitations.

## Demo

<iframe width="560" height="315" src="https://www.youtube.com/embed/Cyjrh9cW1a8?si=0TL20Cd084wEoEVv" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## Next Steps

- [Deploy Gthulhu with Kubernetes](k8s.md)
- [Understand the architecture and current scheduler semantics](how-it-works.md)
- [Read the Claim2Core roadmap](claim2core.md)
- [Configure pod scheduling metrics](pod-metrics.md)
- [Contribute](contributing.md)

## Community

- **GitHub**: [Gthulhu/Gthulhu](https://github.com/Gthulhu/Gthulhu)
- **Roadmap**: [Issue #141](https://github.com/Gthulhu/Gthulhu/issues/141)
- **Framework**: [Gthulhu/qumun](https://github.com/Gthulhu/qumun)
- **License**: Apache License 2.0
