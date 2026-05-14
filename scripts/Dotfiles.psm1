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

function Test-DotfilesForceRelink {
    return $env:DOTFILES_FORCE_RELINK -eq "1"
}

function Get-TargetPath {
    param([Parameter(Mandatory)] [string] $RelativePath)
    return (Join-Path (Get-DotfilesHome) $RelativePath)
}

function Backup-ExistingTarget {
    param(
        [Parameter(Mandatory)] [string] $Target,
        [string] $RelativePath = ""
    )

    $home = Get-DotfilesHome
    $relative = $RelativePath
    if (-not $relative) {
        $relative = $Target
    }
    if (-not $RelativePath -and $Target.StartsWith($home)) {
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

function Ensure-TargetParentDirectories {
    param([Parameter(Mandatory)] [string] $TargetRelativePath)

    $normalized = $TargetRelativePath.Replace('\', '/')
    $lastSlash = $normalized.LastIndexOf('/')
    if ($lastSlash -lt 0) {
        return
    }

    $current = ""
    foreach ($part in $normalized.Substring(0, $lastSlash).Split('/')) {
        if (-not $part) {
            continue
        }
        if ($current) {
            $current = "$current/$part"
        } else {
            $current = $part
        }

        $path = Get-TargetPath $current
        $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.LinkType -or (-not $item.PSIsContainer))) {
            Backup-ExistingTarget $path $current
            if (-not (Test-DotfilesDryRun)) {
                New-Item -ItemType Directory -Force -Path $path | Out-Null
            }
        }
    }
}

function Install-DotfileItem {
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $TargetRelativePath,
        [string] $TargetPath = ""
    )

    $target = if ($TargetPath) { $TargetPath } else { Get-TargetPath $TargetRelativePath }
    $sourcePath = (Resolve-Path $Source).Path
    if (-not $TargetPath) {
        Ensure-TargetParentDirectories $TargetRelativePath
    }
    $currentTarget = Get-LinkTarget $target

    if (($currentTarget -eq $sourcePath) -and -not (Test-DotfilesForceRelink)) {
        Write-DotfilesMessage "  无需变更：$TargetRelativePath" "  unchanged: $TargetRelativePath"
        return
    }

    if (Test-Path -LiteralPath $target) {
        Backup-ExistingTarget $target $TargetRelativePath
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
        [Parameter(Mandatory)] [string] $TargetRelativePath,
        [string] $TargetPath = ""
    )

    $target = if ($TargetPath) { $TargetPath } else { Get-TargetPath $TargetRelativePath }
    $sourcePath = $Source
    if (Test-Path -LiteralPath $Source) {
        $sourcePath = (Resolve-Path -LiteralPath $Source).Path
    }
    $currentTarget = Get-LinkTarget $target

    if (($currentTarget -eq $sourcePath) -and -not (Test-DotfilesForceRelink)) {
        Write-DotfilesMessage "  - ${TargetRelativePath}：已链接" "  - ${TargetRelativePath}: already linked"
    } elseif ($currentTarget -eq $sourcePath) {
        Write-DotfilesMessage "  - ${TargetRelativePath}：强制重新链接，先备份现有链接" "  - ${TargetRelativePath}: force relink, backup existing symlink first"
    } elseif (Test-Path -LiteralPath $target) {
        Write-DotfilesMessage "  - ${TargetRelativePath}：备份现有路径，然后创建链接或复制" "  - ${TargetRelativePath}: backup existing path, then link or copy"
    } else {
        Write-DotfilesMessage "  - ${TargetRelativePath}：创建链接或复制" "  - ${TargetRelativePath}: create link or copy"
    }
}

function Test-DotfileItem {
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $TargetRelativePath,
        [string] $TargetPath = ""
    )

    $target = if ($TargetPath) { $TargetPath } else { Get-TargetPath $TargetRelativePath }
    if (-not (Test-Path -LiteralPath $Source)) {
        Write-DotfilesMessage "  [失败] $TargetRelativePath" "  [FAIL] $TargetRelativePath"
        return $false
    }
    $sourcePath = (Resolve-Path -LiteralPath $Source).Path
    $currentTarget = Get-LinkTarget $target

    if (($currentTarget -eq $sourcePath) -or (Test-Path -LiteralPath $target)) {
        Write-DotfilesMessage "  [成功] $TargetRelativePath" "  [OK] $TargetRelativePath"
        return $true
    }

    Write-DotfilesMessage "  [失败] $TargetRelativePath" "  [FAIL] $TargetRelativePath"
    return $false
}

function Get-ModuleFileRootFor {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $RelativePath
    )

    $item = Get-Item -LiteralPath $Path -Force
    if (-not $item.PSIsContainer -or $item.LinkType) {
        return @($RelativePath.Replace('\', '/'))
    }

    $entries = @(Get-ChildItem -LiteralPath $Path -Force | Sort-Object Name)
    if ($entries.Count -eq 0) {
        return @($RelativePath.Replace('\', '/'))
    }

    $dirs = @($entries | Where-Object { $_.PSIsContainer -and -not $_.LinkType })
    $hasFile = @($entries | Where-Object { -not $_.PSIsContainer -or $_.LinkType }).Count -gt 0

    if ($hasFile) {
        return @($RelativePath.Replace('\', '/'))
    }
    if ($dirs.Count -eq 1) {
        return @(Get-ModuleFileRootFor $dirs[0].FullName (Join-Path $RelativePath $dirs[0].Name))
    }

    $roots = @()
    foreach ($dir in $dirs) {
        $roots += @(Get-ModuleFileRootFor $dir.FullName (Join-Path $RelativePath $dir.Name))
    }
    return $roots
}

function Get-DotfilesModuleFileRoots {
    param([Parameter(Mandatory)] [string] $ModuleDir)

    $filesDir = Join-Path $ModuleDir "files"
    if (-not (Test-Path -LiteralPath $filesDir -PathType Container)) {
        return @()
    }

    $roots = @()
    foreach ($entry in @(Get-ChildItem -LiteralPath $filesDir -Force | Sort-Object Name)) {
        $roots += @(Get-ModuleFileRootFor $entry.FullName $entry.Name)
    }
    return $roots
}

function Get-DotfilesModuleManifest {
    param([Parameter(Mandatory)] [string] $ModuleDir)

    $manifest = Join-Path $ModuleDir "dep\manifest.tsv"
    if (Test-Path -LiteralPath $manifest -PathType Leaf) {
        return $manifest
    }
    return $null
}

function Get-DotfilesModuleDeps {
    param([Parameter(Mandatory)] [string] $ModuleDir)

    $manifest = Get-DotfilesModuleManifest $ModuleDir
    if (-not $manifest) {
        return @()
    }

    $items = @()
    foreach ($line in Get-Content -LiteralPath $manifest) {
        if (-not $line -or $line.StartsWith("#")) {
            continue
        }
        $parts = $line -split "`t"
        if ($parts.Count -lt 2 -or -not $parts[0] -or -not $parts[1]) {
            throw (Get-DotfilesMessage "dep manifest 条目无效：$manifest" "invalid dep manifest entry: $manifest")
        }
        $items += [pscustomobject]@{
            Source = (Join-Path $ModuleDir $parts[0])
            Target = $parts[1]
        }
    }
    return $items
}

function Update-DotfilesModuleSubmodules {
    param([Parameter(Mandatory)] [string] $ModuleDir)

    if (-not (Get-DotfilesModuleManifest $ModuleDir)) {
        return
    }

    $root = Get-DotfilesRoot
    Write-DotfilesMessage "正在获取模块依赖..." "Fetching module dependencies..."

    foreach ($dep in Get-DotfilesModuleDeps $ModuleDir) {
        $sourcePath = $dep.Source
        $relative = $sourcePath.Substring($root.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
        $tracked = (& git -C $root ls-files --stage -- $relative) -match "160000"

        if ($tracked) {
            if (Test-DotfilesDryRun) {
                Write-DotfilesMessage "  将初始化 submodule：$relative" "  would initialize submodule: $relative"
                continue
            }
            Write-DotfilesMessage "  正在初始化 submodule：$relative" "  initializing submodule: $relative"
            git -C $root submodule update --init --recursive -- $relative
            continue
        }

        if ((Test-Path -LiteralPath $sourcePath -PathType Container) -and @(Get-ChildItem -LiteralPath $sourcePath -Force).Count -gt 0) {
            Write-DotfilesMessage "  依赖已存在：$relative" "  dependency already exists: $relative"
            continue
        }

        $url = & git -C $root config -f (Join-Path $root ".gitmodules") --get "submodule.$relative.url"
        if (-not $url) {
            throw (Get-DotfilesMessage "依赖缺失，且 .gitmodules 中未找到 URL：$relative" "dependency is missing and no .gitmodules URL was found for $relative")
        }

        if (Test-DotfilesDryRun) {
            Write-DotfilesMessage "  将克隆依赖：$url -> $relative" "  would clone dependency: $url -> $relative"
            continue
        }

        Write-DotfilesMessage "  正在克隆依赖：$relative" "  cloning dependency: $relative"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $sourcePath) | Out-Null
        git clone --recursive $url $sourcePath
    }
}

function Invoke-DotfilesModulePhase {
    param(
        [Parameter(Mandatory)] [string] $ModuleDir,
        [Parameter(Mandatory)] [string] $Phase
    )

    $filesDir = Join-Path $ModuleDir "files"
    switch ($Phase) {
        "-h" { Write-DotfilesMessage "用法：模块 {describe|deploy|verify|help} [--en]" "Usage: module {describe|deploy|verify|help} [--en]" }
        "--help" { Write-DotfilesMessage "用法：模块 {describe|deploy|verify|help} [--en]" "Usage: module {describe|deploy|verify|help} [--en]" }
        "help" { Write-DotfilesMessage "用法：模块 {describe|deploy|verify|help} [--en]" "Usage: module {describe|deploy|verify|help} [--en]" }
        "describe" {
            foreach ($rel in Get-DotfilesModuleFileRoots $ModuleDir) {
                Show-DotfileImpact (Join-Path $filesDir $rel.Replace('/', '\')) $rel
            }
            $sources = @()
            $targets = @()
            foreach ($dep in Get-DotfilesModuleDeps $ModuleDir) {
                $targetPath = Get-TargetPath $dep.Target
                for ($i = 0; $i -lt $targets.Count; $i++) {
                    $prefix = $targets[$i]
                    if ($dep.Target.StartsWith($prefix + "/")) {
                        $suffix = $dep.Target.Substring($prefix.Length + 1).Replace('/', '\')
                        $targetPath = Join-Path $sources[$i] $suffix
                    }
                }
                Show-DotfileImpact $dep.Source $dep.Target $targetPath
                $sources += $dep.Source
                $targets += $dep.Target
            }
        }
        "deploy" {
            Update-DotfilesModuleSubmodules $ModuleDir
            foreach ($rel in Get-DotfilesModuleFileRoots $ModuleDir) {
                Install-DotfileItem (Join-Path $filesDir $rel.Replace('/', '\')) $rel
            }
            $sources = @()
            $targets = @()
            foreach ($dep in Get-DotfilesModuleDeps $ModuleDir) {
                $targetPath = Get-TargetPath $dep.Target
                for ($i = 0; $i -lt $targets.Count; $i++) {
                    $prefix = $targets[$i]
                    if ($dep.Target.StartsWith($prefix + "/")) {
                        $suffix = $dep.Target.Substring($prefix.Length + 1).Replace('/', '\')
                        $targetPath = Join-Path $sources[$i] $suffix
                    }
                }
                Install-DotfileItem $dep.Source $dep.Target $targetPath
                $sources += $dep.Source
                $targets += $dep.Target
            }
        }
        "verify" {
            $failed = $false
            foreach ($rel in Get-DotfilesModuleFileRoots $ModuleDir) {
                if (-not (Test-DotfileItem (Join-Path $filesDir $rel.Replace('/', '\')) $rel)) {
                    $failed = $true
                }
            }
            $sources = @()
            $targets = @()
            foreach ($dep in Get-DotfilesModuleDeps $ModuleDir) {
                $targetPath = Get-TargetPath $dep.Target
                for ($i = 0; $i -lt $targets.Count; $i++) {
                    $prefix = $targets[$i]
                    if ($dep.Target.StartsWith($prefix + "/")) {
                        $suffix = $dep.Target.Substring($prefix.Length + 1).Replace('/', '\')
                        $targetPath = Join-Path $sources[$i] $suffix
                    }
                }
                if (-not (Test-DotfileItem $dep.Source $dep.Target $targetPath)) {
                    $failed = $true
                }
                $sources += $dep.Source
                $targets += $dep.Target
            }
            if ($failed) {
                throw (Get-DotfilesMessage "验证失败" "verification failed")
            }
        }
        default {
            Write-DotfilesMessage "用法：模块 {describe|deploy|verify|help} [--en]" "Usage: module {describe|deploy|verify|help} [--en]"
            throw (Get-DotfilesMessage "未知阶段：$Phase" "unknown phase: $Phase")
        }
    }
}
