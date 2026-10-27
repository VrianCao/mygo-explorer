# MyGo Explorer

[![CI](https://github.com/VrianCao/mygo-explorer/actions/workflows/ci.yml/badge.svg)](https://github.com/VrianCao/mygo-explorer/actions/workflows/ci.yml)

用 **[MyGo](https://mygo.egoist.dev)** 自身构建的 **Native UI** 桌面应用：把 MyGo 的全部 UI 与控件
（158 条 inventory 条目）做成可交互的画廊，并让 **macOS / Windows / Linux** 的表现差异可见
（真实运行 + 外观切换 + 三平台截图矩阵）。

> **当前状态：Phase 1.1.0（基线锁定与公开仓库初始化）实现完成，等待用户 GATE-1 复核。**
> 目标应用尚未开始铺页面；GATE-1 通过后按 [TODO.md](TODO.md) 从 Phase 1.2.0 逐 Phase 推进。

## 快速开始

```sh
cd app
go tool mygo dev        # 开发运行（热重载）
go test ./...           # 无窗口 Tester 测试
go tool mygo vet .      # MyGo 生命周期检查（Element/Context 误存等）
go tool mygo build      # 打包本机平台 → build/<goos>-<goarch>/
./scripts/check.sh      # 本地质量门禁：gofmt + test + vet + build + 打包，PASS/FAIL 汇总
```

环境要求：**Go 1.27.3**。`GOTOOLCHAIN=auto`（默认）会按 `app/go.mod` 的 `go 1.27.3`
自动选择/下载工具链；无需在 `PATH` 安装 `mygo`——`go tool mygo` 读取 `app/go.mod` 的
`tool` 指令，首次构建需要网络下载 toolchain 与 module。

## 版本锁定（Pins）

| 项 | 值 |
|---|---|
| MyGo | `github.com/egoist/mygo v0.7.1`（`require` + `tool`，见 [`app/go.mod`](app/go.mod)） |
| Go | `1.27.3`（`app/go.mod` 的 `go` 指令；CI 由 `actions/setup-go` 读取） |
| Go module | `github.com/VrianCao/mygo-explorer/app` |
| App 名称 / identifier | `MyGo Explorer` / `dev.mygoexplorer.app`（[`app/mygo.json`](app/mygo.json)） |
| 平台 | macOS（本机真实运行）+ Windows / Linux（GitHub Actions 三平台矩阵） |
| 许可 | MIT（[LICENSE](LICENSE)；第三方归属见 [NOTICE](NOTICE)） |

决策记录与变更流程见 [docs/DECISIONS.md](docs/DECISIONS.md)。

## 文档

| 文档 | 内容 |
|---|---|
| [TODO.md](TODO.md) | **执行清单**：Project → Phase → Checkbox，含验收条件与 10 个用户 GATE |
| [PLAN.md](PLAN.md) | 实施计划：页面地图、技术架构、测试/CI、里程碑、开放问题 |
| [PREPARATION.md](PREPARATION.md) | 调研与准备：MyGo 理解、158 条 UI 清单、跨平台差异、环境验证 |
| [docs/DECISIONS.md](docs/DECISIONS.md) | 已落库决策 D1–D14 与变更流程 |
| [docs/evidence/](docs/evidence/) | 各 Phase 的命令输出、测试与截图证据 |
| [research/](research/) | 阶段 0 研究产物：文档知识库、inventory、示例分析、环境证据 |

## 仓库结构

```
app/                   # 目标应用（独立 Go module）
  main.go              # 当前为 mygo init 骨架：窗口 + Tester 测试
  mygo.json            # 应用元数据：名称 / identifier / 版本 / 输出目录
  scripts/check.sh     # 本地质量门禁
  .agents/skills/      # MyGo 维护 skill（mygo init 生成）
  resources/icon.png   # 占位图标（Phase 1.10.1 换品牌图标）
.github/workflows/     # CI：macOS + Linux + Windows
docs/                  # 决策与证据
research/ prep/        # 阶段 0 调研与一次性环境探针（保留供追溯）
```

## CI

三平台矩阵（`macos-latest` / `ubuntu-latest` / `windows-latest`）依次执行
`go test ./...` → `go tool mygo vet .` → `go tool mygo build`（各 OS 构建本机平台产物并上传 artifact）。

- Workflow：[`.github/workflows/ci.yml`](.github/workflows/ci.yml)
- Runs：<https://github.com/VrianCao/mygo-explorer/actions/workflows/ci.yml>

## 已知限制

- 本机只有 macOS；Windows / Linux 当前仅由 CI 构建，真实运行与平台截图在 Phase 1.8.0 采集。
- 构建产物未签名 / 未公证（无 Developer ID），仅供本地与测试使用。
- 图标为 `mygo init` 占位图，Phase 1.10.1 替换。
- 本轮（Phase 1.1.0）不含应用功能，`main.go` 仍是模板骨架。

## 许可与署名

- 本项目代码以 **MIT** 许可发布，见 [LICENSE](LICENSE)。
- 第三方组件（MyGo v0.7.1、purego、go-text/typesetting、golang.org/x/*）的许可证与版权声明见
  [NOTICE](NOTICE)；版本由 [`app/go.mod`](app/go.mod) 固定。
- 复用 MyGo 示例 / 文档 demo 的源文件会保留
  “Adapted from github.com/egoist/mygo (MIT)” 文件头（当前尚无此类文件）。

## 下一步

完成 **GATE-1**（步骤见 [TODO.md](TODO.md) 的 GATE-1 一节）后，进入
**Phase 1.2.0 — 外壳与设计系统基础**。
