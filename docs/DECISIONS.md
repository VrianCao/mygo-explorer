# DECISIONS — MyGo Explorer 决策记录

> 本文件记录**已落库的默认决策**（Decision Log）。GATE-1 由用户逐条确认后，标记为
> `已确认`；此后如需变更，必须走本文件 §3 的变更流程。
> 依据：[PLAN.md §11](../PLAN.md)（开放问题与建议默认值）、[TODO.md](../TODO.md)（Phase 1.1.0）、
> [PREPARATION.md](../PREPARATION.md)（调研与版本事实）。
> 记录日期：2026-10-27（Asia/Shanghai）· 记录人：执行 Agent（Lead）· 状态：**待 GATE-1 用户确认**

---

## 1. 决策总表

| # | 决策项 | 取值 | 日期 | 来源 | 是否可改 |
|---|---|---|---|---|---|
| D1 | 代码托管 | **Public** GitHub 仓库 `github.com/VrianCao/mygo-explorer`（`origin`） | 2026-10-27 | 用户确认（PLAN §6、§11 #3；TODO 基线行） | 不可改：已由用户明确确认；改私有需用户改需求 |
| D2 | App 名称 | **MyGo Explorer** | 2026-10-27 | PLAN §11 #1 默认值 + TODO 基线 | 可改，仅限 GATE-1 确认前；改动需同步 `mygo.json`、README、窗口标题、CI 与 tag |
| D3 | App identifier | **`dev.mygoexplorer.app`** | 2026-10-27 | PLAN §11 #1 默认值（TODO 1.1.1 明示默认） | 可改，仅限 GATE-1 确认前；v1.0.0 发布后不可改（决定 macOS bundle id、用户配置目录与签名身份） |
| D4 | Go module 路径 | **`github.com/VrianCao/mygo-explorer/app`**（`app/` 为独立 module） | 2026-10-27 | Lead 默认：由 D1 仓库 URL + PLAN §3.1 目录结构 `app/` 推导（PLAN §3.2 原为“待定”，见 §2 偏差记录） | 可改，仅限 GATE-1 确认前（当前仅 `go.mod`/`tool` 引用，无外部 import） |
| D5 | 许可证 | **MIT** | 2026-10-27 | PLAN §6/§11 #3（Public repo 已确认） | 不可改：公开仓库已定 MIT；版权署名见 `LICENSE` |
| D6 | 界面语言 | **English + 简体中文（`en`、`zh-Hans`）** | 2026-10-27 | 用户确认（PLAN §11 #4） | 可扩语言（追加 catalog）；不删已有语言 |
| D7 | 目标平台 | **macOS + Windows + Linux**：macOS 本机真实运行；Windows/Linux 由 CI 构建 + 交叉编译验证 | 2026-10-27 | 用户确认（PLAN §11 #2、#6；PREPARATION §6 能力矩阵） | 可改：若用户提供 Win/Linux 真机则追加真机验收，范围不缩小 |
| D8 | 版本基线 | **MyGo `v0.7.1` · Go `1.27.3` · 纯 Go 无 cgo** | 2026-10-27 | PREPARATION（`mygo 0.7.1`、`go list -m`、工具链验证）；PLAN §3.2 | 可改：仅按 PLAN §3.2 升级清单（`go get` → vet → test → golden → migrate-ui）整体升级 |
| D9 | 版本号 | **`0.1.0`**（`mygo.json`），发布 v1.0.0 时改为 `1.0.0` | 2026-10-27 | TODO 1.1.4 | 可改：按 TODO 1.10.2 发布计划 |
| D10 | CI | **GitHub Actions**，矩阵 `macos-latest` / `windows-latest` / `ubuntu-latest` | 2026-10-27 | PLAN §6；TODO 1.1.7 | 可改：不降低三平台覆盖 |
| D11 | Web 版 | wasm（`go tool mygo build -platform web`）+ GitHub Pages，**Phase 1.8.0 实现** | 2026-10-27 | PLAN §11 #8；TODO 1.8.6 | 可改，但降级需用户确认（属 Project DoD） |
| D12 | 自动更新 / 遥测 | **不做** | 2026-10-27 | PLAN §11 #11；TODO 非目标 | 不可改：属非目标 |
| D13 | 签名与分发 | 本机未签名构建 + 公开 Release 未签名包（无 Developer ID/公证证书） | 2026-10-27 | PREPARATION §6、§12；PLAN §11 #7 | 可改：用户提供证书后加签名/公证 |
| D14 | 图标 | 先用 `mygo init` 生成的占位 icon，Phase 1.10.1 换品牌 icon | 2026-10-27 | PLAN §11 #1；TODO 1.10.1 | 可改：发布前替换 |

> 与 PLAN §11 的一致性：D1/D2/D3/D5/D6/D7/D8/D12/D13 与 PLAN §11 的建议默认值一致；
> D4 由“待定”落为具体值（见 §2）；D10/D11 与 PLAN §6 一致；D9 与 TODO 1.1.4 一致。

## 2. 与既有文档的差异记录

| 项 | 文档原状 | 本记录 | 理由 |
|---|---|---|---|
| Go module 路径 | PLAN §3.2 写作 `module <module> // 待定，见 §13`（§13 不存在，实为 §11；§11 未列该项） | 落为 `github.com/VrianCao/mygo-explorer/app` | TODO 1.1.1 要求“Go module 路径”作为决策落库；由 D1 仓库 URL 唯一推导，无需用户先选；GATE-1 一并确认 |
| Go 版本 | PLAN/基线写作 Go 1.27.3 | 本机 host Go 为 1.26.4，由 `GOTOOLCHAIN=auto` 依据 `app/go.mod` 的 `go 1.27.3` 自动选用 go1.27.3 | 不手动安装第二套 Go（PREPARATION §3）；CI 由 `actions/setup-go` 读 `app/go.mod` 安装同一版本 |
| 仓库 owner | PLAN 仅写 `<owner>/mygo-explorer` | `VrianCao`（`gh auth status` 当前账号） | TODO 1.1.6 的 `<owner>` 由本机认证账号确定 |

## 3. 变更流程

1. GATE-1 前：执行者可就 D2/D3/D4 提出替代值，但必须在 `docs/GATES.md` 记录并交用户确认。
2. GATE-1 后：D3/D4 冻结到 v1.0.0；其余变更需用户明确同意，并在本文件追加一行
   `变更日期 / 旧值 → 新值 / 触发原因 / 用户原话`，不删除历史行。
3. 与 TODO.md 冲突时以 TODO.md 为准，并回写本文件与 PLAN。

## 4. GATE-1 待确认清单

用户执行 GATE-1 时，请逐条确认（详见 [TODO.md](../TODO.md) GATE-1）：

- [ ] D2 名称：MyGo Explorer
- [ ] D3 identifier：`dev.mygoexplorer.app`
- [ ] D4 module 路径：`github.com/VrianCao/mygo-explorer/app`
- [ ] D1 公开仓库：`github.com/VrianCao/mygo-explorer`
- [ ] D5 MIT 许可证
- [ ] D6 English + 简体中文
