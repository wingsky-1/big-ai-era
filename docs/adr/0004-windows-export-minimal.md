# 0004. Windows 导出最小化（不调用 rcedit）

日期：2026-09-07 / 状态：accepted

## 背景

在 Linux（本地与 CI runner）上交叉导出 Windows exe 时，若
`export_presets.cfg` 中 `application/modify_resources=true` 或任一 exe 元数据
字段（product_name/company_name 等）非空，导出尾部必然调用 rcedit 改写 PE
资源。rcedit 是 Windows 程序，Linux 下需要 wine 运行且需配置编辑器设置路径。
脚手架默认环境无 wine/rcedit，导致 Windows 导出必败，进而级联使
Release 与 Pages 部署全部跳过（needs: build 失败）。

## 决策

- `application/modify_resources=false`，并清空全部 exe 元数据字段。
- 代价：Windows exe 无自定义图标/版本信息（Godot 默认图标）。
- 后续需要品牌信息时：在 CI Windows job 安装 wine64 + rcedit-x64.exe 并配置
  `export/windows/rcedit_path`，再把 preset 打开——作为独立 PR 处理。

## 后果

- 正向：三端导出在任何干净 Linux 环境开箱即成，发布链路零平台依赖。
- 代价：发布物暂无自定义图标/元数据（对"试玩优先"的 MVP 阶段可接受）。
