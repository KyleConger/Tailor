# Clothing Catalog Tool

Enumerates **Classic Shirts** and **Classic Pants** sold by a configured set of
Roblox groups, classifies them as **masculine** / **feminine**, then matches
tops with bottoms within each gender.

Classic T-Shirts and all 3D / layered clothing are omitted.

Pure PowerShell + the public Roblox catalog API. No auth, no Node/Python needed.

## Files

| File | Purpose |
|------|---------|
| `groups.json` | Groups to catalog (`id`, `name`, `slug`, `defaultGender`). |
| `CatalogApi.psm1` | Roblox catalog client (CSRF, pagination, batched details, retry/backoff). |
| `GenderClassifier.psm1` | Infers masculine / feminine from name tags, keywords, and garment types. |
| `OutfitMatcher.psm1` | Normalizes item names and pairs tops with bottoms. |
| `Build-Catalog.ps1` | Orchestrator: fetch → filter → classify → match → write outputs. |
| `output/` | Generated results (see below). |

## Usage

```powershell
# From this folder:
./Build-Catalog.ps1                       # all groups
./Build-Catalog.ps1 -Slug beneventis      # one group
./Build-Catalog.ps1 -SkipFetch            # re-classify/match from cached output/raw/*.json
```

If script execution is blocked, run once in the session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## Outputs (`output/`)

| Path | Contents |
|------|----------|
| `raw/<slug>.json` | Per-group snapshot (also the `-SkipFetch` cache). |
| `catalog.json` / `catalog.csv` | Every Classic Shirt/Pants item, with a `gender` field. |
| `matches.json` / `matches.csv` | All paired outfits across genders. |
| `masculine/` | Catalog, matches, unmatched lists, and summary for masculine items. |
| `feminine/` | Same, for feminine items. |
| `unclassified/` | Same, for items with no gender signal (and no group default). |
| `summary.json` | Per-group counts + gender totals. |

## Gender classification

Roblox's public catalog details API does not expose gender for Classic Shirts /
Pants, so we infer it in this order:

1. **Explicit tags** — `[M]` / `[Male]` → masculine; `[W]` / `[F]` / `[Female]` → feminine
2. **Gender words** — `men`, `male`, `gentleman` vs `women`, `lady`, `female`, …
3. **Garment types** — `skirt`, `dress`, `blouse`, `gown`, … → feminine; `tuxedo`, `waistcoat`, … → masculine
4. **Group default** — `defaultGender` in `groups.json` (menswear houses default to masculine; mixed groups leave unclassified)

Matching is performed **within** each gender bucket so a masculine top is never
paired with a feminine bottom.

## How top/bottom matching works

Groups name outfit sets with a shared base name plus a role suffix, e.g.
`[B] Vito, Upper` (shirt) and `[B] Vito, Lower` (pants). The matcher:

1. Uses `assetType` as the authoritative role — `11` = top, `12` = bottom.
2. Normalizes the name into a key by removing bracketed tags, punctuation, and
   role words (`upper`, `lower`, `top`, `bottom`, `shirt`, `pants`, …).
3. Pairs a top with a bottom that share the same key **within the same group**.

Anything that doesn't pair cleanly lands in the `unmatched-*` lists for review.
