local Circle = {}
Circle.__index = Circle

local function toPolar(v)
	return math.atan2(v.Y, v.X), v.Magnitude
end

function Circle.new(ColorPicker, parentContainer)
	local self = setmetatable({}, Circle)
	self.ColorPicker = ColorPicker
	self.ParentContainer = parentContainer

	self:Init()
	return self
end

function Circle:Init()
	local image = Instance.new("ImageLabel")
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.Image = "rbxassetid://91671058647239"
	image.Parent = self.ParentContainer

	self.Instance = image
	self:SetVisible(false)
end

function Circle:SetVisible(bool)
	self.Instance.Visible = bool
end

function Circle:GetColor(mousePos)
	local phi, len = toPolar(Vector2.new(0.5, 0.5) - mousePos)
	local h = math.clamp((phi + math.pi) / (2 * math.pi), 0, 1)
	local s = math.clamp(len * 2, 0, 1)

	return h, s, self.ColorPicker.Color.Value
end

function Circle:GetPointerPositionFromColor(h, s, _v)
	local h2 = h * math.pi * 2
	return UDim2.fromScale(0.5 + (math.cos(h2) / 2 * s), 0.5 + (math.sin(h2) / 2 * s))
end

return Circle
