local UIManager = {}

local UIComponents = script.Parent:WaitForChild("UIComponents")
local UI_HUD = require(UIComponents:WaitForChild("UI_HUD"))
local UI_Backpack = require(UIComponents:WaitForChild("UI_Backpack"))
local UI_DragDrop = require(UIComponents:WaitForChild("UI_DragDrop"))
local UI_MatchButton = require(UIComponents:WaitForChild("UI_MatchButton"))

function UIManager.Init()
	UI_HUD.Init()
	UI_Backpack.Init()
	UI_DragDrop.Init(UI_HUD, UI_Backpack, UIManager)
	UI_MatchButton.Init()
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

function UIManager.GetDragDrop()
	return UI_DragDrop
end

function UIManager.SetBackpackLocked(locked)
	if UI_Backpack and UI_Backpack.SetLocked then
		UI_Backpack.SetLocked(locked)
	end
end

-- 匹配按钮 (REQ-004)
function UIManager.SetMatchButtonState(state)
	UI_MatchButton.SetState(state)
end

function UIManager.SetMatchButtonVisible(visible)
	UI_MatchButton.SetVisible(visible)
end

return UIManager