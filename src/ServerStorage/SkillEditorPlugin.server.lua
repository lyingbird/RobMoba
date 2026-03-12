--[[
	Skill Editor Pro - Roblox Studio Plugin
	6-Track skill presentation editor
	Camera | Animation | VFX | Sound | Event | Hitbox
	
	Usage:
	1. Right-click -> Save as Local Plugin
	2. Restart Studio, click "Skill Editor" in Plugins tab
	3. Add keyframes to tracks, adjust properties
	4. Preview with Play, Export to ModuleScript
]]

if not plugin then return end

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Selection = game:GetService("Selection")

-- ===================== PLUGIN SETUP =====================
local toolbar = plugin:CreateToolbar("Skill Editor Pro")
local openBtn = toolbar:CreateButton("SkillEditorBtn", "Open Skill Editor Pro", "rbxassetid://6031071050")

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Bottom,
	false, false,
	1400, 550,
	1000, 450
)
local widget = plugin:CreateDockWidgetPluginGui("SkillEditorProWidget", widgetInfo)
widget.Title = "Skill Editor Pro"

openBtn.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

-- ===================== STATE =====================
local tracks = {
	camera = {},
	animation = {},
	vfx = {},
	sound = {},
	event = {},
	hitbox = {},
}
local selection = { track = nil, index = 0 }
local previewing = false
local previewConn = nil
local savedCamCF, savedCamFov = nil, nil
local dragging, draggingTrack, draggingIdx = false, nil, nil
local dragPending, dragStartX = false, 0
local dragNeedStart = false
local DRAG_THRESHOLD = 5
local selectedRig = nil
local previewAnims = {}
local previewSounds = {}
local previewSubConns = {}
local previewHitboxParts = {}
local zoomLevel = 1.0
local scrollOffset = 0
local undoStack = {}
local clipboard = nil
local MAX_UNDO = 40
local snapEnabled = false
local snapInterval = 0.1
local FPS = 30

local EASINGS = {"Linear","Sine","Quad","Quint","Back","Exponential"}
local DIRS = {"InOut","In","Out"}
local VFX_TYPES = {"flash","shake","blur","colorShift"}
local EVENT_TYPES = {"damage","displacement","superArmor","buff","custom"}
local HITBOX_SHAPES = {"circle","rectangle","sector"}
local TRACK_NAMES = {"camera","animation","vfx","sound","event","hitbox"}
local TRACK_LABELS = {"Camera","Anim","VFX","Sound","Event","Hitbox"}

-- ===================== THEME =====================
local C = {
	bg       = Color3.fromRGB(22,22,28),
	panel    = Color3.fromRGB(32,32,40),
	panel2   = Color3.fromRGB(38,38,48),
	accent   = Color3.fromRGB(60,140,255),
	accent2  = Color3.fromRGB(80,160,255),
	text     = Color3.fromRGB(220,220,228),
	text2    = Color3.fromRGB(180,180,195),
	dim      = Color3.fromRGB(95,95,110),
	btn      = Color3.fromRGB(48,48,58),
	btnHover = Color3.fromRGB(62,62,75),
	btnPress = Color3.fromRGB(38,38,48),
	red      = Color3.fromRGB(220,60,60),
	green    = Color3.fromRGB(50,185,80),
	yellow   = Color3.fromRGB(240,195,50),
	purple   = Color3.fromRGB(170,95,235),
	cyan     = Color3.fromRGB(55,195,215),
	orange   = Color3.fromRGB(255,140,50),
	pink     = Color3.fromRGB(255,90,130),
	input    = Color3.fromRGB(20,20,26),
	inputBdr = Color3.fromRGB(55,55,68),
	playhead = Color3.fromRGB(255,50,50),
	tlBg     = Color3.fromRGB(42,42,52),
	trackBg  = Color3.fromRGB(34,34,42),
	trackAlt = Color3.fromRGB(38,38,48),
	gridLine = Color3.fromRGB(50,50,62),
	gridMaj  = Color3.fromRGB(60,60,75),
	sel      = Color3.fromRGB(255,110,35),
	castMark = Color3.fromRGB(255,220,50),
	cancelMark = Color3.fromRGB(255,100,80),
	shadow   = Color3.fromRGB(0,0,0),
	statusBar = Color3.fromRGB(26,26,34),
	sep      = Color3.fromRGB(55,55,68),
}
local TRACK_COLORS = {
	Color3.fromRGB(255,200,55),   -- Camera (gold)
	Color3.fromRGB(75,210,105),   -- Animation (green)
	Color3.fromRGB(175,105,245),  -- VFX (purple)
	Color3.fromRGB(65,200,225),   -- Sound (cyan)
	Color3.fromRGB(255,145,55),   -- Event (orange)
	Color3.fromRGB(255,90,130),   -- Hitbox (pink)
}

-- ===================== UI HELPERS =====================
local function corner(p, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 5); c.Parent = p
end

local function stroke(p, col, thick)
	local s = Instance.new("UIStroke")
	s.Color = col or C.inputBdr; s.Thickness = thick or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

local function mkBtn(parent, text, size, pos, color, textCol)
	local baseCol = color or C.btn
	local b = Instance.new("TextButton")
	b.Size = size; b.Position = pos
	b.BackgroundColor3 = baseCol
	b.TextColor3 = textCol or C.text; b.Text = text
	b.Font = Enum.Font.GothamBold; b.TextSize = 11
	b.BorderSizePixel = 0; b.AutoButtonColor = false
	b.Parent = parent; corner(b)
	-- Hover / press effects
	b.MouseEnter:Connect(function()
		if baseCol == C.btn then b.BackgroundColor3 = C.btnHover
		else
			local r,g,bl = baseCol.R, baseCol.G, baseCol.B
			b.BackgroundColor3 = Color3.new(math.min(r+0.08,1), math.min(g+0.08,1), math.min(bl+0.08,1))
		end
	end)
	b.MouseLeave:Connect(function() b.BackgroundColor3 = baseCol end)
	b.MouseButton1Down:Connect(function()
		if baseCol == C.btn then b.BackgroundColor3 = C.btnPress
		else
			local r,g,bl = baseCol.R, baseCol.G, baseCol.B
			b.BackgroundColor3 = Color3.new(math.max(r-0.06,0), math.max(g-0.06,0), math.max(bl-0.06,0))
		end
	end)
	b.MouseButton1Up:Connect(function() b.BackgroundColor3 = baseCol end)
	return b
end

local function mkLabel(parent, text, size, pos, ts)
	local l = Instance.new("TextLabel")
	l.Size = size; l.Position = pos; l.BackgroundTransparency = 1
	l.TextColor3 = C.text; l.Text = text
	l.Font = Enum.Font.Gotham; l.TextSize = ts or 11
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function mkInput(parent, default, size, pos)
	local t = Instance.new("TextBox")
	t.Size = size; t.Position = pos
	t.BackgroundColor3 = C.input; t.TextColor3 = C.text
	t.Text = default; t.Font = Enum.Font.GothamBold; t.TextSize = 11
	t.BorderSizePixel = 0; t.ClearTextOnFocus = false
	t.Parent = parent; corner(t, 4)
	stroke(t, C.inputBdr, 1)
	-- Focus highlight
	t.Focused:Connect(function()
		local s = t:FindFirstChildOfClass("UIStroke")
		if s then s.Color = C.accent end
	end)
	t.FocusLost:Connect(function()
		local s = t:FindFirstChildOfClass("UIStroke")
		if s then s.Color = C.inputBdr end
	end)
	return t
end

local function mkSep(parent, pos)
	local s = Instance.new("Frame")
	s.Size = UDim2.new(0,1,0,20); s.Position = pos
	s.BackgroundColor3 = C.sep; s.BorderSizePixel = 0
	s.BackgroundTransparency = 0.4; s.Parent = parent
	return s
end

local function mkSectionHead(parent, text, color, pos)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1,-6,0,20); f.Position = pos
	f.BackgroundColor3 = C.panel; f.BorderSizePixel = 0
	f.Parent = parent; corner(f, 3)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0,3,0,14); bar.Position = UDim2.new(0,3,0,3)
	bar.BackgroundColor3 = color; bar.BorderSizePixel = 0
	bar.Parent = f; corner(bar, 1)
	local lbl = mkLabel(f, text, UDim2.new(1,-12,1,0), UDim2.new(0,10,0,0), 10)
	lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = C.text2
	return f
end

local function deepCopyT(t)
	if type(t) ~= "table" then return t end
	local copy = {}
	for k, v in pairs(t) do
		if typeof(v) == "CFrame" then copy[k] = v
		else copy[k] = deepCopyT(v) end
	end
	return copy
end

local function saveUndo()
	table.insert(undoStack, deepCopyT(tracks))
	if #undoStack > MAX_UNDO then table.remove(undoStack, 1) end
end

local function snapTime(t)
	if snapEnabled then
		return math.floor(t / snapInterval + 0.5) * snapInterval
	end
	return math.floor(t * 100 + 0.5) / 100
end

-- ===================== MAIN LAYOUT =====================
local root = Instance.new("Frame")
root.Size = UDim2.new(1,0,1,0)
root.BackgroundColor3 = C.bg; root.BorderSizePixel = 0
root.Parent = widget

-- ---- Toolbar (top bar) ----
local TB_H = 36
local tbFrame = Instance.new("Frame")
tbFrame.Size = UDim2.new(1,0,0,TB_H)
tbFrame.BackgroundColor3 = C.panel; tbFrame.BorderSizePixel = 0
tbFrame.Parent = root
-- Bottom border
local tbBorder = Instance.new("Frame")
tbBorder.Size = UDim2.new(1,0,0,1); tbBorder.Position = UDim2.new(0,0,1,-1)
tbBorder.BackgroundColor3 = C.sep; tbBorder.BorderSizePixel = 0; tbBorder.Parent = tbFrame

local titleLbl = mkLabel(tbFrame, "Skill Editor Pro", UDim2.new(0,105,1,0), UDim2.new(0,8,0,0), 13)
titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextColor3 = C.accent2

-- Add group
local x = 120
local bAddCam = mkBtn(tbFrame, "+Cam", UDim2.new(0,44,0,24), UDim2.new(0,x,0,6), C.yellow, Color3.fromRGB(30,30,30))
x = x + 47
local bAddAnim = mkBtn(tbFrame, "+Anim", UDim2.new(0,48,0,24), UDim2.new(0,x,0,6), C.green, Color3.fromRGB(30,30,30))
x = x + 51
local bAddVfx = mkBtn(tbFrame, "+VFX", UDim2.new(0,42,0,24), UDim2.new(0,x,0,6), C.purple)
x = x + 45
local bAddSnd = mkBtn(tbFrame, "+Snd", UDim2.new(0,40,0,24), UDim2.new(0,x,0,6), C.cyan, Color3.fromRGB(30,30,30))
x = x + 43
local bAddEvt = mkBtn(tbFrame, "+Evt", UDim2.new(0,40,0,24), UDim2.new(0,x,0,6), C.orange, Color3.fromRGB(30,30,30))
x = x + 43
local bAddHit = mkBtn(tbFrame, "+Hit", UDim2.new(0,40,0,24), UDim2.new(0,x,0,6), C.pink)
x = x + 45

mkSep(tbFrame, UDim2.new(0,x,0,8))
x = x + 6

-- Edit group
local bDel = mkBtn(tbFrame, "Del", UDim2.new(0,34,0,24), UDim2.new(0,x,0,6), C.red)
x = x + 37
local bDup = mkBtn(tbFrame, "Dup", UDim2.new(0,34,0,24), UDim2.new(0,x,0,6))
x = x + 37
local bUndo = mkBtn(tbFrame, "Undo", UDim2.new(0,40,0,24), UDim2.new(0,x,0,6))
x = x + 44

mkSep(tbFrame, UDim2.new(0,x,0,8))
x = x + 6

-- Play group
local bPreview = mkBtn(tbFrame, "Play", UDim2.new(0,40,0,24), UDim2.new(0,x,0,6), C.green, Color3.fromRGB(30,30,30))
x = x + 43
local bStop = mkBtn(tbFrame, "Stop", UDim2.new(0,38,0,24), UDim2.new(0,x,0,6), C.red)
x = x + 42

mkSep(tbFrame, UDim2.new(0,x,0,8))
x = x + 6

-- Export group
local bExport = mkBtn(tbFrame, "Export", UDim2.new(0,48,0,24), UDim2.new(0,x,0,6), C.accent)
x = x + 51
local bImport = mkBtn(tbFrame, "Import", UDim2.new(0,50,0,24), UDim2.new(0,x,0,6))
x = x + 53
local bClear = mkBtn(tbFrame, "Clear", UDim2.new(0,40,0,24), UDim2.new(0,x,0,6), C.red)
x = x + 44

mkSep(tbFrame, UDim2.new(0,x,0,8))
x = x + 6

-- Rig + Name + Snap (right side)
local bRig = mkBtn(tbFrame, "Rig", UDim2.new(0,32,0,24), UDim2.new(0,x,0,6), C.accent)
x = x + 35
local rigLabel = mkLabel(tbFrame, "None", UDim2.new(0,50,0,24), UDim2.new(0,x,0,6), 9)
rigLabel.TextColor3 = C.dim
x = x + 52

local bSnap = mkBtn(tbFrame, "Snap", UDim2.new(0,38,0,24), UDim2.new(0,x,0,6))
x = x + 42

mkLabel(tbFrame, "Name:", UDim2.new(0,32,0,24), UDim2.new(0,x,0,6), 10).TextColor3 = C.text2
x = x + 34
local txtName = mkInput(tbFrame, "MySkill", UDim2.new(0,80,0,22), UDim2.new(0,x,0,7))
x = x + 84

local zoomLbl = mkLabel(tbFrame, "1.0x", UDim2.new(0,35,0,24), UDim2.new(1,-42,0,6), 10)
zoomLbl.TextColor3 = C.dim; zoomLbl.TextXAlignment = Enum.TextXAlignment.Right

-- ---- Status Bar (bottom) ----
local SB_H = 22
local statusBar = Instance.new("Frame")
statusBar.Size = UDim2.new(1,0,0,SB_H); statusBar.Position = UDim2.new(0,0,1,-SB_H)
statusBar.BackgroundColor3 = C.statusBar; statusBar.BorderSizePixel = 0
statusBar.Parent = root
local sbBorder = Instance.new("Frame")
sbBorder.Size = UDim2.new(1,0,0,1); sbBorder.Position = UDim2.new(0,0,0,0)
sbBorder.BackgroundColor3 = C.sep; sbBorder.BorderSizePixel = 0; sbBorder.Parent = statusBar

local statusSelLbl = mkLabel(statusBar, "No selection", UDim2.new(0,200,1,0), UDim2.new(0,8,0,0), 10)
statusSelLbl.TextColor3 = C.dim
local statusTimeLbl = mkLabel(statusBar, "", UDim2.new(0,120,1,0), UDim2.new(0,220,0,0), 10)
statusTimeLbl.TextColor3 = C.dim
local statusFrameLbl = mkLabel(statusBar, string.format("%dfps", FPS), UDim2.new(0,60,1,0), UDim2.new(0,350,0,0), 10)
statusFrameLbl.TextColor3 = C.dim
local statusZoomLbl = mkLabel(statusBar, "Zoom: 1.0x", UDim2.new(0,80,1,0), UDim2.new(1,-90,0,0), 10)
statusZoomLbl.TextColor3 = C.dim; statusZoomLbl.TextXAlignment = Enum.TextXAlignment.Right

-- Content area (between toolbar and status bar)
local content = Instance.new("Frame")
content.Size = UDim2.new(1,0,1,-TB_H-SB_H); content.Position = UDim2.new(0,0,0,TB_H)
content.BackgroundTransparency = 1; content.Parent = root

-- ---- Properties Panel (right) ----
local PROP_W = 230
local propPanel = Instance.new("Frame")
propPanel.Size = UDim2.new(0,PROP_W,1,-4); propPanel.Position = UDim2.new(1,-PROP_W-2,0,2)
propPanel.BackgroundColor3 = C.panel; propPanel.BorderSizePixel = 0
propPanel.ClipsDescendants = true; propPanel.Parent = content; corner(propPanel)
stroke(propPanel, C.sep, 1)

local propHead = Instance.new("Frame")
propHead.Size = UDim2.new(1,0,0,24); propHead.BackgroundColor3 = C.panel2
propHead.BorderSizePixel = 0; propHead.Parent = propPanel
local propHeadLbl = mkLabel(propHead, "  Properties", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), 11)
propHeadLbl.TextColor3 = C.text2; propHeadLbl.Font = Enum.Font.GothamBold

local propScroll = Instance.new("ScrollingFrame")
propScroll.Size = UDim2.new(1,-4,1,-28); propScroll.Position = UDim2.new(0,2,0,26)
propScroll.BackgroundTransparency = 1; propScroll.ScrollBarThickness = 3
propScroll.ScrollBarImageColor3 = C.dim; propScroll.BorderSizePixel = 0
propScroll.CanvasSize = UDim2.new(0,0,0,300); propScroll.Parent = propPanel

local propNone = mkLabel(propScroll, "Select an item to edit", UDim2.new(1,0,0,30), UDim2.new(0,8,0,10), 10)
propNone.TextColor3 = C.dim; propNone.TextXAlignment = Enum.TextXAlignment.Center

-- ---- Timeline Area (left) ----
local LABEL_W = 62
local TRACK_H = 38
local RULER_H = 22

local tlArea = Instance.new("Frame")
tlArea.Size = UDim2.new(1,-PROP_W-8,1,-4); tlArea.Position = UDim2.new(0,2,0,2)
tlArea.BackgroundColor3 = C.tlBg; tlArea.BorderSizePixel = 0
tlArea.ClipsDescendants = true; tlArea.Parent = content; corner(propPanel)
stroke(tlArea, C.sep, 1)

-- Time ruler header
local timeHeader = Instance.new("Frame")
timeHeader.Size = UDim2.new(1,0,0,RULER_H); timeHeader.BackgroundColor3 = C.panel2
timeHeader.BorderSizePixel = 0; timeHeader.ClipsDescendants = true; timeHeader.Parent = tlArea
local rulerBorder = Instance.new("Frame")
rulerBorder.Size = UDim2.new(1,0,0,1); rulerBorder.Position = UDim2.new(0,0,1,-1)
rulerBorder.BackgroundColor3 = C.sep; rulerBorder.BorderSizePixel = 0; rulerBorder.Parent = timeHeader

-- Ruler tick marks (dynamically created in refreshUI)
local rulerTicks = {}

-- Playhead
local playheadLine = Instance.new("Frame")
playheadLine.Size = UDim2.new(0,2,0,TRACK_H*6+RULER_H+4)
playheadLine.AnchorPoint = Vector2.new(0.5,0)
playheadLine.Position = UDim2.new(0,LABEL_W,0,0)
playheadLine.BackgroundColor3 = C.playhead; playheadLine.BorderSizePixel = 0
playheadLine.ZIndex = 15; playheadLine.Visible = false; playheadLine.Parent = tlArea
-- Playhead triangle
local phTriangle = Instance.new("Frame")
phTriangle.Size = UDim2.new(0,10,0,8); phTriangle.AnchorPoint = Vector2.new(0.5,0)
phTriangle.Position = UDim2.new(0.5,0,0,0)
phTriangle.BackgroundColor3 = C.playhead; phTriangle.BorderSizePixel = 0
phTriangle.ZIndex = 16; phTriangle.Parent = playheadLine; corner(phTriangle, 2)

-- Grid lines container
local gridContainer = Instance.new("Frame")
gridContainer.Size = UDim2.new(1,-LABEL_W,0,TRACK_H*6)
gridContainer.Position = UDim2.new(0,LABEL_W,0,RULER_H)
gridContainer.BackgroundTransparency = 1; gridContainer.ClipsDescendants = true
gridContainer.ZIndex = 1; gridContainer.Parent = tlArea
local gridLines = {}

-- Track lanes
local trackLanes = {}
for i, trackName in ipairs(TRACK_NAMES) do
	local y = RULER_H + (i-1) * TRACK_H

	-- Label panel
	local lbl = Instance.new("Frame")
	lbl.Size = UDim2.new(0,LABEL_W,0,TRACK_H); lbl.Position = UDim2.new(0,0,0,y)
	lbl.BackgroundColor3 = C.panel; lbl.BorderSizePixel = 0; lbl.Parent = tlArea

	local colorBar = Instance.new("Frame")
	colorBar.Size = UDim2.new(0,3,0,TRACK_H-8); colorBar.Position = UDim2.new(0,2,0,4)
	colorBar.BackgroundColor3 = TRACK_COLORS[i]; colorBar.BorderSizePixel = 0
	colorBar.Parent = lbl; corner(colorBar, 1)

	local tl = mkLabel(lbl, TRACK_LABELS[i], UDim2.new(1,-10,1,0), UDim2.new(0,8,0,0), 10)
	tl.Font = Enum.Font.GothamBold; tl.TextColor3 = C.text2

	-- Lane
	local lane = Instance.new("Frame")
	lane.Name = trackName
	lane.Size = UDim2.new(1,-LABEL_W-2,0,TRACK_H)
	lane.Position = UDim2.new(0,LABEL_W+1,0,y)
	lane.BackgroundColor3 = (i%2==0) and C.trackAlt or C.trackBg
	lane.BorderSizePixel = 0; lane.ClipsDescendants = true; lane.Parent = tlArea

	-- Subtle center line
	local centerLine = Instance.new("Frame")
	centerLine.Size = UDim2.new(1,-4,0,1); centerLine.Position = UDim2.new(0,2,0.5,0)
	centerLine.BackgroundColor3 = C.gridLine; centerLine.BackgroundTransparency = 0.5
	centerLine.BorderSizePixel = 0; centerLine.ZIndex = 1; centerLine.Parent = lane

	-- Bottom border
	local laneBorder = Instance.new("Frame")
	laneBorder.Size = UDim2.new(1,0,0,1); laneBorder.Position = UDim2.new(0,0,1,-1)
	laneBorder.BackgroundColor3 = C.sep; laneBorder.BackgroundTransparency = 0.6
	laneBorder.BorderSizePixel = 0; laneBorder.Parent = lane

	trackLanes[trackName] = lane
end

-- ===================== CONTEXT MENU =====================
local ctxMenu = Instance.new("Frame")
ctxMenu.Size = UDim2.new(0,130,0,120)
ctxMenu.BackgroundColor3 = Color3.fromRGB(42,42,54)
ctxMenu.BorderSizePixel = 0; ctxMenu.ZIndex = 20
ctxMenu.Visible = false; ctxMenu.Parent = root; corner(ctxMenu, 6)
stroke(ctxMenu, Color3.fromRGB(70,70,88), 1)
-- Shadow
local ctxShadow = Instance.new("ImageLabel")
ctxShadow.Size = UDim2.new(1,12,1,12); ctxShadow.Position = UDim2.new(0,-6,0,-6)
ctxShadow.BackgroundTransparency = 1; ctxShadow.ImageTransparency = 0.5
ctxShadow.ImageColor3 = Color3.new(0,0,0); ctxShadow.ZIndex = 19
ctxShadow.ScaleType = Enum.ScaleType.Slice; ctxShadow.Parent = ctxMenu

local ctxItems = {"Delete", "Duplicate", "Copy", "Paste"}
local ctxShortcuts = {"Del", "Ctrl+D", "Ctrl+C", "Ctrl+V"}
local ctxBtns = {}
for ci, label in ipairs(ctxItems) do
	local cb = Instance.new("TextButton")
	cb.Size = UDim2.new(1,-4,0,28)
	cb.Position = UDim2.new(0,2,0,2+(ci-1)*28)
	cb.BackgroundColor3 = Color3.fromRGB(42,42,54)
	cb.TextColor3 = C.text; cb.Text = "  " .. label
	cb.Font = Enum.Font.Gotham; cb.TextSize = 11
	cb.TextXAlignment = Enum.TextXAlignment.Left
	cb.BorderSizePixel = 0; cb.ZIndex = 21
	cb.AutoButtonColor = false; cb.Parent = ctxMenu; corner(cb, 4)
	-- Shortcut label
	local scLbl = Instance.new("TextLabel")
	scLbl.Size = UDim2.new(0,50,1,0); scLbl.Position = UDim2.new(1,-54,0,0)
	scLbl.BackgroundTransparency = 1; scLbl.TextColor3 = C.dim
	scLbl.Text = ctxShortcuts[ci]; scLbl.Font = Enum.Font.Gotham; scLbl.TextSize = 9
	scLbl.TextXAlignment = Enum.TextXAlignment.Right; scLbl.ZIndex = 22; scLbl.Parent = cb
	cb.MouseEnter:Connect(function() cb.BackgroundColor3 = Color3.fromRGB(58,58,75) end)
	cb.MouseLeave:Connect(function() cb.BackgroundColor3 = Color3.fromRGB(42,42,54) end)
	ctxBtns[label] = cb
end
local function showCtxMenu(mx, my)
	ctxMenu.Position = UDim2.new(0, mx, 0, my)
	ctxMenu.Visible = true
	ctxBtns["Paste"].TextColor3 = clipboard and C.text or C.dim
end
local function hideCtxMenu() ctxMenu.Visible = false end
root.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then hideCtxMenu() end
end)

-- ===================== PROPERTY GROUPS =====================
local ROW = 22 -- row height for property fields
local LBL_W = 60
local INP_W = 115
local INP_X = LBL_W + 5
local BTN_W = 180

local function propRow(parent, label, yOff)
	mkLabel(parent, label, UDim2.new(0,LBL_W,0,ROW-2), UDim2.new(0,5,0,yOff), 10).TextColor3 = C.text2
end

-- ---- Camera ----
local camGrp = Instance.new("Frame")
camGrp.Size = UDim2.new(1,0,0,180); camGrp.BackgroundTransparency = 1
camGrp.Visible = false; camGrp.Parent = propScroll
mkSectionHead(camGrp, "Camera Keyframe", TRACK_COLORS[1], UDim2.new(0,3,0,0))

local y = 26
propRow(camGrp, "Time(s):", y)
local cpTimeIn = mkInput(camGrp, "0", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(camGrp, "FOV:", y)
local cpFovIn = mkInput(camGrp, "70", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(camGrp, "Easing:", y)
local cpEaseBtn = mkBtn(camGrp, "Sine", UDim2.new(0,INP_W,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(camGrp, "Dir:", y)
local cpDirBtn = mkBtn(camGrp, "InOut", UDim2.new(0,INP_W,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW + 6
local cpSetCam = mkBtn(camGrp, "Set From Camera", UDim2.new(0,BTN_W,0,22), UDim2.new(0,5,0,y), C.accent)
y = y + 26
local cpGoTo = mkBtn(camGrp, "Go to Keyframe", UDim2.new(0,BTN_W,0,22), UDim2.new(0,5,0,y))

-- ---- Animation ----
local animGrp = Instance.new("Frame")
animGrp.Size = UDim2.new(1,0,0,270); animGrp.BackgroundTransparency = 1
animGrp.Visible = false; animGrp.Parent = propScroll
mkSectionHead(animGrp, "Animation Clip", TRACK_COLORS[2], UDim2.new(0,3,0,0))

y = 26
propRow(animGrp, "Name:", y)
local apNameIn = mkInput(animGrp, "Attack", UDim2.new(0,INP_W,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(animGrp, "Start(s):", y)
local apTimeIn = mkInput(animGrp, "0", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(animGrp, "Dur(s):", y)
local apDurIn = mkInput(animGrp, "1.0", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(animGrp, "AnimID:", y)
local apAnimIdIn = mkInput(animGrp, "rbxassetid://0", UDim2.new(0,INP_W,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(animGrp, "Speed:", y)
local apSpeedIn = mkInput(animGrp, "1.0", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW + 4

-- Cancel system section
mkSectionHead(animGrp, "Cancel System", C.castMark, UDim2.new(0,3,0,y))
y = y + 24
propRow(animGrp, "CastPt:", y)
local apCastIn = mkInput(animGrp, "0.3", UDim2.new(0,50,0,18), UDim2.new(0,INP_X,0,y))
local apCastHelp = mkLabel(animGrp, "dmg fires", UDim2.new(0,65,0,14), UDim2.new(0,INP_X+55,0,y+2), 9)
apCastHelp.TextColor3 = C.castMark
y = y + ROW
propRow(animGrp, "CancelPt:", y)
local apCancelIn = mkInput(animGrp, "0.7", UDim2.new(0,50,0,18), UDim2.new(0,INP_X,0,y))
local apCancelHelp = mkLabel(animGrp, "can act", UDim2.new(0,55,0,14), UDim2.new(0,INP_X+55,0,y+2), 9)
apCancelHelp.TextColor3 = C.cancelMark
y = y + ROW + 2
local apInterrupt = mkBtn(animGrp, "[ ] Can Interrupt", UDim2.new(0,BTN_W,0,22), UDim2.new(0,5,0,y))
y = y + 26
local apLegend = mkLabel(animGrp, "|pre-cast| cast |post-cast|", UDim2.new(1,-10,0,14), UDim2.new(0,5,0,y), 9)
apLegend.TextColor3 = C.dim; apLegend.TextXAlignment = Enum.TextXAlignment.Center

-- ---- VFX ----
local vfxGrp = Instance.new("Frame")
vfxGrp.Size = UDim2.new(1,0,0,175); vfxGrp.BackgroundTransparency = 1
vfxGrp.Visible = false; vfxGrp.Parent = propScroll
mkSectionHead(vfxGrp, "Visual Effect", TRACK_COLORS[3], UDim2.new(0,3,0,0))

y = 26
propRow(vfxGrp, "Time(s):", y)
local vpTimeIn = mkInput(vfxGrp, "0", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(vfxGrp, "Type:", y)
local vpTypeBtn = mkBtn(vfxGrp, "flash", UDim2.new(0,INP_W,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(vfxGrp, "Power:", y)
local vpIntIn = mkInput(vfxGrp, "1.0", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(vfxGrp, "Dur(s):", y)
local vpDurIn = mkInput(vfxGrp, "0.3", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(vfxGrp, "Asset:", y)
local vpAssetLbl = mkLabel(vfxGrp, "(none)", UDim2.new(0,INP_W,0,18), UDim2.new(0,INP_X,0,y), 9)
vpAssetLbl.TextColor3 = C.dim
y = y + ROW + 4
local vpAssetBtn = mkBtn(vfxGrp, "Set From Selection", UDim2.new(0,BTN_W,0,22), UDim2.new(0,5,0,y), C.accent)

-- ---- Sound ----
local sndGrp = Instance.new("Frame")
sndGrp.Size = UDim2.new(1,0,0,170); sndGrp.BackgroundTransparency = 1
sndGrp.Visible = false; sndGrp.Parent = propScroll
mkSectionHead(sndGrp, "Sound Trigger", TRACK_COLORS[4], UDim2.new(0,3,0,0))

y = 26
propRow(sndGrp, "Time(s):", y)
local spTimeIn = mkInput(sndGrp, "0", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(sndGrp, "Name:", y)
local spNameIn = mkInput(sndGrp, "Hit", UDim2.new(0,INP_W,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(sndGrp, "SoundID:", y)
local spIdIn = mkInput(sndGrp, "rbxassetid://0", UDim2.new(0,INP_W,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(sndGrp, "Volume:", y)
local spVolIn = mkInput(sndGrp, "1.0", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(sndGrp, "Pitch:", y)
local spPitchIn = mkInput(sndGrp, "1.0", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(sndGrp, "Asset:", y)
local spAssetLbl = mkLabel(sndGrp, "(none)", UDim2.new(0,INP_W,0,18), UDim2.new(0,INP_X,0,y), 9)
spAssetLbl.TextColor3 = C.dim

-- ---- Event ----
local eventGrp = Instance.new("Frame")
eventGrp.Size = UDim2.new(1,0,0,160); eventGrp.BackgroundTransparency = 1
eventGrp.Visible = false; eventGrp.Parent = propScroll
mkSectionHead(eventGrp, "Event Trigger", TRACK_COLORS[5], UDim2.new(0,3,0,0))

y = 26
propRow(eventGrp, "Time(s):", y)
local epTimeIn = mkInput(eventGrp, "0", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(eventGrp, "Type:", y)
local epTypeBtn = mkBtn(eventGrp, "damage", UDim2.new(0,INP_W,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(eventGrp, "Name:", y)
local epNameIn = mkInput(eventGrp, "Event", UDim2.new(0,INP_W,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(eventGrp, "Value:", y)
local epValueIn = mkInput(eventGrp, "100", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(eventGrp, "Params:", y)
local epParamsIn = mkInput(eventGrp, "", UDim2.new(0,INP_W,0,18), UDim2.new(0,INP_X,0,y))
local epParamsHint = mkLabel(eventGrp, "key=val,key=val", UDim2.new(0,INP_W,0,12), UDim2.new(0,INP_X,0,y+19), 8)
epParamsHint.TextColor3 = C.dim

-- ---- Hitbox ----
local hitboxGrp = Instance.new("Frame")
hitboxGrp.Size = UDim2.new(1,0,0,220); hitboxGrp.BackgroundTransparency = 1
hitboxGrp.Visible = false; hitboxGrp.Parent = propScroll
mkSectionHead(hitboxGrp, "Hitbox Region", TRACK_COLORS[6], UDim2.new(0,3,0,0))

y = 26
propRow(hitboxGrp, "Time(s):", y)
local hpTimeIn = mkInput(hitboxGrp, "0", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(hitboxGrp, "Dur(s):", y)
local hpDurIn = mkInput(hitboxGrp, "0.3", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(hitboxGrp, "Shape:", y)
local hpShapeBtn = mkBtn(hitboxGrp, "circle", UDim2.new(0,INP_W,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(hitboxGrp, "Radius:", y)
local hpRadiusIn = mkInput(hitboxGrp, "5", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(hitboxGrp, "Width:", y)
local hpWidthIn = mkInput(hitboxGrp, "6", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(hitboxGrp, "Height:", y)
local hpHeightIn = mkInput(hitboxGrp, "4", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))
y = y + ROW
propRow(hitboxGrp, "Offset:", y)
local hpOffsetIn = mkInput(hitboxGrp, "0,0,5", UDim2.new(0,INP_W,0,18), UDim2.new(0,INP_X,0,y))
local hpOffHint = mkLabel(hitboxGrp, "x,y,z relative", UDim2.new(0,INP_W,0,12), UDim2.new(0,INP_X,0,y+19), 8)
hpOffHint.TextColor3 = C.dim
y = y + ROW + 16
local hpDmgLbl = mkLabel(hitboxGrp, "Damage:", UDim2.new(0,LBL_W,0,18), UDim2.new(0,5,0,y), 10)
hpDmgLbl.TextColor3 = C.text2
local hpDamageIn = mkInput(hitboxGrp, "100", UDim2.new(0,60,0,18), UDim2.new(0,INP_X,0,y))

-- ===================== CORE FUNCTIONS =====================
local allDots = {}
local refreshUI

local function updateStatus()
	if selection.track and selection.index >= 1 then
		local list = tracks[selection.track]
		if selection.index <= #list then
			local item = list[selection.index]
			local trackLabel = TRACK_LABELS[table.find(TRACK_NAMES, selection.track) or 1]
			statusSelLbl.Text = string.format("%s #%d", trackLabel, selection.index)
			statusSelLbl.TextColor3 = C.text2
			local frame = math.floor(item.time * FPS)
			statusTimeLbl.Text = string.format("T: %.2fs  F: %d", item.time, frame)
		else
			statusSelLbl.Text = "No selection"; statusSelLbl.TextColor3 = C.dim
			statusTimeLbl.Text = ""
		end
	else
		statusSelLbl.Text = "No selection"; statusSelLbl.TextColor3 = C.dim
		statusTimeLbl.Text = ""
	end
	statusZoomLbl.Text = string.format("Zoom: %.1fx", zoomLevel)
end

local function getTotalDur()
	local maxT = 5
	for _, list in pairs(tracks) do
		for _, item in ipairs(list) do
			local endT = item.time + (item.duration or 0)
			if endT > maxT then maxT = endT end
		end
	end
	return maxT + 1
end

local function hideAllProps()
	propNone.Visible = false
	camGrp.Visible = false
	animGrp.Visible = false
	vfxGrp.Visible = false
	sndGrp.Visible = false
	eventGrp.Visible = false
	hitboxGrp.Visible = false
end

local function updateProps()
	hideAllProps()
	local trk = selection.track
	local idx = selection.index
	if not trk or idx < 1 then propNone.Visible = true; updateStatus(); return end
	local list = tracks[trk]
	if idx > #list then propNone.Visible = true; updateStatus(); return end
	local item = list[idx]

	if trk == "camera" then
		camGrp.Visible = true
		cpTimeIn.Text = string.format("%.2f", item.time)
		cpFovIn.Text = tostring(math.floor(item.fov))
		cpEaseBtn.Text = item.easingStyle
		cpDirBtn.Text = item.easingDir
	elseif trk == "animation" then
		animGrp.Visible = true
		apNameIn.Text = item.name or "Anim"
		apTimeIn.Text = string.format("%.2f", item.time)
		apDurIn.Text = string.format("%.2f", item.duration)
		apAnimIdIn.Text = item.animId or "rbxassetid://0"
		apSpeedIn.Text = string.format("%.1f", item.speed)
		apCastIn.Text = string.format("%.2f", item.castPoint)
		apCancelIn.Text = string.format("%.2f", item.cancelPoint)
		apInterrupt.Text = item.canInterrupt and "[X] Can Interrupt" or "[ ] Can Interrupt"
	elseif trk == "vfx" then
		vfxGrp.Visible = true
		vpTimeIn.Text = string.format("%.2f", item.time)
		vpTypeBtn.Text = item.vfxType
		vpIntIn.Text = string.format("%.1f", item.intensity)
		vpDurIn.Text = string.format("%.2f", item.duration)
		vpAssetLbl.Text = item.assetPath or "(none)"
	elseif trk == "sound" then
		sndGrp.Visible = true
		spTimeIn.Text = string.format("%.2f", item.time)
		spNameIn.Text = item.name or "Sound"
		spIdIn.Text = item.soundId or "rbxassetid://0"
		spVolIn.Text = string.format("%.1f", item.volume)
		spPitchIn.Text = string.format("%.1f", item.pitch)
		spAssetLbl.Text = item.assetPath or "(none)"
	elseif trk == "event" then
		eventGrp.Visible = true
		epTimeIn.Text = string.format("%.2f", item.time)
		epTypeBtn.Text = item.eventType or "damage"
		epNameIn.Text = item.name or "Event"
		epValueIn.Text = tostring(item.value or 100)
		epParamsIn.Text = item.params or ""
	elseif trk == "hitbox" then
		hitboxGrp.Visible = true
		hpTimeIn.Text = string.format("%.2f", item.time)
		hpDurIn.Text = string.format("%.2f", item.duration or 0.3)
		hpShapeBtn.Text = item.shape or "circle"
		hpRadiusIn.Text = tostring(item.radius or 5)
		hpWidthIn.Text = tostring(item.width or 6)
		hpHeightIn.Text = tostring(item.height or 4)
		local off = item.offset or {0,0,5}
		hpOffsetIn.Text = string.format("%s,%s,%s", tostring(off[1]), tostring(off[2]), tostring(off[3]))
		hpDamageIn.Text = tostring(item.damage or 100)
	end
	updateStatus()
end

local function selectItem(track, idx)
	selection.track = track; selection.index = idx
	if track == "camera" and idx >= 1 and idx <= #tracks.camera then
		workspace.CurrentCamera.CFrame = tracks.camera[idx].cframe
		workspace.CurrentCamera.FieldOfView = tracks.camera[idx].fov
	end
	updateProps(); refreshUI()
end

local function addToTrack(trackName, item)
	saveUndo()
	table.insert(tracks[trackName], item)
	table.sort(tracks[trackName], function(a,b) return a.time < b.time end)
	for i,k in ipairs(tracks[trackName]) do
		if k == item then selection.track = trackName; selection.index = i; break end
	end
	updateProps(); refreshUI()
end

local function deleteSelected()
	if not selection.track or selection.index < 1 then return end
	local list = tracks[selection.track]
	if selection.index > #list then return end
	saveUndo()
	table.remove(list, selection.index)
	if selection.index > #list then selection.index = #list end
	if #list == 0 then selection.track = nil; selection.index = 0 end
	updateProps(); refreshUI()
end

local function clearAllTracks()
	saveUndo()
	for k in pairs(tracks) do tracks[k] = {} end
	selection.track = nil; selection.index = 0
	updateProps(); refreshUI()
end

local function undo()
	if #undoStack == 0 then return end
	tracks = table.remove(undoStack)
	selection.track = nil; selection.index = 0
	updateProps(); refreshUI()
end

local function duplicateSelected()
	if not selection.track or selection.index < 1 then return end
	local list = tracks[selection.track]
	if selection.index > #list then return end
	local item = deepCopyT(list[selection.index])
	item.time = item.time + 0.5
	addToTrack(selection.track, item)
end

-- ===================== REFRESH UI =====================
local function renderRuler(totalDur)
	for _, t in ipairs(rulerTicks) do if t.Parent then t:Destroy() end end
	rulerTicks = {}
	local laneRef = trackLanes.camera
	local laneW = laneRef.AbsoluteSize.X
	if laneW <= 0 then laneW = 600 end

	-- Determine tick interval based on zoom
	local majorInterval = 1.0
	if zoomLevel >= 3 then majorInterval = 0.5
	elseif zoomLevel <= 0.7 then majorInterval = 2.0 end
	local minorInterval = majorInterval / 5

	for t = 0, totalDur, minorInterval do
		local frac = (t / totalDur) * zoomLevel
		if frac > 1.2 then break end
		local isMajor = math.abs(t % majorInterval) < 0.001 or math.abs(t % majorInterval - majorInterval) < 0.001
		local xPos = LABEL_W + 1 + frac * (laneW)

		-- Tick mark on ruler
		local tick = Instance.new("Frame")
		tick.Size = UDim2.new(0, 1, 0, isMajor and 10 or 5)
		tick.Position = UDim2.new(0, xPos, 1, isMajor and -12 or -6)
		tick.BackgroundColor3 = isMajor and C.text2 or C.dim
		tick.BackgroundTransparency = isMajor and 0.3 or 0.6
		tick.BorderSizePixel = 0; tick.Parent = timeHeader
		table.insert(rulerTicks, tick)

		if isMajor then
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(0,30,0,10)
			lbl.Position = UDim2.new(0, xPos - 15, 0, 1)
			lbl.BackgroundTransparency = 1; lbl.TextColor3 = C.dim
			lbl.Text = string.format("%.1fs", t)
			lbl.Font = Enum.Font.Gotham; lbl.TextSize = 8
			lbl.Parent = timeHeader
			table.insert(rulerTicks, lbl)
		end
	end
end

local function renderGridLines(totalDur)
	for _, g in ipairs(gridLines) do if g.Parent then g:Destroy() end end
	gridLines = {}
	local laneRef = trackLanes.camera
	local laneW = laneRef.AbsoluteSize.X
	if laneW <= 0 then laneW = 600 end

	local interval = 0.5
	if zoomLevel >= 3 then interval = 0.25
	elseif zoomLevel <= 0.7 then interval = 1.0 end

	for t = interval, totalDur, interval do
		local frac = (t / totalDur) * zoomLevel
		if frac > 1.2 then break end
		local isMaj = math.abs(t % 1.0) < 0.001 or math.abs(t % 1.0 - 1.0) < 0.001
		local line = Instance.new("Frame")
		line.Size = UDim2.new(0, 1, 1, 0)
		line.Position = UDim2.new(frac, 0, 0, 0)
		line.BackgroundColor3 = isMaj and C.gridMaj or C.gridLine
		line.BackgroundTransparency = isMaj and 0.5 or 0.7
		line.BorderSizePixel = 0; line.ZIndex = 1; line.Parent = gridContainer
		table.insert(gridLines, line)
	end
end

refreshUI = function()
	for _, info in ipairs(allDots) do
		if info.frame and info.frame.Parent then info.frame:Destroy() end
	end
	allDots = {}

	local totalDur = getTotalDur()

	-- Render ruler and grid
	renderRuler(totalDur)
	renderGridLines(totalDur)

	for trkIdx, trackName in ipairs(TRACK_NAMES) do
		local lane = trackLanes[trackName]
		local list = tracks[trackName]
		local trkColor = TRACK_COLORS[trkIdx]

		for i, item in ipairs(list) do
			local isSel = (selection.track == trackName and selection.index == i)
			local frac = (item.time / totalDur) * zoomLevel
			local capturedIdx = i
			local baseColor = isSel and C.sel or trkColor

			if trackName == "animation" or trackName == "hitbox" then
				-- Bar element
				local dur = item.duration or (trackName == "hitbox" and 0.3 or 1)
				local durFrac = (dur / totalDur) * zoomLevel
				local bar = Instance.new("Frame")
				bar.Size = UDim2.new(durFrac, 0, 0, 26)
				bar.AnchorPoint = Vector2.new(0, 0.5)
				bar.Position = UDim2.new(frac, 0, 0.5, 0)
				bar.BackgroundColor3 = baseColor
				bar.BackgroundTransparency = 0.25
				bar.BorderSizePixel = 0; bar.ZIndex = 3
				bar.Parent = lane; corner(bar, 4)
				if isSel then stroke(bar, C.sel, 1) end

				if trackName == "animation" then
					-- Cast point marker (yellow)
					if item.castPoint and item.duration > 0 then
						local cf = math.clamp(item.castPoint / item.duration, 0, 1)
						local mark = Instance.new("Frame")
						mark.Size = UDim2.new(0,2,1,4); mark.Position = UDim2.new(cf,-1,0,-2)
						mark.BackgroundColor3 = C.castMark; mark.BorderSizePixel = 0
						mark.ZIndex = 4; mark.Parent = bar
					end
					-- Cancel point marker
					if item.cancelPoint and item.duration > 0 then
						local cf = math.clamp(item.cancelPoint / item.duration, 0, 1)
						local mark = Instance.new("Frame")
						mark.Size = UDim2.new(0,2,1,4); mark.Position = UDim2.new(cf,-1,0,-2)
						mark.BackgroundColor3 = C.cancelMark; mark.BorderSizePixel = 0
						mark.ZIndex = 4; mark.Parent = bar
					end
				end

				-- Name label inside bar
				local labelText = ""
				if trackName == "animation" then
					labelText = item.name or "Anim"
				else
					labelText = (item.shape or "circle")
				end
				local nLbl = Instance.new("TextLabel")
				nLbl.Size = UDim2.new(1,-6,1,0); nLbl.Position = UDim2.new(0,3,0,0)
				nLbl.BackgroundTransparency = 1; nLbl.TextColor3 = Color3.new(1,1,1)
				nLbl.Text = labelText; nLbl.Font = Enum.Font.GothamBold
				nLbl.TextSize = 9; nLbl.TextXAlignment = Enum.TextXAlignment.Left
				nLbl.TextTruncate = Enum.TextTruncate.AtEnd
				nLbl.ZIndex = 5; nLbl.Parent = bar

				local clickBtn = Instance.new("TextButton")
				clickBtn.Size = UDim2.new(1,0,1,0); clickBtn.BackgroundTransparency = 1
				clickBtn.Text = ""; clickBtn.ZIndex = 6; clickBtn.Parent = bar
				clickBtn.MouseButton1Down:Connect(function()
					selectItem(trackName, capturedIdx)
					dragPending = true; dragNeedStart = true
					draggingTrack = trackName; draggingIdx = capturedIdx
				end)
				clickBtn.MouseButton2Click:Connect(function()
					selectItem(trackName, capturedIdx)
					local mp = widget:GetRelativeMousePosition()
					showCtxMenu(mp.X, mp.Y)
				end)

				table.insert(allDots, {track = trackName, idx = i, frame = bar})
			else
				-- Dot element (camera, vfx, sound, event)
				local dotSize = 14
				local dot = Instance.new("Frame")
				dot.Size = UDim2.new(0,dotSize,0,dotSize)
				dot.AnchorPoint = Vector2.new(0.5,0.5)
				dot.Position = UDim2.new(frac,0,0.5,0)
				dot.BackgroundColor3 = baseColor
				dot.BorderSizePixel = 0; dot.ZIndex = 3
				dot.Parent = lane; corner(dot, dotSize/2)
				if isSel then
					stroke(dot, C.sel, 2)
				end

				-- Label above dot
				local topText = tostring(i)
				if trackName == "event" then
					topText = (item.eventType or "evt"):sub(1,3)
				end
				local idxLbl = Instance.new("TextLabel")
				idxLbl.Size = UDim2.new(0,24,0,10)
				idxLbl.AnchorPoint = Vector2.new(0.5,1)
				idxLbl.Position = UDim2.new(0.5,0,0,-2)
				idxLbl.BackgroundTransparency = 1
				idxLbl.TextColor3 = isSel and C.sel or C.dim
				idxLbl.Text = topText; idxLbl.Font = Enum.Font.GothamBold
				idxLbl.TextSize = 8; idxLbl.Parent = dot

				local clickBtn = Instance.new("TextButton")
				clickBtn.Size = UDim2.new(0,22,0,28)
				clickBtn.AnchorPoint = Vector2.new(0.5,0.5)
				clickBtn.Position = UDim2.new(0.5,0,0.5,0)
				clickBtn.BackgroundTransparency = 1; clickBtn.Text = ""
				clickBtn.ZIndex = 4; clickBtn.Parent = dot
				clickBtn.MouseButton1Down:Connect(function()
					selectItem(trackName, capturedIdx)
					dragPending = true; dragNeedStart = true
					draggingTrack = trackName; draggingIdx = capturedIdx
				end)
				clickBtn.MouseButton2Click:Connect(function()
					selectItem(trackName, capturedIdx)
					local mp = widget:GetRelativeMousePosition()
					showCtxMenu(mp.X, mp.Y)
				end)

				table.insert(allDots, {track = trackName, idx = i, frame = dot})
			end
		end
	end
	updateStatus()
end

-- ===================== TIMELINE DRAG =====================
local function finishDrag()
	local wasDragging = dragging
	dragPending = false; dragNeedStart = false; dragging = false
	if wasDragging and draggingTrack and draggingIdx then
		local list = tracks[draggingTrack]
		if draggingIdx >= 1 and draggingIdx <= #list then
			local draggedItem = list[draggingIdx]
			table.sort(list, function(a,b) return a.time < b.time end)
			for i,k in ipairs(list) do
				if k == draggedItem then selection.index = i; break end
			end
			updateProps(); refreshUI()
		end
	end
	draggingTrack = nil; draggingIdx = nil
end

for _, trackName in ipairs(TRACK_NAMES) do
	local lane = trackLanes[trackName]
	lane.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

		-- Check if mouse button was released (fallback for InputEnded not firing)
		if (dragPending or dragging) and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			finishDrag()
			return
		end

		-- Capture start position on first move, then check threshold
		if dragPending and not dragging then
			if dragNeedStart then
				dragStartX = input.Position.X
				dragNeedStart = false
				return
			end
			if math.abs(input.Position.X - dragStartX) >= DRAG_THRESHOLD then
				dragging = true; dragPending = false
			else
				return
			end
		end
		if not dragging or not draggingTrack then return end
		local absX = lane.AbsolutePosition.X
		local absW = lane.AbsoluteSize.X
		if absW <= 0 then return end
		local frac = math.clamp((input.Position.X - absX) / absW, 0, 1)
		local totalDur = getTotalDur()
		local newTime = snapTime(frac * totalDur / zoomLevel)
		local list = tracks[draggingTrack]
		if draggingIdx >= 1 and draggingIdx <= #list then
			list[draggingIdx].time = math.max(0, newTime)
			for _, info in ipairs(allDots) do
				if info.track == draggingTrack and info.idx == draggingIdx and info.frame then
					info.frame.Position = UDim2.new(frac, 0, info.frame.Position.Y.Scale, info.frame.Position.Y.Offset)
				end
			end
			updateProps()
		end
	end)
end

-- Backup: also listen for InputEnded
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		finishDrag()
	end
end)

-- ===================== ADD FUNCTIONS =====================
local function addCameraKF()
	local cam = workspace.CurrentCamera
	local t = 0
	if #tracks.camera > 0 then t = tracks.camera[#tracks.camera].time + 0.5 end
	addToTrack("camera", {
		time = t, cframe = cam.CFrame, fov = cam.FieldOfView,
		easingStyle = "Sine", easingDir = "InOut",
	})
end

local function addAnimation()
	local t = 0
	if #tracks.animation > 0 then
		local last = tracks.animation[#tracks.animation]
		t = last.time + (last.duration or 1)
	end
	addToTrack("animation", {
		time = t, duration = 1.0, animId = "rbxassetid://0",
		speed = 1.0, castPoint = 0.3, cancelPoint = 0.7,
		canInterrupt = true, name = "Anim",
	})
end

-- Helper: get full path of an instance
local function getFullPath(inst)
	local parts = {}
	local current = inst
	while current and current ~= game do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return "game." .. table.concat(parts, ".")
end

-- Helper: check if instance is a VFX type
local VFX_CLASSES = {"ParticleEmitter","Beam","Trail","Fire","Smoke","Sparkles","PointLight","SpotLight","SurfaceLight"}
local function isVFXAsset(inst)
	for _, cls in ipairs(VFX_CLASSES) do
		if inst:IsA(cls) then return true end
	end
	-- Also accept Models/Folders containing VFX
	if inst:IsA("Model") or inst:IsA("Folder") or inst:IsA("Part") then
		for _, desc in ipairs(inst:GetDescendants()) do
			for _, cls in ipairs(VFX_CLASSES) do
				if desc:IsA(cls) then return true end
			end
		end
	end
	return false
end

local function addVFX(fromAsset)
	local t = 0
	if #tracks.vfx > 0 then t = tracks.vfx[#tracks.vfx].time + 0.3 end

	local item = {
		time = t, vfxType = "flash", intensity = 1.0, duration = 0.3,
		assetPath = nil, assetName = nil,
	}

	-- Check selection for VFX asset
	if fromAsset then
		item.vfxType = "asset"
		item.assetPath = getFullPath(fromAsset)
		item.assetName = fromAsset.Name
	elseif not fromAsset then
		local sel = Selection:Get()
		if #sel > 0 and isVFXAsset(sel[1]) then
			item.vfxType = "asset"
			item.assetPath = getFullPath(sel[1])
			item.assetName = sel[1].Name
		end
	end

	addToTrack("vfx", item)
end

local function addSound(fromAsset)
	local t = 0
	if #tracks.sound > 0 then t = tracks.sound[#tracks.sound].time + 0.5 end

	local item = {
		time = t, soundId = "rbxassetid://0", volume = 1.0, pitch = 1.0,
		name = "Sound", assetPath = nil,
	}

	-- Check selection for Sound asset
	if fromAsset and fromAsset:IsA("Sound") then
		item.soundId = fromAsset.SoundId
		item.volume = fromAsset.Volume
		item.pitch = fromAsset.PlaybackSpeed
		item.name = fromAsset.Name
		item.assetPath = getFullPath(fromAsset)
	elseif not fromAsset then
		local sel = Selection:Get()
		if #sel > 0 and sel[1]:IsA("Sound") then
			local snd = sel[1]
			item.soundId = snd.SoundId
			item.volume = snd.Volume
			item.pitch = snd.PlaybackSpeed
			item.name = snd.Name
			item.assetPath = getFullPath(snd)
		end
	end

	addToTrack("sound", item)
end

local function addEvent()
	local t = 0
	if #tracks.event > 0 then t = tracks.event[#tracks.event].time + 0.3 end
	addToTrack("event", {
		time = t, eventType = "damage", name = "Event",
		value = 100, params = "",
	})
end

local function addHitbox()
	local t = 0
	if #tracks.hitbox > 0 then
		local last = tracks.hitbox[#tracks.hitbox]
		t = last.time + (last.duration or 0.3)
	end
	addToTrack("hitbox", {
		time = t, duration = 0.3, shape = "circle",
		radius = 5, width = 6, height = 4,
		offset = {0, 0, 5}, damage = 100,
	})
end

-- ===================== SELECT RIG =====================
bRig.MouseButton1Click:Connect(function()
	local sel = Selection:Get()
	if #sel > 0 then
		local model = sel[1]
		if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
			selectedRig = model
			rigLabel.Text = model.Name
			rigLabel.TextColor3 = C.green
		else
			warn("[SkillEditor] Select a Model with Humanoid")
		end
	else
		warn("[SkillEditor] Select a Model in Explorer first")
	end
end)

-- ===================== VFX ASSET FROM SELECTION =====================
vpAssetBtn.MouseButton1Click:Connect(function()
	if selection.track ~= "vfx" then return end
	local sel = Selection:Get()
	if #sel > 0 and isVFXAsset(sel[1]) then
		local item = tracks.vfx[selection.index]
		item.vfxType = "asset"
		item.assetPath = getFullPath(sel[1])
		item.assetName = sel[1].Name
		updateProps(); refreshUI()
	else
		warn("[SkillEditor] Select a VFX asset (ParticleEmitter, Beam, Model with effects, etc.)")
	end
end)

-- ===================== DRAG & DROP FROM EXPLORER =====================
widget.PluginDragDropped:Connect(function(dragData)
	local sel = Selection:Get()
	if #sel == 0 then return end
	for _, inst in ipairs(sel) do
		if inst:IsA("Sound") then
			addSound(inst)
			print("[SkillEditor] Added Sound: " .. inst.Name)
		elseif inst:IsA("Animation") then
			local t = 0
			if #tracks.animation > 0 then
				local last = tracks.animation[#tracks.animation]
				t = last.time + (last.duration or 1)
			end
			addToTrack("animation", {
				time = t, duration = 1.0, animId = inst.AnimationId,
				speed = 1.0, castPoint = 0.3, cancelPoint = 0.7,
				canInterrupt = true, name = inst.Name,
			})
			print("[SkillEditor] Added Animation: " .. inst.Name)
		elseif isVFXAsset(inst) then
			addVFX(inst)
			print("[SkillEditor] Added VFX Asset: " .. inst.Name)
		end
	end
end)

widget.PluginDragEntered:Connect(function(dragData)
	infoLbl.Text = "Drop to add asset..."
	infoLbl.TextColor3 = C.accent
end)

widget.PluginDragLeft:Connect(function(dragData)
	infoLbl.Text = "Drag assets from Explorer into this panel | Click track buttons to add | Drag dots to adjust timing"
	infoLbl.TextColor3 = C.dim
end)

-- ===================== PROPERTY HANDLERS =====================
-- Camera
cpTimeIn.FocusLost:Connect(function()
	if selection.track ~= "camera" then return end
	local v = tonumber(cpTimeIn.Text)
	if v and v >= 0 then
		tracks.camera[selection.index].time = v
		table.sort(tracks.camera, function(a,b) return a.time < b.time end)
		refreshUI(); updateProps()
	end
end)
cpFovIn.FocusLost:Connect(function()
	if selection.track ~= "camera" then return end
	local v = tonumber(cpFovIn.Text)
	if v and v >= 10 and v <= 120 then
		tracks.camera[selection.index].fov = v
		workspace.CurrentCamera.FieldOfView = v
	end
end)
cpEaseBtn.MouseButton1Click:Connect(function()
	if selection.track ~= "camera" then return end
	local kf = tracks.camera[selection.index]
	local cur = table.find(EASINGS, kf.easingStyle) or 1
	kf.easingStyle = EASINGS[(cur % #EASINGS) + 1]
	updateProps(); refreshUI()
end)
cpDirBtn.MouseButton1Click:Connect(function()
	if selection.track ~= "camera" then return end
	local kf = tracks.camera[selection.index]
	local cur = table.find(DIRS, kf.easingDir) or 1
	kf.easingDir = DIRS[(cur % #DIRS) + 1]
	updateProps(); refreshUI()
end)
cpSetCam.MouseButton1Click:Connect(function()
	if selection.track ~= "camera" then return end
	tracks.camera[selection.index].cframe = workspace.CurrentCamera.CFrame
	tracks.camera[selection.index].fov = workspace.CurrentCamera.FieldOfView
end)
cpGoTo.MouseButton1Click:Connect(function()
	if selection.track ~= "camera" then return end
	workspace.CurrentCamera.CFrame = tracks.camera[selection.index].cframe
	workspace.CurrentCamera.FieldOfView = tracks.camera[selection.index].fov
end)

-- Animation
apNameIn.FocusLost:Connect(function()
	if selection.track ~= "animation" then return end
	tracks.animation[selection.index].name = apNameIn.Text; refreshUI()
end)
apTimeIn.FocusLost:Connect(function()
	if selection.track ~= "animation" then return end
	local v = tonumber(apTimeIn.Text)
	if v and v >= 0 then
		tracks.animation[selection.index].time = v
		table.sort(tracks.animation, function(a,b) return a.time < b.time end)
		refreshUI(); updateProps()
	end
end)
apDurIn.FocusLost:Connect(function()
	if selection.track ~= "animation" then return end
	local v = tonumber(apDurIn.Text)
	if v and v > 0 then tracks.animation[selection.index].duration = v; refreshUI() end
end)
apAnimIdIn.FocusLost:Connect(function()
	if selection.track ~= "animation" then return end
	tracks.animation[selection.index].animId = apAnimIdIn.Text
end)
apSpeedIn.FocusLost:Connect(function()
	if selection.track ~= "animation" then return end
	local v = tonumber(apSpeedIn.Text)
	if v and v > 0 then tracks.animation[selection.index].speed = v end
end)
apCastIn.FocusLost:Connect(function()
	if selection.track ~= "animation" then return end
	local v = tonumber(apCastIn.Text)
	if v and v >= 0 then tracks.animation[selection.index].castPoint = v; refreshUI() end
end)
apCancelIn.FocusLost:Connect(function()
	if selection.track ~= "animation" then return end
	local v = tonumber(apCancelIn.Text)
	if v and v >= 0 then tracks.animation[selection.index].cancelPoint = v; refreshUI() end
end)
apInterrupt.MouseButton1Click:Connect(function()
	if selection.track ~= "animation" then return end
	local a = tracks.animation[selection.index]
	a.canInterrupt = not a.canInterrupt; updateProps()
end)

-- VFX
vpTimeIn.FocusLost:Connect(function()
	if selection.track ~= "vfx" then return end
	local v = tonumber(vpTimeIn.Text)
	if v and v >= 0 then
		tracks.vfx[selection.index].time = v
		table.sort(tracks.vfx, function(a,b) return a.time < b.time end)
		refreshUI(); updateProps()
	end
end)
vpTypeBtn.MouseButton1Click:Connect(function()
	if selection.track ~= "vfx" then return end
	local item = tracks.vfx[selection.index]
	local cur = table.find(VFX_TYPES, item.vfxType) or 1
	item.vfxType = VFX_TYPES[(cur % #VFX_TYPES) + 1]
	updateProps(); refreshUI()
end)
vpIntIn.FocusLost:Connect(function()
	if selection.track ~= "vfx" then return end
	local v = tonumber(vpIntIn.Text)
	if v then tracks.vfx[selection.index].intensity = v end
end)
vpDurIn.FocusLost:Connect(function()
	if selection.track ~= "vfx" then return end
	local v = tonumber(vpDurIn.Text)
	if v and v > 0 then tracks.vfx[selection.index].duration = v end
end)

-- Sound
spTimeIn.FocusLost:Connect(function()
	if selection.track ~= "sound" then return end
	local v = tonumber(spTimeIn.Text)
	if v and v >= 0 then
		tracks.sound[selection.index].time = v
		table.sort(tracks.sound, function(a,b) return a.time < b.time end)
		refreshUI(); updateProps()
	end
end)
spNameIn.FocusLost:Connect(function()
	if selection.track ~= "sound" then return end
	tracks.sound[selection.index].name = spNameIn.Text; refreshUI()
end)
spIdIn.FocusLost:Connect(function()
	if selection.track ~= "sound" then return end
	tracks.sound[selection.index].soundId = spIdIn.Text
end)
spVolIn.FocusLost:Connect(function()
	if selection.track ~= "sound" then return end
	local v = tonumber(spVolIn.Text)
	if v then tracks.sound[selection.index].volume = v end
end)
spPitchIn.FocusLost:Connect(function()
	if selection.track ~= "sound" then return end
	local v = tonumber(spPitchIn.Text)
	if v then tracks.sound[selection.index].pitch = v end
end)

-- ===================== EVENT PROPERTY HANDLERS =====================
epTimeIn.FocusLost:Connect(function()
	if selection.track ~= "event" then return end
	local v = tonumber(epTimeIn.Text)
	if v and v >= 0 then
		tracks.event[selection.index].time = snapTime(v)
		table.sort(tracks.event, function(a,b) return a.time < b.time end)
		refreshUI(); updateProps()
	end
end)
epTypeBtn.MouseButton1Click:Connect(function()
	if selection.track ~= "event" then return end
	local item = tracks.event[selection.index]
	local cur = table.find(EVENT_TYPES, item.eventType) or 1
	item.eventType = EVENT_TYPES[(cur % #EVENT_TYPES) + 1]
	updateProps(); refreshUI()
end)
epNameIn.FocusLost:Connect(function()
	if selection.track ~= "event" then return end
	tracks.event[selection.index].name = epNameIn.Text
end)
epValueIn.FocusLost:Connect(function()
	if selection.track ~= "event" then return end
	local v = tonumber(epValueIn.Text)
	if v then tracks.event[selection.index].value = v end
end)
epParamsIn.FocusLost:Connect(function()
	if selection.track ~= "event" then return end
	tracks.event[selection.index].params = epParamsIn.Text
end)

-- ===================== HITBOX PROPERTY HANDLERS =====================
hpTimeIn.FocusLost:Connect(function()
	if selection.track ~= "hitbox" then return end
	local v = tonumber(hpTimeIn.Text)
	if v and v >= 0 then
		tracks.hitbox[selection.index].time = snapTime(v)
		table.sort(tracks.hitbox, function(a,b) return a.time < b.time end)
		refreshUI(); updateProps()
	end
end)
hpDurIn.FocusLost:Connect(function()
	if selection.track ~= "hitbox" then return end
	local v = tonumber(hpDurIn.Text)
	if v and v > 0 then tracks.hitbox[selection.index].duration = v; refreshUI() end
end)
hpShapeBtn.MouseButton1Click:Connect(function()
	if selection.track ~= "hitbox" then return end
	local item = tracks.hitbox[selection.index]
	local cur = table.find(HITBOX_SHAPES, item.shape) or 1
	item.shape = HITBOX_SHAPES[(cur % #HITBOX_SHAPES) + 1]
	updateProps(); refreshUI()
end)
hpRadiusIn.FocusLost:Connect(function()
	if selection.track ~= "hitbox" then return end
	local v = tonumber(hpRadiusIn.Text)
	if v and v > 0 then tracks.hitbox[selection.index].radius = v end
end)
hpWidthIn.FocusLost:Connect(function()
	if selection.track ~= "hitbox" then return end
	local v = tonumber(hpWidthIn.Text)
	if v and v > 0 then tracks.hitbox[selection.index].width = v end
end)
hpHeightIn.FocusLost:Connect(function()
	if selection.track ~= "hitbox" then return end
	local v = tonumber(hpHeightIn.Text)
	if v and v > 0 then tracks.hitbox[selection.index].height = v end
end)
hpOffsetIn.FocusLost:Connect(function()
	if selection.track ~= "hitbox" then return end
	local parts = string.split(hpOffsetIn.Text, ",")
	if #parts >= 3 then
		local x,y,z = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
		if x and y and z then
			tracks.hitbox[selection.index].offset = {x, y, z}
		end
	end
end)
hpDamageIn.FocusLost:Connect(function()
	if selection.track ~= "hitbox" then return end
	local v = tonumber(hpDamageIn.Text)
	if v then tracks.hitbox[selection.index].damage = v end
end)

-- ===================== PREVIEW =====================
local function stopPreview()
	if previewConn then previewConn:Disconnect(); previewConn = nil end
	previewing = false; playheadLine.Visible = false
	if savedCamCF then
		workspace.CurrentCamera.CFrame = savedCamCF
		workspace.CurrentCamera.FieldOfView = savedCamFov or 70
	end
	-- Clean up VFX
	local cc = Lighting:FindFirstChild("_SkEdCC")
	if cc then cc:Destroy() end
	local blur = Lighting:FindFirstChild("_SkEdBlur")
	if blur then blur:Destroy() end
	-- Clean up sub-connections (shake etc.)
	for _, conn in ipairs(previewSubConns) do
		if conn.Connected then conn:Disconnect() end
	end
	previewSubConns = {}
	-- Clean up animations
	for _, at in ipairs(previewAnims) do
		pcall(function() at:Stop(); at:Destroy() end)
	end
	previewAnims = {}
	-- Clean up sounds
	for _, snd in ipairs(previewSounds) do
		pcall(function() snd:Stop(); snd:Destroy() end)
	end
	previewSounds = {}
end

local function startPreview()
	local hasItems = false
	for _, list in pairs(tracks) do
		if #list > 0 then hasItems = true; break end
	end
	if not hasItems then warn("[SkillEditor] No items to preview"); return end
	if previewing then stopPreview() end
	previewing = true; playheadLine.Visible = true
	savedCamCF = workspace.CurrentCamera.CFrame
	savedCamFov = workspace.CurrentCamera.FieldOfView

	local cam = workspace.CurrentCamera
	local totalDur = getTotalDur()
	local startT = tick()
	local firedVfx = {}
	local firedSound = {}
	local firedAnim = {}
	local camKfs = tracks.camera

	previewConn = RunService.Heartbeat:Connect(function()
		if not previewing then return end
		local elapsed = tick() - startT

		local maxTime = 0
		for _, list in pairs(tracks) do
			for _, item in ipairs(list) do
				local et = item.time + (item.duration or 0)
				if et > maxTime then maxTime = et end
			end
		end
		if elapsed > maxTime + 0.5 then stopPreview(); return end

		-- Playhead
		local tlFrac = math.clamp(elapsed / totalDur, 0, 1)
		local laneRef = trackLanes.camera
		local phX = laneRef.AbsolutePosition.X + tlFrac * laneRef.AbsoluteSize.X
		playheadLine.Position = UDim2.new(0, phX - tlArea.AbsolutePosition.X, 0, 0)

		-- Camera interpolation
		if #camKfs >= 2 then
			local prevKf, nextKf = camKfs[1], camKfs[#camKfs]
			for j = 1, #camKfs - 1 do
				if elapsed >= camKfs[j].time and elapsed < camKfs[j+1].time then
					prevKf = camKfs[j]; nextKf = camKfs[j+1]; break
				end
			end
			if elapsed >= camKfs[#camKfs].time then
				cam.CFrame = camKfs[#camKfs].cframe
				cam.FieldOfView = camKfs[#camKfs].fov
			else
				local segDur = nextKf.time - prevKf.time
				local segT = segDur > 0 and ((elapsed - prevKf.time) / segDur) or 1
				local style = Enum.EasingStyle[nextKf.easingStyle] or Enum.EasingStyle.Sine
				local dir = Enum.EasingDirection[nextKf.easingDir] or Enum.EasingDirection.InOut
				local eased = TweenService:GetValue(segT, style, dir)
				cam.CFrame = prevKf.cframe:Lerp(nextKf.cframe, eased)
				cam.FieldOfView = prevKf.fov + (nextKf.fov - prevKf.fov) * eased
			end
		end

		-- Animation triggers
		if selectedRig then
			local humanoid = selectedRig:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if animator then
				for i, anim in ipairs(tracks.animation) do
					if not firedAnim[i] and elapsed >= anim.time then
						firedAnim[i] = true
						if anim.animId and anim.animId ~= "rbxassetid://0" then
							local animObj = Instance.new("Animation")
							animObj.AnimationId = anim.animId
							local ok, at = pcall(function()
								return animator:LoadAnimation(animObj)
							end)
							if ok and at then
								at:AdjustSpeed(anim.speed or 1)
								at:Play()
								table.insert(previewAnims, at)
								task.delay((anim.duration or 1) / (anim.speed or 1), function()
									if at.IsPlaying then at:Stop() end
								end)
							end
							animObj:Destroy()
						end
					end
				end
			end
		end

		-- Sound triggers
		for i, snd in ipairs(tracks.sound) do
			if not firedSound[i] and elapsed >= snd.time then
				firedSound[i] = true
				if snd.soundId and snd.soundId ~= "rbxassetid://0" then
					local s = Instance.new("Sound")
					s.SoundId = snd.soundId
					s.Volume = snd.volume or 1
					s.PlaybackSpeed = snd.pitch or 1
					s.Parent = workspace
					s:Play()
					table.insert(previewSounds, s)
					s.Ended:Once(function()
						pcall(function() s:Destroy() end)
					end)
				end
			end
		end

		-- VFX triggers
		for i, vfx in ipairs(tracks.vfx) do
			if not firedVfx[i] and elapsed >= vfx.time then
				firedVfx[i] = true
				if vfx.vfxType == "flash" then
					local cc = Lighting:FindFirstChild("_SkEdCC")
					if not cc then
						cc = Instance.new("ColorCorrectionEffect")
						cc.Name = "_SkEdCC"; cc.Parent = Lighting
					end
					cc.Brightness = vfx.intensity
					TweenService:Create(cc, TweenInfo.new(vfx.duration), {Brightness = 0}):Play()
				elseif vfx.vfxType == "shake" then
					local int = vfx.intensity
					local dur = vfx.duration
					local sStart = tick()
					local sConn
					sConn = RunService.Heartbeat:Connect(function()
						local e = tick() - sStart
						if e >= dur then sConn:Disconnect(); return end
						local decay = 1 - e/dur
						cam.CFrame = cam.CFrame * CFrame.new(
							math.sin(e*25)*int*decay*0.1,
							math.cos(e*32)*int*decay*0.1, 0)
					end)
					table.insert(previewSubConns, sConn)
				elseif vfx.vfxType == "blur" then
					local blurFx = Lighting:FindFirstChild("_SkEdBlur")
					if not blurFx then
						blurFx = Instance.new("BlurEffect")
						blurFx.Name = "_SkEdBlur"; blurFx.Parent = Lighting
					end
					blurFx.Size = vfx.intensity * 20
					TweenService:Create(blurFx, TweenInfo.new(vfx.duration), {Size = 0}):Play()
				elseif vfx.vfxType == "colorShift" then
					local cc = Lighting:FindFirstChild("_SkEdCC")
					if not cc then
						cc = Instance.new("ColorCorrectionEffect")
						cc.Name = "_SkEdCC"; cc.Parent = Lighting
					end
					cc.TintColor = Color3.fromRGB(255, 200, 200)
					cc.Saturation = vfx.intensity
					TweenService:Create(cc, TweenInfo.new(vfx.duration), {
						TintColor = Color3.fromRGB(255,255,255), Saturation = 0
					}):Play()
				end
			end
		end
	end)
end

-- ===================== EXPORT =====================
local function cfToStr(cf)
	local p = {cf:GetComponents()}
	local s = {}
	for _, v in ipairs(p) do table.insert(s, string.format("%.4f", v)) end
	return "CFrame.new(" .. table.concat(s, ",") .. ")"
end

local function exportAll()
	local name = txtName.Text
	if name == "" then name = "SkillData" end

	local lines = {}
	table.insert(lines, "-- Skill: " .. name)
	table.insert(lines, "-- Generated by Skill Editor Plugin")
	table.insert(lines, "")
	table.insert(lines, "local module = {}")
	table.insert(lines, "")

	if #tracks.camera > 0 then
		table.insert(lines, "module.Camera = {")
		for _, kf in ipairs(tracks.camera) do
			table.insert(lines, string.format(
				'\t{time=%.2f, cframe=%s, fov=%d, easing="%s", easingDir="%s"},',
				kf.time, cfToStr(kf.cframe), math.floor(kf.fov), kf.easingStyle, kf.easingDir
			))
		end
		table.insert(lines, "}")
		table.insert(lines, "")
	end

	if #tracks.animation > 0 then
		table.insert(lines, "module.Animations = {")
		for _, a in ipairs(tracks.animation) do
			table.insert(lines, string.format(
				'\t{time=%.2f, duration=%.2f, animId="%s", speed=%.1f, castPoint=%.2f, cancelPoint=%.2f, canInterrupt=%s, name="%s"},',
				a.time, a.duration, a.animId, a.speed,
				a.castPoint, a.cancelPoint, tostring(a.canInterrupt), a.name or "Anim"
			))
		end
		table.insert(lines, "}")
		table.insert(lines, "")
	end

	if #tracks.vfx > 0 then
		table.insert(lines, "module.VFX = {")
		for _, v in ipairs(tracks.vfx) do
			local extra = ""
			if v.assetPath then
				extra = string.format(', assetPath="%s", assetName="%s"', v.assetPath, v.assetName or "")
			end
			table.insert(lines, string.format(
				'\t{time=%.2f, type="%s", intensity=%.1f, duration=%.2f%s},',
				v.time, v.vfxType, v.intensity, v.duration, extra
			))
		end
		table.insert(lines, "}")
		table.insert(lines, "")
	end

	if #tracks.sound > 0 then
		table.insert(lines, "module.Sounds = {")
		for _, s in ipairs(tracks.sound) do
			local extra = ""
			if s.assetPath then
				extra = string.format(', assetPath="%s"', s.assetPath)
			end
			table.insert(lines, string.format(
				'\t{time=%.2f, soundId="%s", volume=%.1f, pitch=%.1f, name="%s"%s},',
				s.time, s.soundId, s.volume, s.pitch, s.name or "Sound", extra
			))
		end
		table.insert(lines, "}")
		table.insert(lines, "")
	end

	if #tracks.event > 0 then
		table.insert(lines, "module.Events = {")
		for _, e in ipairs(tracks.event) do
			local extra = ""
			if e.params and e.params ~= "" then
				extra = string.format(', params="%s"', e.params)
			end
			table.insert(lines, string.format(
				'\t{time=%.2f, type="%s", name="%s", value=%s%s},',
				e.time, e.eventType or "damage", e.name or "Event",
				tostring(e.value or 100), extra
			))
		end
		table.insert(lines, "}")
		table.insert(lines, "")
	end

	if #tracks.hitbox > 0 then
		table.insert(lines, "module.Hitboxes = {")
		for _, h in ipairs(tracks.hitbox) do
			local off = h.offset or {0,0,5}
			table.insert(lines, string.format(
				'\t{time=%.2f, duration=%.2f, shape="%s", radius=%s, width=%s, height=%s, offset={%s,%s,%s}, damage=%s},',
				h.time, h.duration or 0.3, h.shape or "circle",
				tostring(h.radius or 5), tostring(h.width or 6), tostring(h.height or 4),
				tostring(off[1]), tostring(off[2]), tostring(off[3]),
				tostring(h.damage or 100)
			))
		end
		table.insert(lines, "}")
		table.insert(lines, "")
	end

	table.insert(lines, "return module")

	local folder = game.ReplicatedStorage:FindFirstChild("SkillEditorData")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SkillEditorData"
		folder.Parent = game.ReplicatedStorage
	end

	local existing = folder:FindFirstChild(name)
	if existing then existing:Destroy() end

	local mod = Instance.new("ModuleScript")
	mod.Name = name
	mod.Source = table.concat(lines, "\n")
	mod.Parent = folder

	ChangeHistoryService:SetWaypoint("Export Skill: " .. name)
	print("[SkillEditor] Exported -> ReplicatedStorage.SkillEditorData." .. name)
end

-- ===================== IMPORT =====================
local function importData()
	local name = txtName.Text
	if name == "" then name = "MySkill" end
	local folder = game.ReplicatedStorage:FindFirstChild("SkillEditorData")
	if not folder then warn("[SkillEditor] No SkillEditorData folder"); return end
	local mod = folder:FindFirstChild(name)
	if not mod or not mod:IsA("ModuleScript") then
		warn("[SkillEditor] Module '" .. name .. "' not found in SkillEditorData")
		return
	end

	local ok, data = pcall(require, mod)
	if not ok then warn("[SkillEditor] Failed to load: " .. tostring(data)); return end

	saveUndo()
	for k in pairs(tracks) do tracks[k] = {} end

	if data.Camera then
		for _, kf in ipairs(data.Camera) do
			table.insert(tracks.camera, {
				time = kf.time, cframe = kf.cframe, fov = kf.fov,
				easingStyle = kf.easing or "Sine", easingDir = kf.easingDir or "InOut",
			})
		end
	end
	if data.Animations then
		for _, a in ipairs(data.Animations) do
			table.insert(tracks.animation, {
				time = a.time, duration = a.duration, animId = a.animId,
				speed = a.speed or 1, castPoint = a.castPoint or 0.3,
				cancelPoint = a.cancelPoint or 0.7, canInterrupt = a.canInterrupt ~= false,
				name = a.name or "Anim",
			})
		end
	end
	if data.VFX then
		for _, v in ipairs(data.VFX) do
			table.insert(tracks.vfx, {
				time = v.time, vfxType = v.type or "flash",
				intensity = v.intensity or 1, duration = v.duration or 0.3,
				assetPath = v.assetPath, assetName = v.assetName,
			})
		end
	end
	if data.Sounds then
		for _, s in ipairs(data.Sounds) do
			table.insert(tracks.sound, {
				time = s.time, soundId = s.soundId, volume = s.volume or 1,
				pitch = s.pitch or 1, name = s.name or "Sound",
				assetPath = s.assetPath,
			})
		end
	end
	if data.Events then
		for _, e in ipairs(data.Events) do
			table.insert(tracks.event, {
				time = e.time, eventType = e.type or "damage",
				name = e.name or "Event", value = e.value or 100,
				params = e.params or "",
			})
		end
	end
	if data.Hitboxes then
		for _, h in ipairs(data.Hitboxes) do
			table.insert(tracks.hitbox, {
				time = h.time, duration = h.duration or 0.3,
				shape = h.shape or "circle", radius = h.radius or 5,
				width = h.width or 6, height = h.height or 4,
				offset = h.offset or {0,0,5}, damage = h.damage or 100,
			})
		end
	end

	selection.track = nil; selection.index = 0
	updateProps(); refreshUI()
	print("[SkillEditor] Imported: " .. name)
end

-- ===================== SNAP TOGGLE =====================
bSnap.MouseButton1Click:Connect(function()
	snapEnabled = not snapEnabled
	bSnap.Text = snapEnabled and "Snap*" or "Snap"
	bSnap.BackgroundColor3 = snapEnabled and C.accent or C.btn
end)

-- ===================== CONNECTIONS =====================
bAddCam.MouseButton1Click:Connect(addCameraKF)
bAddAnim.MouseButton1Click:Connect(addAnimation)
bAddVfx.MouseButton1Click:Connect(function() addVFX(nil) end)
bAddSnd.MouseButton1Click:Connect(function() addSound(nil) end)
bAddEvt.MouseButton1Click:Connect(addEvent)
bAddHit.MouseButton1Click:Connect(addHitbox)
bDel.MouseButton1Click:Connect(deleteSelected)
bPreview.MouseButton1Click:Connect(startPreview)
bStop.MouseButton1Click:Connect(stopPreview)
bExport.MouseButton1Click:Connect(exportAll)
bImport.MouseButton1Click:Connect(importData)
bClear.MouseButton1Click:Connect(clearAllTracks)
bDup.MouseButton1Click:Connect(duplicateSelected)
bUndo.MouseButton1Click:Connect(undo)

-- Context menu actions
ctxBtns["Delete"].MouseButton1Click:Connect(function() hideCtxMenu(); deleteSelected() end)
ctxBtns["Duplicate"].MouseButton1Click:Connect(function() hideCtxMenu(); duplicateSelected() end)
ctxBtns["Copy"].MouseButton1Click:Connect(function()
	hideCtxMenu()
	if selection.track and selection.index >= 1 then
		local list = tracks[selection.track]
		if selection.index <= #list then
			clipboard = {track = selection.track, data = deepCopyT(list[selection.index])}
		end
	end
end)
ctxBtns["Paste"].MouseButton1Click:Connect(function()
	hideCtxMenu()
	if clipboard then
		local item = deepCopyT(clipboard.data)
		item.time = item.time + 0.5
		addToTrack(clipboard.track, item)
	end
end)

-- ===================== ZOOM =====================
tlArea.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		zoomLevel = math.clamp(zoomLevel + input.Position.Z * 0.2, 0.5, 5.0)
		zoomLbl.Text = string.format("%.1fx", zoomLevel)
		refreshUI()
	end
end)

-- ===================== KEYBOARD SHORTCUTS =====================
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	if ctrl and input.KeyCode == Enum.KeyCode.Z then
		undo()
	elseif ctrl and input.KeyCode == Enum.KeyCode.D then
		duplicateSelected()
	elseif ctrl and input.KeyCode == Enum.KeyCode.C then
		if selection.track and selection.index >= 1 then
			local list = tracks[selection.track]
			if selection.index <= #list then
				clipboard = {track = selection.track, data = deepCopyT(list[selection.index])}
			end
		end
	elseif ctrl and input.KeyCode == Enum.KeyCode.V then
		if clipboard then
			local item = deepCopyT(clipboard.data)
			item.time = item.time + 0.5
			addToTrack(clipboard.track, item)
		end
	elseif input.KeyCode == Enum.KeyCode.Delete then
		deleteSelected()
	end
end)

-- ===================== TIMELINE SCRUB =====================
timeHeader.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	local laneRef = trackLanes.camera
	local absX = laneRef.AbsolutePosition.X
	local absW = laneRef.AbsoluteSize.X
	if absW <= 0 then return end
	local frac = math.clamp((input.Position.X - absX) / absW, 0, 1)
	local totalDur = getTotalDur()
	local targetTime = frac * totalDur

	-- Show playhead
	playheadLine.Visible = true
	playheadLine.Position = UDim2.new(0, input.Position.X - tlArea.AbsolutePosition.X, 0, 0)

	-- Jump camera to interpolated position at target time
	local camKfs = tracks.camera
	if #camKfs >= 2 then
		local prevKf, nextKf = camKfs[1], camKfs[#camKfs]
		for j = 1, #camKfs - 1 do
			if targetTime >= camKfs[j].time and targetTime < camKfs[j+1].time then
				prevKf = camKfs[j]; nextKf = camKfs[j+1]; break
			end
		end
		if targetTime >= camKfs[#camKfs].time then
			workspace.CurrentCamera.CFrame = camKfs[#camKfs].cframe
			workspace.CurrentCamera.FieldOfView = camKfs[#camKfs].fov
		else
			local segDur = nextKf.time - prevKf.time
			local segT = segDur > 0 and ((targetTime - prevKf.time) / segDur) or 1
			local style = Enum.EasingStyle[nextKf.easingStyle] or Enum.EasingStyle.Sine
			local dir = Enum.EasingDirection[nextKf.easingDir] or Enum.EasingDirection.InOut
			local eased = TweenService:GetValue(segT, style, dir)
			workspace.CurrentCamera.CFrame = prevKf.cframe:Lerp(nextKf.cframe, eased)
			workspace.CurrentCamera.FieldOfView = prevKf.fov + (nextKf.fov - prevKf.fov) * eased
		end
	elseif #camKfs == 1 then
		workspace.CurrentCamera.CFrame = camKfs[1].cframe
		workspace.CurrentCamera.FieldOfView = camKfs[1].fov
	end
end)

refreshUI()