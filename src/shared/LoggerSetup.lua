local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Log = require(Packages.Log)

local LoggerConfig = require(script.Parent.LoggerConfig)

local LEVEL_MAP = {
	Verbose = Log.LogLevel.Verbose,
	Debugging = Log.LogLevel.Debugging,
	Information = Log.LogLevel.Information,
	Warning = Log.LogLevel.Warning,
	Error = Log.LogLevel.Error,
	Fatal = Log.LogLevel.Fatal,
}

local initialized = false

local LoggerSetup = {}

function LoggerSetup.init()
	if initialized then
		return
	end
	initialized = true

	local minLevel = LEVEL_MAP[LoggerConfig.MinLevel] or Log.LogLevel.Information
	if RunService:IsStudio() and LoggerConfig.StudioMinLevel then
		minLevel = LEVEL_MAP[LoggerConfig.StudioMinLevel] or Log.LogLevel.Debugging
	end

	local logger = Log.Configure()
		:WriteTo(Log.RobloxOutput())
		:SetMinLogLevel(minLevel)
		:Create()

	Log.SetLogger(logger)
end

return LoggerSetup
