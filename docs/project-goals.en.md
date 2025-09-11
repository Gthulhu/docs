# Project Goals

This page introduces the design philosophy, development objectives, and future vision of the Gthulhu and SCX GoLand Core projects.

## Project Vision

Inspired by scx_rustland, [Ian](https://github.com/ianchen0119) rebuilt this eBPF-based scheduler using Golang and named it Gthulhu.  
Gthulhu aims to be a flexible and efficient CPU scheduler. Regular users can optimize application latency or throughput through configuration. For advanced developers, Gthulhu provides a plugin mechanism, allowing custom scheduling strategies to be implemented in user space and decisions to be delivered to the Linux Kernel via eBPF programs. This enables the Linux scheduler to better adapt to the demands of modern workloads.

## Development Principles

1. Stay in sync with scx: scx is a scheduler extension framework in the Linux Kernel. Gthulhu will continue to follow scx’s development to ensure compatibility with the latest Kernel versions. Moreover, Gthulhu leverages the power of the community to make scheduler implementations easier to share and reuse.
2. As permissive licensing as possible: Gthulhu uses GPL only where necessary, while other parts adopt the more permissive Apache license, allowing developers greater freedom to use and modify the code.
3. Easy to extend and customize: Gthulhu is designed with various application scenarios in mind, providing multiple configuration options and a plugin mechanism so users can tailor scheduling strategies to their needs.
4. Cloud-native oriented: Gthulhu focuses on supporting cloud-native applications, especially containerized workloads, and integrates seamlessly with container orchestration platforms such as Kubernetes.

## Target Application Scenarios

1. Low-latency applications: Gthulhu can optimize the performance of low-latency applications, such as communication systems [[1]](https://www.youtube.com/watch?v=MfU64idQcHg), games, and financial trading systems.
2. High-throughput workloads: Gthulhu supports high-throughput workloads, such as big data processing and machine learning tasks, ensuring these applications can fully utilize system resources.
3. Multi-node distributed systems: Gthulhu can coordinate resource allocation in multi-node distributed systems, improving overall system performance and stability.

---

!!! quote "Project Mission"
    We believe that through continuous technological innovation and open community collaboration, Gthulhu will become an important force in the Linux scheduler field, providing better performance and experience for modern applications.

!!! tip "Contributing"
    If you share our goals and vision, you are welcome to join our developer community! See the [Contribution Guide](contributing.md) to learn how to participate in project development.