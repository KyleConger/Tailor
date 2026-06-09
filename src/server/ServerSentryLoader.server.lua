local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Source = ReplicatedStorage:WaitForChild("Source")

local Sentry = require(Packages.SentryRoblox)
local SentryConfig = require(Source.SentryConfig)
local SentryLoader = require(Source.SentryLoader)

SentryLoader.initServer(Sentry, SentryConfig)
