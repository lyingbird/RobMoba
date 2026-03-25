-- SkillSystemInit: 新技能交互系统的一站式初始化
-- 路径: StarterPlayerScripts/Modules/SkillSystem/SkillSystemInit.lua
--
-- 职责: 组装 SkillSystem 全部模块实例，创建技能按钮 UI，注入依赖，连接 RemoteEvent。
-- 外部（Client.client.lua）只需:
--   local SkillSystemInit = require(...)
--   SkillSystemInit.Init(parentFrame, heroId)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ========== 共享层 ==========
local SkillSystemFolder = ReplicatedStorage:WaitForChild("SkillSystem")
local SkillEnums = require(SkillSystemFolder:WaitForChild("Enums"):WaitForChild("SkillEnums"))
local GlobalConfig = require(SkillSystemFolder:WaitForChild("Config"):WaitForChild("GlobalConfig"))
local SkillConfigAdapter = require(SkillSystemFolder:WaitForChild("Config"):WaitForChild("SkillConfigAdapter"))

-- ========== 客户端模块 ==========
local SkillSystemModules = script.Parent
local InputAdapter = require(SkillSystemModules:WaitForChild("InputAdapter"))
local IndicatorRenderer = require(SkillSystemModules:WaitForChild("IndicatorRenderer"))
local SkillIndicator = require(SkillSystemModules:WaitForChild("SkillIndicator"))
local CancelAreaDetector = require(SkillSystemModules:WaitForChild("CancelAreaDetector"))
local SkillCacheManager = require(SkillSystemModules:WaitForChild("SkillCacheManager"))
local SkillController = require(SkillSystemModules:WaitForChild("SkillController"))
local CommonAttackController = require(SkillSystemModules:WaitForChild("CommonAttackController"))
local SkillButtonManager = require(SkillSystemModules:WaitForChild("SkillButtonManager"))
local SkillCursor = require(SkillSystemModules:WaitForChild("SkillCursor"))

-- ========== 外部依赖 ==========
local HeroRegistry = require(ReplicatedStorage:WaitForChild("HeroRegistry"))
local MobileConfig = require(script.Parent.Parent:WaitForChild("MobileConfig"))

-- ========== slotType → key 反向映射 ==========
local SlotTypeToKey = {}
for key, slotType in pairs(SkillEnums.SlotNameToType) do
	-- 取第一个匹配（Q/W/R 优先于 E）
	if not SlotTypeToKey[slotType] or #key < #SlotTypeToKey[slotType] then
		SlotTypeToKey[slotType] = key
	end
end

-- ========== 模块导出 ==========
local SkillSystemInit = {}

-- 实例引用（供外部获取状态）
local _controller = nil
local _buttonManager = nil
local _cacheManager = nil
local _buttonMap = {}  -- [slotType] = GuiButton (模块级,供 Heartbeat/SwitchHero 共享)
local _initialized = false
local _connections = {} -- RBXScriptConnection 列表

-- 辅助: 计算已配置的槽位数
local function _countSlots(ctrl)
	local count = 0
	for st = 0, 5 do
		if ctrl:GetSkillSlot(st) then count = count + 1 end
	end
	return count
end

--------------------------------------------------------------------------------
-- 按钮配色（与旧 UI_SkillButtons 保持一致）
--------------------------------------------------------------------------------
local BUTTON_COLORS = {
	Attack = { bg = Color3.fromRGB(255, 200, 50),  border = Color3.fromRGB(255, 215, 0),  borderW = 4 },
	Q      = { bg = Color3.fromRGB(40, 80, 160),   border = Color3.fromRGB(100, 150, 255), borderW = 2.5 },
	W      = { bg = Color3.fromRGB(40, 80, 160),   border = Color3.fromRGB(100, 150, 255), borderW = 2.5 },
	R      = { bg = Color3.fromRGB(200, 60, 20),   border = Color3.fromRGB(255, 180, 0),   borderW = 4 },
}

--------------------------------------------------------------------------------
-- 计算弧形按钮位置（与旧 UI_SkillButtons 一致的极坐标算法）
--------------------------------------------------------------------------------
local function computeButtonPositions()
	local positions = {}
	-- 普攻: 绝对位置
	positions.Attack = {
		X = MobileConfig.BTN_ATTACK_POS.X,
		Y = MobileConfig.BTN_ATTACK_POS.Y,
	}
	-- Q/W/R: 以普攻为圆心的极坐标弧形
	local slots = MobileConfig.SKILL_ARC_SLOTS -- {"Q","W","R"}
	local startAngle = MobileConfig.SKILL_ARC_START_ANGLE
	local step = MobileConfig.SKILL_ARC_STEP
	local radius = MobileConfig.SKILL_ARC_RADIUS
	local aspect = MobileConfig.SCREEN_ASPECT_RATIO

	for i, slotKey in ipairs(slots) do
		local angleDeg = startAngle + (i - 1) * step
		local angleRad = math.rad(angleDeg)
		-- 屏幕坐标: 右=0°, 下=90°
		local dx = math.cos(angleRad) * radius / aspect
		local dy = math.sin(angleRad) * radius
		positions[slotKey] = {
			X = positions.Attack.X + dx,
			Y = positions.Attack.Y + dy,
		}
	end
	return positions
end

--------------------------------------------------------------------------------
-- 创建单个圆形技能按钮 UI
--------------------------------------------------------------------------------
local function createSkillButton(parent, slotKey, pos, sizePct)
	local colors = BUTTON_COLORS[slotKey] or BUTTON_COLORS.Q

	local btn = Instance.new("TextButton")
	btn.Name = "SkillBtn_" .. slotKey
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = UDim2.fromScale(pos.X, pos.Y)
	btn.Size = UDim2.new(sizePct, 0, sizePct, 0)
	btn.SizeConstraint = Enum.SizeConstraint.RelativeYY
	btn.BackgroundColor3 = colors.bg
	btn.BackgroundTransparency = 0.15
	btn.Text = slotKey == "Attack" and "A" or slotKey
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.ZIndex = 10
	btn.AutoButtonColor = false
	btn.Parent = parent

	-- 圆角
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = btn

	-- 边框
	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.border
	stroke.Thickness = colors.borderW
	stroke.Transparency = 0.1
	stroke.Parent = btn

	-- 文字内边距（防止文字溢出）
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.2, 0)
	padding.PaddingBottom = UDim.new(0.2, 0)
	padding.PaddingLeft = UDim.new(0.2, 0)
	padding.PaddingRight = UDim.new(0.2, 0)
	padding.Parent = btn

	-- ===== CD冷却遮罩(暗色蒙版 + 倒计时文字) =====
	local cdOverlay = Instance.new("Frame")
	cdOverlay.Name = "CDOverlay"
	cdOverlay.AnchorPoint = Vector2.new(0.5, 0.5)
	cdOverlay.Position = UDim2.fromScale(0.5, 0.5)
	cdOverlay.Size = UDim2.fromScale(1, 1)
	cdOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	cdOverlay.BackgroundTransparency = 0.4
	cdOverlay.ZIndex = 11
	cdOverlay.Visible = false
	cdOverlay.Parent = btn

	local cdCorner = Instance.new("UICorner")
	cdCorner.CornerRadius = UDim.new(0.5, 0)
	cdCorner.Parent = cdOverlay

	local cdText = Instance.new("TextLabel")
	cdText.Name = "CDText"
	cdText.AnchorPoint = Vector2.new(0.5, 0.5)
	cdText.Position = UDim2.fromScale(0.5, 0.5)
	cdText.Size = UDim2.fromScale(0.8, 0.5)
	cdText.BackgroundTransparency = 1
	cdText.Text = ""
	cdText.TextColor3 = Color3.new(1, 1, 1)
	cdText.TextScaled = true
	cdText.Font = Enum.Font.GothamBold
	cdText.TextStrokeTransparency = 0.5
	cdText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	cdText.ZIndex = 12
	cdText.Parent = cdOverlay

	return btn
end

--------------------------------------------------------------------------------
-- 创建取消按钮 UI（右上角醒目的 ✕ 圆形按钮）
-- 技能拖出后显示，手指拖到按钮上松手即取消
--------------------------------------------------------------------------------
local CANCEL_BTN_DEFAULT_BG   = Color3.fromRGB(60, 60, 60)   -- 默认灰底
local CANCEL_BTN_HOVER_BG     = Color3.fromRGB(220, 50, 50)  -- 拖入→红色
local CANCEL_BTN_CONFIRM_BG   = Color3.fromRGB(180, 20, 20)  -- 停留>阈值→深红
local CANCEL_BTN_BORDER_COLOR = Color3.fromRGB(255, 255, 255)

local function createCancelUI(parent)
	-- 外层 Frame（作为碰撞检测区域，比视觉按钮稍大以提高拖入容错）
	local cancelFrame = Instance.new("Frame")
	cancelFrame.Name = "CancelArea"
	cancelFrame.AnchorPoint = Vector2.new(1, 0)
	cancelFrame.Position = UDim2.new(1, -16, 0, 16)  -- 右上角，留 16px 安全边距
	cancelFrame.Size = UDim2.new(0, 80, 0, 80)       -- 80×80 正方形碰撞区
	cancelFrame.BackgroundTransparency = 1            -- 碰撞区本身透明
	cancelFrame.Visible = false                       -- 初始隐藏，技能拖出后才显示
	cancelFrame.ZIndex = 50
	cancelFrame.Parent = parent

	-- 视觉圆形按钮（在碰撞区内居中）
	local btnVisual = Instance.new("Frame")
	btnVisual.Name = "CancelBtnVisual"
	btnVisual.AnchorPoint = Vector2.new(0.5, 0.5)
	btnVisual.Position = UDim2.fromScale(0.5, 0.5)
	btnVisual.Size = UDim2.new(0, 64, 0, 64)         -- 64×64 圆形
	btnVisual.BackgroundColor3 = CANCEL_BTN_DEFAULT_BG
	btnVisual.BackgroundTransparency = 0.2
	btnVisual.ZIndex = 51
	btnVisual.Parent = cancelFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = btnVisual

	local stroke = Instance.new("UIStroke")
	stroke.Color = CANCEL_BTN_BORDER_COLOR
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = btnVisual

	-- ✕ 文字
	local xLabel = Instance.new("TextLabel")
	xLabel.Name = "XLabel"
	xLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	xLabel.Position = UDim2.fromScale(0.5, 0.42)     -- 略偏上，视觉居中
	xLabel.Size = UDim2.fromScale(0.6, 0.5)
	xLabel.BackgroundTransparency = 1
	xLabel.Text = "✕"
	xLabel.TextColor3 = Color3.new(1, 1, 1)
	xLabel.TextScaled = true
	xLabel.Font = Enum.Font.GothamBold
	xLabel.TextTransparency = 0
	xLabel.ZIndex = 52
	xLabel.Parent = btnVisual

	-- "取消" 文字（在 ✕ 下方）
	local cancelText = Instance.new("TextLabel")
	cancelText.Name = "CancelText"
	cancelText.AnchorPoint = Vector2.new(0.5, 0)
	cancelText.Position = UDim2.fromScale(0.5, 0.68)
	cancelText.Size = UDim2.fromScale(1, 0.26)
	cancelText.BackgroundTransparency = 1
	cancelText.Text = "取消"
	cancelText.TextColor3 = Color3.new(1, 1, 1)
	cancelText.TextScaled = true
	cancelText.Font = Enum.Font.GothamBold
	cancelText.TextTransparency = 0.2
	cancelText.ZIndex = 52
	cancelText.Parent = btnVisual

	return {
		CancelFrame = cancelFrame,       -- 碰撞检测区域（CancelAreaDetector 使用）
		CancelTips = btnVisual,           -- 视觉按钮（SkillButtonManager 控制颜色）
	}
end

--------------------------------------------------------------------------------
-- Init: 一站式初始化
-- parentFrame: ScreenGui 下的 Frame（技能按钮容器）
-- heroId: 当前英雄 ID（用于加载技能槽位数据）
--
-- 返回: boolean, string? (成功标志, 错误信息)
--------------------------------------------------------------------------------
function SkillSystemInit.Init(parentFrame, heroId)
	if _initialized then
		warn("[SkillSystemInit] 已初始化，跳过重复调用")
		return true
	end

	-- ① 获取英雄技能配置
	local heroData = HeroRegistry[heroId]
	if not heroData or not heroData.Skills then
		warn("[SkillSystemInit] 英雄数据不存在:", heroId)
		return false, "英雄数据不存在"
	end

	-- ② 获取 RemoteEvent
	local CastSkillEvent = ReplicatedStorage:WaitForChild("CastSkillEvent", 5)
	local AttackTargetEvent = ReplicatedStorage:WaitForChild("AttackTargetEvent", 5)
	local SkillCastFinishedEvent = ReplicatedStorage:WaitForChild("SkillCastFinishedEvent", 5)

	if not CastSkillEvent then
		warn("[SkillSystemInit] CastSkillEvent 未找到")
		return false, "CastSkillEvent 未找到"
	end

	-- ③ 创建模块实例（按依赖顺序）
	local renderer = IndicatorRenderer.new()
	local indicator = SkillIndicator.new({ indicatorRenderer = renderer })
	local cancelDet = CancelAreaDetector.new(nil) -- cancelFrame 后续设置

	-- SkillCacheManager: 负责缓冲和发送
	-- 关键: _FireSkill 中需要将新格式转换为旧服务端协议
	local cache = SkillCacheManager.new({
		skillRemoteEvent = CastSkillEvent,
		getSlotFunc = function(slotType)
			if _controller then
				return _controller:GetSkillSlot(slotType)
			end
			return nil
		end,
		onExecuteCallback = nil, -- 在 _FireSkill 中已经 FireServer 了
	})

	-- ④ 重写 SkillCacheManager 的 _FireSkill 方法
	-- 转换: 新 param 表 → 旧服务端协议 (key, targetPos)
	function cache:_FireSkill(param)
		if not param then return end

		-- 普攻走 AttackTargetEvent
		if param.slotType == 0 then
			if AttackTargetEvent then
				-- 服务端 AttackTargetEvent 期望 (target: Model?)
				-- 我们发送 nil，让服务端自己索敌
				AttackTargetEvent:FireServer(nil)
			end
			if self._onExecute then self._onExecute(param) end
			return
		end

		-- 技能: 转换 slotType → key 字符串
		local key = SlotTypeToKey[param.slotType]
		if not key then
			warn("[SkillSystemInit] 无法反查 slotType → key:", param.slotType)
			return
		end

		-- 目标位置: 优先 targetPosition，Directional 型用角色位置+方向
		local targetPos = param.targetPosition or Vector3.zero
		if param.rangeType == SkillEnums.SkillRangeType.Directional then
			-- Directional 技能: 服务端期望 targetPos 为方向向量（或前方某点）
			local dir = param.targetDirection or Vector3.new(0, 0, 1)
			local c = Players.LocalPlayer and Players.LocalPlayer.Character
			local hrp = c and c:FindFirstChild("HumanoidRootPart")
			if hrp then
				targetPos = hrp.Position + dir * 50
			end
		end

		-- 发送到服务端
		if self._remoteEvent then
			self._remoteEvent:FireServer(key, targetPos)
		end

		if self._onExecute then self._onExecute(param) end
	end

	local controller = SkillController.new({
		skillIndicator = indicator,
		cancelAreaDetector = cancelDet,
		skillCacheManager = cache,
	})
	_controller = controller

	-- ⑤ 配置技能槽位
	for key, skillId in pairs(heroData.Skills) do
		local slotType = SkillEnums.SlotNameToType[key]
		if slotType then
			controller:SetSkillSlot(slotType, {
				skillId = skillId,
				isEnabled = true,
				cooldownEndTime = 0,
			})
		end
	end

	-- ⑥ 普攻控制器
	local atkCtrl = CommonAttackController.new({
		skillCacheManager = cache,
		attackRemoteEvent = AttackTargetEvent,
		findEnemyFunc = function(pos, radius)
			return controller:_FindEnemy(pos, radius)
		end,
	})

	-- 设置普攻范围（从英雄配置获取）
	local attackRange = 8
	if heroData.Skills and heroData.Skills["Attack"] then
		local atkData = SkillConfigAdapter[heroData.Skills["Attack"]]
		if atkData then
			attackRange = atkData.castRange or 8
		end
	end
	atkCtrl:SetAttackRange(attackRange)

	-- ⑦ 输入适配器
	local inputAdapter = InputAdapter.new()

	-- ⑧ 按钮管理器
	local btnMgr = SkillButtonManager.new({
		skillController = controller,
		commonAttackController = atkCtrl,
		inputAdapter = inputAdapter,
		cancelAreaDetector = cancelDet,
	})
	_buttonManager = btnMgr
	_cacheManager = cache

	-- ⑨ 创建技能按钮 UI
	local buttonPositions = computeButtonPositions()
	local buttonMap = {} -- [slotType] = GuiButton

	-- 普攻按钮 (slotType = 0)
	local atkBtn = createSkillButton(
		parentFrame, "Attack",
		buttonPositions.Attack,
		MobileConfig.SKILL_BTN_ATTACK
	)
	buttonMap[0] = atkBtn

	-- Q/W/R 技能按钮
	for key, slotType in pairs(SkillEnums.SlotNameToType) do
		if buttonPositions[key] and heroData.Skills[key] then
			local sizePct = MobileConfig.BTN_SIZES[key] or MobileConfig.SKILL_BTN_NORMAL
			local btn = createSkillButton(parentFrame, key, buttonPositions[key], sizePct)
			buttonMap[slotType] = btn
		end
	end

	-- 同步到模块级变量（供 Heartbeat CD 遍历 + SwitchHero 使用）
	_buttonMap = buttonMap

	-- ⑩ 创建取消 UI
	local cancelUI = createCancelUI(parentFrame)

	-- ⑪ 初始化按钮管理器（绑定 UI → 事件分发）
	btnMgr:Init(buttonMap, cancelUI)

	-- ⑪.5 创建并注入技能摇杆（移动端技能操控反馈）
	local skillCursor = SkillCursor.new(parentFrame)
	btnMgr:SetSkillCursor(skillCursor)

	-- ⑫ 设置技能释放回调（通知外部）
	controller:SetOnSkillFire(function(param)
		-- 直接发送（由 _FireSkill 处理格式转换）
		cache:_FireSkill(param)
	end)

	-- ⑬ 监听服务端技能释放完毕通知
	if SkillCastFinishedEvent then
		local conn = SkillCastFinishedEvent.OnClientEvent:Connect(function(data)
			if data and data.slotType then
				controller:OnSkillCastFinished(data.slotType)
			elseif data and data.key then
				-- 兼容: 旧格式用 key 字符串
				local st = SkillEnums.SlotNameToType[data.key]
				if st then
					controller:OnSkillCastFinished(st)
				end
			end
		end)
		table.insert(_connections, conn)
	end

	-- ⑭ 监听服务端冷却同步
	local SyncCooldownEvent = ReplicatedStorage:FindFirstChild("SyncCooldownEvent")
	if SyncCooldownEvent then
		local conn = SyncCooldownEvent.OnClientEvent:Connect(function(key, cd, skillId)
			-- REQ-009: "ALL" 标记 = 训练场CD开关，重置所有槽位CD + 清除释放锁
			if key == "ALL" then
				for st = 0, 5 do
					local slot = controller:GetSkillSlot(st)
					if slot then
						slot.cooldownEndTime = 0
					end
				end
				-- 清除 _casting 锁，防止无CD快速连按后卡死
				controller._casting = false
				controller._castSlot = -1
				if cache then cache:Clear() end
				-- 立即刷新所有按钮 CD 遮罩（不等 Heartbeat 节流）
				for _, btn in pairs(_buttonMap) do
					local cdOverlay = btn:FindFirstChild("CDOverlay")
					if cdOverlay and cdOverlay.Visible then
						cdOverlay.Visible = false
						local cdTextLabel = cdOverlay:FindFirstChild("CDText")
						if cdTextLabel then
							cdTextLabel.Text = ""
						end
					end
				end
				return
			end

			local slotType = SkillEnums.SlotNameToType[key]
			if slotType and controller then
				local slot = controller:GetSkillSlot(slotType)
				if slot then
					slot.cooldownEndTime = os.clock() + (cd or 0)
				end
			end
			-- 也通知 SkillCastFinished（CD 开始意味着技能已释放完毕）
			if slotType then
				controller:OnSkillCastFinished(slotType)
			end
		end)
		table.insert(_connections, conn)
	end

	-- ⑮ CC控制联动: 监听 Humanoid 的 CanCastSkill/CanAutoAttack 属性
	-- 服务端 EffectExecutor 设置这些属性控制被控(眩晕/沉默/缴械)状态
	local function _bindCCListeners(char)
		local hum = char:WaitForChild("Humanoid", 5)
		if not hum then return end

		-- CanCastSkill: false→禁用Q/W/R, true→恢复
		local ccConn1 = hum:GetAttributeChangedSignal("CanCastSkill"):Connect(function()
			local canCast = hum:GetAttribute("CanCastSkill")
			if btnMgr then
				for st = 1, 5 do
					btnMgr:SetSlotEnabled(st, canCast ~= false)
				end
			end
			-- 同步 SkillCacheManager 的可释放标记
			if cache then
				cache:SetCanCast(canCast ~= false)
			end
		end)
		table.insert(_connections, ccConn1)

		-- CanAutoAttack: false→禁用普攻(slotType=0), true→恢复
		local ccConn2 = hum:GetAttributeChangedSignal("CanAutoAttack"):Connect(function()
			local canAttack = hum:GetAttribute("CanAutoAttack")
			if btnMgr then
				btnMgr:SetSlotEnabled(0, canAttack ~= false)
			end
		end)
		table.insert(_connections, ccConn2)

		-- 死亡: 禁用所有技能
		local deathConn = hum.Died:Connect(function()
			if btnMgr then
				for st = 0, 5 do
					btnMgr:SetSlotEnabled(st, false)
				end
			end
		end)
		table.insert(_connections, deathConn)
	end

	-- 当前角色
	local localPlayer = Players.LocalPlayer
	local currentChar = localPlayer and localPlayer.Character
	if currentChar then
		task.spawn(_bindCCListeners, currentChar)
	end

	-- 未来角色(重生后重新绑定)
	if localPlayer then
		local charConn = localPlayer.CharacterAdded:Connect(function(newChar)
			task.spawn(function()
				_bindCCListeners(newChar)
				-- 重生后恢复所有技能启用
				if btnMgr then
					for st = 0, 5 do
						btnMgr:SetSlotEnabled(st, true)
					end
				end
			end)
		end)
		table.insert(_connections, charConn)
	end

	-- ⑯ CD冷却UI更新: Heartbeat 驱动按钮冷却遮罩
	local CD_UPDATE_INTERVAL = 3 -- 每3帧更新一次(节流)
	local cdFrame = 0
	local cdHBConn = RunService.Heartbeat:Connect(function()
		cdFrame = cdFrame + 1
		if cdFrame % CD_UPDATE_INTERVAL ~= 0 then return end
		if not _controller or not _buttonMap then return end

		local now = os.clock()
		for slotType, btn in pairs(_buttonMap) do
			local cdOverlay = btn:FindFirstChild("CDOverlay")
			if cdOverlay then
				local slot = _controller:GetSkillSlot(slotType)
				if slot and slot.cooldownEndTime and slot.cooldownEndTime > now then
					-- 在冷却中: 显示遮罩 + 倒计时
					cdOverlay.Visible = true
					local remaining = slot.cooldownEndTime - now
					local cdTextLabel = cdOverlay:FindFirstChild("CDText")
					if cdTextLabel then
						if remaining >= 1 then
							cdTextLabel.Text = string.format("%.0f", math.ceil(remaining))
						else
							cdTextLabel.Text = string.format("%.1f", remaining)
						end
					end
				else
					-- 不在冷却中: 隐藏遮罩
					if cdOverlay.Visible then
						cdOverlay.Visible = false
						local cdTextLabel = cdOverlay:FindFirstChild("CDText")
						if cdTextLabel then
							cdTextLabel.Text = ""
						end
					end
				end
			end
		end
	end)
	table.insert(_connections, cdHBConn)

	_initialized = true
	print("[SkillSystemInit] 新技能系统初始化完成 | 英雄:", heroId, "| 槽位数:", _countSlots(controller))
	return true
end

--------------------------------------------------------------------------------
-- SwitchHero: 切换英雄时重新配置技能槽位和按钮（不重建整个系统）
-- 只更新 SkillController 槽位数据 + 重建按钮 UI
-- parentFrame: 技能按钮容器（MobileFrame）
-- heroId: 新英雄 ID
--------------------------------------------------------------------------------
function SkillSystemInit.SwitchHero(parentFrame, heroId)
	if not _initialized then
		warn("[SkillSystemInit] 未初始化，无法切换英雄，请先调用 Init")
		return false, "未初始化"
	end

	local heroData = HeroRegistry[heroId]
	if not heroData or not heroData.Skills then
		warn("[SkillSystemInit] 切换英雄失败，英雄数据不存在:", heroId)
		return false, "英雄数据不存在"
	end

	-- ① 清除旧槽位
	if _controller then
		for st = 0, 5 do
			_controller:SetSkillSlot(st, nil)
		end
		-- 清除释放锁
		_controller._casting = false
		_controller._castSlot = -1
	end

	-- ② 配置新技能槽位
	for key, skillId in pairs(heroData.Skills) do
		local slotType = SkillEnums.SlotNameToType[key]
		if slotType and _controller then
			_controller:SetSkillSlot(slotType, {
				skillId = skillId,
				isEnabled = true,
				cooldownEndTime = 0,
			})
		end
	end

	-- ③ 清除缓冲队列
	if _cacheManager then
		_cacheManager:Clear()
	end

	-- ④ 销毁旧按钮 UI 并重建
	if _buttonManager then
		_buttonManager:Destroy()
	end

	-- 清理旧的 CancelArea（由 createCancelUI 创建，直接挂在 parentFrame 下）
	local oldCancel = parentFrame:FindFirstChild("CancelArea")
	if oldCancel then
		oldCancel:Destroy()
	end

	-- 重新计算按钮位置
	local buttonPositions = computeButtonPositions()
	local buttonMap = {}

	-- 普攻按钮 (slotType = 0)
	local atkBtn = createSkillButton(
		parentFrame, "Attack",
		buttonPositions.Attack,
		MobileConfig.SKILL_BTN_ATTACK
	)
	buttonMap[0] = atkBtn

	-- Q/W/R 技能按钮
	for key, slotType in pairs(SkillEnums.SlotNameToType) do
		if buttonPositions[key] and heroData.Skills[key] then
			local sizePct = MobileConfig.BTN_SIZES[key] or MobileConfig.SKILL_BTN_NORMAL
			local btn = createSkillButton(parentFrame, key, buttonPositions[key], sizePct)
			buttonMap[slotType] = btn
		end
	end

	-- 重建取消 UI
	local cancelUI = createCancelUI(parentFrame)

	-- ⑤ 重建按钮管理器
	local inputAdapter = InputAdapter.new()
	local atkCtrl = CommonAttackController.new({
		skillCacheManager = _cacheManager,
		attackRemoteEvent = ReplicatedStorage:FindFirstChild("AttackTargetEvent"),
		findEnemyFunc = function(pos, radius)
			return _controller:_FindEnemy(pos, radius)
		end,
	})

	-- 设置普攻范围
	local attackRange = 8
	if heroData.Skills and heroData.Skills["Attack"] then
		local atkData = SkillConfigAdapter[heroData.Skills["Attack"]]
		if atkData then
			attackRange = atkData.castRange or 8
		end
	end
	atkCtrl:SetAttackRange(attackRange)

	local btnMgr = SkillButtonManager.new({
		skillController = _controller,
		commonAttackController = atkCtrl,
		inputAdapter = inputAdapter,
		cancelAreaDetector = CancelAreaDetector.new(nil),
	})
	_buttonManager = btnMgr
	_buttonMap = buttonMap  -- 同步到模块级（供 Heartbeat CD 遍历）
	btnMgr:Init(buttonMap, cancelUI)

	-- 创建并注入技能摇杆
	local skillCursor = SkillCursor.new(parentFrame)
	btnMgr:SetSkillCursor(skillCursor)

	print("[SkillSystemInit] 英雄切换完成 | 新英雄:", heroId, "| 槽位数:", _countSlots(_controller))
	return true
end

--------------------------------------------------------------------------------
-- GetController: 获取 SkillController 实例
--------------------------------------------------------------------------------
function SkillSystemInit.GetController()
	return _controller
end

--------------------------------------------------------------------------------
-- GetButtonManager: 获取 SkillButtonManager 实例
--------------------------------------------------------------------------------
function SkillSystemInit.GetButtonManager()
	return _buttonManager
end

--------------------------------------------------------------------------------
-- IsInitialized
--------------------------------------------------------------------------------
function SkillSystemInit.IsInitialized()
	return _initialized
end

--------------------------------------------------------------------------------
-- SetEnabled: 启用/禁用技能系统（被控时禁用）
--------------------------------------------------------------------------------
function SkillSystemInit.SetEnabled(enabled)
	if _buttonManager then
		for st = 0, 5 do
			_buttonManager:SetSlotEnabled(st, enabled)
		end
	end
end

--------------------------------------------------------------------------------
-- Destroy: 清理所有模块实例和连接
--------------------------------------------------------------------------------
function SkillSystemInit.Destroy()
	for _, conn in ipairs(_connections) do
		if conn.Disconnect then conn:Disconnect() end
	end
	_connections = {}

	if _buttonManager then _buttonManager:Destroy() end
	if _controller then _controller:Destroy() end

	_controller = nil
	_buttonManager = nil
	_cacheManager = nil
	_buttonMap = {}
	_initialized = false
end

return SkillSystemInit
