# Project Overview
- Round-based lacrosse game: players manually pick teams/slots (no auto assignment or rotation), race for kickoff (only slot 1 per team participates), carry/pass/throw a ball, score on tagged goals, and can opt into a goalie role. Core flows live in `src/server/Services/RoundService.lua`, `BallService.lua`, `ActionService.lua`, and `GoalieService.lua`.
- Architecture: Rojo (`default.project.json`) maps `src/server` -> `ServerScriptService`, `src/client` -> `StarterPlayerScripts`, `src/shared` -> `ReplicatedStorage/Source`; Wally packages in `ReplicatedStorage/Packages`. Knit boots from `src/server/KnitRuntime.server.lua` and `src/client/KnitRuntime.client.lua`; components via `sleitnick/component`; Cmdr for admin commands; Sentry loaders use `src/shared/SentryConfig.lua`.

# How To Run / Develop
- Build/sync with Rojo: `rojo build -o "Lax Blast.rbxlx"` then `rojo serve` (per `README.md`); layout defined in `default.project.json`.
- Knit entrypoints: server `src/server/KnitRuntime.server.lua`; client `src/client/KnitRuntime.client.lua`.
- Tooling: `aftman.toml` pins `wally`; `selene.toml` uses `roblox`.
- Sentry: `src/server/ServerSentryLoader.server.lua` and `src/client/ClientSentryLoader.client.lua` read `ReplicatedStorage/Source/SentryConfig`.
- Assets required in Studio place: `ReplicatedStorage/Assets` (Meshes/Animations/Sounds/UI/Effects/Maps) and `ServerStorage/Characters/Goalie`—not stored in repo.

# Repository Map (Most Important Paths)
- `src/server/Services` - Knit services (rounds, ball, actions, stamina, voting, map loading, ragdoll, goalie).
- `src/server/Components` - Tagged components (`Goal`, `OutOfBounds`, `RollingFriction`) for workspace parts.
- `src/server/Cmdr` - Cmdr setup and commands (ball reset/drop/give, ragdoll, goalie/player toggle, pause/resume, team/slot selection) with permissions in `AdminConfig.lua`.
- `src/client/Controllers` - Knit controllers for actions, input, HUD, voting, kickoff prompt, goalie handling, mobile UI, ragdoll camera, tilt, crease collision, team/goalie selection UI.
- `src/shared/Libs` - Shared helpers (`Hitbox.lua`, `Ragdoll.lua`, `Mouse2.rbxm`, `RotatedRegion3.rbxm`) and `SentryConfig.lua`.
- `Packages` - Wally-installed libraries under `ReplicatedStorage/Packages`.
- `backup/` - Legacy code/analysis not loaded by Rojo.

# Knit Architecture
## Services
- **ActionService** (`src/server/Services/ActionService.lua`): Handles Truck/Poke/Shoot/Pass with stamina costs/cooldowns; client remotes for each and `ActionEvent` for HUD cooldown. Validates carrier status, team alignment (passes), stamina, goalie/kickoff/stun/paused blocks, drop/touch cooldowns; uses `Hitbox` for melee; plays animations/SFX; Truck ragdolls/stuns/drops ball.
- **BallService** (`src/server/Services/BallService.lua`): Owns ball creation, touch pickup, carrier tracking, drops, passes, throws, collision groups, `RollingFriction` tagging. Attributes set on ball/carrier (e.g., `LastTeam`, `CarrierUserId`, `PassingTargetId`, `LastShooterIsGoalie`). Disables touch during kickoff; prevents pickup if stunned or on cooldown; manages visuals (HeadIcon/Highlight).
- **GoalieService** (`src/server/Services/GoalieService.lua`): One goalie per team; swaps character to `ServerStorage/Characters/Goalie`, sets `Goalie` attribute, removes from normal field slots, applies stick collision, resets uniforms. Signals `GoalieState`/`GoalieAssignments`; remotes `RequestGoalie(team?)`, `LeaveGoalie`, `GetGoalieSnapshot`.
- **MapService** (`src/server/Services/MapService.lua`): Clones maps from `ReplicatedStorage/Assets/Maps` to `Workspace/Game`, cleans prior map, applies lighting, signals `MapLoaded`; helpers `LoadMap`, `CleanupMap`, `GetSpawn`, `GetMap`.
- **RagdollService** (`src/server/Services/RagdollService.lua`): Wraps shared `Ragdoll` lib; remotes `RagdollEvent`; used by ActionService and RoundService.
- **RoundService** (`src/server/Services/RoundService.lua`): Drives round loop (Waiting -> Voting -> Countdown -> Kickoff -> Playing with quarters/goal pauses -> PostRound -> Intermission). Tracks state/time/scores/settings, teams/uniforms/teleports, kickoff races, goals, cleanup. Team slots are ordered sparse arrays per team (indices 1–5 preserved; no compaction); goalie slots separate via GoalieService. No auto team assignment—players select teams/slots; unassigned players stay put. Kickoff only uses the field player in slot 1 per team (empty/goalie means no runner for that side). Signals `StateChanged`, `GoalScored`, `KickoffPrompt`; remotes `GetState`, `GetScores`, `KickoffClick`, `GetTeamSnapshot`, `RequestJoinTeam` (blocks during kickoff/non-playing; capacity-aware). Supports manual pause/resume (`Paused` flag via `PauseRound/ResumeRound`, freezes players, drops/anchors ball and disables touch so no one can pick it up; context `paused` sent in `StateChanged`). Quarter length currently forced to 30s for testing.
- **StaminaService** (`src/server/Services/StaminaService.lua`): Stamina regen/drain, sprint speed, dash gating (carriers only); remotes `StartSprint`, `StopSprint`, `Dash`; signals `StaminaChanged`, `DashTriggered`; blocks goalies/frozen/paused players; heartbeat loop only active players.
- **VotingService** (`src/server/Services/VotingService.lua`): Runs match-setting votes (Duration, Team, Time, Weather); signals `VotingStarted`/`VotingEnded`; remotes `SubmitVote`, `GetOptions`; enforces one vote per player per category.

## Controllers
- **ActionController** (`src/client/Controllers/ActionController.lua`): Binds truck (E/ButtonB), poke/shoot (Mouse1/ButtonR2), pass (X/ButtonY); routes to ActionService; uses `Mouse2` for aim; highlights nearest teammate while carrying.
- **InputController** (`src/client/Controllers/InputController.lua`): Binds sprint (LeftShift/ButtonL3) and dash (Q/ButtonB), manages dash effects/FOV and movement animations; stops sprint on stamina drain; respects goalie state.
- **HudController** (`src/client/Controllers/HudController.lua`): Drives `PlayerGui/HUDGui` scoreboard/timer/stamina/truck cooldown from RoundService, StaminaService, ActionService signals; fallback notification if score UI missing.
- **VotingController** (`src/client/Controllers/VotingController.lua`): Shows `PlayerGui/VotingGui`, slide per category, countdown to end timestamp, submits votes.
- **KickoffController** (`src/client/Controllers/KickoffController.lua`): Listens to kickoff prompts; clones `Assets/UI/KickoffButton`, fires `KickoffClick`.
- **GoalieController** (`src/client/Controllers/GoalieController.lua`): Reacts to GoalieState/attribute; toggles camera zoom, Animate, stick collision.
- **GoalieHandlerController** (`src/client/Controllers/GoalieHandlerController.lua`): Goalie-only block inputs (high/low), custom animations, hitbox parts on stick; blocks input while holding ball; manages stun windows/reset.
- **CreaseController** (`src/client/Controllers/CreaseController.lua`): Toggles crease collision parts per team/goalie state; responds to map reloads.
- **RagdollController** (`src/client/Controllers/RagdollController.lua`): Camera/humanoid state changes on `RagdollEvent`.
- **RoundController** (`src/client/Controllers/RoundController.lua`): Logs round state snapshots.
- **SelectionController** (`src/client/Controllers/SelectionController.lua`): Connects `SelectionGui/Main/TeamSelect/Container` buttons (`Team1`, `Team2`, `Team1Goalie`, `Team2Goalie`) to team/goalie selection; hover toggles `onHover`, `Amount` shows `x/y` counts using `RoundService:GetTeamSnapshot` and `GoalieService` signals/snapshots; polls every few seconds and refreshes on state/goalie changes; actions call `RoundService:RequestJoinTeam` and `GoalieService:RequestGoalie(team)`.
- **TiltController** (`src/client/Controllers/TiltController.lua`): Lean joints based on velocity.
- **MobileController** (`src/client/Controllers/MobileController.lua`): Enables `PlayerGui/ShootSystem` on touch; wires buttons to ActionController/StaminaService.

## Shared Modules / Utilities
- `Hitbox.lua` (`src/shared/Libs/Hitbox.lua`): Region/sphere detection used by ActionService melee.
- `Ragdoll.lua` (`src/shared/Libs/Ragdoll.lua`): Ragdoll/stand helpers used by RagdollService.
- `Mouse2.rbxm` (`src/shared/Libs/Mouse2.rbxm`): Mouse hit helper used by ActionController.
- `RotatedRegion3.rbxm` (`src/shared/Libs/RotatedRegion3.rbxm`): Region helper used by `OutOfBoundsComponent`.
- `SentryConfig.lua` (`src/shared/SentryConfig.lua`): Shared DSN/env/release/debug for Sentry.

# Core Game Systems (Flows)
- **Player join -> ready**: `RoundService:KnitStart` no longer auto-assigns teams; players stay in place until they choose a team/slot (Cmdr UI pending). `StaminaService:SetupPlayer` seeds stamina/frozen attributes.
- **Voting to match start**: `RoundService:RunVotingPhase` calls `VotingService:BeginVoting`, broadcasts options/end time; results applied (duration forced to 30s for testing) before `BeginCountdown` loads map, teleports assigned players, anchors ball, counts down.
- **Kickoff flow**: `RunKickoff` freezes all, disables ball touch, selects only the field player in slot 1 per team, fires `KickoffPrompt`; winner gets carrier, loser ragdolled and `KickoffLocked` for 3s; unfreeze and resume play clock.
- **Ball handling**: `PlaceBallAtSpawn` creates/spawns ball, tags `RollingFriction`, tracks position; `AttachTouchHandler` grants possession if stick handle, not stunned, cooldowns passed, touch enabled; carrier welds ball, sets attributes/visuals; `PassBall`/`ThrowBallToPosition` set velocity/trails; `OutOfBoundsComponent` resets ball; `GoalComponent` handles scoring directionally and own-goal goalie ignore.
- **Combat actions**: Client inputs -> ActionService validates (opposite teams, carrier present, not goalie/kickoff/stunned/paused, stamina/cooldown) then spawns Hitbox. Truck drops ball, stuns/ragdolls target, applies shove and temporary stick drop; Poke stacks stun chance and may force drop; both spend stamina and trigger truck cooldown HUD.
- **Stamina/sprint/dash**: InputController toggles sprint/dash remotes; StaminaService drains on sprint movement, regens idle, gates dash to carriers with cooldown/cost; `DashTriggered` drives client dash BV/FOV; HUD bar via `StaminaChanged`.
- **Goalie loop**: Cmdr `goalie`/`player` (or `RequestGoalie`) toggles goalie; goalie character swap, crease collision opened, handler controls for saves; goalies excluded from field slot counts and ActionService melee unless carrying.
- **Round cleanup**: `CleanupAfterRound` clears uniforms/scores/ball, resets teams (empty sparse buckets), respawns players (strips shirts), resets goalies and map, emits Waiting state.
- **Pause/Resume**: `RoundService:PauseRound(duration?)` sets `IsPaused`, freezes players, anchors/disables ball touch, broadcasts `StateChanged` with `paused=true`; timers stop (`DecrementTime` gated). `ResumeRound` reverses and re-enables touch/ball anchor, unfreezes, re-broadcasts state. Cmdr commands `pause [duration]` / `resume` call these.

# Networking & Replication
- Knit remotes/signals: RoundService (`StateChanged` with `paused` flag, `GoalScored`, `KickoffPrompt`; remotes `GetState`, `GetScores`, `KickoffClick`, `GetTeamSnapshot`, `RequestJoinTeam`), ActionService (remotes Truck/Poke/Shoot/Pass; signal `ActionEvent`), StaminaService (remotes `StartSprint`, `StopSprint`, `Dash`; signals `StaminaChanged`, `DashTriggered`), VotingService (remotes `SubmitVote`, `GetOptions`; signals `VotingStarted`, `VotingEnded`), GoalieService (remotes `RequestGoalie(team?)`, `LeaveGoalie`, `GetGoalieSnapshot`; signals `GoalieState`, `GoalieAssignments`), RagdollService (`RagdollEvent`), MapService (`MapLoaded`).
- Validation: server-side team/carrier checks, stamina spend, cooldowns (ActionService/StaminaService/Ball touch/drop), dash gated to carriers, voting one-per-category, kickoff participant tracking.
- Rate limiting: ActionService cooldowns (Truck 30s, Poke/Shoot/Pass 1s), StaminaService dash cooldown 3s, BallService touch/drop cooldown ~1s.

# Data Persistence
- None active in `src`; ProfileService is present but unused. Persistence is unknown and would need implementation.

# UI & Input
- Expected GUIs: `HUDGui` (scoreboard/timer/stamina/truck cooldown/goal frames), `VotingGui` (slides), `ShootSystem` (mobile), `KickoffButton` clone from `Assets/UI`, `SelectionGui` (team/goalie selection buttons); ball/carrier visuals `HeadIcon`/`PassHighlight`.
- State driven by Knit signals/attributes; HUD responds to RoundService/ActionService/StaminaService; voting UI to VotingService; kickoff button to RoundService prompt; selection UI polls `RoundService:GetTeamSnapshot` and listens to `GoalieAssignments`.
- Inputs: sprint LeftShift/ButtonL3, dash Q/ButtonB, truck E/ButtonB, poke/shoot Mouse1/ButtonR2, pass X/ButtonY; goalie blocks Mouse1/R2 high, Mouse2/L2 low; mobile buttons mirror via MobileController.

# Assets / Tags / Collections
- Tags: `RollingFriction` (ball damping via `RollingFrictionComponent`), `OutOfBounds` (ball reset region), `Goal` (scoring detection).
- Map expectations: `Workspace/Game/Map` with team spawn folders/parts, `BallSpawn`, goalie spawns, crease collision parts `Team1Collision`/`Team2Collision`, goal parts named with team identifiers.
- Referenced assets: sounds (`Throw`, `Hitstick`, `Fall`, `Whistlee`, `Dash`), effects (`Kickoff`, `Dirt`), meshes (`Ball`, `HelmRed/HelmBlue`, `LacrosseStick`), UI (`HeadIcon`, `PassHighlight`, `KickoffButton`).

# Conventions (This Repo's Rules)
- Services under `src/server/Services`; controllers under `src/client/Controllers`; components in `src/server/Components`.
- Player attributes used: `Team`, `Goalie`, `HasBall`, `Frozen`, `Stamina`, `MaxStamina`, `DoingKickoff`, `KickoffLocked`, `Stun`, `PokeCheckStacks`; ball attributes: `LastTeam`, `CarrierUserId`, `PassingTargetId`, `LastShooterIsGoalie`.
- Cmdr commands in `src/server/Cmdr/Commands` with admin guard via `AdminConfig.lua`; key commands include `goalie [team]`, `player [team]` (capacity-aware, optional team), `switchteams [player] [team]` (players self; admins can target others), `setslot [player] <1-5>` (keeps chosen index; admins can target others), `pause [duration]`, `resume`, and ball/ragdoll utilities.
- Uniforms via `RoundService:ApplyTeamUniform`; team slots are ordered/sparse and never auto-rotated; kickoff uses slot 1 only.
- Selection UI: `StarterGui/SelectionGui/Main/TeamSelect/Container` buttons for Team1/Team2 (field) and Team1Goalie/Team2Goalie. Hover toggles `onHover`; `Amount` shows current/max (`x/y`, max field 5, goalie 1). Client calls `RoundService:RequestJoinTeam` (blocks kickoff/non-playing, capacity-aware, reverts goalie first) and `GoalieService:RequestGoalie(team)` (capacity-checked). Counts updated via `RoundService:GetTeamSnapshot`, `GoalieService:GoalieAssignments/GetGoalieSnapshot`, plus periodic polling.

# Dependencies
- `sleitnick/knit@1.7.0`, `sleitnick/component@2.4.8`, `evaera/cmdr@1.12.0`, `sleitnick/signal@2.0.3`, `evaera/promise@4.0.0` (unused), `howmanysmall/janitor@1.18.3` (unused), `brittonfischer/profileservice@2.1.5` (unused), `ffrostflame/bridgenet@1.9.9` (unused), `devsparkle/sentry-roblox@1.2.1`.
- Additional `_Index` libs (Comm, Option, Trove, etc.) come with dependencies but are unused in current source.

# Known Pitfalls / TODO
- Round duration voting ignored (forced 30s in `RoundService:ApplyVotingResults` for testing).
- Asset reliance: missing `Assets` folder or `Characters/Goalie` model in Studio will break uniforms/ball/goalie/UI cloning.
- ProfileService/BridgeNet/Janitor/Promise unused; could prune if not needed.

# Changelog
- 2025-12-25T17:10:00+01:00 - Added SelectionController and new RoundService/GoalieService remotes for team/goalie UI; documented selection UI behavior and updated goal scoring popup colors/scorer plumbing.
- 2025-12-25T15:10:00+01:00 - Documented sparse slot preservation (no auto rotation), kickoff using only slot 1, manual team/slot selection with commands, and removal of auto team assignment.
- 2025-12-25T13:25:42+01:00 - Team selection now manual via commands (switchteams/setslot), no auto assignment/rotation; kickoff selection handles empty slots; fixed team bucket resets and auto-balance for Field/FieldSet structure.
- 2025-12-20T15:23:09+01:00 - Team assignment refactor (ordered, compact field slots capped at 5), goalie/player commands allow team switch with capacity/slot enforcement, goalie moves across teams if slot free, uniforms reapplied on role/team change, kickoff participant selection fixed for single-side cases.
- 2025-12-20T14:05:55+01:00 - ActionService blocks actions while paused; pause now drops ball before anchoring/locking pickup.
- 2025-12-20T14:00:31+01:00 - Added pause/resume (RoundService pause flag, Cmdr `pause`/`resume`), ActionService blocks when stunned; updated context.
- 2025-12-20T13:12:03+01:00 - Initial AGENT_CONTEXT created after full scan.
