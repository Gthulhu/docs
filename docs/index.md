<a href="https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu" target="_blank"><img src="https://img.shields.io/badge/CNCF%20Landscape-5699C6?style=for-the-badge&logo=cncf&label=cncf" alt="cncf landscape" /></a>

<img src="https://raw.githubusercontent.com/Gthulhu/Gthulhu/main/assets/logo.png" width="250" alt="LOGO">

Welcome to the official documentation for **Gthulhu** and **SCX GoLand Core** - advanced Linux schedulers designed to optimize cloud-native workloads using the Linux Scheduler Extension (sched_ext) framework.

## 📰 Latest News

!!! success "Gthulhu joins CNCF Landscape"
    Gthulhu is now part of the [CNCF (Cloud Native Computing Foundation) Landscape](https://landscape.cncf.io/?item=provisioning--automation-configuration--gthulhu), joining the ecosystem of cloud-native technologies.

!!! success "Gthulhu joins eBPF Application Landscape"
    Gthulhu has been added to the [eBPF Application Landscape](https://ebpf.io/applications/), recognized as an innovative eBPF-based scheduling solution.



## Overview
Gthulhu is a next-generation scheduler designed for the cloud-native ecosystem, built with Golang and powered by the qumun framework.

The name Gthulhu is inspired by Cthulhu, a mythical creature known for its many tentacles. Just as tentacles can grasp and steer, Gthulhu symbolizes the ability to take the helm and navigate the complex world of modern distributed systems — much like how Kubernetes uses a ship’s wheel as its emblem.

The prefix “G” comes from Golang, the language at the core of this project, highlighting both its technical foundation and its developer-friendly design.

Underneath, Gthulhu runs on the qumun framework (qumun means “heart” in the Bunun language, an Indigenous people of Taiwan), reflecting the role of a scheduler as the beating heart of the operating system. This not only emphasizes its central importance in orchestrating workloads but also shares a piece of Taiwan’s Indigenous culture with the global open-source community.

## Inspiration
The project is inspired by the Andrea Righi's talk "Crafting a Linux kernel scheduler in Rust". So I spent sometime to re-implement the scx_rustland, which is called qumun (scx_goland). After I done all of infrastructure setup, I redefine the project's mission, I make Gthulhu to be a generic scheduling solution dedicated to cloud-native workloads.

## What it does
Gthulhu simplfies the transformation from user's intents to scheduling policies. User can use machine friendly language (e.g. json) or use AI agent with MCP to communicate with Gthulhu, then Gthulhu will optimize specific workloads based on what you gave!

## DEMO

Click the image below to see our DEMO on YouTube!

[![IMAGE ALT TEXT HERE](https://github.com/Gthulhu/Gthulhu/raw/main/assets/preview.png){ width="200" }](https://www.youtube.com/watch?v=MfU64idQcHg)

## Product Roadmap

```mermaid
timeline
        title Gthulhu 2025 Roadmap
        section 2025 Q1 - Q2 <br> Gthulhu -- bare metal 
          scx_goland (qumun) : ☑️  7x24 test : ☑️  CI/CD pipeline
          Gthulhu : ☑️  CI/CD pipeline : ☑️  Official doc
          K8s integration : ☑️  Helm chart support : ☑️  API Server
        section 2025 Q3 - Q4 <br> Cloud-Native Scheduling Solution
          Gthulhu : ☑️ plugin mode : ☑️  Running on Ubuntu 25.04
          K8s integration : ☑️  Container image release : ☑️  MCP tool : Multiple node management system
          Release 1 : ☑️  R1 DEMO (free5GC) : ☑️  R1 DEMO (MCP) : R1 DEMO (Agent Builder)
```

## Architecture

```mermaid
graph TB
    A[User Applications] --> B[Linux Kernel]
    B --> C[sched_ext Framework]
    C --> D[BPF Scheduler Program]
    D --> E[User Space Scheduler]
    E --> F[Go Scheduling Logic]
    F --> G[SCX GoLand Core]
    
    subgraph "Kernel Space"
        B
        C
        D
    end
    
    subgraph "User Space"
        E
        F
        G
    end
```

## Key Features

### 🚀 Performance Optimizations

- **Virtual Runtime (vruntime) Based Scheduling**: Fair scheduling with low latency
- **Latency-Sensitive Task Prioritization**: Automatic detection and prioritization of interactive workloads
- **Dynamic Time Slice Adjustment**: Adaptive time slice allocation based on workload characteristics
- **CPU Topology Aware Task Placement**: Cache-aware task assignment for optimal performance
- **Automatic Idle CPU Selection**: Intelligent CPU selection algorithms

### ☁️ Cloud-Native Features

- **Container Awareness**: Understanding of container boundaries and resource limits
- **Microservice Optimization**: Reduced inter-service communication latency
- **Elastic Scaling Support**: Dynamic resource allocation capabilities
- **Multi-Tenant Isolation**: Fair resource sharing between different tenants

### 🔧 Developer-Friendly

- **User-Space Extensibility**: Custom scheduling policies without kernel modifications
- **Rich Debugging Tools**: Comprehensive monitoring and debugging capabilities
- **Complete Documentation**: From beginner to advanced developer guides
- **Active Community**: Open and welcoming developer community

## Quick Start

### Prerequisites

- Linux kernel 6.12+ with sched_ext support
- Go 1.22+
- LLVM/Clang 17+
- libbpf

### Installation

```bash
# Clone the repository
git clone https://github.com/Gthulhu/Gthulhu.git
cd Gthulhu

# Set up dependencies
make dep
git submodule init && git submodule update

# Build the scheduler
make build

# Run the scheduler (requires root)
sudo ./main
```

### Docker Quick Start

```bash
# Build Docker image
make image

# Run in container
docker run --privileged=true --pid host --rm gthulhu:latest /gthulhu/main
```

## Use Cases

### 🎮 Interactive Applications

Perfect for applications requiring low latency and smooth user experience:

- Desktop environments
- Gaming applications  
- Real-time multimedia
- Video conferencing

### 🏢 Enterprise Workloads

Optimized for business-critical applications:

- Web servers and APIs
- Database systems
- Application servers
- Batch processing

### 🔬 High-Performance Computing

Designed for compute-intensive workloads:

- Scientific computing
- Data analytics
- Machine learning training
- Simulation workloads


## System Requirements

### Minimum Requirements

- **OS**: Linux with kernel 6.12+
- **Architecture**: x86_64
- **Memory**: 2GB RAM
- **Storage**: 1GB available space

## Community

### Get Involved

- 💬 **Discussions**: [GitHub Discussions](https://github.com/Gthulhu/Gthulhu/discussions)
- 🐛 **Issues**: [GitHub Issues](https://github.com/Gthulhu/Gthulhu/issues)
- 📧 **Contact**: [Project Maintainers](mailto:maintainers@gthulhu.dev)
- 📰 **Media Coverage**: Check out [Media Coverage & Mentions](mentioned.en.md) to see project impact

### Contributing

We welcome contributions! See our [Contributing Guide](contributing.en.md) to get started.

### License

This software is distributed under the terms of the GNU General Public License version 2.

---

!!! tip "Getting Started"
    New to Gthulhu? Start with our [Installation Guide](installation.en.md) and learn [How It Works](how-it-works.en.md).

!!! info "Learn More"
    Explore the [Development History](development-history.en.md) to understand technical challenges and solutions.

!!! info "Need Help?"
    Check our [FAQ](faq.en.md) for common questions or create an issue on GitHub.
