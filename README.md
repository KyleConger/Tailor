# Limit Testing

## Setup

```bash
wally install
rojo serve
```

Open the generated place in Roblox Studio and connect Rojo.

## Packages

Installed via Wally into `ReplicatedStorage/Packages`:

- **Knit** — services and controllers
- **Component** — tagged instance components
- **Promise** — async (used by Knit)
- **Log** — structured logging
- **SentryRoblox** — error reporting

## Project layout

| Path | Rojo target |
|------|-------------|
| `src/server` | `ServerScriptService/Source` |
| `src/client` | `StarterPlayerScripts/Source` |
| `src/shared` | `ReplicatedStorage/Source` |
| `Packages` | `ReplicatedStorage/Packages` |

## Entrypoints

- **Server:** `KnitRuntime.server.lua` boots logging, Sentry, components, and services.
- **Client:** `KnitRuntime.client.lua` boots logging and controllers.
- **Sentry:** set `Enabled = true` and your `DSN` in `src/shared/SentryConfig.lua`.

## Adding code

- New **service** → `src/server/Services/MyService.lua`
- New **controller** → `src/client/Controllers/MyController.lua`
- New **component** → `src/server/Components/MyComponent.lua` (set a CollectionService tag)
