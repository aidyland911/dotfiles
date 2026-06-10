# Dotfiles → Ansible Conversion

This document records the full conversion of the shell-script-based dotfiles
setup into Ansible, done on 2026-06-10. There are **two playbooks**:

| Playbook | Replaces | Run with |
|---|---|---|
| `rhel.yml` | `install-dotfiles` + everything in `install/rhel/` | `ansible-playbook rhel.yml -K` |
| `ubuntu.yml` | `install-dotfiles` + everything in `install/ubuntu/` | `ansible-playbook ubuntu.yml -K` |

The original shell scripts were left in place untouched; the playbooks are a
parallel, idempotent replacement for them.

## Setting up Ansible in a venv

Ansible is installed into a Python virtualenv inside this directory rather
than system-wide — no `sudo pip`, no PEP 668 "externally managed environment"
errors, and easy to throw away and rebuild. The venv lives at
`ansible/.venv/` and is excluded from git via the repo's `.gitignore`.

```bash
# One-time prerequisites
sudo apt install -y python3-venv python3-pip     # Ubuntu
sudo dnf install -y python3 python3-pip          # RHEL (venv ships with python3)

# Create the venv and install Ansible into it
cd ~/dotfiles/ansible
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Verify
ansible --version
```

In every new shell, activate the venv before running playbooks:

```bash
cd ~/dotfiles/ansible && source .venv/bin/activate
```

Deactivate with `deactivate`; rebuild from scratch by deleting `.venv/` and
repeating the steps above. To upgrade Ansible later:
`pip install --upgrade ansible` inside the activated venv.

### Python version note (RHEL 9)

RHEL 9's default `python3` is 3.9, but ansible 9+ requires Python >= 3.10.
`requirements.txt` handles this with environment markers: on Python 3.9 it
installs ansible 8.x (ansible-core 2.15, still fully supports these playbooks),
on Python >= 3.10 it installs ansible 9+. Nothing to do — `pip install -r
requirements.txt` just works on both.

If you want a current ansible on RHEL 9 anyway, build the venv from a newer
interpreter from AppStream:

```bash
sudo dnf install -y python3.12
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Quick start

```bash
cd ~/dotfiles/ansible
source .venv/bin/activate   # if not already active

# On a RHEL machine:
ansible-playbook -i inventory.ini rhel.yml -K

# On an Ubuntu machine:
ansible-playbook -i inventory.ini ubuntu.yml -K
```

`-K` prompts for your sudo password (needed for the `become: true` tasks).
The default inventory (`inventory.ini`) targets `localhost` with a local
connection; edit it to manage remote machines over SSH instead. Each playbook
asserts the OS family up front, so running the wrong playbook on the wrong
distro fails immediately instead of half-applying.

Run a single component using tags, e.g.:

```bash
ansible-playbook -i inventory.ini rhel.yml -K --tags shellcheck,tealdeer
ansible-playbook -i inventory.ini ubuntu.yml -K --tags dotfiles
```

Available tags — both: `dotfiles`, `tmux`; RHEL: `thefuck`, `shellcheck`,
`ncdu`, `bat`, `figurine`, `dysk`, `tealdeer`; Ubuntu: `brew`, `fonts`, `pomo`.

## Air-gapped installs (offline mode)

Hosts in the `[airgapped]` inventory group (e.g. `automation1`) have no
internet access, so nothing on them can reach GitHub, PyPI, EPEL, or any other
download source. The playbook handles this with an `offline` flag (set to
`true` for the group in `group_vars/airgapped.yml`): every download is taken
from `ansible/offline/` **on the control node** and pushed over SSH instead.

Workflow, from the jumpbox (which has internet and the same RHEL release as
the targets):

```bash
cd ~/dotfiles/ansible
source .venv/bin/activate

# 1. Stage all artifacts into ansible/offline/ (one-time, re-run to refresh)
ansible-playbook -i inventory.ini fetch-offline.yml

# 2. Install on the air-gapped node(s)
ansible-playbook -i inventory.ini rhel.yml --limit airgapped
```

No `-K` needed when the targets are reached as root (as in this lab).

What `fetch-offline.yml` stages:

| Artifact | Used by |
|---|---|
| `shellcheck-*.tar.xz`, `ncdu.tar.gz`, `figurine.tar.gz`, `dysk`, `tealdeer`, `tldr.zip` | the matching task files, which switch `unarchive`/`copy` to control-node sources when `offline` |
| `tmux-plugins/` (TPM + resurrect + continuum clones) | `tasks/tmux.yml` — copied wholesale because `prefix + I` can't clone from GitHub on an air-gapped host |
| `wheels/` (`pip3 download thefuck`) | `tasks/thefuck.yml` — installed with `pip --no-index --find-links` |
| `rpms/` (`dnf download --resolve --alldeps` of `offline_rpm_packages`, including bat from EPEL, plus `createrepo_c` metadata) | `rhel.yml` pre-tasks — copied to the target and used as a **local dnf repo** (`--repofrompath=offline,file:///tmp/rpms --disablerepo='*'`), requesting only the wanted packages so dnf resolves minimally against what's installed. Installing all bundle RPMs directly was the first attempt; it failed on automation1 because the bundle's newer base libs (systemd-libs, …) forced an upgrade chain that, with repos disabled, dnf could only complete by removing protected systemd. |

Notes:

- The RPM bundle is dependency-resolved against the **staging** machine's dnf
  metadata, which is why the jumpbox must run the same RHEL release as the
  targets (here: both RHEL 9). Same for the Python wheels (same Python = 3.9).
- `offline_rpm_packages` deliberately excludes curl and wget: Ansible modules
  download via Python so the playbook never needs them, and requesting full
  `curl` fails on RHEL 9 minimal installs because it conflicts with the
  preinstalled `curl-minimal` (hit on automation1; `curl-minimal` still
  provides the `curl` command).
- Remote targets also get the dotfiles repo itself pushed from the control
  node (tarball excluding `.git`, `.venv`, `offline/`) — an air-gapped host
  can't `git clone` it. Local runs keep using the existing checkout.
- `ansible/offline/` is git-ignored; expect a few hundred MB after staging
  (the RPM closure is the bulk of it).
- Offline mode is implemented for **rhel.yml** only. The Ubuntu playbook's
  Homebrew installer fundamentally needs internet.
- The inventory now contains both `localhost` and `[airgapped]`, so use
  `--limit localhost` / `--limit airgapped` to target one or the other;
  a bare run with `hosts: all` would try both.

## Directory layout

```
ansible/
├── .venv/               # Python virtualenv with Ansible (git-ignored, see above)
├── requirements.txt     # pip requirements for the venv (ansible)
├── ansible.cfg          # points at inventory.ini, quiet defaults
├── inventory.ini        # localhost by default; remote host examples included
├── group_vars/
│   ├── all.yml          # all pinned versions/URLs and shared variables
│   └── airgapped.yml    # offline: true for the [airgapped] inventory group
├── rhel.yml             # RHEL playbook (online or offline)
├── ubuntu.yml           # Ubuntu playbook
├── fetch-offline.yml    # stages downloads into offline/ for air-gapped runs
├── offline/             # staged artifacts (git-ignored, created by fetch-offline.yml)
├── tasks/
│   ├── dotfiles.yml     # shared: symlinks (replaces install-dotfiles)
│   ├── tmux.yml         # shared: tmux package + TPM clone
│   ├── thefuck.yml      # RHEL
│   ├── shellcheck.yml   # RHEL
│   ├── ncdu.yml         # RHEL
│   ├── bat.yml          # RHEL
│   ├── figurine.yml     # RHEL
│   ├── dysk.yml         # RHEL
│   ├── tealdeer.yml     # RHEL
│   ├── brew.yml         # Ubuntu
│   ├── fonts.yml        # Ubuntu
│   └── pomo.yml         # Ubuntu
└── README.md            # this document
```

Both playbooks run as your login user (`become: false` at play level) and
elevate per-task only where root is required. This keeps `ansible_env.HOME`
pointing at *your* home, so symlinks, font installs, and caches land in the
right place — the shell scripts had to juggle `SUDO_USER` for the same effect.

## Script-by-script conversion map

### `install-dotfiles` → `tasks/dotfiles.yml` (both playbooks)

Original: `ln -sf` for `aliases` → `~/.aliases`, `bashrc` → `~/.bashrc`,
`tmux.conf` → `~/.tmux.conf`, then `source ~/.bashrc`.

Converted to `ansible.builtin.file` with `state: link` + `force: true`.
Two notes:

- **`source ~/.bashrc` has no Ansible equivalent** — a playbook can't change
  your already-running shell. Open a new terminal or `source ~/.bashrc` after
  the run.
- **Added:** the scripts in `cmd/` (`goggle_ws`, `newx`, `tail_status`,
  `tail_toggle`, `toggle_ws`) are now symlinked into `~/.local/bin/`, which is
  already on `PATH` via bashrc. The old installer never deployed them anywhere.
  `cmd/test` and `cmd/pomo.bak` are deliberately skipped (the list lives in
  `group_vars/all.yml` as `cmd_scripts`).
- **Added (2026-06-10):** a `functions` file (extract-any-archive `extract()`
  and ls-after-`cd()`) is symlinked to `~/.functions` and sourced from bashrc,
  same pattern as `aliases`. Note `extract()` calls `unrar2dir`/`unzip2dir`,
  which must exist separately for `.rar`/`.zip` support.
- **Added (2026-06-10):** `profile.d/custom-ps1.sh` (the two-line 💣 prompt) is
  copied to `/etc/profile.d/custom-ps1.sh` (root-owned, so this task uses
  `become`), replacing the manual `sudo tee` step. `/etc/profile.d/` is only
  sourced by *login* shells (SSH sessions, consoles) — for terminal tabs that
  spawn non-login shells, source it from bashrc instead.

### `install/ubuntu/install-tmux` → `tasks/tmux.yml` (both playbooks)

Original: heredoc-wrote a copy of the tmux config directly into `~/.tmux.conf`.
That config was a byte-for-byte duplicate of the repo's `tmux.conf`, so the
heredoc is gone — the symlink from `tasks/dotfiles.yml` is the single source of
truth now.

What remains here: install the `tmux` package and clone
[TPM](https://github.com/tmux-plugins/tpm) to `~/.tmux/plugins/tpm`, because
`tmux.conf` loads TPM/resurrect/continuum but nothing previously installed TPM.
Since `tmux.conf` is linked on both OSes, this task file runs in **both**
playbooks (it uses the generic `package` module). After the first run, press
`prefix + I` inside tmux once to let TPM install the plugins.

### RHEL: `install/rhel/*`

| Script | Task file | Conversion notes |
|---|---|---|
| `install-thefuck` | `tasks/thefuck.yml` | dnf installs python3/pip/devel, pip installs `thefuck`. **Dropped:** the blanket `dnf update -y` (a setup playbook shouldn't force a full system upgrade) and the two lines appended to `.bashrc` — `eval "$(thefuck --alias)"` and `alias fk=fuck` already live in the repo `aliases` file (now guarded, see below). |
| `install-ShellCheck.sh` | `tasks/shellcheck.yml` | Downloads/extracts the pinned release tarball (`v0.10.0`), copies the binary to `/usr/local/bin`, cleans up. Skipped entirely when the binary already exists. To upgrade: bump `shellcheck_version` in `group_vars/all.yml`, delete `/usr/local/bin/shellcheck`, re-run. |
| `install-ncdu` | `tasks/ncdu.yml` | One `unarchive` task: the release tarball contains the binary at its root, so it extracts straight into `/usr/local/bin` with `creates:` as the idempotency guard. The original's curl-installation fallback logic is unnecessary (curl/tar are in the playbook's base packages). |
| `install-bat` | `tasks/bat.yml` | **Changed:** the original downloaded a hardcoded EPEL **10** RPM, which fails on RHEL 9 (found during a real run on RHEL 9.4). Now the playbook enables the EPEL repo matching the host's major version (`epel-release-latest-{{ distribution_major_version }}`) and installs `bat` from it — works on RHEL 9 and 10. **Dropped:** appending `MANPAGER` to `.bashrc` — the export already lives in the repo `bashrc` (now guarded). |
| `install-figurine` | `tasks/figurine.yml` | Downloads/extracts the pinned release (`v1.3.0`, which unpacks to `/tmp/deploy/`), installs the binary, and writes the same `/etc/profile.d/hostname-banner.sh` login banner via `copy: content:`. |
| `install-dysk` | `tasks/dysk.yml` | One `get_url` task to `/usr/local/bin/dysk` with mode `0755`. `get_url` skips the download when the file exists. |
| `install-tldr` | `tasks/tealdeer.yml` | **Changed:** the original installed a Fedora **43** RPM, which is incompatible with RHEL 9 (needs newer glibc/rpm), and tealdeer isn't packaged in EPEL at all. Now the upstream static musl binary is installed as `/usr/local/bin/tldr` — runs on any RHEL version. The tldr cache is still seeded by unzipping `tldr.zip` into `~/.cache/tealdeer/tldr-pages` (kept because `tldr --update` can fail behind proxies); cache tasks run as you, so no `SUDO_USER`/`chown` gymnastics are needed. |

### Ubuntu: `install/ubuntu/*`

| Script | Task file | Conversion notes |
|---|---|---|
| `install-brew` | `tasks/brew.yml` | apt installs the prerequisites, then runs the official installer with `NONINTERACTIVE=1` — only when `/home/linuxbrew/.linuxbrew/bin/brew` doesn't exist. **Changed:** instead of appending the `brew shellenv` eval to `.bashrc` (which, with symlinked dotfiles, would dirty the repo on every run), the eval now lives in the repo `bashrc` behind an `if brew exists` guard. Runs without `become` because Homebrew refuses to install as root. |
| `install-fonts` | `tasks/fonts.yml` | apt installs `fontconfig`/`xz-utils`, creates `~/.local/share/fonts`, `unarchive`s the JetBrainsMono Nerd Font release, and refreshes the font cache via a handler (only fires when fonts were actually extracted). |
| `pomo/install-pomo.sh` | `tasks/pomo.yml` | Copies the `pomo` binary from `install/ubuntu/pomo/` to `~/.local/bin/pomo` and `vars` to `~/.cache/pomo/vars`, same as the script. **Changed (2026-06-10):** now runs in **both** playbooks — `tmux.conf` calls `pomo` in the status bar on every OS, and a RHEL run surfaced the missing binary. Upstream (rwxrob/pomo) deleted the released binary, so the repo copy (v0.2.5, static Go build, verified working) is the source of truth; `cmd/pomo/pomo-backup.tar.gz` holds the same binary plus the vendored Go source for rebuilding (`go build` inside `pomo@v0.2.5/`). |

## Changes made to the dotfiles themselves

The old scripts appended config lines to `~/.bashrc` at install time. Under
Ansible, `~/.bashrc` is a symlink into this repo, so appending would modify the
tracked file on every run. Instead, those lines were moved into the repo files
**once**, behind existence guards, so the same `bashrc`/`aliases` work on any
machine regardless of which tools are installed:

- **`bashrc`**
  - `MANPAGER` (bat) export is now wrapped in `command -v bat` — `man` no
    longer breaks on machines without bat (e.g. Ubuntu, where the package is
    `batcat` anyway).
  - Added a guarded Homebrew block: `eval "$(brew shellenv)"` only when
    `/home/linuxbrew/.linuxbrew/bin/brew` exists. This replaces what
    `install-brew` used to append.
- **`aliases`**
  - `eval "$(thefuck --alias)"` and `alias fk=fuck` wrapped in
    `command -v thefuck` — no more startup error on machines without it.
  - Duplicate `MANPAGER` export given the same bat guard.
- **`bashrc` additions (2026-06-10)**
  - Sources the new `functions` file alongside `aliases`.
  - `LESS_TERMCAP_*` exports for colorized man pages.
  - `MANPAGER` now picks bat when installed, falling back to `less -R`
    otherwise — instead of appending a competing `MANPAGER='less -R'` that
    would have overridden the bat pager everywhere.

## Variables

Everything tunable lives in `group_vars/all.yml`: pinned versions
(`shellcheck_version`, `figurine_version`), download URLs (`epel_release_url`,
`tealdeer_url`, `ncdu_url`, `nerd_font_url`, …), the repo location
(`dotfiles_dir`, defaults to `~/dotfiles`), and the `cmd_scripts` list. Bump a
version there instead of editing task files.

## Known caveats

- **This machine's shell exports `ANSIBLE_CONFIG` and `ANSIBLE_INVENTORY`
  pointing at `~/.config/ansible/` files that don't exist.** Those env vars
  take precedence over the local `ansible.cfg`, and a missing inventory means
  `hosts: all` matches nothing — the playbook would silently do zero work.
  The commands above pass `-i inventory.ini` explicitly (the CLI flag beats
  the env var), so always include it, or unset/fix those env vars.
- `pip3 install thefuck` system-wide may be rejected on very new distros that
  enforce PEP 668 (externally-managed environments). If that happens, switch
  `tasks/thefuck.yml` to `pipx` or add `extra_args: --break-system-packages`.
- `dysk`, the tealdeer binary, and the tldr `latest` zip are unpinned upstream
  downloads (tealdeer/tldr by necessity — tealdeer isn't in EPEL).
- TPM plugins still need a one-time `prefix + I` inside tmux.

## Verification performed

- `ansible-playbook --syntax-check` on both playbooks (ansible-core 2.17.8) —
  both pass.
- `ansible-playbook -i inventory.ini ubuntu.yml --check --tags dotfiles` dry
  run on this machine — all symlink tasks resolve and report `changed` as
  expected, no failures.
- `bash -n` on the edited `bashrc` and `aliases` — clean.
- The RHEL playbook's dnf/RPM tasks could not be exercised here (this host is
  WSL2 Ubuntu); they mirror the original scripts' commands one-to-one.
