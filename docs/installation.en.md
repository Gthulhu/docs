# Installation Guide

This guide will help you install and set up Gthulhu and SCX GoLand Core on your system.

## System Requirements

### Hardware Requirements

- **CPU**: x86_64 architecture processor
- **Memory**: At least 2GB RAM
- **Storage**: At least 1GB available space

### Software Requirements

!!! warning "Kernel Version Requirement"
    **Linux kernel 6.12+ with sched_ext support** is mandatory. Please ensure your kernel version meets this requirement.

#### Required Packages

| Package | Version | Purpose |
|---------|---------|---------|
| Go | 1.22+ | User-space scheduler development |
| LLVM/Clang | 17+ | BPF program compilation |
| libbpf | Latest | BPF library |
| make | - | Build tools |
| git | - | Version control |

#### Check Kernel Support

```bash
# Check kernel version
uname -r

# Check sched_ext support
grep -r "CONFIG_SCHED_CLASS_EXT" /boot/config-$(uname -r) || \
cat /proc/config.gz | gunzip | grep "CONFIG_SCHED_CLASS_EXT"

# Check BPF support
grep -r "CONFIG_BPF" /boot/config-$(uname -r) | head -5
```

## Installation Steps

### Step 1: Install Dependencies

=== "Ubuntu/Debian"
    ```bash
    # Update package list
    sudo apt update
    
    # Install build tools
    sudo apt install -y build-essential git make
    
    # Install LLVM/Clang
    sudo apt install -y llvm-17 clang-17 libbpf-dev
    
    # Install Go (if not already installed)
    wget https://go.dev/dl/go1.22.6.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.22.6.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
    source ~/.zshrc
    ```

=== "CentOS/RHEL/Fedora"
    ```bash
    # Fedora
    sudo dnf install -y gcc make git
    sudo dnf install -y llvm clang libbpf-devel
    
    # CentOS/RHEL (requires EPEL)
    sudo yum install -y epel-release
    sudo yum install -y gcc make git
    sudo yum install -y llvm clang libbpf-devel
    
    # Install Go
    wget https://go.dev/dl/go1.22.6.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.22.6.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
    source ~/.zshrc
    ```

=== "Arch Linux"
    ```bash
    # Install basic tools
    sudo pacman -S base-devel git
    
    # Install LLVM/Clang and libbpf
    sudo pacman -S llvm clang libbpf
    
    # Install Go
    sudo pacman -S go
    ```

### Step 2: Clone the Project

```bash
# Clone main project
git clone https://github.com/Gthulhu/Gthulhu.git
cd Gthulhu

# Or, if you want to use SCX GoLand Core separately
git clone https://github.com/Gthulhu/scx_goland_core.git
cd scx_goland_core
```

### Step 3: Set Up Dependencies

```bash
# Set up dependencies
make dep

# Initialize and update git submodules
git submodule init
git submodule sync
git submodule update

# Enter scx directory and compile
cd scx
meson setup build --prefix ~
meson compile -C build
cd ..
```

!!! tip "Submodules Explanation"
    The project uses git submodules to manage libbpf and custom libbpfgo fork. These are essential components for the project to function properly.

### Step 4: Build the Project

```bash
# Run complete build
make build
```

The build process includes:

1. **Compile BPF Program** (`main.bpf.c` → `main.bpf.o`)
2. **Build libbpf Library**
3. **Generate BPF Skeleton** (`main.skeleton.h`)
4. **Compile Go Application**

### Step 5: Verify Installation

```bash
# Check build results
ls -la main
file main

# Check BPF object file
ls -la main.bpf.o
file main.bpf.o

# Check Go modules
go version
go mod verify
```

## Testing Installation

### Virtual Environment Testing

If you want to test the scheduler in a virtual environment:

```bash
# Use vng (Virtual Kernel Playground) for testing
make test
```

### Basic Functionality Test

```bash
# Test on current system (requires root privileges)
sudo ./main &

# Check if scheduler is running
ps aux | grep main

# Check if BPF program is loaded
sudo bpftool prog list | grep sched

# Stop scheduler
sudo pkill -f "./main"
```

## Docker Installation

If you prefer using Docker:

```bash
# Build Docker image
make image

# Run scheduler container
docker run --privileged=true --pid host --rm gthulhu:latest /gthulhu/main
```

!!! warning "Permission Requirements"
    Since the scheduler needs to load BPF programs and modify kernel scheduling behavior, it requires `--privileged=true` and `--pid host` permissions.

## Troubleshooting

### Compilation Errors

??? question "libbpf not found"
    ```bash
    # Verify libbpf path
    find /usr -name "libbpf.so*" 2>/dev/null
    
    # Set environment variables
    export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
    export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
    ```

??? question "Clang version mismatch"
    ```bash
    # Check Clang version
    clang --version
    
    # If multiple versions exist, specify clang-17
    export CC=clang-17
    export CXX=clang++-17
    ```

??? question "BPF program loading failed"
    ```bash
    # Check kernel BPF support
    cat /proc/sys/kernel/unprivileged_bpf_disabled
    
    # Check sched_ext support
    ls /sys/kernel/sched_ext/ 2>/dev/null || echo "sched_ext not supported"
    
    # View detailed error messages
    sudo dmesg | tail -20
    ```

### Runtime Issues

??? question "Permission denied"
    The scheduler requires root privileges to load BPF programs:
    ```bash
    sudo ./main
    ```

??? question "Kernel doesn't support sched_ext"
    Please ensure your kernel version is 6.12+ and was compiled with `CONFIG_SCHED_CLASS_EXT` enabled.

## Next Steps

After installation, you can:

- 📖 Read [How It Works](how-it-works.en.md) to understand the scheduler mechanisms
- 🎯 Check [Project Goals](project-goals.en.md) to understand the design philosophy
- 🔧 Refer to [API Documentation](api-reference.en.md) for custom development

---

!!! success "Installation Complete"
    Congratulations! You have successfully installed the Gthulhu scheduler. If you encounter any issues, please check the [FAQ](faq.en.md) or submit an issue on GitHub.
