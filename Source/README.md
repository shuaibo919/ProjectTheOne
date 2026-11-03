# Source（C++ GDExtension）

原生扩展的 C++ 实现。绑定库是 `../EngineAdaptor`（godot-cpp）。

## 版本对应（2026-11-03）

| 组件 | 版本 |
| --- | --- |
| `Engine` | Godot 4.7 beta 自定义 fork，提交 `3bfa50fd` |
| `EngineAdaptor` | godot-cpp `master`，提交 `e103d34`，支持 `api_version=4.3 … 4.8` |
| 目标 API | `4.7` —— godot-cpp 自带 `gdextension/extension_api-4-7.json` |

构建时必须显式传 `api_version=4.7`（godot-cpp 的 `api_version` 没有默认值，缺省会直接报错）。

## 为什么不再是 4.3

旧工程把 godot-cpp 固定在 `4.3` 分支，而引擎是 4.7 fork，ABI 不匹配。godot-cpp 现在按版本提供 API 快照（4.3–4.8），`master` 分支包含 4.7，因此升级到 `master` 并为构建指定 `api_version=4.7`。

## 引擎 API 与官方 4.7 的差异

本工程的引擎是自定义 fork，用引擎自身 dump 出来的 API 与 godot-cpp 官方的 4.7 快照对比：

| 来源 | 体积 | 版本串 |
| --- | ---: | --- |
| 引擎 dump | 6,963,881 B | `4.7.0 beta custom_build` |
| godot-cpp `extension_api-4-7.json` | 6,965,055 B | `4.7.0 stable official` |

两者相差约 1.2 KB，说明 fork 没有改动 GDExtension 暴露面，默认使用官方快照即可。

若后续 fork 改动了绑定接口，用引擎自身 dump 覆盖：

```powershell
# 在 Source/build_api 目录下执行，会生成 extension_api.json
..\..\Engine\bin\godot.windows.editor.x86_64.console.exe --headless --dump-extension-api
# 构建时改用自定义 API
scons api_version=4.7 custom_api_file=Source/build_api/extension_api.json ...
```

`Source/build_api/` 已在 `.gitignore` 中忽略：该文件可由引擎提交确定性重建，不入库。

## 构建环境

- 系统未安装 SCons；旧工程使用 `D:\VibeSpace\ProjectAbyss\.venv`（Python 3.14 + scons）。
- 生成绑定与编译需要 MSVC 工具链（旧工程用它编译过引擎）。
- 本目录尚无 `SConstruct`，接入前先写构建脚本（计划：复用 godot-cpp 的 SConstruct 约定）。

## 规划中的结构

```
Source/
├─ RegisterTypes.cpp      # 扩展入口
├─ <Module>/              # 按模块分目录
├─ build_api/             # 引擎 dump 的 API（忽略，可重建）
└─ SConstruct             # 与 EngineAdaptor 的构建对接
```