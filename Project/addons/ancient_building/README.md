# AncientBuilding

古建 PCG 工具。重构计划见 `Wiki/Temp/008-AncientBuilding.md`（验收通过后转 Spec）。

## 目录

| 目录 | 层 | 内容 |
| --- | --- | --- |
| `core/` | L1 | 模块目录、量化、模块键 |
| `runtime/` | L2 | 运行时装配（M3 起） |
| `editor/` | L2 | 编辑器 dock（M6） |
| `cli/` | L2 | headless 命令入口 |
| `resources/` | 数据 | `module_catalog.json`、模块预设 |

## M1 已实现

- `ModuleKey` 原生类（`Source/AncientBuilding/`）：SHA-1、规范化 JSON、`ab1_` 模块键；
- 71 个模块目录（`resources/module_catalog.json`），按 Base/Frame/Wall/Opening/Roof/Ornament 分层；
- 策略 S/R/A/P 落入目录；S/R 的键不含尺寸，A/P 含尺寸；
- `cli/main.gd`：`list-modules`、`describe <id>`；
- 验收：`Project/Tests/Checks/test_module_key.gd`（26 项断言）。