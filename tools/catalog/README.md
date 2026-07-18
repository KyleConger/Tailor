# Clothing Catalog Tool

Enumerates every **2D clothing** item (Classic Shirts, Classic Pants, Classic
T-Shirts) sold by a configured set of Roblox groups, then matches **tops**
(shirts) with **bottoms** (pants) into outfits.

Pure PowerShell + the public Roblox catalog API. No auth, no Node/Python needed.

## Files

| File | Purpose |
|------|---------|
| `groups.json` | The groups to catalog (`id`, `name`, `slug`). |
| `CatalogApi.psm1` | Roblox catalog client (CSRF, pagination, batched details, retry/backoff). |
| `OutfitMatcher.psm1` | Normalizes item names and pairs tops with bottoms. |
| `Build-Catalog.ps1` | Orchestrator: fetch -> catalog -> match -> write outputs. |
| `output/` | Generated results (see below). |

## Usage

```powershell
# From this folder:
./Build-Catalog.ps1                       # all groups
./Build-Catalog.ps1 -Slug beneventis      # one group
./Build-Catalog.ps1 -Slug beneventis,gravelle
./Build-Catalog.ps1 -SkipFetch            # re-match from cached output/raw/*.json
```

If script execution is blocked, run once in the session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## Outputs (`output/`)

| File | Contents |
|------|----------|
| `raw/<slug>.json` | Per-group normalized snapshot (also the `-SkipFetch` cache). |
| `catalog.json` / `catalog.csv` | Every item across all groups. |
| `matches.json` / `matches.csv` | Paired outfits (top + bottom, prices, links). |
| `unmatched-tops.csv` | Shirts with no detected pants partner — needs manual review. |
| `unmatched-bottoms.csv` | Pants with no detected shirt partner — needs manual review. |
| `tshirts.csv` | Classic T-Shirts (standalone, not paired). |
| `summary.json` | Per-group counts + totals. |

## How matching works

Groups name outfit sets with a shared base name plus a role suffix, e.g.
`[B] Vito, Upper` (shirt) and `[B] Vito, Lower` (pants). The matcher:

1. Uses `assetType` as the authoritative role — `11` = top, `12` = bottom, `2` = t-shirt.
2. Normalizes the name into a key by removing bracketed tags (`[B]`), punctuation,
   and role words (`upper`, `lower`, `top`, `bottom`, `shirt`, `pants`, ...).
3. Pairs a top with a bottom that share the same key **within the same group**.

Anything that doesn't pair cleanly lands in the `unmatched-*` lists for review,
so no item is silently dropped. To improve matching, extend `$RoleTokens` in
`OutfitMatcher.psm1` and re-run with `-SkipFetch`.
