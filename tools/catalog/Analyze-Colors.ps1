#requires -Version 5.1
<#
.SYNOPSIS
    Extract the three most common hex colors for catalog clothing items.

.DESCRIPTION
    Uses Roblox CDN catalog thumbnails (fetched in memory — no local image
    cache). For matched top/bottom pairs, only the top is analyzed; pair colors
    are stored on the match row and the top item. Unmatched bottoms are still
    analyzed individually.

    Results are written into catalog/matches JSON (CDN thumbnailUrl + colors)
    so the durable output lives with the repo / remote, not on disk as images.

.PARAMETER OutputDir
    Catalog output directory. Default: <tool>\output

.PARAMETER Limit
    Optional cap on how many assets to analyze (for smoke tests).

.PARAMETER Resume
    Skip asset IDs already present in colors.json.

.EXAMPLE
    ./Analyze-Colors.ps1

.EXAMPLE
    ./Analyze-Colors.ps1 -Limit 25
#>
[CmdletBinding()]
param(
    [string] $OutputDir,
    [int]    $Limit = 0,
    [switch] $Resume
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Import-Module (Join-Path $root 'ColorExtractor.psm1') -Force

if (-not $OutputDir) { $OutputDir = Join-Path $root 'output' }
if (-not (Test-Path (Join-Path $OutputDir 'catalog.json'))) {
    throw "No catalog.json in $OutputDir. Run Build-Catalog.ps1 first."
}

function ConvertFrom-JsonArray {
    param([Parameter(Mandatory)] [string] $Path)
    $parsed = Get-Content -Path $Path -Raw | ConvertFrom-Json
    if ($null -eq $parsed) { return @() }
    if ($parsed -is [System.Array]) { return $parsed }
    return @($parsed)
}

function Write-Csv-Safe {
    param([object[]] $Data, [string] $Path)
    if ($Data -and $Data.Count -gt 0) {
        $Data | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    } else {
        Set-Content -Path $Path -Value '' -Encoding UTF8
    }
}

function Flatten-Colors {
    param($Colors)
    $arr = @($Colors)
    if ($arr.Count -eq 1 -and $arr[0] -is [System.Array]) { $arr = @($arr[0]) }
    return @($arr)
}

function Get-ColorFields {
    param($Analysis)
    $colors = Flatten-Colors $Analysis.colors
    $hex1 = $null; $hex2 = $null; $hex3 = $null
    $cov1 = $null; $cov2 = $null; $cov3 = $null
    if ($colors.Count -gt 0) { $hex1 = $colors[0].hex; $cov1 = $colors[0].coverage }
    if ($colors.Count -gt 1) { $hex2 = $colors[1].hex; $cov2 = $colors[1].coverage }
    if ($colors.Count -gt 2) { $hex3 = $colors[2].hex; $cov3 = $colors[2].coverage }
    return [pscustomobject]@{
        thumbnailUrl = $Analysis.thumbnailUrl
        color1       = $hex1
        color1Cov    = $cov1
        color2       = $hex2
        color2Cov    = $cov2
        color3       = $hex3
        color3Cov    = $cov3
        colors       = $colors
        colorError   = $Analysis.error
    }
}

Write-Host "Loading catalog + matches..."
$catalog = @(ConvertFrom-JsonArray (Join-Path $OutputDir 'catalog.json'))
$matchesPath = Join-Path $OutputDir 'matches.json'
$matches = @()
if (Test-Path $matchesPath) {
    $matches = @(ConvertFrom-JsonArray $matchesPath)
}

# Bottoms that belong to a matched pair are omitted from analysis.
$pairedBottomIds = @{}
foreach ($m in $matches) {
    if ($m.bottomId) { $pairedBottomIds[[long]$m.bottomId] = $true }
}

$toAnalyze = New-Object System.Collections.Generic.List[long]
foreach ($item in $catalog) {
    $id = [long]$item.id
    if ($item.role -eq 'top') {
        $toAnalyze.Add($id)
    } elseif ($item.role -eq 'bottom' -and -not $pairedBottomIds.ContainsKey($id)) {
        $toAnalyze.Add($id)
    }
}
$toAnalyze = @($toAnalyze | Select-Object -Unique)

$colorsPath = Join-Path $OutputDir 'colors.json'
$existing = @{}
if ($Resume -and (Test-Path $colorsPath)) {
    foreach ($row in @(ConvertFrom-JsonArray $colorsPath)) {
        $existing[[long]$row.id] = $row
    }
    Write-Host "Resume: loaded $($existing.Count) existing color rows."
}

if ($Resume -and $existing.Count -gt 0) {
    $toAnalyze = @($toAnalyze | Where-Object { -not $existing.ContainsKey($_) })
}

if ($Limit -gt 0 -and $toAnalyze.Count -gt $Limit) {
    $toAnalyze = @($toAnalyze | Select-Object -First $Limit)
}

Write-Host ("Assets to analyze: {0} (tops + unmatched bottoms; paired bottoms omitted)" -f $toAnalyze.Count)
if ($toAnalyze.Count -eq 0) {
    Write-Host "Nothing to do."
    return
}

Write-Host "Resolving CDN thumbnail URLs..."
$urlMap = Get-AssetThumbnailUrls -Ids $toAnalyze
Write-Host ("  resolved {0}/{1}" -f $urlMap.Count, $toAnalyze.Count)

$results = @{}
foreach ($k in $existing.Keys) { $results[$k] = $existing[$k] }

$done = 0
$failed = 0
$sw = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($id in $toAnalyze) {
    $done++
    $url = $null
    if ($urlMap.ContainsKey($id)) { $url = $urlMap[$id] }

    $analysis = Get-AssetDominantColors -AssetId $id -ThumbnailUrl $url
    $fields = Get-ColorFields -Analysis $analysis

    $results[$id] = [pscustomobject]@{
        id           = $id
        thumbnailUrl = $fields.thumbnailUrl
        color1       = $fields.color1
        color1Cov    = $fields.color1Cov
        color2       = $fields.color2
        color2Cov    = $fields.color2Cov
        color3       = $fields.color3
        color3Cov    = $fields.color3Cov
        colors       = $fields.colors
        error        = $fields.colorError
        source       = 'roblox-cdn-thumbnail'
    }

    if ($fields.colorError) { $failed++ }

    if (($done % 25) -eq 0 -or $done -eq $toAnalyze.Count) {
        $rate = if ($sw.Elapsed.TotalSeconds -gt 0) { [Math]::Round($done / $sw.Elapsed.TotalSeconds, 2) } else { 0 }
        Write-Host ("  [{0}/{1}] fail={2} {3}/s  last={4} {5}" -f `
            $done, $toAnalyze.Count, $failed, $rate, $id, ($fields.colors | ForEach-Object { $_.hex }) -join ',')
    }

    # Checkpoint every 100 so a long run can resume.
    if (($done % 100) -eq 0) {
        @($results.Values | Sort-Object id) | ConvertTo-Json -Depth 6 |
            Set-Content -Path $colorsPath -Encoding UTF8
    }

    Start-Sleep -Milliseconds 40
}

Write-Host "`nWriting colors.json..."
$colorRows = @($results.Values | Sort-Object id)
($colorRows | ConvertTo-Json -Depth 6) | Set-Content -Path $colorsPath -Encoding UTF8
Write-Csv-Safe -Data @(
    $colorRows | Select-Object id, thumbnailUrl, color1, color1Cov, color2, color2Cov, color3, color3Cov, error, source
) -Path (Join-Path $OutputDir 'colors.csv')

Write-Host "Merging colors into catalog + matches..."
foreach ($item in $catalog) {
    $id = [long]$item.id
    if ($results.ContainsKey($id)) {
        $row = $results[$id]
        $item | Add-Member -NotePropertyName thumbnailUrl -NotePropertyValue $row.thumbnailUrl -Force
        $item | Add-Member -NotePropertyName color1 -NotePropertyValue $row.color1 -Force
        $item | Add-Member -NotePropertyName color2 -NotePropertyValue $row.color2 -Force
        $item | Add-Member -NotePropertyName color3 -NotePropertyValue $row.color3 -Force
        $item | Add-Member -NotePropertyName colors -NotePropertyValue $row.colors -Force
        $item | Add-Member -NotePropertyName colorSource -NotePropertyValue 'self' -Force
    } elseif ($item.role -eq 'bottom' -and $pairedBottomIds.ContainsKey($id)) {
        $item | Add-Member -NotePropertyName colorSource -NotePropertyValue 'pair-top' -Force
        $item | Add-Member -NotePropertyName colors -NotePropertyValue @() -Force
    }
}

# Matches: colors come from the top only.
foreach ($m in $matches) {
    $topId = [long]$m.topId
    if ($results.ContainsKey($topId)) {
        $row = $results[$topId]
        $m | Add-Member -NotePropertyName thumbnailUrl -NotePropertyValue $row.thumbnailUrl -Force
        $m | Add-Member -NotePropertyName color1 -NotePropertyValue $row.color1 -Force
        $m | Add-Member -NotePropertyName color2 -NotePropertyValue $row.color2 -Force
        $m | Add-Member -NotePropertyName color3 -NotePropertyValue $row.color3 -Force
        $m | Add-Member -NotePropertyName colors -NotePropertyValue $row.colors -Force
        $m | Add-Member -NotePropertyName colorFrom -NotePropertyValue 'top' -Force
    }
}

($catalog | ConvertTo-Json -Depth 8) | Set-Content -Path (Join-Path $OutputDir 'catalog.json') -Encoding UTF8
Write-Csv-Safe -Data @(
    $catalog | Select-Object id, name, role, gender, groupName, groupId, price, url, thumbnailUrl, color1, color2, color3, colorSource
) -Path (Join-Path $OutputDir 'catalog.csv')

($matches | ConvertTo-Json -Depth 8) | Set-Content -Path (Join-Path $OutputDir 'matches.json') -Encoding UTF8
Write-Csv-Safe -Data @(
    $matches | Select-Object gender, groupName, outfitKey, topId, topName, bottomId, bottomName, priceTotal, thumbnailUrl, color1, color2, color3, topUrl, bottomUrl
) -Path (Join-Path $OutputDir 'matches.csv')

# Refresh gender bucket catalogs with color fields when present.
foreach ($bucket in @('masculine', 'feminine', 'unclassified')) {
    $bucketCatalog = Join-Path $OutputDir "$bucket\catalog.json"
    if (-not (Test-Path $bucketCatalog)) { continue }
    $rows = @(ConvertFrom-JsonArray $bucketCatalog)
    foreach ($item in $rows) {
        $id = [long]$item.id
        if ($results.ContainsKey($id)) {
            $row = $results[$id]
            $item | Add-Member -NotePropertyName thumbnailUrl -NotePropertyValue $row.thumbnailUrl -Force
            $item | Add-Member -NotePropertyName color1 -NotePropertyValue $row.color1 -Force
            $item | Add-Member -NotePropertyName color2 -NotePropertyValue $row.color2 -Force
            $item | Add-Member -NotePropertyName color3 -NotePropertyValue $row.color3 -Force
            $item | Add-Member -NotePropertyName colors -NotePropertyValue $row.colors -Force
            $item | Add-Member -NotePropertyName colorSource -NotePropertyValue 'self' -Force
        } elseif ($item.role -eq 'bottom' -and $pairedBottomIds.ContainsKey($id)) {
            $item | Add-Member -NotePropertyName colorSource -NotePropertyValue 'pair-top' -Force
        }
    }
    ($rows | ConvertTo-Json -Depth 8) | Set-Content -Path $bucketCatalog -Encoding UTF8
    Write-Csv-Safe -Data @(
        $rows | Select-Object id, name, role, gender, groupName, price, url, thumbnailUrl, color1, color2, color3, colorSource
    ) -Path (Join-Path $OutputDir "$bucket\catalog.csv")

    $bucketMatches = Join-Path $OutputDir "$bucket\matches.json"
    if (Test-Path $bucketMatches) {
        $mrows = @(ConvertFrom-JsonArray $bucketMatches)
        foreach ($m in $mrows) {
            $topId = [long]$m.topId
            if ($results.ContainsKey($topId)) {
                $row = $results[$topId]
                $m | Add-Member -NotePropertyName thumbnailUrl -NotePropertyValue $row.thumbnailUrl -Force
                $m | Add-Member -NotePropertyName color1 -NotePropertyValue $row.color1 -Force
                $m | Add-Member -NotePropertyName color2 -NotePropertyValue $row.color2 -Force
                $m | Add-Member -NotePropertyName color3 -NotePropertyValue $row.color3 -Force
                $m | Add-Member -NotePropertyName colors -NotePropertyValue $row.colors -Force
                $m | Add-Member -NotePropertyName colorFrom -NotePropertyValue 'top' -Force
            }
        }
        ($mrows | ConvertTo-Json -Depth 8) | Set-Content -Path $bucketMatches -Encoding UTF8
        Write-Csv-Safe -Data @(
            $mrows | Select-Object groupName, outfitKey, topId, topName, bottomId, bottomName, priceTotal, thumbnailUrl, color1, color2, color3
        ) -Path (Join-Path $OutputDir "$bucket\matches.csv")
    }
}

$summaryPath = Join-Path $OutputDir 'summary.json'
$summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
$summary | Add-Member -NotePropertyName colors -NotePropertyValue ([pscustomobject]@{
    analyzed          = $colorRows.Count
    failed            = @($colorRows | Where-Object { $_.error }).Count
    pairedBottomsSkipped = $pairedBottomIds.Count
    source            = 'roblox-cdn-thumbnail (in-memory; CDN URL stored)'
    generatedUtc      = (Get-Date).ToUniversalTime().ToString('o')
}) -Force
($summary | ConvertTo-Json -Depth 10) | Set-Content -Path $summaryPath -Encoding UTF8

Write-Host "`n===== Color analysis ====="
Write-Host ("Analyzed          : {0}" -f $colorRows.Count)
Write-Host ("Failed            : {0}" -f @($colorRows | Where-Object { $_.error }).Count)
Write-Host ("Paired bottoms skipped: {0}" -f $pairedBottomIds.Count)
Write-Host ("Elapsed           : {0}" -f $sw.Elapsed.ToString())
Write-Host ("Wrote             : colors.json, colors.csv, updated catalog/matches")
Write-Host ("CDN thumbnails referenced; no local image cache retained.")
