# Source（C++ GDExtension）

原生扩展实现。绑定库是 `../EngineAdaptor`（godot-cpp `master`），构建入口在仓库根 `SConstruct`。
编辑器与扩展都从本仓库源码构建，不依赖旧工程二进制。

## 版本对应

| 组件 | 版本 |
| --- | --- |
| `Engine` | Godot 4.7 beta 自定义 fork，提交 `3bfa50fd`，本地编译 |
| `EngineAdaptor` | godot-cpp `master`，提交 `e103d34` |
| 目标 API | `4.7`（默认用引擎 dump 的 `Source/build_api/extension_api.json`，缺失时回退 godot-cpp 的 4.7 快照） |
| 构建 Python | 3.13.13（uv 托管，`.python-version`） |
| SCons | 4.11.1（`uv.lock`） |

## 文件

| 文件 | 作用 |
| --- | --- |
| `src/register_types.cpp` | 扩展入口 `theone_library_init`，注册 `TheOneNode` / `ModuleKey` |
| `src/theone_node.h/.cpp` | 最小 `Node` 子类，方法 `get_build_info()`，用于证明管线打通 |
| `AncientBuilding/` | 古建模块化重构的原生部分（M1：SHA-1、规范化 JSON、`ModuleKey`） |
| `../SConstruct` | 调用 `EngineAdaptor/SConstruct`，产物写入 `Project/bin/` |
| `../Project/bin/theone.gdextension` | 扩展描述符，`entry_symbol = theone_library_init` |

## 构建（Git Bash）

```bash
./Tools/Build/setup-env.sh      # 首次：uv sync
./Tools/Build/build-engine.sh   # 首次或引擎升级后：编译 Engine/
./Tools/Build/build-native.sh   # 编译 godot-cpp + Source/
```

等价的直接命令：

```bash
cd Engine
"$REPO/.venv/Scripts/python.exe" -m SCons platform=windows target=editor arch=x86_64 angle=no -j16

cd "$REPO"
"$REPO/.venv/Scripts/python.exe" -m SCons platform=windows target=template_debug -j8
```

产物：

- 引擎：`Engine/bin/godot.windows.editor.x86_64.exe`（GUI）与 `.console.exe`（带 stdout）
- 扩展：`Project/bin/theone.windows.template_debug.x86_64.dll`

构建脚本会重定向 `TMP`/`TEMP`（否则本机 link.exe 报 `LNK1104`）并设置 `VSLANG=1033`。

## 验证

```bash
./Tools/Build/test-extension.sh   # 扩展列表扫描 + 冒烟脚本
./test.sh                         # AncientBuilding 全量验收（M1-M5）
```

输出 `SMOKE_OK: TheOne native extension` 且退出码 0，表示 DLL 被引擎加载、`TheOneNode` 已注册、方法可调用。

> 引擎从 `.godot/extension_list.cfg` 读取扩展列表，该文件由编辑器扫描生成。全新克隆必须先跑一次 `--headless --editor --quit`，`test-extension.sh` 已内置。

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
