-- IndicatorRenderer: 指示器渲染器
-- 路径: StarterPlayerScripts/Modules/SkillSystem/IndicatorRenderer.lua
-- 职责: Part 创建/回收/缩放/显隐/颜色 — 纯渲染层，不含游戏逻辑

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SkillEnums = require(
	ReplicatedStorage:WaitForChild("SkillSystem")
		:WaitForChild("Enums")
		:WaitForChild("SkillEnums")
)

local IR = {}
IR.__index = IR

-- 预定义颜色
local COLORS = {
	Default      = Color3.fromRGB(100, 180, 255),  -- 蓝色: 默认技能范围
	Warn         = Color3.fromRGB(255, 80, 80),     -- 红色: 警告/取消
	Guide        = Color3.fromRGB(255, 255, 255),   -- 白色: Guide 层
	DelayConfirm = Color3.fromRGB(255, 200, 50),    -- 黄色: 延迟确认
}

-- 默认半透明度
local ALPHA_VISIBLE = 0.5
local ALPHA_HIDDEN  = 1.0  -- Transparency = 1 → 完全透明

-- Ring 圆环参数
local RING_SEGMENTS = 24       -- 圆环由 24 个弧段组成
local RING_THICKNESS = 0.25    -- 弧段宽度（环的粗细），stud

-- 简单对象池
local pool = {} -- { [shape_key] = { part1, part2, ... } }

function IR.new()
	local self = setmetatable({}, IR)
	-- 创建统一的容器 Folder
	self._folder = Instance.new("Folder")
	self._folder.Name = "SkillIndicators"
	self._folder.Parent = workspace
	return self
end

--------------------------------------------------------------------------------
-- Create: 根据资源类型创建对应形状的 Part
-- layer: IndicatorLayer 枚举
-- resType: IndicatorResType 枚举
-- p: 参数表 {radius?, angle?, width?, length?}
--------------------------------------------------------------------------------
function IR:Create(layer, resType, p)
	local RT = SkillEnums.IndicatorResType
	local color = (layer == SkillEnums.IndicatorLayer.Guide) and COLORS.Guide or COLORS.Default

	-- ============ Ring: 空心圆环（多段弧组成） ============
	if resType == RT.Ring then
		local radius = p.radius or 3
		local model = self:_GetFromPool("Ring_Model")
		if model then
			-- 复用已有 Model，调整子 Part 位置/尺寸
			self:_ResizeRing(model, radius, color)
		else
			-- 新建 Model + 子 Part
			model = Instance.new("Model")
			model.Name = "RingIndicator"

			-- 创建一个不可见的锚点 Part 作为 PrimaryPart，确保 PivotTo 行为可预测
			local anchor = Instance.new("Part")
			anchor.Name = "Anchor"
			anchor.Size = Vector3.new(0.1, 0.1, 0.1)
			anchor.Transparency = 1
			anchor.CanCollide = false
			anchor.Anchored = true
			anchor.CastShadow = false
			anchor.CFrame = CFrame.new(0, 0, 0)
			anchor.Parent = model
			model.PrimaryPart = anchor

			local segAngle = (2 * math.pi) / RING_SEGMENTS
			local segLen = 2 * radius * math.sin(segAngle / 2)  -- 弦长
			for i = 0, RING_SEGMENTS - 1 do
				local angle = segAngle * i
				local cx = math.cos(angle + segAngle / 2) * radius
				local cz = math.sin(angle + segAngle / 2) * radius
				local seg = Instance.new("Part")
				seg.Shape = Enum.PartType.Block
				seg.Size = Vector3.new(segLen + 0.02, 0.05, RING_THICKNESS)  -- 略微重叠避免缝隙
				seg.CFrame = CFrame.new(cx, 0, cz) * CFrame.Angles(0, -(angle + segAngle / 2) + math.pi / 2, 0)
				seg.Color = color
				seg.Transparency = ALPHA_VISIBLE
				seg.CanCollide = false
				seg.Anchored = true
				seg.CastShadow = false
				seg.Material = Enum.Material.Neon
				seg.Parent = model
			end
		end
		model:SetAttribute("_IsRing", true)
		model:SetAttribute("_Radius", radius)
		model.Parent = self._folder
		return model
	end

	-- ============ 其他类型: 单 Part ============
	local part

	if resType == RT.Circle then
		-- 实心圆: Cylinder Part, Y 轴极扁放平
		part = self:_GetFromPool("Cylinder") or Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		local d = (p.radius or 3) * 2
		part.Size = Vector3.new(0.05, d, d)

	elseif resType == RT.Sector or resType == RT.HalfCircle then
		-- 扇形/半圆: Cylinder 近似 + SectorAngle 属性
		part = self:_GetFromPool("Cylinder_Sector") or Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		local d = (p.radius or 3) * 2
		part.Size = Vector3.new(0.05, d, d)
		part:SetAttribute("SectorAngle", p.angle or 60)

	elseif resType == RT.Arrow or resType == RT.Rectangle then
		-- 箭头/矩形: Block Part
		part = self:_GetFromPool("Block") or Instance.new("Part")
		part.Shape = Enum.PartType.Block
		local len = p.length or 10
		part.Size = Vector3.new(p.width or 2, 0.05, len)
		-- 保存 length 供 SetPosRot 做前向偏移（从角色脚下出发，而非居中）
		part:SetAttribute("_HalfLen", len / 2)

	elseif resType == RT.Line then
		-- 线型: 极细 Block Part
		part = self:_GetFromPool("Block_Line") or Instance.new("Part")
		part.Shape = Enum.PartType.Block
		local len = p.length or 10
		part.Size = Vector3.new(0.2, 0.05, len)
		part:SetAttribute("_HalfLen", len / 2)

	else
		-- 默认: 圆形
		part = self:_GetFromPool("Cylinder") or Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		local d = (p.radius or 3) * 2
		part.Size = Vector3.new(0.05, d, d)
	end

	-- 通用属性
	part.Color = color
	part.Transparency = ALPHA_VISIBLE
	part.CanCollide = false
	part.Anchored = true
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Parent = self._folder

	return part
end

--------------------------------------------------------------------------------
-- _ResizeRing: 调整复用的 Ring Model 子 Part 位置/尺寸
--------------------------------------------------------------------------------
function IR:_ResizeRing(model, radius, color)
	-- 重置 Anchor（PrimaryPart）到原点，确保 PivotTo 基准正确
	local anchor = model.PrimaryPart
	if anchor then
		anchor.CFrame = CFrame.new(0, 0, 0)
	end

	local segAngle = (2 * math.pi) / RING_SEGMENTS
	local segLen = 2 * radius * math.sin(segAngle / 2)
	local i = 0
	for _, seg in ipairs(model:GetChildren()) do
		-- 跳过 Anchor Part（PrimaryPart，不可见）
		if seg:IsA("BasePart") and seg.Name ~= "Anchor" then
			local angle = segAngle * i
			local cx = math.cos(angle + segAngle / 2) * radius
			local cz = math.sin(angle + segAngle / 2) * radius
			seg.Size = Vector3.new(segLen + 0.02, 0.05, RING_THICKNESS)
			seg.CFrame = CFrame.new(cx, 0, cz) * CFrame.Angles(0, -(angle + segAngle / 2) + math.pi / 2, 0)
			seg.Color = color
			seg.Transparency = ALPHA_VISIBLE
			seg.Material = Enum.Material.Neon
			i = i + 1
		end
	end
	model:SetAttribute("_Radius", radius)
end

--------------------------------------------------------------------------------
-- Destroy: 回收 Part 到对象池
--------------------------------------------------------------------------------
function IR:Destroy(part)
	if not part then return end

	-- Ring Model 特殊处理
	if typeof(part) == "Instance" and part:IsA("Model") and part:GetAttribute("_IsRing") then
		-- 隐藏所有环段 Part（跳过 Anchor）
		for _, seg in ipairs(part:GetChildren()) do
			if seg:IsA("BasePart") and seg.Name ~= "Anchor" then
				seg.Transparency = 1
			end
		end
		self:_ReturnToPool("Ring_Model", part)
		return
	end

	-- 单 Part 处理
	-- 确定池 key
	local key
	if part:GetAttribute("SectorAngle") then
		key = "Cylinder_Sector"
		part:SetAttribute("SectorAngle", nil)
	elseif part.Shape == Enum.PartType.Cylinder then
		key = "Cylinder"
	elseif part.Size.X <= 0.3 and part.Shape == Enum.PartType.Block then
		key = "Block_Line"
	else
		key = "Block"
	end

	-- 清除自定义属性
	if part:GetAttribute("_HalfLen") then
		part:SetAttribute("_HalfLen", nil)
	end

	self:_ReturnToPool(key, part)
end

--------------------------------------------------------------------------------
-- SetPos: 设置位置（无旋转），用于 Guide/Fixed 层
--------------------------------------------------------------------------------
function IR:SetPos(part, pos)
	if not part then return end

	-- Y 轴偏移 0.1 避免 Z-fighting
	local elevated = pos + Vector3.new(0, 0.1, 0)

	-- Ring Model 特殊处理
	if typeof(part) == "Instance" and part:IsA("Model") and part:GetAttribute("_IsRing") then
		part:PivotTo(CFrame.new(elevated))
		return
	end

	if part.Shape == Enum.PartType.Cylinder then
		-- Cylinder 默认沿 X 轴，需旋转 90° 让圆面朝上
		part.CFrame = CFrame.new(elevated) * CFrame.Angles(0, 0, math.rad(90))
	else
		part.CFrame = CFrame.new(elevated)
	end
end

--------------------------------------------------------------------------------
-- SetPosRot: 设置位置和朝向，用于 Effect 层
-- Arrow/Rectangle 从角色脚下出发: 把 Part 沿 dir 方向前移 halfLen
--------------------------------------------------------------------------------
function IR:SetPosRot(part, pos, dir)
	if not part then return end

	local elevated = pos + Vector3.new(0, 0.1, 0)

	-- Ring Model 特殊处理（SetPosRot 不常用于 Ring，但防御性处理）
	if typeof(part) == "Instance" and part:IsA("Model") and part:GetAttribute("_IsRing") then
		part:PivotTo(CFrame.new(elevated))
		return
	end

	local cf = CFrame.lookAt(elevated, elevated + dir)

	if part.Shape == Enum.PartType.Cylinder then
		if part:GetAttribute("SectorAngle") then
			-- 扇形 Cylinder 需要朝向 + 放平
			part.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
		else
			-- 普通圆形不需要朝向
			part.CFrame = CFrame.new(elevated) * CFrame.Angles(0, 0, math.rad(90))
		end
	else
		-- Block Part: lookAt 给出朝向
		-- Arrow/Rectangle 需要从脚下出发，前移 halfLen 使起点在角色脚下
		local halfLen = part:GetAttribute("_HalfLen")
		if halfLen then
			local fwdDir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(0, 0, 1)
			local origin = elevated + fwdDir * halfLen
			part.CFrame = CFrame.lookAt(origin, origin + fwdDir)
		else
			part.CFrame = cf
		end
	end
end

--------------------------------------------------------------------------------
-- Show: 显隐切换
--------------------------------------------------------------------------------
function IR:Show(part, vis)
	if not part then return end

	-- Ring Model: 遍历环段 Part（跳过 Anchor）
	if typeof(part) == "Instance" and part:IsA("Model") and part:GetAttribute("_IsRing") then
		local t = vis and ALPHA_VISIBLE or ALPHA_HIDDEN
		for _, seg in ipairs(part:GetChildren()) do
			if seg:IsA("BasePart") and seg.Name ~= "Anchor" then
				seg.Transparency = t
			end
		end
		return
	end

	part.Transparency = vis and ALPHA_VISIBLE or ALPHA_HIDDEN
end

--------------------------------------------------------------------------------
-- SetColor: 颜色切换
--------------------------------------------------------------------------------
function IR:SetColor(part, colorKey)
	if not part or not COLORS[colorKey] then return end

	-- Ring Model: 遍历环段 Part（跳过 Anchor）
	if typeof(part) == "Instance" and part:IsA("Model") and part:GetAttribute("_IsRing") then
		for _, seg in ipairs(part:GetChildren()) do
			if seg:IsA("BasePart") and seg.Name ~= "Anchor" then
				seg.Color = COLORS[colorKey]
			end
		end
		return
	end

	part.Color = COLORS[colorKey]
end

--------------------------------------------------------------------------------
-- 对象池内部方法
--------------------------------------------------------------------------------
function IR:_GetFromPool(key)
	if pool[key] and #pool[key] > 0 then
		local part = table.remove(pool[key])
		return part
	end
	return nil
end

function IR:_ReturnToPool(key, part)
	pool[key] = pool[key] or {}
	if part:IsA("BasePart") then
		part.Transparency = 1
	end
	part.Parent = nil -- 从场景中移除但不销毁
	table.insert(pool[key], part)
end

--------------------------------------------------------------------------------
-- Cleanup: 清理所有指示器和对象池
--------------------------------------------------------------------------------
function IR:Cleanup()
	-- 清理场景中的
	if self._folder then
		self._folder:ClearAllChildren()
	end
	-- 清理对象池
	for key, parts in pairs(pool) do
		for _, part in ipairs(parts) do
			part:Destroy()
		end
		pool[key] = {}
	end
end

return IR
