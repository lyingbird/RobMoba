--[[
    DataManager.luau
    数据管理器 — 统一查询接口
    聚合所有数据表，提供便捷的查询方法
]]

local HeroTable = require(script.Parent.HeroTable)
local SkillTable = require(script.Parent.SkillTable)
local SkillEventTable = require(script.Parent.SkillEventTable)
local SkillEffectTable = require(script.Parent.SkillEffectTable)
local SkillIndicatorTable = require(script.Parent.SkillIndicatorTable)
local VFXTemplateTable = require(script.Parent.VFXTemplateTable)
local EventTypes = require(script.Parent.EventTypes)

local DataManager = {}

--============================================================
-- 英雄查询
--============================================================

function DataManager.getHero(heroId: string)
    return HeroTable.getHero(heroId)
end

function DataManager.getAllHeroIds(): { string }
    return HeroTable.getAllHeroIds()
end

--============================================================
-- 技能查询
--============================================================

function DataManager.getSkill(skillId: string)
    return SkillTable.getSkill(skillId)
end

function DataManager.getHeroSkills(heroId: string): { any }
    return SkillTable.getHeroSkills(heroId)
end

-- 获取英雄按键对应的技能ID
function DataManager.getSkillIdByKey(heroId: string, key: string): string?
    local hero = HeroTable.getHero(heroId)
    if hero and hero.skills then
        return hero.skills[key]
    end
    return nil
end

-- 获取技能的完整信息（基础配置 + 事件时间轴）
function DataManager.getSkillFull(skillId: string)
    local skillBase = SkillTable.getSkill(skillId)
    local skillEvents = SkillEventTable.getSkillEvents(skillId)
    if not skillBase then return nil end
    return {
        base = skillBase,
        timeline = skillEvents,
    }
end

--============================================================
-- 事件类型查询
--============================================================

function DataManager.getEventTypes()
    return EventTypes.Types
end

function DataManager.isTickEvent(eventType: string): boolean
    return EventTypes.isTick(eventType)
end

function DataManager.isDurationEvent(eventType: string): boolean
    return EventTypes.isDuration(eventType)
end

--============================================================
-- 技能事件时间轴查询
--============================================================

function DataManager.getSkillEvents(skillId: string)
    return SkillEventTable.getSkillEvents(skillId)
end

--============================================================
-- 特效模板查询
--============================================================

function DataManager.getVFXTemplate(templateId: string)
    return VFXTemplateTable.getTemplate(templateId)
end

--============================================================
-- 指示器查询
--============================================================

function DataManager.getIndicator(indicatorId: string)
    return SkillIndicatorTable.getIndicator(indicatorId)
end

-- 获取技能的指示器配置
function DataManager.getSkillIndicator(skillId: string)
    local skill = SkillTable.getSkill(skillId)
    if skill and skill.indicatorId then
        local indicator = SkillIndicatorTable.getIndicator(skill.indicatorId)
        if indicator then
            -- 合并技能特定参数覆盖
            local merged = {}
            for k, v in pairs(indicator) do
                merged[k] = v
            end
            if skill.indicatorParams then
                if not merged.params then merged.params = {} end
                for k, v in pairs(skill.indicatorParams) do
                    merged.params[k] = v
                end
            end
            return merged
        end
    end
    return nil
end

--============================================================
-- 效果查询
--============================================================

function DataManager.getMarkConfig(markId: string)
    return SkillEffectTable.Marks[markId]
end

function DataManager.isControlDebuff(buffType: string): boolean
    return SkillEffectTable.ControlDebuffs[buffType] == true
end

return DataManager
