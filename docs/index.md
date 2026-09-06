# Gthulhu

<div class="gth-hero" markdown>

## Keep critical workloads fast when CPUs get busy

Gthulhu is a cloud-native runtime scheduling platform built with eBPF and Linux `sched_ext`. It protects latency- and throughput-sensitive Linux tasks inside Kubernetes workloads when CPU contention would otherwise slow them down.

<div class="gth-hero-actions">
<a href="k8s.md" class="md-button md-button--primary">Get Started</a>
<a href="https://github.com/Gthulhu/Gthulhu" class="md-button">View on GitHub</a>
</div>

</div>

<div class="gth-proof-grid" markdown>

<div class="gth-proof-card" markdown>
<span class="gth-proof-eyebrow">free5GC / 5G user plane</span>

### 97.66% lower average latency

**88.98 ms → 2.079 ms** average UE ping latency under CPU stress.

Maximum latency also fell from **130.95 ms → 8.45 ms**.

[Read the published free5GC case study →](https://free5gc.org/blog/20251126/20251126/)
</div>

<div class="gth-proof-card" markdown>
<span class="gth-proof-eyebrow">vLLM / GPU inference</span>

### ~3.2× decode throughput

**~6.7 t/s → ~21.3 t/s** on `tg128` under CPU pressure with Gthulhu + tiered scheduling policy.

*Reproducible community benchmark currently under upstream vLLM blog review.*

[Review the benchmark and methodology →](https://github.com/vllm-project/vllm-project.github.io/pull/300)
</div>

</div>

<div class="gth-trust-row" markdown>
<a href="https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu" target="_blank"><img src="https://img.shields.io/badge/CNCF%20Landscape-5699C6?style=for-the-badge&logo=cncf&label=cncf" alt="cncf landscape" /></a>
<a href="https://ebpf.io/applications/" target="_blank"><img src="https://img.shields.io/badge/eBPF%20Application%20Landscape-5699C6?style=for-the-badge&logo=ebpf&label=ebpf" alt="ebpf landscape" /></a>
<a href="https://insights.linuxfoundation.org/project/gthulhu"><img src="https://insights.linuxfoundation.org/api/badge/health-score?project=gthulhu" alt="LFX Health Score" /></a>
</div>

## The problem Gthulhu solves

Kubernetes can place a workload on the right node and allocate the right resources. That still does not guarantee the workload's critical Linux threads will get CPU time when they need it.

Under contention, GPU feeder threads, `EngineCore`, packet-processing workers, IRQ-related work, or other latency-sensitive tasks can be delayed by background CPU load. The result is simple: **allocated resources, but missed SLOs**.

Gthulhu closes that execution gap.

<div class="gth-flow" markdown>

**1. Observe**  
Use eBPF to see which tasks are waiting, running, migrating, and competing for CPU.

**2. Target**  
Resolve Kubernetes workload intent down to the Linux process or thread that actually matters.

**3. Control**  
Use `sched_ext` to apply bounded runtime scheduling policy and protect critical execution paths.

</div>

> **DRA chooses what and where. Gthulhu controls how it actually runs.**

## Built for workload-aware runtime scheduling

<div class="grid cards" markdown>

-   :material-eye-outline:{ .lg .middle } **Scheduling observability**

    ---

    Pod-level scheduling metrics with eBPF, plus Prometheus and Grafana integration.

-   :material-tune-variant:{ .lg .middle } **Fine-grained control**

    ---

    Apply scheduling intent to specific workloads, processes, or non-leader worker threads with TID-aware matching.

-   :material-server-network:{ .lg .middle } **Cloud-native operation**

    ---

    Manager + per-node Decision Makers distribute scheduling intent across Kubernetes nodes.

-   :material-chart-line:{ .lg .middle } **SLO-oriented automation**

    ---

    Feed scheduler signals into Prometheus, Grafana, and KEDA to support runtime-aware operations and scaling.

</div>

[See how Gthulhu works](how-it-works.md){: .md-button }

## Where Gthulhu is going: Claim2Core

Today, Gthulhu can observe and control Linux task scheduling at runtime. The next step is to connect that control directly to Kubernetes' **actual resource allocation**.

```text
Kueue / Workload API
        ↓
kube-scheduler / DRA
        ↓  ResourceClaim + topology
Gthulhu Runtime Plane
        ↓  Pod / cgroup / TGID / TID
sched_ext + eBPF
        ↓
Delivered workload SLO
```

The principle is simple:

- `ResourceSlice` tells us what resources exist.
- `ResourceClaim.status.allocation` tells us what the workload actually received.
- Gthulhu turns that allocation into a verifiable runtime execution policy **without crossing the CPU/resource boundaries Kubernetes already established**.

[Explore the Claim2Core roadmap](claim2core.md){: .md-button }
[Follow roadmap issue #141](https://github.com/Gthulhu/Gthulhu/issues/141){: .md-button }

## Start with a real workload

<div class="gth-cta" markdown>

### See what CPU scheduling is doing to your workload

Deploy Gthulhu on Kubernetes, inspect scheduler behavior, then apply policy only where the data shows it matters.

[Deploy Gthulhu](k8s.md){: .md-button .md-button--primary }
[Read the free5GC case study](https://free5gc.org/blog/20251126/20251126/){: .md-button }
[Contribute](contributing.md){: .md-button }

</div>
