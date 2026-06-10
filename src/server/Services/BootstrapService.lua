local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Source = ReplicatedStorage:WaitForChild("Source")
local Knit = require(Packages.Knit)
local Log = require(Source.Log)

local BootstrapService = Knit.CreateService({
	Name = "BootstrapService",
	Client = {},
})

function BootstrapService:KnitInit()
	self._log = Log.ForContext("BootstrapService")
end

function BootstrapService:KnitStart()
	self._log:Info("Server services ready")
end

return BootstrapService
