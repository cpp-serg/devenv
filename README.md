# devenv

Personal shell and development environment: zsh + oh-my-zsh, neovim, tmux, fzf
and the usual search/diff tooling, driven from one bootstrap command.

Works on **Rocky/RHEL 8+** (dnf) and **Debian 12+/Ubuntu 22.04+/Proxmox VE** (apt).

## Install

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/cpp-serg/devenv/main/bootstrap.sh)"
```

It asks whether this is a developer or a user machine, installs git if it is
missing (asking first), clones the repo to `~/devenv` and takes it from there.

Non-interactive variants:

```sh
# lean machine, accept all defaults
sh -c "$(curl -fsSL .../bootstrap.sh)" -- --user --yes

# full developer machine, no questions
sh -c "$(curl -fsSL .../bootstrap.sh)" -- --dev --yes

# see the plan without changing anything
sh -c "$(curl -fsSL .../bootstrap.sh)" -- --user --dry-run
```

## Modes

**Base — installed in both modes, never asked about:**
zsh + oh-my-zsh, the dotfile symlinks, git, git-lfs, ripgrep, fd, htop, ncdu,
dos2unix, and the build toolchain (gcc/g++/make, cmake ≥ 3.20, ninja, gettext)
because **neovim is always built from source**.

**`--user`** then asks once per optional group, showing what the host already
has before each question: extra dev packages (ccache/gdb/clang/headers), tmux,
fzf, bat + delta, lazygit + tig, misc CLI, rust/go toolchains, Claude Code,
and whether to make zsh the login shell.

**`--dev`** (default) installs all of that without asking, plus the EL
gcc-toolsets, SCTP, the `/opt/tools` rust/go builds, and the site-specific host
tweaks (CIFS build share, sshd banner/forwarding, tmux lock).

## Options

| Flag | Effect |
|---|---|
| `--user` / `--dev` | mode; default is dev, or a prompt when a terminal is attached |
| `--yes` | never ask; take every default |
| `--dry-run` | print the package/build plan, change nothing |
| `--target DIR` | where to clone (default `~/devenv`) |
| `--branch REF` | branch or tag to check out |
| `--repo URL\|PATH` | clone from elsewhere; a local directory is copied as-is |
| `--link-mode entries\|dir` | link each `.config` entry (default) or replace `~/.config` wholesale |
| `--build-git` | build git from source instead of using the distro package |
| `--no-work-tweaks` | skip the site-specific tweaks in dev mode |
| `--no-opt-tools` | skip the rust/go `/opt/tools` rebuild (that step takes tens of minutes) |

Re-running is safe. `~/devenv/setup.sh --user` repeats the run without
re-cloning, and anything already installed is detected and left alone.

## How the distro abstraction works

```
bootstrap.sh   POSIX sh only - it is executed by /bin/sh, which is dash on
               Debian/Ubuntu/Proxmox. Installs git, clones, execs bash setup.sh.
setup.sh       Orchestrator: mode resolution, profiles, summary, logging.
lib/distro.sh  Host detection: OS_FAMILY, PKG_MGR, IS_PVE, IS_CONTAINER, SUDO.
lib/pkgmap.sh  Canonical tool name -> native package(s). The only translation table.
lib/pkg.sh     The only code that knows dnf from apt. Also alt_register().
lib/steps.sh   Idempotent installation steps shared by the profiles.
profiles/      base.sh (always), user.sh (interview), dev.sh (everything).
```

Adding a tool means one entry in `lib/pkgmap.sh` and one call to
`pkg_install <canonical>`; no script mentions `dnf` or `apt-get` directly.

Two details worth knowing:

- **Binary names differ on apt.** `fd-find` installs `fdfind` and `bat`
  installs `batcat`. Those are registered with `update-alternatives` as
  `/usr/local/bin/fd` and `/usr/local/bin/bat` at **priority 50**. Tools built
  into `/opt/tools` register at **priority 100**, so a `cargo`-built `fd`
  automatically takes over, and `update-alternatives --config fd` switches back.
- **Version floors, not blind source builds.** tmux (≥ 3.2) and cmake (≥ 3.20)
  use the distro package when it is new enough and are built from source when it
  is not — which is why Rocky 8, with tmux 2.7, still compiles tmux while Debian
  13 does not. Neovim is the exception: always built from source.

On a **Proxmox VE host** the apt sources, sshd config, kernel modules and CIFS
mounts are all left alone, and dev mode warns that it is about to put a
toolchain on a hypervisor.

## Testing

`test/run-lxc-tests.sh` runs the whole thing end to end in throwaway LXC
containers on a Proxmox host — Rocky 8, Ubuntu 24.04 and Debian 13, in both
modes, on machines stripped of git and curl first:

```sh
test/run-lxc-tests.sh                     # all of it, then destroy the CTs
test/run-lxc-tests.sh --only rocky8 --mode user --keep
test/run-lxc-tests.sh --full              # include the /opt/tools rebuild
```

It asserts that an interactive zsh starts silently, that the tools resolve under
their canonical names, that the symlinks point into the repo, and that a second
run changes nothing. `test/shellcheck.sh` lints every shell script.
