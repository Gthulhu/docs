# Claim2Core

> **DRA chooses what and where; Gthulhu controls how it actually runs.**

Claim2Core is the Gthulhu roadmap for connecting Kubernetes resource allocation to Linux task scheduling.

The core problem is simple: **allocated resources do not automatically become delivered performance**.

A workload may receive a GPU, NIC, CPU set, NUMA domain, or other device and still miss its latency/throughput target because its host-side Linux tasks are delayed, placed poorly, or starved by CPU contention.

## Responsibility Boundary

```text
Kueue / Workload API
  admission, quota, fair sharing
            │
            ▼
kube-scheduler / DRA
  Node + device + topology allocation
            │
            ▼
Gthulhu Runtime Plane
  Claim → Pod/cgroup → TGID/TID
            │
            ▼
sched_ext + eBPF
  runtime policy + verification
            │
            ▼
Delivered workload SLO
```

| Layer | Typical timescale | Core question |
|---|---:|---|
| Kueue / workload admission | seconds → minutes | Can this workload start now? |
| kube-scheduler / DRA | milliseconds → seconds | Which Node/device/topology does it get? |
| Gthulhu / `sched_ext` | microseconds → milliseconds | Which workload threads run when and on which CPUs? |

## Source of Truth

The important correctness distinction is:

- `ResourceSlice` = **inventory**;
- `ResourceClaim.status.allocation` = **actual allocation**.

The target lineage is:

```text
Workload / PodGroup UID
  → Pod UID
  → ResourceClaim UID + generation
  → allocated driver / pool / device
  → NUMA / PCIe / network topology
  → Pod cgroup
  → TGID / TID / starttime
  → sched_ext DSQ / BPF-map entry
  → runtime metrics
  → workload SLO
```

## Implementation Order

### 1. Correct DRA semantics

- use modern `resource.k8s.io/v1` semantics;
- handle all supported ResourceSlice node-selection forms;
- separate DeviceClass from driver identity;
- keep inventory and allocation code paths clearly separate.

Tracking: [Gthulhu/Gthulhu#133](https://github.com/Gthulhu/Gthulhu/issues/133)

### 2. Read-only ResourceClaim observer

Observe allocated claims and build workload-to-device binding without changing scheduler behavior.

The observer should maintain identities such as:

```go
type ClaimDeviceBinding struct {
    ClaimUID        types.UID
    ClaimGeneration int64
    PodUID          types.UID
    NodeName        string
    Driver          string
    Pool            string
    Device          string
    NUMANodes       []int
    PCIeRoot        string
    PCIBusID        string
}
```

Kubernetes API state belongs in the control/update path. Microsecond-level scheduling must use node-local cached state.

### 3. Claim-to-Task preview and provenance

Before writing scheduler state, Gthulhu should be able to explain:

```text
Claim → Pod → cgroup → TGID/TID/starttime → proposed runtime policy
```

The preview path must be read-only and should expose matched tasks, conflicts, warnings, policy generation, and intended-vs-actual runtime state.

Tracking: [Gthulhu/Gthulhu#134](https://github.com/Gthulhu/Gthulhu/issues/134)

The TID-aware groundwork is already merged in [Gthulhu/Gthulhu#135](https://github.com/Gthulhu/Gthulhu/pull/135).

### 4. Static DRAExecutionPolicy

The user should express portable intent instead of raw scheduler internals.

Example direction:

```yaml
apiVersion: scheduling.gthulhu.io/v1alpha1
kind: DRAExecutionPolicy
metadata:
  name: llm-decode
spec:
  workloadSelector:
    matchLabels:
      llm-d.ai/role: decode
  resourceClaims:
    - gpu
    - rdma
    - cpu
  topology:
    respectAllocatedCPUSet: true
    preferSameNUMA: true
    preferSamePCIeRoot: true
  taskRoles:
    - name: decode
      selector:
        registeredRole: decode
      executionClass: latency-critical
  safety:
    requirePreview: true
    maxBoostDuration: 30s
    failClosedOnStaleClaim: true
    fallback: default-scheduler
```

The controller compiles this intent into concrete DSQ / slice / weight / locality decisions based on the allocated cpuset and topology.

### 5. One workload adapter

Prove the model on one workload before attempting generic automatic classification.

Two high-value paths:

- **CPU DRA × Gthulhu × free5GC/UPF** — fastest credible end-to-end validation;
- **GPU + RDMA + CPU DRA × LLM phase-aware scheduling** — highest research upside.

Task-role discovery should mature in this order:

1. explicit role hint;
2. workload-specific adapter;
3. eBPF/uprobes/activity-based classification with confidence.

### 6. Closed-loop runtime controller

Only after static policy and provenance are trustworthy should Gthulhu adapt policy from runtime signals.

Start with bounded, explainable rules, not unconstrained ML/RL.

## Correctness Invariants

Claim2Core needs correctness properties, not just benchmark wins.

- Claim deallocation must not leave stale policy that can affect a future task.
- TID reuse must not cause an old `(TID, starttime)` policy to affect a new task.
- Generation rollback must not resurrect invalid execution state.
- Policy generation must be monotonic.
- Actual BPF state must not contain unexplained extra entries.
- DRA/cgroup cpuset is a hard boundary.
- Decision Maker restart must reconstruct only currently valid state.

## Experimental Methodology

Do not compare only `default scheduler vs Gthulhu`.

Use a 2×2 design:

| Group | DRA topology-aware allocation | Gthulhu runtime scheduling |
|---|---|---|
| A | off | off |
| B | on | off |
| C | off | on |
| D | on | on |

This separates allocation benefit, runtime scheduling benefit, and interaction between them.

### Example KPIs

**LLM**: TTFT, ITL, tokens/s, GPU idle gap.

**5G/UPF**: p50/p95/p99/p99.9 RTT, jitter, packet loss.

**Runtime**: runnable-to-running latency, context switches, CPU/NUMA migrations, device-local CPU time, scheduler apply latency.

**Safety**: background slowdown, starvation duration, stale BPF entries, task reuse correctness, restart recovery, rollback latency.

## Hard Boundaries

- Gthulhu is **not a GPU scheduler**. It schedules Linux CPU tasks, not CUDA kernels, GPU SMs, MIG, or NIC hardware queues.
- ResourceClaim/ResourceSlice API calls do **not** belong in the microsecond scheduler hot path.
- CPU DRA/cgroups/kubelet define the allowed CPU envelope; Gthulhu optimizes only inside it.
- Multi-tenant policy must be bounded, scoped, auditable, and deterministic.

## Roadmap Discussion

The living roadmap is [Gthulhu/Gthulhu#141](https://github.com/Gthulhu/Gthulhu/issues/141).
