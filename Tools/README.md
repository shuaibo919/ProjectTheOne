# Tools（编辑器期工具）

与游戏运行无关的通用脚本：构建、导入/转换、批处理、截图、工程检查、编辑器自动化。

## 目录

| 路径 | 用途 |
| --- | --- |
| `Build/` | 引擎与原生扩展的构建、启动、冒烟入口 |
| `Test/` | 验收脚本 |

## Build（Git Bash 为主）

| 脚本 | 作用 |
| --- | --- |
| `setup-env.sh` | `uv sync`：按 `pyproject.toml` + `uv.lock` 创建 `.venv`（Python 3.13.13 + SCons 4.11.1） |
| `build-engine.sh` | 从 `Engine/` 子模块编译编辑器（`angle=no`，`-j$(nproc)`） |
| `build-native.sh` | 编译 godot-cpp + `Source/`，产物到 `Project/bin/`（`TARGET=template_release` 可切换） |
| `build-all.sh` | 引擎缺失先建引擎，再建扩展 |
| `launch-editor.sh` | 用本地引擎打开 `Project/`（缺引擎会先构建） |
| `run-game.sh` | 运行 Project（主场景尚未定义） |
| `test-extension.sh` | 扩展列表扫描 + `Tests/smoke_extension.gd` |

仓库根还有三个快捷方式：`./build.sh`（= build-all）、`./edit.sh`（= launch-editor）、`./test.sh`（= 验收）。

`*.ps1` / `*.cmd` 保留为 Windows 原生入口（`-ExecutionPolicy Bypass` 包装），但不再新增；新脚本一律用 Bash 写在 `Tools/` 下。

所有构建脚本固定做两件事：把 `TMP`/`TEMP` 指向 `.build-temp/`（否则 link.exe 报 `LNK1104`），以及设置 `VSLANG=1033` 让 MSVC 输出英文。并发可用 `JOBS=24 ./build.sh` 覆盖。

## 规则

- 只放可复用的工具，不放一次性调查脚本；一次性脚本用完即删。
- 工具不得被 `Project/` 的运行时场景依赖。
- 每个工具在文件头写：用途、输入、输出、典型命令。
