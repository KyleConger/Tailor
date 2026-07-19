# Project Overview

Roblox project scaffold using Knit, Component, Log, and SentryRoblox. Rojo syncs `src/` into Studio; Wally packages live in `ReplicatedStorage/Packages`.

Git remote: `https://github.com/KyleConger/Limit-Testing`

# How To Run / Develop

```bash
wally install
rojo serve
```

- Build place file: `rojo build -o "Limit Testing.rbxlx"`
- Regenerate sourcemap: `rojo sourcemap default.project.json -o sourcemap.json`
- Tooling: `aftman.toml` (wally, rojo 7.7.0), `selene.toml` (roblox std)

# Rojo Layout

| Local path | Studio path |
|------------|-------------|
| `src/server` | `ServerScriptService/Source` |
| `src/client` | `StarterPlayer/StarterPlayerScripts/Source` |
| `src/shared` | `ReplicatedStorage/Source` |
| `Packages` | `ReplicatedStorage/Packages` |

# Repository Map

```
src/
  server/
    KnitRuntime.server.lua       # boots logger, sentry, components, services
    ServerSentryLoader.server.lua
    Services/
      BootstrapService.lua
    Components/
      ExampleComponent.lua       # tag: "Example"
  client/
    KnitRuntime.client.lua       # boots logger, controllers
    ClientSentryLoader.client.lua
    Controllers/
      BootstrapController.lua
    Components/
      init.meta.json             # placeholder for client component extensions
  shared/
    LoggerConfig.lua
    LoggerSetup.lua
    SentryConfig.lua
    SentryLoader.lua
```

# Bootstrap Flow

## Server (`KnitRuntime.server.lua`)

1. `LoggerSetup.init()` — configures vorlias/log default logger
2. `SentryLoader.initServer()` — inits Sentry if enabled in `SentryConfig`
3. Requires all modules in `Components/`
4. `Knit.AddServices(Services/)` then `Knit.Start()`

## Client (`KnitRuntime.client.lua`)

1. `LoggerSetup.init()`
2. `Knit.AddControllers(Controllers/)` then `Knit.Start()`

## Sentry

- Config: `src/shared/SentryConfig.lua` (`Enabled`, `DSN`, `Environment`, `Release`)
- Server init: `ServerSentryLoader.server.lua` and `KnitRuntime.server.lua` (idempotent via `SentryLoader`)
- Client errors relayed by SentryRoblox's `SentryClientRelay` once server inits with a valid DSN
- `ClientSentryLoader.client.lua` is a no-op placeholder when Sentry is disabled

## Logging

- Config: `src/shared/LoggerConfig.lua` (`MinLevel`, `StudioMinLevel`)
- Use `Log.ForContext("MyModule"):Info("message {Key}", value)` after `LoggerSetup.init()`

# Knit Modules

## Services

- **BootstrapService** — logs when server Knit finishes starting

## Controllers

- **BootstrapController** — logs when client Knit finishes starting

## Components

- **ExampleComponent** — CollectionService tag `Example`; logs when tagged instances start

# Conventions

- Services → `src/server/Services/`; auto-loaded by `Knit.AddServices`
- Controllers → `src/client/Controllers/`; auto-loaded by `Knit.AddControllers`
- Components → `src/server/Components/`; required manually in `KnitRuntime.server.lua` before `Knit.Start()`
- Shared config/helpers → `src/shared/`
- Require packages: `require(ReplicatedStorage.Packages.Knit)` (etc.)

# Dependencies

Direct (`wally.toml`):

| Package | Version | Role |
|---------|---------|------|
| Knit | 1.7.0 | Services, controllers, remotes |
| Component | 2.4.8 | Tagged instance lifecycle |
| Promise | 4.0.0 | Async (Knit transitive + direct use) |
| Log | 0.6.4 | Structured logging |
| SentryRoblox | 1.2.1 | Error reporting |

Transitive (via `Packages/_Index/`): Comm, Signal, Symbol, Trove, Option

# Changelog

- 2026-06-09 — Reset AGENT_CONTEXT. Fresh Limit Testing scaffold: Knit/Component/Log/Sentry bootstrap, BootstrapService/Controller, ExampleComponent. Removed legacy game documentation.
