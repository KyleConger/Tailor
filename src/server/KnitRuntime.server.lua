local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Source = ReplicatedStorage:WaitForChild("Source")
local Knit = require(Packages.Knit)
local Log = require(Packages.Log)

local LoggerSetup = require(Source.LoggerSetup)
local SentryLoader = require(Source.SentryLoader)
local SentryConfig = require(Source.SentryConfig)

LoggerSetup.init()
SentryLoader.initServer(require(Packages.SentryRoblox), SentryConfig)

local sourceFolder = ServerScriptService:WaitForChild("Source")

for _, child in sourceFolder.Components:GetChildren() do
	if child:IsA("ModuleScript") then
		require(child)
	end
end

Knit.AddServices(sourceFolder.Services)

Knit.Start()
	:andThen(function()
		Log.ForContext("KnitRuntime"):Info("Knit server started")
	end)
	:catch(function(err)
		warn("[KnitRuntime] Failed to start:", err)
	end)
