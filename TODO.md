# TODO — MyGo Explorer 执行清单

> 层级：**Project(X.x.x) → Phase(x.X.x) → Checkbox(x.x.X)**  
> 本文件是唯一执行依据：范围、顺序、验收、GATE 都以本文件为准；与 [PLAN.md](PLAN.md) 冲突时，以本文件为准，并回写 PLAN。
> 基线：MyGo **v0.7.1** · Go **1.27.3** · 纯 Go 无 cgo · 公开仓库 `mygo-explorer`（Public，已确认）
> 关联：[PREPARATION.md](PREPARATION.md)（调研/环境）· [PLAN.md](PLAN.md)（方案）· [research/ui-catalog/SCREENS.md](research/ui-catalog/SCREENS.md)（逐页规格）· [research/ui-catalog/inventory.json](research/ui-catalog/inventory.json)（158 条目）

---

## 0. 使用规则（先读再执行）

### 0.1 状态图例

| 标记 | 含义 | 允许的操作 |
|---|---|---|
| `[ ]` | 未开始 | 只有当前 Phase 内的任务可开始 |
| `[~]` | 进行中 | **同一时刻全局只允许一个** `[~]` |
| `[x]` | 已完成 | 必须附证据（命令输出/截图/测试名/提交 SHA），否则视为未完成 |
| `[!]` | 阻塞 | 必须写明阻塞原因与需要谁决策，并立即通知用户 |
| `SKIPPED` | 用户主动跳过 | 只允许用户明确说“跳过 GATE-x / 跳过 1.x.y”后标记，并记录到 `docs/GATES.md` |

### 0.2 GATE 规则（防止 Long Session 跑偏）

1. **GATE = 人工复核点**：GATE 不是自动化测试，必须由**用户实际观察/操作/试用**后给出结论。
2. **默认必须执行**：GATE 未通过前，禁止开始下一 Phase 的任何实现工作（可以修本 Phase 的 bug）。
3. **只有用户主动跳过才能继续**：用户需明确说出「跳过 GATE-x」（或等价明确指令），执行者才能在 `docs/GATES.md` 记录 `SKIPPED` 并继续；执行者**不得**自行判断“看起来没问题”而跳过。
4. **每次 GATE 必须产出**：
   - 一份 ≤ 15 行的 Phase 摘要（做了什么、证据路径、遗留问题）；
   - 证据（截图/日志/测试输出/CI run URL）；
   - 给用户的**可执行复核步骤**（具体命令 + 具体观察点 + 预期结果）；
   - `docs/GATES.md` 记录：GATE 编号、日期、结论（PASS/SKIP/FAIL）、用户原话、后续动作。
5. **FAIL 处理**：用户提出任何不通过项 → 停留在本 Phase 修复；修复后**重新提交同一 GATE**，不得跳 Phase。
6. **方向对齐**：每个 GATE 都要求用户回答一句「当前成果是否仍对齐项目目标（展示全部 UI/控件 + 各系统表现）？」；答“否”则立即停下重新对齐需求。

### 0.3 Long Session 守则

- **单 Phase 单分支**：`phase/x.y.z` 分支 → PR → CI 绿 → GATE → 合并 main。不跨 Phase 混提交。
- **一次只推进一步**：完成一个 Checkbox 就更新本文件状态与证据；禁止“批量静默推进一个 Phase 再说”。
- **3 次失败升级**：同一 Checkbox 连续 3 次达不到验收条件，或修复尝试超过 2 小时 → 停下，向用户说明卡点与 2–3 个方案，等决策。
- **1.5 倍超时升级**：某 Phase 实际耗时超过估算 ×1.5，立即停下汇报进度与剩余工作。
- **范围冻结**：Phase 进行中不接受新功能；新想法写入 `docs/BACKLOG.md`，GATE 时由用户决定是否纳入。
- **不破坏已验证内容**：任何改动后必须重跑 `go test ./...` + `go tool mygo vet .`；失败不得提交。
- **证据可复查**：所有验证结果写入 `docs/evidence/phase-x.y.z/`（命令、输出、截图、耗时），不依赖会话记忆。
- **禁止假验收**：不得把“代码写完”当作完成；每个 Checkbox 的“→ 验收”必须真实命令/产物通过。

### 0.4 统一验收术语

- **验收条件（AC）**：客观、可复现的通过条件（命令返回、文件存在、数量、截图、测试名）。
- **验收内容**：用户/复核者实际要看的东西（运行哪个命令、点哪里、看哪个文件/截图）。
- **验收说明**：由谁、以什么方式判定（自动测试 / 代码审查 / **用户 GATE** / CI）。
- 每个 Checkbox 行内用 `→ 验收:` 给出可执行的通过条件；每个 Phase 末尾有完整的「验收条件 / 验收内容 / 验收说明」。

### 0.5 GATE 总览

| GATE | 所属 Phase | 类型 | 用户必须亲自做的事 |
|---|---|---|---|
| GATE-1 | 1.1.0 | 仓库与基线 | 打开公开仓库 URL、本地启动骨架、确认名称/identifier |
| GATE-2 | 1.2.0 | 外壳与设计系统 | 运行 App，走查导航/主题/命令面板/页面模板 |
| GATE-3 | 1.3.0 | 试点页模式 | 操作 5 个试点页，确认“页面模板 + 代码片段”模式可复制 |
| GATE-4 | 1.4.0 | 目录 A + 性能 | 抽查 3 页 + 10k 列表滚动，确认性能/观感 |
| GATE-5 | 1.5.0 | 全量覆盖 | 逐项确认 158/158 可达、命令面板可搜到、语言可切 |
| GATE-6 | 1.6.0 | 复杂内容 | 图表/编辑器/Markdown/玻璃/拖放逐个实操 |
| GATE-7 | 1.7.0 | 真实桌面能力 | **必须在真机**试菜单/托盘/通知/对话框/快捷键/第二窗口 |
| GATE-8 | 1.8.0 | 跨平台证据 + Web | 看三平台真实截图矩阵、打开浏览器版 |
| GATE-9 | 1.9.0 | 无障碍/i18n/RTL | 键盘-only 走查 + VoiceOver 抽查 + RTL 对比 |
| GATE-10 | 1.10.0 | 发布验收 | 安装 dmg、完整体验、审 Release/README/Pages |

---

# Project 1.0.0 — MyGo Explorer v1.0

**项目目标**：用 MyGo 自身构建一个 Native UI App，展示 MyGo 的**全部 UI 与控件（158/158）**，并让用户**直观看到 macOS / Windows / Linux 的表现差异**（真实运行 + 外观切换 + 三平台截图矩阵）。

**项目验收（Project DoD，全部满足才可发布 1.0.0）**

1. 公开仓库 `mygo-explorer`，MIT License，README 含三平台截图、覆盖徽章、运行说明。
2. 单一 Native UI 应用，macOS/Windows/Linux 均可在 CI 构建；macOS 本机真实运行通过。
3. 158/158 inventory 条目均可达（≤2 次点击），每页含 live demo、变体、状态、API、代码片段、文档链接、平台说明。
4. `ui` 包公开构造器覆盖率 100%（完整性测试守护）。
5. Appearance Lab 与 Platform 页可用：可实时切换主题/accent/密度/字号/RTL/locale/zoom；显示运行时平台真相与三平台差异矩阵。
6. 三平台 CI 绿（test/vet/golden/build），真实截图矩阵已生成并在 App 内展示。
7. 无障碍/i18n（en+zh）/RTL 走查通过；键盘可完成全部导航。
8. v1.0.0 Release 发布（公开），附 macOS/Windows/Linux 产物与截图包；web 版（GitHub Pages）可访问。
9. GATE-1…GATE-10 全部 PASS 或由用户明确 SKIP，且记录在 `docs/GATES.md`。

**非目标**（出现即拒绝，除非用户改需求）：通用 UI 设计器；文档站替代品；自动更新；遥测；私有仓库托管（已确认用 Public）；替换 MyGo 主题皮肤；Windows/Linux 签名分发（可选后置）。

---

## Phase 1.1.0 — 基线锁定与公开仓库初始化

**目标**：把“调研结论 + 默认决策”固化为可执行项目：pin 版本、建公开仓库、CI 骨架、可运行骨架、首批证据。
**前置**：无（Phase 0 已完成）。
**估算**：1 天。

- [x] **1.1.1 决策落库**：新建 `docs/DECISIONS.md`，记录：Public repo（已定）、名称 `MyGo Explorer`、identifier `dev.mygoexplorer.app`（默认，GATE-1 确认）、Go module 路径、MIT、en+zh、三平台目标、MyGo v0.7.1 固定。
  → 验收：文件存在；每条决策含“日期/来源/是否可改”；与 PLAN §11 一致。
  → 证据：`docs/DECISIONS.md`（D1–D14 总表 + §2 差异记录 + §4 GATE-1 待确认清单）。
- [x] **1.1.2 初始化 app 模块**：在 workspace 下执行 `mygo init -template native app -name "MyGo Explorer" -module <module>`；确认生成 `main.go`、`main_test.go`、`go.mod`、`mygo.json`、`resources/icon.png`、`.agents/skills/mygo-maintenance/`、`.gitignore`。
  → 验收：文件齐全；`cd app && go version` 输出 `go1.27.3`。
  → 证据：`docs/evidence/phase-1.1.0/01-init.log`、`02-scaffold.log`（`go1.27.3` + 文件清单 + `go test` ok）。注：CLI 的 flag 解析要求 flags 在目录前，实际命令为 `mygo init -template native -name "MyGo Explorer" -module github.com/VrianCao/mygo-explorer/app app`。
- [x] **1.1.3 锁定依赖**：确认 `app/go.mod` 含 `go 1.27.3`、`tool github.com/egoist/mygo/cmd/mygo`、`require github.com/egoist/mygo v0.7.1`；执行 `go mod tidy` 后 `git diff --exit-code` 无变化。
  → 验收：`go list -m github.com/egoist/mygo` = `github.com/egoist/mygo v0.7.1`；输出存档。
  → 证据：`docs/evidence/phase-1.1.0/03-pin.log`（tidy 后 `git diff` 空；`go list -m` = v0.7.1；`go tool mygo version` = 0.7.1；`GOVERSION` = go1.27.3）。
- [ ] **1.1.4 配置 mygo.json**：`name: "MyGo Explorer"`、默认 identifier、`version: "0.1.0"`（发布时改 1.0.0）、`out: "build"`；`go tool mygo build` 产出 `build/darwin-arm64/MyGo Explorer.app`。
  → 验收：产物路径与名称正确；`plutil -p ".../Info.plist"` 的 CFBundleName/Identifier 正确。
- [ ] **1.1.5 仓库卫生文件**：`LICENSE`（MIT）、`NOTICE`/README credits（MyGo 及复用示例的 MIT 归属）、`.gitignore`（`/reference/`、`app/build/`、`app/.mygo/`、`*.p12`、`mygo-update.key`、`docs/evidence/**/*.tmp`、`.DS_Store`）。
  → 验收：`git check-ignore -v` 命中上述敏感/临时路径；无密钥文件被跟踪。
- [ ] **1.1.6 创建公开仓库**：`gh repo create <owner>/mygo-explorer --public --source . --remote origin --push`；确认匿名可访问；设置 description/topics（`go`、`native-ui`、`mygo`、`gallery`）。
  → 验收：`gh repo view --json visibility -q .visibility` 输出 `PUBLIC`；无痕浏览器可打开。
- [ ] **1.1.7 CI 骨架**：`.github/workflows/ci.yml`，矩阵 `macos-latest / windows-latest / ubuntu-latest`；步骤：checkout → `actions/setup-go`（读 `app/go.mod`）→ `cd app && go test ./...` → `go tool mygo vet .` → `go tool mygo build`（各 OS 构建本机平台）→ 上传日志/产物。
  → 验收：首次 Actions run 三个 job 全绿（附 run URL）。
- [ ] **1.1.8 本地校验脚本**：`app/scripts/check.sh`（gofmt 检查 + `go test ./...` + `go tool mygo vet .` + `go build ./...` + `go tool mygo build`），输出 PASS/FAIL 汇总。
  → 验收：脚本 exit 0；故意改坏一个测试时 exit ≠ 0（自测一次后还原）。
- [ ] **1.1.9 初始提交与 tag**：提交初始代码；`git tag v0.1.0`；README 最小版（定位、pins、运行命令、链接 PREPARATION/PLAN/TODO）。
  → 验收：`git log --oneline -1` 与 `git tag` 可见；README 内链接 200。
- [ ] **1.1.10 骨架冒烟运行**：`cd app && go tool mygo dev` 启动窗口 `MyGo Explorer`，标题正确，Ctrl+C 干净退出；截图存 `docs/evidence/phase-1.1.0/smoke.png`；确认无残留进程。
  → 验收：截图存在；`pgrep -fl "MyGo|mygo dev"` 无结果。

**Phase 验收条件（AC）**

1. `app/` 模块可构建、可运行、测试通过。
2. 公开仓库可访问，初始 commit + CI 绿。
3. 版本 pin 与调研一致（go1.27.3 / mygo v0.7.1）。
4. 决策、证据、README、LICENSE、.gitignore 齐备。

**验收内容**：仓库 URL、CI run URL、`app/go.mod`、`docs/DECISIONS.md`、`docs/evidence/phase-1.1.0/`（`go version` 输出、build 产物、smoke.png）。

**验收说明**：1–4 由执行者用命令自动验证；最终由用户完成 GATE-1。

### GATE-1 — 仓库与基线确认（必须）

**用户操作（约 5 分钟）**

1. 打开公开仓库 URL（未登录/无痕窗口），确认能访问、README 可读。
2. 本地执行：`cd app && go tool mygo dev`，确认窗口标题为 `MyGo Explorer`，关闭后无残留进程。
3. 查看 `docs/DECISIONS.md`，确认：名称、identifier、module 路径、公开仓库、MIT、en+zh 均无异议。

**通过标准**：用户回复「GATE-1 PASS」并确认上述三项；或指出需修改项（修改后重提）。**未通过前，禁止进入 Phase 1.2.0。**

---

## Phase 1.2.0 — 外壳与设计系统基础

**目标**：建立 App 的“骨架 + 页面模板 + 外观引擎”，让后续按模式批量铺页面。
**前置**：GATE-1 PASS。
**估算**：3–4 天。

- [ ] **1.2.1 App 状态与主窗口**：`appState`（router、appearance、settings、pages 状态容器）；`NewWindow{Title:"MyGo Explorer", Width:1180, Height:760, MinWidth:900, MinHeight:600, StateKey:"explorer", TitleBarStyle: mygo.TitleBarHidden, Content: ui.View(app.view)}`。
  → 验收：窗口以 1180×760 打开；重启后记住尺寸/位置；`c.TitleBar()` 在 macOS 返回非零高度。
- [ ] **1.2.2 外壳布局**：`Row(Sidebar(240) + Column(Toolbar + Router.View(Scroll(page))))`；侧栏分组 `Elements / Content / Platform / Tooling`，21 条占位页（图标 + 标题 + badge 条目数）；内容区 `MinWidth(0)`。
  → 验收：侧栏 21 项可点、分组正确；窗口缩到 900 宽不溢出；RTL 下侧栏在右侧。
- [ ] **1.2.3 路由与深链**：`ui.NewRouter("/overview")`；定义 **21 条路由 = 20 个内容页（SCREENS §1–§20）+ `/settings`**；每页 `r.Title(...)`；`--open /charts` 启动直达；`/data/list/{row}` 等详情路由可回退。
  → 验收：`go test ./internal/shell -run TestRoutes` 通过；命令行 `--open /actions` 启动显示 Actions 页。
- [ ] **1.2.4 工具栏**：BackButton/ForwardButton/Breadcrumbs/Spacer；主题菜单（System/Light/Dark）、语言菜单（占位 en/zh）、RTL Toggle、Zoom −/重置/+、平台徽章（`runtime.GOOS` + 渲染后端 + `ScaleFactor`）。
  → 验收：每个控件可操作；Breadcrumbs 随路由更新；缩放 50%/100%/200% 内容清晰（非位图放大）。
- [ ] **1.2.5 快捷键**：⌘1…⌘9 跳页、⌘K 命令面板、⌘+/⌘−/⌘0 缩放、⌘[ / ⌘] 前进后退、⌘⇧L 切语言、⌘⇧D 切方向；Windows/Linux 用 Ctrl/Alt 对应。
  → 验收：`go test ./internal/shell -run TestShortcuts` 通过；macOS 手按全生效。
- [ ] **1.2.6 命令面板（骨架）**：⌘K 打开 Overlay + SearchField；过滤页面名；↑↓ 选择、Enter 跳转、Esc 关闭；无结果显示提示。
  → 验收：输入 “char” 可跳到 Charts；键盘全程可用；Esc 关闭后焦点回到原控件。
- [ ] **1.2.7 外观引擎**：`internal/appearance`：`mode(system|light|dark)`、`accent(system|custom)`、`density(3|4|5)`、`fontScale(1|1.15|1.3)`、`radius(0|6|10)`；每帧派生 `*ui.Theme` 并 `c.SetTheme`；启动读取 `settings.json`（`mygo.App.Path(mygo.PathUserConfig)`），修改即保存（防抖 300ms）。
  → 验收：切换主题/密度/字号后，整窗立即变化；重启保持；`settings.json` 内容正确。
- [ ] **1.2.8 页面模板组件**：`PageHeader`（标题/目的/文档链接/源码引用）、`DemoCard`、`StateRail`（状态按钮）、`SnippetCard`（代码 + 复制）、`APITable`（构造器/方法/事件/状态）、`PlatformNotes`（平台差异 + 徽章）。
  → 验收：临时路由 `/template-demo` 渲染 6 个组件供本 Phase 验收，验收后**删除该路由**；6 组件随后由 Overview/Foundations 正式使用；`go test ./internal/shell -run TestTemplate` 通过。
- [ ] **1.2.9 Overview 页**：平台档案卡（GOOS/GOARCH/renderer 推断/scale/theme/accent）、能力徽章（WebViewAvailable/NotificationsSupported/Vibrancy/tray/shortcut）、库存计数（19 分类/158 条目/覆盖 0/158）、快捷入口、spinner/meter/progress 三连。
  → 验收：数据与真实环境一致（macOS 应为 Metal 推断、scale=2）；计数来自 registry 非硬编码。
- [ ] **1.2.10 Foundations 页**：颜色 token 网格（16+ 项，含 hex）、light/dark 并排、字体样张（字号/字重/装饰/对齐）、Spacing/Radius/Shadow/Blur token、`MeasureText` 读数、系统 accent 与自定义 accent 对比。
  → 验收：切换主题时两栏同步；所有 token 来自 `ui.Theme`/`c.Preferences()`，无硬编码色值（除展示 hex）。
- [ ] **1.2.11 测试与静态检查**：Tester 冒烟（启动/导航/主题/命令面板）；`go tool mygo vet .` 干净；`gofmt -l` 为空。
  → 验收：`app/scripts/check.sh` PASS；vet 输出 “no findings”。
- [ ] **1.2.12 截图基线（壳层）**：Overview/Foundations × light/dark 用 `ui.Render` 生成到 `app/testdata/golden/<goos>/`；提供 `-update` 开关；提交基线。
  → 验收：`go test ./internal/capture -run TestGolden` 通过；基线 PNG 肉眼正常（黑色/空白即失败）。

**Phase 验收条件（AC）**

1. App 以目标窗口打开；21 条路由可达；侧栏/工具栏/面包屑行为正确。
2. 外观切换（主题/accent/密度/字号/RTL/zoom）实时生效并持久化。
3. 命令面板、快捷键可用。
4. 页面模板 6 组件齐备且被 Overview/Foundations 实际使用。
5. `go test ./...`、`go tool mygo vet .`、gofmt 全绿；壳层 golden 截图存在。

**验收内容**：运行 `cd app && go tool mygo dev`；截图（light/dark/RTL/zoom）；`app/testdata/golden/`；测试输出；`docs/evidence/phase-1.2.0/`。

**验收说明**：1–5 自动验证；GATE-2 由用户实机走查并判定“外壳与页面模板是否值得批量复制”。

### GATE-2 — 外壳与设计系统（必须）

**用户操作（约 10 分钟）**

1. 运行 `cd app && go tool mygo dev`。
2. 依次：侧栏点 5 个页面 → 用 ⌘K 搜索跳转 → 切换 Light/Dark/System → 切换 accent/密度/字号 → 切 RTL 再切回 → 缩放 200% 看文字 → 重启 App 确认设置保留。
3. 打开 Overview/Foundations，判断：① 信息是否有用；② 页面模板（卡片/代码/API/平台注记）是否够用；③ 视觉是否“像原生 MyGo 应用”。

**通过标准**：用户回复「GATE-2 PASS」并给出至少一条体验问题（没有则说“无”）；有问题先修再重提。**未通过前，禁止进入 Phase 1.3.0。**

---

## Phase 1.3.0 — 试点分类页（5 页）与模式验证

**目标**：用 5 个代表页验证“registry + 页面模板 + 代码片段 + 截图”的批量生产模式，确认后可复制到全量。
**前置**：GATE-2 PASS。
**估算**：2–3 天。

- [ ] **1.3.1 Actions 页**：inventory Actions 全部 7 条（`button`、`button-base`、`menu-button`、`primary-button`、`toggle`、`toggle-base`、`toggle-group`）；含变体网格、真实禁用/焦点状态、点击计数、快捷键示例、API 表、代码片段、平台注记。
  → 验收：页面所有条目可在两跳内到达；Tester 测试 `TestActionsPage` 通过；截图 light/dark 各 1 张。
- [ ] **1.3.2 Text Inputs 页**：inventory Text Inputs 全部 13 条（`text-input`、`text-input-base`、`text-input-buffer`、`text-input-buffer-base`、`text-area`、`text-area-base`、`text-area-buffer`、`text-area-buffer-base`、`search-field`、`token-field`、`autocomplete`、`number-input`、`editable-text`）。
  → 验收：能输入/选择/清除；禁用与只读可见；Tester `TestInputsPage` 通过；截图 2 张。
- [ ] **1.3.3 Selection 页**：inventory Selection Controls 全部 16 条（`checkbox`、`checkbox-base`、`checkbox-group`、`radio`、`radio-base`、`radio-group`、`switch`、`switch-base`、`segmented`、`segmented-base`、`combobox`、`combobox-base`、`select`、`select-base`、`tabs`、`tabs-base`）；Base 与主题版并排。
  → 验收：checked/mixed/disabled/readonly 状态真实可见；键盘可操作；Tester 通过。
- [ ] **1.3.4 Overlays 页**：inventory Overlays 全部 9 条（`modal`、`alert-dialog`、`dialog-base`、`popover`、`popover-base`、`overlay`、`toast-base`、`toast-viewport-base`、`tooltip-base`）；注意：主题 Toast 用 `c.Toast`、Tooltip 用 `Element.Tooltip`，不要虚构构造器；含 ContextMenu 演示（菜单 API，非 inventory 条目）。
  → 验收：每个 Overlay 可打开/关闭；Escape 生效；焦点陷阱正确；Tester 通过。
- [ ] **1.3.5 Data Display 试点**：List（1,000 行虚拟滚动 + 多选 + 键盘）、Table（排序/编辑 1 列）、GridView 基础。
  → 验收：滚动无卡顿；键盘可选中；Tester 通过。
- [ ] **1.3.6 代码片段生成器 v1**：`tools/snippetgen` 用 AST 抽取这 5 页的 demo 函数 → `internal/snippets/<id>.go.txt`（`go:embed`）；`go generate ./...` 可重生成；生成结果提交；测试校验“重新生成 = 已提交”（防漂移）。
  → 验收：`go generate ./... && git diff --exit-code` 通过；SnippetCard 显示真实源码且可复制。
- [ ] **1.3.7 截图管线 v1**：`internal/capture` 提供 `RenderPage(app, route, theme, size) *image.RGBA`；5 页 × light/dark 生成基线；`TestGolden` 通过；失败时输出 diff 图路径。
  → 验收：`go test ./internal/capture -run TestGolden` PASS；基线数量 = 5×2。
- [ ] **1.3.8 页面测试**：5 页各一个 Tester 行为测试（交互 + 状态切换 + 路由）。`go test ./...` 全绿；`go tool mygo vet .` 干净。
  → 验收：测试名清单存档；覆盖率报告（可选）。
- [ ] **1.3.9 页面模式文档**：`docs/PAGE-PATTERN.md`：如何新增一个页面（注册 Entry、写 demo、加变体/状态、生成片段、加测试/截图、更新文档链接）——目标：后续页面“照文档复制即可”。
  → 验收：一位未参与的人按文档能在 30 分钟内加出一个占位页（自测一次）。

**Phase 验收条件（AC）**

1. 5 个试点页内容完整（条目/变体/状态/API/片段/平台注记）。
2. 片段生成与校验、golden 截图、Tester 测试三条流水线可重复。
3. `docs/PAGE-PATTERN.md` 可让后续页面机械复制。

**验收内容**：5 页截图；`app/internal/snippets/`；`app/testdata/golden/`；测试输出；`PAGE-PATTERN.md`。

**验收说明**：1–3 自动/文档验证；GATE-3 由用户实操 5 页并确认“模式可复制”。

### GATE-3 — 试点页模式确认（必须）

**用户操作（约 10 分钟）**

1. 运行 App，依次进入 Actions / Inputs / Selection / Overlays / Data 试点页。
2. 每页做至少 2 个交互（输入、勾选、开弹窗、列表选择）；展开 “Variants & states” 与 “Code”，确认代码片段与真实 demo 一致。
3. 判断：① 页面信息密度是否合适；② 状态展示是否直观；③ 该模板放大到 21 页是否会失控。

**通过标准**：用户回复「GATE-3 PASS」；若认为模板需调整，在本 Phase 内先改模板再重提，**禁止**带问题进入铺量。

---

## Phase 1.4.0 — 目录 A（布局/文本/导航/数据/滑块/选择器/表单）

**目标**：完成 7 个基础分类页，并压测 10k 列表与表格。
**前置**：GATE-3 PASS。
**估算**：5–6 天。

- [ ] **1.4.1 Layout 页**：inventory Layout 全部 13 条（`box`、`column`、`row`、`divider`、`spacer`、`scroll`、`scroll-horizontal`、`scroll-both`、`grid`、`split`、`split-percent`、`split-vertical`、`split-vertical-percent`）；含 Wrap/对齐/伸展演示、窗口缩放压力测试。
  → 验收：13 条全在页内；拖动分隔条可用；窄窗不溢出；Tester + golden 通过。
- [ ] **1.4.2 Text 页**：inventory Text & Typography 全部 4 条（`text`、`textf`、`rich-text`、`link`）；字号/字重/装饰/对齐/MaxLines/单行省略、可选文本、富文本 Span、CJK/emoji/RTL 样例、字体列表（`FontFamilies`）。
  → 验收：所有文本状态可见；复制/选择可用；Tester + golden 通过。
- [ ] **1.4.3 Navigation 页**：inventory Navigation 全部 8 条（`sidebar`、`sidebar-item`、`sidebar-section`、`back-button`、`forward-button`、`breadcrumbs`、`toolbar`、`find-bar`）；含嵌套路由、历史栈、Router 深链与过渡演示。
  → 验收：路由前进/后退/深链正确；Tester 通过。
- [ ] **1.4.4 Data Display 完整页**：inventory Data Display 全部 11 条（`list-scrolling`、`table`、`tree`、`tree-item`、`outline`、`outline-table`、`grid-view`、`accordion`、`accordion-item`、`collapsible`、`collapsible-base`）；List 用 10,000 行/混合行高/多选/右键菜单/键盘；行详情路由 `/data/list/{row}`。
  → 验收：10k 行滚动流畅（无 >16ms/帧 持续掉帧）；排序/编辑正确；Tester + golden 通过。
- [ ] **1.4.5 Sliders & Steppers 页**：Sliders & Steppers 5 条（`slider`、`slider-base`、`range-slider`、`step-slider`、`stepper`）+ Feedback & Status 5 条（`progress`、`meter`、`rating`、`spinner`、`badge`）。
  → 验收：拖动/键盘/禁用状态正确；Tester 通过。
- [ ] **1.4.6 Pickers 页**：inventory Pickers 全部 5 条（`calendar`、`date-input`、`time-input`、`color-picker`、`color-well`）；区域格式联动（首周日/12-24 小时制）。
  → 验收：切换 locale 后日期/时间格式变化；Tester 通过。
- [ ] **1.4.7 Forms & Fields 页**：inventory Forms & Fields 全部 3 条（`form`、`field`、`fieldset`）；标签位置/错误提示/禁用/只读。
  → 验收：表单布局正确；错误态可见；Tester 通过。
- [ ] **1.4.8 每页测试 + golden + 文档链接 + 平台注记**；`gofmt`、`go test ./...`、`mygo vet` 全绿。
  → 验收：7 页测试清单 + 14 张基线截图；`app/scripts/check.sh` PASS。
- [ ] **1.4.9 性能记录**：10k 列表滚动、页面切换 build 时间（`MYGO_FRAME_STATS=1`）、内存占用；写入 `docs/evidence/phase-1.4.0/perf.md`。
  → 验收：页面切换 build < 16ms；空闲 CPU ~0%；无内存持续增长。

**Phase 验收条件（AC）**

1. 7 页内容完整、可达、状态/变体/API/代码/平台注记齐全。
2. 10k 列表与表格性能达标。
3. 测试、vet、golden 全绿。

**验收内容**：7 页截图/录屏（可选）；`perf.md`；测试输出；golden 目录。

**验收说明**：1–3 自动验证；GATE-4 由用户抽查 3 页 + 亲自滚动 10k 列表。

### GATE-4 — 目录 A 与性能（必须）

**用户操作（约 8 分钟）**

1. 打开 Layout、Data Display、Sliders 三页，各做一次交互（拖分隔条、滚动/排序列表、拖滑块）。
2. 在 Data Display 滚动 10k 列表到底部再回顶，感受是否卡顿。
3. 连续切换 5 个页面，观察切换是否即时。

**通过标准**：用户回复「GATE-4 PASS」；对性能或信息组织不满意 → 本 Phase 内修，不得进入下一 Phase。

---

## Phase 1.5.0 — 目录 B：全量覆盖与完整性守护

**目标**：补齐剩余条目与所有 `*Base`，建立“158/158 + 构造器 100%”的硬门禁。
**前置**：GATE-4 PASS。
**估算**：5–6 天。

- [ ] **1.5.1 Base/parts 全量**：在对应页补齐全部 `*Base` 与 parts（ButtonBase/CheckboxBase/RadioBase/SwitchBase/ToggleBase/SegmentedBase/ComboboxBase/SliderBase/TextInputBase/TextAreaBase/TextInputBuffer/TextAreaBuffer/CollapsibleBase/DialogBase/PopoverBase/TooltipBase/ToastBase/ToastViewportBase 等），每个与主题版并排。
  → 验收：inventory 中所有 `base` 标记条目均有展示；Tester 找到对应 Label 元素。
- [ ] **1.5.2 覆盖率守卫 `internal/uicheck`**：用 `go/parser` 解析 `go list -m -f '{{.Dir}}' github.com/egoist/mygo` 下 `ui/api_gen.go` + 手写构造器，与 registry `Covers` 集合比对；缺失即失败并列出；排除项（Local/NewTester/Render/Drop 等）在 `exclude.go` 显式注释理由。
  → 验收：`go test ./internal/uicheck -run TestCoverage` PASS；故意删除一个 Entry 时测试失败（自测后还原）。
- [ ] **1.5.3 计数器与覆盖徽章**：Overview/侧栏显示 `covered/total`（158/158）与分类计数；数据来自 registry 实时计算。
  → 验收：删除一张页面注册后数字下降（自测还原）；Release 构建显示 158/158。
- [ ] **1.5.4 命令面板全量**：可搜 页面/条目/id/构造器名/标签；结果分组、高亮匹配；Enter 直达条目锚点。
  → 验收：随机抽 10 个 inventory id 均能搜到并跳转；无结果提示正确。
- [ ] **1.5.5 片段生成全量 + CI 校验**：所有页 demo 片段生成；CI 执行 `go generate ./... && git diff --exit-code`。
  → 验收：CI 绿；本地 `git diff` 干净。
- [ ] **1.5.6 无障碍标注补齐**：所有可交互 demo 有 `Label`/`Role`/状态；Tester 断言关键词；`docs/A11Y-INVENTORY.md` 记录每个条目的 name/role。
  → 验收：无未标注的可交互控件（脚本扫描 `Focusable()` 无 `Label` 的 demo）；Tester 通过。
- [ ] **1.5.7 i18n 骨架**：`app/locales/en.json` + `zh-Hans.json`；App 自身文案走 catalogs；语言菜单切换整窗生效；`go tool mygo i18n check` 0 error。
  → 验收：切到 zh-Hans 后侧栏/标题/页面说明中文；重新切回英文正确；日期/数字格式随 locale。
- [ ] **1.5.8 目录结构收口**：每页一目录/文件、每页一测试、每页一条 registry 注册；单文件 < 1,500 行；`docs/PAGE-PATTERN.md` 更新。
  → 验收：`find app/internal/catalog/screens -name '*.go' | xargs wc -l` 无超标；文档更新。

**Phase 验收条件（AC）**

1. inventory 158/158 全部在 registry 中且页面可达。
2. `uicheck` 覆盖 `ui` 公开构造器 100%，违规即失败。
3. 命令面板可检索全部条目；片段/CI 校验通过；a11y 标注与 i18n 骨架完成。

**验收内容**：覆盖率测试输出；Overview 截图；命令面板录屏/截图；`locales/*.json`；CI run。

**验收说明**：1–3 自动验证；GATE-5 由用户确认“真的全了”。

### GATE-5 — 全量覆盖确认（必须）

**用户操作（约 10 分钟）**

1. 打开 Overview，确认显示 158/158 与分类计数。
2. 侧栏逐页快速点过（21 页），确认没有空白页/报错页。
3. 用 ⌘K 随机搜 5 个控件（如 `glass`、`token`、`diff`、`meter`、`tooltip`），确认能跳到对应内容。
4. 工具栏切到中文，确认界面文案变化且无乱码。

**通过标准**：用户回复「GATE-5 PASS」，并确认“全部 UI 与控件已覆盖”。若发现遗漏 → 补 Entry 后重提。

---

## Phase 1.6.0 — 复杂内容（图表/编辑器/Markdown/富文本/媒体/拖放/效果）

**目标**：完成重内容页面，验证性能与交互质量。
**前置**：GATE-5 PASS。
**估算**：5–7 天。

- [ ] **1.6.1 Charts 页**：inventory Charts 全部 6 条（`chart-marks`、`chart-plot`、`chart-scales`、`chart-select`、`chart-paths`、`chart-stack-minmax`：Line/Area/Band/Pie/Stack/Time/Streaming/Plot）；hover tooltip、选择、图例；streaming 用 `Window.Update` 且可暂停。
  → 验收：6 类图可见且数据正确；tooltip/选择可用；暂停后无持续帧；Tester + golden 通过。
- [ ] **1.6.2 Editors 页**：Editors 中编辑器 3 条（`editor-buffer-langs`、`editor-code`、`editor-diff`）：CodeEditor（高亮/补全/hover/diagnostics/折叠/查找）与 DiffViewer（side-by-side/unified）；只读示例可切换。
  → 验收：输入/撤销/查找可用；diff 渲染正确；Tester + golden 通过。
- [ ] **1.6.3 Markdown & Rich Text 页**：Markdown 3 条（`markdown-view`、`markdown-stream`、`markdown-code-theme`）+ Rich Text 3 条（`richtext-document`、`richtext-editor`、`richtext-base`）：View/Stream（流式追加）、Editor + 格式工具栏（粗体/斜体/列表/链接/标题）。
  → 验收：流式渲染不闪烁；富文本命令生效；Tester + golden 通过。
- [ ] **1.6.4 Media/Drawing/WebView 页**：Media 4 条（`avatar`、`icon`、`image`、`web-view`）+ Decoration & Drawing 2 条（`canvas-painter`、`svg-bitmap`）；WebView 用 `mygo.WebViewAvailable()` 检测，不可用时显示说明与占位。
  → 验收：图片/SVG 正确显示；自绘图正常；WebView 在有/无环境都给出明确状态（不崩溃）。
- [ ] **1.6.5 Drag & Drop 页**：元素拖拽（自定义类型）、列表重排、文件拖入（`DroppedFiles`/`FileDragOver`）、`transfer` 多格式、跨窗口拖放演示说明。
  → 验收：拖拽结果正确、Escape 取消、文件拖入路径显示；Tester 通过（文件拖放可用 fake）。
- [ ] **1.6.6 Effects 页**：Effects & Materials 5 条（`glass-glass`、`glass-blur`、`glass-scrolledge`、`shader-draw`、`shader-effect`）+ Plugins & Extras 2 条（`loading-spinners` 29 个指示器、`game-view` 以 API 卡片+代码+链接 examples/farm 呈现，不做可玩 demo）+ Motion 示例（Timeline/Keyframes/Transition）。
  → 验收：玻璃/模糊可见（`MYGO_GPU=0` 也正确）；29 个指示器齐全；Reduce Motion 时静止；Tester + golden。
- [ ] **1.6.7 性能与懒加载**：复杂页首次构建 < 100ms（记录）；编辑/图表对象仅在页面激活时创建；离开页面释放重资源；`perf.md` 更新。
  → 验收：切换进出复杂页 10 次无内存持续增长；无 >16ms 的持续掉帧。
- [ ] **1.6.8 测试补充**：每个复杂页 1 个 Tester 交互测试 + golden（light/dark）。
  → 验收：`go test ./...` 绿；基线数量符合预期。

**Phase 验收条件（AC）**

1. 6 个复杂页全部可用，关键交互真实（非静态截图）。
2. 性能与内存达标。
3. 测试与 golden 通过。

**验收内容**：逐页截图/录屏；`perf.md`；测试输出。

**验收说明**：1–3 自动验证；GATE-6 由用户逐页实操判定。

### GATE-6 — 复杂内容实操（必须）

**用户操作（约 15 分钟）**

1. Charts：hover 看 tooltip、切换图表、暂停 streaming。
2. Editors：输入代码、触发补全、打开 diff。
3. Markdown/Rich Text：滚动长文、用工具栏加粗/加列表。
4. Effects：看玻璃/模糊/29 个 loading；打开 Reduce Motion 再对比。
5. Drag & Drop：拖一个任务到另一列，拖一个文件进窗口。

**通过标准**：用户回复「GATE-6 PASS」；若有卡顿/错位/崩溃 → 本 Phase 修完重提。

---

## Phase 1.7.0 — 桌面与平台能力（真实窗口/菜单/托盘/通知…）

**目标**：把 31 个桌面 API 变成**真实可操作**的演示，并完成平台档案与差异矩阵。
**前置**：GATE-6 PASS。
**估算**：4–5 天。

- [ ] **1.7.1 窗口演示**：从 `/desktop` 打开第二窗口，可切换：Frameless / Transparent / AlwaysOnTop / Panel / TitleBarHidden / HideWindowButtons；实时显示 `c.Size()`/`c.TitleBar()`/`c.Vibrancy()`；StateKey 记忆演示。
  → 验收：第二窗口每个选项符合文档；关闭后主窗口正常；无崩溃。
- [ ] **1.7.2 菜单演示**：应用菜单（RoleAppMenu/Edit/View/Window/Help + 自定义项、勾选/单选/子菜单/快捷键/禁用项）、上下文菜单；事件日志记录选择。
  → 验收：macOS 菜单栏出现且项可用；快捷键生效；Win/Linux 行为按平台（CI/文档标注）。
- [ ] **1.7.3 系统集成演示**：Tray + Flyout（创建/菜单/点击/移除）、GlobalShortcut（注册/冲突/注销）、Notification（打包 app 下发送/点击/清除/权限拒绝态）、Dialog Open/Save/Message/Error、Clipboard 读写。
  → 验收：每个动作有成功/失败日志；通知在 `mygo dev` 打包 app 下真实弹出；拒绝权限时有说明。
- [ ] **1.7.4 平台档案页**：运行时 OS/arch、渲染后端（Metal/D3D11/OpenGL/CPU，注明推断依据）、显示器/scale、系统 accent、Preferences（ReduceMotion/ReduceTransparency/HighContrast/TextScale）、`c.TitleBar()`、`c.Vibrancy()`、WebViewAvailable/NotificationsSupported、可用桌面能力列表。
  → 验收：页面数据与本机真实情况一致（用户可核对系统设置）。
- [ ] **1.7.5 平台差异矩阵页**：Table/Grid 呈现 PLATFORM-DIFFERENCES：窗口 chrome、字体/字号、accent/对比度/文本缩放、材质、菜单/托盘/通知、快捷键、滚动条、打包；每格含 `docs 依据 / 推断` 标记；高亮当前 OS。
  → 验收：矩阵行/列完整；与 `research/docs/PLATFORM-DIFFERENCES.md` 一致；无空单元格（缺数据标“未知”）。
- [ ] **1.7.6 事件日志组件**：统一 `eventLog`（时间、动作、结果、错误），可清空/复制；桌面页所有动作接入。
  → 验收：每个按钮至少产生一条日志；错误有可读信息。
- [ ] **1.7.7 外观实验台补全**：在 Appearance Lab 中集中展示并切换所有 token；标注“系统偏好无法完全模拟”的项（如真实 VoiceOver）；提供一键恢复系统默认。
  → 验收：所有项可用；恢复默认后窗口回到系统外观。
- [ ] **1.7.8 手动验收脚本**：`docs/DESKTOP-CHECKLIST.md`：macOS 必测项、Windows/Linux（有真机时）必测项、每项预期结果与记录栏。
  → 验收：清单可逐项打勾；本次 macOS 全部通过并记录。
- [ ] **1.7.9 Desktop 31 条全覆盖核对**：在 `/desktop` 建立完整映射并逐条验收（每条的展示形态 = 真实动作 / 实时状态 / API 卡片+代码片段，且都有可用性徽章与 `docs` 依据）。映射：`window-new`/`window-controls`/`window-state`/`ui-view-window-content`/`window-titlebar`/`window-vibrancy`（1.7.1）；`app-menu`/`context-menu`（1.7.2）；`tray`/`flyout`/`notifications-native`/`dialogs-native`/`global-shortcut`/`clipboard`（1.7.3）；`screens`/`theme-appearance`/`locale-i18n`（平台档案页 1.7.4/1.9.1）；`network`/`power`/`nowplaying`/`secrets`/`dock-jumplist`/`updater`/`shell-integration`/`documents`/`single-instance`/`open-at-login`/`deep-links`/`app-lifecycle`/`drag-drop-desktop`/`webview-desktop`（本页状态/API 卡片，其中 drag-drop/webview 的交互在 1.6.4/1.6.5 已做）。
  → 验收：`internal/uicheck` 报告 Desktop 31/31；页面无缺失条目；每条徽章与说明可见。

**Phase 验收条件（AC）**

1. 桌面演示真实可用（非 mock），失败有明确日志。
2. 平台档案与差异矩阵准确、完整。
3. 本机 macOS 手动清单全过；CI 构建不受桌面调用影响。

**验收内容**：`/desktop` 各 section 截图/录屏；`DESKTOP-CHECKLIST.md`；平台页截图；事件日志。

**验收说明**：1–3 自动+清单；**GATE-7 必须用户在真机亲自操作**。

### GATE-7 — 真实桌面能力（必须，禁止跳过除非用户明确同意）

**用户操作（约 20 分钟，macOS 真机）**

1. `/desktop` 打开第二窗口，切换标题栏/材质/置顶，观察差异；关闭。
2. 菜单：用菜单栏执行一个自定义命令；试一个勾选项。
3. 托盘：点击菜单栏图标，选一项；再移除托盘。
4. 通知：发送一条，确认弹出；点击通知。
5. 全局快捷键：按一次，确认窗口/日志响应。
6. 对话框：打开文件选择、消息框；剪贴板复制/粘贴。
7. 平台页核对：OS/scale/accent/ReduceMotion 等与系统设置一致；差异矩阵无事实错误。

**通过标准**：用户回复「GATE-7 PASS」并说明实机观察结果；若用户表示“无 Windows/Linux 真机”，记录该限制，不视为失败。**未通过前禁止进入 Phase 1.8.0。**

---

## Phase 1.8.0 — 跨平台证据与 Web 版

**目标**：用 CI 生成 macOS/Windows/Linux 真实截图矩阵并在 App 内呈现；发布 wasm Web 版。
**前置**：GATE-7 PASS。
**估算**：4–5 天。

- [ ] **1.8.1 CI 三平台测试/截图**：CI 增加 `golden` 与 `build` job（mac/win/ubuntu）；Ubuntu 用 `MYGO_GPU=0`；三平台 `go test ./...` 与 golden 全绿。
  → 验收：三平台 job 全绿；附 run URL。
- [ ] **1.8.2 golden 更新工作流**：`workflow_dispatch` 触发 `-update`，提交基线；PR 校验 `-update=false` 失败时给出 diff。
  → 验收：手动触发一次更新 PR；故意改样式时 PR 失败（自测后还原）。
- [ ] **1.8.3 `--capture` 模式**：App 支持 `--capture <dir>`：逐页渲染（每页 light/dark），输出 `PNG + manifest.json`（OS/theme/locale/size/条目）；无交互退出码 0。
  → 验收：本机运行生成 21×2 PNG；manifest 可被 `jq` 解析；退出码 0。
- [ ] **1.8.4 CI 截图矩阵**：三平台 runner 运行 `--capture`（或 headless capture），上传 artifact；选取代表性页面提交到 `docs/platform-shots/<os>/`。
  → 验收：三平台 artifact 可下载；`docs/platform-shots/` 有 mac/win/linux 三套。
- [ ] **1.8.5 App 内三平台截图**：Platforms 页并列显示三平台截图（`go:embed`，缩略图 ≤ 15MB 总量，含 OS/字体/日期标注）；无法获取的 OS 显示“待 CI 采集”。
  → 验收：App 内可见三平台对照；加载 < 200ms；release 构建体积增量 ≤ 15MB。
- [ ] **1.8.6 Web 版**：`go tool mygo build -platform web` 成功；GitHub Pages workflow 部署；浏览器 smoke（headless Chrome 截图 + 手动打开）；页面标注功能限制。
  → 验收：Pages URL 可访问；打开显示 Overview；限制说明存在。
- [ ] **1.8.7 Release 草稿工作流（可选）**：tag 触发三平台构建并上传 draft release。
  → 验收：一次 dry-run 成功（可删除草稿）。

**Phase 验收条件（AC）**

1. 三平台 CI 全绿，真实截图矩阵生成。
2. App 内可查看三平台对照，数据有来源标注。
3. Web 版可访问并标注限制。

**验收内容**：CI run URL；`docs/platform-shots/`；App Platforms 页截图；Pages URL。

**验收说明**：1–3 自动验证；GATE-8 由用户查看矩阵与浏览器版。

### GATE-8 — 跨平台证据与 Web（必须）

**用户操作（约 10 分钟）**

1. 打开 App 的 Platforms 页，逐组看 macOS/Windows/Linux 截图，判断差异展示是否直观、标注是否可信。
2. 打开 CI artifacts 中的三平台截图包（或 `docs/platform-shots/`）。
3. 浏览器打开 GitHub Pages 的 web 版，点几个页面，确认可用性与限制提示。

**通过标准**：用户回复「GATE-8 PASS」并确认“能直观看到各系统表现”；若不满意 → 调整截图选取/展示方式后重提。

---

## Phase 1.9.0 — 无障碍、i18n、RTL 与加固

**目标**：达到可发布质量：中英双语、完整 RTL、键盘/屏幕阅读器可用、无崩溃/竞态、性能达标。
**前置**：GATE-8 PASS。
**估算**：3–4 天。

- [ ] **1.9.1 i18n 完整**：所有页面/说明/按钮文案进 catalogs（en/zh-Hans）；语言切换即时生效且持久化；`go tool mygo i18n check` 0 error；日期/数字/货币格式随 `c.Region()`。
  → 验收：随机 10 页中英切换无残留英文/乱码；CI 中 `i18n check` 绿。
- [ ] **1.9.2 RTL 完整**：全局 RTL 下 21 页布局正确（侧栏/面包屑/表格/时间轴/图表轴）；关键页 LTR/RTL 并排；RTL 截图入库。
  → 验收：无 RTL 破版（溢出/反向文本）；截图对比正常。
- [ ] **1.9.3 无障碍走查**：`docs/A11Y-CHECKLIST.md`；键盘-only 完成导航/操作/关闭覆盖层；VoiceOver（macOS）抽查 5 个页面朗读 name/role/state；`c.Announce` 用于关键状态变化。
  → 验收：键盘-only 无死路；VoiceOver 可读出控件名称；记录问题清零。
- [ ] **1.9.4 加固**：`go test -race ./...` 绿；`go tool mygo vet .` 干净；边界用例（演示中关闭窗口、空列表、快速切页、窗口极小/极大、连续开关 Overlay）无 panic。
  → 验收：测试与手工边界清单全过。
- [ ] **1.9.5 性能验收**：启动 < 1s（冷启动到首帧）；空闲 CPU 0%；页面切换 build < 16ms；内存 < 200MB（含截图资源）；记录到 `docs/evidence/phase-1.9.0/perf.md`。
  → 验收：`MYGO_FRAME_STATS=1` 与 Activity Monitor 数据符合阈值。
- [ ] **1.9.6 仓库文档**：README（截图/平台矩阵/覆盖徽章/运行方式）、CONTRIBUTING、CHANGELOG、SECURITY、Issue/PR 模板；repo description/topics 完整。
  → 验收：文档链接可达；Issue 模板可见。

**Phase 验收条件（AC）**

1. en/zh 完整、RTL 完整、键盘/VoiceOver 可用。
2. race/vet 干净，边界用例无崩溃，性能达标。
3. 仓库文档齐备。

**验收内容**：`A11Y-CHECKLIST.md`；RTL 截图；`perf.md`；race/vet 输出；仓库文档页。

**验收说明**：1–3 自动+用户 GATE-9 判定。

### GATE-9 — 无障碍/i18n/RTL（必须）

**用户操作（约 10 分钟）**

1. 只用键盘（Tab/Shift+Tab/方向键/Enter/Esc）完成：切页、打开命令面板、操作一个表单、关闭弹窗——全程不碰鼠标。
2. 打开 VoiceOver（⌘F5），听 3 个页面的控件朗读，确认名称/角色合理。
3. 切到中文，走查 3 页；切 RTL，看 Layout/Data 两页布局是否镜像正确。

**通过标准**：用户回复「GATE-9 PASS」；键盘卡住/朗读混乱/中文缺失/RTL 破版 → 本 Phase 修复重提。

---

## Phase 1.10.0 — 发布 v1.0.0

**目标**：产出可公开下载的 1.0.0：三平台安装包、截图包、Release、README、Pages。
**前置**：GATE-9 PASS。
**估算**：3–4 天。

- [ ] **1.10.1 品牌与标识定稿**：最终 icon（1024×1024 PNG → macOS `.icns`；Windows `.ico` 可选）；`mygo.json` name/identifier 锁定；About 面板显示版本/版权/许可。
  → 验收：三平台图标正确显示；identifier 与 `docs/DECISIONS.md` 一致。
- [ ] **1.10.2 版本与许可**：`version: "1.0.0"`；CHANGELOG 记录功能；credits 列 MyGo（MIT）与复用示例归属；`LICENSE` 检查。
  → 验收：About/Release/README 版本一致；许可文本齐全。
- [ ] **1.10.3 三平台构建**：`go tool mygo build -platform darwin/universal,windows/amd64,windows/arm64,linux/amd64,linux/arm64`；macOS dmg 本机安装冒烟（拖入 Applications → 打开 → 完整走查）；Windows/Linux 产物来自 CI；生成 SHA256SUMS。
  → 验收：产物清单齐；macOS 安装后可运行；checksum 可校验。
- [ ] **1.10.4 发布 Release**：打 tag `v1.0.0`；GitHub Release（公开）附三平台产物、截图压缩包、checksums、Release Notes（含未签名说明/已知限制/系统要求）。
  → 验收：Release 页面可匿名访问；资产可下载；Notes 完整。
- [ ] **1.10.5 README/Pages 定稿**：README 顶部截图/GIF、三平台矩阵、158/158 覆盖、安装/运行/开发命令；Pages 更新到 v1.0.0；仓库 About 区链接 Pages。
  → 验收：README 在 GitHub 渲染正常；Pages URL 为最新版。
- [ ] **1.10.6 发布验证文档**：`docs/RELEASE-VERIFICATION.md`：逐项命令/结果/证据（test/vet/golden/build/install/Pages/Release）。
  → 验收：文档完整；所有条目 PASS 或标注限制。

**Phase 验收条件（AC）**

1. v1.0.0 Release 公开可下载，三平台产物可用。
2. macOS 安装冒烟通过；README/Pages 展示完整。
3. 发布验证文档齐备，Project DoD 逐项勾选。

**验收内容**：Release URL；产物清单/校验和；安装截图；README/Pages；`RELEASE-VERIFICATION.md`。

**验收说明**：1–3 自动+用户 GATE-10 最终验收。

### GATE-10 — 发布验收（必须）

**用户操作（约 15 分钟）**

1. 从 Release 下载 macOS dmg，安装到 Applications 并打开，完整走查：Overview → 任意 5 页 → 命令面板 → 主题切换 → Platforms 页。
2. 打开 Release 页面与 README，检查截图/说明/已知限制是否准确。
3. 打开 Pages 的 web 版，确认可用。
4. 逐条核对 Project DoD（本文件顶部 9 条），确认全部满足。

**通过标准**：用户回复「GATE-10 PASS / v1.0.0 验收通过」；未通过项列回本 Phase 修复。**通过后 Project 1.0.0 完成。**

---

## 附：证据与记录模板

### `docs/GATES.md` 记录模板

```md
## GATE-x — <名称>
- 日期：YYYY-MM-DD HH:MM
- 结论：PASS / FAIL / SKIPPED（用户原话）
- 用户观察：<原话摘要>
- 遗留问题：<列表或“无”>
- 下一步：进入 Phase x.y.z / 修复项
```

### `docs/evidence/phase-x.y.z/` 目录约定

```
phase-1.2.0/
  commands.log        # 执行的命令与关键输出
  test.txt            # go test 结果
  vet.txt             # mygo vet 结果
  screens/            # light/dark/RTL/关键交互截图
  notes.md            # 耗时、问题、偏差、下一步
```

### 与已确认决策的对应

| 决策 | 值 | 落点 |
|---|---|---|
| 仓库 | Public GitHub `mygo-explorer` | 1.1.6 / GATE-1 |
| 版本 | MyGo v0.7.1 · Go 1.27.3 · 纯 Go | 1.1.2–1.1.4 |
| 名称/identifier | MyGo Explorer / `dev.mygoexplorer.app`（GATE-1 确认） | 1.1.1 / GATE-1 |
| 语言 | English + 简体中文 | 1.5.7 / 1.9.1 |
| 平台 | macOS + Windows + Linux（CI） | 1.1.7 / 1.8.x |
| Web 版 | wasm + GitHub Pages | 1.8.6 |
| 范围 | 全量 158 条目 | 1.5.x |
| GATE 策略 | 用户不主动跳过则必须执行 | 0.2 / 全部 GATE |
