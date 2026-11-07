# Tests

检查登记表（规范 007）。新增检查必须在这里登记，写明「证明什么 / 运行方式 / 保留理由」。

## 登记

| 检查 | 脚本 | 证明什么 | 运行 | 层 | 保留理由 |
| --- | --- | --- | --- | --- | --- |
| 扩展冒烟 | `Tests/smoke_extension.gd` | DLL 加载、`TheOneNode` 注册、方法可调用 | `Tools\Build\test-extension.cmd` | L1 | 原生管线回归 |
| 模块键与目录 | `Tests/Checks/test_module_key.gd` | SHA-1/规范化稳定、量化规则、S/R/A/P 策略与尺寸关系、71 模块目录完整 | 见下 | L1 | AncientBuilding M1 验收 |

## 运行

```powershell
# 首次或换机器：先让引擎生成扩展列表
D:\VibeSpace\ProjectAbyss\Engine\bin\godot.windows.editor.x86_64.console.exe `
  --headless --editor --quit --path D:\VibeSpace\ProjectTheOne\Project

# 模块键检查
D:\VibeSpace\ProjectAbyss\Engine\bin\godot.windows.editor.x86_64.console.exe `
  --headless --path D:\VibeSpace\ProjectTheOne\Project `
  --script res://Tests/Checks/test_module_key.gd
```

通过时输出 `PASS: module key and registry (N checks)` 且退出码 0。

## 约定

- 检查必须能失败：破坏对应行为时变红。
- 失败输出包含期望/实际，不返回裸布尔。
- 一次性探针放 `Tests/Temp/`（带 `.gdignore`），用完删除。
