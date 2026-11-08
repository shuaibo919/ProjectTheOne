# Tests

检查登记表（规范 007）。新增检查必须在这里登记，写明「证明什么 / 运行方式 / 保留理由」。

## 登记

| 检查 | 脚本 | 证明什么 | 运行 | 层 | 保留理由 |
| --- | --- | --- | --- | --- | --- |
| 扩展冒烟 | `Tests/smoke_extension.gd` | `theone_core` 与 `ancient_building` 两个扩展加载、三个类注册 | `Tools/Build/test-extension.sh` | L1 | 原生管线回归 |
| 模块键与目录 | `Tests/Checks/test_module_key.gd` | SHA-1/规范化稳定、量化规则、策略与尺寸关系、71 模块目录完整 | `Test-AncientBuilding.ps1` | L1 | AncientBuilding M1 |
| 宽度求解与装配 | `Tests/Checks/test_layout.gd` | S/R/A/P 求解、实例展开、共享网格、布局哈希 | 同上 | L1 | M2 |
| 屋顶模块 | `Tests/Checks/test_roof.gd` | P 类随宽度重建、R 类复用、屋面/脊/瓦网格尺寸 | 同上 | L1 | M3 |
| MultiMesh 与磁盘缓存 | `Tests/Checks/test_batch.gd` | 转换/还原、磁盘命中、往返哈希一致 | 同上 | L1 | M4 |
| CLI 全流程 | `Tools/Test/Test-AncientBuilding.ps1` | build/bake/convert/revert/inspect 端到端 | `Tools\Test\Test-AncientBuilding.ps1` | L2 | M5 |

## 运行

```powershell
# 一键验收（含扩展列表初始化）
.\Tools\Test\Test-AncientBuilding.ps1

# 单个检查
D:\VibeSpace\ProjectAbyss\Engine\bin\godot.windows.editor.x86_64.console.exe `
  --headless --path D:\VibeSpace\ProjectTheOne\Project `
  --script res://Tests/Checks/test_layout.gd
```

通过时输出 `PASS: ...` 且退出码 0；CLI 流程通过时输出 `ANCIENTBUILDING CHECK PASSED`。

## 约定

- 检查必须能失败：破坏对应行为时变红。
- 失败输出包含期望/实际，不返回裸布尔。
- 一次性探针放 `Tests/Temp/`（带 `.gdignore`），用完删除。
