-- SkillButtonManager: 技能按钮管理器
-- 路径: StarterPlayerScripts/Modules/SkillSystem/SkillButtonManager.lua
-- 职责: UI 按钮绑定 → 事件分发(Down/Drag/Up) → SkillController/CommonAttackController
--       + 取消 UI 刷新 + 按钮状态管理(CD/禁用)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GlobalConfig = require(
	ReplicatedStorage:WaitForChild("SkillSystem")
		:WaitForChild("Config")
		:WaitForChild("GlobalConfig")
)

local SBM = {}
SBM.__index = SBM

-- 按钮按压动画参数
local BTN_PRESS_SCALE = 0.85          -- 按下时缩放到 85%
local BTN_PRESS_TWEEN_INFO = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BTN_RELEASE_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- 活跃的按钮 Tween (用于冲突时取消)
local activeTweens = {}  -- [slotType] = Tween

--------------------------------------------------------------------------------
-- Constructor
-- deps.skillController       : SkillController 实例
-- deps.commonAttackController: CommonAttackController 实例
-- deps.inputAdapter          : InputAdapter 实例
-- deps.cancelAreaDetector    : CancelAreaDetector 实例
--------------------------------------------------------------------------------
function SBM.new(deps)
	local self = setmetatable({}, SBM)

	-- 依赖
	self._skillCtrl = deps.skillController
	self._atkCtrl   = deps.commonAttackController
	self._input     = deps.inputAdapter
	self._cancelDet = deps.cancelAreaDetector

	-- UI 引用
	self._buttons    = {}     -- [slotType] = GuiButton
	self._btnCenters = {}     -- [slotType] = Vector2 (按钮中心屏幕坐标)
	self._btnOriginalSizes = {} -- [slotType] = UDim2 (按钮原始大小,用于动画恢复)
	self._activeSlot = -1     -- 当前按下的槽位
	self._prevPressedSlot = nil -- 上一个按下的槽位(用于防止遗漏 release)
	self._cancelTips = nil    -- 取消视觉按钮 (CancelBtnVisual)
	self._cancelFrame = nil   -- 取消碰撞区 Frame (CancelArea)

	-- 技能摇杆
	self._skillCursor = nil  -- SkillCursor 实例（由 SkillSystemInit 注入）

	-- 连接列表（用于清理）
	self._connections = {}

	return self
end

--------------------------------------------------------------------------------
-- SetSkillCursor: 注入 SkillCursor 实例
--------------------------------------------------------------------------------
function SBM:SetSkillCursor(skillCursor)
	self._skillCursor = skillCursor
end

--------------------------------------------------------------------------------
-- Init: 初始化按钮绑定和回调注册
-- buttonMap: { [slotType] = GuiButton }
-- cancelUI:  { CancelFrame = Frame, CancelTips = ImageLabel } 或 nil
--------------------------------------------------------------------------------
function SBM:Init(buttonMap, cancelUI)
	if cancelUI then
		self._cancelTips = cancelUI.CancelTips     -- 视觉按钮 (CancelBtnVisual)
		self._cancelFrame = cancelUI.CancelFrame   -- 碰撞区 Frame (CancelArea)
		if cancelUI.CancelFrame and self._cancelDet then
			self._cancelDet:SetCancelFrame(cancelUI.CancelFrame)
		end
	end

	-- 为每个按钮绑定输入事件
	for slotType, btn in pairs(buttonMap) do
		self._buttons[slotType] = btn
		self._btnOriginalSizes[slotType] = btn.Size  -- 记录原始大小(用于动画恢复)

		-- 计算按钮中心
		self:_UpdateBtnCenter(slotType, btn)

		-- 监听位置变化以更新中心（适配横竖屏切换）
		local posConn = btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			self:_UpdateBtnCenter(slotType, btn)
		end)
		table.insert(self._connections, posConn)

		-- 绑定按下事件
		-- 关键保护: 当已有技能在拖拽中(_activeSlot >= 0 且 InputAdapter 正在追踪),
		-- 忽略其他按钮的 InputBegan，防止手指滑过 W/切换英雄等 UI 时错误触发
		local downConn = btn.InputBegan:Connect(function(inputObject)
			if inputObject.UserInputType == Enum.UserInputType.Touch
				or inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
				-- 如果已有技能在拖拽中，忽略新的按钮按下
				if self._activeSlot >= 0 and self._input and self._input:IsTracking() then
					return
				end
				self._activeSlot = slotType
				if self._input then
					self._input:BeginTracking(inputObject)
				end
			end
		end)
		table.insert(self._connections, downConn)
	end

	-- 注册 InputAdapter 回调
	if self._input then
		-- 确保输入监听已启动
		self._input:Start()
		self._input.onInputBegan = function(screenPos)
			self:_OnDown(self._activeSlot, screenPos)
		end

		self._input.onInputChanged = function(screenPos)
			if self._activeSlot >= 0 then
				self:_OnDrag(self._activeSlot, screenPos)
			end
		end

		self._input.onInputEnded = function(screenPos)
			if self._activeSlot >= 0 then
				self:_OnUp(self._activeSlot, screenPos)
				self._activeSlot = -1
			end
		end
	end
end

--------------------------------------------------------------------------------
-- _OnDown: 按下
--------------------------------------------------------------------------------
function SBM:_OnDown(slot, screenPos)
	-- 安全保护: 如果上一个 slot 还在激活状态，先恢复其按钮大小
	-- 防止快速连按/多指时上一个按钮卡在缩小状态
	if self._prevPressedSlot and self._prevPressedSlot ~= slot then
		self:_AnimateButtonRelease(self._prevPressedSlot)
	end
	self._prevPressedSlot = slot

	-- 按下缩放动画
	self:_AnimateButtonPress(slot)

	-- 普攻走独立控制器
	if slot == 0 then
		if self._atkCtrl then
			self._atkCtrl:OnButtonDown()
		end
		return
	end

	-- 分发给 SkillController（它内部会调用 cancelDet:SetPressStart）
	if self._skillCtrl then
		self._skillCtrl:OnButtonDown(slot, screenPos, self._btnCenters[slot])
	end

	-- Auto 型技能在 OnButtonDown 内部已经按下即释放，不需要显示取消UI和技能摇杆
	-- 注意: 不用 GetState()=="Idle" 判断，因为冷却中/释放中等情况也会导致状态为 Idle
	local slotRangeType = self._skillCtrl and self._skillCtrl:GetSlotRangeType(slot)
	if slotRangeType == 0 then  -- SkillRangeType.Auto == 0
		-- 恢复按钮大小（按下动画已播，需要恢复）
		self:_AnimateButtonRelease(slot)
		self._prevPressedSlot = nil
		return
	end

	-- 技能按下后显示取消按钮（普攻不显示，已在上面 return）
	self:_ShowCancelButton()

	-- 显示技能摇杆（在手指按下位置）
	if self._skillCursor then
		self._skillCursor:Show(screenPos)
	end
end

--------------------------------------------------------------------------------
-- _OnDrag: 拖动
--------------------------------------------------------------------------------
function SBM:_OnDrag(slot, screenPos)
	if slot == 0 then
		if self._atkCtrl then
			self._atkCtrl:OnButtonDrag(screenPos)
		end
		return
	end

	-- 分发给 SkillController
	if self._skillCtrl then
		self._skillCtrl:OnButtonDrag(slot, screenPos, self._btnCenters[slot])
	end

	-- 刷新取消区域 UI
	self:_RefreshCancelUI()

	-- 更新技能摇杆小圆点位置 + 取消颜色
	if self._skillCursor then
		self._skillCursor:UpdateDot(screenPos)
		-- 同步取消状态颜色（与 CancelAreaDetector 一致）
		if self._cancelDet then
			local cancelState = self._cancelDet:GetState()
			self._skillCursor:SetCancelState(cancelState.isInCancelArea)
		end
	end
end

--------------------------------------------------------------------------------
-- _OnUp: 抬起
--------------------------------------------------------------------------------
function SBM:_OnUp(slot, screenPos)
	-- 抬起恢复动画
	self:_AnimateButtonRelease(slot)
	self._prevPressedSlot = nil

	if slot == 0 then
		if self._atkCtrl then
			self._atkCtrl:OnButtonUp()
		end
		return
	end

	if self._skillCtrl then
		self._skillCtrl:OnButtonUp(slot, screenPos)
	end

	-- 隐藏取消按钮
	self:_HideCancelButton()

	-- 隐藏技能摇杆
	if self._skillCursor then
		self._skillCursor:Hide()
	end
end

--------------------------------------------------------------------------------
-- _ShowCancelButton: 技能按下时显示取消按钮并重置为默认状态
--------------------------------------------------------------------------------
function SBM:_ShowCancelButton()
	pcall(function()
		if self._cancelFrame then
			self._cancelFrame.Visible = true
		end
		if self._cancelTips then
			self._cancelTips.BackgroundColor3 = Color3.fromRGB(60, 60, 60)  -- 默认灰底
			self._cancelTips.BackgroundTransparency = 0.2
		end
	end)
end

--------------------------------------------------------------------------------
-- _HideCancelButton: 松手/取消后隐藏取消按钮
--------------------------------------------------------------------------------
function SBM:_HideCancelButton()
	pcall(function()
		if self._cancelFrame then
			self._cancelFrame.Visible = false
		end
	end)
end

--------------------------------------------------------------------------------
-- _RefreshCancelUI: 刷新取消按钮视觉反馈
-- 手指拖入取消区域 → 红色; 停留>阈值 → 深红; 不在区域 → 默认灰色
--------------------------------------------------------------------------------
function SBM:_RefreshCancelUI()
	if not self._cancelTips or not self._cancelDet then return end

	local cancelState = self._cancelDet:GetState()

	pcall(function()
		if cancelState.isInCancelArea then
			if cancelState.timeInCancelArea > GlobalConfig.CANCEL_AREA_STAY_THRESHOLD then
				-- 停留超过阈值 → 深红（确认取消状态）
				self._cancelTips.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
				self._cancelTips.BackgroundTransparency = 0.05
			else
				-- 刚进入取消区域 → 红色
				self._cancelTips.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
				self._cancelTips.BackgroundTransparency = 0.1
			end
		else
			-- 不在取消区域 → 恢复默认灰色
			self._cancelTips.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			self._cancelTips.BackgroundTransparency = 0.2
		end
	end)
end

--------------------------------------------------------------------------------
-- _AnimateButtonPress: 按下时缩小按钮（触感反馈）
--------------------------------------------------------------------------------
function SBM:_AnimateButtonPress(slot)
	local btn = self._buttons[slot]
	if not btn then return end

	-- 取消同一按钮上残留的 Tween（防止冲突）
	if activeTweens[slot] then
		pcall(function() activeTweens[slot]:Cancel() end)
		activeTweens[slot] = nil
	end

	-- 使用 _btnOriginalSizes 而非 btn.Size 计算目标大小
	-- 防止连续按下时 btn.Size 已是缩小值导致累计缩小
	local origSize = self._btnOriginalSizes and self._btnOriginalSizes[slot]
	if not origSize then return end

	pcall(function()
		local tween = TweenService:Create(btn, BTN_PRESS_TWEEN_INFO, {
			Size = UDim2.new(
				origSize.X.Scale * BTN_PRESS_SCALE, 0,
				origSize.Y.Scale * BTN_PRESS_SCALE, 0
			),
		})
		activeTweens[slot] = tween
		tween:Play()
	end)
end

--------------------------------------------------------------------------------
-- _AnimateButtonRelease: 抬起时恢复按钮大小（带弹性）
--------------------------------------------------------------------------------
function SBM:_AnimateButtonRelease(slot)
	local btn = self._buttons[slot]
	if not btn then return end

	-- 取消同一按钮上残留的 Tween（防止 press tween 还在播就 release）
	if activeTweens[slot] then
		pcall(function() activeTweens[slot]:Cancel() end)
		activeTweens[slot] = nil
	end

	-- 从 _btnOriginalSizes 恢复原始大小
	local origSize = self._btnOriginalSizes and self._btnOriginalSizes[slot]
	if not origSize then return end
	pcall(function()
		local tween = TweenService:Create(btn, BTN_RELEASE_TWEEN_INFO, {
			Size = origSize,
		})
		activeTweens[slot] = tween
		tween:Play()
	end)
end

--------------------------------------------------------------------------------
-- _UpdateBtnCenter: 更新按钮中心坐标
--------------------------------------------------------------------------------
function SBM:_UpdateBtnCenter(slotType, btn)
	pcall(function()
		self._btnCenters[slotType] = Vector2.new(
			btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2,
			btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2
		)
	end)
end

--------------------------------------------------------------------------------
-- RefreshButtonCenters: 外部手动刷新所有按钮中心
--------------------------------------------------------------------------------
function SBM:RefreshButtonCenters()
	for slotType, btn in pairs(self._buttons) do
		self:_UpdateBtnCenter(slotType, btn)
	end
end

--------------------------------------------------------------------------------
-- SetSlotEnabled: 控制单个技能槽位的启用/禁用
--------------------------------------------------------------------------------
function SBM:SetSlotEnabled(slotType, enabled)
	if self._skillCtrl then
		local slot = self._skillCtrl:GetSkillSlot(slotType)
		if slot then
			slot.isEnabled = enabled
		end
	end
end

--------------------------------------------------------------------------------
-- UpdateCooldown: 更新技能冷却结束时间
--------------------------------------------------------------------------------
function SBM:UpdateCooldown(slotType, cooldownEndTime)
	if self._skillCtrl then
		local slot = self._skillCtrl:GetSkillSlot(slotType)
		if slot then
			slot.cooldownEndTime = cooldownEndTime
		end
	end
end

--------------------------------------------------------------------------------
-- Destroy: 清理所有连接和按钮 UI
--------------------------------------------------------------------------------
function SBM:Destroy()
	-- 停止 InputAdapter 监听（断开全局 UserInputService 连接）
	if self._input and self._input.Destroy then
		pcall(function() self._input:Destroy() end)
	end

	for _, conn in ipairs(self._connections) do
		if conn.Disconnect then
			conn:Disconnect()
		end
	end
	self._connections = {}

	-- 取消所有活跃 Tween
	for slot, tween in pairs(activeTweens) do
		pcall(function() tween:Cancel() end)
		activeTweens[slot] = nil
	end

	-- 销毁技能摇杆
	if self._skillCursor then
		pcall(function() self._skillCursor:Destroy() end)
		self._skillCursor = nil
	end

	-- 销毁按钮 UI 实例
	for slotType, btn in pairs(self._buttons) do
		pcall(function() btn:Destroy() end)
	end
	self._buttons = {}
	self._btnCenters = {}
	self._btnOriginalSizes = {}
end

return SBM
