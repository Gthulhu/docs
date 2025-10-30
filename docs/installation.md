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

## Install Gthulhu on Ubuntu 25.04

To save time, we skip kernel compilation/installation and use Ubuntu 25.04 which directly supports sched_ext:
https://canonical.com/blog/canonical-releases-ubuntu-25-04-plucky-puffin

Use the following script to install required packages:

```sh
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
for tool in "clang" "clang-format" "llc" "llvm-strip"
do
  sudo rm -f /usr/bin/$tool
  sudo ln -s /usr/bin/$tool-17 /usr/bin/$tool
done
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

These packages include everything needed to build scx.

Before building Gthulhu, install Golang:

```sh
wget https://go.dev/dl/go1.24.2.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.24.2.linux-amd64.tar.gz
```

Add the following to ~/.profile:

```sh
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
```

After adding, run source ~/.profile to apply the changes.

After the prerequisites are installed, install Gthulhu:

```sh
git clone https://github.com/Gthulhu/Gthulhu.git
cd Gthulhu
make dep
git submodule init
git submodule sync
git submodule update
cd scx
meson setup build --prefix ~
meson compile -C build
cd ..
cd libbpfgo
make
cd ..
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
