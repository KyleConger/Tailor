#requires -Version 5.1
<#
    OutfitMatcher.psm1
    Pairs Classic Shirts (tops) with Classic Pants (bottoms) that belong to the
    same outfit. Groups name their sets with a shared base name plus a role
    suffix, e.g. "[B] Vito, Upper" (shirt) and "[B] Vito, Lower" (pants). We
    normalize away the decoration + role tokens to derive a match key, then pair
    tops and bottoms that share that key within the same group.
#>

# Whole-word tokens that describe the garment's role rather than the outfit name.
# Stripped so "Vito Upper" and "Vito Lower" collapse to the same key "vito".
$script:RoleTokens = @(
    'upper', 'uppers', 'lower', 'lowers',
    'top', 'tops', 'bottom', 'bottoms',
    'shirt', 'shirts', 'tshirt', 'tshirts', 'tee', 'tees',
    'pant', 'pants', 'trouser', 'trousers',
    'jean', 'jeans', 'short', 'shorts', 'skirt', 'skirts',
    'overshirt', 'undershirt',
    # Bottom synonyms
    'slacks', 'chino', 'chinos', 'jogger', 'joggers',
    'sweatpants', 'leggings', 'cargo', 'cargos',
    # Top garment types (stripping keeps the outfit base name consistent)
    'polo', 'polos', 'waistcoat', 'waistcoats', 'blazer', 'blazers',
    'jacket', 'jackets', 'hoodie', 'hoodies', 'sweater', 'sweaters',
    'vest', 'vests', 'coat', 'coats',
    # Studio 20 Clothing Co. uses Variant (tops) / Dropdown (bottoms)
    'variant', 'variants', 'dropdown', 'dropdowns'
)

function Get-OutfitKey {
    <# Reduce a catalog name to a comparable outfit key. #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Name)

    $key = $Name.ToLowerInvariant()

    # Drop bracketed / parenthesized decorations: "[b]", "(v2)", "{new}".
    $key = [regex]::Replace($key, '[\[\(\{][^\]\)\}]*[\]\)\}]', ' ')

    # Punctuation -> spaces so tokens split cleanly.
    $key = [regex]::Replace($key, "[^a-z0-9\s]", ' ')

    # Remove role tokens as standalone words.
    $pattern = '\b(' + ($script:RoleTokens -join '|') + ')\b'
    $key = [regex]::Replace($key, $pattern, ' ')

    # Collapse whitespace.
    $key = [regex]::Replace($key, '\s+', ' ').Trim()

    return $key
}

function Get-OutfitMatches {
    <#
        Input: flat list of normalized clothing records (see Get-GroupClothing).
        Output: pscustomobject with .matched, .unmatchedTops, .unmatchedBottoms
        arrays. Matching is scoped per group + outfit key.
    #>
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Records)

    $matched          = New-Object System.Collections.Generic.List[object]
    $unmatchedTops    = New-Object System.Collections.Generic.List[object]
    $unmatchedBottoms = New-Object System.Collections.Generic.List[object]

    # Bucket by group so identical names across groups never cross-match.
    $byGroup = $Records | Group-Object -Property groupId

    foreach ($group in $byGroup) {
        $tops    = @{}  # key -> list of top records
        $bottoms = @{}  # key -> list of bottom records

        foreach ($rec in $group.Group) {
            if ($rec.role -ne 'top' -and $rec.role -ne 'bottom') { continue }

            $key = Get-OutfitKey -Name $rec.name
            $rec | Add-Member -NotePropertyName outfitKey -NotePropertyValue $key -Force

            if ($rec.role -eq 'top') {
                if (-not $tops.ContainsKey($key)) { $tops[$key] = New-Object System.Collections.Generic.List[object] }
                $tops[$key].Add($rec)
            } elseif ($rec.role -eq 'bottom') {
                if (-not $bottoms.ContainsKey($key)) { $bottoms[$key] = New-Object System.Collections.Generic.List[object] }
                $bottoms[$key].Add($rec)
            }
        }

        $allKeys = @($tops.Keys) + @($bottoms.Keys) | Select-Object -Unique

        foreach ($key in $allKeys) {
            $hasTop    = $tops.ContainsKey($key)    -and $key -ne ''
            $hasBottom = $bottoms.ContainsKey($key) -and $key -ne ''

            if ($hasTop -and $hasBottom) {
                foreach ($t in $tops[$key]) {
                    foreach ($b in $bottoms[$key]) {
                        $priceTotal = $null
                        if ($null -ne $t.price -and $null -ne $b.price) { $priceTotal = $t.price + $b.price }

                        $matched.Add([pscustomobject]@{
                            groupId    = $t.groupId
                            groupName  = $t.groupName
                            outfitKey  = $key
                            topId      = $t.id
                            topName    = $t.name
                            topPrice   = $t.price
                            bottomId   = $b.id
                            bottomName = $b.name
                            bottomPrice= $b.price
                            priceTotal = $priceTotal
                            topUrl     = $t.url
                            bottomUrl  = $b.url
                        })
                    }
                }
            } else {
                if ($hasTop)    { foreach ($t in $tops[$key])    { $unmatchedTops.Add($t) } }
                if ($hasBottom) { foreach ($b in $bottoms[$key]) { $unmatchedBottoms.Add($b) } }
            }
        }

        # Tops/bottoms whose key normalized to empty can't be paired reliably.
        if ($tops.ContainsKey(''))    { foreach ($t in $tops[''])    { $unmatchedTops.Add($t) } }
        if ($bottoms.ContainsKey('')) { foreach ($b in $bottoms['']) { $unmatchedBottoms.Add($b) } }
    }

    return [pscustomobject]@{
        matched          = $matched.ToArray()
        unmatchedTops    = $unmatchedTops.ToArray()
        unmatchedBottoms = $unmatchedBottoms.ToArray()
    }
}

Export-ModuleMember -Function Get-OutfitKey, Get-OutfitMatches
