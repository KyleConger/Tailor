export type Color = {
	Hue: number,
	Saturation: number,
	Value: number,
	Transparency: number?,
}

export type Params = {
	Parent: SurfaceGui?,
	Position: UDim2?,
	Size: (number | UDim2)?,
	TopbarEnabled: boolean?,
	PaletteEnabled: boolean?,
	Draggable: boolean?,
	Resizable: boolean?,
	DisplayOrder: number?,
	ZIndex: number?,
	TransparencyEnabled: boolean?,
	UserCanClose: boolean?,
	PickerMode: PickerMode?,
	ColorSpace: ColorSpace?,
	Style: StyleGuide?,
}

export type PickerMode = "Circle" | "Square" | "Triangle"
export type ColorSpace = number
export type PaletteColor = Color3 | string

export type ColorPicker = {
	Color: Color,
	Params: Params,

	ColorChanged: RBXScriptSignal,
	WindowClosed: RBXScriptSignal,

	new: (Params) -> ColorPicker,

	SetHSV: (self: ColorPicker, number, number, number) -> nil,
	GetHSV: (self: ColorPicker) -> (number, number, number),
	SetColor: (self: ColorPicker, Color3) -> nil,
	GetColor: (self: ColorPicker) -> (Color3, number?),
	SetTransparency: (self: ColorPicker, number) -> nil,
	GetTransparency: (self: ColorPicker) -> number?,

	SetVisible: (self: ColorPicker, boolean) -> nil,
	GetVisible: (self: ColorPicker) -> boolean,

	SetPickerMode: (self: ColorPicker, PickerMode) -> nil,
	SetColorSpace: (self: ColorPicker, ColorSpace) -> nil,

	SetPaletteVisible: (self: ColorPicker, boolean) -> nil,
	GetPaletteColor: (self: ColorPicker, index: number, isColor3: boolean?) -> PaletteColor,
	GetPaletteColors: (self: ColorPicker, isColor3: boolean?) -> { [number]: PaletteColor },
	SetPaletteColor: (self: ColorPicker, index: number, PaletteColor) -> nil,
	SetPaletteColors: (self: ColorPicker, PaletteColors: { [number]: PaletteColor }) -> nil,
	AddPaletteColor: (self: ColorPicker, PaletteColor) -> nil,
	AddPaletteColors: (self: ColorPicker, { [number]: PaletteColor }) -> nil,

	GetPosition: (self: ColorPicker) -> UDim2,
	SetPosition: (self: ColorPicker, UDim2) -> nil,
	GetSize: (self: ColorPicker) -> UDim2,
	SetSize: (self: ColorPicker, UDim2 | number) -> nil,

	Destroy: (self: ColorPicker) -> nil,

	PICKER_MODE: { CIRCLE: string, SQUARE: string, TRIANGLE: string },
	COLOR_SPACE: { HSV: number, RGB: number },
}

type StyleColor = {
	Color: Color3?,
	Transparency: number?,
}

export type StyleGuide = {
	BackgroundColor: StyleColor?,
	AccentColor: StyleColor?,
	TextColor: StyleColor?,
	RoundedCorners: boolean?,
}

return {}
