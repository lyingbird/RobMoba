-- SkillIndicator: 技能指示器
-- 路径: StarterPlayerScripts/Modules/SkillSystem/SkillIndicator.lua
-- 职责: 三层 Part 生命周期管理 + 位置/方向平滑插值

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

local SI = {}
SI.__index = SI

function SI.new(deps)
	local self = setmetatable({}, SI)
	self._renderer = deps.indicatorRenderer   -- IndicatorRenderer 实例

	-- 三层资源引用
	self._guide  = nil   -- BasePart: Guide 层
	self._effect = nil   -- BasePart: Effect 层
	self._fixed  = nil   -- BasePart: Fixed 层

	-- 配置
	self._config = nil   -- 当前 IndicatorConfig 条目
	self._active = false

	-- 平滑插值状态
	self._curPos = Vector3.zero
	self._curDir = Vector3.new(0, 0, 1)
	self._tgtPos = Vector3.zero
	self._tgtDir = Vector3.new(0, 0, 1)

	return self
end

--------------------------------------------------------------------------------
-- Enable: 按下技能按钮时创建三层指示器
-- slot: SkillSlot 数据
-- cfg: IndicatorConfig 条目
--------------------------------------------------------------------------------
function SI:Enable(slot, cfg)
	-- 如果已有激活指示器，先清理
	if self._active then
		self:Disable()
	end

	self._config = cfg
	self._active = true
	local cPos = self:_CPos()

	-- Guide 层: 最大施法范围圆
	if cfg.guideEnabled then
		self._guide = self._renderer:Create(
			SkillEnums.IndicatorLayer.Guide,
			cfg.guideResType,
			{ radius = cfg.guideDistance, angle = 360 }
		)
		self._renderer:SetPos(self._guide, cPos)
		self._renderer:Show(self._guide, true)
	end

	-- Fixed 层: 固定脚下指示器
	if cfg.fixedEnabled then
		self._fixed = self._renderer:Create(
			SkillEnums.IndicatorLayer.Fixed,
			cfg.fixedResType,
			{ radius = cfg.guideDistance, angle = 360 }
		)
		self._renderer:SetPos(self._fixed, cPos)
		self._renderer:Show(self._fixed, true)
	end

	-- Effect 层: 技能作用范围（初始隐藏，等 Drag 再显示）
	if cfg.effectEnabled then
		self._effect = self._renderer:Create(
			SkillEnums.IndicatorLayer.Effect,
			cfg.effectResType,
			{
				radius = cfg.effectRadius,
				angle  = cfg.effectAngle,
				width  = cfg.effectWidth,
				length = cfg.effectLength,
			}
		)
		self._renderer:Show(self._effect, false)  -- 初始隐藏
	end

	self._curPos = cPos
	self._tgtPos = cPos
end

--------------------------------------------------------------------------------
-- Disable: 抬起/取消时销毁所有层
--------------------------------------------------------------------------------
function SI:Disable()
	self._active = false

	-- 安全销毁三层（即使某层已为 nil 也不报错）
	local function safeDestroy(layerName, obj)
		if not obj then return end
		local ok, err = pcall(function()
			self._renderer:Destroy(obj)
		end)
		if not ok then
			warn("[SkillIndicator] Destroy " .. layerName .. " failed: " .. tostring(err))
		end
	end

	safeDestroy("guide", self._guide)
	self._guide = nil

	safeDestroy("effect", self._effect)
	self._effect = nil

	safeDestroy("fixed", self._fixed)
	self._fixed = nil

	self._config = nil
end

--------------------------------------------------------------------------------
-- UpdatePosition: 每次 Drag 更新目标位置和方向
-- tPos: 目标位置 (Vector3)
-- tDir: 目标方向 (Vector3)
-- move: Effect 层是否跟随拖动移动 (Pos/Track 型为 true)
-- rotate: Effect 层是否跟随拖动旋转 (Directional/Target 型为 true)
--------------------------------------------------------------------------------
function SI:UpdatePosition(tPos, tDir, move, rotate)
	if not self._active then return end

	local cPos = self:_CPos()

	-- Guide 和 Fixed 始终跟随角色位置
	if self._guide then self._renderer:SetPos(self._guide, cPos) end
	if self._fixed then self._renderer:SetPos(self._fixed, cPos) end

	-- Effect 层目标位置
	self._tgtPos = move and tPos or cPos

	-- Effect 层目标方向
	if rotate and tDir.Magnitude > 0.01 then
		self._tgtDir = tDir
	end

	-- 立即将目标应用到 Effect（减少一帧延迟，提升跟手感）
	if self._effect then
		-- 位置直接 snap 到目标（Tick 中会做平滑插值兜底）
		self._curPos = self._tgtPos
		-- 方向也直接 snap
		if self._tgtDir.Magnitude > 0.01 then
			self._curDir = self._tgtDir
		end
		self._renderer:SetPosRot(self._effect, self._curPos, self._curDir)
	end
end

--------------------------------------------------------------------------------
-- ShowEffect: 显示/隐藏 Effect 层（拖动开始后才显示）
--------------------------------------------------------------------------------
function SI:ShowEffect(visible)
	if self._effect then
		self._renderer:Show(self._effect, visible)
	end
end

--------------------------------------------------------------------------------
-- SetLayerVisible: 按层控制显隐
-- layer: IndicatorLayer 枚举值
-- vis: boolean
--------------------------------------------------------------------------------
function SI:SetLayerVisible(layer, vis)
	local p = ({
		[SkillEnums.IndicatorLayer.Guide]  = self._guide,
		[SkillEnums.IndicatorLayer.Effect] = self._effect,
		[SkillEnums.IndicatorLayer.Fixed]  = self._fixed,
	})[layer]
	if p then
		self._renderer:Show(p, vis)
	end
end

--------------------------------------------------------------------------------
-- SetCancelVisual: 取消区域视觉反馈（红色）
-- inCancel: boolean
--------------------------------------------------------------------------------
function SI:SetCancelVisual(inCancel)
	if not self._active then return end
	local colorKey = inCancel and "Warn" or "Default"
	if self._effect then self._renderer:SetColor(self._effect, colorKey) end
	if self._guide then
		self._renderer:SetColor(self._guide, inCancel and "Warn" or "Guide")
	end
end

--------------------------------------------------------------------------------
-- Tick: Heartbeat 驱动的平滑插值
-- dt: delta time (秒)
--------------------------------------------------------------------------------
function SI:Tick(dt)
	if not self._active then return end

	-- Guide 和 Fixed 层始终跟随角色位置（即使不拖动）
	local cPos = self:_CPos()
	if self._guide then self._renderer:SetPos(self._guide, cPos) end
	if self._fixed then self._renderer:SetPos(self._fixed, cPos) end

	-- Effect 层需要插值
	if not self._effect then return end

	-- 插值系数
	local lerpSpeed = GlobalConfig.INDICATOR_LERP_SPEED or 30
	local dirSpeed = GlobalConfig.DIRECTION_LERP_SPEED or 40
	local tPos = math.clamp(dt * lerpSpeed, 0, 1)
	local tDir = math.clamp(dt * dirSpeed, 0, 1)

	-- 位置插值
	self._curPos = self._curPos:Lerp(self._tgtPos, tPos)

	-- 方向插值
	if self._tgtDir.Magnitude > 0.01 then
		-- 计算当前方向与目标方向的夹角
		local dot = self._curDir:Dot(self._tgtDir)
		dot = math.clamp(dot, -1, 1)

		-- 当角度差较大(>90°)或方向几乎反转时，直接 snap 不做缓慢插值
		if dot < 0.1 then
			self._curDir = self._tgtDir
		else
			local cf0 = CFrame.lookAt(Vector3.zero, self._curDir)
			local cf1 = CFrame.lookAt(Vector3.zero, self._tgtDir)
			self._curDir = cf0:Lerp(cf1, tDir).LookVector
		end
	end

	-- 应用到 Effect Part
	self._renderer:SetPosRot(self._effect, self._curPos, self._curDir)
end

--------------------------------------------------------------------------------
-- IsActive: 是否正在显示
--------------------------------------------------------------------------------
function SI:IsActive()
	return self._active
end

--------------------------------------------------------------------------------
-- GetCurrentPos/Dir: 获取当前插值后的位置/方向（供 SkillController 使用）
--------------------------------------------------------------------------------
function SI:GetCurrentPos()
	return self._curPos
end

function SI:GetCurrentDir()
	return self._curDir
end

--------------------------------------------------------------------------------
-- 内部辅助: 获取角色脚下位置
--------------------------------------------------------------------------------
function SI:_CPos()
	local c = Players.LocalPlayer and Players.LocalPlayer.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return r and r.Position or Vector3.zero
end

return SI
