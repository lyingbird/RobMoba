-- SkillCursor: 技能摇杆 UI（王者荣耀风格）
-- 路径: StarterPlayerScripts/Modules/SkillSystem/SkillCursor.lua
--
-- 职责: 在手指按下技能按钮时，在按下位置显示"大圈 + 小圆点"拖动控件。
--       拖动时小圆点跟随手指（钳位在大圈半径内），取消时变红。
-- API:
--   SkillCursor.new(parentFrame)          -- 创建 UI 实例（初始隐藏）
--   SkillCursor:Show(screenPos)           -- 在屏幕位置显示摇杆
--   SkillCursor:UpdateDot(screenPos)      -- 更新小圆点位置
--   SkillCursor:SetCancelState(isCancel)  -- 蓝色 ↔ 红色
--   SkillCursor:Hide()                    -- 隐藏并重置
--   SkillCursor:Destroy()                 -- 清理

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(
	ReplicatedStorage:WaitForChild("SkillSystem")
		:WaitForChild("Config")
		:WaitForChild("GlobalConfig")
)

local SkillCursor = {}
SkillCursor.__index = SkillCursor

--------------------------------------------------------------------------------
-- Constructor
-- parentFrame: ScreenGui 下的 Frame（技能按钮容器，摇杆 UI 挂在它下面）
--------------------------------------------------------------------------------
function SkillCursor.new(parentFrame)
	local self = setmetatable({}, SkillCursor)

	self._parent = parentFrame
	self._centerPos = Vector2.zero   -- 大圈中心的屏幕坐标
	self._isVisible = false
	self._isCancel = false

	-- 读取配置
	local cfg = GlobalConfig
	local ringSize = cfg.SKILL_CURSOR_RING_SIZE or 210
	local dotSize = cfg.SKILL_CURSOR_DOT_SIZE or 40
	self._maxRadius = cfg.SKILL_CURSOR_MAX_RADIUS or 110
	self._defaultColor = cfg.SKILL_CURSOR_DEFAULT_COLOR or Color3.fromRGB(43, 194, 255)
	self._cancelColor = cfg.SKILL_CURSOR_CANCEL_COLOR or Color3.fromRGB(248, 47, 47)

	-- ===== 创建 UI =====

	-- 容器 Frame（绝对定位，不影响父容器布局）
	local container = Instance.new("Frame")
	container.Name = "SkillCursorContainer"
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Size = UDim2.fromOffset(ringSize, ringSize)
	container.Position = UDim2.fromOffset(0, 0)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.ZIndex = 60
	container.Parent = parentFrame
	self._container = container

	-- 大圈（描边环 + 半透明填充）
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundColor3 = self._defaultColor
	ring.BackgroundTransparency = 0.85  -- 非常淡的填充
	ring.ZIndex = 61
	ring.Parent = container

	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(0.5, 0)
	ringCorner.Parent = ring

	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = self._defaultColor
	ringStroke.Thickness = 3
	ringStroke.Transparency = 0.2
	ringStroke.Parent = ring
	self._ringStroke = ringStroke
	self._ring = ring

	-- 小圆点（实心圆）
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5) -- 初始居中
	dot.Size = UDim2.fromOffset(dotSize, dotSize)
	dot.BackgroundColor3 = self._defaultColor
	dot.BackgroundTransparency = 0.1
	dot.ZIndex = 62
	dot.Parent = container

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(0.5, 0)
	dotCorner.Parent = dot
	self._dot = dot

	return self
end

--------------------------------------------------------------------------------
-- Show: 在手指按下的屏幕位置显示摇杆
-- screenPos: Vector2 (屏幕坐标)
--------------------------------------------------------------------------------
function SkillCursor:Show(screenPos)
	if not self._container then return end

	self._centerPos = screenPos
	self._isVisible = true
	self._isCancel = false

	-- 将容器中心移到 screenPos（使用 Offset 定位）
	self._container.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
	self._container.Visible = true

	-- 重置小圆点到中心
	self._dot.Position = UDim2.fromScale(0.5, 0.5)

	-- 重置颜色为默认蓝色
	self:_ApplyColor(self._defaultColor)
end

--------------------------------------------------------------------------------
-- UpdateDot: 拖动时更新小圆点位置
-- screenPos: Vector2 (当前手指屏幕坐标)
--------------------------------------------------------------------------------
function SkillCursor:UpdateDot(screenPos)
	if not self._isVisible or not self._container then return end

	-- 计算相对于大圈中心的偏移
	local delta = screenPos - self._centerPos
	local mag = delta.Magnitude

	-- 钳位到最大半径
	if mag > self._maxRadius then
		delta = delta.Unit * self._maxRadius
	end

	-- 将偏移转换为容器内的 Scale 位置
	-- 容器的一半尺寸 = 大圈尺寸 / 2
	local containerAbsSize = self._container.AbsoluteSize
	local halfW = containerAbsSize.X / 2
	local halfH = containerAbsSize.Y / 2

	if halfW > 0 and halfH > 0 then
		local scaleX = 0.5 + delta.X / (halfW * 2)
		local scaleY = 0.5 + delta.Y / (halfH * 2)
		self._dot.Position = UDim2.fromScale(scaleX, scaleY)
	end
end

--------------------------------------------------------------------------------
-- SetCancelState: 切换取消/正常颜色
-- isCancel: boolean
--------------------------------------------------------------------------------
function SkillCursor:SetCancelState(isCancel)
	if not self._isVisible then return end
	if self._isCancel == isCancel then return end  -- 避免重复设置

	self._isCancel = isCancel
	local color = isCancel and self._cancelColor or self._defaultColor
	self:_ApplyColor(color)
end

--------------------------------------------------------------------------------
-- Hide: 隐藏摇杆并重置
--------------------------------------------------------------------------------
function SkillCursor:Hide()
	if not self._container then return end

	self._isVisible = false
	self._isCancel = false
	self._container.Visible = false

	-- 重置小圆点到中心
	self._dot.Position = UDim2.fromScale(0.5, 0.5)
end

--------------------------------------------------------------------------------
-- IsVisible: 查询可见状态
--------------------------------------------------------------------------------
function SkillCursor:IsVisible()
	return self._isVisible
end

--------------------------------------------------------------------------------
-- Destroy: 清理 UI
--------------------------------------------------------------------------------
function SkillCursor:Destroy()
	if self._container then
		pcall(function() self._container:Destroy() end)
		self._container = nil
	end
	self._ring = nil
	self._dot = nil
	self._ringStroke = nil
end

--------------------------------------------------------------------------------
-- 内部方法: 应用颜色到大圈和小圆点
--------------------------------------------------------------------------------
function SkillCursor:_ApplyColor(color)
	pcall(function()
		-- 大圈填充
		self._ring.BackgroundColor3 = color
		-- 大圈描边
		self._ringStroke.Color = color
		-- 小圆点
		self._dot.BackgroundColor3 = color
	end)
end

return SkillCursor
