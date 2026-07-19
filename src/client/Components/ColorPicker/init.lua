--[[

Color Picker
Author: @Viperdune

https://devforum.roblox.com/t/-/4648754

----------------------------------------

Example usage:

local newColorPicker = ColorPicker.new({
	Position = UDim2.fromScale(0.4,0.2),

	PickerMode = ColorPicker.PICKER_MODE.SQUARE,
	ColorSpace = ColorPicker.COLOR_SPACE.RGB
})

newColorPicker:SetColor(button.BackgroundColor3)
newColorPicker.ColorChanged:Connect(function(color)
	button.BackgroundColor3 = color
end)

newColorPicker.WindowClosed:Connect(function()
	...
end)

--]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local PaletteInterface = require(script:WaitForChild("PaletteInterface"))
local PickerInterface = require(script:WaitForChild("PickerInterface"))
local BuiltinSliders = require(script:WaitForChild("BuiltinSliders"))
local MouseMovement = require(script:WaitForChild("MouseMovement"))
local Styling = require(script:WaitForChild("Styling"))
local Slider = require(script:WaitForChild("Slider"))
local Types = require(script:WaitForChild("Types"))

local samplesFolder = script:WaitForChild("Samples")

local PICKER_MODE = {
	CIRCLE = "Circle",
	SQUARE = "Square",
	TRIANGLE = "Triangle",
}

local COLOR_SPACE = {
	HSV = 0,
	RGB = 1,
}

local parametersTemplate = {
	Parent = nil,
	Position = nil,
	Size = 0.6,
	TopbarEnabled = true,
	PaletteEnabled = true,
	Draggable = true,
	Resizable = true,
	DisplayOrder = 1,
	ZIndex = 1,
	TransparencyEnabled = false,
	UserCanClose = true,
	PickerMode = PICKER_MODE.CIRCLE,
	ColorSpace = COLOR_SPACE.HSV,
	Style = {},
}

local function deepCopy(t)
	local copy = {}
	for key, value in pairs(t) do
		if type(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local function reconcile(tab, template)
	local new = deepCopy(tab)
	for i, v in pairs(template) do
		if tab[i] == nil then
			new[i] = if typeof(v) == "table" then deepCopy(v) else v
		elseif typeof(tab[i]) == "table" then
			new[i] = reconcile(tab[i], v)
		end
	end

	return new
end

export type Type = Types.ColorPicker
export type PickerMode = Types.PickerMode
export type ColorSpace = Types.ColorSpace
export type Style = Types.StyleGuide

local ColorPicker: Types.ColorPicker = {}
ColorPicker.__index = ColorPicker

ColorPicker.PICKER_MODE = PICKER_MODE
ColorPicker.COLOR_SPACE = COLOR_SPACE

function ColorPicker.new(params: Types.Params): Type
	local self = setmetatable({}, ColorPicker)
	self.Color = { Hue = 0, Saturation = 0, Value = 1, Transparency = 0 }
	self.Params = reconcile(params or {}, parametersTemplate)

	self._sliders = {}
	self:Init()

	return self
end

function ColorPicker:GetMousePos()
	local topbarHeight = GuiService.TopbarInset.Height
	return UserInputService:GetMouseLocation() - Vector2.new(0, topbarHeight)
end

function ColorPicker:GetMousePosUDim()
	local mousePos = self:GetMousePos() / self.UI.AbsoluteSize
	return UDim2.fromScale(mousePos.X, mousePos.Y)
end

function ColorPicker:SetHSV(h, s, v)
	self.Color.Hue, self.Color.Saturation, self.Color.Value = h, s, v
	self:_updateColorVisuals()
	self:_fireColorChanged()
end

function ColorPicker:GetHSV()
	return self.Color.Hue, self.Color.Saturation, self.Color.Value
end

function ColorPicker:SetColor(color: Color3)
	self.Color.Hue, self.Color.Saturation, self.Color.Value = color:ToHSV()
	self:_updateColorVisuals()
	self:_fireColorChanged()
end

function ColorPicker:GetColor()
	return Color3.fromHSV(self:GetHSV())
end

function ColorPicker:SetTransparency(t)
	self.Color.Transparency = t
	self:_updateColorVisuals()
	self:_fireColorChanged()
end

function ColorPicker:GetTransparency()
	return self.Color.Transparency
end

function ColorPicker:SetVisible(bool)
	self.Instance.Visible = bool
end

function ColorPicker:GetVisible()
	return self.Instance.Visible
end

function ColorPicker:SetPickerMode(pickerMode: PickerMode)
	local settingsFrame = self.Instance:WaitForChild("Settings")
	local pickerModeFrame = settingsFrame:WaitForChild("PickerMode")

	for _, v in pickerModeFrame:GetChildren() do
		local selected = v.Name == pickerMode
		v.Icon.ImageTransparency = if selected then 0 else 0.5
	end

	self.PickerMode = pickerMode
	self.PickerInterface:SetPickerMode(pickerMode)
	self.PickerInterface:UpdateVisual()
end

function ColorPicker:_updateColorVisuals()
	local color = self:GetColor()

	local middleFrame = self.Instance:WaitForChild("Middle")
	local colorPreview = middleFrame:WaitForChild("ColorPreview")
	colorPreview.BackgroundColor3 = color

	self.PickerInterface:UpdateVisual()
	for _, v in self._sliders do
		if v:GetVisible() then
			v:UpdateVisual()
		end
	end

	local optionsFrame = middleFrame:WaitForChild("Options")
	local hexInput = optionsFrame:WaitForChild("Hex"):WaitForChild("Input")
	hexInput.Text = string.format("#%s", self:GetColor():ToHex())
end

function ColorPicker:Create()
	self.UI = self.Params.Parent or Instance.new("ScreenGui")
	if not self.Params.Parent then
		self.UI.Name = "COLOR_PICKER_UI"
		self.UI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		self.UI.DisplayOrder = self.Params.DisplayOrder
		self.UI.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	self.Instance = samplesFolder:WaitForChild("ColorPickerSample"):Clone()
	self.Instance.Name = "ColorPickerUI"
	self.Instance.ZIndex = self.Params.ZIndex
	self.Instance.Size = if typeof(self.Params.Size) == "UDim2"
		then self.Params.Size
		else UDim2.fromScale(self.Params.Size, self.Params.Size)
	self.Instance.Position = self.Params.Position or self:GetMousePosUDim()
	self.Instance.Parent = self.UI
	self.Instance.Visible = true
end

function ColorPicker:_createSlider(title, layoutOrder, maxValue)
	local slider = Slider.new(self, title, layoutOrder, maxValue)
	self._sliders[title] = slider

	if self.Params.Style then
		Styling.stylizeSlider(slider.Instance, self.Params.Style)
	end

	return slider
end

function ColorPicker:_setSliderVisible(name, bool)
	local slider = self._sliders[name]
	if slider then
		slider:SetVisible(bool)
	elseif BuiltinSliders[name] and bool then
		BuiltinSliders[name](self)
	end
end

function ColorPicker:_updateSliders()
	local isHSV = self.ColorSpace == 0
	self:_setSliderVisible("Hue", isHSV)
	self:_setSliderVisible("Saturation", isHSV)
	self:_setSliderVisible("Value", isHSV)

	self:_setSliderVisible("Red", not isHSV)
	self:_setSliderVisible("Green", not isHSV)
	self:_setSliderVisible("Blue", not isHSV)
end

function ColorPicker:SetColorSpace(colorSpace: ColorSpace)
	local middleFrame = self.Instance:WaitForChild("Middle")
	local optionsFrame = middleFrame:WaitForChild("Options")
	local colorSpaceFrame = optionsFrame:WaitForChild("ColorSpace")

	self.ColorSpace = colorSpace
	for _, v in colorSpaceFrame:GetChildren() do
		v.Selection.Visible = COLOR_SPACE[v.Name] == colorSpace
	end

	self:_updateSliders()
end

function ColorPicker:UpdateBackground()
	local backgroundFrame = self.Instance:WaitForChild("Background")
	local posScale, sizeScale = 0, 1

	if self.Params.TopbarEnabled then
		posScale -= 0.11
		sizeScale += 0.11
	end

	if self.Params.TransparencyEnabled then
		sizeScale += 0.084
	end

	backgroundFrame.Position = UDim2.fromScale(0, posScale)
	backgroundFrame.Size = UDim2.fromScale(1, sizeScale)
end

function ColorPicker:SetPaletteVisible(bool)
	if not self.PaletteInterface then
		print("ColorPicker:SetPaletteVisible - Palette not enabled")
		return
	end
	self.PaletteInterface:SetVisible(bool)

	local pickerFrame = self.Instance:WaitForChild("Picker")
	local settingsFrame = self.Instance:WaitForChild("Settings")
	pickerFrame.Visible, settingsFrame.Visible = not bool, not bool
end

function ColorPicker:GetPaletteColor(index, isColor3)
	if not self.PaletteInterface then
		print("ColorPicker:GetPaletteColor - Palette not enabled")
		return
	end
	return if isColor3 then self.PaletteInterface:GetColor3(index) else self.PaletteInterface:GetColor(index)
end

function ColorPicker:GetPaletteColors(isColor3)
	if not self.PaletteInterface then
		print("ColorPicker:GetPaletteColors - Palette not enabled")
		return
	end
	return if isColor3 then self.PaletteInterface:GetColors3() else self.PaletteInterface:GetColors()
end

function ColorPicker:SetPaletteColor(index, color: Color3 | string)
	if not self.PaletteInterface then
		print("ColorPicker:SetPaletteColor - Palette not enabled")
		return
	end
	self.PaletteInterface:SetColor(index, color)
end

function ColorPicker:SetPaletteColors(colors: { [number]: Color3 | string })
	if not self.PaletteInterface then
		print("ColorPicker:SetPaletteColors - Palette not enabled")
		return
	end
	self.PaletteInterface:SetColors(colors)
end

function ColorPicker:AddPaletteColor(color)
	if not self.PaletteInterface then
		print("ColorPicker:AddPaletteColor - Palette not enabled")
		return
	end
	self.PaletteInterface:AddColor(color)
end

function ColorPicker:AddPaletteColors(colors)
	if not self.PaletteInterface then
		print("ColorPicker:AddPaletteColors - Palette not enabled")
		return
	end
	for _, v in colors do
		self.PaletteInterface:AddColor(v)
	end
end

function ColorPicker:GetPosition()
	return self.Instance.Position
end

function ColorPicker:SetPosition(pos)
	self.Instance.Position = pos
end

function ColorPicker:GetSize()
	return self.Instance.Size
end

function ColorPicker:SetSize(size)
	self.Instance.Size = if typeof(size) == "number" then UDim2.fromScale(size, size) else size
end

function ColorPicker:_fireColorChanged()
	self._colorChangedEvent:Fire(self:GetColor(), self:GetTransparency())
end

function ColorPicker:Init()
	self:Create()

	self._colorChangedEvent = Instance.new("BindableEvent")
	self.ColorChanged = self._colorChangedEvent.Event

	self._windowClosedEvent = Instance.new("BindableEvent")
	self.WindowClosed = self._windowClosedEvent.Event

	self.PickerInterface = PickerInterface.new(self, self.Instance:WaitForChild("Picker"))

	local settingsFrame = self.Instance:WaitForChild("Settings")
	local pickerModeFrame = settingsFrame:WaitForChild("PickerMode")

	for _, v in pickerModeFrame:GetChildren() do
		local button = v:WaitForChild("Button")
		button.MouseButton1Down:Connect(function()
			self:SetPickerMode(v.Name)
		end)
	end

	local middleFrame = self.Instance:WaitForChild("Middle")
	local optionsFrame = middleFrame:WaitForChild("Options")

	local colorSpaceFrame = optionsFrame:WaitForChild("ColorSpace")
	for _, v in colorSpaceFrame:GetChildren() do
		local button = v:WaitForChild("Button")
		button.MouseButton1Down:Connect(function()
			self:SetColorSpace(COLOR_SPACE[v.Name])
		end)
	end

	local hexInput = optionsFrame:WaitForChild("Hex"):WaitForChild("Input")
	hexInput.FocusLost:Connect(function()
		local success, color = pcall(function()
			return Color3.fromHex(hexInput.Text)
		end)
		self:SetColor(if success then color else Color3.new(1, 1, 1))
	end)

	if self.Params.TopbarEnabled then
		self.Topbar = samplesFolder:WaitForChild("Topbar"):Clone()
		self.Topbar.Parent = self.Instance

		if self.Params.Draggable then
			self._dragMouseMovement = MouseMovement.new(function(startMousePos, startWindowPos)
				local pos = ((self:GetMousePos() or Vector2.zero) - startMousePos) / self.UI.AbsoluteSize
				self.Instance.Position = startWindowPos + UDim2.fromScale(pos.X, pos.Y)
			end)

			self.Topbar:WaitForChild("Button").MouseButton1Down:Connect(function()
				local startMousePos = self:GetMousePos() or Vector2.zero
				local startWindowPos = self.Instance.Position
				self._dragMouseMovement:Connect(startMousePos, startWindowPos)
			end)
		end

		if self.Params.UserCanClose then
			local closeButton = samplesFolder:WaitForChild("TopbarCloseButton"):Clone()
			closeButton.Parent = self.Topbar

			closeButton.MouseButton1Down:Connect(function()
				self._windowClosedEvent:Fire()
				self:Destroy()
			end)
		end
	end

	local paletteButtonContainer = settingsFrame:WaitForChild("Palette")
	if self.Params.PaletteEnabled then
		self.PaletteInterface = PaletteInterface.new(self, self.Instance:WaitForChild("Palette"))

		local paletteButton = paletteButtonContainer:WaitForChild("Button")
		paletteButton.MouseButton1Down:Connect(function()
			self:SetPaletteVisible(true)
		end)
	else
		pickerModeFrame.Position = UDim2.fromScale(0, 0.5)
		paletteButtonContainer.Visible = false
	end

	if self.Params.Resizable then
		local resizeFrame = samplesFolder:WaitForChild("Resize"):Clone()
		resizeFrame.Frame.BackgroundTransparency = 1
		resizeFrame.Parent = self.Instance

		self._resizeMovement = MouseMovement.new(function(startMousePos, startWindowSize)
			local mousePos = self:GetMousePos()
			local parentSize = self.UI.AbsoluteSize
			local aspectRatio = self.Instance.UIAspectRatioConstraint.AspectRatio

			local offsetX = (mousePos.X - startMousePos.X) * (parentSize.X / parentSize.Y) / aspectRatio
			local newScale = math.clamp(startWindowSize.X.Scale + offsetX / parentSize.X, 0.3, 1)
			self.Instance.Size = UDim2.fromScale(newScale, newScale)
		end)

		local resizeButton = resizeFrame:WaitForChild("Button")
		resizeButton.MouseButton1Down:Connect(function()
			local startMousePos = self:GetMousePos() or Vector2.zero
			local startWindowSize = self.Instance.Size
			self._resizeMovement:Connect(startMousePos, startWindowSize)
		end)

		resizeButton.MouseEnter:Connect(function()
			TweenService:Create(
				resizeFrame.Frame,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ BackgroundTransparency = 0.4 }
			):Play()
		end)

		resizeButton.MouseLeave:Connect(function()
			TweenService:Create(
				resizeFrame.Frame,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ BackgroundTransparency = 1 }
			):Play()
		end)
	end

	if self.Params.Style then
		Styling.stylize(self, self.Params.Style)
	end

	self:SetPickerMode(self.Params.PickerMode)
	self:SetColorSpace(self.Params.ColorSpace)

	if self.Params.TransparencyEnabled then
		BuiltinSliders.Transparency(self)
	end

	self:UpdateBackground()
end

function ColorPicker:Destroy()
	if self._colorChangedEvent then
		self._colorChangedEvent:Destroy()
		self._colorChangedEvent = nil
	end

	if self._windowClosedEvent then
		self._windowClosedEvent:Destroy()
		self._windowClosedEvent = nil
	end

	if self._dragMouseMovement then
		self._dragMouseMovement:Destroy()
	end

	if self._resizeMovement then
		self._resizeMovement:Destroy()
	end

	if self.PickerInterface then
		self.PickerInterface:Destroy()
	end

	for _, v in self._sliders do
		v:Destroy()
	end

	if self.Instance then
		self.Instance:Destroy()
		self.Instance = nil
	end

	if not self.Params.Parent and self.UI then
		self.UI:Destroy()
		self.UI = nil
	end
end

return ColorPicker
