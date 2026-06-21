-- ==========================================
-- RemoteEvent 初始化器 (安全网模式)
-- 主要创建源：default.project.json 中 Rojo 项目树静态声明
-- 此脚本作为安全网：如果 Rojo 项目树声明缺失某个 Event，
-- 运行时补创建，确保向后兼容。
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
	"MatchStateEvent",
	"DeathTimerEvent",

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

	-- 能量系统同步 (REQ-007)
	"SyncEnergyEvent",

	-- 训练场 (REQ-009)
	"TrainingEvent",
	"TrainingSyncEvent",

	-- 训练场模式进入/退出 (REQ-002)
	"TrainingModeEvent",

	-- 注意: 以下由 GameManager 自己创建，这里也确保存在
	-- "GameStateEvent",
	-- "BattleStartEvent",
	-- "MatchResultEvent",
	-- "HeroSelectEvent",
	-- "RematchEvent",
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
