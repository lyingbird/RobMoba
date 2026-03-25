local UIManager = {}

local UIComponents = script.Parent:WaitForChild("UIComponents")
local UI_HUD = require(UIComponents:WaitForChild("UI_HUD"))
local UI_Backpack = require(UIComponents:WaitForChild("UI_Backpack"))
local UI_DragDrop = require(UIComponents:WaitForChild("UI_DragDrop"))
local UI_MatchButton = require(UIComponents:WaitForChild("UI_MatchButton"))
local UI_LobbyPanel = require(UIComponents:WaitForChild("UI_LobbyPanel"))

-- 完整初始化（PC端 / 移动端进入战斗后调用）
function UIManager.Init()
	UI_HUD.Init()
	UI_Backpack.Init()
	UI_DragDrop.Init(UI_HUD, UI_Backpack, UIManager)
	UI_MatchButton.Init()
end

-- 移动端大厅阶段：只初始化最基础的依赖，不创建任何战斗/匹配 UI
function UIManager.InitLobbyOnly()
	-- 大厅阶段不初始化 HUD/Backpack/DragDrop/MatchButton
	-- 这些在进入训练场/战斗后通过 UIManager.Init() 或 InitMobileOnly() 初始化
end

-- REQ-014: 移动端战斗专用初始化（跳过PC端HUD/背包/拖拽）
local UI_MobileHUD = nil
local mobileHUDRef = nil

function UIManager.InitMobileOnly(mobileHUDParent)
	-- 惰性 require UI_MobileHUD（只在移动端路径加载）
	if not UI_MobileHUD then
		UI_MobileHUD = require(UIComponents:WaitForChild("UI_MobileHUD"))
	end
	UI_MobileHUD.Init(mobileHUDParent)
	mobileHUDRef = UI_MobileHUD
	-- 匹配按钮仍然复用
	UI_MatchButton.Init()
end

function UIManager.GetMobileHUD()
	return mobileHUDRef
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

-- 大厅面板 (REQ-013: 移动端流程)
function UIManager.GetLobbyPanel()
	return UI_LobbyPanel
end

function UIManager.SetLobbyPanelVisible(visible)
	if visible then
		UI_LobbyPanel.Show()
	else
		UI_LobbyPanel.Hide()
	end
end

return UIManager