local MouseMovement = require(script.Parent:WaitForChild("MouseMovement"))
local samplesFolder = script.Parent:WaitForChild("Samples")

local Slider = {}
Slider.__index = Slider

function Slider.new(ColorPicker, title, layoutOrder, maxValue)
	local self = setmetatable({}, Slider)
	self.ColorPicker = ColorPicker
	self.LayoutOrder = layoutOrder

	self.Title = title
	self.MaxValue = maxValue

	self:Init()
	return self
end

function Slider:UpdateVisual()
	if self.GetValue then
		local value = self.GetValue()

		local slider = self.Instance:WaitForChild("Slider")
		local selectImage = slider:WaitForChild("Select")
		selectImage.Position = UDim2.fromScale(value, 0.5)

		local inputFrame = self.Instance:WaitForChild("Input")
		local inputBox = inputFrame:WaitForChild("TextBox")
		inputBox.Text = math.round(value * self.MaxValue)
	end

	if self.OnValueChanged then
		self.OnValueChanged()
	end
end

function Slider:SetVisible(bool)
	if bool then
		self:UpdateVisual()
	end
	self.Instance.Visible = bool
end

function Slider:GetVisible()
	return self.Instance.Visible
end

function Slider:Create()
	local sample = samplesFolder:WaitForChild("SliderSample"):Clone()
	sample.Parent = self.ColorPicker.Instance:WaitForChild("Sliders")
	sample.Name = tostring(self.LayoutOrder)

	return sample
end

function Slider:Init()
	self.Instance = self:Create()

	local slider = self.Instance:WaitForChild("Slider")
	self._mouseMovement = MouseMovement.new(function()
		local newValue =
			math.clamp((self.ColorPicker:GetMousePos().X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
		if self.OnManualChange then
			self.OnManualChange(newValue)

			self.ColorPicker:_updateColorVisuals()
			self.ColorPicker:_fireColorChanged()
		end
	end)

	local button = slider:WaitForChild("Button")
	button.MouseButton1Down:Connect(function()
		self._mouseMovement:Connect()
	end)

	local inputFrame = self.Instance:WaitForChild("Input")
	local inputBox = inputFrame:WaitForChild("TextBox")
	inputBox.FocusLost:Connect(function()
		local newValue = math.clamp((tonumber(inputBox.Text) or 0) / self.MaxValue, 0, 1)
		if self.OnManualChange then
			self.OnManualChange(newValue)

			self.ColorPicker:_updateColorVisuals()
			self.ColorPicker:_fireColorChanged()
		end
	end)
end

function Slider:Destroy()
	self._mouseMovement:Destroy()
	if self.Instance then
		self.Instance:Destroy()
	end
end

return Slider
