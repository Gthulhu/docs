# Blog

Technical articles, experiments, and project notes from the Gthulhu community.

<div class="grid cards" markdown>

-   :material-gauge:{ .lg .middle } **Fine-Tuning Gthulhu's Go User-Space Scheduler**

    ---

    How we traced stalled tasks and slow wakeups to ring-buffer handoffs, BPF dispatch ordering, Go runtime crossings, and CPU yielding—then passed the `adaptive_priority` benchmark.

    [:octicons-arrow-right-24: Read article](userspace-scheduler-optimization.md)


-   :material-brain:{ .lg .middle } **When Does CPU Scheduling Help AI Inference?**

    ---

    What our vLLM and DGX Spark experiments actually show about CPU contention, static pinning, `sched_ext`, and when host scheduling becomes part of the AI inference critical path.

    [:octicons-arrow-right-24: Read article](vllm-cpu-pressure.md)

-   :material-shield-lock:{ .lg .middle } **Hardening Gthulhu Network Security with Istio Ambient Mode**

    ---

    Reduce the blast radius of privileged scheduler components with Kubernetes NetworkPolicy, Istio Ambient, Waypoint, Gateway API, and L7 authorization.

    [:octicons-arrow-right-24: Read article](istio.md)

-   :material-network:{ .lg .middle } **Improving Network Performance with Custom eBPF-based Schedulers**

    ---

    An early Gthulhu case study on using eBPF-based CPU scheduling to improve networking workloads. Published on the free5GC community blog.

    [:octicons-arrow-right-24: Read on free5GC](https://free5gc.org/blog/20250726/index.en/)

-   :material-access-point-network:{ .lg .middle } **Implementing GTP-driven Automatic Scheduling Optimization with eBPF-based Scheduler**

    ---

    Explore how GTP-aware signals can drive automatic runtime scheduling decisions for 5G packet-processing workloads. Published on the free5GC community blog.

    [:octicons-arrow-right-24: Read on free5GC](https://free5gc.org/blog/20251126/20251126/)

</div>

## What we write about

Gthulhu sits between Kubernetes resource allocation and Linux task execution, so most articles focus on practical questions around:

- Linux `sched_ext` and eBPF scheduling;
- Kubernetes workload and topology awareness;
- AI / GPU inference host-side scheduling;
- networking and packet-processing workloads;
- runtime observability and scheduling policy;
- security and production hardening.

New experiments and project notes will be added here rather than making the top-level **Blog** navigation point directly to a single external article.
