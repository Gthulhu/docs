<a href="https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu" target="_blank"><img src="https://img.shields.io/badge/CNCF%20Landscape-5699C6?style=for-the-badge&logo=cncf&label=cncf" alt="cncf landscape" /></a>

<a href="https://ebpf.io/applications/" target="_blank"><img src="https://img.shields.io/badge/eBPF%20Application%20Landscape-5699C6?style=for-the-badge&logo=ebpf&label=ebpf" alt="ebpf landscape" /></a>

[![LFX Health Score](https://insights.linuxfoundation.org/api/badge/health-score?project=gthulhu)](https://insights.linuxfoundation.org/project/gthulhu)

# Gthulhu

Gthulhu helps platform teams understand, automate, and tune Linux scheduling for Kubernetes workloads.

It starts with safe, pod-level scheduling observability powered by eBPF. From there, teams can connect those signals to Prometheus, Grafana, and KEDA for scaling decisions that reflect real scheduler pressure. On Linux 6.12+ clusters with `sched_ext`, Gthulhu can also apply workload-aware CPU scheduling policies at the kernel boundary.

[Get Started](k8s.md){: .md-button .md-button--primary }
[How It Works](how-it-works.md){: .md-button }
[Share Your Case Study](https://docs.google.com/forms/d/e/1FAIpQLSeT9Ia1iigu45DDbPgfqijWIN7-Ewkm6-AbTc-HsjyHMvBjCA/viewform?usp=publish-editor){: .md-button }

## Why Gthulhu?

Kubernetes schedules pods onto nodes, but the Linux kernel still decides when each process runs on CPU. That last-mile behavior is often invisible, even when it is the reason a workload is waiting, migrating, or missing latency goals.

Gthulhu closes that gap:

- **See scheduling pressure** — collect per-process scheduler signals and aggregate them into pod-level metrics.
- **Scale from scheduler reality** — feed Prometheus and KEDA with wait time, runtime, context switches, and CPU migration signals instead of relying only on CPU averages.
- **Configure workloads declaratively** — select pods through the Web UI, REST API, or `PodSchedulingMetrics` CRD.
- **Tune critical workloads** — apply priority and time-slice policies through `sched_ext` when supported by the node kernel.
- **Operate across clusters** — use a Manager plus per-node Decision Makers to turn workload intent into node-local action.

## What You Can Do

### Observe Every Workload

Gthulhu attaches eBPF programs to Linux scheduling events and turns raw process activity into Kubernetes-aware metrics. You can track whether a pod is waiting for CPU, moving across CPUs, or spending time in scheduler contention.

### Automate Smarter Scaling

Scheduling behavior is often a better scaling signal than coarse resource utilization. Gthulhu exports metrics to Prometheus so KEDA can scale workloads based on real pressure observed at the kernel level.

### Apply Scheduling Intent

For advanced environments, Gthulhu lets teams define scheduling strategies for selected workloads. The Manager resolves Kubernetes intent, Decision Makers map it to node-local processes, and the scheduler applies policies such as priority and custom time slices.

### Keep the Kernel Untouched

The base monitor runs with eBPF on BTF-enabled Linux kernels and does not require kernel patches. The optional scheduler uses Linux `sched_ext`, so teams can experiment with custom scheduling policies without maintaining a custom kernel.

## Architecture at a Glance

```
User / Web UI / CRD
        │
        ▼
Manager API ───────▶ MongoDB
        │
        ▼
Decision Maker DaemonSet
        │
        ├── eBPF scheduling metrics collector ──▶ Prometheus / Grafana / KEDA
        │
        └── sched_ext scheduler integration ───▶ Linux kernel scheduler path
```

The Manager owns users, RBAC, strategy APIs, and cluster-wide intent. Decision Makers run on each node, discover matching pod processes, expose node-local PID strategies, collect metrics, and forward runtime configuration to the local Gthulhu daemon. The daemon can run in monitor-only mode or enable the advanced scheduler when configured.

Read the full data flow in [How It Works](how-it-works.md).

## Demo

<iframe width="560" height="315" src="https://www.youtube.com/embed/0n7i4RDSy90?si=r2kAHvF8e7WGTDEY" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

<iframe width="560" height="315" src="https://www.youtube.com/embed/Cyjrh9cW1a8?si=0TL20Cd084wEoEVv" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

<iframe width="560" height="315" src="https://www.youtube.com/embed/MfU64idQcHg?si=HAdQLQU1NaoQEbkf" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## Latest News

!!! success "Gthulhu joins CNCF Landscape"
    Gthulhu is part of the [CNCF Landscape](https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu), alongside cloud-native infrastructure projects.

!!! success "Gthulhu joins eBPF Application Landscape"
    Gthulhu is listed in the [eBPF Application Landscape](https://ebpf.io/applications/) as an eBPF-based scheduling and observability project.

## Next Steps

- [Deploy Gthulhu with Kubernetes](k8s.md)
- [Understand the architecture](how-it-works.md)
- [Configure pod scheduling metrics](pod-metrics.md)
- [Explore the API reference](api-reference.md)

## Community

- **GitHub**: [Gthulhu](https://github.com/Gthulhu/Gthulhu) | [Qumun](https://github.com/Gthulhu/scx_goland_core)
- **Issues**: Report bugs or request features through GitHub Issues.
- **License**: Apache License 2.0.
