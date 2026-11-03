# Tools（编辑器期工具）

与游戏运行无关的通用脚本：构建、导入/转换、批处理、截图、工程检查、编辑器自动化。

## 目录

| 路径 | 用途 |
| --- | --- |
| `Build/` | 原生扩展的构建与验证入口 |

## Build

| 脚本 | 作用 |
| --- | --- |
| `setup-env.cmd` | `uv sync`：按 `pyproject.toml` + `uv.lock` 创建 `.venv`（Python 3.13.13 + SCons 4.11.1） |
| `build-native.cmd` | 编译 godot-cpp + `Source/`，产物到 `Project/bin/` |
| `test-extension.cmd` | 用引擎加载 DLL，跑 `Project/Tests/smoke_extension.gd` |

三个 `.cmd` 只是 `-ExecutionPolicy Bypass` 包装器，参数会原样转发给同名 `.ps1`。

构建脚本固定做两件事：把 `TMP`/`TEMP` 指向 `.build-temp/`（否则本机 link.exe 报 `LNK1104`），以及设置 `VSLANG=1033` 让 MSVC 输出英文。

## 规则

- 只放可复用的工具，不放一次性调查脚本；一次性脚本用完即删。
- 工具不得被 `Project/` 的运行时场景依赖。
- 每个工具在文件头写：用途、输入、输出、典型命令。