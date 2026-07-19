local MouseMovement = require(script.Parent:WaitForChild("MouseMovement"))
local PICKER_MODE_MODULES = {
	Circle = require(script:WaitForChild("Circle")),
	Square = require(script:WaitForChild("Square")),
	Triangle = require(script:WaitForChild("Triangle")),
}

local PickerInterface = {}
PickerInterface.__index = PickerInterface

function PickerInterface.new(ColorPicker, container)
	local self = setmetatable({}, PickerInterface)
	self.ColorPicker = ColorPicker
	self.Instance = container

	self.PickerModes = {}
	self:Init()

	return self
end

function PickerInterface:GetPickerMode(mode)
	if not self.PickerModes[mode] and PICKER_MODE_MODULES[mode] then
		self.PickerModes[mode] = PICKER_MODE_MODULES[mode].new(self.ColorPicker, self.Instance)
	end

	return self.PickerModes[mode]
end

function PickerInterface:SetPickerMode(mode)
	self.CurrentPickerMode = mode
	if not self.PickerModes[mode] and PICKER_MODE_MODULES[mode] then
		self.PickerModes[mode] = PICKER_MODE_MODULES[mode].new(self.ColorPicker, self.Instance)
	end

	self:UpdateVisibility()
end

function PickerInterface:UpdateVisibility()
	for i, v in self.PickerModes do
		v:SetVisible(self.CurrentPickerMode == i)
	end
end

function PickerInterface:UpdateSelectFrame()
	local selectFrame = self.Instance:WaitForChild("Select")
	local currentPicker = self:GetPickerMode(self.CurrentPickerMode)
	if currentPicker then
		selectFrame.Position = currentPicker:GetPointerPositionFromColor(self.ColorPicker:GetHSV())
		if self.CurrentPickerMode == "Circle" then
			local _, _, v = self.ColorPicker:GetHSV()
			selectFrame.ImageColor3 = Color3.fromHSV(1, 0, 0.4 + v * 0.6)
		else
			selectFrame.ImageColor3 = Color3.fromHSV(1, 0, 1)
		end
	end
end

function PickerInterface:UpdateVisual()
	self:UpdateSelectFrame()

	local picker = self:GetPickerMode(self.CurrentPickerMode)
	if picker and picker.UpdateVisual then
		picker:UpdateVisual()
	end
end

function PickerInterface:GetRelativeMousePos()
	return (self.ColorPicker:GetMousePos() - self.Instance.AbsolutePosition) / self.Instance.AbsoluteSize
end

function PickerInterface:Init()
	self._pickerMouseMovement = MouseMovement.new(function()
		local currentPicker = self:GetPickerMode(self.CurrentPickerMode)
		if currentPicker then
			self.ColorPicker:SetHSV(currentPicker:GetColor(self:GetRelativeMousePos()))
		end
	end)

	local pickerButton = self.Instance:WaitForChild("Button")
	pickerButton.MouseButton1Down:Connect(function()
		local picker = self:GetPickerMode(self.CurrentPickerMode)
		if picker then
			if picker.MouseDown then
				picker:MouseDown(self:GetRelativeMousePos())
			end

			self._pickerMouseMovement:Connect()
		end
	end)
end

function PickerInterface:Destroy()
	self._pickerMouseMovement:Destroy()
	if self.Instance then
		self.Instance:Destroy()
	end
end

return PickerInterface
