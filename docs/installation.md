# Installation Guide

This guide helps you install and configure Gthulhu and Qumun.

## System Requirements

### Hardware Requirements

- CPU: x86_64 architecture processor
- Memory: At least 4GB RAM
- Storage: At least 10GB free space

### Software Requirements

!!! warning "Kernel Version Requirement"
    Linux Kernel 6.12+ with sched_ext enabled is required. Please make sure your kernel meets this requirement.

#### Required Packages

| Package | Version Requirement | Purpose |
|--------|---------------------|---------|
| Go | 1.22+ | User-space scheduler development |
| LLVM/Clang | 17+ | BPF program compilation |
| libbpf | Latest | BPF library |
| make | - | Build tool |
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

## Distribution-Specific Installation

Choose your Linux distribution below for detailed installation instructions.

### Ubuntu 25.04

To save time, we skip kernel compilation/installation and use Ubuntu 25.04 which directly supports sched_ext:
https://canonical.com/blog/canonical-releases-ubuntu-25-04-plucky-puffin

#### Install Dependencies

```bash
sudo apt-get update
sudo apt-get install --yes bsdutils
sudo apt-get install --yes build-essential
sudo apt-get install --yes pkgconf
sudo apt-get install --yes llvm-17 clang-17 clang-format-17
sudo apt-get install --yes libbpf-dev libelf-dev libzstd-dev zlib1g-dev
sudo apt-get install --yes virtme-ng
sudo apt-get install --yes gcc-multilib
sudo apt-get install --yes systemtap-sdt-dev
sudo apt-get install --yes python3 python3-pip ninja-build
sudo apt-get install --yes libseccomp-dev protobuf-compiler
sudo apt-get install --yes meson cmake
sudo apt-get install --yes cargo
```

#### Configure Clang

```bash
for tool in "clang" "clang-format" "llc" "llvm-strip"
do
  sudo rm -f /usr/bin/$tool
  sudo ln -s /usr/bin/$tool-17 /usr/bin/$tool
done
```

#### Install Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### openSUSE Tumbleweed

openSUSE Tumbleweed provides rolling updates and supports kernel 6.12+ with sched_ext.

#### Install Dependencies

```bash
# Update package repository
sudo zypper refresh

# Install build tools and compilers
sudo zypper install -y gcc make cmake meson ninja pkg-config rust cargo

# Install LLVM/Clang 18+ (minimum required: 17)
sudo zypper install -y llvm18 clang18 clang18-devel

# Install development libraries
sudo zypper install -y libbpf-devel libelf-devel libzstd-devel zlib-devel

# Install additional build dependencies
sudo zypper install -y systemtap-sdt-devel libseccomp-devel jq protobuf-devel

# Install static libraries for static linking
sudo zypper install -y zlib-devel-static libzstd-devel-static
```

#### Configure Clang

```bash
for tool in "clang" "clang-format" "llc" "llvm-strip"
do
  sudo rm -f /usr/bin/$tool
  sudo ln -s /usr/bin/$tool-18 /usr/bin/$tool
done
```

## Install Go

Before building Gthulhu, install Golang (required version: 1.22+):

```bash
wget https://go.dev/dl/go1.24.2.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.24.2.linux-amd64.tar.gz
```

Add the following to `~/.profile`:

```bash
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
```

After adding, run `source ~/.profile` to apply the changes.

## Build Gthulhu

After the prerequisites are installed, clone and build Gthulhu:

```bash
# Clone repository
git clone https://github.com/Gthulhu/Gthulhu.git
cd Gthulhu

# Clone libbpf dependency
make dep

# Initialize and update submodules
git submodule init
git submodule sync
git submodule update

# Build sched_ext framework
cd scx
meson setup build --prefix ~
meson compile -C build
cd ..

# Build libbpfgo
cd libbpfgo
make
cd ..

# Build Gthulhu
make 
```

After compilation, Gthulhu should run successfully on your system:

![image](https://hackmd.io/_uploads/Sy0reSVige.png)

You can observe Gthulhu’s output to see how many tasks are currently being scheduled by Gthulhu.

## Troubleshooting

### Issue 1: `undefined reference to eu_search_tree_init`

If you encounter this, it’s because the system is using the elfutils version of libelf. You can download and compile libelf yourself to resolve it:
```sh
sudo apt remove --purge elfutils libelf-dev
cd ~
git clone https://github.com/arachsys/libelf.git
cd libelf
make
sudo make install
```

### Issue 2: `ERROR: Program 'clang' not found or not executable`

If you see this when running meson setup build --prefix ~, try:
```sh
sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-17 100
sudo update-alternatives --install /usr/bin/llvm-strip llvm-strip /usr/bin/llvm-strip-17 100
```

## Next Steps

After installation, you can:

- 📖 Read How It Works (how-it-works.md) to understand the scheduler’s mechanisms
- 🎯 See Project Goals (project-goals.md) for design principles
- 🔧 Refer to the API Reference (api-reference.md) for custom development

---

!!! success "Installation Complete"
    Congratulations! You have successfully installed the Gthulhu scheduler. If you encounter any issues, check the FAQ (faq.md) or open an issue on GitHub.
