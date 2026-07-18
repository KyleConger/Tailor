#requires -Version 5.1
<#
    CatalogApi.psm1
    Thin wrapper around Roblox's public catalog endpoints used to enumerate the
    2D clothing (Classic Shirts / Classic Pants / Classic T-Shirts) that a group
    sells. No authentication is required for public catalog data; the details
    endpoint only needs a rotating x-csrf-token which we fetch automatically.
#>

$script:SearchUrl  = 'https://catalog.roblox.com/v1/search/items'
$script:DetailsUrl = 'https://catalog.roblox.com/v1/catalog/items/details'

# assetTypeId -> our normalized role. Everything else is ignored (bundles, UGC,
# accessories, etc.) because the request is scoped to 2D clothing.
$script:RoleByAssetType = @{
    2  = 'tshirt'  # Classic T-Shirt
    11 = 'top'     # Classic Shirt
    12 = 'bottom'  # Classic Pants
}

function Get-RobloxCsrfToken {
    <# Roblox returns the token in an x-csrf-token header on a 403. #>
    try {
        Invoke-RestMethod -Uri $script:DetailsUrl -Method Post `
            -Body '{"items":[]}' -ContentType 'application/json' | Out-Null
        return $null
    } catch {
        $resp = $_.Exception.Response
        if ($null -ne $resp) {
            $token = $resp.Headers['x-csrf-token']
            if ($token) { return $token }
        }
        throw "Unable to obtain x-csrf-token: $($_.Exception.Message)"
    }
}

function Invoke-CatalogRequest {
    <#
        Wrapper that transparently handles CSRF rotation (403) and rate limiting
        (429) with bounded retries. $CsrfRef is a [ref] so a refreshed token is
        reused by later calls.
    #>
    param(
        [Parameter(Mandatory)] [string] $Uri,
        [Parameter(Mandatory)] [ValidateSet('Get', 'Post')] [string] $Method,
        [string] $Body,
        [ref] $CsrfRef,
        [int] $MaxRetries = 6
    )

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $headers = @{}
        if ($Method -eq 'Post' -and $CsrfRef -and $CsrfRef.Value) {
            $headers['x-csrf-token'] = $CsrfRef.Value
        }

        try {
            $params = @{
                Uri         = $Uri
                Method      = $Method
                Headers     = $headers
                ErrorAction = 'Stop'
            }
            if ($Method -eq 'Post') {
                $params['Body'] = $Body
                $params['ContentType'] = 'application/json'
            }
            return Invoke-RestMethod @params
        } catch {
            $resp = $_.Exception.Response
            $status = if ($resp) { [int]$resp.StatusCode } else { 0 }

            if ($status -eq 403 -and $resp.Headers['x-csrf-token'] -and $CsrfRef) {
                # Token expired/rotated: pick up the fresh one and retry immediately.
                $CsrfRef.Value = $resp.Headers['x-csrf-token']
                continue
            }

            if ($status -eq 429) {
                $wait = [Math]::Min(30, [Math]::Pow(2, $attempt))
                Write-Warning "Rate limited (429). Backing off $wait s (attempt $attempt/$MaxRetries)."
                Start-Sleep -Seconds $wait
                continue
            }

            if ($attempt -lt $MaxRetries) {
                Write-Warning "Request failed ($status): $($_.Exception.Message). Retrying..."
                Start-Sleep -Seconds ([Math]::Min(10, $attempt * 2))
                continue
            }

            throw
        }
    }

    throw "Request to $Uri failed after $MaxRetries attempts."
}

function Get-GroupClothingIds {
    <# Paginates the catalog search for a group's Clothing category. #>
    param(
        [Parameter(Mandatory)] [long] $GroupId,
        [ref] $CsrfRef,
        [int] $ThrottleMs = 350
    )

    $ids = New-Object System.Collections.Generic.List[long]
    $cursor = $null

    do {
        $uri = "$($script:SearchUrl)?category=Clothing&creatorType=Group&creatorTargetId=$GroupId&limit=30&salesTypeFilter=1"
        if ($cursor) { $uri += "&cursor=$([uri]::EscapeDataString($cursor))" }

        $page = Invoke-CatalogRequest -Uri $uri -Method Get -CsrfRef $CsrfRef
        foreach ($entry in $page.data) {
            if ($entry.itemType -eq 'Asset') { $ids.Add([long]$entry.id) }
        }

        $cursor = $page.nextPageCursor
        if ($cursor) { Start-Sleep -Milliseconds $ThrottleMs }
    } while ($cursor)

    return $ids
}

function Get-ItemDetails {
    <# Batched details lookup. Roblox caps the details endpoint well above 50. #>
    param(
        [Parameter(Mandatory)] [long[]] $Ids,
        [ref] $CsrfRef,
        [int] $BatchSize = 50,
        [int] $ThrottleMs = 350
    )

    $results = New-Object System.Collections.Generic.List[object]

    for ($i = 0; $i -lt $Ids.Count; $i += $BatchSize) {
        $chunk = $Ids[$i..([Math]::Min($i + $BatchSize - 1, $Ids.Count - 1))]
        $items = $chunk | ForEach-Object { @{ itemType = 'Asset'; id = $_ } }
        $body = @{ items = @($items) } | ConvertTo-Json -Depth 4 -Compress

        $resp = Invoke-CatalogRequest -Uri $script:DetailsUrl -Method Post -Body $body -CsrfRef $CsrfRef
        foreach ($d in $resp.data) { $results.Add($d) }

        if ($i + $BatchSize -lt $Ids.Count) { Start-Sleep -Milliseconds $ThrottleMs }
    }

    return $results
}

function Get-GroupClothing {
    <#
        High-level: returns normalized 2D-clothing records for a group.
        Each record: id, name, role (top|bottom|tshirt), assetType, price,
        productId, collectibleItemId, groupId, groupName, url, created.
    #>
    param(
        [Parameter(Mandatory)] [long] $GroupId,
        [string] $GroupName,
        [ref] $CsrfRef
    )

    if (-not $CsrfRef -or -not $CsrfRef.Value) {
        $token = Get-RobloxCsrfToken
        if ($CsrfRef) { $CsrfRef.Value = $token }
    }

    $ids = Get-GroupClothingIds -GroupId $GroupId -CsrfRef $CsrfRef
    if ($ids.Count -eq 0) { return @() }

    $details = Get-ItemDetails -Ids $ids.ToArray() -CsrfRef $CsrfRef

    $records = New-Object System.Collections.Generic.List[object]
    foreach ($d in $details) {
        $role = $script:RoleByAssetType[[int]$d.assetType]
        if (-not $role) { continue }  # not a 2D clothing item we care about

        $records.Add([pscustomobject]@{
            id                = [long]$d.id
            name              = [string]$d.name
            role              = $role
            assetType         = [int]$d.assetType
            price             = if ($null -ne $d.price) { [int]$d.price } else { $null }
            lowestPrice       = if ($null -ne $d.lowestPrice) { [int]$d.lowestPrice } else { $null }
            productId         = $d.productId
            collectibleItemId = $d.collectibleItemId
            groupId           = [long]$GroupId
            groupName         = if ($GroupName) { $GroupName } else { [string]$d.creatorName }
            url               = "https://www.roblox.com/catalog/$($d.id)"
            created           = [string]$d.itemCreatedUtc
        })
    }

    return $records
}

Export-ModuleMember -Function `
    Get-RobloxCsrfToken, Invoke-CatalogRequest, Get-GroupClothingIds, `
    Get-ItemDetails, Get-GroupClothing
