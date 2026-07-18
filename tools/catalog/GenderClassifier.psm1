#requires -Version 5.1
<#
    GenderClassifier.psm1
    Assign masculine / feminine / unclassified to classic 2D clothing items.

    Roblox's public catalog details endpoint does not expose a gender field for
    Classic Shirts/Pants, so we infer from naming conventions used by these
    tailor groups (e.g. Style Abby [M]/[W] tags, "Lady", "skirt", "dress")
    and fall back to an optional per-group default.
#>

# Explicit role tags commonly used in outfit names.
$script:MasculineTagPattern = '(?i)(?:\[|\(|\{)\s*(?:M|Male|Men|Man|Masculine)\s*(?:\]|\)|\})'
$script:FeminineTagPattern  = '(?i)(?:\[|\(|\{)\s*(?:W|F|Female|Women|Woman|Feminine|Ladies)\s*(?:\]|\)|\})'

# Whole-word gender descriptors (not garment types).
$script:MasculineWordPattern = '(?i)\b(?:men|man|male|masculine|gentleman|gentlemen|boys?)\b'
$script:FeminineWordPattern  = '(?i)\b(?:women|woman|female|feminine|lad(?:y|ies)|girls?|nurses?)\b'

# Garment types that are strongly gendered for these formalwear catalogs.
# Kept conservative: only forms that rarely appear on the opposite presentation.
$script:FeminineGarmentPattern = '(?i)\b(?:skirts?|dresses?|blouses?|gowns?|bodices?|corsets?|chemises?|petticoats?|frocks?)\b'
$script:MasculineGarmentPattern = '(?i)\b(?:tuxedos?|tux(?:es)?|waistcoats?|double[\s-]?breasted)\b'

function Get-ClothingGender {
    <#
        Returns 'masculine', 'feminine', or 'unclassified'.
        $DefaultGender (optional) is used only when no name signal is found.
    #>
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Name,
        [ValidateSet('masculine', 'feminine', 'unclassified', '')]
        [string] $DefaultGender = 'unclassified'
    )

    if (-not $DefaultGender) { $DefaultGender = 'unclassified' }

    $hasMascTag = $Name -match $script:MasculineTagPattern
    $hasFemTag  = $Name -match $script:FeminineTagPattern
    if ($hasMascTag -and -not $hasFemTag) { return 'masculine' }
    if ($hasFemTag  -and -not $hasMascTag) { return 'feminine' }

    $hasMascWord = $Name -match $script:MasculineWordPattern
    $hasFemWord  = $Name -match $script:FeminineWordPattern
    if ($hasMascWord -and -not $hasFemWord) { return 'masculine' }
    if ($hasFemWord  -and -not $hasMascWord) { return 'feminine' }

    $hasFemGarment  = $Name -match $script:FeminineGarmentPattern
    $hasMascGarment = $Name -match $script:MasculineGarmentPattern
    if ($hasFemGarment -and -not $hasMascGarment) { return 'feminine' }
    if ($hasMascGarment -and -not $hasFemGarment) { return 'masculine' }

    return $DefaultGender
}

function Add-ClothingGender {
    <#
        Annotate each record with a .gender property. $GroupDefaults is a
        hashtable of groupId (or slug) -> default gender string.
    #>
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Records,
        [hashtable] $GroupDefaults = @{}
    )

    foreach ($rec in $Records) {
        $default = 'unclassified'
        if ($GroupDefaults.ContainsKey([string]$rec.groupId)) {
            $default = $GroupDefaults[[string]$rec.groupId]
        } elseif ($rec.PSObject.Properties['groupSlug'] -and $GroupDefaults.ContainsKey([string]$rec.groupSlug)) {
            $default = $GroupDefaults[[string]$rec.groupSlug]
        }

        $gender = Get-ClothingGender -Name ([string]$rec.name) -DefaultGender $default
        $rec | Add-Member -NotePropertyName gender -NotePropertyValue $gender -Force
    }

    return $Records
}

Export-ModuleMember -Function Get-ClothingGender, Add-ClothingGender
