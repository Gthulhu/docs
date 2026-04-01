<a href="https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu" target="_blank"><img src="https://img.shields.io/badge/CNCF%20Landscape-5699C6?style=for-the-badge&logo=cncf&label=cncf" alt="cncf landscape" /></a>

<a href="https://ebpf.io/applications/" target="_blank"><img src="https://img.shields.io/badge/eBPF%20Application%20Landscape-5699C6?style=for-the-badge&logo=ebpf&label=ebpf" alt="ebpf landscape" /></a>

[![LFX Health Score](https://insights.linuxfoundation.org/api/badge/health-score?project=gthulhu)](https://insights.linuxfoundation.org/project/gthulhu)

Welcome to the official website of Gthulhu — a cloud-native workload orchestration platform that provides granular, pod-level scheduling observability and automated scaling for Kubernetes workloads. Through an intuitive web GUI, users can monitor fine-grained scheduling metrics collected via eBPF and configure automatic scaling policies powered by KEDA. For clusters running Linux 6.12+ with `sched_ext`, Gthulhu further supports kernel-level custom CPU scheduling.

[📝 Share Your Case Study](https://docs.google.com/forms/d/e/1FAIpQLSeT9Ia1iigu45DDbPgfqijWIN7-Ewkm6-AbTc-HsjyHMvBjCA/viewform?usp=publish-editor){: .md-button .md-button--primary }

## 📰 Latest News

!!! success "Gthulhu joins CNCF Landscape"
    Gthulhu is now part of the [CNCF (Cloud Native Computing Foundation) Landscape](https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu), joining the ecosystem of cloud-native technologies.

!!! success "Gthulhu joins eBPF Application Landscape"
    Gthulhu has been added to the [eBPF Application Landscape](https://ebpf.io/applications/), recognized as an innovative eBPF-based scheduling solution.

## Overview

Gthulhu is a cloud-native workload orchestration platform that provides granular, pod-level scheduling observability and automated scaling for Kubernetes workloads — all without modifying the kernel or application code.

<iframe width="560" height="315" src="https://www.youtube.com/embed/0n7i4RDSy90?si=r2kAHvF8e7WGTDEY" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

### Key Capabilities

- **Pod-Level Scheduling Metrics** — Gthulhu uses eBPF to hook into kernel scheduling events (`fentry`/`fexit`), collecting per-process metrics such as voluntary/involuntary context switches, CPU time, wait time, run count, and CPU migrations. These metrics are aggregated at the pod level and exposed via REST APIs.
- **Declarative Configuration** — Users define which workloads to monitor using Kubernetes label selectors and namespaces, either through the web GUI or the `PodSchedulingMetrics` CRD.
- **KEDA Auto-Scaling Integration** — Gthulhu provides out-of-the-box integration with [KEDA](https://keda.sh/), enabling auto-scaling decisions driven by real scheduling behavior rather than generic resource utilization.
- **Advanced: Scheduling Strategies & Intents** *(requires Linux 6.12+ with `sched_ext`)* — Users can define scheduling strategies (priority, time-slice, CPU affinity) for specific workloads via the web GUI or REST API. The Manager converts strategies into scheduling intents and distributes them to Decision Makers on each node, enabling cross-node coordinated scheduling policy enforcement.
- **Advanced: Custom CPU Scheduling** *(requires Linux 6.12+ with `sched_ext`)* — On nodes running a supported kernel, Gthulhu attaches a custom eBPF-based CPU scheduler through the `sched_ext` mechanism, applying the scheduling intents at the kernel level — including priority-based dispatching, dynamic time-slice tuning, and preemption control — without modifying the kernel itself.

### Why Gthulhu?

The default Linux kernel scheduler emphasizes fairness and cannot be optimized for the specific needs of individual applications. Cloud-native workloads — trading systems, big data analytics, ML training — all have different scheduling requirements. Gthulhu bridges this gap by:

1. **Making scheduling visible** — exposing kernel-level scheduling behavior as actionable metrics
2. **Making scaling smarter** — driving auto-scaling from actual scheduling pressure, not just CPU/memory averages
3. **Making scheduling tunable** (advanced) — allowing per-workload CPU scheduling policies on supported kernels

### Architecture Overview

To enable users to easily transform their intents into scheduling and monitoring policies, Gthulhu provides an intuitive web GUI and REST API. Behind these interfaces, several key components work together:

#### 1\. Gthulhu API Server (Manager Mode)

The Manager accepts policy requests from users and transforms them into specific scheduling intents. It also manages `PodSchedulingMetrics` CRD configurations for metrics collection.

```bash
$ curl -X POST http://localhost:8080/api/v1/strategies \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{            
    "strategyNamespace": "default",
    "labelSelectors": [
      {"key": "app.kubernetes.io/name", "value": "prometheus"}
    ],
    "k8sNamespace": ["default"],
    "priority": 10,
    "executionTime": 20000000
  }'
```

The example above demonstrates how to send a scheduling policy request to the Gthulhu API Server using the curl command. Upon receiving the request, the Manager attempts to select Pods from the Kubernetes cluster that match the label selectors and adjusts the scheduling policies for these Pods based on the specified priority and execution time.

#### 2\. Gthulhu API Server (Decision Maker Mode)

The Decision Maker runs as a DaemonSet on each node in the cluster. It attaches eBPF programs to kernel scheduling hooks to collect per-process metrics in real time, and identifies target Process(es) based on scheduling intents sent by the Manager.

#### 3\. eBPF Metrics Collector

Each Decision Maker includes an eBPF metrics collector that hooks into kernel scheduling events (`fentry`/`fexit`) to collect fine-grained, per-process scheduling metrics. These metrics are aggregated at the pod level and exported to Prometheus, enabling Grafana dashboards and KEDA-driven auto-scaling.

#### 4\. Gthulhu Scheduler *(Advanced — requires Linux 6.12+ with sched_ext)*

On nodes with a supported kernel, the Gthulhu Scheduler can be activated to apply custom CPU scheduling policies at the kernel level. It can be further divided into two parts:

- **Gthulhu Agent**: Responsible for interacting with the Linux Kernel's sched_ext framework and applying scheduling decisions (priority-based dispatching, dynamic time-slice tuning, and preemption control).
- **Qumun Framework**: Provides the underlying eBPF code and related tools, ensuring that the Gthulhu Agent can efficiently communicate with the Linux kernel.

The diagram below illustrates the overall architecture of Gthulhu:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             Gthulhu Architecture                                 │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   ┌──────────────┐        ┌──────────────────────┐        ┌─────────────────┐    │
│   │    User      │──────▶ │      Manager         │──────▶ │    MongoDB      │    │
│   │  (Web GUI)   │        │ (Central Management) │        │  (Persistence)  │    │
│   └──────────────┘        └──────────┬───────────┘        └─────────────────┘    │
│                                      │                                           │
│                      ┌───────────────┼───────────────┐                           │
│                      │               │               │                           │
│                      ▼               ▼               ▼                           │
│           ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                     │
│           │Decision Maker│ │Decision Maker│ │Decision Maker│  (DaemonSet)        │
│           │   (Node 1)   │ │   (Node 2)   │ │   (Node N)   │                     │
│           └──────┬───────┘ └──────┬───────┘ └──────┬───────┘                     │
│                  │                │                │                              │
│          ┌───────┴───────┐ ┌──────┴───────┐ ┌─────┴────────┐                     │
│          ▼               ▼ ▼              ▼ ▼              ▼                      │
│   ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐                    │
│   │eBPF Metrics│ │ sched_ext  │ │eBPF Metrics│ │ sched_ext  │                    │
│   │ Collector  │ │ Scheduler* │ │ Collector  │ │ Scheduler* │                    │
│   └──────┬─────┘ └────────────┘ └──────┬─────┘ └────────────┘                    │
│          │                              │                                        │
│          ▼                              ▼               ┌─────────────────┐       │
│   ┌────────────────────────────────────────────┐        │      KEDA       │       │
│   │       Prometheus / Grafana Dashboards      │───────▶│  (Auto-Scaler)  │       │
│   └────────────────────────────────────────────┘        └─────────────────┘       │
│                                                                                  │
│   * sched_ext scheduler requires Linux 6.12+ (advanced feature)                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

**How it works:**

1. Users select Kubernetes workloads through the **Web GUI** (or `PodSchedulingMetrics` CRD) and define monitoring/scheduling policies.
2. The **Manager** persists configurations, queries pods via the Kubernetes API (Informer), and distributes intents to Decision Makers.
3. Each **Decision Maker** (deployed as a DaemonSet) runs on every node and attaches eBPF programs to kernel scheduling hooks to collect per-process metrics in real time.
4. Metrics are aggregated at the pod level and exported to **Prometheus**, enabling Grafana dashboards and **KEDA**-driven auto-scaling.
5. On nodes with Linux 6.12+ and `sched_ext` support, the advanced **custom scheduler** can be activated for priority-based dispatching and time-slice tuning.

## DEMO

Click the link below to watch our DEMO on YouTube!

<iframe width="560" height="315" src="https://www.youtube.com/embed/Cyjrh9cW1a8?si=0TL20Cd084wEoEVv" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

<iframe width="560" height="315" src="https://www.youtube.com/embed/MfU64idQcHg?si=HAdQLQU1NaoQEbkf" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## License

This project is licensed under the **Apache License 2.0**.

## Community & Support

- **GitHub**: [Gthulhu](https://github.com/Gthulhu/Gthulhu) | [Qumun](https://github.com/Gthulhu/scx_goland_core)
- **Issue Reporting**: Please report issues on GitHub Issues
- **Feature Requests**: Welcome to submit Pull Requests or open Issues for discussion
- **Media Coverage**: Check out [Media Coverage & Mentions](mentioned.md) to see project impact

---

## Next Steps

- 📖 Read [How It Works](how-it-works.md) to understand the technical details
- 🎯 Check out [Project Goals](project-goals.md) to learn about the development direction
- 📜 Browse [Development History](development-history.md) to understand technical challenges and solutions
- 🛠️ Refer to [API Documentation](api-reference.md) for development
