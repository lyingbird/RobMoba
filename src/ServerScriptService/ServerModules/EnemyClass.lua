local Enemy = {}
Enemy.__index = Enemy

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LevelConfig = require(ReplicatedStorage:WaitForChild("LevelConfig"))
local StatsManager = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("StatsManager"))

function Enemy.new(modelInstance, xpReward)
	local self = setmetatable({}, Enemy)
	self.Model = modelInstance
	self.Humanoid = modelInstance:WaitForChild("Humanoid")
	self.RootPart = modelInstance:WaitForChild("HumanoidRootPart")
	self.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	self.PreviousHealth = self.Humanoid.Health
	self.XPReward = xpReward or LevelConfig.BaseEnemyXP
	self.LastDamagePlayer = nil
	self:CreateHealthBar()

	self.HealthConnection = self.Humanoid.HealthChanged:Connect(function(currentHealth)
		self:OnHealthChanged(currentHealth)
	end)

	return self
end

function Enemy:CreateHealthBar()
	local healthGui = Instance.new("BillboardGui")
	healthGui.Name = "HealthBarGui"
	healthGui.Size = UDim2.new(4, 0, 0.5, 0)
	healthGui.StudsOffset = Vector3.new(0, 4, 0)
	healthGui.AlwaysOnTop = true
	healthGui.Parent = self.RootPart

	local bgFrame = Instance.new("Frame")
	bgFrame.Size = UDim2.new(1, 0, 1, 0)
	bgFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	bgFrame.BorderSizePixel = 2
	bgFrame.Parent = healthGui

	self.HpFrame = Instance.new("Frame")
	self.HpFrame.Size = UDim2.new(1, 0, 1, 0)
	self.HpFrame.BackgroundColor3 = Color3.fromRGB(220, 20, 60)
	self.HpFrame.BorderSizePixel = 0
	self.HpFrame.Parent = bgFrame
end

function Enemy:OnHealthChanged(currentHealth)
	local healthPercent = math.clamp(currentHealth / self.Humanoid.MaxHealth, 0, 1)
	TweenService:Create(self.HpFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(healthPercent, 0, 1, 0)
	}):Play()

	-- Floating damage number
	local damage = (self.PreviousHealth or self.Humanoid.MaxHealth) - currentHealth
	self.PreviousHealth = currentHealth

	-- Track last player who damaged this enemy
	if damage > 0 then
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
				local dist = (p.Character.HumanoidRootPart.Position - self.RootPart.Position).Magnitude
				if dist < 200 then
					self.LastDamagePlayer = p
					break
				end
			end
		end
	end

	if damage > 0 and self.RootPart and self.RootPart.Parent then
		local randomX = (math.random() - 0.5) * 3
		local startY = math.random(3, 5)

		local dmgGui = Instance.new("BillboardGui")
		dmgGui.Name = "DamageNumber"
		dmgGui.Size = UDim2.new(3, 0, 1.5, 0)
		dmgGui.StudsOffset = Vector3.new(randomX, startY, 0)
		dmgGui.AlwaysOnTop = true
		dmgGui.Parent = self.RootPart

		local dmgLabel = Instance.new("TextLabel")
		dmgLabel.Size = UDim2.new(1, 0, 1, 0)
		dmgLabel.BackgroundTransparency = 1
		dmgLabel.Text = tostring(math.floor(damage))
		dmgLabel.Font = Enum.Font.GothamBold
		dmgLabel.TextScaled = false
		dmgLabel.TextSize = damage >= 200 and 28 or (damage >= 100 and 24 or 20)
		dmgLabel.TextColor3 = damage >= 200 and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(255, 255, 255)
		dmgLabel.TextStrokeTransparency = 0.3
		dmgLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		dmgLabel.TextTransparency = 0
		dmgLabel.Parent = dmgGui

		-- Float upward and fade out
		local endY = startY + math.random(2, 3)
		TweenService:Create(dmgGui, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			StudsOffset = Vector3.new(randomX, endY, 0)
		}):Play()
		TweenService:Create(dmgLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			TextStrokeTransparency = 1
		}):Play()

		Debris:AddItem(dmgGui, 1)
	end

	if currentHealth <= 0 then
		self:Die()
	end
end

function Enemy:Die()
	-- Grant XP to killer
	if self.LastDamagePlayer then
		StatsManager.GiveXP(self.LastDamagePlayer, self.XPReward)
	end

	-- Respawn after delay
	task.delay(3, function()
		if self.Humanoid and self.Humanoid.Parent then
			self.Humanoid.Health = self.Humanoid.MaxHealth
			self.PreviousHealth = self.Humanoid.MaxHealth
			self.LastDamagePlayer = nil
		end
	end)
end

return Enemy