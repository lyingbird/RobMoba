-- ==========================================
-- 服务端主入口 (Server Entry Point)
-- 初始化所有服务端系统模块
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local ServerModules = ServerScriptService:WaitForChild("ServerModules")

-- 初始化背包系统（必须在StatsManager之前，因为StatsManager装备逻辑依赖它）
local InventoryManager = require(ServerModules:WaitForChild("InventoryManager"))
InventoryManager.Init()

-- 初始化属性系统（HP/MP/等级/装备 → 角色 Attribute）
local StatsManager = require(ServerModules:WaitForChild("StatsManager"))
StatsManager.Init()

print("[Server] All systems initialized!")
