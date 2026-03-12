-- ==========================================
-- 服务端系统：敌人管理器 (Enemy Manager)
-- 职责：集中管理、初始化所有敌人
-- ==========================================
local workspace = game:GetService("Workspace")

-- 引入我们刚刚写的类
local EnemyClass = require(script.Parent:WaitForChild("ServerModules"):WaitForChild("EnemyClass"))

-- 找到你在工作区建的文件夹
local EnemiesFolder = workspace:WaitForChild("敌人")

-- 用一个表来存储所有激活的敌人对象，方便后续统一管理（比如发AOE伤害时遍历这个表）
local activeEnemies = {}

-- 核心函数：把一个模型转化为敌人对象
local function registerEnemy(model)
	if model:IsA("Model") and model:FindFirstChild("Humanoid") then
		local newEnemy = EnemyClass.new(model)
		table.insert(activeEnemies, newEnemy)
		print("成功注册敌人：" .. model.Name)
	end
end

-- 1. 游戏启动时，扫描文件夹里已经存在的敌人（比如你截图里的木桩）
for _, child in ipairs(EnemiesFolder:GetChildren()) do
	registerEnemy(child)
end

-- 2. 动态监听：如果在游戏运行中，有新的敌人被生成 (Spawn) 到这个文件夹里，自动接管
EnemiesFolder.ChildAdded:Connect(function(child)
	-- 等待一小会儿确保模型内部的 Humanoid 加载完毕
	task.wait(0.1)
	registerEnemy(child)
end)