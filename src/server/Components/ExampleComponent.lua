local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Component = require(Packages.Component)
local Log = require(Packages.Log)

local ExampleComponent = Component.new({
	Tag = "Example",
})

function ExampleComponent:Construct()
	self._log = Log.ForContext("ExampleComponent")
end

function ExampleComponent:Start()
	self._log:Info("Started on {Instance}", self.Instance:GetFullName())
end

return ExampleComponent
