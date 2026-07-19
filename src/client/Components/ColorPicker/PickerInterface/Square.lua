local Square = {}
Square.__index = Square

function Square.new(ColorPicker, parentContainer)
	local self = setmetatable({}, Square)
	self.ColorPicker = ColorPicker
	self.ParentContainer = parentContainer

	self:Init()
	return self
end

function Square:Init()
	local frame = Instance.new("CanvasGroup")
	frame.BackgroundTransparency = 0
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = self.ParentContainer

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0.032, 0)
	uiCorner.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1))
	gradient.Parent = frame

	local valueFrame = Instance.new("Frame")
	valueFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	valueFrame.BackgroundTransparency = 0
	valueFrame.Size = UDim2.fromScale(1, 1)
	valueFrame.Parent = frame

	local valueGradient = Instance.new("UIGradient")
	valueGradient.Color = ColorSequence.new(Color3.new(0, 0, 0))
	valueGradient.Rotation = -90
	valueGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	valueGradient.Parent = valueFrame

	self.Instance = frame
	self.Gradient = gradient
	self:SetVisible(false)
end

function Square:SetVisible(bool)
	self.Instance.Visible = bool
end

function Square:GetColor(mousePos)
	return self.ColorPicker.Color.Hue, math.clamp(mousePos.X, 0, 1), math.clamp(1 - mousePos.Y, 0, 1)
end

function Square:GetPointerPositionFromColor(_h, s, v)
	return UDim2.fromScale(s, 1 - v)
end

function Square:UpdateVisual()
	self.Gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(self.ColorPicker.Color.Hue, 1, 1)),
	})
end

return Square
