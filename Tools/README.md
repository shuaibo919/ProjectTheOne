# Tools（编辑器期工具）

与游戏运行无关的通用脚本：构建、导入/转换、批处理、截图、工程检查、编辑器自动化。

## 目录

| 路径 | 用途 |
| --- | --- |
| `Build/` | 引擎与原生扩展的构建、启动、冒烟入口 |
| `AncientBuilding/` | 生产用程序纹理烘焙、生成物盘点/清理与 manifest |

## AncientBuilding

| 脚本 | 作用 |
| --- | --- |
| `build_materials.py` | 生成八族 BC/N/ORM 纹理并更新材质索引 |
| `cache_report.py` | 扫描 `Project/Generated/AncientBuilding` 的版本/体积/场景引用；`--prune --yes --manifest` 只清理旧且未引用缓存，并写 `manifest.json` / `README.md` |
| `generate_param_reference.sh` | 调 CLI `params` 重新生成 `Project/addons/ancient_building/PARAMETERS.md`；Git Bash 运行 |

两者都不依赖游戏运行时；使用仓库 `.venv`。缓存清理永远保留当前 `generator_version` 与任何被 `.tscn`/`.tres` 引用的版本，不接受“先删后修”。完整重建顺序见 `Wiki/Temp/008-AncientBuilding.md` §13.5。

## Build（Git Bash 为主）

| 脚本 | 作用 |
| --- | --- |
| `setup-env.sh` | `uv sync`：按 `pyproject.toml` + `uv.lock` 创建 `.venv`（Python 3.13.13 + SCons 4.11.1） |
| `build-engine.sh` | 从 `Engine/` 子模块编译编辑器（`angle=no`，`-j$(nproc)`） |
| `build-native.sh` | 编译 godot-cpp + 全部扩展模块，产物到 `Project/bin/`（`TARGET=template_release` 可切换） |
| `build-all.sh` | 引擎缺失先建引擎，再建扩展 |
| `launch-editor.sh` | 用本地引擎打开 `Project/`（缺引擎会先构建） |
| `run-game.sh` | 运行 Project（主场景尚未定义） |

仓库根快捷方式：`./build.sh`（= build-all）、`./edit.sh`（= launch-editor）。验证脚本按用户要求放本地 `Project/Tests/Temp/` 并由 Git 忽略，不作为 Tools 的交付内容。

`*.ps1` / `*.cmd` 保留为 Windows 原生入口（`-ExecutionPolicy Bypass` 包装），但不再新增；`Build/` 新脚本一律用 Bash 写在 `Tools/` 下，`AncientBuilding/` 的 Python 工具沿用现有烘焙/盘点管线。

所有构建脚本固定做两件事：把 `TMP`/`TEMP` 指向 `.build-temp/`（否则 link.exe 报 `LNK1104`），以及设置 `VSLANG=1033` 让 MSVC 输出英文。并发可用 `JOBS=24 ./build.sh` 覆盖。

## 规则

- 只放可复用的工具，不放一次性调查脚本；一次性脚本用完即删。
- 工具不得被 `Project/` 的运行时场景依赖。
- 每个工具在文件头写：用途、输入、输出、典型命令。
