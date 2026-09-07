# Node-Level Scheduling Policies

Gthulhu can apply scheduling policies directly to Linux tasks on a selected node, without requiring the workload to be represented by a Kubernetes Pod.

This is useful for workloads such as:

- standalone or Docker-based vLLM servers;
- systemd services and host daemons;
- local inference runtimes on DGX Spark / GB10 systems;
- other processes that need workload-aware CPU scheduling but are not managed by Kubernetes.

A node-level policy selects one or more nodes, matches Linux tasks by their `comm` name, and assigns a Gthulhu scheduling strategy to the matched tasks.

!!! tip "Try the live mock"
    The Web GUI mock includes a Node Policies page at [gthulhu.github.io/Gthulhu/#/node-policies](https://gthulhu.github.io/Gthulhu/#/node-policies).

## Node Policies vs Kubernetes Scheduling Policies

The two policy paths solve different selection problems:

| Policy type | Selects workload by | Best fit |
| --- | --- | --- |
| Kubernetes scheduling policy | Namespace, labels, Pod/container identity | Workloads managed by Kubernetes |
| Node-level scheduling policy | Node identity plus Linux task name | Host processes, Docker workloads, standalone vLLM, system services |

Both paths eventually resolve workload intent into node-local Linux task scheduling. The main difference is how the target task is discovered.

## Prerequisites

To change CPU scheduling behavior, the target node must run the Gthulhu scheduler path on Linux 6.12+ with `sched_ext` support enabled.

The Manager and the node-local Decision Maker must also be connected so the Manager can generate a node scheduling intent and deliver it to the selected node.

See [Installation](installation.md) and [Loading sched_ext schedulers](scx-loader.md) for scheduler setup.

## Creating a Node Policy from the Web GUI

Open **Node Policies** from the Web GUI and click **New Node Policy**.

The form contains the following fields:

- **Node Names**: exact node names, separated by commas. For a standalone inference host, this is usually the simplest selector.
- **Node Label Selectors**: select nodes by labels when multiple registered nodes share the same role or hardware class.
- **DRA Selectors**: optional device-based selection for Kubernetes/DRA-aware environments. Standalone vLLM users can normally leave this empty.
- **Command Regex**: regular expression matched against the Linux task name (`comm`).
- **Priority**: controls whether the matched task receives Gthulhu's boosting behavior.
- **Execution Time**: custom scheduling time slice, in nanoseconds.

After the policy is saved, the Manager generates one or more **Node Scheduling Intents** for the nodes selected by the policy.

## Task Matching Is TID-Aware

Linux schedules tasks/threads, not only process leaders. Gthulhu therefore scans thread entries under:

```text
/proc/<tgid>/task/<tid>/comm
```

and applies `Command Regex` to each thread name independently.

For example, a vLLM process may look like this:

```text
/proc/3785998/comm               = python3.12
/proc/3785998/task/3786004/comm = EngineCore_DP0
/proc/3785998/task/3786005/comm = EngineCore_DP1
```

A policy using:

```regex
^EngineCore(_DP[0-9]+)?$
```

can therefore target the latency-sensitive vLLM worker threads even when the process leader itself is only named `python3.12`.

The resolved strategy is keyed by the matched **TID**. In user-space scheduling, an exact TID strategy is checked first and a TGID strategy is used as a fallback.

!!! note
    Match the value in `/proc/.../comm`, not the full command line from `ps` or `/proc/.../cmdline`.

## Priority and Time-Slice Semantics

Current Gthulhu semantics are:

- `Priority > 0`: the strategy is **boosting**. The matching task receives priority treatment in the user-space scheduler.
- `Priority == 0`: the strategy is **non-boosting**. In user-space mode, it can still apply a custom time slice without jumping the run queue.
- `Execution Time`: the custom time slice in nanoseconds, where supported by the active scheduler path.

For example:

```text
2,000,000 ns = 2 ms
20,000,000 ns = 20 ms
```

Do not treat the numeric priority value as a general-purpose Linux `nice` level. In the current Gthulhu user-space policy path, the important distinction is whether the priority value is greater than zero.

!!! warning "Kernel-mode slice-only behavior"
    Kernel mode currently does not have a separate normal-priority custom-slice state. A `Priority == 0` slice-only policy therefore has no scheduling effect in kernel mode. Use the user-space Gthulhu scheduler when you need slice-only behavior.

## Example: Standalone vLLM on DGX Spark

Assume vLLM is running directly on a host named `dgx-spark-gb10`, outside Kubernetes.

First, inspect the actual task names:

```bash
ps -eT -o pid,tid,comm,args | grep -E 'vllm|EngineCore'
```

You can also verify a specific process directly:

```bash
for task in /proc/<PID>/task/*; do
  printf '%s ' "${task##*/}"
  cat "$task/comm"
done
```

Then create a node policy such as:

| Field | Example |
| --- | --- |
| Node Names | `dgx-spark-gb10` |
| Command Regex | `^EngineCore(_DP[0-9]+)?$` |
| Priority | `1` |
| Execution Time | `2000000` |

This example boosts the matching EngineCore tasks and gives them a 2 ms custom slice.

The values above are an example, not a universal vLLM tuning recommendation. Measure throughput, TTFT/TPOT, scheduler wait time, and system contention before deciding on production values.

### Why this matters for vLLM

Kubernetes is not involved in this setup, but Linux still decides when vLLM's CPU-side threads run. Under CPU contention, the CPU-side engine, request-processing, tokenizer, networking, or feeder threads can be delayed even if the GPU itself is available.

Node policies let Gthulhu protect selected host threads directly instead of requiring users to wrap the inference server in Kubernetes only to gain access to workload-aware scheduling.

## Creating the Same Policy through the REST API

The Manager exposes node-policy APIs under `/api/v1`.

Example:

```bash
curl -X POST http://<manager>:8080/api/v1/node-scheduling-policies \
  -H 'Authorization: Bearer <token>' \
  -H 'Content-Type: application/json' \
  -d '{
    "nodeNames": ["dgx-spark-gb10"],
    "commandRegex": "^EngineCore(_DP[0-9]+)?$",
    "priority": 1,
    "executionTime": 2000000
  }'
```

Useful read endpoints include:

```text
GET /api/v1/node-scheduling-policies/self
GET /api/v1/node-scheduling-intents/self
```

The policy API also supports `nodeSelectors` and `draSelectors` for environments where node selection should be driven by labels or device inventory rather than an exact node name.

## Verifying the Policy

After saving a policy, check the **Node Scheduling Intents** table in the Web GUI.

Intent states are:

- **Pending**: created but not yet delivered;
- **Sent**: sent toward the target node;
- **Applied**: accepted by the node-side path;
- **Failed**: policy delivery or application failed.

For a vLLM policy, also verify that the regex actually matches the intended TIDs. A policy can be delivered successfully but still be ineffective if the task names do not match what the workload is currently using.

## Troubleshooting

### No node intent is generated

Check that:

- the node name exactly matches the node registered with Gthulhu;
- the node label selectors resolve at least one node;
- the Decision Maker is registered and reachable.

### Intent is Applied but vLLM behavior does not change

Check that:

- `Command Regex` matches `/proc/<tgid>/task/<tid>/comm`;
- the Gthulhu scheduler is enabled on that node;
- the workload is actually CPU-contention-sensitive;
- the policy is using the expected user-space or kernel scheduler mode;
- `Priority == 0` is not being used as a slice-only policy in kernel mode.

### The policy matches too many tasks

Use the narrowest possible regex. Node-level policies can target arbitrary host processes, so a broad expression such as `.*` may affect unrelated services on the machine.

Start with one identifiable vLLM worker thread family, verify the result, and expand the policy only when necessary.

## Related Documentation

- [How It Works](how-it-works.md) — TID-aware matching, TID-first lookup, priority semantics, and scheduler internals.
- [Loading sched_ext schedulers](scx-loader.md) — configure the node scheduler runtime.
- [Configuring Scheduling Policies via Web GUI](gui.md) — Kubernetes-oriented scheduling policies.
- [Keeping vLLM Fast Under CPU Pressure](https://vllm-project-github-9ojnpu1yg-simon-mos-projects.vercel.app/2026/08/07/vllm-gthulhu.html) — an example of Gthulhu applied to vLLM under CPU contention.
