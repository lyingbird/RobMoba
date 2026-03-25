-- CommonAttackController: 普攻控制器
-- 路径: StarterPlayerScripts/Modules/SkillSystem/CommonAttackController.lua
-- 职责: 普攻按钮 Down/Drag/Up 处理 + 索敌 + 缓冲协调
--
-- 精简策略: 只保留基础索敌（最近目标），去掉4种精准索敌策略

local Players = game:GetService("Players")

local CAC = {}
CAC.__index = CAC

--------------------------------------------------------------------------------
-- Constructor
-- deps.skillCacheManager  : SkillCacheManager 引用
-- deps.attackRemoteEvent  : 普攻 RemoteEvent
-- deps.findEnemyFunc      : function(pos, radius) → targetId (可选)
--------------------------------------------------------------------------------
function CAC.new(deps)
	local self = setmetatable({}, CAC)

	self._cache       = deps.skillCacheManager
	self._remoteEvent = deps.attackRemoteEvent
	self._findEnemy   = deps.findEnemyFunc

	self._isAttacking = false
	self._attackRange = 8  -- 默认普攻范围（studs）

	return self
end

--------------------------------------------------------------------------------
-- SetAttackRange: 更新普攻范围（由英雄数据决定）
--------------------------------------------------------------------------------
function CAC:SetAttackRange(range)
	self._attackRange = range or 8
end

--------------------------------------------------------------------------------
-- OnButtonDown: 按下普攻按钮
--------------------------------------------------------------------------------
function CAC:OnButtonDown()
	-- 如果当前不可释放（技能释放中）→ 标记普攻缓冲
	if self._cache and not self._cache:CanCast() then
		self._cache:SetCommonAttackCache()
		return
	end

	-- 检查连续普攻窗口
	if self._cache and self._cache:IsInContinueAttackWindow() then
		self._cache:SetContinueCommonAttackCache()
	end

	self:_DoAttack()
end

--------------------------------------------------------------------------------
-- OnButtonDrag: 普攻拖动（预留 — 高级版可做目标选择）
--------------------------------------------------------------------------------
function CAC:OnButtonDrag(screenPos)
	-- 预留接口
end

--------------------------------------------------------------------------------
-- OnButtonUp: 普攻抬起
--------------------------------------------------------------------------------
function CAC:OnButtonUp()
	-- 预留接口
end

--------------------------------------------------------------------------------
-- _DoAttack: 执行普攻
-- 发送到服务端，服务端做实际的索敌和伤害计算
--------------------------------------------------------------------------------
function CAC:_DoAttack()
	local charPos = self:_CharPos()
	local lookDir = self:_CharLookDir()

	local param = {
		slotType  = 0,
		skillId   = 0,
		rangeType = 0,
		targetPosition  = charPos + lookDir * self._attackRange,
		targetDirection = lookDir,
		targetActorId   = 0,
	}

	-- 客户端侧索敌（辅助定位，服务端会重新验证）
	if self._findEnemy then
		local targetId = self._findEnemy(charPos, self._attackRange)
		if targetId and targetId ~= 0 then
			param.targetActorId = targetId
		end
	end

	-- 发送
	if self._remoteEvent then
		self._remoteEvent:FireServer(param)
	end

	-- 通知缓冲管理器
	if self._cache then
		self._cache:SetCanCast(false)
	end

	self._isAttacking = true
end

--------------------------------------------------------------------------------
-- OnAttackFinished: 普攻完成回调
-- 由服务端或动画结束事件触发
--------------------------------------------------------------------------------
function CAC:OnAttackFinished(attackCD)
	self._isAttacking = false

	if self._cache then
		self._cache:SetCanCast(true)
		-- 设置连续普攻窗口
		if attackCD and attackCD > 0 then
			self._cache:SetContinueAttackWindow(attackCD)
		end
		-- 尝试释放缓冲
		self._cache:TryUseCache()
	end
end

--------------------------------------------------------------------------------
-- IsAttacking
--------------------------------------------------------------------------------
function CAC:IsAttacking()
	return self._isAttacking
end

--------------------------------------------------------------------------------
-- 辅助
--------------------------------------------------------------------------------
function CAC:_CharPos()
	local c = Players.LocalPlayer and Players.LocalPlayer.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return r and r.Position or Vector3.zero
end

function CAC:_CharLookDir()
	local c = Players.LocalPlayer and Players.LocalPlayer.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if r then return r.CFrame.LookVector end
	return Vector3.new(0, 0, 1)
end

-- Destroy: 清理
function CAC:Destroy()
	-- 无持久连接需要清理
end

return CAC
