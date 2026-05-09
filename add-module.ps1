$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot
Import-Module (Join-Path $Root "scripts\Dotfiles.psm1") -Force

$ModuleName = ""
$DryRun = $false

function Show-Usage {
    if (Test-DotfilesEnglish) {
        @"
Usage:
  .\add-module.ps1                  Interactively add a dotfile module
  .\add-module.ps1 --module <name>  Use the specified module name
  .\add-module.ps1 --dry-run        Preview changes without writing files
  .\add-module.ps1 --en             Output English prompts and logs
  .\add-module.ps1 -h|--help        Show this help

Interactive selector:
  Up/Down or k/j      Move cursor
  Space               Select or unselect a file/directory
  Right or l          Enter directory
  Left or h           Go to parent directory
  Enter               Confirm selected paths

Selected local Git repositories are added as submodules under dep/.
Other files and directories are copied into modules/<name>/files with their HOME-relative paths preserved.
"@ | Write-Host
    } else {
        @"
用法：
  .\add-module.ps1                  交互式添加 dotfile 模块
  .\add-module.ps1 --module <name>  使用指定模块名称
  .\add-module.ps1 --dry-run        仅预览变更，不写入文件
  .\add-module.ps1 --en             使用英文提示和日志
  .\add-module.ps1 -h|--help        显示此帮助

交互式选择器：
  上/下 或 k/j        移动光标
  空格                选择或取消选择文件/目录
  右 或 l             进入目录
  左 或 h             返回父目录
  回车                确认已选择路径

选中的本地 Git 仓库会作为 submodule 添加到 dep/。
其他文件和目录会按 HOME 相对路径复制到 modules/<name>/files。
"@ | Write-Host
    }
}

for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "--module" {
            if ($i + 1 -ge $args.Count) { throw (Get-DotfilesMessage "缺少 --module 参数值" "missing --module value") }
            $ModuleName = $args[$i + 1]
            $i++
        }
        "--dry-run" { $DryRun = $true }
        "--en" { Set-DotfilesEnglish }
        "-h" { Show-Usage; exit 0 }
        "--help" { Show-Usage; exit 0 }
        "/?" { Show-Usage; exit 0 }
        default { throw (Get-DotfilesMessage "未知参数：$($args[$i])" "unknown argument: $($args[$i])") }
    }
}

function Test-ModuleName {
    param([Parameter(Mandatory)] [string] $Name)
    return $Name -match '^[A-Za-z0-9][A-Za-z0-9._-]*$'
}

while (-not $ModuleName) {
    $ModuleName = Read-Host (Get-DotfilesMessage "请输入模块名称（软件名）" "Enter module name (software name)")
}
if (-not (Test-ModuleName $ModuleName)) {
    throw (Get-DotfilesMessage "模块名称只能包含字母、数字、点、下划线和短横线，且不能以点开头：$ModuleName" "module name may only contain letters, numbers, dots, underscores, and dashes, and must not start with a dot: $ModuleName")
}

$ModuleDir = Join-Path $Root "modules\$ModuleName"
if (Test-Path -LiteralPath $ModuleDir) {
    throw (Get-DotfilesMessage "模块已存在：$ModuleName" "module already exists: $ModuleName")
}

function Get-RelativeToHome {
    param([Parameter(Mandatory)] [string] $Path)
    $home = (Resolve-Path (Get-DotfilesHome)).Path
    $full = (Resolve-Path -LiteralPath $Path).Path
    if ($full -eq $home) { return "." }
    if (-not $full.StartsWith($home + [IO.Path]::DirectorySeparatorChar)) {
        throw (Get-DotfilesMessage "所选路径必须位于 HOME 下：$full" "selected path must be under HOME: $full")
    }
    return $full.Substring($home.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
}

function Test-GitRepoRoot {
    param([Parameter(Mandatory)] [string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }
    $top = (& git -C $Path rev-parse --show-toplevel 2>$null)
    if (-not $top) { return $false }
    return ((Resolve-Path -LiteralPath $top).Path -eq (Resolve-Path -LiteralPath $Path).Path)
}

function Get-GitRemoteUrl {
    param([Parameter(Mandatory)] [string] $Path)
    $url = (& git -C $Path config --get remote.origin.url 2>$null)
    if ($url) { return $url }
    $remote = (& git -C $Path remote 2>$null | Select-Object -First 1)
    if (-not $remote) { throw (Get-DotfilesMessage "Git 仓库没有可用 remote：$Path" "Git repository has no usable remote: $Path") }
    $url = (& git -C $Path config --get "remote.$remote.url" 2>$null)
    if (-not $url) { throw (Get-DotfilesMessage "Git 仓库没有可用 remote：$Path" "Git repository has no usable remote: $Path") }
    return $url
}

function Select-ConfigPaths {
    $current = (Resolve-Path (Get-DotfilesHome)).Path
    $selected = @{}
    $cursor = 0

    while ($true) {
        $items = @("..") + @(Get-ChildItem -LiteralPath $current -Force | Sort-Object Name)
        Clear-Host
        Write-DotfilesMessage "选择要加入模块的配置文件或目录。空格选择，回车确认。" "Select config files or directories for the module. Space selects, Enter confirms."
        Write-DotfilesMessage "当前目录：$current" "Current directory: $current"
        Write-DotfilesMessage "已选择：$($selected.Count)`n" "Selected: $($selected.Count)`n"

        for ($i = 0; $i -lt $items.Count; $i++) {
            $entry = $items[$i]
            $name = if ($entry -eq "..") { ".." } else { $entry.Name }
            $path = if ($entry -eq "..") { Split-Path -Parent $current } else { $entry.FullName }
            $suffix = if (($entry -eq "..") -or (Test-Path -LiteralPath $path -PathType Container)) { "/" } else { "" }
            $pointer = if ($i -eq $cursor) { ">" } else { " " }
            $mark = if (($entry -ne "..") -and $selected.ContainsKey((Resolve-Path -LiteralPath $path).Path)) { "x" } else { " " }
            Write-Host "$pointer [$mark] $name$suffix"
        }

        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        switch ($key.VirtualKeyCode) {
            13 {
                if ($selected.Count -gt 0) { return @($selected.Keys) }
                Write-DotfilesMessage "请至少选择一个路径。" "Select at least one path."
                Start-Sleep -Seconds 1
            }
            32 {
                if ($items[$cursor] -ne "..") {
                    $path = (Resolve-Path -LiteralPath $items[$cursor].FullName).Path
                    if ($selected.ContainsKey($path)) { $selected.Remove($path) } else { $selected[$path] = $true }
                }
            }
            37 {
                $current = Split-Path -Parent $current
                $cursor = 0
            }
            39 {
                $entry = $items[$cursor]
                $path = if ($entry -eq "..") { Split-Path -Parent $current } else { $entry.FullName }
                if (Test-Path -LiteralPath $path -PathType Container) {
                    $current = (Resolve-Path -LiteralPath $path).Path
                    $cursor = 0
                }
            }
            38 { if ($cursor -gt 0) { $cursor-- } }
            40 { if ($cursor -lt ($items.Count - 1)) { $cursor++ } }
            72 {
                $current = Split-Path -Parent $current
                $cursor = 0
            }
            74 { if ($cursor -lt ($items.Count - 1)) { $cursor++ } }
            75 { if ($cursor -gt 0) { $cursor-- } }
            76 {
                $entry = $items[$cursor]
                $path = if ($entry -eq "..") { Split-Path -Parent $current } else { $entry.FullName }
                if (Test-Path -LiteralPath $path -PathType Container) {
                    $current = (Resolve-Path -LiteralPath $path).Path
                    $cursor = 0
                }
            }
        }
    }
}

function ConvertTo-PsSingleQuoted {
    param([Parameter(Mandatory)] [string] $Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

$selectedPaths = @(Select-ConfigPaths)
$fileTargets = @()
$submoduleSources = @()
$submoduleTargets = @()

Write-DotfilesMessage "将创建模块：$ModuleName" "Module to create: $ModuleName"
foreach ($path in $selectedPaths) {
    $rel = Get-RelativeToHome $path
    if (Test-GitRepoRoot $path) {
        $name = Split-Path -Leaf $path
        $dest = "dep/$name"
        $destPath = Join-Path $Root $dest
        if (Test-Path -LiteralPath $destPath) {
            throw (Get-DotfilesMessage "submodule 目标路径已存在：$dest" "submodule target already exists: $dest")
        }
        $url = Get-GitRemoteUrl $path
        $submoduleSources += $dest
        $submoduleTargets += $rel
        if ($DryRun) {
            Write-DotfilesMessage "  将添加 submodule：$url -> $dest" "  would add submodule: $url -> $dest"
        } else {
            & git -C $Root submodule add $url $dest
            Write-DotfilesMessage "  已添加 submodule：$dest" "  added submodule: $dest"
        }
    } else {
        $fileTargets += $rel
        $dest = Join-Path $ModuleDir ("files\" + $rel.Replace('/', '\'))
        if ($DryRun) {
            Write-DotfilesMessage "  将复制：$path -> $dest" "  would copy: $path -> $dest"
        } else {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            if (Test-Path -LiteralPath $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
            Copy-Item -Recurse -Force -LiteralPath $path -Destination $dest
            Write-DotfilesMessage "  已复制：$path -> $dest" "  copied: $path -> $dest"
        }
    }
}

if ($DryRun) {
    Write-DotfilesMessage "预览完成，未写入任何文件。" "Dry-run completed. No files were written."
    exit 0
}

New-Item -ItemType Directory -Force -Path (Join-Path $ModuleDir "files") | Out-Null

$shFileSources = ($fileTargets | ForEach-Object { "  " + '"' + '${MODULE_DIR}/files/' + $_ + '"' }) -join "`n"
$shFileTargets = ($fileTargets | ForEach-Object { "  '$_'" }) -join "`n"
$shSubSources = ($submoduleSources | ForEach-Object { "  " + '"' + '${DOTFILES_ROOT}/' + $_ + '"' }) -join "`n"
$shSubTargets = ($submoduleTargets | ForEach-Object { "  '$_'" }) -join "`n"

$deploySh = @"
#!/usr/bin/env bash

set -euo pipefail
source "`$(cd "`$(dirname "`${BASH_SOURCE[0]}")/../.." && pwd)/scripts/lib.sh"
if parse_language_arg "`${1:-}"; then shift; fi

MODULE_DIR="`${DOTFILES_ROOT}/modules/$ModuleName"
FILES_SOURCES=(
$shFileSources
)
FILES_TARGETS=(
$shFileTargets
)
SUBMODULE_SOURCES=(
$shSubSources
)
SUBMODULE_TARGETS=(
$shSubTargets
)

prepare_deps() {
  if [ "`${#SUBMODULE_SOURCES[@]}" -gt 0 ]; then
    msg_line "正在获取 submodule 依赖..." "Fetching submodule dependencies..."
    git -C "`$DOTFILES_ROOT" submodule update --init --recursive
  fi
}

describe_items() {
  local i
  for i in "`${!FILES_SOURCES[@]}"; do describe_link "`${FILES_SOURCES[`$i]}" "`${FILES_TARGETS[`$i]}"; done
  for i in "`${!SUBMODULE_SOURCES[@]}"; do describe_link "`${SUBMODULE_SOURCES[`$i]}" "`${SUBMODULE_TARGETS[`$i]}"; done
}

deploy_items() {
  local i
  prepare_deps
  for i in "`${!FILES_SOURCES[@]}"; do link_item "`${FILES_SOURCES[`$i]}" "`${FILES_TARGETS[`$i]}"; done
  for i in "`${!SUBMODULE_SOURCES[@]}"; do link_item "`${SUBMODULE_SOURCES[`$i]}" "`${SUBMODULE_TARGETS[`$i]}"; done
}

verify_items() {
  local i failed=0
  for i in "`${!FILES_SOURCES[@]}"; do verify_link "`${FILES_SOURCES[`$i]}" "`${FILES_TARGETS[`$i]}" || failed=1; done
  for i in "`${!SUBMODULE_SOURCES[@]}"; do verify_link "`${SUBMODULE_SOURCES[`$i]}" "`${SUBMODULE_TARGETS[`$i]}" || failed=1; done
  return "`$failed"
}

case "`${1:-}" in
  -h|--help|help) msg_line "用法：%s {describe|deploy|verify|help} [--en]" "Usage: %s {describe|deploy|verify|help} [--en]" "`$0" ;;
  describe) describe_items ;;
  deploy) deploy_items ;;
  verify) verify_items ;;
  *) if is_en; then die "usage: `$0 {describe|deploy|verify|help}"; else die "用法：`$0 {describe|deploy|verify|help}"; fi ;;
esac
"@
Set-Content -LiteralPath (Join-Path $ModuleDir "deploy.sh") -Value $deploySh -Encoding UTF8

$psFileItems = ($fileTargets | ForEach-Object {
    "    @{ Source = (Join-Path `$ModuleDir " + (ConvertTo-PsSingleQuoted ("files\" + $_.Replace('/', '\'))) + "); Target = " + (ConvertTo-PsSingleQuoted $_) + " }"
}) -join ",`n"
$psSubItems = for ($i = 0; $i -lt $submoduleSources.Count; $i++) {
    "    @{ Source = (Join-Path (Get-DotfilesRoot) " + (ConvertTo-PsSingleQuoted ($submoduleSources[$i].Replace('/', '\'))) + "); Target = " + (ConvertTo-PsSingleQuoted $submoduleTargets[$i]) + " }"
}
$psSubItems = $psSubItems -join ",`n"

$deployPs1 = @"
`$ErrorActionPreference = "Stop"
Import-Module (Join-Path `$PSScriptRoot "..\..\scripts\Dotfiles.psm1") -Force
`$ModuleDir = `$PSScriptRoot
`$ScriptArgs = @(`$args)
if (`$ScriptArgs.Count -gt 0 -and `$ScriptArgs[0] -eq "--en") {
    Set-DotfilesEnglish
    `$ScriptArgs = @(`$ScriptArgs | Select-Object -Skip 1)
}

`$FileItems = @(
$psFileItems
)
`$SubmoduleItems = @(
$psSubItems
)

function Show-Usage { Write-DotfilesMessage "用法：deploy.ps1 {describe|deploy|verify|help} [--en]" "Usage: deploy.ps1 {describe|deploy|verify|help} [--en]" }
function Initialize-Submodules {
    if (`$SubmoduleItems.Count -gt 0) {
        Write-DotfilesMessage "正在获取 submodule 依赖..." "Fetching submodule dependencies..."
        git -C (Get-DotfilesRoot) submodule update --init --recursive
    }
}

switch (`$ScriptArgs[0]) {
    "-h" { Show-Usage }
    "--help" { Show-Usage }
    "help" { Show-Usage }
    "describe" {
        foreach (`$item in `$FileItems) { Show-DotfileImpact `$item.Source `$item.Target }
        foreach (`$item in `$SubmoduleItems) { Show-DotfileImpact `$item.Source `$item.Target }
    }
    "deploy" {
        Initialize-Submodules
        foreach (`$item in `$FileItems) { Install-DotfileItem `$item.Source `$item.Target }
        foreach (`$item in `$SubmoduleItems) { Install-DotfileItem `$item.Source `$item.Target }
    }
    "verify" {
        `$failed = `$false
        foreach (`$item in `$FileItems) { if (-not (Test-DotfileItem `$item.Source `$item.Target)) { `$failed = `$true } }
        foreach (`$item in `$SubmoduleItems) { if (-not (Test-DotfileItem `$item.Source `$item.Target)) { `$failed = `$true } }
        if (`$failed) { throw (Get-DotfilesMessage "验证失败" "verification failed") }
    }
    default { Show-Usage; throw (Get-DotfilesMessage "未知阶段：`$(`$ScriptArgs[0])" "unknown phase: `$(`$ScriptArgs[0])") }
}
"@
Set-Content -LiteralPath (Join-Path $ModuleDir "deploy.ps1") -Value $deployPs1 -Encoding UTF8

Write-DotfilesMessage "模块已创建：$ModuleDir" "Module created: $ModuleDir"
Write-DotfilesMessage "可以运行 .\install.ps1 --dry-run 预览部署影响。" "Run .\install.ps1 --dry-run to preview deployment impact."
