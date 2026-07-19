local Triangle = {}
Triangle.__index = Triangle

local triangleHeight = math.sqrt(3) / 2
local function heightToTriangleHeight(h)
	return h / triangleHeight - (1 - triangleHeight) / 2
end

local trianglePoints = {
	[1] = Vector2.new(0.5, 0),
	[2] = Vector2.new(0, 1),
	[3] = Vector2.new(1, 1),
}

function Triangle.new(ColorPicker, parentContainer)
	local self = setmetatable({}, Triangle)
	self.ColorPicker = ColorPicker
	self.ParentContainer = parentContainer

	self:Init()
	return self
end

function Triangle:Init()
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = self.ParentContainer

	local colorImage = Instance.new("ImageLabel")
	colorImage.BackgroundTransparency = 1
	colorImage.Size = UDim2.fromScale(1, 1)
	colorImage.Image = "rbxassetid://119614645478849"
	colorImage.ImageColor3 = Color3.new(1, 0, 0)
	colorImage.ZIndex = 1
	colorImage.Parent = frame

	local saturationImage = Instance.new("ImageLabel")
	saturationImage.BackgroundTransparency = 1
	saturationImage.Size = UDim2.fromScale(1, 1)
	saturationImage.Image = "rbxassetid://114393129271758"
	saturationImage.ImageColor3 = Color3.new(1, 1, 1)
	saturationImage.ZIndex = 2
	saturationImage.Parent = frame

	local valueImage = Instance.new("ImageLabel")
	valueImage.BackgroundTransparency = 1
	valueImage.Size = UDim2.fromScale(1, 1)
	valueImage.Image = "rbxassetid://90395096352510"
	valueImage.ImageColor3 = Color3.new(1, 1, 1)
	valueImage.ZIndex = 3
	valueImage.Parent = frame

	self.Instance = frame
	self.ColorImage = colorImage
	self:SetVisible(false)
end

function Triangle:SetVisible(bool)
	self.Instance.Visible = bool
end

function Triangle:GetColor(mousePos)
	local x = mousePos.X
	local y = math.clamp(heightToTriangleHeight(mousePos.Y), 0, 1)

	x = math.clamp(x, 0.5 - (y / 2), 0.5 + (y / 2))

	local tri1, tri2, tri3 = trianglePoints[1], trianglePoints[2], trianglePoints[3]

	local l1 = ((tri2.Y - tri3.Y) * (x - tri3.X) + (tri3.X - tri2.X) * (y - tri3.Y))
		/ ((tri2.Y - tri3.Y) * (tri1.X - tri3.X) + (tri3.X - tri2.X) * (tri1.Y - tri3.Y))

	local l2 = ((tri3.Y - tri1.Y) * (x - tri3.X) + (tri1.X - tri3.X) * (y - tri3.Y))
		/ ((tri2.Y - tri3.Y) * (tri1.X - tri3.X) + (tri3.X - tri2.X) * (tri1.Y - tri3.Y))

	local l3 = 1 - l1 - l2

	l1, l2, l3 = math.clamp(l1, 0, 1), math.clamp(l2, 0, 1), math.clamp(l3, 0, 1)

	local hue = Color3.fromHSV(self.ColorPicker.Color.Hue, 1, 1)
	local color = Color3.new(
		l1 * hue.R + l2 * 0 + l3 * 1,
		l1 * hue.G + l2 * 0 + l3 * 1,
		l1 * hue.B + l2 * 0 + l3 * 1
	)

	local _, newS, newV = color:ToHSV()
	return self.ColorPicker.Color.Hue, newS, newV
end

function Triangle:GetPointerPositionFromColor(_h, s, v)
	local pos = Vector2.new(0.5, 0):Lerp(Vector2.new(1, 1), 1 - s):Lerp(Vector2.new(0, 1), 1 - v)
	return UDim2.fromScale(pos.X, (1 - triangleHeight) / 2 + pos.Y * triangleHeight)
end

function Triangle:UpdateVisual()
	self.ColorImage.ImageColor3 = Color3.fromHSV(self.ColorPicker.Color.Hue, 1, 1)
end

return Triangle
