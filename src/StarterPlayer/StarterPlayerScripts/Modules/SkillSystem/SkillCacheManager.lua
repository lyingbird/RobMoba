-- SkillCacheManager: 技能缓冲区管理
-- 路径: StarterPlayerScripts/Modules/SkillSystem/SkillCacheManager.lua
-- 职责: 技能缓冲队列 + 普攻缓冲 + 连续普攻窗口 + 受控保护
--
-- 核心问题: 当前技能还在释放中，玩家按了下一个技能怎么办？ → 缓存起来

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(
	ReplicatedStorage:WaitForChild("SkillSystem")
		:WaitForChild("Config")
		:WaitForChild("GlobalConfig")
)

local GCfg = GlobalConfig

local SCM = {}
SCM.__index = SCM

--------------------------------------------------------------------------------
-- Constructor
-- deps.skillRemoteEvent : RemoteEvent 引用
-- deps.getSlotFunc      : function(slotType) → SkillSlot
-- deps.onExecuteCallback: function(skillParam) 通知外部
--------------------------------------------------------------------------------
function SCM.new(deps)
	local self = setmetatable({}, SCM)

	-- ========== 依赖 ==========
	self._remoteEvent = deps.skillRemoteEvent
	self._getSlot     = deps.getSlotFunc
	self._onExecute   = deps.onExecuteCallback

	-- ========== 技能缓冲队列 ==========
	self._cacheList = {}
	self._maxCount  = GCfg.SKILL_CACHE_MAX_COUNT

	-- ========== 普攻缓冲 ==========
	self._cacheCommonAttack = false
	self._cacheContinueCommonAttack = false

	-- ========== 连续普攻窗口 ==========
	self._continueWindowBegin = 0
	self._continueWindowEnd   = 0
	self._pursueWindowBegin   = 0

	-- ========== 缓存窗口 ==========
	self._cacheWindowActive    = false
	self._cacheWindowBeginTime = 0

	-- ========== 过期 ==========
	self._lastCacheTick = 0

	-- ========== 受控保护 ==========
	self._controlProtectExpire = 0

	-- ========== 可释放标记 ==========
	self._canCast = true

	return self
end

--------------------------------------------------------------------------------
-- TryExecuteOrBuffer: 主入口
-- 当前可释放 → 直接发送; 否则 → 缓冲
-- 返回 true = 已释放, false = 已缓冲
--------------------------------------------------------------------------------
function SCM:TryExecuteOrBuffer(param)
	if self._canCast then
		self:_FireSkill(param)
		return true
	else
		self:PushToCache({
			skillParam = param,
			timestamp = os.clock(),
			isCommonAttack = (param.slotType == 0),
		})
		return false
	end
end

--------------------------------------------------------------------------------
-- PushToCache: 入队
-- 两种模式: 覆盖(窗口未生效) vs 追加(窗口已生效)
--------------------------------------------------------------------------------
function SCM:PushToCache(entry)
	-- 普攻走独立标记通道
	if entry.isCommonAttack then
		self._cacheCommonAttack = true
		return
	end

	self._lastCacheTick = os.clock()

	if not self._cacheWindowActive
		or os.clock() < self._cacheWindowBeginTime then
		-- 覆盖模式: 只保留最新1个
		self._cacheList = {}
		table.insert(self._cacheList, entry)
	else
		-- 追加模式: 队列未满则追加
		if #self._cacheList < self._maxCount then
			table.insert(self._cacheList, entry)
		end
	end
end

--------------------------------------------------------------------------------
-- TryUseCache: 出队
-- 优先级: 普攻 > 技能
-- 由 SkillController.OnSkillCastFinished() 调用
--------------------------------------------------------------------------------
function SCM:TryUseCache()
	-- ① 过期检查
	if self:_IsExpired() then
		self:Clear()
		return
	end

	-- ② 普攻缓存优先
	if self._cacheCommonAttack then
		self._cacheCommonAttack = false
		self:_FireSkill({
			slotType  = 0,
			skillId   = 0,
			rangeType = 0,
		})
		return
	end

	-- ③ 技能缓存
	if #self._cacheList > 0 then
		local entry = table.remove(self._cacheList, 1)  -- FIFO
		-- 校验槽位
		if self._getSlot then
			local slot = self._getSlot(entry.skillParam.slotType)
			if slot and slot.isEnabled then
				self:_FireSkill(entry.skillParam)
			end
		else
			self:_FireSkill(entry.skillParam)
		end
		return
	end

	-- ④ 队列为空
end

--------------------------------------------------------------------------------
-- 连续普攻窗口
--------------------------------------------------------------------------------
function SCM:SetContinueAttackWindow(attackCD)
	local now = os.clock()
	local beginPct  = GCfg.CONTINUE_ATTACK_WINDOW_BEGIN_PCT / 100
	local pursuePct = GCfg.CONTINUE_PURSUE_WINDOW_BEGIN_PCT / 100
	local frameDelta = 1 / 60 * 2  -- 2帧裕度

	self._continueWindowBegin = now + attackCD * beginPct
	self._continueWindowEnd   = now + attackCD + frameDelta
	self._pursueWindowBegin   = now + attackCD * pursuePct
end

function SCM:IsInContinueAttackWindow()
	local now = os.clock()
	return now >= self._continueWindowBegin and now < self._continueWindowEnd
end

function SCM:SetContinueCommonAttackCache()
	if self:IsInContinueAttackWindow() then
		self._cacheContinueCommonAttack = true
	end
end

--------------------------------------------------------------------------------
-- 受控保护
--------------------------------------------------------------------------------
function SCM:OnControlStart()
	if self._cacheWindowActive then
		self._controlProtectExpire = os.clock() + GCfg.CONTROL_PROTECT_DURATION
	end
end

function SCM:OnControlEnd()
	if os.clock() <= self._controlProtectExpire then
		self:TryUseCache()
	else
		self:Clear()
	end
end

--------------------------------------------------------------------------------
-- 缓存窗口控制
--------------------------------------------------------------------------------
function SCM:EnableCacheWindow()
	self._cacheWindowActive = true
	self._cacheWindowBeginTime = os.clock()
end

function SCM:DisableCacheWindow()
	self._cacheWindowActive = false
end

--------------------------------------------------------------------------------
-- 可释放标记
--------------------------------------------------------------------------------
function SCM:SetCanCast(can)
	self._canCast = can
end

function SCM:CanCast()
	return self._canCast
end

--------------------------------------------------------------------------------
-- SetCommonAttackCache: 标记普攻缓冲（公共接口）
--------------------------------------------------------------------------------
function SCM:SetCommonAttackCache()
	self._cacheCommonAttack = true
end

--------------------------------------------------------------------------------
-- Clear: 清空所有缓存
--------------------------------------------------------------------------------
function SCM:Clear()
	self._cacheList = {}
	self._cacheCommonAttack = false
	self._cacheContinueCommonAttack = false
end

--------------------------------------------------------------------------------
-- 内部方法
--------------------------------------------------------------------------------

function SCM:_IsExpired()
	if self._lastCacheTick == 0 then return false end
	return (os.clock() - self._lastCacheTick) > GCfg.SKILL_CACHE_EXPIRED_TIME
end

function SCM:_FireSkill(param)
	-- 发送到服务端
	if self._remoteEvent then
		self._remoteEvent:FireServer(param)
	end
	-- 通知外部回调
	if self._onExecute then
		self._onExecute(param)
	end
end

-- Destroy: 清理
function SCM:Destroy()
	self:Clear()
end

return SCM
