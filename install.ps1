$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot
Import-Module (Join-Path $Root "scripts\Dotfiles.psm1") -Force

function Show-Usage {
    if (Test-DotfilesEnglish) {
        @"
Usage:
  .\install.ps1             Interactive deployment
  .\install.ps1 --all       Deploy all modules
  .\install.ps1 --dry-run   Preview selected module impact without changing files
  .\install.ps1 --all --dry-run
                            Preview all module impact without changing files
  .\install.ps1 --en        Output English prompts and logs
  .\install.ps1 -h|--help   Show this help

Use Space to select modules and Enter to deploy in interactive mode.
Environment:
  DOTFILES_HOME             Override deployment home directory
  DOTFILES_BACKUP_DIR       Override backup directory
  DOTFILES_DRY_RUN=1        Preview changes without writing
"@ | Write-Host
    } else {
        @"
用法：
  .\install.ps1             交互式部署
  .\install.ps1 --all       部署所有模块
  .\install.ps1 --dry-run   仅预览已选择模块的影响，不修改文件
  .\install.ps1 --all --dry-run
                            仅预览所有模块影响，不修改文件
  .\install.ps1 --en        使用英文提示和日志
  .\install.ps1 -h|--help   显示此帮助

交互模式中使用空格选择模块，回车确认开始部署。
环境变量：
  DOTFILES_HOME             覆盖部署目标 HOME 目录
  DOTFILES_BACKUP_DIR       覆盖备份目录
  DOTFILES_DRY_RUN=1        仅预览，不写入
"@ | Write-Host
    }
}

$DeployAll = $false
$DryRun = $false
foreach ($arg in $args) {
    if ($arg -eq "--en") {
        Set-DotfilesEnglish
        break
    }
}
foreach ($arg in $args) {
    switch ($arg) {
        "--all" { $DeployAll = $true }
        "--dry-run" { $DryRun = $true; $env:DOTFILES_DRY_RUN = "1" }
        "--en" { Set-DotfilesEnglish }
        "-h" { Show-Usage; exit 0 }
        "--help" { Show-Usage; exit 0 }
        "/?" { Show-Usage; exit 0 }
        default { throw (Get-DotfilesMessage "未知参数：$arg" "Unknown argument: $arg") }
    }
}

if (-not $env:DOTFILES_BACKUP_DIR) {
    $env:DOTFILES_BACKUP_DIR = Get-DotfilesBackupDir
}
if (-not $env:DOTFILES_HOME) {
    $env:DOTFILES_HOME = Get-DotfilesHome
}

function Get-Modules {
    Get-ChildItem -Directory (Join-Path $Root "modules") |
        Where-Object { Test-Path (Join-Path $_.FullName "deploy.ps1") } |
        Sort-Object Name
}

function Select-Modules {
    param([Parameter(Mandatory)] [array] $Modules)

    $selected = @{}
    $cursor = 0
    foreach ($module in $Modules) {
        $selected[$module.Name] = $false
    }

while ($true) {
        Clear-Host
        Write-DotfilesMessage "选择要部署的 dotfile 模块。空格切换选择，回车确认。`n" "Select dotfile modules to deploy. Space toggles, Enter confirms.`n"
        for ($i = 0; $i -lt $Modules.Count; $i++) {
            $pointer = if ($i -eq $cursor) { ">" } else { " " }
            $mark = if ($selected[$Modules[$i].Name]) { "x" } else { " " }
            Write-Host "$pointer [$mark] $($Modules[$i].Name)"
        }

        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        switch ($key.VirtualKeyCode) {
            13 { return @($Modules | Where-Object { $selected[$_.Name] }) }
            32 { $selected[$Modules[$cursor].Name] = -not $selected[$Modules[$cursor].Name] }
            38 { if ($cursor -gt 0) { $cursor-- } }
            40 { if ($cursor -lt ($Modules.Count - 1)) { $cursor++ } }
        }
    }
}

$modules = @(Get-Modules)
if ($modules.Count -eq 0) {
    throw (Get-DotfilesMessage "未找到可部署的 PowerShell 模块。" "No deployable PowerShell modules found.")
}

$selected = if ($DeployAll) { $modules } else { Select-Modules $modules }
if ($selected.Count -eq 0) {
    throw (Get-DotfilesMessage "未选择任何模块。" "No modules selected.")
}

Write-Host ""
Write-DotfilesMessage "部署影响：" "Deployment impact:"
Write-DotfilesMessage "  HOME：$(Get-DotfilesHome)" "  home: $(Get-DotfilesHome)"
Write-DotfilesMessage "  备份：$(Get-DotfilesBackupDir)" "  backup: $(Get-DotfilesBackupDir)"
foreach ($module in $selected) {
    Write-Host ""
    Write-Host "[$($module.Name)]"
    & (Join-Path $module.FullName "deploy.ps1") describe
}

Write-Host ""
if ($env:DOTFILES_DRY_RUN -eq "1") {
    Write-DotfilesMessage "预览完成。" "Dry-run completed."
    exit 0
}

Read-Host (Get-DotfilesMessage "按回车开始部署，或按 Ctrl-C 取消" "Press Enter to start deployment, or Ctrl-C to cancel")

foreach ($module in $selected) {
    Write-Host ""
    Write-DotfilesMessage "正在部署 $($module.Name)..." "Deploying $($module.Name)..."
    & (Join-Path $module.FullName "deploy.ps1") deploy
}

Write-Host ""
Write-DotfilesMessage "验证结果：" "Verification:"
foreach ($module in $selected) {
    Write-Host "[$($module.Name)]"
    & (Join-Path $module.FullName "deploy.ps1") verify
}

Write-Host ""
Write-DotfilesMessage "部署完成。" "Deployment completed."
