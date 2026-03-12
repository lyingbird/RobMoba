local UIManager = {}

local UIComponents = script.Parent:WaitForChild("UIComponents")
local UI_HUD = require(UIComponents:WaitForChild("UI_HUD"))
local UI_Backpack = require(UIComponents:WaitForChild("UI_Backpack"))
local UI_DragDrop = require(UIComponents:WaitForChild("UI_DragDrop"))

function UIManager.Init()
	UI_HUD.Init()
	UI_Backpack.Init()
	UI_DragDrop.Init(UI_HUD, UI_Backpack, UIManager)
end

function UIManager.GetSkillIDInSlot(key)
	return UI_HUD.GetSkillIDInSlot(key)
end

function UIManager.ToggleBackpack()
	local isOpen = UI_Backpack.Toggle()
	if not isOpen then
		UI_HUD.CloseAllPopups()
	end
	return isOpen
end

function UIManager.HasSkillInSlot(key)
	return UI_HUD.HasSkillInSlot(key)
end

function UIManager.ShowWarning(text)
	UI_HUD.ShowWarning(text)
end

function UIManager.GetHUD()
	return UI_HUD
end

return UIManager