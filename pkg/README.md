# AgentSight Arch Linux Packaging

This directory contains PKGBUILD files to build and install AgentSight on Arch Linux and Arch-based distributions (CachyOS, Manjaro, EndeavourOS, etc.).

## Quick Start (Local Build)

If you are building from the local git checkout (the recommended way since submodules are required):

```bash
cd /path/to/agentsight/pkg

# Option A: use makepkg directly with local source
# Edit PKGBUILD and uncomment the two "local build" lines:
#   source=()
#   sha256sums=()
# Then run:
makepkg -si

# Option B: use the helper script
./build-local.sh
```

## Standard Build (From GitHub Release)

```bash
cd pkg
makepkg -si
```

> **Warning**: The GitHub auto-generated release tarball does **not** include git submodules (`libbpf`, `bpftool`). If you use the tarball source, you must either:
> - Switch to the git source: `source=("agentsight::git+https://github.com/eunomia-bpf/agentsight.git#tag=v0.2.16")`
> - Or build from a local checkout.

## Dependencies

### Runtime
- `libelf`
- `zlib`

### Build-time
- `clang` / `llvm` — eBPF compilation
- `make` — build orchestration
- `git` — submodule management
- `nodejs` / `npm` — frontend build
- `rust` — collector compilation

All build dependencies are automatically installed by `makepkg -s`.

## Post-Install

The `.install` script prints a quick-start message. Key points:

- **Root required**: eBPF live capture needs `sudo` or file capabilities:
  ```bash
  sudo setcap cap_bpf,cap_sys_admin+ep /usr/bin/agentsight
  ```
- **Documentation**: installed to `/usr/share/doc/agentsight/`
- **No systemd service**: AgentSight is primarily an interactive CLI/TUI tool. No background service is installed by default.

## Troubleshooting

### Build fails with "missing bundled BPF loader"
Run `make build-bpf` manually first, then re-run `makepkg`.

### npm install hangs
Set a registry mirror if needed:
```bash
export NPM_CONFIG_REGISTRY=https://registry.npmmirror.com
makepkg -si
```

### Cargo download slow
Use a Cargo mirror in `~/.cargo/config.toml`:
```toml
[source.crates-io]
replace-with = 'rsproxy'

[source.rsproxy]
registry = "https://rsproxy.cn/crates.io-index"
```

## AUR Submission (Optional)

To publish to AUR:

1. Update `pkgver` and `pkgrel` in PKGBUILD
2. Generate `.SRCINFO`:
   ```bash
   makepkg --printsrcinfo > .SRCINFO
   ```
3. Push to AUR git repository

See [Arch Wiki - AUR submission guidelines](https://wiki.archlinux.org/title/AUR_submission_guidelines) for details.
