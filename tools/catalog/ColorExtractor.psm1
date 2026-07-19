#requires -Version 5.1
<#
    ColorExtractor.psm1
    Resolve Roblox CDN thumbnail URLs and extract the three most common hex
    colors from each image entirely in memory (no local image cache).
#>

Add-Type -AssemblyName System.Drawing

$script:ThumbnailsUrl = 'https://thumbnails.roblox.com/v1/assets'

function Get-AssetThumbnailUrls {
    <# Batch-resolve CDN image URLs for asset IDs. Returns hashtable id -> url. #>
    param(
        [Parameter(Mandatory)] [long[]] $Ids,
        [int] $BatchSize = 100,
        [int] $ThrottleMs = 250,
        [string] $Size = '420x420'
    )

    $map = @{}
    $unique = @($Ids | Select-Object -Unique)

    for ($i = 0; $i -lt $unique.Count; $i += $BatchSize) {
        $chunk = $unique[$i..([Math]::Min($i + $BatchSize - 1, $unique.Count - 1))]
        $idList = ($chunk -join ',')
        $uri = "$($script:ThumbnailsUrl)?assetIds=$idList&size=$Size&format=Png&isCircular=false"

        $attempt = 0
        while ($true) {
            $attempt++
            try {
                $resp = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
                foreach ($row in $resp.data) {
                    if ($row.state -eq 'Completed' -and $row.imageUrl) {
                        $map[[long]$row.targetId] = [string]$row.imageUrl
                    }
                }
                break
            } catch {
                if ($attempt -ge 5) { throw }
                $wait = [Math]::Min(30, 2 * $attempt)
                Write-Warning "Thumbnail lookup failed; retry in ${wait}s: $($_.Exception.Message)"
                Start-Sleep -Seconds $wait
            }
        }

        if ($i + $BatchSize -lt $unique.Count) { Start-Sleep -Milliseconds $ThrottleMs }
    }

    return $map
}

function Get-ImageBytes {
    param([Parameter(Mandatory)] [string] $Url)

    $attempt = 0
    while ($true) {
        $attempt++
        try {
            $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop
            return [byte[]]$resp.Content
        } catch {
            if ($attempt -ge 4) { throw }
            Start-Sleep -Seconds ([Math]::Min(15, 2 * $attempt))
        }
    }
}

function ConvertTo-HexColor {
    param([int] $R, [int] $G, [int] $B)
    return ('#{0:X2}{1:X2}{2:X2}' -f $R, $G, $B)
}

function Get-DominantColorsFromBytes {
    <#
        Quantize a PNG/JPEG byte array to the 3 most common clothing colors.
        Ignores transparent / near-transparent pixels and near-white catalog
        background, then histogram-buckets the remaining pixels and merges
        near-duplicates before picking the top 3 by coverage.
    #>
    param(
        [Parameter(Mandatory)] [byte[]] $Bytes,
        [int] $SampleSize = 64,
        [int] $MaxColors = 3,
        [int] $BucketBits = 4,          # 16 levels/channel => 4096 buckets
        [double] $MergeDistance = 42.0  # RGB euclidean merge threshold
    )

    $ms = $null
    $src = $null
    $sample = $null

    try {
        $ms = New-Object System.IO.MemoryStream(,$Bytes)
        $src = [System.Drawing.Image]::FromStream($ms)
        $sample = New-Object System.Drawing.Bitmap($SampleSize, $SampleSize)
        $g = [System.Drawing.Graphics]::FromImage($sample)
        try {
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBilinear
            $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.Clear([System.Drawing.Color]::Transparent)
            $g.DrawImage($src, 0, 0, $SampleSize, $SampleSize)
        } finally {
            $g.Dispose()
        }

        $shift = 8 - $BucketBits
        $counts = @{}
        $sumsR  = @{}
        $sumsG  = @{}
        $sumsB  = @{}
        $kept = 0

        $rect = New-Object System.Drawing.Rectangle(0, 0, $SampleSize, $SampleSize)
        $data = $sample.LockBits(
            $rect,
            [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )
        try {
            $stride = $data.Stride
            $totalBytes = [Math]::Abs($stride) * $SampleSize
            $raw = New-Object byte[] $totalBytes
            [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $raw, 0, $totalBytes)

            for ($y = 0; $y -lt $SampleSize; $y++) {
                $row = $y * $stride
                for ($x = 0; $x -lt $SampleSize; $x++) {
                    $i = $row + ($x * 4)
                    $b = [int]$raw[$i]
                    $gCh = [int]$raw[$i + 1]
                    $r = [int]$raw[$i + 2]
                    $a = [int]$raw[$i + 3]

                    if ($a -lt 200) { continue }
                    # Pure white field
                    if ($r -ge 248 -and $gCh -ge 248 -and $b -ge 248) { continue }
                    # Roblox catalog backdrop is a light near-neutral gray (~#A8A8A4).
                    $mx = [Math]::Max([Math]::Max($r, $gCh), $b)
                    $mn = [Math]::Min([Math]::Min($r, $gCh), $b)
                    $avg = ($r + $gCh + $b) / 3.0
                    if (($mx - $mn) -le 16 -and $avg -ge 145 -and $avg -le 220) { continue }

                    $qr = $r -shr $shift
                    $qg = $gCh -shr $shift
                    $qb = $b -shr $shift
                    $key = ($qr -shl (2 * $BucketBits)) -bor ($qg -shl $BucketBits) -bor $qb

                    if (-not $counts.ContainsKey($key)) {
                        $counts[$key] = 0
                        $sumsR[$key] = 0
                        $sumsG[$key] = 0
                        $sumsB[$key] = 0
                    }
                    $counts[$key]++
                    $sumsR[$key] += $r
                    $sumsG[$key] += $gCh
                    $sumsB[$key] += $b
                    $kept++
                }
            }
        } finally {
            $sample.UnlockBits($data)
        }

        if ($kept -eq 0) { return @() }

        $clusters = New-Object System.Collections.Generic.List[object]
        foreach ($key in $counts.Keys) {
            $n = $counts[$key]
            $clusters.Add([pscustomobject]@{
                r = [int][Math]::Round($sumsR[$key] / $n)
                g = [int][Math]::Round($sumsG[$key] / $n)
                b = [int][Math]::Round($sumsB[$key] / $n)
                count = $n
            })
        }

        $ordered = @($clusters | Sort-Object count -Descending)
        $merged = New-Object System.Collections.Generic.List[object]

        foreach ($c in $ordered) {
            $hostIdx = -1
            for ($mi = 0; $mi -lt $merged.Count; $mi++) {
                $m = $merged[$mi]
                $dr = $c.r - $m.r; $dg = $c.g - $m.g; $db = $c.b - $m.b
                $dist = [Math]::Sqrt(($dr * $dr) + ($dg * $dg) + ($db * $db))
                if ($dist -le $MergeDistance) { $hostIdx = $mi; break }
            }

            if ($hostIdx -lt 0) {
                $merged.Add([pscustomobject]@{
                    r = $c.r; g = $c.g; b = $c.b; count = $c.count
                })
            } else {
                $m = $merged[$hostIdx]
                $total = $m.count + $c.count
                $m.r = [int][Math]::Round((($m.r * $m.count) + ($c.r * $c.count)) / $total)
                $m.g = [int][Math]::Round((($m.g * $m.count) + ($c.g * $c.count)) / $total)
                $m.b = [int][Math]::Round((($m.b * $m.count) + ($c.b * $c.count)) / $total)
                $m.count = $total
            }
        }

        $top = @($merged | Sort-Object count -Descending | Select-Object -First $MaxColors)
        $out = @()
        foreach ($c in $top) {
            $out += [pscustomobject]@{
                hex      = ConvertTo-HexColor -R $c.r -G $c.g -B $c.b
                coverage = [Math]::Round(($c.count / $kept), 4)
            }
        }
        return $out
    } finally {
        if ($sample) { $sample.Dispose() }
        if ($src) { $src.Dispose() }
        if ($ms) { $ms.Dispose() }
    }
}

function Get-AssetDominantColors {
    <# Resolve CDN URL (if needed), download bytes, return analysis object. #>
    param(
        [Parameter(Mandatory)] [long] $AssetId,
        [string] $ThumbnailUrl,
        [int] $MaxColors = 3
    )

    if (-not $ThumbnailUrl) {
        $map = Get-AssetThumbnailUrls -Ids @($AssetId)
        $ThumbnailUrl = $map[$AssetId]
    }
    if (-not $ThumbnailUrl) {
        return [pscustomobject]@{
            id           = $AssetId
            thumbnailUrl = $null
            colors       = @()
            error        = 'thumbnail_unavailable'
        }
    }

    try {
        $bytes = Get-ImageBytes -Url $ThumbnailUrl
        $colors = @(Get-DominantColorsFromBytes -Bytes $bytes -MaxColors $MaxColors)
        # Flatten accidental nesting from PowerShell array returns.
        if ($colors.Count -eq 1 -and $colors[0] -is [System.Array]) {
            $colors = @($colors[0])
        }
        return [pscustomobject]@{
            id           = $AssetId
            thumbnailUrl = $ThumbnailUrl
            colors       = @($colors)
            error        = $null
        }
    } catch {
        return [pscustomobject]@{
            id           = $AssetId
            thumbnailUrl = $ThumbnailUrl
            colors       = @()
            error        = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function `
    Get-AssetThumbnailUrls, Get-ImageBytes, Get-DominantColorsFromBytes, `
    Get-AssetDominantColors, ConvertTo-HexColor
