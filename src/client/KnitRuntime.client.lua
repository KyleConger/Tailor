local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Source = ReplicatedStorage:WaitForChild("Source")
local Knit = require(Packages.Knit)
local Log = require(Source.Log)

local LoggerSetup = require(Source.LoggerSetup)

LoggerSetup.init()

local sourceFolder = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Source")

Knit.AddControllers(sourceFolder.Controllers)

Knit.Start()
	:andThen(function()
		Log.ForContext("KnitRuntime"):Info("Knit client started")
	end)
	:catch(function(err)
		warn("[KnitRuntime] Failed to start:", err)
	end)
