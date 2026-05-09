# dotfiles

一个按软件模块管理的 dotfiles 仓库。每个软件都有独立目录，配置文件和依赖都放在对应模块里，便于单独选择、预览和部署。

## 📁 目录结构

- `install.sh`：Linux / macOS 的一键部署入口。
- `install.ps1`：Windows PowerShell 的一键部署入口。
- `install.bat`：Windows cmd 的包装入口，会调用 `install.ps1`。
- `add-module.sh`：Linux / macOS 的新增模块入口。
- `add-module.ps1`：Windows PowerShell 的新增模块入口。
- `add-module.bat`：Windows cmd 的新增模块包装入口。
- `modules/<name>/files`：按 `$HOME` 相对路径保存的配置文件。
- `modules/<name>/dep`：该模块私有的 Git submodule 依赖。
- `modules/<name>/dep/manifest.tsv`：显式声明依赖部署顺序和目标路径。
- `scripts/lib.sh`：POSIX 共享部署函数。
- `scripts/Dotfiles.psm1`：PowerShell 共享部署函数。

## 🚀 快速开始

Linux / macOS：

```sh
./install.sh
```

Windows PowerShell：

```powershell
.\install.ps1
```

Windows cmd：

```bat
install.bat
```

## 🧭 交互式部署

默认部署入口会扫描 `modules` 下所有可部署模块，并进入交互式选择界面：

- `Space`：选择或取消选择模块。
- `Enter`：确认选择并继续。
- 部署前会显示本次部署影响，包括目标 HOME、备份目录、将创建或替换的配置。
- 现有目标会先移动到 `~/.dotfiles-backup/<timestamp>/`，再创建新链接或执行部署。
- `files` 下的配置会按 `$HOME` 相对路径部署；`dep` 下的依赖会按 `manifest.tsv` 的顺序部署。

## 🌏 语言

脚本默认输出中文提示和日志。需要英文输出时添加 `--en`：

```sh
./install.sh --en
./install.sh --en --dry-run
```

```powershell
.\install.ps1 --en
.\install.ps1 --en --dry-run
```

## ⚙️ 常用命令

部署所有模块，不进入选择界面：

```sh
./install.sh --all
```

```powershell
.\install.ps1 --all
```

只预览已选择模块的影响，不写入文件：

```sh
./install.sh --dry-run
```

```powershell
.\install.ps1 --dry-run
```

预览所有模块，不进入选择界面：

```sh
./install.sh --all --dry-run
```

```powershell
.\install.ps1 --all --dry-run
```

强制重新创建已部署链接：

```sh
./install.sh --force-relink
./install.sh --all --force-relink
```

```powershell
.\install.ps1 --force-relink
.\install.ps1 --all --force-relink
```

## 🆘 查看帮助

POSIX：

```sh
./install.sh --help
./add-module.sh --help
./prepare.sh --help
```

PowerShell / cmd：

```powershell
.\install.ps1 --help
.\add-module.ps1 --help
.\add-module.bat /?
.\install.bat /?
```

## 🧩 模块说明

当前模块按软件或配置类别拆分，例如：

- `bash`：Bash 配置。
- `profile`：通用 shell profile 配置。
- `pip`：pip 配置。
- `tmux`：tmux 配置和插件目录。
- `vim`：Vim 配置和插件目录。
- `zsh`：zsh、oh-my-zsh、主题和插件配置。

新增软件配置时，推荐创建 `modules/<software>/`，并把该软件相关内容集中放在这个目录下。

## 🧱 模块结构

每个模块遵循同一套约定，不需要为每个软件单独维护部署逻辑：

```text
modules/<name>/
  files/
  dep/
    manifest.tsv
```

`files/` 目录按 `$HOME` 相对路径保存配置。例如：

```text
modules/nvim/files/.config/nvim
```

部署目标就是：

```text
~/.config/nvim
```

如果模块包含 Git submodule 依赖，则放在该模块自己的 `dep/` 目录下，并通过 `manifest.tsv` 声明部署顺序和目标路径。格式为制表符分隔：

```text
# source	target
dep/oh-my-zsh	.oh-my-zsh
dep/powerlevel10k	.oh-my-zsh/custom/themes/powerlevel10k
```

部署器会先初始化该模块的 submodule，再按 manifest 行顺序创建链接。

## ➕ 新增模块

可以使用新增模块脚本把本机已有配置纳入仓库管理：

Linux / macOS：

```sh
./add-module.sh
```

Windows PowerShell：

```powershell
.\add-module.ps1
```

Windows cmd：

```bat
add-module.bat
```

新增流程会先要求输入模块名称，例如 `nvim`、`git`、`alacritty`，然后进入交互式路径选择界面：

- `Space`：选择或取消选择文件/目录。
- `Enter`：确认选择并开始添加。
- `上/下` 或 `k/j`：移动光标。
- `右` 或 `l`：进入目录。
- `左` 或 `h`：返回父目录。

脚本会按路径类型自动处理：

- 普通文件或目录：按 HOME 相对路径复制到 `modules/<name>/files`。
- 本地 Git 仓库目录：读取该仓库 remote，并作为 submodule 添加到 `modules/<name>/dep/`，同时写入 `manifest.tsv`。

例如选择 `~/.config/nvim` 时，会保存为：

```text
modules/nvim/files/.config/nvim
```

部署时仍会链接回：

```text
~/.config/nvim
```

常用参数：

```sh
./add-module.sh --module nvim
./add-module.sh --dry-run
./add-module.sh --en
./add-module.sh --help
```

```powershell
.\add-module.ps1 --module nvim
.\add-module.ps1 --dry-run
.\add-module.ps1 --en
.\add-module.ps1 --help
```

## 🔁 兼容入口

`prepare.sh` 和 `deploy.sh` 仍然保留，用于兼容旧习惯：

- `prepare.sh`：兼容包装脚本，当前用于初始化 zsh 模块的 submodule 依赖。
- `deploy.sh`：兼容包装脚本，转发到新的 `install.sh`。

新的日常使用方式推荐优先使用：

```sh
./install.sh
```

或在 Windows 上使用：

```powershell
.\install.ps1
```
