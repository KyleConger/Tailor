local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Source = ReplicatedStorage:WaitForChild("Source")
local Knit = require(Packages.Knit)
local Log = require(Source.Log)

local BootstrapController = Knit.CreateController({
	Name = "BootstrapController",
})

function BootstrapController:KnitStart()
	Log.ForContext("BootstrapController"):Info("Client controllers ready")
end

return BootstrapController
