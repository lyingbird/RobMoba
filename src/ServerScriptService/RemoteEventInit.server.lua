-- ==========================================
-- RemoteEvent 初始化器
-- 职责：在所有其他脚本启动前，确保所有需要的 RemoteEvent 存在
-- 原因：Rojo 同步 ReplicatedStorage 时会删除手动创建的 Instance，
--        所以需要服务端脚本在运行时重新创建它们
-- ==========================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 所有项目需要的 RemoteEvent 列表
local REMOTE_EVENTS = {
	-- 技能系统
	"CastSkillEvent",
	"EquipSkillEvent",
	"SkillDirectionEvent",

	-- 冷却/同步
	"SyncCooldownEvent",
	"SyncRecastEvent",
	"SyncRuneEvent",
	"SyncEquipEvent",
	"SyncLevelEvent",

	-- 战斗
	"AttackTargetEvent",

	-- 特效/音效/镜头
	"SkillVFXEvent",
	"SkillSoundEvent",
	"SkillCameraEvent",

	-- 电影特写
	"CinematicEvent",

	-- 大厅+匹配+对决 (REQ-004)
	"MatchmakingEvent",
	"DuelEvent",
	"HeroSwapEvent",

	-- 注意: 以下由 GameManager / MatchSystem 自己创建，这里也确保存在
	-- "GameStateEvent",
	-- "BattleStartEvent",
	-- "MatchResultEvent",
	-- "HeroSelectEvent",
	-- "RematchEvent",
	-- "MatchStateEvent",
	-- "DeathTimerEvent",
}

local created = 0
for _, eventName in ipairs(REMOTE_EVENTS) do
	if not ReplicatedStorage:FindFirstChild(eventName) then
		local event = Instance.new("RemoteEvent")
		event.Name = eventName
		event.Parent = ReplicatedStorage
		created = created + 1
	end
end

print(("[RemoteEventInit] Ensured %d RemoteEvents exist (%d newly created)"):format(
	#REMOTE_EVENTS, created
))
