# dotfiles

一个按软件模块管理的 dotfiles 仓库。每个软件都有独立目录，配置文件和部署脚本都放在对应模块里，便于单独选择、预览和部署。

## 📁 目录结构

- `install.sh`：Linux / macOS 的一键部署入口。
- `install.ps1`：Windows PowerShell 的一键部署入口。
- `install.bat`：Windows cmd 的包装入口，会调用 `install.ps1`。
- `modules/<name>/files`：某个软件模块实际管理的配置文件。
- `modules/<name>/deploy.sh`：该模块在 POSIX 终端下的部署脚本。
- `modules/<name>/deploy.ps1`：该模块在 PowerShell 下的部署脚本。
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

## 🆘 查看帮助

POSIX：

```sh
./install.sh --help
./prepare.sh --help
modules/zsh/deploy.sh --help
```

PowerShell / cmd：

```powershell
.\install.ps1 --help
.\install.bat /?
.\modules\zsh\deploy.ps1 --help
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

## 🔁 兼容入口

`prepare.sh` 和 `deploy.sh` 仍然保留，用于兼容旧习惯：

- `prepare.sh`：兼容包装脚本，当前用于准备 zsh 相关依赖。
- `deploy.sh`：兼容包装脚本，转发到新的 `install.sh`。

新的日常使用方式推荐优先使用：

```sh
./install.sh
```

或在 Windows 上使用：

```powershell
.\install.ps1
```
