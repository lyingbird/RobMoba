-- SkillTypes: 数据结构类型标注
-- 路径: ReplicatedStorage.SkillSystem.Types.SkillTypes
--
-- Luau type annotation，供所有模块引用。
-- 这些类型不产生运行时开销，仅用于 Luau 类型检查和文档说明。

--------------------------------------------------------------------------------
-- 1. SkillSlot — 技能槽位运行时数据
--------------------------------------------------------------------------------
export type SkillSlot = {
	slotType: number,           -- SlotType 枚举值
	skillId: number,            -- 技能ID，对应配置的 key
	skillLevel: number,         -- 技能等级
	isEnabled: boolean,         -- 是否可用（被沉默/未学习时 false）
	cooldownEndTime: number,    -- CD结束时刻，os.clock() 基准
	cooldownTotal: number,      -- CD总时长（秒）
	manaCost: number,           -- 蓝量消耗
	rangeType: number,          -- SkillRangeType 枚举值
	castRange: number,          -- 施法范围（studs）
	indicatorCfgId: number,     -- 指示器配置ID
	-- 来自原始配置的引用
	skillName: string,          -- 技能名称（调试用）
	uiName: string,             -- UI 显示名称
	icon: string,               -- 图标资源 ID
}

--------------------------------------------------------------------------------
-- 2. SkillParam — 技能释放参数（客户端→服务端）
--------------------------------------------------------------------------------
export type SkillParam = {
	slotType: number,
	skillId: number,
	rangeType: number,
	targetPosition: Vector3?,    -- Pos/Target 使用
	targetDirection: Vector3?,   -- Directional 使用（单位向量）
	targetActorId: number?,      -- Target 使用（目标的唯一ID）
	trackPoints: {Vector3}?,     -- Track 使用（有序路径点数组）
}

--------------------------------------------------------------------------------
-- 3. CacheEntry — 缓冲队列条目
--------------------------------------------------------------------------------
export type CacheEntry = {
	skillParam: SkillParam,
	timestamp: number,           -- 入队时刻，os.clock() 基准
	isCommonAttack: boolean,     -- 是否为普攻
}

--------------------------------------------------------------------------------
-- 4. IndicatorState — 指示器运行时状态
--------------------------------------------------------------------------------
export type IndicatorState = {
	isActive: boolean,
	slotType: number,
	guidePart: BasePart?,
	effectPart: BasePart?,
	fixedPart: BasePart?,
	currentTargetPos: Vector3,
	currentTargetDir: Vector3,
}

--------------------------------------------------------------------------------
-- 5. CancelState — 取消区域检测状态
--------------------------------------------------------------------------------
export type CancelState = {
	isInCancelArea: boolean,
	timeInCancelArea: number,
	hasTriggeredVibration: boolean,
}

--------------------------------------------------------------------------------
-- 6. IndicatorConfigEntry — 指示器配置条目
--------------------------------------------------------------------------------
export type IndicatorConfigEntry = {
	cfgId: number,
	rangeType: number,
	guideEnabled: boolean,
	guideDistance: number,
	guideResType: number,
	effectEnabled: boolean,
	effectRadius: number,
	effectAngle: number,
	effectWidth: number,
	effectLength: number,
	effectResType: number,
	effectResSize: number,
	effectResLength: number,
	fixedEnabled: boolean,
	fixedResType: number,
}

--------------------------------------------------------------------------------
-- 7. SkillConfigEntry — 技能配置条目（适配后的统一格式）
--------------------------------------------------------------------------------
export type SkillConfigEntry = {
	skillId: number,
	skillName: string,
	uiName: string,
	icon: string,
	slotType: number,
	rangeType: number,
	cooldown: number,
	manaCost: number,
	castRange: number,
	indicatorCfgId: number,
	-- 保留原始配置引用，供服务端使用
	archetypeType: string?,
	isUltimate: boolean?,
}

return nil  -- 本文件仅提供类型标注，不导出运行时值
