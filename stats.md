Stats System - Complete Notes (authoritative)

Purpose
- Provide a full stats system for Lax Blast with three views (Current Game, Server, Global) and a My Stats panel.
- Keep XP/Level as progression only (not used for stat ranking).
- Use a hidden RankScore for global ranking; RankScore resets with stats.

UI Asset Reference
File: stats-ui.rbxmx
Root: ScreenGui named "Stats" (resetOnSpawn=true) with a main frame "Main".
Close: TextButton "CloseBtn" (text "X") closes the stats UI.
Open: HUDGui.Main has a new TextButton "Stats" that opens the Stats UI.

Main Hierarchy (direct children)
- Background (Frame)
- TopBtns (Frame)
- Header (Frame)
- CloseBtn (TextButton)
- UIScale
- Pages (Folder)

Pages Folder
- CurrentGame (ScrollingFrame)
- Server (ScrollingFrame)
- Global (ScrollingFrame)
- MyStats (Frame)

Tabs
TopBtns contains:
- MyStatsBtn (text "My Stats")
- CurrentGameBtn (text "Current Game")
- ServerBtn (text "Server")
- GlobalBtn (text "Global")
Each toggles one page; only one page should be visible at a time.

Views (ScrollingFrames)
- CurrentGame (Visible=false by default)
- Server (Visible=false by default)
- Global (Visible=false by default)
Each includes:
- Template row named "Template" for player rows.
- Column headers frame "StatsHeaders" with TextLabels:
  - Player
  - Goals
  - Assists
  - Trucks
  - Poke Checks
  - Saves

Template Row Fields
- Background (Frame)
- UserIcon (ImageLabel) for player thumbnail
- Name (TextLabel) for rank + player name (default example: "1. syrqrim")
- TextLabels named (values only):
  - Goals
  - Assists
  - Trucks
  - PokeChecks
  - Saves
Default value text in template is "N/A".

My Stats Panel
- Frame: MyStats (Visible=false by default, inside Pages)
- Direct children: Offense, Defense, Content, SearchBar
- Offense card: "Offense" with Title "Offense" and TextLabels:
  - Goals (text format: "Goals: <value>")
  - Assists (text format: "Assists: <value>")
- Defense card: "Defense" with Title "Defense" and TextLabels:
  - Trucks (text format: "Trucks: <value>")
  - PokeChecks (text format: "Poke Checks: <value>")
  - Saves (text format: "Saves: <value>")
- Content section:
  - AvatarFrame (Frame) -> Avatar (ImageLabel)
  - Username (TextLabel, "@name")
  - GlobalPosition (TextLabel, "#... Global")
  - Level (TextLabel, "Lvl <n>")
  - XPBar (Frame) -> Main (Frame) -> Fill (Frame) + Lines (ImageLabel)
  - Wins (TextLabel, rich text: green label + white value)
  - Loses (TextLabel, rich text: red label + white value)
  - ResetButton (TextButton, text "Reset")

Formatting Rules
- Table rows: show raw numbers only (no suffixes).
- MyStats cards: "Label: value".
- Wins/Loses: rich text color formatting.

Stat Keys (resettable)
- goals
- assists
- trucks
- pokeChecks
- saves
- wins
- losses
- rankScore (hidden)

Progression (not reset)
- level
- xp
XP and Level are for progression only and are NOT used for stat ranking.

RankScore
- Stored value (authoritative).
- Used for GlobalPosition and OrderedDataStore ranking.
- Resets with other stats (on Reset button).

RankScore Weights (success-only)
- Goal: +4
- Assist: +3
- Save: +3
- Truck: +1
- PokeCheck: +1
- Win: +6
- Loss: +2

Assist Rule (Option B)
- Assist credited to the last teammate who touched the ball within 7 seconds before the goal.
- Assist is not given to the scorer.
- Requires tracking last teammate touch + timestamp.

Save Rule
- A save is counted when a goalie touches the ball after an attacker had possession and the attack does not score.
- Requires tracking: last attacking carrier/team and goalie touch.

Success-Only Counts
- Trucks and PokeChecks increment only on successful hits (not on attempts).

Scopes and Reset Behavior
- CurrentGame: per-match totals for all players in the server; reset at round end.
- Server: totals for the current server session.
- Global: persistent totals across sessions.
- Reset button:
  - Resets goals, assists, trucks, pokeChecks, saves, wins, losses, rankScore across CurrentGame/Server/Global for that player.
  - Does NOT reset level or xp.

Persistence Plan
- Global stats and progression stored per-player via ProfileService.
- OrderedDataStore used for RankScore leaderboard (ProfileService does not provide ordered stores).
- OrderedDataStore value updated whenever RankScore changes or on save.

UI Wiring Plan
- StatsController (client) owns Stats UI and tab switching.
- Fetch stats snapshots from StatsService (server) for CurrentGame/Server/Global.
- For each scope, clone Template row and fill:
  - UserIcon (thumbnail)
  - Goals/Assists/Trucks/PokeChecks/Saves values
- Update MyStats panel for LocalPlayer:
  - Offense: goals/assists
  - Defense: trucks/pokeChecks/saves
  - Profile: avatar, username, global rank text, level/xp, wins/losses, XP bar fill
- ResetButton triggers StatsService:ResetPlayerStats (stats only).

Tracking Hook Points (server)
- Goals: RoundService:OnTeamScored -> increment scorer goals and RankScore.
- Assists: track last teammate touch in BallService; on goal, award if last touch within 7s.
- Trucks/PokeChecks: ActionService:handleHit for action "Truck" or "Poke" when hit lands.
- Saves: when goalie touches ball after attacker possession and no goal results.
- Wins/Losses: at round end, award for players on winning/losing team (no change on tie).

Global Rank
- GlobalPosition text uses RankScore leaderboard (OrderedDataStore rank).
- Display format in UI: "#<rank> Global".

Notes
- Template row and StatsHeaders appear in multiple scopes; update the correct hierarchy.
- Default UI shows placeholders ("N/A", "Goals: 1", etc.); replace with live data.
- Use ASCII text in labels; avoid smart quotes.
