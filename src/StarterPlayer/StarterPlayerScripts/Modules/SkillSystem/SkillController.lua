-- SkillController: 技能控制器（核心状态机）
-- 路径: StarterPlayerScripts/Modules/SkillSystem/SkillController.lua
-- 职责: Down/Drag/Up 三阶段处理 + 4种目标选择(Target/Pos/Dir/Track) + 防误触判定
--
-- 状态机: Idle → Pressing → Dragging → Released/Cancelled/Buffered → Idle

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillEnums = require(
	ReplicatedStorage:WaitForChild("SkillSystem")
		:WaitForChild("Enums")
		:WaitForChild("SkillEnums")
)

local GlobalConfig = require(
	ReplicatedStorage:WaitForChild("SkillSystem")
		:WaitForChild("Config")
		:WaitForChild("GlobalConfig")
)

local SkillConfigAdapter = require(
	ReplicatedStorage:WaitForChild("SkillSystem")
		:WaitForChild("Config")
		:WaitForChild("SkillConfigAdapter")
)

local IndicatorConfig = require(
	ReplicatedStorage:WaitForChild("SkillSystem")
		:WaitForChild("Config")
		:WaitForChild("IndicatorConfig")
)

local R = SkillEnums.SkillRangeType
local CS = SkillEnums.ControllerState
local GCfg = GlobalConfig

local SC = {}
SC.__index = SC

--------------------------------------------------------------------------------
-- Constructor
-- deps.skillIndicator    : SkillIndicator 实例
-- deps.cancelAreaDetector: CancelAreaDetector 实例
-- deps.skillCacheManager : SkillCacheManager 实例
--------------------------------------------------------------------------------
function SC.new(deps)
	local self = setmetatable({}, SC)

	-- ========== 依赖 ==========
	self._indicator = deps.skillIndicator       -- SkillIndicator 实例
	self._cancelDet = deps.cancelAreaDetector    -- CancelAreaDetector 实例
	self._cache     = deps.skillCacheManager     -- SkillCacheManager 实例

	-- ========== 技能槽位 ==========
	-- [slotType] = { skillId, isEnabled, cooldownEndTime }
	self._slots = {}

	-- ========== 状态机 ==========
	self._state = CS.Idle

	-- ========== 当前操作 ==========
	self._activeSlot = -1
	self._rangeType  = 0
	self._indCfg     = nil

	-- ========== 按下记录 ==========
	self._pressStart  = 0
	self._pressPos    = Vector2.zero
	self._btnCenter   = Vector2.zero
	self._pressTime   = 0
	self._hasDragged  = false
	self._controlMove = false

	-- ========== 目标结果 ==========
	self._targetPos   = Vector3.zero
	self._targetDir   = Vector3.zero
	self._targetActor = 0
	self._rotateFlag  = false
	self._moveFlag    = false

	-- ========== 释放状态 ==========
	self._casting   = false
	self._castSlot  = -1

	-- ========== Heartbeat ==========
	self._hbConn = nil
	self._frame  = 0

	-- ========== Track 专用 ==========
	self._trackPts    = nil
	self._lastTrackPt = Vector3.zero

	-- ========== 回调 ==========
	-- 外部注入: function(param) — 发送技能释放请求
	self._onSkillFire = nil

	return self
end

--------------------------------------------------------------------------------
-- 公共: 设置技能槽位数据
--------------------------------------------------------------------------------
function SC:SetSkillSlot(slot, data)
	self._slots[slot] = data
end

--------------------------------------------------------------------------------
-- 公共: 获取技能槽位数据
--------------------------------------------------------------------------------
function SC:GetSkillSlot(slot)
	return self._slots[slot]
end

--------------------------------------------------------------------------------
-- 公共: 设置技能释放回调
--------------------------------------------------------------------------------
function SC:SetOnSkillFire(callback)
	self._onSkillFire = callback
end

--------------------------------------------------------------------------------
-- 公共: 通知技能释放完毕
--------------------------------------------------------------------------------
function SC:OnSkillCastFinished(slot)
	if self._castSlot == slot then
		self._casting = false
		self._castSlot = -1
		if self._cache then
			self._cache:TryUseCache()
		end
	elseif self._casting then
		-- 安全保底: castSlot 不匹配但 _casting 仍为 true
		-- (可能因 Auto 型快速连按覆盖了 _castSlot)
		-- 也清除释放锁，防止永久卡死
		self._casting = false
		self._castSlot = -1
		if self._cache then
			self._cache:TryUseCache()
		end
	end
end

--------------------------------------------------------------------------------
-- 公共: 获取当前状态
--------------------------------------------------------------------------------
function SC:GetState()
	return self._state
end

--------------------------------------------------------------------------------
-- 公共: 获取当前激活的槽位
--------------------------------------------------------------------------------
function SC:GetActiveSlot()
	return self._activeSlot
end

--------------------------------------------------------------------------------
-- 公共: 获取指定槽位的 rangeType（供 SkillButtonManager 判断是否为 Auto 型）
-- 返回 rangeType 数字，找不到返回 nil
--------------------------------------------------------------------------------
function SC:GetSlotRangeType(slot)
	local sd = self._slots[slot]
	if not sd then return nil end
	local sk = SkillConfigAdapter[sd.skillId]
	if not sk then return nil end
	return sk.rangeType
end

--------------------------------------------------------------------------------
-- 公共: 是否正在释放技能
--------------------------------------------------------------------------------
function SC:IsCasting()
	return self._casting
end

--------------------------------------------------------------------------------
-- ======================= 阶段一: OnButtonDown =======================
--------------------------------------------------------------------------------
function SC:OnButtonDown(slot, screenPos, btnCenter)
	-- ① 校验槽位
	local sd = self._slots[slot]
	if not sd or not sd.isEnabled then return end
	if sd.cooldownEndTime and sd.cooldownEndTime > os.clock() then return end

	-- 查配置
	local sk = SkillConfigAdapter[sd.skillId]
	if not sk then
		warn("[SkillController] SkillConfig not found for skillId:", sd.skillId)
		return
	end

	-- ② Auto 型: 按下即释放，无指示器
	if sk.rangeType == R.Auto then
		self:_Execute(slot, {
			slotType  = slot,
			skillId   = sd.skillId,
			rangeType = R.Auto,
			targetPosition  = self:_CharPos(),
			targetDirection = self:_CharLookDir(),
			targetActorId   = 0,
		})
		return
	end

	-- ②b SelfRange 型: 与 Auto 类似但需要显示范围圈指示器
	-- 不立刻释放，进入 Pressing 状态，松手时释放
	if sk.rangeType == R.SelfRange then
		-- 清除旧的 casting 锁（用户主动按了新技能 = 想使用新技能）
		if self._casting then
			self._casting = false
			self._castSlot = -1
		end

		-- 记录上下文
		self._activeSlot  = slot
		self._rangeType   = sk.rangeType
		self._pressStart  = os.clock()
		self._pressPos    = screenPos
		self._btnCenter   = btnCenter
		self._pressTime   = 0
		self._hasDragged  = false
		self._controlMove = false
		self._rotateFlag  = false
		self._moveFlag    = false
		self._targetPos   = self:_CharPos()
		self._targetDir   = self:_CharLookDir()
		self._targetActor = 0
		self._trackPts    = nil

		-- 加载指示器: 需要动态覆写范围圈大小
		local baseCfg = IndicatorConfig[sk.indicatorCfgId]
		if baseCfg then
			-- 浅拷贝一份，用技能的 selfRangeRadius 覆写 guideDistance
			local cfgCopy = {}
			for k, v in pairs(baseCfg) do cfgCopy[k] = v end
			if sk.selfRangeRadius then
				cfgCopy.guideDistance = sk.selfRangeRadius
			end
			self._indCfg = cfgCopy
			if self._indicator then
				self._indicator:Enable(slot, cfgCopy)
			end
		else
			warn("[SkillController] SelfRange 指示器配置未找到: cfgId=", sk.indicatorCfgId)
		end

		-- 通知取消检测器
		if self._cancelDet then
			self._cancelDet:SetPressStart(screenPos)
		end

		-- 启动 Heartbeat
		self:_StartHB()

		-- 进入 Pressing 状态
		self._state = CS.Pressing
		return
	end

	-- ③ 当前正在释放技能
	-- 对于需要指示器的技能(Target/Pos/Directional)，允许立即进入 Pressing 显示指示器
	-- 用户主动按了新技能按钮 = 明确想使用新技能，清除旧的 casting 锁
	if self._casting then
		self._casting = false
		self._castSlot = -1
	end

	-- ④ 记录上下文
	self._activeSlot  = slot
	self._rangeType   = sk.rangeType
	self._pressStart  = os.clock()
	self._pressPos    = screenPos
	self._btnCenter   = btnCenter
	self._pressTime   = 0
	self._hasDragged  = false
	self._controlMove = false
	self._rotateFlag  = false
	self._moveFlag    = false
	self._targetPos   = Vector3.zero
	self._targetDir   = Vector3.zero
	self._targetActor = 0
	self._trackPts    = nil

	-- ⑤ 加载指示器配置并启用
	self._indCfg = IndicatorConfig[sk.indicatorCfgId]
	if self._indCfg and self._indicator then
		self._indicator:Enable(slot, self._indCfg)
	else
		warn("[SkillController] 指示器未启用: indCfg=", self._indCfg ~= nil, "indicator=", self._indicator ~= nil, "cfgId=", sk.indicatorCfgId)
	end

	-- ⑥ 通知取消检测器
	if self._cancelDet then
		self._cancelDet:SetPressStart(screenPos)
	end

	-- ⑦ 启动 Heartbeat
	self:_StartHB()

	-- ⑧ 状态切换
	self._state = CS.Pressing
end

--------------------------------------------------------------------------------
-- ======================= 阶段二: OnButtonDrag =======================
--------------------------------------------------------------------------------
function SC:OnButtonDrag(slot, screenPos, btnCenter)
	-- 守卫
	if self._state ~= CS.Pressing and self._state ~= CS.Dragging then return end
	if slot ~= self._activeSlot then return end

	-- ① 计算拖动向量（屏幕空间）
	local delta = screenPos - btnCenter
	local mag = delta.Magnitude
	local axis = mag > 0.001 and (delta / mag) or Vector2.zero

	-- ② 拖动判定
	if mag > GCfg.DRAG_THRESHOLD and not self._hasDragged then
		self._hasDragged = true
		self._state = CS.Dragging
	end

	-- ③ 归一化偏移 (0~1)
	local maxR = GCfg.MAX_DRAG_RADIUS
	local normOff = math.clamp(mag / maxR, 0, 1)

	-- ④ 目标选择
	self:_SelectSkillTarget(self._rangeType, axis, normOff)

	-- ⑤ 指示器位置更新
	if self._indCfg and self._indicator then
		self._indicator:UpdatePosition(
			self._targetPos,
			self._targetDir,
			self._moveFlag,
			self._rotateFlag
		)
	end

	-- ⑥ 取消区域检测
	if self._cancelDet then
		self._cancelDet:Update(screenPos)

		-- 取消视觉反馈
		if self._indicator then
			local cs = self._cancelDet:GetState()
			self._indicator:SetCancelVisual(cs.isInCancelArea)
		end
	end
end

--------------------------------------------------------------------------------
-- ======================= 阶段三: OnButtonUp =======================
--------------------------------------------------------------------------------
function SC:OnButtonUp(slot, screenPos)
	-- 守卫
	if self._state ~= CS.Pressing and self._state ~= CS.Dragging then return end
	if slot ~= self._activeSlot then return end

	-- ① 最后一次 Drag（用抬手位置再算一次目标）
	self:OnButtonDrag(slot, screenPos, self._btnCenter)

	-- ② 按压时长（秒）
	local dur = os.clock() - self._pressStart

	-- ③ 取消判定
	if self._cancelDet then
		local cs = self._cancelDet:GetState()
		local bNoCancel = (not cs.isInCancelArea)
			or (cs.timeInCancelArea <= GCfg.CANCEL_AREA_STAY_THRESHOLD)

		if not bNoCancel then
			self:_Cancel()
			return
		end
	end

	-- ④ 防误触判定
	if not self:_IsAllowUseSkill(self._rangeType, dur) then
		self:_Cancel()
		return
	end

	-- ⑤ 构建 SkillParam
	local sd = self._slots[slot]
	if not sd then
		self:_Cancel()
		return
	end

	local param = {
		slotType        = slot,
		skillId         = sd.skillId,
		rangeType       = self._rangeType,
		targetPosition  = self._targetPos,
		targetDirection = self._targetDir,
		targetActorId   = self._targetActor,
		trackPoints     = self._trackPts,
	}

	-- ⑥ 执行（尝试释放或缓冲）
	self:_Execute(slot, param)

	-- ⑦ 清理
	self:_Cleanup()
end

--------------------------------------------------------------------------------
-- ======================= 目标选择 =======================
--------------------------------------------------------------------------------
function SC:_SelectSkillTarget(rt, axis, normOff)
	if     rt == R.Target      then self:_ST_Target(axis, normOff)
	elseif rt == R.Pos         then self:_ST_Pos(axis, normOff)
	elseif rt == R.Directional then self:_ST_Dir(axis, normOff)
	elseif rt == R.Track       then self:_ST_Track(axis, normOff)
	elseif rt == R.SelfRange   then self:_ST_SelfRange()
	end
	self:_RefreshIndicatorShow(normOff)
end

-- Target 型: 简易(normOff≤0.5) vs 高级(normOff>0.5) 模式
function SC:_ST_Target(axis, normOff)
	local gd = self._indCfg and self._indCfg.guideDistance or 10
	local wDir = self:_AxisToWorld(axis)
	local offset = wDir * (gd * normOff)
	local cPos = self:_CharPos()

	self._targetPos = cPos + offset
	self._rotateFlag = true
	self._moveFlag = false

	if offset.Magnitude > 0.01 then
		self._targetDir = offset.Unit
	end

	-- 简易 vs 高级模式
	local advanced = normOff > GCfg.TARGET_MODE_SWITCH_THRESHOLD

	if advanced then
		-- 高级模式: 以 targetPos 为圆心搜索
		self._targetActor = self:_FindEnemy(
			self._targetPos,
			self._indCfg and self._indCfg.effectRadius or 3
		)
	else
		-- 简易模式: 以角色位置为圆心搜索最近目标
		self._targetActor = self:_FindEnemy(cPos, gd)
		if self._targetActor ~= 0 then
			self._targetPos = self:_ActorPos(self._targetActor)
		end
	end
end

-- Pos 型: 拖动选择落点
function SC:_ST_Pos(axis, normOff)
	local gd = self._indCfg and self._indCfg.guideDistance or 12
	local wDir = self:_AxisToWorld(axis)
	local offset = wDir * (gd * normOff)
	local cPos = self:_CharPos()

	self._targetPos = cPos + offset
	self._moveFlag = true
	self._rotateFlag = true

	-- controlMove: 拖超 5% → 标记有效拖动
	if normOff > GCfg.POS_CONTROL_MOVE_THRESHOLD then
		self._controlMove = true
	end

	if offset.Magnitude > 0.01 then
		self._targetDir = offset.Unit
	end
end

-- Directional 型: 拖动选择方向
function SC:_ST_Dir(axis, normOff)
	local wDir = self:_AxisToWorld(axis)

	if wDir.Magnitude > 0.01 then
		self._targetDir = wDir.Unit
	end

	-- 位置始终是角色脚下
	self._targetPos = self:_CharPos()
	self._rotateFlag = true
	self._moveFlag = false
end

-- Track 型: 绘制轨迹（预留）
function SC:_ST_Track(axis, normOff)
	local gd = self._indCfg and self._indCfg.guideDistance or 10
	local wDir = self:_AxisToWorld(axis)
	local cPos = self:_CharPos()
	local pt = cPos + wDir * (gd * normOff)

	self._targetPos = pt

	if not self._trackPts then
		self._trackPts = {}
		self._lastTrackPt = cPos
	end

	-- 间距≥1 stud 才记录
	if (pt - self._lastTrackPt).Magnitude >= GCfg.TRACK_MIN_POINT_DISTANCE then
		if #self._trackPts < GCfg.TRACK_MAX_POINTS then
			table.insert(self._trackPts, pt)
			self._lastTrackPt = pt
		end
	end

	self._moveFlag = true
	self._rotateFlag = false

	-- 方向 = 轨迹末两点的连线方向
	local n = #self._trackPts
	if n >= 2 then
		local d = self._trackPts[n] - self._trackPts[n - 1]
		if d.Magnitude > 0.01 then
			self._targetDir = d.Unit
		end
	end
end

-- SelfRange 型: 始终以角色位置为目标，无拖动选择
function SC:_ST_SelfRange()
	self._targetPos = self:_CharPos()
	self._targetDir = self:_CharLookDir()
	self._moveFlag = false
	self._rotateFlag = false
end

--------------------------------------------------------------------------------
-- ======================= 防误触 =======================
--------------------------------------------------------------------------------
function SC:_IsAllowUseSkill(rangeType, pressDuration)
	-- Pos 型: 未拖动+按压≤1秒 → 误触
	if rangeType == R.Pos then
		if not self._controlMove and pressDuration <= GCfg.POS_PRESS_TIME_THRESHOLD then
			return false
		end
	end

	-- Directional 型: 快速点击 → 使用角色当前朝向
	if rangeType == R.Directional then
		if pressDuration <= GCfg.DIR_QUICK_TAP_THRESHOLD then
			if self._targetDir.Magnitude < 0.01 then
				local lookDir = self:_CharLookDir()
				self._targetDir = lookDir
			end
		end
	end

	return true
end

--------------------------------------------------------------------------------
-- ======================= 指示器刷新 =======================
--------------------------------------------------------------------------------
function SC:_RefreshIndicatorShow(normOff)
	if not self._indicator or not self._indCfg then return end
	local L = SkillEnums.IndicatorLayer
	local cfg = self._indCfg
	if cfg.guideEnabled then
		self._indicator:SetLayerVisible(L.Guide, true)
	end
	if cfg.effectEnabled then
		self._indicator:SetLayerVisible(L.Effect, normOff > 0.05)
	end
	if cfg.fixedEnabled then
		self._indicator:SetLayerVisible(L.Fixed, true)
	end
end

--------------------------------------------------------------------------------
-- ======================= 内部方法 =======================
--------------------------------------------------------------------------------

-- Heartbeat: 驱动 pressTime 累加 + 指示器 Tick
-- 内含超时保护: 按下超过 INDICATOR_TIMEOUT 秒自动清理（防 Touch 丢失）
local INDICATOR_TIMEOUT = 10  -- 秒

function SC:_StartHB()
	if self._hbConn then return end
	self._frame = 0
	self._hbConn = RunService.Heartbeat:Connect(function(dt)
		if self._state == CS.Idle then return end
		self._pressTime = self._pressTime + dt  -- 秒
		self._frame = self._frame + 1

		-- 超时保护: 防止 Touch 丢失后指示器永远留在屏幕上
		if self._pressTime > INDICATOR_TIMEOUT then
			warn("[SkillController] Indicator timeout after " .. INDICATOR_TIMEOUT .. "s, force cleanup")
			self:_Cleanup()
			return
		end

		-- 节流
		if self._frame % GCfg.INDICATOR_UPDATE_INTERVAL ~= 0 then return end
		if self._indicator then
			self._indicator:Tick(dt)
		end
	end)
end

function SC:_StopHB()
	if self._hbConn then
		self._hbConn:Disconnect()
		self._hbConn = nil
	end
end

-- 执行: 尝试释放或缓冲
-- 释放后设 _casting=true 锁定，等服务端 SyncCooldownEvent 或 SkillCastFinishedEvent 解锁
-- 超时保底: 3 秒后自动解锁，防止服务端无响应导致永久卡死
local CAST_LOCK_TIMEOUT = 3

function SC:_Execute(slot, param)
	if self._cache then
		-- 使用缓冲管理器
		if self._cache:TryExecuteOrBuffer(param) then
			self._casting = true
			self._castSlot = slot
		end
	else
		-- 无缓冲管理器时直接发送
		if self._onSkillFire then
			self._onSkillFire(param)
		end
		self._casting = true
		self._castSlot = slot
	end

	-- 超时保底: 防止服务端未回复导致永久锁定
	if self._casting then
		task.delay(CAST_LOCK_TIMEOUT, function()
			if self._casting and self._castSlot == slot then
				warn("[SkillController] Cast lock timeout for slot", slot, "- force releasing")
				self._casting = false
				self._castSlot = -1
				if self._cache then
					self._cache:TryUseCache()
				end
			end
		end)
	end
end

-- 取消
function SC:_Cancel()
	self:_Cleanup()
end

-- 清理: 关闭指示器、重置取消检测、停止 Heartbeat
-- 注意顺序: 先停 Heartbeat 再清理指示器，防止 Disable 后的下一帧 Tick 竞态
function SC:_Cleanup()
	self:_StopHB()
	if self._indicator then
		self._indicator:Disable()
	end
	if self._cancelDet then
		self._cancelDet:Reset()
	end
	self._state = CS.Idle
	self._activeSlot = -1
	self._indCfg = nil
	self._hasDragged = false
	self._controlMove = false
end

--------------------------------------------------------------------------------
-- ======================= 辅助方法 =======================
--------------------------------------------------------------------------------

-- 屏幕2D轴 → 世界XZ方向
function SC:_AxisToWorld(axis)
	local cam = workspace.CurrentCamera
	if not cam then
		return Vector3.new(axis.X, 0, -axis.Y)
	end
	local look = cam.CFrame.LookVector
	local fwd = Vector3.new(look.X, 0, look.Z)
	if fwd.Magnitude < 0.001 then
		return Vector3.new(axis.X, 0, -axis.Y)
	end
	fwd = fwd.Unit
	local rt = Vector3.new(-fwd.Z, 0, fwd.X)  -- 右方向 = fwd 绕Y轴顺时针90°
	local w = rt * axis.X + fwd * (-axis.Y)
	return w.Magnitude > 0.01 and w.Unit or Vector3.zero
end

-- 获取角色位置
function SC:_CharPos()
	local c = Players.LocalPlayer and Players.LocalPlayer.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return r and r.Position or Vector3.zero
end

-- 获取角色朝向
function SC:_CharLookDir()
	local c = Players.LocalPlayer and Players.LocalPlayer.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if r then
		return r.CFrame.LookVector
	end
	return Vector3.new(0, 0, 1)
end

-- 搜索敌方（接入角色管理系统）
-- 返回最近敌方的 Model 或 nil
function SC:_FindEnemy(pos, radius)
	-- 遍历所有角色，找最近的敌方
	local localPlayer = Players.LocalPlayer
	if not localPlayer then return 0 end

	local localTeam = localPlayer.Team

	local bestDist = radius
	local bestId = 0

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer then
			-- 队伍检测: 不同队伍或无队伍
			local isEnemy = (not localTeam) or (player.Team ~= localTeam)
			if isEnemy then
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then
					local dist = (hrp.Position - pos).Magnitude
					if dist <= bestDist then
						bestDist = dist
						bestId = player.UserId
					end
				end
			end
		end
	end

	-- 也检查假人（名为 "Dummy" 或有 "IsDummy" 属性的模型）
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		for _, dummy in ipairs(dummies:GetChildren()) do
			local hrp = dummy:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dist = (hrp.Position - pos).Magnitude
				if dist <= bestDist then
					bestDist = dist
					bestId = -1  -- 用 -1 表示假人
				end
			end
		end
	end

	return bestId
end

-- 获取 Actor 位置
function SC:_ActorPos(id)
	if id == 0 then return Vector3.zero end

	-- 假人
	if id == -1 then
		local dummies = workspace:FindFirstChild("Dummies")
		if dummies then
			for _, dummy in ipairs(dummies:GetChildren()) do
				local hrp = dummy:FindFirstChild("HumanoidRootPart")
				if hrp then return hrp.Position end
			end
		end
		return Vector3.zero
	end

	-- 真实玩家
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == id then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then return hrp.Position end
		end
	end

	return Vector3.zero
end

-- Destroy: 清理所有连接
function SC:Destroy()
	self:_Cleanup()
end

return SC
