$ErrorActionPreference = "Stop"
Import-Module (Join-Path $PSScriptRoot "..\..\scripts\Dotfiles.psm1") -Force
$ScriptArgs = @($args)
if ($ScriptArgs.Count -gt 0 -and $ScriptArgs[0] -eq "--en") {
    Set-DotfilesEnglish
    $ScriptArgs = @($ScriptArgs | Select-Object -Skip 1)
}

function Show-Usage {
    if (Test-DotfilesEnglish) {
        @"
Usage:
  deploy.ps1 describe  Show deployment impact
  deploy.ps1 deploy    Skip zsh on native Windows
  deploy.ps1 verify    Verify skipped zsh state
  deploy.ps1 --en      Output English prompts and logs
  deploy.ps1 --help    Show this help
"@ | Write-Host
    } else {
        @"
用法：
  deploy.ps1 describe  显示部署影响
  deploy.ps1 deploy    在原生 Windows 上跳过 zsh
  deploy.ps1 verify    验证 zsh 跳过状态
  deploy.ps1 --en      使用英文提示和日志
  deploy.ps1 --help    显示此帮助
"@ | Write-Host
    }
}

switch ($ScriptArgs[0]) {
    "-h" { Show-Usage }
    "--help" { Show-Usage }
    "help" { Show-Usage }
    "describe" { Write-DotfilesMessage "  - zsh：原生 Windows 上跳过；如需 zsh/oh-my-zsh 请使用 WSL 或 POSIX install.sh" "  - zsh: skipped on native Windows; use WSL or POSIX install.sh for zsh/oh-my-zsh" }
    "deploy" { Write-DotfilesMessage "  已在原生 Windows 上跳过 zsh" "  skipped zsh on native Windows" }
    "verify" { Write-DotfilesMessage "  [成功] zsh 已在原生 Windows 上跳过" "  [OK] zsh skipped on native Windows" }
    default { Show-Usage; throw (Get-DotfilesMessage "未知阶段：$($ScriptArgs[0])" "unknown phase: $($ScriptArgs[0])") }
}
