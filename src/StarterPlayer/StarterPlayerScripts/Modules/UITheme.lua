local Theme = {}

-- Genshin-inspired palette (dark HUD + light menus)

-- HUD panels (dark translucent for in-game readability)
Theme.HUD_BG = Color3.fromRGB(20, 25, 35)
Theme.HUD_TRANSPARENCY = 0.2
Theme.HUD_INNER = Color3.fromRGB(30, 35, 50)

-- Menu panels (light, for backpack/popups)
Theme.MENU_BG = Color3.fromRGB(245, 245, 250)
Theme.MENU_TRANSPARENCY = 0.08
Theme.MENU_INNER = Color3.fromRGB(235, 237, 245)

-- Accent
Theme.ACCENT = Color3.fromRGB(70, 175, 230)
Theme.ACCENT_GLOW = Color3.fromRGB(100, 200, 255)
Theme.ACCENT_DIM = Color3.fromRGB(50, 120, 170)

-- Text
Theme.TEXT_WHITE = Color3.fromRGB(240, 242, 248)
Theme.TEXT_LIGHT = Color3.fromRGB(180, 185, 195)
Theme.TEXT_DARK = Color3.fromRGB(45, 50, 60)
Theme.TEXT_MID = Color3.fromRGB(100, 108, 120)

-- Bars
Theme.HP_GREEN = Color3.fromRGB(90, 200, 90)
Theme.HP_BG = Color3.fromRGB(40, 50, 40)
Theme.MP_BLUE = Color3.fromRGB(75, 155, 235)
Theme.MP_BG = Color3.fromRGB(35, 40, 60)

-- Slots
Theme.SLOT_BG = Color3.fromRGB(35, 40, 55)
Theme.SLOT_BORDER = Color3.fromRGB(60, 68, 85)
Theme.SLOT_LIGHT = Color3.fromRGB(225, 228, 238)
Theme.SLOT_BORDER_LIGHT = Color3.fromRGB(195, 200, 212)

-- Misc
Theme.DIVIDER = Color3.fromRGB(60, 68, 85)
Theme.DIVIDER_LIGHT = Color3.fromRGB(210, 215, 225)

function Theme.corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

function Theme.stroke(parent, thickness, color, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.SLOT_BORDER
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.3
	s.Parent = parent
	return s
end

function Theme.gradient(parent, topColor, bottomColor)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(topColor, bottomColor)
	g.Rotation = 90
	g.Parent = parent
	return g
end

function Theme.shadow(parent, offset, spread)
	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxassetid://5554236805"
	shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	shadow.ImageTransparency = 0.78
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(23, 23, 277, 277)
	local s = spread or 20
	shadow.Size = UDim2.new(1, s, 1, s)
	shadow.Position = UDim2.new(0, -s / 2, 0, (offset or 4) - s / 2)
	shadow.ZIndex = math.max(1, parent.ZIndex - 1)
	shadow.Parent = parent
	return shadow
end

function Theme.circleFrame(parent, diameter, position)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, diameter, 0, diameter)
	frame.Position = position or UDim2.new(0, 0, 0, 0)
	frame.BackgroundColor3 = Theme.SLOT_BG
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Theme.corner(frame, math.ceil(diameter / 2))
	return frame
end

-- Auto-scale based on viewport size (reference: 1920x1080)
local REF_WIDTH = 1600
local REF_HEIGHT = 900

function Theme.autoScale(screenGui)
	local camera = workspace.CurrentCamera
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = screenGui

	local function update()
		local viewportSize = camera.ViewportSize
		local scaleX = viewportSize.X / REF_WIDTH
		local scaleY = viewportSize.Y / REF_HEIGHT
		uiScale.Scale = math.min(scaleX, scaleY)
	end

	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()

	return uiScale
end

function Theme.slot(parent, size, radius)
	local r = radius or 10
	local frame = Instance.new("Frame")
	frame.Size = size or UDim2.new(0, 46, 0, 46)
	frame.BackgroundColor3 = Color3.fromRGB(32, 37, 52)
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.Parent = parent

	-- Rounded corners
	Theme.corner(frame, r)

	-- Outer border
	Theme.stroke(frame, 1, Color3.fromRGB(55, 62, 80), 0.2)

	-- Top highlight (subtle glass edge)
	local highlight = Instance.new("Frame")
	highlight.Size = UDim2.new(1, -4, 0.4, 0)
	highlight.Position = UDim2.new(0, 2, 0, 2)
	highlight.BackgroundColor3 = Color3.fromRGB(60, 68, 90)
	highlight.BackgroundTransparency = 0.5
	highlight.BorderSizePixel = 0
	highlight.ZIndex = 2
	highlight.Parent = frame
	Theme.corner(highlight, math.max(r - 2, 4))

	local highlightGrad = Instance.new("UIGradient")
	highlightGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	highlightGrad.Rotation = 90
	highlightGrad.Parent = highlight

	-- Bottom inner shadow (depth)
	local innerShadow = Instance.new("Frame")
	innerShadow.Size = UDim2.new(1, -4, 0.3, 0)
	innerShadow.Position = UDim2.new(0, 2, 0.7, -2)
	innerShadow.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
	innerShadow.BackgroundTransparency = 0.6
	innerShadow.BorderSizePixel = 0
	innerShadow.ZIndex = 2
	innerShadow.Parent = frame
	Theme.corner(innerShadow, math.max(r - 2, 4))

	local shadowGrad = Instance.new("UIGradient")
	shadowGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	shadowGrad.Rotation = 90
	shadowGrad.Parent = innerShadow

	return frame
end

return Theme
