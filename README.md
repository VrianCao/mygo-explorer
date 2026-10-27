# MyGo Explorer — 阶段 0（调研与准备）

本仓库用于开发一个用 **[MyGo](https://mygo.egoist.dev)** 自身构建的 Native UI 应用，展示 MyGo 的全部 UI/控件，并对比 macOS / Windows / Linux 上的表现。

**当前状态：阶段 0 完成，目标应用尚未开始实现（按用户要求）。**

## 从这里开始

| 文档 | 内容 |
|---|---|
| [PREPARATION.md](PREPARATION.md) | 调研与准备报告：MyGo 深度理解、文档清单、UI 清单、跨平台差异、环境验证结果、风险、就绪检查 |
| [PLAN.md](PLAN.md) | 实施计划提案：产品设计、21 页页面地图、技术架构、跨平台截图策略、测试、CI、里程碑、开放问题 |
| [TODO.md](TODO.md) | **执行清单**：Project(1.0.0) → Phase(1.1.0…1.10.0) → Checkbox，含验收条件与 10 个用户 GATE 复核点 |
| [research/](research/) | 阶段 0 研究产物：文档知识库、158 条控件清单、示例分析、环境证据 |
| [prep/probe-native/](prep/probe-native/) | 一次性 CLI 脚手架探针（环境验证用，不是目标应用） |
| [prep/scripts/preflight.sh](prep/scripts/preflight.sh) | 环境自检（19 PASS / 0 FAIL；`--gui` 含真实窗口） |

## 快速验证环境

```sh
export PATH="$HOME/go/bin:$PATH"      # mygo 0.7.1
./prep/scripts/preflight.sh           # 约 6s；--gui 会短暂打开探针窗口
```

## 关键事实

- MyGo **v0.7.1**（2026-10-27 发布），纯 Go、无 cgo，Native UI 由 MyGo 自己在 GPU 上绘制。
- 项目 pin：Go **1.27.3** + `tool github.com/egoist/mygo/cmd/mygo` + `require github.com/egoist/mygo v0.7.1`。
- 本机已验证：无窗口测试、真实 Metal 窗口渲染、`CapturePage` 截图、热重载、三平台交叉编译、wasm 构建全部 PASS。
- 已知限制：本机无 Windows/Linux GUI 运行时（仅交叉编译）；无 Developer ID/公证证书；跨平台真实截图需 CI/真机。

## 下一步

代码托管已确认使用 **Public GitHub repo**（见 [PLAN.md](PLAN.md) §6/§11）。其余开放问题确认后，按 [TODO.md](TODO.md) 从 **Phase 1.1.0** 开始执行（每个 Phase 末尾有必须通过的 GATE）。
