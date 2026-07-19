local Styling = {}

function Styling.applyStyleColor(instance, colorProp, tProp, styleColor)
	if styleColor.Color then
		instance[colorProp] = styleColor.Color
	end

	if styleColor.Transparency then
		instance[tProp] = styleColor.Transparency
	end
end

function Styling.stylize(ColorPicker, styleGuide)
	local obj = ColorPicker.Instance
	if styleGuide.BackgroundColor then
		Styling.applyStyleColor(obj.Background, "BackgroundColor3", "BackgroundTransparency", styleGuide.BackgroundColor)
	end

	if styleGuide.AccentColor then
		Styling.applyStyleColor(obj.Topbar, "BackgroundColor3", "BackgroundTransparency", styleGuide.AccentColor)
		Styling.applyStyleColor(
			obj.Middle.Options,
			"BackgroundColor3",
			"BackgroundTransparency",
			styleGuide.AccentColor
		)
		Styling.applyStyleColor(obj.Palette, "BackgroundColor3", "BackgroundTransparency", styleGuide.AccentColor)
	end

	if styleGuide.TextColor then
		for _, v in obj:GetDescendants() do
			if v:IsDescendantOf(obj.Picker) then
				continue
			end
			if v:IsA("TextLabel") or v:IsA("TextBox") then
				Styling.applyStyleColor(v, "TextColor3", "TextTransparency", styleGuide.TextColor)
			elseif v:IsA("ImageLabel") or v:IsA("ImageButton") then
				Styling.applyStyleColor(v, "ImageColor3", "ImageTransparency", styleGuide.TextColor)
			end
		end

		if obj:FindFirstChild("Resize") and obj.Resize:FindFirstChild("Frame") then
			obj.Resize.Frame.BackgroundColor3 = styleGuide.TextColor.Color
		end
	end

	if styleGuide.RoundedCorners == false then
		for _, v in obj:GetDescendants() do
			if v:IsA("UICorner") then
				v:Destroy()
			end
		end
	end
end

function Styling.stylizeSlider(instance, styleGuide)
	if styleGuide.AccentColor then
		Styling.applyStyleColor(instance.Input, "BackgroundColor3", "BackgroundTransparency", styleGuide.AccentColor)
	end

	if styleGuide.TextColor then
		Styling.applyStyleColor(instance.Input.TextBox, "TextColor3", "TextTransparency", styleGuide.TextColor)
	end

	if styleGuide.RoundedCorners == false then
		for _, v in instance:GetDescendants() do
			if v:IsA("UICorner") then
				v:Destroy()
			end
		end
	end
end

return Styling
