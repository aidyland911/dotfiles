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

## Directory layout

```
ansible/
├── .venv/               # Python virtualenv with Ansible (git-ignored, see above)
├── requirements.txt     # pip requirements for the venv (ansible)
├── ansible.cfg          # points at inventory.ini, quiet defaults
├── inventory.ini        # localhost by default; remote host examples included
├── group_vars/
│   └── all.yml          # all pinned versions/URLs and shared variables
├── rhel.yml             # RHEL playbook
├── ubuntu.yml           # Ubuntu playbook
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
| `install-bat` | `tasks/bat.yml` | `dnf` installs the pinned EPEL 10 RPM by URL (`disable_gpg_check` because it's a direct rpmfind download, matching the original). **Dropped:** appending `MANPAGER` to `.bashrc` — the export already lives in the repo `bashrc` (now guarded). |
| `install-figurine` | `tasks/figurine.yml` | Downloads/extracts the pinned release (`v1.3.0`, which unpacks to `/tmp/deploy/`), installs the binary, and writes the same `/etc/profile.d/hostname-banner.sh` login banner via `copy: content:`. |
| `install-dysk` | `tasks/dysk.yml` | One `get_url` task to `/usr/local/bin/dysk` with mode `0755`. `get_url` skips the download when the file exists. |
| `install-tldr` | `tasks/tealdeer.yml` | dnf installs the pinned Fedora RPM by URL, then seeds the tldr cache by unzipping `tldr.zip` into `~/.cache/tealdeer/tldr-pages` (kept because `tldr --update` can fail behind proxies). The cache tasks run as you, so no `SUDO_USER`/`chown` gymnastics are needed. |

### Ubuntu: `install/ubuntu/*`

| Script | Task file | Conversion notes |
|---|---|---|
| `install-brew` | `tasks/brew.yml` | apt installs the prerequisites, then runs the official installer with `NONINTERACTIVE=1` — only when `/home/linuxbrew/.linuxbrew/bin/brew` doesn't exist. **Changed:** instead of appending the `brew shellenv` eval to `.bashrc` (which, with symlinked dotfiles, would dirty the repo on every run), the eval now lives in the repo `bashrc` behind an `if brew exists` guard. Runs without `become` because Homebrew refuses to install as root. |
| `install-fonts` | `tasks/fonts.yml` | apt installs `fontconfig`/`xz-utils`, creates `~/.local/share/fonts`, `unarchive`s the JetBrainsMono Nerd Font release, and refreshes the font cache via a handler (only fires when fonts were actually extracted). |
| `pomo/install-pomo.sh` | `tasks/pomo.yml` | Copies the `pomo` binary from `install/ubuntu/pomo/` to `~/.local/bin/pomo` and `vars` to `~/.cache/pomo/vars`, same as the script. Kept Ubuntu-only to match the original layout — if you want the tmux status-bar timer on RHEL too, add `import_tasks: tasks/pomo.yml` to `rhel.yml`. |

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

## Variables

Everything tunable lives in `group_vars/all.yml`: pinned versions
(`shellcheck_version`, `figurine_version`), RPM/tarball URLs (`bat_rpm_url`,
`tealdeer_rpm_url`, `ncdu_url`, `nerd_font_url`, …), the repo location
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
- The bat and tealdeer RPM URLs are distro-release-specific (EPEL 10 /
  Fedora 43), exactly as in the original scripts. On other RHEL releases,
  update the URLs in `group_vars/all.yml` — or replace both tasks with plain
  `dnf` packages if you enable EPEL.
- `dysk` and the tldr `latest` zip are unpinned upstream downloads, same as
  before.
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
