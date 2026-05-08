$ErrorActionPreference = "Stop"

function Test-DotfilesEnglish {
    return $env:DOTFILES_LANG -eq "en"
}

function Set-DotfilesEnglish {
    $env:DOTFILES_LANG = "en"
}

function Write-DotfilesMessage {
    param(
        [Parameter(Mandatory)] [string] $Zh,
        [Parameter(Mandatory)] [string] $En
    )

    if (Test-DotfilesEnglish) {
        Write-Host $En
    } else {
        Write-Host $Zh
    }
}

function Get-DotfilesMessage {
    param(
        [Parameter(Mandatory)] [string] $Zh,
        [Parameter(Mandatory)] [string] $En
    )

    if (Test-DotfilesEnglish) {
        return $En
    }
    return $Zh
}

function Get-DotfilesRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Get-DotfilesHome {
    if ($env:DOTFILES_HOME) {
        return $env:DOTFILES_HOME
    }
    return $HOME
}

function Get-DotfilesBackupDir {
    if ($env:DOTFILES_BACKUP_DIR) {
        return $env:DOTFILES_BACKUP_DIR
    }
    $stamp = Get-Date -Format "yyyyMMddHHmmss"
    return (Join-Path (Get-DotfilesHome) ".dotfiles-backup\$stamp")
}

function Test-DotfilesDryRun {
    return $env:DOTFILES_DRY_RUN -eq "1"
}

function Get-TargetPath {
    param([Parameter(Mandatory)] [string] $RelativePath)
    return (Join-Path (Get-DotfilesHome) $RelativePath)
}

function Backup-ExistingTarget {
    param([Parameter(Mandatory)] [string] $Target)

    $home = Get-DotfilesHome
    $relative = $Target
    if ($Target.StartsWith($home)) {
        $relative = $Target.Substring($home.Length).TrimStart([char[]]@('\', '/'))
    }
    $backup = Join-Path (Get-DotfilesBackupDir) $relative

    if (Test-DotfilesDryRun) {
        Write-DotfilesMessage "  将备份：$Target -> $backup" "  would backup: $Target -> $backup"
        return
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
    Move-Item -Force -Path $Target -Destination $backup
    Write-DotfilesMessage "  已备份：$Target -> $backup" "  backed up: $Target -> $backup"
}

function Get-LinkTarget {
    param([Parameter(Mandatory)] [string] $Path)

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) {
        return $null
    }
    if ($item.LinkType) {
        return [string]$item.Target
    }
    return $null
}

function Install-DotfileItem {
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $TargetRelativePath
    )

    $target = Get-TargetPath $TargetRelativePath
    $sourcePath = (Resolve-Path $Source).Path
    $currentTarget = Get-LinkTarget $target

    if ($currentTarget -eq $sourcePath) {
        Write-DotfilesMessage "  无需变更：$TargetRelativePath" "  unchanged: $TargetRelativePath"
        return
    }

    if (Test-Path -LiteralPath $target) {
        Backup-ExistingTarget $target
    }

    if (Test-DotfilesDryRun) {
        Write-DotfilesMessage "  将创建链接或复制：$target -> $sourcePath" "  would link or copy: $target -> $sourcePath"
        return
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    try {
        if ((Get-Item -LiteralPath $sourcePath).PSIsContainer) {
            New-Item -ItemType Junction -Path $target -Target $sourcePath | Out-Null
        } else {
            New-Item -ItemType SymbolicLink -Path $target -Target $sourcePath | Out-Null
        }
        Write-DotfilesMessage "  已链接：$TargetRelativePath" "  linked: $TargetRelativePath"
    } catch {
        if ((Get-Item -LiteralPath $sourcePath).PSIsContainer) {
            Copy-Item -Recurse -Force -Path $sourcePath -Destination $target
        } else {
            Copy-Item -Force -Path $sourcePath -Destination $target
        }
        Write-DotfilesMessage "  已复制：$TargetRelativePath" "  copied: $TargetRelativePath"
    }
}

function Show-DotfileImpact {
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $TargetRelativePath
    )

    $target = Get-TargetPath $TargetRelativePath
    $sourcePath = (Resolve-Path $Source).Path
    $currentTarget = Get-LinkTarget $target

    if ($currentTarget -eq $sourcePath) {
        Write-DotfilesMessage "  - ${TargetRelativePath}：已链接" "  - ${TargetRelativePath}: already linked"
    } elseif (Test-Path -LiteralPath $target) {
        Write-DotfilesMessage "  - ${TargetRelativePath}：备份现有路径，然后创建链接或复制" "  - ${TargetRelativePath}: backup existing path, then link or copy"
    } else {
        Write-DotfilesMessage "  - ${TargetRelativePath}：创建链接或复制" "  - ${TargetRelativePath}: create link or copy"
    }
}

function Test-DotfileItem {
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $TargetRelativePath
    )

    $target = Get-TargetPath $TargetRelativePath
    $sourcePath = (Resolve-Path $Source).Path
    $currentTarget = Get-LinkTarget $target

    if (($currentTarget -eq $sourcePath) -or (Test-Path -LiteralPath $target)) {
        Write-DotfilesMessage "  [成功] $TargetRelativePath" "  [OK] $TargetRelativePath"
        return $true
    }

    Write-DotfilesMessage "  [失败] $TargetRelativePath" "  [FAIL] $TargetRelativePath"
    return $false
}
