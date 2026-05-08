# dotfiles

This repository manages dotfiles by software module. Each module lives under
`modules/<name>` and owns its config files plus platform-specific deployment
scripts.

## Layout

- `install.sh`: POSIX one-step deployment entrypoint for Linux and macOS.
- `install.ps1`: PowerShell one-step deployment entrypoint for Windows.
- `install.bat`: cmd wrapper for `install.ps1`.
- `modules/<name>/files`: dotfiles owned by that module.
- `modules/<name>/deploy.sh`: POSIX module deployment phases.
- `modules/<name>/deploy.ps1`: PowerShell module deployment phases.
- `scripts/lib.sh`: shared POSIX deployment helpers.
- `scripts/Dotfiles.psm1`: shared PowerShell deployment helpers.

## Usage

Linux and macOS:

```sh
./install.sh
```

Windows PowerShell:

```powershell
.\install.ps1
```

Windows cmd:

```bat
install.bat
```

The interactive menu uses Space to select modules and Enter to confirm. Before
deployment, the script prints the target home directory, backup directory, and
the impact for every selected module. Existing targets are moved into
`~/.dotfiles-backup/<timestamp>/` before replacement.

Scripts print Chinese prompts and logs by default. Add `--en` to use English
output:

```sh
./install.sh --en
./install.sh --en --dry-run
```

```powershell
.\install.ps1 --en
.\install.ps1 --en --dry-run
```

For non-interactive deployment:

```sh
./install.sh --all
```

```powershell
.\install.ps1 --all
```

For impact preview only, keep the interactive module picker and add `--dry-run`:

```sh
./install.sh --dry-run
```

```powershell
.\install.ps1 --dry-run
```

For previewing every module without the picker, combine `--all` and `--dry-run`:

```sh
./install.sh --all --dry-run
```

```powershell
.\install.ps1 --all --dry-run
```

Help:

```sh
./install.sh --help
./prepare.sh --help
modules/zsh/deploy.sh --help
```

```powershell
.\install.ps1 --help
.\install.bat /?
.\modules\zsh\deploy.ps1 --help
```

`prepare.sh` and `deploy.sh` are kept as compatibility wrappers. New usage
should prefer `install.sh`, `install.ps1`, or `install.bat`.
