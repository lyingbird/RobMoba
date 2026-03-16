--[[
	UI_Minimap.lua
	简化版小地图: 竞技场缩略 + 己方蓝点 + 敌方红点
	REQ-011: 手机端MOBA UI与操控系统 (MOD-06)

	纯UI方案(Frame+圆点), 不使用ViewportFrame
	0.5s定时更新位置标记, 1v1简化(仅2个标记)
]]

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local MobileConfig = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("MobileConfig"))

local UI_Minimap = {}

-- 内部引用
local minimapFrame = nil
local myDot = nil
local enemyDot = nil
local updateRunning = false

-- 地图边界 (世界坐标 XZ 平面)
local mapMinX = 0
local mapMinZ = 0
local mapRangeX = 1
local mapRangeZ = 1

-- ═══════════════════════════════════════
-- 内部工具
-- ═══════════════════════════════════════
-- 世界坐标 → 小地图比例坐标 (UDim2)
local function worldToMinimap(worldPos)
	local nx = math.clamp((worldPos.X - mapMinX) / mapRangeX, 0, 1)
	local nz = math.clamp((worldPos.Z - mapMinZ) / mapRangeZ, 0, 1)
	return UDim2.new(nx, 0, nz, 0)
end

-- 获取敌方角色 HumanoidRootPart
local function getEnemyRootPart()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			local root = p.Character:FindFirstChild("HumanoidRootPart")
			if root then
				return root
			end
		end
	end
	-- 也检查训练假人
	local dummies = workspace:FindFirstChild("TrainingDummies")
	if dummies then
		for _, dummy in ipairs(dummies:GetChildren()) do
			local root = dummy:FindFirstChild("HumanoidRootPart")
			if root then
				return root
			end
		end
	end
	return nil
end

-- 创建标记圆点
local function createDot(name, color, parent)
	local dot = Instance.new("Frame")
	dot.Name = name
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.new(MobileConfig.MINIMAP_DOT_SIZE, 0, MobileConfig.MINIMAP_DOT_SIZE, 0)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.ZIndex = 7
	dot.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0) -- 圆形
	corner.Parent = dot

	return dot
end

-- ═══════════════════════════════════════
-- 定时更新循环
-- ═══════════════════════════════════════
local function updateLoop()
	while updateRunning and minimapFrame and minimapFrame.Parent do
		-- 己方位置
		local myChar = player.Character
		local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
		if myRoot and myDot then
			myDot.Position = worldToMinimap(myRoot.Position)
			myDot.Visible = true
		end

		-- 敌方位置
		local enemyRoot = getEnemyRootPart()
		if enemyRoot and enemyDot then
			enemyDot.Position = worldToMinimap(enemyRoot.Position)
			enemyDot.Visible = true
		elseif enemyDot then
			enemyDot.Visible = false
		end

		task.wait(MobileConfig.MINIMAP_UPDATE_INTERVAL)
	end
end

-- ═══════════════════════════════════════
-- 公共 API
-- ═══════════════════════════════════════
-- mapBounds: { min = Vector2(minX, minZ), max = Vector2(maxX, maxZ) }
function UI_Minimap.Init(parentFrame, mapBounds)
	-- 解析地图边界
	if mapBounds then
		mapMinX = mapBounds.min.X
		mapMinZ = mapBounds.min.Y -- Vector2(X=worldX, Y=worldZ)
		mapRangeX = math.max(mapBounds.max.X - mapBounds.min.X, 1)
		mapRangeZ = math.max(mapBounds.max.Y - mapBounds.min.Y, 1)
	else
		-- 默认竞技场范围 (如果未提供)
		mapMinX = -100
		mapMinZ = -100
		mapRangeX = 200
		mapRangeZ = 200
	end

	-- 小地图容器
	minimapFrame = Instance.new("Frame")
	minimapFrame.Name = "Minimap"
	minimapFrame.AnchorPoint = Vector2.new(0, 0)
	minimapFrame.Size = UDim2.new(MobileConfig.MINIMAP_SIZE, 0, MobileConfig.MINIMAP_SIZE, 0)
	minimapFrame.Position = UDim2.new(0.01, 0, 0.12, 0) -- 左上角, 顶部信息栏下方
	minimapFrame.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
	minimapFrame.BackgroundTransparency = 0.2
	minimapFrame.BorderSizePixel = 0
	minimapFrame.ZIndex = 5
	minimapFrame.ClipsDescendants = true
	minimapFrame.Parent = parentFrame

	-- 白色边框
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 180, 180)
	stroke.Thickness = 1
	stroke.Parent = minimapFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = minimapFrame

	-- 纵横分割线 (简易地图参考线)
	local hLine = Instance.new("Frame")
	hLine.Name = "HLine"
	hLine.Size = UDim2.new(1, 0, 0, 1)
	hLine.Position = UDim2.new(0, 0, 0.5, 0)
	hLine.BackgroundColor3 = Color3.fromRGB(60, 65, 70)
	hLine.BorderSizePixel = 0
	hLine.ZIndex = 6
	hLine.Parent = minimapFrame

	local vLine = Instance.new("Frame")
	vLine.Name = "VLine"
	vLine.Size = UDim2.new(0, 1, 1, 0)
	vLine.Position = UDim2.new(0.5, 0, 0, 0)
	vLine.BackgroundColor3 = Color3.fromRGB(60, 65, 70)
	vLine.BorderSizePixel = 0
	vLine.ZIndex = 6
	vLine.Parent = minimapFrame

	-- 标记圆点
	myDot = createDot("MyDot", MobileConfig.MINIMAP_MY_COLOR, minimapFrame)
	enemyDot = createDot("EnemyDot", MobileConfig.MINIMAP_ENEMY_COLOR, minimapFrame)
	enemyDot.Visible = false

	-- 启动更新循环
	updateRunning = true
	task.spawn(updateLoop)
end

function UI_Minimap.UpdatePositions(myPosition, enemyPosition)
	if myDot and myPosition then
		myDot.Position = worldToMinimap(myPosition)
		myDot.Visible = true
	end

	if enemyDot then
		if enemyPosition then
			enemyDot.Position = worldToMinimap(enemyPosition)
			enemyDot.Visible = true
		else
			enemyDot.Visible = false
		end
	end
end

function UI_Minimap.SetVisible(visible)
	if minimapFrame then
		minimapFrame.Visible = visible
	end
end

function UI_Minimap.Destroy()
	updateRunning = false

	if minimapFrame then
		minimapFrame:Destroy()
		minimapFrame = nil
	end

	myDot = nil
	enemyDot = nil
end

return UI_Minimap
