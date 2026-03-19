# 项目交接面板

## 当前主线

- 仓库是唯一真相源，Studio 只作为运行和验证环境。
- Rojo 主线入口固定为：
  - `ReplicatedStorage.Shared`
  - `ServerScriptService.Server`
  - `StarterPlayer.StarterPlayerScripts.Client`
- 旧 Studio 系统已经按“只保留 Rojo 主线”的方向清理，相关约束见 [STUDIO_CLEANLINESS.md](./STUDIO_CLEANLINESS.md)。

## 当前仓库状态

- 项目类型：Roblox + Rojo 7.7.0-rc.1。
- 当前分支：`master`。
- 现在已经具备可提交的 git 仓库结构，但此前没有有效提交历史。
- 构建方式：
  1. `rojo build -o "roblox_vibecoding.rbxlx"`
  2. 或 Windows 下运行 `./tools/rebuild-place.ps1`
  3. 在 Studio 打开生成的 place，并运行 `rojo serve`

## 已完成的关键收敛

- 清理 Studio 中未受 Rojo 管理的旧服务端、旧客户端、旧 RemoteEvent、旧配置对象。
- 明确 Studio 清洁契约，禁止手工在 Studio 中补业务逻辑。
- 补充 place 重建脚本，支持从仓库重新生成干净 place。

## 本轮最新改动

### 技能输入与释放体验

- 客户端输入层接入了 `CooldownUpdate`，技能现在会区分：
  - CD 中不可释放
  - 临近可释放时允许预输入
  - 已可释放时立即发送
- 增加 `0.2s` 预输入窗口：
  - 技能距离转好不超过 `0.2s` 时，允许先拉出技能指示器
  - 玩家确认后会缓存该次输入，等 CD 结束自动发出
- 施法前不再过早 `stopMovement()`：
  - 只有真正发包时才会停移动
  - 避免“技能没放出去但人物先顿一下”的手感问题
- 技能替换/恢复时会同步清理或刷新挂起的指示器与预输入状态，避免显示与实际释放错配

### 技能指示器

- 位置型技能的预览指示器和实际目标点现在统一按 `indicatorParams.range` 做射程裁剪
- 避免出现“圈能拖很远，但实际设计不该这么远”的错觉

### UI 容错

- 技能栏每个技能槽增加了更大的透明点击命中区
- 命中区覆盖图标周边、槽位间隙和键位标签附近
- 玩家点击接近技能槽的位置也能命中该技能，不再要求必须点得很准
- UI 点击统一复用 `InputHandler` 的标准技能输入逻辑，不会与键盘输入分叉

## 当前关注点

- 现有静态代码链路已经对齐：
  - CD 显示
  - 输入 gating
  - 预输入
  - 指示器裁剪
  - UI 容错点击
- 但仍需要在“最新由仓库构建的 place”里做一轮 Studio 实机验证。
- 当前不要再把旧逻辑手工补回 Studio；缺失对象应该回补到仓库，再通过 Rojo 同步。

## 下一步建议

1. 用仓库生成的干净 place 打开 Studio。
2. 启动 `rojo serve` 并重新连接。
3. 逐项验证：
   - 技能 CD 中无法释放
   - CD 最后 `0.2s` 可拖出指示器并预输入
   - CD 结束后预输入会自动释放
   - 位置型技能预览与实际落点都被射程限制
   - 点击技能槽附近也能稳定命中对应技能
4. 验证通过后继续做手感微调，例如方向型技能的一段/二段确认节奏。
