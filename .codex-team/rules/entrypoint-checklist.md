# Entrypoint Checklist

## 仓库预期入口
- `src/server/init.server.luau` -> `ServerScriptService.Server`
- `src/client/init.client.luau` -> `StarterPlayer.StarterPlayerScripts.Client`
- `src/shared/*` -> `ReplicatedStorage.Shared.*`

## Studio 必查路径
- `ServerScriptService.Server`
- `StarterPlayer.StarterPlayerScripts.Client`
- `ReplicatedStorage.Shared`
- `ServerScriptService`
- `StarterPlayer.StarterPlayerScripts`
- `ReplicatedStorage`

## 一旦仍在主流程中，就说明另一套系统还没被收敛
- `ServerScriptService.MatchSystem`
- `ServerScriptService.LobbyManager`
- `ServerScriptService.DuelManager`
- `ServerScriptService.TrainingManager`
- `ServerScriptService.PlayerSkillManager`
- `ServerScriptService.RemoteEventInit`
- `ServerScriptService.GameManager`
- `ServerScriptService.ServerModules`
- `StarterPlayer.StarterPlayerScripts.UIManager`
- `StarterPlayer.StarterPlayerScripts.SkillEffectHandler`
- `StarterPlayer.StarterPlayerScripts.Modules`
- `StarterPlayer.StarterPlayerScripts.UIComponents`
- `ReplicatedStorage.HeroRegistry`
- `ReplicatedStorage.SkillRegistry`
- `ReplicatedStorage.ItemConfig`
- `ReplicatedStorage.RuneConfig`
- `ReplicatedStorage.LevelConfig`
- `ReplicatedStorage.PassiveConfig`
- `ReplicatedStorage.EnergyConfig`
- `ReplicatedStorage.EffectConfig`
- `ReplicatedStorage.Heroes`
- `ReplicatedStorage.Skills`
- `ReplicatedStorage.CastSkillEvent`
- `ReplicatedStorage.HeroSwapEvent`
- `ReplicatedStorage.AttackTargetEvent`
- `ReplicatedStorage.SyncCooldownEvent`
- `ReplicatedStorage.SkillDirectionEvent`
- `ReplicatedStorage.SkillVFXEvent`
- `ReplicatedStorage.SkillCameraEvent`
- `ReplicatedStorage.SkillSoundEvent`
- `ReplicatedStorage.MatchmakingEvent`
- `ReplicatedStorage.TrainingEvent`
- `ReplicatedStorage.TrainingSyncEvent`
- `ReplicatedStorage.DuelEvent`
