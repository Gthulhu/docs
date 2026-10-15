# Keeping vLLM Fast Under CPU Pressure with `sched_ext`

LLM serving is usually discussed as a GPU problem. In practice, however, a production inference node also depends on CPU time for tokenization, request handling, engine scheduling, kernel work, and GPU interrupt handling. Once those CPU-side paths compete with noisy neighbors, a fast GPU can spend more time waiting for the host to feed it work.

This post documents a Gthulhu experiment on a DGX Spark / GB10 system running vLLM under deliberate CPU contention. The goal was not to claim that Gthulhu universally makes vLLM several times faster. The narrower question was:

> If CPU contention is the bottleneck, can workload-aware CPU scheduling recover inference performance without changing the model or GPU configuration?

The answer from this experiment was yes.

## Why CPU scheduling matters for GPU inference

A vLLM deployment does not run in isolation. On a Kubernetes node, CPU time is shared with components such as `containerd`, kubelet, CNI agents, metrics collectors, sidecars, preprocessing jobs, and other colocated workloads.

vLLM itself also has CPU-sensitive paths:

- HTTP and streaming request handling;
- tokenization and preprocessing;
- `EngineCore` scheduling and kernel submission;
- worker and helper threads;
- host-side GPU interrupt handling.

When the host CPUs are saturated, Linux still has to decide which runnable tasks get serviced first. That makes CPU scheduling part of the inference pipeline even when the dominant computation happens on the GPU.

## Experiment setup

The test environment used:

- NVIDIA DGX Spark / GB10-class hardware;
- Linux 6.17;
- MicroK8s;
- vLLM serving `Qwen/Qwen2.5-0.5B-Instruct`;
- `stress-ng --cpu 16` to create sustained CPU pressure;
- Gthulhu on top of Linux `sched_ext`.

The contention is intentionally aggressive. It is designed to expose scheduling behavior rather than represent every production deployment.

Three scenarios were compared:

1. **Default Linux scheduler under CPU pressure**.
2. **Gthulhu scheduler under the same pressure**, without workload-specific tiering.
3. **Gthulhu with workload-aware policy**, prioritizing latency-sensitive inference work over background CPU load.

## Results

The stressed default-scheduler case reduced decode throughput to roughly **6.6 tokens/s** and increased TTFT to about **336 ms**.

Switching the node to the Gthulhu `sched_ext` scheduler raised decode throughput to roughly **18 tokens/s** and reduced TTFT to about **126 ms** in this specific setup.

Adding a workload-aware policy changed the trade-off again. For the longer decode case (`tg128`), throughput increased from about **17.5 tokens/s** to about **21.3 tokens/s**, roughly a **22% improvement** over the untuned Gthulhu case. TTFT rose to about **169 ms**, because the policy deliberately favored the decode hot path over front-end work.

| Scenario | Decode throughput (`tg128`) | TTFT |
| --- | ---: | ---: |
| Default scheduler + CPU pressure | ~6.6 tok/s | ~336 ms |
| Gthulhu | ~17.5 tok/s | ~126 ms |
| Gthulhu + workload policy | ~21.3 tok/s | ~169 ms |

The important result is not the headline multiplier. It is that the system was **CPU-scheduling constrained**, and changing how runnable host tasks were serviced recovered a large amount of lost inference throughput.

## Why `sched_ext` is useful here

Linux `sched_ext`, available in mainline Linux starting from 6.12, allows custom CPU scheduling policies to be implemented with BPF and loaded dynamically.

For this kind of experiment, that matters for two reasons.

First, it makes scheduler experimentation practical. We can test workload-aware scheduling without carrying a custom kernel patch or rebooting into a different kernel for each policy iteration.

Second, it gives Gthulhu a runtime control point below Kubernetes. Kubernetes decides where the Pod runs and what resources it receives; Gthulhu can then influence how the Linux tasks inside that workload are serviced once they are runnable.

That distinction is central to Gthulhu's direction: allocation and admission remain Kubernetes responsibilities, while runtime scheduling focuses on the execution behavior after placement.

## What the policy actually protects

The policy used in this experiment targeted CPU-side work associated with the inference critical path and deprioritized synthetic background load.

Conceptually, the desired ordering looked like this:

```text
GPU / latency-critical host work
        ↓
vLLM engine hot path
        ↓
platform / infrastructure work
        ↓
background CPU noise
```

The experiment also exposed an important limitation: optimizing one stage can move the bottleneck elsewhere.

The policy that improved long decode throughput also increased TTFT compared with the untuned Gthulhu case. That is expected when more CPU budget is directed toward decode while request-front-end work such as uvicorn or tokenization receives relatively less service.

So a useful production policy cannot simply assign one global priority to "vLLM". It needs to understand which threads matter for TTFT, prefill, decode, networking, and background maintenance, and then balance those objectives against each other.

## What this experiment does **not** prove

There are two boundaries worth making explicit.

### It does not prove a universal 3× vLLM speedup

The large recovery happened under a deliberately CPU-saturated scenario where the default scheduler was already performing poorly. If the workload is GPU-bound, memory-bound, or network-bound, changing the CPU scheduler may provide little or no improvement.

The result should therefore be read as:

> workload-aware scheduling can recover substantial performance when CPU contention is the actual bottleneck.

It should not be read as a general-purpose inference acceleration ratio.

### It does not yet prove dynamic scheduling is better than static pinning

Follow-up DGX Spark tests showed that static CPU placement can also recover much of the performance lost to CPU contention. In a two-node vLLM test, default scheduling under synthetic CPU pressure dropped decode throughput to about `17.51 ± 4.03 tok/s`, while pinning work to selected fast cores restored it to about `22.34 ± 1.39 tok/s`.

That means the next benchmark must be harder than "contention exists." It needs to test cases where the optimal placement changes over time: mixed-priority workloads, moving contention, phase changes, multiple colocated inference services, or runtime topology changes.

That is where dynamic scheduling should justify its complexity.

## Where Gthulhu goes next

This experiment was useful because it validated the basic premise: CPU scheduling can materially affect GPU inference when the host becomes the bottleneck.

The next step is not to repeat the same benchmark with a bigger model and claim a larger number. More useful experiments are:

- compare default scheduling, static pinning, and Gthulhu under the same workload;
- introduce contention that moves between CPU groups over time;
- separate TTFT, prefill, decode, and inter-token latency objectives;
- test multi-node serving where NCCL / RDMA progress threads compete for host CPU;
- use workload adapters to discover critical threads instead of relying on hand-written process matching;
- connect Kubernetes allocation and topology information to runtime policy through the Claim2Core path.

The broader idea is simple: GPU scheduling and CPU scheduling are not independent layers. A GPU workload still depends on host execution to keep the accelerator busy. When that host-side execution becomes noisy, Linux scheduling becomes part of the serving architecture.

## Related links

- [Gthulhu](https://github.com/Gthulhu/Gthulhu)
- [Gthulhu Claim2Core roadmap](https://github.com/Gthulhu/Gthulhu/issues/141)
- [Original vLLM community blog PR](https://github.com/vllm-project/vllm-project.github.io/pull/300)
- [Linux `sched_ext`](https://github.com/sched-ext/scx)
