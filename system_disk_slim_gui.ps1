[CmdletBinding()]
param(
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:Version = "1.3"
$script:Language = "zh"
$script:ModeOrder = @("safe", "advanced", "scan")
$script:ToolRoot = $PSScriptRoot
$script:ConfigPath = Join-Path -Path $script:ToolRoot -ChildPath "cleanup_targets.json"
$script:TranslationsPath = Join-Path -Path $script:ToolRoot -ChildPath "translations.json"
$script:ExportsRoot = Join-Path -Path $script:ToolRoot -ChildPath "exports"
$script:ProtectedRootTemplates = @(
    "%WINDIR%\\System32",
    "%WINDIR%\\SysWOW64",
    "%WINDIR%\\servicing",
    "%WINDIR%\\Installer",
    "%WINDIR%\\Boot",
    "%WINDIR%\\WinSxS",
    "%ProgramFiles%",
    "%ProgramFiles(x86)%",
    "%SystemDrive%\\System Volume Information",
    "%SystemDrive%\\Recovery"
)

try {
    $script:Translations = Get-Content -LiteralPath $script:TranslationsPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
catch {
    Write-Error ("Failed to load translations: " + $_.Exception.Message)
    exit 1
}

$script:TargetConfig = $null
$script:ProtectedRoots = @()
$script:SupportedTargetTypes = @("directory_contents", "directory_glob_contents", "file_pattern", "empty_directories")
$script:SupportedRiskLevels = @("Low", "Medium", "High")
$script:SupportedLanguages = @("zh", "en", "ja")

function T {
    param([string]$Key)
    return $script:Translations.$($script:Language).$Key
}

function Get-AppTitle {
    return ("{0} v{1}" -f (T "app_title"), $script:Version)
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restart-ElevatedGui {
    $scriptPath = $PSCommandPath
    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-STA", "-File", ('"{0}"' -f $scriptPath))
    try {
        Start-Process -FilePath "powershell.exe" -Verb RunAs -WindowStyle Hidden -WorkingDirectory $script:ToolRoot -ArgumentList $args | Out-Null
        return $true
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show((T "auto_elevate_failed"), (T "info_title"), [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return $false
    }
}

function Format-Size {
    param([Int64]$Bytes)
    if ($Bytes -lt 1KB) { return "$Bytes B" }
    if ($Bytes -lt 1MB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }
    if ($Bytes -lt 1GB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    return ('{0:N2} GB' -f ($Bytes / 1GB))
}

function Format-ItemCount {
    param(
        [int]$Count,
        [string]$Kind = "items"
    )
    $key = "count_{0}" -f $Kind
    $template = T $key
    if ([string]::IsNullOrWhiteSpace($template)) {
        $template = T "count_items"
    }
    if ([string]::IsNullOrWhiteSpace($template)) {
        return ("{0} item(s)" -f $Count)
    }
    return [string]::Format($template, $Count)
}

function Get-DisplaySizeText {
    param(
        [Int64]$SizeBytes,
        [int]$ItemCount,
        [string]$CountKind = "items"
    )
    if ($SizeBytes -gt 0) {
        return Format-Size $SizeBytes
    }
    if ($ItemCount -gt 0) {
        return Format-ItemCount -Count $ItemCount -Kind $CountKind
    }
    return Format-Size 0
}

function Test-HasActionableMetrics {
    param($Metrics)
    if ($null -eq $Metrics) { return $false }
    return ($Metrics.SizeBytes -gt 0) -or ($Metrics.ItemCount -gt 0)
}

function Get-TargetMetrics {
    param($Target)
    $type = [string]$Target.Type
    switch ($type) {
        'directory_contents' {
            $size = Get-TargetSize $Target
            $itemCount = if ($size -gt 0) { 1 } else { 0 }
            return [pscustomobject]@{
                SizeBytes   = [Int64]$size
                ItemCount   = $itemCount
                CountKind   = 'items'
                DisplaySize = Get-DisplaySizeText -SizeBytes $size -ItemCount $itemCount -CountKind 'items'
            }
        }
        'directory_glob_contents' {
            $dirs = @(Resolve-DirectoryGlobs (Get-TargetPaths $Target))
            $size = 0L
            foreach ($dir in $dirs) {
                $size += Get-DirectoryContentsSize $dir.FullName
            }
            return [pscustomobject]@{
                SizeBytes   = [Int64]$size
                ItemCount   = $dirs.Count
                CountKind   = 'folders'
                DisplaySize = Get-DisplaySizeText -SizeBytes $size -ItemCount $dirs.Count -CountKind 'folders'
            }
        }
        'file_pattern' {
            $matches = @(Get-FilePatternMatches $Target)
            $sum = ($matches | Measure-Object -Property Length -Sum).Sum
            if ($null -eq $sum) { $sum = 0L }
            return [pscustomobject]@{
                SizeBytes   = [Int64]$sum
                ItemCount   = $matches.Count
                CountKind   = 'files'
                DisplaySize = Get-DisplaySizeText -SizeBytes $sum -ItemCount $matches.Count -CountKind 'files'
            }
        }
        'empty_directories' {
            $count = @(Get-EmptyDirectoryMatches $Target).Count
            return [pscustomobject]@{
                SizeBytes   = 0L
                ItemCount   = $count
                CountKind   = 'folders'
                DisplaySize = Get-DisplaySizeText -SizeBytes 0 -ItemCount $count -CountKind 'folders'
            }
        }
        default {
            return [pscustomobject]@{
                SizeBytes   = 0L
                ItemCount   = 0
                CountKind   = 'items'
                DisplaySize = Format-Size 0
            }
        }
    }
}

function Get-RowDisplaySize {
    param($Row)
    if ($null -ne $Row -and $Row.PSObject.Properties.Name -contains 'DisplaySize' -and -not [string]::IsNullOrWhiteSpace([string]$Row.DisplaySize)) {
        return [string]$Row.DisplaySize
    }
    $sizeBytes = 0L
    if ($null -ne $Row -and $Row.PSObject.Properties.Name -contains 'SizeBytes') {
        $sizeBytes = [Int64]$Row.SizeBytes
    }
    return Format-Size $sizeBytes
}

function New-ResultRow {
    param(
        $Target,
        [Int64]$SizeBytes,
        [int]$ItemCount,
        [string]$DisplaySize,
        $Source,
        [bool]$Selected = $true
    )
    return [pscustomobject]@{
        Selected    = $Selected
        Name        = $Target.Name
        Path        = Get-TargetPathSummary $Target
        Risk        = $Target.Risk
        RiskNote    = $Target.RiskNote
        SizeBytes   = [Int64]$SizeBytes
        ItemCount   = [int]$ItemCount
        DisplaySize = $DisplaySize
        Type        = $Target.Type
        Source      = $Source
    }
}

function Resolve-TargetPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    return [Environment]::ExpandEnvironmentVariables($Path)
}

function Normalize-Path {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    try {
        $resolved = Resolve-TargetPath $Path
        if ([string]::IsNullOrWhiteSpace($resolved)) { return $null }
        return [System.IO.Path]::GetFullPath($resolved).TrimEnd('\\')
    }
    catch {
        return $null
    }
}

function Get-ProtectedRoots {
    if ($script:ProtectedRoots.Count -gt 0) { return $script:ProtectedRoots }
    $roots = @()
    foreach ($item in $script:ProtectedRootTemplates) {
        $normalized = Normalize-Path $item
        if (-not [string]::IsNullOrWhiteSpace($normalized)) {
            $roots += $normalized
        }
    }
    $script:ProtectedRoots = $roots | Sort-Object -Unique
    return $script:ProtectedRoots
}

function Test-IsProtectedPath {
    param([string]$Path)
    $normalized = Normalize-Path $Path
    if ([string]::IsNullOrWhiteSpace($normalized)) { return $false }
    foreach ($root in Get-ProtectedRoots) {
        if ($normalized -ieq $root) { return $true }
        if ($normalized.StartsWith($root + "\\", [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Test-IsReparsePoint {
    param([System.IO.FileSystemInfo]$Item)
    if ($null -eq $Item) { return $false }
    return [bool]($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
}

function Get-LastWriteCutoff {
    param($Target)
    if ($null -eq $Target.MinAgeDays) { return $null }
    $days = 0
    if (-not [int]::TryParse([string]$Target.MinAgeDays, [ref]$days)) { return $null }
    if ($days -le 0) { return $null }
    return (Get-Date).AddDays(-1 * $days)
}

function Test-ItemAge {
    param(
        [System.IO.FileSystemInfo]$Item,
        [Nullable[datetime]]$Cutoff
    )
    if ($null -eq $Cutoff) { return $true }
    return $Item.LastWriteTime -le $Cutoff.Value
}

function Get-TargetPaths {
    param($Target)
    $paths = @()
    if ($Target.PSObject.Properties.Name -contains 'Paths') {
        $paths += @($Target.Paths)
    }
    if ($Target.PSObject.Properties.Name -contains 'Path' -and -not [string]::IsNullOrWhiteSpace($Target.Path)) {
        $paths += @($Target.Path)
    }
    return @($paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-TargetPathSummary {
    param($Target)
    $paths = @(Get-TargetPaths $Target | ForEach-Object { Resolve-TargetPath $_ })
    if ($paths.Count -eq 0) { return $null }
    if ($paths.Count -eq 1) { return $paths[0] }
    return ($paths[0] + " (+" + ($paths.Count - 1) + ")")
}

function Get-ChildItemsSafe {
    param(
        [string]$Path,
        [switch]$Recurse,
        [switch]$IncludeDirectories
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return @() }
    if (-not (Test-Path -LiteralPath $Path)) { return @() }

    $items = @()
    try {
        if ($IncludeDirectories) {
            $items = @(Get-ChildItem -LiteralPath $Path -Force -Recurse:$Recurse -Directory -ErrorAction SilentlyContinue)
        }
        else {
            $items = @(Get-ChildItem -LiteralPath $Path -Force -Recurse:$Recurse -File -ErrorAction SilentlyContinue)
        }
    }
    catch {
        return @()
    }

    return @($items | Where-Object {
            -not (Test-IsReparsePoint $_) -and -not (Test-IsProtectedPath $_.FullName)
        })
}

function Resolve-DirectoryGlobs {
    param([string[]]$Patterns)
    $dirs = @()
    foreach ($pattern in @($Patterns)) {
        $resolvedPattern = Resolve-TargetPath $pattern
        if ([string]::IsNullOrWhiteSpace($resolvedPattern)) { continue }
        try {
            $dirs += @(Get-ChildItem -Path $resolvedPattern -Force -Directory -ErrorAction SilentlyContinue)
        }
        catch {
            continue
        }
    }
    return @($dirs | Where-Object {
            -not (Test-IsReparsePoint $_) -and -not (Test-IsProtectedPath $_.FullName)
        } | Sort-Object FullName -Unique)
}

function Get-DirectoryContentsSize {
    param([string]$Path)
    $files = Get-ChildItemsSafe -Path $Path -Recurse -IncludeDirectories:$false
    $sum = ($files | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { return 0L }
    return [Int64]$sum
}

function Get-FilePatternMatches {
    param($Target)
    $matches = @()
    $includes = @($Target.Include)
    if ($includes.Count -eq 0) { $includes = @('*') }
    $cutoff = Get-LastWriteCutoff $Target
    $zeroByteOnly = [bool]$Target.ZeroByteOnly
    $recurse = [bool]$Target.Recurse

    foreach ($basePath in Get-TargetPaths $Target) {
        $resolvedBase = Resolve-TargetPath $basePath
        foreach ($file in Get-ChildItemsSafe -Path $resolvedBase -Recurse:$recurse -IncludeDirectories:$false) {
            if (-not (Test-ItemAge -Item $file -Cutoff $cutoff)) { continue }
            if ($zeroByteOnly -and $file.Length -ne 0) { continue }
            $isMatch = $false
            foreach ($pattern in $includes) {
                if ($file.Name -like $pattern) {
                    $isMatch = $true
                    break
                }
            }
            if ($isMatch) {
                $matches += $file
            }
        }
    }

    return @($matches | Sort-Object FullName -Unique)
}

function Get-EmptyDirectoryMatches {
    param($Target)
    $matches = @()
    foreach ($basePath in Get-TargetPaths $Target) {
        $resolvedBase = Resolve-TargetPath $basePath
        foreach ($dir in Get-ChildItemsSafe -Path $resolvedBase -Recurse -IncludeDirectories) {
            if ($dir.FullName -ieq (Normalize-Path $resolvedBase)) { continue }
            $hasChildren = @(Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue).Count -gt 0
            if (-not $hasChildren) {
                $matches += $dir
            }
        }
    }
    return @($matches | Sort-Object FullName -Unique)
}

function Get-TargetItems {
    param($Target)
    $type = [string]$Target.Type
    switch ($type) {
        'directory_contents' {
            $items = @()
            foreach ($path in Get-TargetPaths $Target) {
                $resolved = Resolve-TargetPath $path
                if ([string]::IsNullOrWhiteSpace($resolved)) { continue }
                if (Test-IsProtectedPath $resolved) { continue }
                $items += [pscustomobject]@{ Path = $resolved }
            }
            return $items
        }
        'directory_glob_contents' {
            return @(Resolve-DirectoryGlobs (Get-TargetPaths $Target) | ForEach-Object { [pscustomobject]@{ Path = $_.FullName } })
        }
        'file_pattern' {
            return @(Get-FilePatternMatches $Target)
        }
        'empty_directories' {
            return @(Get-EmptyDirectoryMatches $Target)
        }
        default {
            return @()
        }
    }
}

function Get-TargetSize {
    param($Target)
    $type = [string]$Target.Type
    switch ($type) {
        'directory_contents' {
            $total = 0L
            foreach ($path in Get-TargetPaths $Target) {
                $resolved = Resolve-TargetPath $path
                if ([string]::IsNullOrWhiteSpace($resolved)) { continue }
                $total += Get-DirectoryContentsSize $resolved
            }
            return $total
        }
        'directory_glob_contents' {
            $total = 0L
            foreach ($dir in Resolve-DirectoryGlobs (Get-TargetPaths $Target)) {
                $total += Get-DirectoryContentsSize $dir.FullName
            }
            return $total
        }
        'file_pattern' {
            $sum = (Get-FilePatternMatches $Target | Measure-Object -Property Length -Sum).Sum
            if ($null -eq $sum) { return 0L }
            return [Int64]$sum
        }
        'empty_directories' {
            return [Int64]@(Get-EmptyDirectoryMatches $Target).Count
        }
        default {
            return 0L
        }
    }
}

function Remove-TargetItems {
    param($Target)
    $freed = 0L
    $failed = 0
    $removed = 0
    $type = [string]$Target.Type
    $items = @(Get-TargetItems $Target)
    $issues = @()

    foreach ($item in $items) {
        $fullPath = $item.FullName
        if ([string]::IsNullOrWhiteSpace($fullPath)) { $fullPath = $item.Path }
        if ([string]::IsNullOrWhiteSpace($fullPath)) {
            $failed++
            $issues += [pscustomobject]@{ Path = '<empty>'; Reason = 'empty_path' }
            continue
        }
        if (Test-IsProtectedPath $fullPath) {
            $failed++
            $issues += [pscustomobject]@{ Path = $fullPath; Reason = 'protected_path' }
            continue
        }
        if (-not (Test-Path -LiteralPath $fullPath)) {
            $failed++
            $issues += [pscustomobject]@{ Path = $fullPath; Reason = 'path_not_found' }
            continue
        }
        try {
            if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
                $length = (Get-Item -LiteralPath $fullPath -Force -ErrorAction Stop).Length
                Remove-Item -LiteralPath $fullPath -Force -ErrorAction Stop
                if (-not (Test-Path -LiteralPath $fullPath)) {
                    $freed += [Int64]$length
                    $removed++
                }
                else {
                    $failed++
                    $issues += [pscustomobject]@{ Path = $fullPath; Reason = 'delete_failed' }
                }
            }
            elseif (Test-Path -LiteralPath $fullPath -PathType Container) {
                if ($type -eq 'empty_directories') {
                    $before = @(Get-ChildItem -LiteralPath $fullPath -Force -ErrorAction SilentlyContinue).Count
                    if ($before -eq 0) {
                        Remove-Item -LiteralPath $fullPath -Force -ErrorAction Stop
                        if (-not (Test-Path -LiteralPath $fullPath)) {
                            $removed++
                        }
                        else {
                            $failed++
                            $issues += [pscustomobject]@{ Path = $fullPath; Reason = 'delete_failed' }
                        }
                    }
                    else {
                        $failed++
                        $issues += [pscustomobject]@{ Path = $fullPath; Reason = 'directory_not_empty' }
                    }
                }
                else {
                    $children = @(Get-ChildItem -LiteralPath $fullPath -Force -ErrorAction SilentlyContinue)
                    foreach ($child in $children) {
                        if (Test-IsProtectedPath $child.FullName) {
                            $failed++
                            $issues += [pscustomobject]@{ Path = $child.FullName; Reason = 'protected_path' }
                            continue
                        }
                        $childBytes = 0L
                        if ($child.PSIsContainer) {
                            $childBytes = Get-DirectoryContentsSize $child.FullName
                        }
                        else {
                            $childBytes = [Int64]$child.Length
                        }
                        try {
                            Remove-Item -LiteralPath $child.FullName -Recurse -Force -ErrorAction Stop
                            if (-not (Test-Path -LiteralPath $child.FullName)) {
                                $freed += $childBytes
                                $removed++
                            }
                            else {
                                $failed++
                                $issues += [pscustomobject]@{ Path = $child.FullName; Reason = 'delete_failed' }
                            }
                        }
                        catch {
                            $failed++
                            $issues += [pscustomobject]@{ Path = $child.FullName; Reason = $_.Exception.Message }
                        }
                    }
                }
            }
        }
        catch {
            $failed++
            $issues += [pscustomobject]@{ Path = $fullPath; Reason = $_.Exception.Message }
        }
    }

    return [pscustomobject]@{
        Freed        = $freed
        FailedCount  = $failed
        RemovedCount = $removed
        Issues       = @($issues)
    }
}

function Get-RemovalCountKind {
    param([string]$TargetType)
    switch ($TargetType) {
        'empty_directories' { return 'folders' }
        'file_pattern' { return 'files' }
        default { return 'items' }
    }
}

function Format-IssueReason {
    param([string]$Reason)
    switch ($Reason) {
        'empty_path' { return 'empty_path' }
        'protected_path' { return T 'issue_reason_protected_path' }
        'path_not_found' { return T 'issue_reason_path_not_found' }
        'delete_failed' { return T 'issue_reason_delete_failed' }
        'directory_not_empty' { return T 'issue_reason_directory_not_empty' }
        default { return $Reason }
    }
}

function Add-LogCleanupIssues {
    param(
        [string]$TargetName,
        [array]$Issues
    )
    if ($null -eq $Issues -or $Issues.Count -eq 0) { return }
    $maxIssueLogs = 5
    $take = [Math]::Min($Issues.Count, $maxIssueLogs)
    for ($i = 0; $i -lt $take; $i++) {
        $issue = $Issues[$i]
        Add-Log ([string]::Format((T 'cleanup_issue_detail'), $TargetName, $issue.Path, (Format-IssueReason $issue.Reason)))
    }
    if ($Issues.Count -gt $maxIssueLogs) {
        Add-Log ([string]::Format((T 'cleanup_issue_more'), $TargetName, ($Issues.Count - $maxIssueLogs)))
    }
}

function Get-RiskLabel {
    param([string]$Risk)
    switch ($Risk) {
        "Low" { return (T "risk_low") }
        "Medium" { return (T "risk_medium") }
        "High" { return (T "risk_high") }
        default { return $Risk }
    }
}

function Get-RiskNoteText {
    param([string]$RiskNote)
    $key = "risk_note_{0}" -f $RiskNote
    $value = T $key
    if ([string]::IsNullOrWhiteSpace($value)) { return $RiskNote }
    return $value
}

function Get-AllConfiguredTargets {
    param($Config)
    $allTargets = @()
    foreach ($sectionName in @('safe', 'advanced', 'scanOnly')) {
        if ($Config.PSObject.Properties.Name -contains $sectionName) {
            foreach ($target in @($Config.$sectionName)) {
                $allTargets += [pscustomobject]@{
                    Section = $sectionName
                    Target  = $target
                }
            }
        }
    }
    return $allTargets
}

function Test-TargetHasConfiguredPaths {
    param($Target)
    return (Get-TargetPaths $Target).Count -gt 0
}

function Validate-TargetDefinition {
    param(
        $Target,
        [string]$Section,
        [int]$Index
    )

    $label = "{0}[{1}]" -f $Section, $Index

    if ([string]::IsNullOrWhiteSpace([string]$Target.Name)) {
        throw "Target $label is missing Name."
    }
    if ([string]::IsNullOrWhiteSpace([string]$Target.Type)) {
        throw "Target '$($Target.Name)' in $label is missing Type."
    }
    if ($script:SupportedTargetTypes -notcontains [string]$Target.Type) {
        throw "Target '$($Target.Name)' in $label uses unsupported Type '$($Target.Type)'. Supported types: $($script:SupportedTargetTypes -join ', ')."
    }
    if ([string]::IsNullOrWhiteSpace([string]$Target.Risk)) {
        throw "Target '$($Target.Name)' in $label is missing Risk."
    }
    if ($script:SupportedRiskLevels -notcontains [string]$Target.Risk) {
        throw "Target '$($Target.Name)' in $label uses unsupported Risk '$($Target.Risk)'. Supported risks: $($script:SupportedRiskLevels -join ', ')."
    }
    if ([string]::IsNullOrWhiteSpace([string]$Target.RiskNote)) {
        throw "Target '$($Target.Name)' in $label is missing RiskNote."
    }
    if (-not (Test-TargetHasConfiguredPaths $Target)) {
        throw "Target '$($Target.Name)' in $label does not define Path or Paths."
    }

    switch ([string]$Target.Type) {
        'file_pattern' {
            if ($Target.PSObject.Properties.Name -contains 'Include' -and @($Target.Include).Count -eq 0) {
                throw "Target '$($Target.Name)' in $label has an empty Include list."
            }
        }
        'directory_glob_contents' {
            $paths = @(Get-TargetPaths $Target)
            if ($paths.Count -eq 0) {
                throw "Target '$($Target.Name)' in $label must define at least one glob path."
            }
        }
    }
}

function Validate-TranslationCoverage {
    param($Config)
    $allTargets = @(Get-AllConfiguredTargets $Config)
    $requiredRiskNoteKeys = @($allTargets | ForEach-Object { "risk_note_{0}" -f $_.Target.RiskNote } | Sort-Object -Unique)
    $requiredCommonKeys = @(
        'app_title', 'title', 'description', 'language', 'mode', 'mode_safe', 'mode_advanced', 'mode_scan',
        'scan', 'cleanup', 'export_log', 'save_scan', 'select_all', 'clear_selection', 'ready', 'status_found',
        'status_cleaned', 'selection_summary', 'log', 'scan_only_notice', 'no_data', 'no_selection',
        'advanced_warning', 'confirm_cleanup', 'info_title', 'warn_title', 'confirm_title', 'auto_elevate_failed',
        'config_load_failed', 'translations_load_failed', 'target_selected', 'target_name', 'target_risk',
        'target_risk_note', 'target_size', 'target_path', 'risk_low', 'risk_medium', 'risk_high',
        'count_items', 'count_files', 'count_folders', 'tool_launched', 'tool_hint', 'detected_apps',
        'scan_started', 'scan_completed', 'cleaning_item', 'cleanup_item_result', 'cleanup_partial_failed',
        'cleanup_completed', 'cleanup_issue_detail', 'cleanup_issue_more', 'issue_reason_protected_path',
        'issue_reason_path_not_found', 'issue_reason_delete_failed', 'issue_reason_directory_not_empty',
        'scan_saved', 'log_saved', 'mode_changed'
    )
    $requiredKeys = @($requiredCommonKeys + $requiredRiskNoteKeys | Sort-Object -Unique)

    foreach ($lang in $script:SupportedLanguages) {
        if (-not ($script:Translations.PSObject.Properties.Name -contains $lang)) {
            throw "Translations are missing language section '$lang'."
        }
        $langTable = $script:Translations.$lang
        foreach ($key in $requiredKeys) {
            $value = $langTable.$key
            if ([string]::IsNullOrWhiteSpace([string]$value)) {
                throw "Translations are missing key '$key' for language '$lang'."
            }
        }
    }
}

function Validate-LoadedConfiguration {
    param($Config)

    foreach ($sectionName in @('safe', 'advanced', 'scanOnly')) {
        if (-not ($Config.PSObject.Properties.Name -contains $sectionName)) {
            throw "Config is missing section '$sectionName'."
        }
        $targets = @($Config.$sectionName)
        for ($i = 0; $i -lt $targets.Count; $i++) {
            Validate-TargetDefinition -Target $targets[$i] -Section $sectionName -Index $i
        }
    }

    Validate-TranslationCoverage -Config $Config
}

function Load-TargetConfig {
    if (-not (Test-Path -LiteralPath $script:ConfigPath)) {
        throw "Config file not found: $($script:ConfigPath)"
    }
    $raw = Get-Content -LiteralPath $script:ConfigPath -Raw -Encoding UTF8
    return $raw | ConvertFrom-Json
}

function Get-ModeTargets {
    param([string]$Mode)

    if ($null -eq $script:TargetConfig) {
        $script:TargetConfig = Load-TargetConfig
    }

    $safe = @($script:TargetConfig.safe)
    $advanced = @($script:TargetConfig.advanced)
    $scanOnly = @($script:TargetConfig.scanOnly)

    switch ($Mode) {
        "safe" { return $safe }
        "advanced" { return ($safe + $advanced) }
        "scan" { return ($safe + $advanced + $scanOnly) }
        default { return $safe }
    }
}

function Get-ModeName {
    param([string]$Mode)
    switch ($Mode) {
        "safe" { return (T "mode_safe") }
        "advanced" { return (T "mode_advanced") }
        "scan" { return (T "mode_scan") }
        default { return $Mode }
    }
}

function Scan-Targets {
    param([array]$Targets)
    foreach ($target in $Targets) {
        $metrics = Get-TargetMetrics $target
        if (-not (Test-HasActionableMetrics $metrics)) { continue }
        New-ResultRow -Target $target -SizeBytes $metrics.SizeBytes -ItemCount $metrics.ItemCount -DisplaySize $metrics.DisplaySize -Source $target
    }
}

function Get-RunningAppNames {
    $names = @("JianyingPro", "Chrome", "msedge", "cloudmusic", "WeChat", "wps", "firefox", "brave")
    return Get-Process -ErrorAction SilentlyContinue | Where-Object { $names -contains $_.ProcessName } | Sort-Object ProcessName -Unique | Select-Object -ExpandProperty ProcessName
}

function Ensure-ExportsRoot {
    if (-not (Test-Path -LiteralPath $script:ExportsRoot)) {
        New-Item -ItemType Directory -Path $script:ExportsRoot -Force | Out-Null
    }
}

function Get-SystemDrivePath {
    $systemDrive = [Environment]::GetEnvironmentVariable('SystemDrive')
    if ([string]::IsNullOrWhiteSpace($systemDrive)) {
        $systemDrive = [System.IO.Path]::GetPathRoot($env:WINDIR)
    }
    if ([string]::IsNullOrWhiteSpace($systemDrive)) {
        return 'C:'
    }
    return $systemDrive.TrimEnd('\\')
}

function Get-SystemDriveLabel {
    return Get-SystemDrivePath
}

function Get-SystemDriveFreeSpaceText {
    try {
        $driveInfo = New-Object System.IO.DriveInfo((Get-SystemDrivePath))
        return Format-Size $driveInfo.AvailableFreeSpace
    }
    catch {
        return Format-Size 0
    }
}

function Export-Log {
    Ensure-ExportsRoot
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
    $dialog.InitialDirectory = $script:ExportsRoot
    $dialog.FileName = "system_disk_slim_log_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss")
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    [System.IO.File]::WriteAllText($dialog.FileName, $logBox.Text, [System.Text.Encoding]::UTF8)
    Add-Log ([string]::Format((T "log_saved"), $dialog.FileName))
}

function Save-ScanResults {
    if ($state.LastResults.Count -eq 0) {
        Run-ScanWorkflow
        if ($state.LastResults.Count -eq 0) { return }
    }

    Sync-GridSelectionToState

    Ensure-ExportsRoot
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = "CSV Files (*.csv)|*.csv|JSON Files (*.json)|*.json"
    $dialog.InitialDirectory = $script:ExportsRoot
    $dialog.FileName = "system_disk_slim_scan_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss")
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

    $ext = [System.IO.Path]::GetExtension($dialog.FileName)
    if ($ext -ieq ".json") {
        $payload = $state.LastResults | Select-Object Selected, Name, Risk, RiskNote, SizeBytes, ItemCount, DisplaySize, Path, Type
        $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $dialog.FileName -Encoding UTF8
    }
    else {
        $payload = $state.LastResults | Select-Object Selected, Name, Risk, RiskNote, SizeBytes, ItemCount, DisplaySize, Path, Type, @{ Name = "SizeFormatted"; Expression = { Get-RowDisplaySize $_ } }
        $payload | Export-Csv -LiteralPath $dialog.FileName -NoTypeInformation -Encoding UTF8
    }
    Add-Log ([string]::Format((T "scan_saved"), $dialog.FileName))
}

function Sync-GridSelectionToState {
    if ($null -eq $grid.DataSource) { return }
    for ($i = 0; $i -lt $grid.Rows.Count -and $i -lt $state.LastResults.Count; $i++) {
        $cellValue = $grid.Rows[$i].Cells[(T "target_selected")].Value
        $state.LastResults[$i].Selected = [System.Convert]::ToBoolean($cellValue)
    }
}

function Get-SelectedResults {
    Sync-GridSelectionToState
    return @($state.LastResults | Where-Object { $_.Selected })
}

function Set-AllSelections {
    param([bool]$Selected)
    foreach ($item in $state.LastResults) {
        $item.Selected = $Selected
    }
    if ($state.LastResults.Count -gt 0) {
        Refresh-Grid $state.LastResults
    }
}

if ($SelfTest) {
    try {
        $config = Load-TargetConfig
        Validate-LoadedConfiguration $config
        $null = Get-ProtectedRoots
        Write-Output "GUI script, cleanup config, and translations validated successfully."
        exit 0
    }
    catch {
        Write-Error $_
        exit 1
    }
}

if (-not (Test-IsAdministrator)) {
    if (-not (Restart-ElevatedGui)) { exit 1 }
    exit 0
}

try {
    $script:TargetConfig = Load-TargetConfig
    Validate-LoadedConfiguration $script:TargetConfig
    $null = Get-ProtectedRoots
}
catch {
    [System.Windows.Forms.MessageBox]::Show(([string]::Format((T "config_load_failed"), $_.Exception.Message)), (T "info_title"), [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit 1
}

$form = New-Object System.Windows.Forms.Form
$form.Size = New-Object System.Drawing.Size(1180, 720)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(247, 249, 252)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(24, 20)
$titleLabel.AutoSize = $true
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($titleLabel)

$descLabel = New-Object System.Windows.Forms.Label
$descLabel.Location = New-Object System.Drawing.Point(24, 58)
$descLabel.Size = New-Object System.Drawing.Size(1120, 40)
$form.Controls.Add($descLabel)

$languageLabel = New-Object System.Windows.Forms.Label
$languageLabel.Location = New-Object System.Drawing.Point(24, 108)
$languageLabel.AutoSize = $true
$form.Controls.Add($languageLabel)

$languageCombo = New-Object System.Windows.Forms.ComboBox
$languageCombo.Location = New-Object System.Drawing.Point(24, 130)
$languageCombo.Size = New-Object System.Drawing.Size(140, 28)
$languageCombo.DropDownStyle = "DropDownList"
[void]$languageCombo.Items.Add("Chinese")
[void]$languageCombo.Items.Add("English")
[void]$languageCombo.Items.Add("Japanese")
$languageCombo.SelectedIndex = 0
$form.Controls.Add($languageCombo)

$modeLabel = New-Object System.Windows.Forms.Label
$modeLabel.Location = New-Object System.Drawing.Point(180, 108)
$modeLabel.AutoSize = $true
$form.Controls.Add($modeLabel)

$modeCombo = New-Object System.Windows.Forms.ComboBox
$modeCombo.Location = New-Object System.Drawing.Point(180, 130)
$modeCombo.Size = New-Object System.Drawing.Size(220, 28)
$modeCombo.DropDownStyle = "DropDownList"
$form.Controls.Add($modeCombo)

$scanButton = New-Object System.Windows.Forms.Button
$scanButton.Location = New-Object System.Drawing.Point(420, 127)
$scanButton.Size = New-Object System.Drawing.Size(110, 34)
$form.Controls.Add($scanButton)

$cleanupButton = New-Object System.Windows.Forms.Button
$cleanupButton.Location = New-Object System.Drawing.Point(542, 127)
$cleanupButton.Size = New-Object System.Drawing.Size(150, 34)
$cleanupButton.BackColor = [System.Drawing.Color]::FromArgb(29, 78, 216)
$cleanupButton.ForeColor = [System.Drawing.Color]::White
$cleanupButton.FlatStyle = "Flat"
$form.Controls.Add($cleanupButton)

$exportLogButton = New-Object System.Windows.Forms.Button
$exportLogButton.Location = New-Object System.Drawing.Point(706, 127)
$exportLogButton.Size = New-Object System.Drawing.Size(120, 34)
$form.Controls.Add($exportLogButton)

$saveScanButton = New-Object System.Windows.Forms.Button
$saveScanButton.Location = New-Object System.Drawing.Point(838, 127)
$saveScanButton.Size = New-Object System.Drawing.Size(120, 34)
$form.Controls.Add($saveScanButton)

$selectAllButton = New-Object System.Windows.Forms.Button
$selectAllButton.Location = New-Object System.Drawing.Point(970, 127)
$selectAllButton.Size = New-Object System.Drawing.Size(80, 34)
$form.Controls.Add($selectAllButton)

$clearSelectionButton = New-Object System.Windows.Forms.Button
$clearSelectionButton.Location = New-Object System.Drawing.Point(1062, 127)
$clearSelectionButton.Size = New-Object System.Drawing.Size(82, 34)
$form.Controls.Add($clearSelectionButton)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(24, 176)
$statusLabel.Size = New-Object System.Drawing.Size(1120, 24)
$form.Controls.Add($statusLabel)

$selectionSummaryLabel = New-Object System.Windows.Forms.Label
$selectionSummaryLabel.Location = New-Object System.Drawing.Point(24, 198)
$selectionSummaryLabel.Size = New-Object System.Drawing.Size(1120, 24)
$selectionSummaryLabel.ForeColor = [System.Drawing.Color]::FromArgb(55, 65, 81)
$form.Controls.Add($selectionSummaryLabel)

$grid = New-Object System.Windows.Forms.DataGridView
$grid.Location = New-Object System.Drawing.Point(24, 228)
$grid.Size = New-Object System.Drawing.Size(1120, 330)
$grid.ReadOnly = $false
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.AllowUserToResizeRows = $false
$grid.RowHeadersVisible = $false
$grid.SelectionMode = "FullRowSelect"
$grid.AutoSizeColumnsMode = "Fill"
$grid.BackgroundColor = [System.Drawing.Color]::White
$grid.EditMode = [System.Windows.Forms.DataGridViewEditMode]::EditOnEnter
$form.Controls.Add($grid)

$logLabel = New-Object System.Windows.Forms.Label
$logLabel.Location = New-Object System.Drawing.Point(24, 560)
$logLabel.AutoSize = $true
$form.Controls.Add($logLabel)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(24, 582)
$logBox.Size = New-Object System.Drawing.Size(1120, 100)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($logBox)

$state = @{
    Mode        = "safe"
    LastResults = @()
}

function Add-Log {
    param([string]$Text)
    $logBox.AppendText(("[" + (Get-Date -Format "HH:mm:ss") + "] " + $Text + "`r`n"))
}

function Update-SelectionSummary {
    Sync-GridSelectionToState
    $totalCount = @($state.LastResults).Count
    $selected = @($state.LastResults | Where-Object { $_.Selected })
    $selectedCount = $selected.Count
    $selectedSum = ($selected | Measure-Object -Property SizeBytes -Sum).Sum
    if ($null -eq $selectedSum) { $selectedSum = 0L }
    $selectionSummaryLabel.Text = [string]::Format((T "selection_summary"), $totalCount, $selectedCount, (Format-Size $selectedSum))
}

function Refresh-Grid {
    param([array]$Rows)
    $table = New-Object System.Data.DataTable
    [void]$table.Columns.Add((T "target_selected"), [bool])
    [void]$table.Columns.Add((T "target_name"))
    [void]$table.Columns.Add((T "target_risk"))
    [void]$table.Columns.Add((T "target_risk_note"))
    [void]$table.Columns.Add((T "target_size"))
    [void]$table.Columns.Add((T "target_path"))
    foreach ($row in $Rows) {
        $dr = $table.NewRow()
        $dr[(T "target_selected")] = [bool]$row.Selected
        $dr[(T "target_name")] = $row.Name
        $dr[(T "target_risk")] = Get-RiskLabel $row.Risk
        $dr[(T "target_risk_note")] = Get-RiskNoteText $row.RiskNote
        $dr[(T "target_size")] = Get-RowDisplaySize $row
        $dr[(T "target_path")] = $row.Path
        [void]$table.Rows.Add($dr)
    }
    $grid.DataSource = $table
    foreach ($column in $grid.Columns) {
        $column.ReadOnly = $true
    }
    $grid.Columns[(T "target_selected")].ReadOnly = $false
    $grid.Columns[(T "target_selected")].FillWeight = 18
    $grid.Columns[(T "target_path")].FillWeight = 200
    Update-SelectionSummary
}

function Refresh-ModeCombo {
    $modeCombo.Items.Clear()
    foreach ($modeKey in $script:ModeOrder) { [void]$modeCombo.Items.Add((Get-ModeName $modeKey)) }
    $idx = [Array]::IndexOf($script:ModeOrder, $state.Mode)
    if ($idx -lt 0) { $idx = 0 }
    $modeCombo.SelectedIndex = $idx
}

function Apply-Language {
    $form.Text = Get-AppTitle
    $titleLabel.Text = ("{0} v{1}" -f (T "title"), $script:Version)
    $descLabel.Text = T "description"
    $languageLabel.Text = T "language"
    $modeLabel.Text = T "mode"
    $scanButton.Text = T "scan"
    $cleanupButton.Text = T "cleanup"
    $exportLogButton.Text = T "export_log"
    $saveScanButton.Text = T "save_scan"
    $selectAllButton.Text = T "select_all"
    $clearSelectionButton.Text = T "clear_selection"
    $logLabel.Text = T "log"
    Refresh-ModeCombo
    if ($state.LastResults.Count -gt 0) {
        Refresh-Grid $state.LastResults
    }
    else {
        Update-SelectionSummary
    }
    if ([string]::IsNullOrWhiteSpace($statusLabel.Text)) {
        $statusLabel.Text = T "ready"
    }
}

function Run-ScanWorkflow {
    Add-Log ([string]::Format((T "scan_started"), (Get-ModeName $state.Mode)))
    $running = @(Get-RunningAppNames)
    if ($running.Count -gt 0) {
        Add-Log ([string]::Format((T "detected_apps"), ($running -join ", ")))
    }
    $results = @(Scan-Targets (Get-ModeTargets $state.Mode) | Sort-Object -Property @(
            @{ Expression = 'SizeBytes'; Descending = $true },
            @{ Expression = 'ItemCount'; Descending = $true }
        ))
    $state.LastResults = $results
    Refresh-Grid $results
    $sum = ($results | Measure-Object -Property SizeBytes -Sum).Sum
    if ($null -eq $sum) { $sum = 0L }
    Add-Log ([string]::Format((T "scan_completed"), $results.Count, (Format-Size $sum)))
    $statusLabel.Text = [string]::Format((T "status_found"), $results.Count, (Format-Size $sum))
}

function Run-CleanupWorkflow {
    if ($state.Mode -eq "scan") {
        [System.Windows.Forms.MessageBox]::Show((T "scan_only_notice"), (T "info_title"), [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        return
    }
    if ($state.LastResults.Count -eq 0) { Run-ScanWorkflow }
    if ($state.LastResults.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show((T "no_data"), (T "info_title"), [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        return
    }

    $selectedItems = @(Get-SelectedResults)
    if ($selectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show((T "no_selection"), (T "info_title"), [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        return
    }
    if ($state.Mode -eq "advanced") {
        $adv = [System.Windows.Forms.MessageBox]::Show((T "advanced_warning"), (T "warn_title"), [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($adv -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    }
    $confirm = [System.Windows.Forms.MessageBox]::Show((T "confirm_cleanup"), (T "confirm_title"), [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $rows = @()
    $totalFreed = 0L
    foreach ($item in $state.LastResults) {
        if (-not $item.Selected) {
            $rows += $item
            continue
        }

        Add-Log ([string]::Format((T "cleaning_item"), $item.Name))
        $result = Remove-TargetItems $item.Source
        $totalFreed += $result.Freed
        Add-Log ([string]::Format((T "cleanup_item_result"), $item.Name, (Get-DisplaySizeText -SizeBytes $result.Freed -ItemCount $result.RemovedCount -CountKind (Get-RemovalCountKind $item.Type))))
        if ($result.FailedCount -gt 0) {
            Add-Log ([string]::Format((T "cleanup_partial_failed"), $item.Name, $result.FailedCount))
            Add-LogCleanupIssues -TargetName $item.Name -Issues $result.Issues
        }
        $rows += [pscustomobject]@{
            Selected    = $false
            Name        = $item.Name
            Risk        = $item.Risk
            RiskNote    = $item.RiskNote
            SizeBytes   = [Int64]$result.Freed
            ItemCount   = [int]$result.RemovedCount
            DisplaySize = Get-DisplaySizeText -SizeBytes $result.Freed -ItemCount $result.RemovedCount -CountKind (Get-RemovalCountKind $item.Type)
            Path        = $item.Path
            Type        = $item.Type
            Source      = $item.Source
        }
    }
    $state.LastResults = $rows
    Refresh-Grid $rows
    $systemDriveLabel = Get-SystemDriveLabel
    $systemDriveFreeSpace = Get-SystemDriveFreeSpaceText
    Add-Log ([string]::Format((T "cleanup_completed"), (Format-Size $totalFreed), $systemDriveFreeSpace, $systemDriveLabel))
    $statusLabel.Text = [string]::Format((T "status_cleaned"), (Format-Size $totalFreed), $systemDriveFreeSpace, $systemDriveLabel)
}

$scanButton.Add_Click({ Run-ScanWorkflow })
$cleanupButton.Add_Click({ Run-CleanupWorkflow })
$exportLogButton.Add_Click({ Export-Log })
$saveScanButton.Add_Click({ Save-ScanResults })
$selectAllButton.Add_Click({ Set-AllSelections $true })
$clearSelectionButton.Add_Click({ Set-AllSelections $false })
$grid.Add_CurrentCellDirtyStateChanged({
        if ($grid.IsCurrentCellDirty) {
            $grid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)
        }
    })
$grid.Add_CellValueChanged({
        param($sender, $e)
        if ($e.RowIndex -ge 0 -and $e.ColumnIndex -ge 0 -and $grid.Columns[$e.ColumnIndex].Name -eq (T "target_selected")) {
            Update-SelectionSummary
        }
    })
$modeCombo.Add_SelectedIndexChanged({
        $idx = $modeCombo.SelectedIndex
        if ($idx -ge 0 -and $idx -lt $script:ModeOrder.Count) {
            $state.Mode = $script:ModeOrder[$idx]
            $state.LastResults = @()
            $grid.DataSource = $null
            Update-SelectionSummary
            $statusLabel.Text = T "mode_changed"
        }
    })
$languageCombo.Add_SelectedIndexChanged({
        switch ($languageCombo.SelectedIndex) {
            0 { $script:Language = "zh" }
            1 { $script:Language = "en" }
            2 { $script:Language = "ja" }
            default { $script:Language = "zh" }
        }
        Apply-Language
    })

Apply-Language
Update-SelectionSummary
Add-Log (T "tool_launched")
Add-Log (T "tool_hint")
Add-Log ("Loaded config: " + $script:ConfigPath)
Add-Log ("Exports root: " + $script:ExportsRoot)
Add-Log ("Detected system drive: " + (Get-SystemDriveLabel))
Add-Log ("Configuration validation passed.")
Add-Log ("Protected roots: " + ((Get-ProtectedRoots) -join "; "))
[void]$form.ShowDialog()
