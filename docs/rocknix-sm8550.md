# AgentSight on ROCKNIX SM8550

This document describes how to run AgentSight on a ROCKNIX SM8550 handheld, where `/usr/bin/bash` is shipped stripped and the `readline` symbol required by the process runner is not available in the bash binary itself.

## Problem

On ROCKNIX SM8550, starting `agentsight debug trace --process` (or any mode that enables the process runner) fails with:

```text
libbpf: elf: failed to find symbol 'readline' in '/usr/bin/bash'
libbpf: prog 'bash_readline': failed to auto-attach: -ENOENT
Failed to attach BPF skeleton
```

Root cause:

- The process BPF program attaches a `uretprobe` to `readline` inside `/usr/bin/bash`.
- ROCKNIX strips `/usr/bin/bash`, so the symbol table no longer contains `readline`.
- However, ROCKNIX's bash links `libreadline.so.8` dynamically, and the `readline` symbol is present in that library.

## Verification on the device

```bash
file /usr/bin/bash
# /usr/bin/bash: ELF 64-bit LSB executable ... stripped

ldd /usr/bin/bash
# libreadline.so.8 => /usr/lib/libreadline.so.8

readelf -s /lib/libreadline.so.8 | grep -w readline
# 375: 000000000001a940    184 FUNC    GLOBAL DEFAULT       10 readline
```

## Source-code fix

`bpf/process.bpf.c` now defines the uretprobe target through a build-time macro `BASH_READLINE_SEC` that defaults to the historical target but can be overridden for distributions like ROCKNIX.

Default (upstream) target:

```c
SEC("uretprobe//usr/bin/bash:readline")
```

ROCKNIX target:

```c
SEC("uretprobe//lib/libreadline.so.8:readline")
```

The `comm` check in the handler still ensures only processes named `bash` are reported, so attaching to the shared library is safe even if other programs also use `readline`.

## Building for ROCKNIX SM8550

The device is `aarch64`, so the Rust collector must be cross-compiled (or built natively on another aarch64 host). The eBPF bytecode itself is portable once compiled with the correct kernel BTF.

### Build the process BPF program with the ROCKNIX target

```bash
cd bpf
make BASH_READLINE_SEC='"uretprobe//lib/libreadline.so.8:readline"' process
```

This produces `bpf/process` (the userspace loader) and the embedded BPF object.

### Cross-compile the collector for aarch64

The collector crate is at `collector/`. You need:

- Rust target `aarch64-unknown-linux-gnu`
- An AArch64 cross-compiler, e.g. `aarch64-linux-gnu-gcc`

Example:

```bash
rustup target add aarch64-unknown-linux-gnu

export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
export CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc
export CXX_aarch64_unknown_linux_gnu=aarch64-linux-gnu-g++

cd collector
AGENTSIGHT_SYNC_VENDOR=1 cargo build --release --target aarch64-unknown-linux-gnu
```

The resulting binary is:

```text
collector/target/aarch64-unknown-linux-gnu/release/agentsight
```

> Note: `AGENTSIGHT_SYNC_VENDOR=1` is required after rebuilding eBPF programs so the new `process` BPF binary is embedded into the Rust crate.

### Deploy to the device

Copy the new binary to the device (password is `rocknix` for the default ROCKNIX root account):

```bash
scp collector/target/aarch64-unknown-linux-gnu/release/agentsight \
  root@192.168.10.155:/storage/.local/bin/agentsight
```

## Running on ROCKNIX SM8550

After deploying the adapted binary, the process runner can attach successfully:

```bash
ssh root@192.168.10.155
/storage/.local/bin/agentsight debug trace \
  --ssl --process --system \
  --server --listen 0.0.0.0
```

If you also need stdio capture for a specific process, add `--stdio -p <PID>`:

```bash
/storage/.local/bin/agentsight debug trace \
  --ssl --process --system --stdio \
  --server --listen 0.0.0.0 \
  -p <PID>
```

The Web UI listens on port **7395**.

## Verifying BTF

ROCKNIX kernels for AgentSight must be built with:

```text
CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_DEBUG_INFO_BTF_MODULES=y
```

On the device:

```bash
ls /sys/kernel/btf/vmlinux
zcat /proc/config.gz | grep -E 'CONFIG_DEBUG_INFO_BTF|CONFIG_PAHOLE_VERSION'
```

## References

- `bpf/process.bpf.c` — readline uretprobe definition
- `bpf/Makefile` — `BASH_READLINE_SEC` build override
- `AGENTSIGHT_KERNEL_DEPLOY.md` (in the ROCKNIX distribution repo) — kernel build and deployment notes for SM8550
