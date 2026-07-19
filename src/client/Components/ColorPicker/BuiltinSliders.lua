local hueGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
	ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
})

local BuiltinSliders = {}

function BuiltinSliders.Hue(ColorPicker)
	local self = ColorPicker:_createSlider("Hue", 1, 360)
	local gradient = self.Instance:WaitForChild("Slider"):WaitForChild("Gradient")
	gradient.Color = hueGradient

	self.OnManualChange = function(value)
		ColorPicker.Color.Hue = value
	end

	self.GetValue = function()
		return ColorPicker.Color.Hue or 0
	end

	self:UpdateVisual()
	return self
end

function BuiltinSliders.Saturation(ColorPicker)
	local self = ColorPicker:_createSlider("Saturation", 2, 100)
	self.OnManualChange = function(value)
		ColorPicker.Color.Saturation = value
	end

	self.GetValue = function()
		return ColorPicker.Color.Saturation or 0
	end

	self.OnValueChanged = function()
		local h = ColorPicker.Color.Hue
		local v = ColorPicker.Color.Value

		local gradient = self.Instance:WaitForChild("Slider"):WaitForChild("Gradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 1, v)),
		})
	end

	self:UpdateVisual()
	return self
end

function BuiltinSliders.Value(ColorPicker)
	local self = ColorPicker:_createSlider("Value", 3, 100)
	self.OnManualChange = function(value)
		ColorPicker.Color.Value = value
	end

	self.GetValue = function()
		return ColorPicker.Color.Value or 0
	end

	self.OnValueChanged = function()
		local h, s = ColorPicker:GetHSV()

		local gradient = self.Instance:WaitForChild("Slider"):WaitForChild("Gradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(h, s, 1)),
		})
	end

	self:UpdateVisual()
	return self
end

function BuiltinSliders.Red(ColorPicker)
	local self = ColorPicker:_createSlider("Red", 1, 255)
	self.OnManualChange = function(value)
		local color = ColorPicker:GetColor()
		local g, b = color.G, color.B

		ColorPicker.Color.Hue, ColorPicker.Color.Saturation, ColorPicker.Color.Value =
			Color3.new(value, g, b):ToHSV()
	end

	self.GetValue = function()
		return ColorPicker:GetColor().R or 0
	end

	self.OnValueChanged = function()
		local color = ColorPicker:GetColor()
		local g, b = color.G, color.B

		local gradient = self.Instance:WaitForChild("Slider"):WaitForChild("Gradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(0, g, b)),
			ColorSequenceKeypoint.new(1, Color3.new(1, g, b)),
		})
	end

	self:UpdateVisual()
	return self
end

function BuiltinSliders.Green(ColorPicker)
	local self = ColorPicker:_createSlider("Green", 2, 255)
	self.OnManualChange = function(value)
		local color = ColorPicker:GetColor()
		local r, b = color.R, color.B

		ColorPicker.Color.Hue, ColorPicker.Color.Saturation, ColorPicker.Color.Value =
			Color3.new(r, value, b):ToHSV()
	end

	self.GetValue = function()
		return ColorPicker:GetColor().G or 0
	end

	self.OnValueChanged = function()
		local color = ColorPicker:GetColor()
		local r, b = color.R, color.B

		local gradient = self.Instance:WaitForChild("Slider"):WaitForChild("Gradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(r, 0, b)),
			ColorSequenceKeypoint.new(1, Color3.new(r, 1, b)),
		})
	end

	self:UpdateVisual()
	return self
end

function BuiltinSliders.Blue(ColorPicker)
	local self = ColorPicker:_createSlider("Blue", 3, 255)
	self.OnManualChange = function(value)
		local color = ColorPicker:GetColor()
		local r, g = color.R, color.G

		ColorPicker.Color.Hue, ColorPicker.Color.Saturation, ColorPicker.Color.Value =
			Color3.new(r, g, value):ToHSV()
	end

	self.GetValue = function()
		return ColorPicker:GetColor().B or 0
	end

	self.OnValueChanged = function()
		local color = ColorPicker:GetColor()
		local r, g = color.R, color.G

		local gradient = self.Instance:WaitForChild("Slider"):WaitForChild("Gradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(r, g, 0)),
			ColorSequenceKeypoint.new(1, Color3.new(r, g, 1)),
		})
	end

	self:UpdateVisual()
	return self
end

function BuiltinSliders.Transparency(ColorPicker)
	local self = ColorPicker:_createSlider("Transparency", 4, 100)
	local gradient = self.Instance:WaitForChild("Slider"):WaitForChild("Gradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})

	local pattern = Instance.new("ImageLabel")
	pattern.BackgroundTransparency = 1
	pattern.Size = UDim2.fromScale(0.77, 1)
	pattern.Image = "rbxassetid://111137375763311"
	pattern.ImageTransparency = 0.5
	pattern.ScaleType = Enum.ScaleType.Tile
	pattern.TileSize = UDim2.fromScale(0.08, 1)
	pattern.ZIndex = -1

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.4, 0)
	corner.Parent = pattern

	pattern.Parent = self.Instance

	self.OnManualChange = function(value)
		ColorPicker.Color.Transparency = value
	end

	self.GetValue = function()
		return ColorPicker.Color.Transparency or 0
	end

	self.OnValueChanged = function()
		gradient.Color = ColorSequence.new(ColorPicker:GetColor())
	end

	return self
end

return BuiltinSliders
