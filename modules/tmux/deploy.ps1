$ErrorActionPreference = "Stop"
Import-Module (Join-Path $PSScriptRoot "..\..\scripts\Dotfiles.psm1") -Force
$ModuleDir = $PSScriptRoot
$ScriptArgs = @($args)
if ($ScriptArgs.Count -gt 0 -and $ScriptArgs[0] -eq "--en") {
    Set-DotfilesEnglish
    $ScriptArgs = @($ScriptArgs | Select-Object -Skip 1)
}

function Show-Usage { Write-DotfilesMessage "用法：deploy.ps1 {describe|deploy|verify|help} [--en]" "Usage: deploy.ps1 {describe|deploy|verify|help} [--en]" }

switch ($ScriptArgs[0]) {
    "-h" { Show-Usage }
    "--help" { Show-Usage }
    "help" { Show-Usage }
    "describe" {
        Show-DotfileImpact (Join-Path $ModuleDir "files\.tmux.conf") ".tmux.conf"
        Show-DotfileImpact (Join-Path $ModuleDir "files\.tmux") ".tmux"
    }
    "deploy" {
        Install-DotfileItem (Join-Path $ModuleDir "files\.tmux.conf") ".tmux.conf"
        Install-DotfileItem (Join-Path $ModuleDir "files\.tmux") ".tmux"
    }
    "verify" {
        $ok = (Test-DotfileItem (Join-Path $ModuleDir "files\.tmux.conf") ".tmux.conf")
        $ok = (Test-DotfileItem (Join-Path $ModuleDir "files\.tmux") ".tmux") -and $ok
        if (-not $ok) { throw (Get-DotfilesMessage "验证失败" "verification failed") }
    }
    default { Show-Usage; throw (Get-DotfilesMessage "未知阶段：$($ScriptArgs[0])" "unknown phase: $($ScriptArgs[0])") }
}
