local RunService = game:GetService("RunService")

local initialized = false

local SentryLoader = {}

function SentryLoader.initServer(sentry, config)
	if initialized or not RunService:IsServer() then
		return
	end

	if not config.Enabled or config.DSN == "" then
		return
	end

	sentry:Init({
		DSN = config.DSN,
		Environment = config.Environment,
		Release = config.Release,
		debug = config.Debug,
		SendStudioEvents = config.SendStudioEvents,
	})

	initialized = true
end

return SentryLoader
