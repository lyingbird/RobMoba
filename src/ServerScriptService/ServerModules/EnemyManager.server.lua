local EnemyClass = require(script.Parent:WaitForChild("EnemyClass"))
local EnemiesFolder = workspace:WaitForChild("敌人")

local activeEnemies = {}

local function registerEnemy(model)
	if model:IsA("Model") and model:FindFirstChild("Humanoid") then
		local newEnemy = EnemyClass.new(model)
		table.insert(activeEnemies, newEnemy)
	end
end

for _, child in ipairs(EnemiesFolder:GetChildren()) do
	registerEnemy(child)
end

EnemiesFolder.ChildAdded:Connect(function(child)
	task.wait(0.1)
	registerEnemy(child)
end)