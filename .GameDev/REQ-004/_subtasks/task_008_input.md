# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-008 |
| 父需求 | REQ-004 自由大厅+匹配对决 |
| 子任务名称 | 集成测试 + 修复 |
| 执行者 | 程序 Agent |
| 优先级 | 3 |

## 任务描述
全部模块完成后的集成验证和修复：
1. UIManager.lua 更新: 添加 UI_MatchButton 的转发方法
2. UI_HUD.lua 调整: 对决相关UI适配DuelEvent
3. 验证所有 RemoteEvent 连接正确
4. 验证 shared 表跨脚本通信正确
5. 检查所有 require 路径正确
6. 修复集成过程中发现的任何问题

## 技术要求
- 修改文件: `src/StarterPlayer/StarterPlayerScripts/UIManager.lua`
- 修改文件: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_HUD.lua`
- 预估行数: ~50行改动

## 输入依赖
- 依赖: T1-T7 全部完成

## 输出要求
- UIManager: 添加 UI_MatchButton require 和转发方法
- UI_HUD: DuelEvent 监听适配 (复用现有PvP UI或新建)

## 接口约定
```lua
-- UIManager 新增方法
function UIManager.InitMatchButton()
    UI_MatchButton.Init()
end

function UIManager.SetMatchButtonState(state)
    UI_MatchButton.SetState(state)
end

function UIManager.SetMatchButtonVisible(visible)
    UI_MatchButton.SetVisible(visible)
end
```

## 与其他模块的关系
- 被依赖: 无 (最后执行)
- 依赖: T1-T7 全部
