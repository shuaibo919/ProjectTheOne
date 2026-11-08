## Project: The One

水墨风武侠 ARPG。Godot 4.7 自定义 fork + C++ GDExtension，全部源码本地构建。

## 快速开始（Git Bash）

```bash
./Tools/Build/setup-env.sh   # 首次：uv sync（Python 3.13.13 + SCons 4.11.1）
./build.sh                   # 编译引擎（首次 10–20 分钟）+ 原生扩展
./edit.sh                    # 用本地引擎打开 Project/
./test.sh                    # AncientBuilding 验收
```

| 快捷方式 | 等价 |
| --- | --- |
| `./build.sh` | `Tools/Build/build-all.sh` |
| `./edit.sh` | `Tools/Build/launch-editor.sh` |
| `./test.sh` | `Tools/Test/Test-AncientBuilding.sh` |

产物：`Engine/bin/godot.windows.editor.x86_64.exe`；扩展按模块拆分为 `Project/bin/theone_core...dll` 与 `Project/bin/ancient_building...dll`。

规范与计划：[Wiki/Spec/001-Overview.md](Wiki/Spec/001-Overview.md)、[Wiki/Temp/008-AncientBuilding.md](Wiki/Temp/008-AncientBuilding.md)。