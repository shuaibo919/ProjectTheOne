# ProjectX

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
| `EngineAdaptor` | `https://github.com/godotengine/godot-cpp` | `4.3` |
| `Wiki` | `https://github.com/shuaibo919/ProjectAbyssWiki.git` | `projectx`（orphan，与旧文档无历史关系） |

首次拉取：

```powershell
git clone --recurse-submodules <this-repo-url> ProjectX
# 或已有仓库：
git submodule update --init --recursive
```

## 当前状态

- 本仓库只包含骨架：Godot 工程尚未初始化内容，C++ 扩展尚未接入构建。
- 规范入口：[Wiki/Spec/001-Overview.md](Wiki/Spec/001-Overview.md)。

## 构建提示

引擎与绑定库的版本关系需要先确认：旧工程使用 Godot 4.7 fork + godot-cpp `4.3` 分支，两者 ABI 并不匹配。接入 `Source/` 前先决定绑定库版本（见 `Source/README.md`）。
## 附注

- `Engine` 为 **浅克隆**（`--depth 1`），只有当前提交的历史。需要完整历史时执行：
  `git -C Engine fetch --unshallow`
- 本机 SSH 的 22 端口不可用，需要推送子模块时走 SSH 443：
  ```powershell
  $env:GIT_SSH_COMMAND='ssh -p 443'
  git -C Wiki push git@ssh.github.com:shuaibo919/ProjectAbyssWiki.git projectx
  ```
- `Wiki` 子模块跟踪 `projectx` 分支（孤立历史），不要合并 `master`。