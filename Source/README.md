# Source（C++ GDExtension）

原生扩展实现。绑定库是 `../EngineAdaptor`（godot-cpp `master`），构建入口在仓库根 `SConstruct`。

## 版本对应

| 组件 | 版本 |
| --- | --- |
| `Engine` | Godot 4.7 beta 自定义 fork，提交 `3bfa50fd` |
| `EngineAdaptor` | godot-cpp `master`，提交 `e103d34` |
| 目标 API | `4.7`（默认用引擎 dump 的 `Source/build_api/extension_api.json`，缺失时回退 godot-cpp 的 4.7 快照） |
| 构建 Python | 3.13.13（uv 托管，`.python-version`） |
| SCons | 4.11.1（`uv.lock`） |

## 文件

| 文件 | 作用 |
| --- | --- |
| `src/register_types.cpp` | 扩展入口 `theone_library_init`，注册 `TheOneNode` |
| `src/theone_node.h/.cpp` | 最小 `Node` 子类，方法 `get_build_info()`，用于证明管线打通 |
| `../SConstruct` | 调用 `EngineAdaptor/SConstruct`，产物写入 `Project/bin/` |
| `../Project/bin/theone.gdextension` | 扩展描述符，`entry_symbol = theone_library_init` |

## 构建（已验证）

```powershell
.\Tools\Build\setup-env.cmd      # 首次：uv sync 创建 .venv
.\Tools\Build\build-native.cmd   # 默认 template_debug，8 并发
.\Tools\Build\build-native.cmd -Target template_release
```

等价的直接命令（需先 `setup-env.cmd`）：

```powershell
$env:TMP='.build-temp'; $env:TEMP='.build-temp'; $env:VSLANG='1033'
.\.venv\Scripts\python.exe -m SCons platform=windows target=template_debug -j8
```

产物：`Project/bin/theone.windows.template_debug.x86_64.dll`（326,144 B）。首次构建连带编译 godot-cpp（约 960 个编译单元，8 并发约 2 分钟），之后增量。

## 验证（已验证）

```powershell
.\Tools\Build\test-extension.cmd
```

输出 `SMOKE_OK: TheOne native extension` 且退出码 0，表示 DLL 被引擎加载、`TheOneNode` 已注册、方法可调用。

> 引擎从 `.godot/extension_list.cfg` 读取扩展列表，该文件由编辑器扫描生成。全新克隆必须先跑一次 `--headless --editor --quit`，否则 headless 运行不加载扩展——`Test-Extension.ps1` 已内置这一步。

## 引擎 API 与官方 4.7 的差异

| 来源 | 体积 | 版本串 |
| --- | ---: | --- |
| 引擎 dump（`Source/build_api/`） | 6,963,881 B | `4.7.0 beta custom_build` |
| godot-cpp `extension_api-4-7.json` | 6,965,055 B | `4.7.0 stable official` |

差约 1.2 KB，说明 fork 未改动 GDExtension 暴露面。`Source/build_api/` 已忽略，可按引擎提交确定性重建：

```powershell
cd Source\build_api
..\..\Engine\bin\godot.windows.editor.x86_64.console.exe --headless --dump-extension-api
```