#requires -Version 5.1
<#
.SYNOPSIS
    Catalog Classic Shirts and Classic Pants sold by the configured Roblox
    groups, classify them as masculine / feminine, and match tops with bottoms.

.DESCRIPTION
    1. Reads groups.json (including optional defaultGender per group).
    2. Fetches each group's Clothing catalog via the public Roblox API
       (or reuses output\raw\*.json with -SkipFetch).
    3. Keeps only Classic Shirts (tops) and Classic Pants (bottoms) —
       Classic T-Shirts and all 3D/layered clothing are omitted.
    4. Classifies each item as masculine, feminine, or unclassified.
    5. Pairs tops/bottoms within each gender and writes review lists.

.PARAMETER Slug
    Optional. One or more group slugs to limit the run (default: all).

.PARAMETER OutputDir
    Where to write results. Default: <tool>\output.

.PARAMETER SkipFetch
    Reuse existing output\raw\*.json instead of hitting the API.

.EXAMPLE
    ./Build-Catalog.ps1

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

Import-Module (Join-Path $root 'CatalogApi.psm1')         -Force
Import-Module (Join-Path $root 'OutfitMatcher.psm1')      -Force
Import-Module (Join-Path $root 'GenderClassifier.psm1')   -Force

if (-not $OutputDir) { $OutputDir = Join-Path $root 'output' }
$rawDir = Join-Path $OutputDir 'raw'
New-Item -ItemType Directory -Force -Path $rawDir | Out-Null

$groups = Get-Content (Join-Path $root 'groups.json') -Raw | ConvertFrom-Json
if ($Slug) { $groups = $groups | Where-Object { $Slug -contains $_.slug } }
if (-not $groups) { throw "No groups selected. Check the -Slug values against groups.json." }

# groupId -> defaultGender for items with no name signal
$groupDefaults = @{}
foreach ($g in $groups) {
    $default = if ($g.PSObject.Properties['defaultGender'] -and $g.defaultGender) {
        [string]$g.defaultGender
    } else {
        'unclassified'
    }
    $groupDefaults[[string]$g.id] = $default
}

function ConvertFrom-JsonArray {
    # PS 5.1: assign ConvertFrom-Json to a variable so large arrays don't nest.
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

function Write-GenderBucket {
    param(
        [Parameter(Mandatory)] [string] $BucketDir,
        [Parameter(Mandatory)] [string] $Label,
        [object[]] $Records
    )

    New-Item -ItemType Directory -Force -Path $BucketDir | Out-Null
    $records = @($Records)
    $match = Get-OutfitMatches -Records $records

    ($records | ConvertTo-Json -Depth 6) |
        Set-Content -Path (Join-Path $BucketDir 'catalog.json') -Encoding UTF8
    Write-Csv-Safe -Data $records -Path (Join-Path $BucketDir 'catalog.csv')

    ($match | ConvertTo-Json -Depth 6) |
        Set-Content -Path (Join-Path $BucketDir 'matches.json') -Encoding UTF8
    Write-Csv-Safe -Data $match.matched          -Path (Join-Path $BucketDir 'matches.csv')
    Write-Csv-Safe -Data $match.unmatchedTops    -Path (Join-Path $BucketDir 'unmatched-tops.csv')
    Write-Csv-Safe -Data $match.unmatchedBottoms -Path (Join-Path $BucketDir 'unmatched-bottoms.csv')

    $tops    = @($records | Where-Object { $_.role -eq 'top' }).Count
    $bottoms = @($records | Where-Object { $_.role -eq 'bottom' }).Count

    $bucketSummary = [pscustomobject]@{
        gender           = $Label
        items            = $records.Count
        tops             = $tops
        bottoms          = $bottoms
        matchedOutfits   = $match.matched.Count
        unmatchedTops    = $match.unmatchedTops.Count
        unmatchedBottoms = $match.unmatchedBottoms.Count
    }
    ($bucketSummary | ConvertTo-Json -Depth 4) |
        Set-Content -Path (Join-Path $BucketDir 'summary.json') -Encoding UTF8

    return $bucketSummary
}

$allRecords = New-Object System.Collections.Generic.List[object]
$csrf = $null
$csrfRef = [ref]$csrf
$perGroupSummary = New-Object System.Collections.Generic.List[object]

foreach ($group in $groups) {
    $rawPath = Join-Path $rawDir "$($group.slug).json"

    if ($SkipFetch) {
        if (Test-Path $rawPath) {
            Write-Host "[skip-fetch] $($group.name) <- $rawPath"
            $records = @(ConvertFrom-JsonArray -Path $rawPath)
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
        ($records | ConvertTo-Json -Depth 6) | Set-Content -Path $rawPath -Encoding UTF8
        Start-Sleep -Seconds 2
    }

    # Enforce scope: Classic Shirts + Classic Pants only (drop cached t-shirts / anything else).
    $records = @($records | Where-Object { $_.role -eq 'top' -or $_.role -eq 'bottom' })

    foreach ($r in $records) {
        $r | Add-Member -NotePropertyName groupSlug -NotePropertyValue $group.slug -Force
        $allRecords.Add($r)
    }

    $tops    = @($records | Where-Object { $_.role -eq 'top' }).Count
    $bottoms = @($records | Where-Object { $_.role -eq 'bottom' }).Count
    Write-Host ("  tops={0} bottoms={1} total={2}" -f $tops, $bottoms, $records.Count)

    $perGroupSummary.Add([pscustomobject]@{
        group         = $group.name
        slug          = $group.slug
        groupId       = $group.id
        defaultGender = $groupDefaults[[string]$group.id]
        tops          = $tops
        bottoms       = $bottoms
        total         = $records.Count
    })
}

Write-Host "`nClassifying gender..."
$catalog = @(Add-ClothingGender -Records $allRecords.ToArray() -GroupDefaults $groupDefaults)

$masculine    = @($catalog | Where-Object { $_.gender -eq 'masculine' })
$feminine     = @($catalog | Where-Object { $_.gender -eq 'feminine' })
$unclassified = @($catalog | Where-Object { $_.gender -eq 'unclassified' })

Write-Host ("  masculine={0} feminine={1} unclassified={2}" -f `
    $masculine.Count, $feminine.Count, $unclassified.Count)

Write-Host "`nMatching tops and bottoms by gender..."
$mascSummary = Write-GenderBucket -BucketDir (Join-Path $OutputDir 'masculine')    -Label 'masculine'    -Records $masculine
$femSummary  = Write-GenderBucket -BucketDir (Join-Path $OutputDir 'feminine')     -Label 'feminine'     -Records $feminine
$uncSummary  = Write-GenderBucket -BucketDir (Join-Path $OutputDir 'unclassified') -Label 'unclassified' -Records $unclassified

# Combined catalog (all genders, shirts+pants only)
($catalog | ConvertTo-Json -Depth 6) |
    Set-Content -Path (Join-Path $OutputDir 'catalog.json') -Encoding UTF8
Write-Csv-Safe -Data $catalog -Path (Join-Path $OutputDir 'catalog.csv')

# Combined matches across genders (pairing already done per gender bucket)
$allMatched = @()
foreach ($dir in @('masculine', 'feminine', 'unclassified')) {
    $path = Join-Path $OutputDir "$dir\matches.csv"
    if ((Test-Path $path) -and ((Get-Item $path).Length -gt 0)) {
        $rows = @(Import-Csv $path)
        foreach ($row in $rows) {
            $row | Add-Member -NotePropertyName gender -NotePropertyValue $dir -Force
            $allMatched += $row
        }
    }
}
Write-Csv-Safe -Data $allMatched -Path (Join-Path $OutputDir 'matches.csv')
($allMatched | ConvertTo-Json -Depth 6) |
    Set-Content -Path (Join-Path $OutputDir 'matches.json') -Encoding UTF8

# Drop obsolete t-shirt artifact if present from earlier runs
$legacyTee = Join-Path $OutputDir 'tshirts.csv'
if (Test-Path $legacyTee) { Remove-Item $legacyTee -Force }

$summary = [pscustomobject]@{
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    scope        = 'Classic Shirts + Classic Pants only (no t-shirts, no 3D clothing)'
    groups       = $perGroupSummary.ToArray()
    byGender     = [pscustomobject]@{
        masculine    = $mascSummary
        feminine     = $femSummary
        unclassified = $uncSummary
    }
    totals = [pscustomobject]@{
        items            = $catalog.Count
        masculine        = $masculine.Count
        feminine         = $feminine.Count
        unclassified     = $unclassified.Count
        matchedOutfits   = ($mascSummary.matchedOutfits + $femSummary.matchedOutfits + $uncSummary.matchedOutfits)
    }
}
($summary | ConvertTo-Json -Depth 8) |
    Set-Content -Path (Join-Path $OutputDir 'summary.json') -Encoding UTF8

Write-Host "`n===== Summary ====="
$perGroupSummary.ToArray() | Format-Table group, tops, bottoms, total, defaultGender -AutoSize | Out-String | Write-Host
Write-Host ("Masculine    : {0} items, {1} matched outfits" -f $mascSummary.items, $mascSummary.matchedOutfits)
Write-Host ("Feminine     : {0} items, {1} matched outfits" -f $femSummary.items, $femSummary.matchedOutfits)
Write-Host ("Unclassified : {0} items, {1} matched outfits" -f $uncSummary.items, $uncSummary.matchedOutfits)
Write-Host ("`nOutput written to: {0}" -f $OutputDir)
