--[[
	MobileCancelZone.lua
	移动端技能释放取消框 (REQ-026)

	功能:
	- 右上角圆形取消框(✕)
	- 手指进入取消区域时变红, 离开恢复
	- 松手时在取消区域内 → 取消技能释放
	- 遵守移动端UI自适应标准: Scale定位 + RelativeYY + MinSize 44×44
	- ScreenGui DisplayOrder = 15 (高于指示器5, 高于MobileUI 10)
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local MobileConfig = require(script.Parent.Parent.Modules.MobileConfig)

local MobileCancelZone = {}

-- ═══════════════════════════════════════
-- 内部状态
-- ═══════════════════════════════════════
local screenGui: ScreenGui? = nil
local cancelFrame: Frame? = nil
local cancelLabel: TextLabel? = nil
local isVisible = false
local isActive = false   -- 手指是否在取消区域内

-- 缓存绝对坐标用于快速判定
local cachedCenterX = 0
local cachedCenterY = 0
local cachedHitRadius = 0

-- ═══════════════════════════════════════
-- 初始化
-- ═══════════════════════════════════════

--- 初始化取消框UI
--- @param playerGui PlayerGui
function MobileCancelZone.Init(playerGui: PlayerGui)
	-- 创建 ScreenGui (DisplayOrder=15, 在指示器和MobileUI之上)
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CancelZoneGui"
	screenGui.DisplayOrder = MobileConfig.CANCEL_ZONE_GUI_DISPLAY_ORDER
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- 取消框容器
	cancelFrame = Instance.new("Frame")
	cancelFrame.Name = "CancelZone"
	cancelFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	-- Scale定位(右上角)
	cancelFrame.Position = UDim2.new(
		MobileConfig.CANCEL_ZONE_POS.X, 0,
		MobileConfig.CANCEL_ZONE_POS.Y, 0
	)
	-- RelativeYY尺寸 + MinSize保障
	local zoneSize = MobileConfig.CANCEL_ZONE_SIZE
	cancelFrame.Size = UDim2.new(zoneSize, 0, zoneSize, 0)
	cancelFrame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	cancelFrame.BackgroundColor3 = MobileConfig.CANCEL_ZONE_NORMAL_COLOR
	cancelFrame.BackgroundTransparency = 1  -- 初始完全透明(隐藏)
	cancelFrame.BorderSizePixel = 0
	cancelFrame.Visible = false
	cancelFrame.Parent = screenGui

	-- 圆角(圆形)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = cancelFrame

	-- 最小尺寸约束(触达性: 44×44px)
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(
		MobileConfig.CANCEL_ZONE_MIN_SIZE,
		MobileConfig.CANCEL_ZONE_MIN_SIZE
	)
	sizeConstraint.Parent = cancelFrame

	-- 边框
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	stroke.Color = MobileConfig.CANCEL_ZONE_NORMAL_COLOR
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = cancelFrame

	-- ✕ 文字
	cancelLabel = Instance.new("TextLabel")
	cancelLabel.Name = "CancelText"
	cancelLabel.Size = UDim2.new(0.6, 0, 0.6, 0)
	cancelLabel.Position = UDim2.new(0.2, 0, 0.2, 0)
	cancelLabel.BackgroundTransparency = 1
	cancelLabel.Text = "✕"
	cancelLabel.TextColor3 = Color3.new(1, 1, 1)
	cancelLabel.TextScaled = true
	cancelLabel.Font = Enum.Font.GothamBold
	cancelLabel.Parent = cancelFrame
end

-- ═══════════════════════════════════════
-- 显示/隐藏
-- ═══════════════════════════════════════

--- 显示取消框(淡入)
function MobileCancelZone.Show()
	if not cancelFrame then return end
	if isVisible then return end

	isVisible = true
	isActive = false
	cancelFrame.Visible = true
	cancelFrame.BackgroundColor3 = MobileConfig.CANCEL_ZONE_NORMAL_COLOR
	cancelFrame.BackgroundTransparency = 1  -- 从透明开始
	local stroke = cancelFrame:FindFirstChild("Border")
	if stroke then
		stroke.Color = MobileConfig.CANCEL_ZONE_NORMAL_COLOR
	end

	-- 淡入动画
	TweenService:Create(cancelFrame, TweenInfo.new(
		MobileConfig.CANCEL_ZONE_TWEEN_IN,
		Enum.EasingStyle.Quad, Enum.EasingDirection.Out
	), {
		BackgroundTransparency = 1 - MobileConfig.CANCEL_ZONE_NORMAL_ALPHA,
	}):Play()

	-- 更新缓存坐标(用于IsInCancelZone判定)
	MobileCancelZone._updateCachedPosition()
end

--- 隐藏取消框(淡出)
function MobileCancelZone.Hide()
	if not cancelFrame then return end
	if not isVisible then return end

	isVisible = false
	isActive = false
	cancelFrame.BackgroundColor3 = MobileConfig.CANCEL_ZONE_NORMAL_COLOR
	local stroke = cancelFrame:FindFirstChild("Border")
	if stroke then
		stroke.Color = MobileConfig.CANCEL_ZONE_NORMAL_COLOR
	end

	-- 淡出动画
	local tween = TweenService:Create(cancelFrame, TweenInfo.new(
		MobileConfig.CANCEL_ZONE_TWEEN_OUT,
		Enum.EasingStyle.Quad, Enum.EasingDirection.In
	), {
		BackgroundTransparency = 1,
	})
	tween.Completed:Connect(function()
		if not isVisible and cancelFrame then
			cancelFrame.Visible = false
		end
	end)
	tween:Play()
end

-- ═══════════════════════════════════════
-- 激活状态(变红/恢复)
-- ═══════════════════════════════════════

--- 设置激活状态
--- @param isInZone boolean - 手指是否在取消区域内
function MobileCancelZone.SetActive(isInZone: boolean)
	if not cancelFrame then return end
	if isActive == isInZone then return end  -- 无变化

	isActive = isInZone

	if isInZone then
		-- 变红
		cancelFrame.BackgroundColor3 = MobileConfig.CANCEL_ZONE_ACTIVE_COLOR
		cancelFrame.BackgroundTransparency = 1 - MobileConfig.CANCEL_ZONE_ACTIVE_ALPHA
		local stroke = cancelFrame:FindFirstChild("Border")
		if stroke then stroke.Color = MobileConfig.CANCEL_ZONE_ACTIVE_COLOR end
		if cancelLabel then cancelLabel.TextColor3 = Color3.new(1, 1, 1) end
	else
		-- 恢复正常
		cancelFrame.BackgroundColor3 = MobileConfig.CANCEL_ZONE_NORMAL_COLOR
		cancelFrame.BackgroundTransparency = 1 - MobileConfig.CANCEL_ZONE_NORMAL_ALPHA
		local stroke = cancelFrame:FindFirstChild("Border")
		if stroke then stroke.Color = MobileConfig.CANCEL_ZONE_NORMAL_COLOR end
		if cancelLabel then cancelLabel.TextColor3 = Color3.new(1, 1, 1) end
	end
end

-- ═══════════════════════════════════════
-- 判定
-- ═══════════════════════════════════════

--- 判断屏幕坐标是否在取消区域内
--- @param screenPos Vector2 - 手指屏幕位置(绝对像素)
--- @return boolean
function MobileCancelZone.IsInCancelZone(screenPos: Vector2): boolean
	if not isVisible or not cancelFrame then return false end

	-- 刷新缓存(万一屏幕旋转了)
	MobileCancelZone._updateCachedPosition()

	local dx = screenPos.X - cachedCenterX
	local dy = screenPos.Y - cachedCenterY
	local dist = math.sqrt(dx * dx + dy * dy)

	return dist <= cachedHitRadius
end

--- 内部: 更新缓存的绝对坐标
function MobileCancelZone._updateCachedPosition()
	if not cancelFrame then return end
	local absPos = cancelFrame.AbsolutePosition
	local absSize = cancelFrame.AbsoluteSize
	cachedCenterX = absPos.X + absSize.X / 2
	cachedCenterY = absPos.Y + absSize.Y / 2
	-- 判定半径 = 可视半径 × 容错系数
	cachedHitRadius = (absSize.X / 2) * MobileConfig.CANCEL_HIT_RADIUS_MULT
end

-- ═══════════════════════════════════════
-- 销毁
-- ═══════════════════════════════════════

function MobileCancelZone.Destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
	cancelFrame = nil
	cancelLabel = nil
	isVisible = false
	isActive = false
end

return MobileCancelZone
