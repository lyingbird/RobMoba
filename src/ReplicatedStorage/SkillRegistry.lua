-- ==========================================
-- SkillRegistry: 技能配置自动发现与汇聚
-- 扫描 Skills/ 目录下所有 ModuleScript，自动注册
-- 对外接口与原 SkillConfig 完全兼容:
--   SkillRegistry[1002].Name == "LuxQ"  ✅
-- ==========================================
local SkillRegistry = {}

local Skills = script.Parent:WaitForChild("Skills")

for _, module in ipairs(Skills:GetChildren()) do
	if module:IsA("ModuleScript") then
		local ok, skillData = pcall(require, module)
		if ok and type(skillData) == "table" then
			for skillId, config in pairs(skillData) do
				if SkillRegistry[skillId] then
					warn("[SkillRegistry] 技能 ID 冲突: " .. tostring(skillId) .. " 来自 " .. module.Name)
				end
				SkillRegistry[skillId] = config
			end
		else
			warn("[SkillRegistry] 加载技能配置失败: " .. module.Name)
		end
	end
end

return SkillRegistry
