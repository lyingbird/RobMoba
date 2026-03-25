-- CancelAreaDetector: 取消区域检测
-- 路径: StarterPlayerScripts/Modules/SkillSystem/CancelAreaDetector.lua
-- 职责: 检测手指是否在取消区域内，支持 AreaCancel 和 DistanceCancel 两种模式

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HapticService = game:GetService("HapticService")

local GlobalConfig = require(
	ReplicatedStorage:WaitForChild("SkillSystem")
		:WaitForChild("Config")
		:WaitForChild("GlobalConfig")
)

local CAD = {}
CAD.__index = CAD

function CAD.new(cancelFrame)
	local self = setmetatable({}, CAD)

	self._frame = cancelFrame            -- 取消区域 Frame UI 引用（可为 nil）
	self._inArea = false                 -- 当前是否在取消区域内
	self._time = 0                       -- 停留累计时间（秒）
	self._vibrated = false               -- 是否已触发过震动
	self._hbConn = nil                   -- Heartbeat 连接
	self._lastScreenPos = Vector2.zero
	self._pressStartScreenPos = Vector2.zero

	return self
end

-- SetCancelFrame: 动态设置取消区域 Frame（UI 可能延迟创建）
function CAD:SetCancelFrame(frame)
	self._frame = frame
end

-- SetPressStart: 在 OnButtonDown 时调用，记录按下位置
function CAD:SetPressStart(pos)
	self._pressStartScreenPos = pos
end

-- Update: 每次 Drag 调用，检测取消状态
function CAD:Update(screenPos)
	self._lastScreenPos = screenPos

	-- 模式1: AreaCancel — 屏幕坐标在 CancelFrame UI 范围内
	local areaIn = self:_IsInFrame(screenPos)

	-- 模式2: DistanceCancel — 拖动总距离超过阈值
	local distIn = (screenPos - self._pressStartScreenPos).Magnitude
		> GlobalConfig.CANCEL_DISTANCE_THRESHOLD

	local nowIn = areaIn or distIn

	-- 状态切换
	if nowIn and not self._inArea then
		-- 刚进入取消区域
		self._inArea = true
		self._time = 0
		self._vibrated = false
		self:_StartTimer()

	elseif not nowIn and self._inArea then
		-- 离开取消区域
		self._inArea = false
		self._time = 0
		self:_StopTimer()
	end
end

-- GetState: 获取当前状态，由 SkillController.OnButtonUp() 调用
function CAD:GetState()
	return {
		isInCancelArea = self._inArea,
		timeInCancelArea = self._time,
		hasTriggeredVibration = self._vibrated,
	}
end

-- ShouldCancel: 便捷方法 — 是否应取消技能
-- 取消条件: 在取消区域内 且 停留时间超过阈值
function CAD:ShouldCancel()
	return self._inArea and self._time > GlobalConfig.CANCEL_AREA_STAY_THRESHOLD
end

-- Reset: 重置状态
function CAD:Reset()
	self._inArea = false
	self._time = 0
	self._vibrated = false
	self:_StopTimer()
end

--------------------------------------------------------------------------------
-- 内部方法
--------------------------------------------------------------------------------

-- 判断屏幕坐标是否在 Frame UI 内
function CAD:_IsInFrame(pos)
	if not self._frame then return false end
	local ok, result = pcall(function()
		local ap = self._frame.AbsolutePosition
		local as = self._frame.AbsoluteSize
		return pos.X >= ap.X and pos.X <= ap.X + as.X
			and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
	end)
	if ok then return result end
	return false
end

-- 启动停留计时器
function CAD:_StartTimer()
	if self._hbConn then return end
	self._hbConn = RunService.Heartbeat:Connect(function(dt)
		if self._inArea then
			self._time += dt
			-- 首次超过阈值时触发震动
			if self._time > GlobalConfig.CANCEL_AREA_STAY_THRESHOLD and not self._vibrated then
				self._vibrated = true
				pcall(function()
					HapticService:SetMotor(
						Enum.UserInputType.Gamepad1,
						Enum.VibrationMotor.Small,
						0.5
					)
					task.delay(0.1, function()
						pcall(function()
							HapticService:SetMotor(
								Enum.UserInputType.Gamepad1,
								Enum.VibrationMotor.Small,
								0
							)
						end)
					end)
				end)
			end
		end
	end)
end

-- 停止计时器
function CAD:_StopTimer()
	if self._hbConn then
		self._hbConn:Disconnect()
		self._hbConn = nil
	end
end

-- Destroy: 清理
function CAD:Destroy()
	self:_StopTimer()
end

return CAD
