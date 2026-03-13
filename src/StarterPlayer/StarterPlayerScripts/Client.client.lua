-- ==========================================
-- 客户端主入口 (Client Entry Point)
-- 流程: 选英雄 → 装备技能 → 初始化系统
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local Modules = script.Parent:WaitForChild("Modules")
local UIComponents = script.Parent:WaitForChild("UIComponents")

local CameraManager = require(Modules:WaitForChild("CameraManager"))
local MovementManager = require(Modules:WaitForChild("MovementManager"))
local InputManager = require(Modules:WaitForChild("InputManager"))
local UIManager = require(script.Parent:WaitForChild("UIManager"))
local StatsBinding = require(Modules:WaitForChild("StatsBinding"))
local OverheadUI = require(Modules:WaitForChild("OverheadUI"))
local HeroAnimator = require(Modules:WaitForChild("HeroAnimator"))
local HeroSelectUI = require(UIComponents:WaitForChild("UI_HeroSelect"))
local HeroConfig = require(ReplicatedStorage:WaitForChild("HeroConfig"))

local selectedHeroID = nil

local function onCharacterAdded(character)
	character:WaitForChild("HumanoidRootPart")
	character:WaitForChild("Humanoid")

	CameraManager.Init(character)
	MovementManager.Init(character)

	if selectedHeroID then
		HeroAnimator.Init(character, selectedHeroID)
	end
end

-- === 第1步: 初始化基础UI和摄像机 ===
UIManager.Init()
OverheadUI.Init()
local UI_HUD = UIManager.GetHUD()
StatsBinding.Init(UI_HUD)

-- 先绑定角色(摄像机和移动需要)
if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- === 第2步: 显示选英雄界面 (yield等待选择) ===
selectedHeroID = HeroSelectUI.Show()
print("[Client] 已选择英雄: " .. selectedHeroID)

-- === 第3步: 根据英雄自动装备技能 ===
local heroData = HeroConfig[selectedHeroID]
local SkillConfig = require(ReplicatedStorage:WaitForChild("SkillConfig"))

if heroData and heroData.Skills and next(heroData.Skills) then
	local EquipSkillEvent = ReplicatedStorage:WaitForChild("EquipSkillEvent")
	local DragDrop = UIManager.GetDragDrop()
	local UI_HUD_mod = UIManager.GetHUD()
	local skillsContainer = UI_HUD_mod.SkillsContainer

	for key, skillID in pairs(heroData.Skills) do
		-- 服务端装备
		EquipSkillEvent:FireServer(key, skillID)

		-- 客户端UI槽位放入技能图标
		if skillsContainer and SkillConfig[skillID] then
			local slot = skillsContainer:FindFirstChild("ActionSlot_" .. key)
			if slot then
				DragDrop.CreateItemCard(slot, skillID, SkillConfig[skillID].Icon, true)
			end
		end
		task.wait(0.05)
	end
	print("[Client] 技能已自动装备")
end

-- === 第4步: 背包控制 ===
if not heroData.AllowBackpack then
	UIManager.SetBackpackLocked(true)
	print("[Client] 背包已锁定 (英雄模式)")
else
	UIManager.SetBackpackLocked(false)
	print("[Client] 背包已解锁 (测试模式)")
end

-- === 第5步: 初始化输入系统 + 英雄动画 ===
InputManager.Init()

if player.Character and selectedHeroID then
	HeroAnimator.Init(player.Character, selectedHeroID)
end

print("[Client] All systems initialized!")
