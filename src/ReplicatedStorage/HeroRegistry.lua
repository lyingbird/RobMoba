-- ==========================================
-- HeroRegistry: 英雄配置自动发现与汇聚
-- 扫描 Heroes/ 目录下所有 ModuleScript，自动注册
-- 对外接口与原 HeroConfig 完全兼容:
--   HeroRegistry["Angela"].Skills.Q == 1006  ✅
--   HeroRegistry["Angela"].Role == "Mage"    ✅ (新字段)
-- ==========================================
local HeroRegistry = {}

local Heroes = script.Parent:WaitForChild("Heroes")

for _, module in ipairs(Heroes:GetChildren()) do
	if module:IsA("ModuleScript") then
		local ok, heroData = pcall(require, module)
		if ok and type(heroData) == "table" and heroData.HeroID then
			HeroRegistry[heroData.HeroID] = heroData
		else
			warn("[HeroRegistry] 加载英雄配置失败: " .. module.Name)
		end
	end
end

return HeroRegistry
