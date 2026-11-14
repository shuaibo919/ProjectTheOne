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
| `Engine` | Godot 4.7 beta 自定义 fork，基线见父仓库锁定的子模块 SHA。TheOne 构建脚本开启 `with_hj_game=yes` |
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
"$REPO/.venv/Scripts/python.exe" -m SCons platform=windows target=editor arch=x86_64 angle=no with_hj_game=yes -j16

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

## TheOne 引擎 API

`with_hj_game=yes` 定义 `WITH_HJ_GAME`，向 `CompositorEffect` 增加 `needs_outline_data`，并开放 `RenderingServer.COMPOSITOR_EFFECT_FLAG_NEEDS_OUTLINE_DATA`。可向构建脚本传 `with_hj_game=no` 关闭扩展。编译模板与编辑器时应使用相同开关。

在 Forward+ 中，启用该请求的视口将不透明材质的 `OUTLINE_DATA = vec2(float(region_id) / 255.0, weight)` 写入线性 RG8。区域编号取 1–255，默认值和背景均为零。后处理在不透明绘制结束后可用 `get_texture("forward_clustered", "outline_data")` 取得本视口的解析纹理。用最近点采样或 `texelFetch` 读取离散编号。

启用扩展的编辑器有额外的类方法和枚举。原生绑定使用匹配的本地 API dump。`Source/build_api/` 已忽略，编译相应的引擎后运行：

```bash
cd Source/build_api
../../Engine/bin/godot.windows.editor.x86_64.console.exe --headless --dump-extension-api
```
