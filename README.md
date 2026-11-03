# ProjectTheOne

水墨风武侠 ARPG 的新工程骨架。旧工程 `ProjectAbyss` 保留为素材与实现参考，按需移植。

## 目录

| 目录 | 用途 | 版本控制 |
| --- | --- | --- |
| `Engine/` | Godot 源码引擎（fork），submodule | 指针入库 |
| `Project/` | Godot 游戏工程与资产 | 入库 |
| `EngineAdaptor/` | godot-cpp 绑定库，submodule | 指针入库 |
| `Source/` | C++ GDExtension 源码 | 入库 |
| `Tools/` | 编辑器期通用脚本（构建、导入、批处理） | 入库 |
| `Wiki/` | 文档与规范，submodule（独立分支） | 指针入库 |
| `Reference/` | 参考资源（美术、论文、竞品） | 入库，大文件走 LFS |

## 子模块

| 路径 | 远端 | 分支 |
| --- | --- | --- |
| `Engine` | `https://github.com/shuaibo919/godot.git` | 默认分支 |
| `EngineAdaptor` | `https://github.com/godotengine/godot-cpp` | `master`（`api_version=4.7`） |
| `Wiki` | `https://github.com/shuaibo919/ProjectAbyssWiki.git` | `theone`（orphan，与旧文档无历史关系） |

首次拉取：

```powershell
git clone --recurse-submodules <this-repo-url> ProjectTheOne
# 或已有仓库：
git submodule update --init --recursive
```

## 当前状态

- 仓库骨架 + 三个子模块已就位；Godot 工程尚未加入游戏内容。
- **原生扩展管线已打通并验证**（2026-11-03）：godot-cpp `master` + 引擎 4.7 fork，`TheOneNode` 注册成功。
- 规范入口：[Wiki/Spec/001-Overview.md](Wiki/Spec/001-Overview.md)。

## 构建与验证

```powershell
.\Tools\Build\build-native.cmd     # 构建 godot-cpp + 原生扩展（首次约 2 分钟）
.\Tools\Build\test-extension.cmd   # 用引擎加载 DLL 并跑冒烟脚本
```

| 项 | 结果 |
| --- | --- |
| 构建产物 | `Project/bin/theone.windows.template_debug.x86_64.dll`（326,144 B） |
| 链接的绑定库 | `EngineAdaptor/bin/libgodot-cpp.windows.template_debug.x86_64.lib` |
| 冒烟输出 | `SMOKE_OK: TheOne native extension`，退出码 0 |
| 工具链 | VS 2026（`E:\ProgramWares\vs2026`）+ SCons 4.10.1（旧工程 `.venv`） |

脚本默认使用旧工程的 Python 环境；换机器时用 `-Python` 参数或 `THEONE_PYTHON` 环境变量指定。

> 系统默认执行策略禁止运行未签名 `.ps1`。`.cmd` 包装器内部用 `-ExecutionPolicy Bypass` 调用，直接双击或命令行运行即可；要单独跑 `.ps1` 时用：
> `powershell -NoProfile -ExecutionPolicy Bypass -File Tools\Build\Test-Extension.ps1`

## 构建提示

绑定库已升级到 godot-cpp `master`（支持 API 4.3–4.8），构建时指定 `api_version=4.7`。引擎 API 与官方 4.7 快照差异约 1.2KB，详见 `Source/README.md`。
## 附注

- `Engine` 为 **浅克隆**（`--depth 1`），只有当前提交的历史。需要完整历史时执行：
  `git -C Engine fetch --unshallow`
- 本机 SSH 的 22 端口不可用，需要推送子模块时走 SSH 443：
  ```powershell
  $env:GIT_SSH_COMMAND='ssh -p 443'
  git -C Wiki push git@ssh.github.com:shuaibo919/ProjectAbyssWiki.git theone
  ```
- `Wiki` 子模块跟踪 `theone` 分支（孤立历史），不要合并 `master`。