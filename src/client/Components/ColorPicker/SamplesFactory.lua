local SamplesFactory = {}

local COLORS = {
	background = Color3.fromRGB(23, 25, 31),
	panel = Color3.fromRGB(34, 37, 46),
	accent = Color3.fromRGB(75, 112, 255),
	text = Color3.fromRGB(238, 240, 247),
	muted = Color3.fromRGB(147, 154, 175),
	danger = Color3.fromRGB(225, 73, 90),
}

local function create(className, name, parent, properties)
	local instance = Instance.new(className)
	instance.Name = name
	for property, value in properties or {} do
		instance[property] = value
	end
	instance.Parent = parent
	return instance
end

local function corner(parent, scale)
	return create("UICorner", "UICorner", parent, {
		CornerRadius = UDim.new(scale or 0.12, 0),
	})
end

local function stroke(parent, color, transparency)
	return create("UIStroke", "UIStroke", parent, {
		Color = color or COLORS.muted,
		Transparency = transparency or 0.55,
		Thickness = 1,
	})
end

local function textButton(name, parent, text, position, size)
	local button = create("TextButton", name, parent, {
		AutoButtonColor = true,
		BackgroundColor3 = COLORS.panel,
		Position = position,
		Size = size,
		Text = text,
		TextColor3 = COLORS.text,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
	})
	corner(button, 0.16)
	return button
end

local function transparentButton(parent)
	return create("TextButton", "Button", parent, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 20,
	})
end

local function makeColorPickerSample(folder)
	local root = create("Frame", "ColorPickerSample", folder, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 420),
		Visible = false,
	})
	create("UIAspectRatioConstraint", "UIAspectRatioConstraint", root, {
		AspectRatio = 4 / 3,
		AspectType = Enum.AspectType.ScaleWithParentSize,
	})

	local background = create("Frame", "Background", root, {
		BackgroundColor3 = COLORS.background,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
	})
	corner(background, 0.035)
	stroke(background)

	local middle = create("Frame", "Middle", root, {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.035, 0.13),
		Size = UDim2.fromScale(0.93, 0.18),
	})

	local preview = create("Frame", "ColorPreview", middle, {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0.17, 1),
	})
	corner(preview, 0.14)
	stroke(preview, Color3.new(1, 1, 1), 0.7)

	local options = create("Frame", "Options", middle, {
		BackgroundColor3 = COLORS.panel,
		Position = UDim2.fromScale(0.2, 0),
		Size = UDim2.fromScale(0.8, 1),
	})
	corner(options, 0.05)

	local hex = create("Frame", "Hex", options, {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.04, 0.15),
		Size = UDim2.fromScale(0.47, 0.7),
	})
	create("TextLabel", "Label", hex, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.3, 1),
		Text = "HEX",
		TextColor3 = COLORS.muted,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
	})
	local hexInput = create("TextBox", "Input", hex, {
		BackgroundColor3 = COLORS.background,
		Position = UDim2.fromScale(0.31, 0),
		Size = UDim2.fromScale(0.69, 1),
		ClearTextOnFocus = false,
		Text = "#FFFFFF",
		TextColor3 = COLORS.text,
		TextSize = 14,
		Font = Enum.Font.Code,
	})
	corner(hexInput, 0.14)

	local colorSpace = create("Frame", "ColorSpace", options, {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.55, 0.15),
		Size = UDim2.fromScale(0.41, 0.7),
	})
	for index, name in { "HSV", "RGB" } do
		local item = create("Frame", name, colorSpace, {
			BackgroundColor3 = COLORS.background,
			Position = UDim2.fromScale((index - 1) * 0.52, 0),
			Size = UDim2.fromScale(0.48, 1),
		})
		corner(item, 0.14)
		create("TextLabel", "Icon", item, {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = name,
			TextColor3 = COLORS.text,
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
		})
		create("Frame", "Selection", item, {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = COLORS.accent,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(0.65, 0.06),
			Visible = false,
		})
		transparentButton(item)
	end

	local picker = create("Frame", "Picker", root, {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.04, 0.36),
		Size = UDim2.fromScale(0.47, 0.58),
	})
	create("UIAspectRatioConstraint", "UIAspectRatioConstraint", picker, {
		AspectRatio = 1,
	})
	local selectImage = create("ImageLabel", "Select", picker, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.05,
		Size = UDim2.fromOffset(14, 14),
		Image = "",
		ZIndex = 15,
	})
	corner(selectImage, 0.5)
	stroke(selectImage, Color3.new(0, 0, 0), 0)
	transparentButton(picker)

	local settings = create("Frame", "Settings", root, {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.55, 0.36),
		Size = UDim2.fromScale(0.41, 0.12),
	})
	local pickerMode = create("Frame", "PickerMode", settings, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.76, 1),
	})
	for index, name in { "Circle", "Square", "Triangle" } do
		local item = create("Frame", name, pickerMode, {
			BackgroundColor3 = COLORS.panel,
			Position = UDim2.fromScale((index - 1) * 0.34, 0),
			Size = UDim2.fromScale(0.31, 1),
		})
		corner(item, 0.15)
		create("TextLabel", "Icon", item, {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = string.sub(name, 1, 1),
			TextColor3 = COLORS.text,
			TextSize = 15,
			Font = Enum.Font.GothamBold,
		})
		transparentButton(item)
	end

	local paletteControl = create("Frame", "Palette", settings, {
		BackgroundColor3 = COLORS.panel,
		Position = UDim2.fromScale(0.8, 0),
		Size = UDim2.fromScale(0.2, 1),
	})
	corner(paletteControl, 0.15)
	create("TextLabel", "Icon", paletteControl, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "+",
		TextColor3 = COLORS.text,
		TextSize = 20,
		Font = Enum.Font.GothamBold,
	})
	transparentButton(paletteControl)

	local sliders = create("Frame", "Sliders", root, {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.55, 0.51),
		Size = UDim2.fromScale(0.41, 0.43),
	})
	create("UIListLayout", "UIListLayout", sliders, {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0.03, 0),
		SortOrder = Enum.SortOrder.Name,
	})

	local palette = create("Frame", "Palette", root, {
		BackgroundColor3 = COLORS.panel,
		Position = UDim2.fromScale(0.55, 0.36),
		Size = UDim2.fromScale(0.41, 0.58),
		Visible = false,
		ZIndex = 10,
	})
	corner(palette, 0.04)
	textButton("Close", palette, "Back", UDim2.fromScale(0.04, 0.04), UDim2.fromScale(0.43, 0.12))
	textButton("Save", palette, "Save color", UDim2.fromScale(0.53, 0.04), UDim2.fromScale(0.43, 0.12))
	local list = create("ScrollingFrame", "List", palette, {
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		Position = UDim2.fromScale(0.04, 0.2),
		ScrollBarThickness = 4,
		Size = UDim2.fromScale(0.92, 0.76),
	})
	create("UIListLayout", "UIListLayout", list, {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	return root
end

local function makeTopbar(folder)
	local topbar = create("Frame", "Topbar", folder, {
		BackgroundColor3 = COLORS.panel,
		Size = UDim2.fromScale(1, 0.1),
		Visible = true,
	})
	corner(topbar, 0.08)
	create("TextLabel", "Title", topbar, {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.04, 0),
		Size = UDim2.fromScale(0.72, 1),
		Text = "Choose a color",
		TextColor3 = COLORS.text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
	})
	transparentButton(topbar)
	return topbar
end

local function makeTopbarCloseButton(folder)
	local button = create("ImageButton", "TopbarCloseButton", folder, {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = COLORS.danger,
		Position = UDim2.fromScale(0.97, 0.5),
		Size = UDim2.fromOffset(26, 26),
		Image = "",
		ZIndex = 30,
	})
	corner(button, 0.5)
	create("TextLabel", "Icon", button, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "×",
		TextColor3 = COLORS.text,
		TextSize = 18,
		Font = Enum.Font.GothamBold,
	})
	return button
end

local function makeResize(folder)
	local resize = create("Frame", "Resize", folder, {
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(28, 28),
	})
	create("Frame", "Frame", resize, {
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = COLORS.text,
		Position = UDim2.fromScale(0.82, 0.82),
		Rotation = -45,
		Size = UDim2.fromOffset(12, 3),
	})
	transparentButton(resize)
	return resize
end

local function makeSliderSample(folder)
	local sample = create("Frame", "SliderSample", folder, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.22),
		Visible = true,
	})
	create("TextLabel", "Title", sample, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.22, 1),
		Text = "",
		TextColor3 = COLORS.muted,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamMedium,
	})
	local slider = create("Frame", "Slider", sample, {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromScale(0.23, 0.3),
		Size = UDim2.fromScale(0.53, 0.4),
	})
	corner(slider, 0.5)
	create("UIGradient", "Gradient", slider, {})
	local select = create("Frame", "Select", slider, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(10, 18),
		ZIndex = 5,
	})
	corner(select, 0.5)
	stroke(select, Color3.new(0, 0, 0), 0.35)
	transparentButton(slider)

	local input = create("Frame", "Input", sample, {
		BackgroundColor3 = COLORS.panel,
		Position = UDim2.fromScale(0.79, 0.12),
		Size = UDim2.fromScale(0.21, 0.76),
	})
	corner(input, 0.15)
	create("TextBox", "TextBox", input, {
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Size = UDim2.fromScale(1, 1),
		Text = "0",
		TextColor3 = COLORS.text,
		TextSize = 12,
		Font = Enum.Font.Code,
	})
	return sample
end

local function makePaletteItemSample(folder)
	local sample = create("Frame", "PaletteItemSample", folder, {
		BackgroundColor3 = COLORS.background,
		Size = UDim2.new(1, -4, 0, 42),
		Visible = false,
	})
	corner(sample, 0.12)
	local preview = create("Frame", "Preview", sample, {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromScale(0.03, 0.15),
		Size = UDim2.fromScale(0.14, 0.7),
	})
	corner(preview, 0.15)
	create("TextLabel", "Index", sample, {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.19, 0),
		Size = UDim2.fromScale(0.1, 1),
		Text = "1",
		TextColor3 = COLORS.muted,
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
	})
	create("TextLabel", "Hex", sample, {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.29, 0),
		Size = UDim2.fromScale(0.45, 1),
		Text = "#FFFFFF",
		TextColor3 = COLORS.text,
		TextSize = 13,
		Font = Enum.Font.Code,
	})
	local delete = create("Frame", "Delete", sample, {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.78, 0.1),
		Size = UDim2.fromScale(0.18, 0.8),
	})
	create("TextLabel", "Icon", delete, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "×",
		TextColor3 = COLORS.danger,
		TextSize = 17,
		Font = Enum.Font.GothamBold,
	})
	transparentButton(delete)
	transparentButton(sample)
	return sample
end

function SamplesFactory.ensure(folder)
	if not folder:FindFirstChild("ColorPickerSample") then
		makeColorPickerSample(folder)
	end
	if not folder:FindFirstChild("Topbar") then
		makeTopbar(folder)
	end
	if not folder:FindFirstChild("TopbarCloseButton") then
		makeTopbarCloseButton(folder)
	end
	if not folder:FindFirstChild("Resize") then
		makeResize(folder)
	end
	if not folder:FindFirstChild("SliderSample") then
		makeSliderSample(folder)
	end
	if not folder:FindFirstChild("PaletteItemSample") then
		makePaletteItemSample(folder)
	end
end

return SamplesFactory
