local samplesFolder = script.Parent:WaitForChild("Samples")

local function hexToColor3(str)
	local success, color = pcall(function()
		return Color3.fromHex(str)
	end)
	return success and color
end

local PaletteInterface = {}
PaletteInterface.__index = PaletteInterface

function PaletteInterface.new(ColorPicker, container)
	local self = setmetatable({}, PaletteInterface)
	self.ColorPicker = ColorPicker
	self.Instance = container

	self.Colors = {}
	self:Init()

	return self
end

function PaletteInterface:GetColor(index)
	local tab = self.Colors[index]
	return tab and tab.color
end

function PaletteInterface:GetColor3(index)
	local tab = self.Colors[index]
	return tab and hexToColor3(tab.color)
end

function PaletteInterface:SetColor(index, value)
	if typeof(value) == "Color3" then
		value = value:ToHex()
	end

	local tab = self.Colors[index]
	if tab then
		tab.color = value
		tab.updateVisual()
	else
		self:AddColor(value)
	end
end

function PaletteInterface:GetColors()
	local tab = {}
	for i, v in self.Colors do
		tab[i] = v.color
	end

	return tab
end

function PaletteInterface:GetColors3()
	local tab = {}
	for i, v in self.Colors do
		tab[i] = hexToColor3(v.color)
	end

	return tab
end

function PaletteInterface:SetColors(value)
	for i, v in value do
		local v2 = if typeof(v) == "Color3" then v:ToHex() else v

		local tab = self.Colors[i]
		if tab then
			tab.color = v2
			tab.updateVisual()
		else
			self:AddColor(v2)
		end
	end
end

function PaletteInterface:AddColor(color)
	if #self.Colors >= 32 then
		print("Palette limit")
		return
	end

	if typeof(color) == "Color3" then
		color = color:ToHex()
	end

	local obj = samplesFolder:WaitForChild("PaletteItemSample"):Clone()
	obj.Parent = self.Instance:WaitForChild("List")
	obj.Visible = true

	local tab = {
		instance = obj,
		color = color,
	}

	tab.updateVisual = function()
		obj.Preview.BackgroundColor3 = hexToColor3(tab.color)
		obj.Hex.Text = string.format("#%s", tab.color)
		obj.Index.Text = table.find(self.Colors, tab) or ""
	end

	local deleteButton = obj:WaitForChild("Delete"):WaitForChild("Button")
	deleteButton.MouseButton1Down:Connect(function()
		self:RemoveColor(table.find(self.Colors, tab))
	end)

	local button = obj:WaitForChild("Button")
	button.MouseButton1Down:Connect(function()
		self.ColorPicker:SetColor(hexToColor3(tab.color))
	end)

	table.insert(self.Colors, tab)
	tab.updateVisual()
end

function PaletteInterface:RemoveColor(index)
	local tab = self.Colors[index]
	if tab then
		if tab.instance then
			tab.instance:Destroy()
		end

		table.remove(self.Colors, index)

		if index <= #self.Colors then
			for i = index, #self.Colors do
				self.Colors[i].updateVisual()
			end
		end
	end
end

function PaletteInterface:SetVisible(bool)
	self.Instance.Visible = bool
end

function PaletteInterface:Init()
	local closeButton = self.Instance:WaitForChild("Close")
	closeButton.MouseButton1Down:Connect(function()
		self.ColorPicker:SetPaletteVisible(false)
	end)

	local saveButton = self.Instance:WaitForChild("Save")
	saveButton.MouseButton1Down:Connect(function()
		self:AddColor(self.ColorPicker:GetColor())
	end)
end

return PaletteInterface
