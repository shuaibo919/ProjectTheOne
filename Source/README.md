# Source（C++ GDExtension）

每个 `Source/<Module>/` 是一个独立的 GDExtension：独立 DLL、独立 `.gdextension`、独立入口符号。
编辑器与扩展都从本仓库源码构建，不依赖旧工程二进制。

## 模块

| 模块 | 目录 | 入口符号 | 产物 | 注册的类 |
| --- | --- | --- | --- | --- |
| `theone_core` | `Core/` | `theone_core_library_init` | `theone_core.<suffix>.dll` | `TheOneNode`、`ModuleKey` |
| `ancient_building` | `AncientBuilding/` | `ancient_building_library_init` | `ancient_building.<suffix>.dll` | `AncientBuildingModule`（M1 占位） |

`Common/` 是共享纯 C++ 工具（SHA-1、规范化 JSON），编进每个模块；**不得**放 Godot 类。
描述符在 `Project/bin/<module>.gdextension`，`entry_symbol` 必须与实现一致。

## 版本对应

| 组件 | 版本 |
| --- | --- |
| `Engine` | Godot 4.7 beta 自定义 fork，提交 `3bfa50fd`，本地编译 |
| `EngineAdaptor` | godot-cpp `master`，提交 `e103d34` |
| 目标 API | `4.7`（默认用引擎 dump 的 `Source/build_api/extension_api.json`，缺失时回退 godot-cpp 的 4.7 快照） |
| 构建 Python | 3.13.13（uv 托管，`.python-version`） |
| SCons | 4.11.1（`uv.lock`） |

## 构建（Git Bash）

```bash
./Tools/Build/setup-env.sh      # 首次：uv sync
./Tools/Build/build-engine.sh   # 首次或引擎升级后：编译 Engine/
./Tools/Build/build-native.sh   # 编译 godot-cpp + 全部扩展模块
```

等价的直接命令：

```bash
cd Engine
"$REPO/.venv/Scripts/python.exe" -m SCons platform=windows target=editor arch=x86_64 angle=no -j16

cd "$REPO"
"$REPO/.venv/Scripts/python.exe" -m SCons platform=windows target=template_debug -j8
```

产物：

- 引擎：`Engine/bin/godot.windows.editor.x86_64.exe`（GUI）与 `.console.exe`（headless 用）
- 扩展：`Project/bin/theone_core...dll`、`Project/bin/ancient_building...dll`

构建脚本会重定向 `TMP`/`TEMP`（否则 link.exe 报 `LNK1104`）并设置 `VSLANG=1033`。

## 新增一个扩展模块

1. 建 `Source/<Module>/`，写 `register_types.h/.cpp`，入口符号 `<module>_library_init`；
2. 建 `Project/bin/<module>.gdextension`，`entry_symbol` 与入口一致；
3. 在根 `SConstruct` 的 `modules` 列表加 `("<module>", Glob("Source/<Module>/*.cpp"))`；
4. `./Tools/Build/build-native.sh`，然后在编辑器里扫描一次扩展列表。

## 验证

扩展冒烟与 AncientBuilding 检查按用户要求仅在本地 `Project/Tests/Temp/` 使用，不进入 Git；本版最终结果见 `Wiki/Temp/008-AncientBuilding.md` §14。

引擎从 `.godot/extension_list.cfg` 读取扩展列表。首次打开本地编辑器会扫描并生成此文件；构建流程不依赖临时验证脚本。

## 引擎 API 与官方 4.7 的差异

| 来源 | 体积 | 版本串 |
| --- | ---: | --- |
| 引擎 dump（`Source/build_api/`） | 6,963,881 B | `4.7.0 beta custom_build` |
| godot-cpp `extension_api-4-7.json` | 6,965,055 B | `4.7.0 stable official` |

差约 1.2 KB，说明 fork 未改动 GDExtension 暴露面。`Source/build_api/` 已忽略，可按下述命令确定性重建（需先编译引擎）：

```bash
cd Source/build_api
../../Engine/bin/godot.windows.editor.x86_64.console.exe --headless --dump-extension-api
```
