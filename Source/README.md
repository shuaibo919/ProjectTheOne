# Source（C++ GDExtension）

原生扩展的 C++ 实现，绑定库位于 `../EngineAdaptor`（godot-cpp）。

## 待决事项

旧工程使用 **Godot 4.7 fork** + **godot-cpp `4.3` 分支**，版本不匹配，无法直接编译出可用绑定。接入前必须先定其中一项：

1. 把 `EngineAdaptor` 切到与 4.7 对应的 godot-cpp 分支/提交（推荐，需确认 godot-cpp 是否已有 4.7 支持）；
2. 把 `Engine` 降到与 godot-cpp 4.3 匹配的 4.3 标签（会丢失 fork 的 4.7 改动）。

在决定前，本目录只放设计说明，不放构建脚本。

## 规划中的结构

```
Source/
├─ RegisterTypes.cpp      # 扩展入口
├─ <Module>/              # 按模块分目录
└─ SConstruct              # 与 EngineAdaptor 的构建对接
```