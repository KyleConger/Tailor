local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

local ColorPicker = require(script.Parent.Parent.Components.ColorPicker)

local PLAYER = Players.LocalPlayer
local DEFAULT_RADIUS = 0.12

local THEME = {
	background = Color3.fromRGB(17, 19, 24),
	panel = Color3.fromRGB(27, 30, 38),
	card = Color3.fromRGB(35, 39, 49),
	accent = Color3.fromRGB(84, 116, 255),
	text = Color3.fromRGB(238, 241, 248),
	muted = Color3.fromRGB(151, 158, 177),
	danger = Color3.fromRGB(229, 78, 96),
}

local OutfitSearchController = Knit.CreateController({
	Name = "OutfitSearchController",
})

local function create(className, name, parent, properties)
	local instance = Instance.new(className)
	instance.Name = name
	for property, value in properties or {} do
		instance[property] = value
	end
	instance.Parent = parent
	return instance
end

local function addCorner(parent, radius)
	return create("UICorner", "UICorner", parent, {
		CornerRadius = UDim.new(0, radius or 10),
	})
end

local function addPadding(parent, padding)
	return create("UIPadding", "UIPadding", parent, {
		PaddingBottom = UDim.new(0, padding),
		PaddingLeft = UDim.new(0, padding),
		PaddingRight = UDim.new(0, padding),
		PaddingTop = UDim.new(0, padding),
	})
end

local function colorToHex(color)
	return string.format("#%s", color:ToHex())
end

local function makeLabel(parent, text, size, position, textSize, color)
	return create("TextLabel", "Label", parent, {
		BackgroundTransparency = 1,
		Position = position or UDim2.new(),
		Size = size,
		Text = text,
		TextColor3 = color or THEME.text,
		TextSize = textSize or 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
	})
end

local function makeButton(parent, text, size, position, color)
	local button = create("TextButton", "Button", parent, {
		AutoButtonColor = true,
		BackgroundColor3 = color or THEME.card,
		Position = position or UDim2.new(),
		Size = size,
		Text = text,
		TextColor3 = THEME.text,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
	})
	addCorner(button, 9)
	return button
end

function OutfitSearchController:_makeColorSlot(parent, key, title, color, order)
	local button = makeButton(parent, "", UDim2.new(1, 0, 0, 58), nil, THEME.card)
	button.Name = key
	button.LayoutOrder = order

	local swatch = create("Frame", "Swatch", button, {
		BackgroundColor3 = color,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(42, 42),
	})
	addCorner(swatch, 8)

	makeLabel(button, title, UDim2.new(1, -66, 0, 22), UDim2.fromOffset(60, 7), 13, THEME.muted)
	local hex = makeLabel(
		button,
		colorToHex(color),
		UDim2.new(1, -66, 0, 22),
		UDim2.fromOffset(60, 29),
		14,
		THEME.text
	)
	hex.Name = "Hex"
	hex.Font = Enum.Font.Code

	button.Activated:Connect(function()
		self:_openPicker(key)
	end)

	self._slotButtons[key] = button
end

function OutfitSearchController:_updateColorSlot(key)
	local button = self._slotButtons[key]
	local color = self._colors[key]
	button.Swatch.BackgroundColor3 = color
	button.Hex.Text = colorToHex(color)
end

function OutfitSearchController:_openPicker(key)
	if self._picker then
		self._picker:Destroy()
		self._picker = nil
	end

	self._activeSlot = key
	self._picker = ColorPicker.new({
		Parent = self._screenGui,
		Position = UDim2.fromScale(0.2, 0.54),
		Size = UDim2.fromOffset(440, 330),
		Resizable = false,
		PickerMode = ColorPicker.PICKER_MODE.SQUARE,
		ColorSpace = ColorPicker.COLOR_SPACE.RGB,
		Style = {
			BackgroundColor = { Color = THEME.background },
			AccentColor = { Color = THEME.panel },
			TextColor = { Color = THEME.text },
		},
	})
	self._picker:SetColor(self._colors[key])

	self._picker.ColorChanged:Connect(function(color)
		self._colors[key] = color
		self:_updateColorSlot(key)
	end)

	self._picker.WindowClosed:Connect(function()
		self._picker = nil
		self._activeSlot = nil
	end)
end

function OutfitSearchController:_getRadius()
	local percent = tonumber(self._radiusInput.Text) or (DEFAULT_RADIUS * 100)
	percent = math.clamp(percent, 2.5, 35)
	self._radiusInput.Text = string.format("%.1f", percent)
	return percent / 100
end

function OutfitSearchController:_clearResults()
	for _, child in self._results:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

function OutfitSearchController:_promptAsset(assetId)
	local success, errorMessage = pcall(function()
		MarketplaceService:PromptPurchase(PLAYER, assetId)
	end)
	if not success then
		self._status.Text = "Could not open asset: " .. tostring(errorMessage)
	end
end

function OutfitSearchController:_tryOn(result, button)
	if not button.Active then
		return
	end

	button.Active = false
	button.Text = "Applying..."
	self._service
		:TryOn(result.topId, result.bottomId)
		:andThen(function(response)
			button.Active = true
			button.Text = "Try on"
			if response and response.ok then
				self._status.Text = "Outfit applied to your avatar."
			else
				self._status.Text = if response then response.error else "Could not apply outfit"
			end
		end)
		:catch(function(errorMessage)
			button.Active = true
			button.Text = "Try on"
			self._status.Text = "Could not apply outfit: " .. tostring(errorMessage)
		end)
end

function OutfitSearchController:_renderResult(result, order)
	local card = create("Frame", "Result", self._results, {
		BackgroundColor3 = THEME.card,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 126),
	})
	addCorner(card, 10)

	create("ImageLabel", "Thumbnail", card, {
		BackgroundColor3 = THEME.panel,
		Image = string.format("rbxthumb://type=Asset&id=%s&w=150&h=150", tostring(result.topId)),
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(110, 110),
	})
	addCorner(card.Thumbnail, 8)

	local title = makeLabel(
		card,
		result.topName,
		UDim2.new(1, -135, 0, 36),
		UDim2.fromOffset(128, 8),
		14,
		THEME.text
	)
	title.Font = Enum.Font.GothamBold

	makeLabel(
		card,
		result.bottomName,
		UDim2.new(1, -135, 0, 30),
		UDim2.fromOffset(128, 42),
		12,
		THEME.muted
	)

	local matchText = string.format(
		"%s %.1f%%  •  %s %.1f%%  •  R$%d",
		result.firstHex,
		result.firstDistance * 100,
		result.secondHex,
		result.secondDistance * 100,
		result.priceTotal
	)
	local match = makeLabel(card, matchText, UDim2.new(1, -135, 0, 20), UDim2.fromOffset(128, 73), 11, THEME.muted)
	match.Font = Enum.Font.Code

	local topButton = makeButton(card, "Buy top", UDim2.fromOffset(82, 25), UDim2.fromOffset(128, 96), THEME.accent)
	topButton.Activated:Connect(function()
		self:_promptAsset(result.topId)
	end)

	local bottomButton =
		makeButton(card, "Buy bottom", UDim2.fromOffset(90, 25), UDim2.fromOffset(218, 96), THEME.panel)
	bottomButton.Activated:Connect(function()
		self:_promptAsset(result.bottomId)
	end)

	local tryOnButton = makeButton(card, "Try on", UDim2.fromOffset(78, 25), UDim2.fromOffset(316, 96), THEME.panel)
	tryOnButton.Activated:Connect(function()
		self:_tryOn(result, tryOnButton)
	end)
end

function OutfitSearchController:_renderResponse(response)
	self:_clearResults()
	self._searchButton.Text = "Find outfits"
	self._searchButton.Active = true

	if not response or not response.ok then
		self._status.Text = if response then response.error else "Search failed"
		return
	end

	self._status.Text = string.format(
		"%d matching outfits • showing %d • colors currently describe tops",
		response.total,
		#response.results
	)

	if #response.results == 0 then
		local empty = makeLabel(
			self._results,
			"No outfits matched all three color rules. Increase the radius or choose broader colors.",
			UDim2.new(1, -8, 0, 80),
			nil,
			14,
			THEME.muted
		)
		empty.LayoutOrder = 1
		empty.TextXAlignment = Enum.TextXAlignment.Center
	end

	for index, result in response.results do
		self:_renderResult(result, index)
	end
end

function OutfitSearchController:_search()
	if not self._searchButton.Active then
		return
	end

	self._searchButton.Active = false
	self._searchButton.Text = "Searching..."
	self._status.Text = "Comparing 2,454 outfits in perceptual color space..."

	self._service
		:Search({
			include1 = self._colors.include1,
			include2 = self._colors.include2,
			exclude = self._colors.exclude,
			radius = self:_getRadius(),
			limit = 30,
		})
		:andThen(function(response)
			self:_renderResponse(response)
		end)
		:catch(function(errorMessage)
			self:_renderResponse({
				ok = false,
				error = tostring(errorMessage),
			})
		end)
end

function OutfitSearchController:_buildInterface()
	self._screenGui = create("ScreenGui", "OutfitColorSearch", PLAYER:WaitForChild("PlayerGui"), {
		DisplayOrder = 20,
		IgnoreGuiInset = false,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local sidebar = create("Frame", "LeftPanel", self._screenGui, {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = THEME.panel,
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.new(0, 300, 1, -32),
	})
	addCorner(sidebar, 14)
	addPadding(sidebar, 18)

	local title = makeLabel(sidebar, "Outfit color search", UDim2.new(1, 0, 0, 30), nil, 20, THEME.text)
	title.Font = Enum.Font.GothamBold
	makeLabel(
		sidebar,
		"Choose two colors that must appear and one color to reject.",
		UDim2.new(1, 0, 0, 44),
		UDim2.fromOffset(0, 34),
		12,
		THEME.muted
	)

	local slots = create("Frame", "Slots", sidebar, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 190),
	})
	create("UIListLayout", "UIListLayout", slots, {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	self:_makeColorSlot(slots, "include1", "Include color 1", self._colors.include1, 1)
	self:_makeColorSlot(slots, "include2", "Include color 2", self._colors.include2, 2)
	self:_makeColorSlot(slots, "exclude", "Exclude color", self._colors.exclude, 3)

	makeLabel(sidebar, "Match radius (2.5–35%)", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 300), 12, THEME.muted)
	self._radiusInput = create("TextBox", "Radius", sidebar, {
		BackgroundColor3 = THEME.card,
		ClearTextOnFocus = false,
		Position = UDim2.fromOffset(0, 326),
		Size = UDim2.new(1, 0, 0, 40),
		Text = string.format("%.1f", DEFAULT_RADIUS * 100),
		TextColor3 = THEME.text,
		TextSize = 15,
		Font = Enum.Font.Code,
	})
	addCorner(self._radiusInput, 9)

	self._searchButton =
		makeButton(sidebar, "Find outfits", UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 380), THEME.accent)
	self._searchButton.Activated:Connect(function()
		self:_search()
	end)

	local content = create("Frame", "RightPanel", self._screenGui, {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = THEME.background,
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.new(0, 460, 1, -32),
	})
	addCorner(content, 14)
	addPadding(content, 18)

	self._status =
		makeLabel(content, "Choose your colors, then search.", UDim2.new(1, 0, 0, 28), nil, 13, THEME.muted)
	self._results = create("ScrollingFrame", "Results", content, {
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		Position = UDim2.fromOffset(0, 38),
		ScrollBarImageColor3 = THEME.muted,
		ScrollBarThickness = 5,
		Size = UDim2.new(1, 0, 1, -38),
	})
	create("UIListLayout", "UIListLayout", self._results, {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function OutfitSearchController:KnitStart()
	self._service = Knit.GetService("OutfitSearchService")
	self._colors = {
		include1 = Color3.fromHex("#202020"),
		include2 = Color3.fromHex("#81807E"),
		exclude = Color3.fromHex("#D02030"),
	}
	self._slotButtons = {}
	self:_buildInterface()
end

return OutfitSearchController
