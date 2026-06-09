-- Client errors are relayed to the server by SentryRoblox's SentryClientRelay integration.
-- Enable Sentry in src/shared/SentryConfig.lua and init on the server via ServerSentryLoader.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SentryConfig = require(ReplicatedStorage:WaitForChild("Source").SentryConfig)

if not SentryConfig.Enabled or SentryConfig.DSN == "" then
	return
end
