#requires -Version 5.1
<#
.SYNOPSIS
    Catalog every 2D clothing item sold by the configured Roblox groups and match
    tops (Classic Shirts) with bottoms (Classic Pants).

.DESCRIPTION
    1. Reads groups.json.
    2. Fetches each group's Clothing catalog via the public Roblox API.
    3. Writes a normalized per-group record set + a combined catalog (JSON + CSV).
    4. Pairs tops/bottoms into outfits and writes matches + review lists.

.PARAMETER Slug
    Optional. One or more group slugs to limit the run (default: all).

.PARAMETER OutputDir
    Where to write results. Default: <tool>\output.

.PARAMETER SkipFetch
    Reuse existing output\raw\*.json instead of hitting the API. Useful for
    re-running only the matching step after tweaking OutfitMatcher.

.EXAMPLE
    ./Build-Catalog.ps1

.EXAMPLE
    ./Build-Catalog.ps1 -Slug beneventis,gravelle

.EXAMPLE
    ./Build-Catalog.ps1 -SkipFetch
#>
[CmdletBinding()]
param(
    [string[]] $Slug,
    [string]   $OutputDir,
    [switch]   $SkipFetch
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

Import-Module (Join-Path $root 'CatalogApi.psm1')     -Force
Import-Module (Join-Path $root 'OutfitMatcher.psm1')  -Force

if (-not $OutputDir) { $OutputDir = Join-Path $root 'output' }
$rawDir = Join-Path $OutputDir 'raw'
New-Item -ItemType Directory -Force -Path $rawDir | Out-Null

$groups = Get-Content (Join-Path $root 'groups.json') -Raw | ConvertFrom-Json
if ($Slug) { $groups = $groups | Where-Object { $Slug -contains $_.slug } }
if (-not $groups) { throw "No groups selected. Check the -Slug values against groups.json." }

$allRecords = New-Object System.Collections.Generic.List[object]
$csrf = $null
$csrfRef = [ref]$csrf
$perGroupSummary = New-Object System.Collections.Generic.List[object]

foreach ($group in $groups) {
    $rawPath = Join-Path $rawDir "$($group.slug).json"

    if ($SkipFetch) {
        if (Test-Path $rawPath) {
            Write-Host "[skip-fetch] $($group.name) <- $rawPath"
            $records = @(Get-Content $rawPath -Raw | ConvertFrom-Json)
        } else {
            Write-Warning "[skip-fetch] no cache for $($group.name); skipping."
            $records = @()
        }
    } else {
        Write-Host "Fetching $($group.name) (group $($group.id))..."
        try {
            $records = @(Get-GroupClothing -GroupId $group.id -GroupName $group.name -CsrfRef $csrfRef)
        } catch {
            Write-Warning "Failed to fetch $($group.name): $($_.Exception.Message)"
            $records = @()
        }
        # Persist raw per-group snapshot even when empty for traceability.
        ($records | ConvertTo-Json -Depth 6) | Set-Content -Path $rawPath -Encoding UTF8
        Start-Sleep -Seconds 2  # be polite between groups to avoid 429s
    }

    foreach ($r in $records) { $allRecords.Add($r) }

    $tops    = @($records | Where-Object { $_.role -eq 'top' }).Count
    $bottoms = @($records | Where-Object { $_.role -eq 'bottom' }).Count
    $tees    = @($records | Where-Object { $_.role -eq 'tshirt' }).Count
    Write-Host ("  tops={0} bottoms={1} tshirts={2} total={3}" -f $tops, $bottoms, $tees, $records.Count)

    $perGroupSummary.Add([pscustomobject]@{
        group   = $group.name
        slug    = $group.slug
        groupId = $group.id
        tops    = $tops
        bottoms = $bottoms
        tshirts = $tees
        total   = $records.Count
    })
}

Write-Host "`nMatching tops and bottoms..."
$match = Get-OutfitMatches -Records $allRecords.ToArray()

function Write-Csv-Safe {
    param([object[]] $Data, [string] $Path)
    if ($Data -and $Data.Count -gt 0) {
        $Data | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    } else {
        Set-Content -Path $Path -Value '' -Encoding UTF8
    }
}

# --- Combined catalog ---
($allRecords.ToArray() | ConvertTo-Json -Depth 6) |
    Set-Content -Path (Join-Path $OutputDir 'catalog.json') -Encoding UTF8
Write-Csv-Safe -Data $allRecords.ToArray() -Path (Join-Path $OutputDir 'catalog.csv')

# --- Matches + review lists ---
($match | ConvertTo-Json -Depth 6) |
    Set-Content -Path (Join-Path $OutputDir 'matches.json') -Encoding UTF8
Write-Csv-Safe -Data $match.matched          -Path (Join-Path $OutputDir 'matches.csv')
Write-Csv-Safe -Data $match.unmatchedTops    -Path (Join-Path $OutputDir 'unmatched-tops.csv')
Write-Csv-Safe -Data $match.unmatchedBottoms -Path (Join-Path $OutputDir 'unmatched-bottoms.csv')
Write-Csv-Safe -Data $match.tshirts          -Path (Join-Path $OutputDir 'tshirts.csv')

$summary = [pscustomobject]@{
    generatedUtc     = (Get-Date).ToUniversalTime().ToString('o')
    groups           = $perGroupSummary.ToArray()
    totals           = [pscustomobject]@{
        items            = $allRecords.Count
        matchedOutfits   = $match.matched.Count
        unmatchedTops    = $match.unmatchedTops.Count
        unmatchedBottoms = $match.unmatchedBottoms.Count
        tshirts          = $match.tshirts.Count
    }
}
($summary | ConvertTo-Json -Depth 6) |
    Set-Content -Path (Join-Path $OutputDir 'summary.json') -Encoding UTF8

Write-Host "`n===== Summary ====="
$perGroupSummary.ToArray() | Format-Table group, tops, bottoms, tshirts, total -AutoSize | Out-String | Write-Host
Write-Host ("Matched outfits : {0}" -f $match.matched.Count)
Write-Host ("Unmatched tops  : {0}" -f $match.unmatchedTops.Count)
Write-Host ("Unmatched bottoms: {0}" -f $match.unmatchedBottoms.Count)
Write-Host ("Standalone tees : {0}" -f $match.tshirts.Count)
Write-Host ("`nOutput written to: {0}" -f $OutputDir)
