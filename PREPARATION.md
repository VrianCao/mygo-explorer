# MyGo Explorer — 阶段 0 调研与准备报告

> 日期：2026-10-27 · 阶段：**只调研与准备，未开始应用实现**（用户要求先了解项目、拉取文档、完成安装/测试/可用性检查）
> 目标应用：用 MyGo 自身开发的 **Native UI App**，展示 MyGo 全部 UI 与控件，并直观对比各系统表现（macOS / Windows / Linux）
> 配套文件：[PLAN.md](PLAN.md)（实施计划）· [research/ui-catalog/](research/ui-catalog/)（控件清单与页面规划）· [research/docs/](research/docs/)（文档知识库）· [research/prep/](research/prep/)（环境证据与 Runbook）· [research/examples/EXAMPLES.md](research/examples/EXAMPLES.md)（示例分析）

---

## 1. 结论速览（TL;DR）

**MyGo 是什么**：egoist 开发的 Go 桌面应用框架（MIT，2026-10-27 刚发布 **v0.7.1**）。核心卖点是一个窗口可选两种内容——**Native UI**（用 Go 写视图，MyGo 自己在 GPU 上用 Metal / Direct3D 11 / OpenGL 绘制，无 HTML/JS/webview）或系统 webview 中的 Web 前端；纯 Go、无 cgo，单文件约 7–10 MB，可直接交叉编译三大平台，并自带打包、签名、自动更新与桌面 API。

**这个项目适合做“UI 展示 App”吗**：非常适合。MyGo 的 `ui` 包本身就是一套完整的 UI 工具箱（约 78k 行源码、158 个可展示条目、19 个分类），官方已有 `examples/gallery`（13 页的 tour）和 `website/docs-demo`（64 个逐组件在线预览，可编译为 WebAssembly）两个先例；我们可以在它们之上做“全量 + 可解释 + 跨平台对比”的参考级目录应用。

**阶段 0 完成度：就绪（GREEN）**

| 准备项 | 状态 | 证据 |
|---|---|---|
| 深入理解项目与源码结构 | ✅ | docs/ 6 份 digest、ui-catalog/、repository checkout `reference/mygo` |
| 拉取所需文档 | ✅ | `research/docs/llms-full.txt`（1.2 MB / 22,738 行，全站文档）+ 114 页仓库 Markdown + INDEX 索引 |
| 安装工具链 | ✅ | `mygo 0.7.1` CLI、Go **1.27.3**（自动下载）、探针项目（`prep/probe-native`，pin `mygo v0.7.1`） |
| 测试与可用性检查 | ✅ | 无窗口测试、真实 GUI 窗口（Metal 渲染）、截图、热重载、三平台交叉编译、wasm 构建全部 PASS |
| 未实施目标 App | ✅ | 只生成了一次性探针项目；目标 app 未创建 |
| 已知限制 | ⚠️ | 本机无法运行 Windows/Linux GUI（仅交叉编译）；无 Developer ID 证书（不能公证分发）；跨平台截图需 CI 或真机 |

**关键结论**：Native UI 在各系统**由同一套渲染器与控件绘制**，像素风格基本一致；真正的系统差异来自 4 个层面——① 系统窗口 chrome（标题栏/菜单/托盘/材质）、② 系统字体与桌面偏好（深色/强调色/文本缩放/减少动态）、③ 平台键鼠惯例（Cmd vs Ctrl 等）、④ 后端与打包（Metal/D3D11/OpenGL、通知、签名）。因此“各系统表现”应该用**三层方案**呈现（详见 §6 与 PLAN）：应用内平台档案 + 外观实验台（真实 token 切换）+ CI/真机生成的真实截图矩阵。

---

## 2. 调研范围与方法

- **一手源码**：`reference/mygo`（main @ `b553a90`，2026-10-27；release tag `v0.7.1` = `76dd068`）—— docs、ui、examples、website、plugins、cmd 全部只读检视。
- **官方文档**：https://mygo.egoist.dev（另拉取 `/llms-full.txt` 全量离线副本与 `/llms.txt` 索引；文档页 114 篇：root 20 + ui 85 + plugins 9）。
- **官方站点外延**：Showcase（9 个真实 MyGo 应用）、Benchmarks（每次 push 在 macOS/Linux/Windows runner 上测时间/内存/分配/GPU 编码）。
- **环境实测**：在用户这台 macOS 27.0.1（M5 Pro / Metal 4 / 19 寸？内建 3024×1964@2x）上完成安装、脚手架、测试、真实运行、截图、打包、交叉编译、wasm 构建。
- **团队分工**：docs-analyst（文档知识库）、ui-cataloger（控件清单/screen map）、env-prep（环境验证），Lead 负责示例分析、跨平台策略、复核与最终报告。

产物地图：

```
research/
  00-RECON.md                 基线（事实、路径、写作用域）
  docs/                       文档知识库（INDEX + 4 digest + 平台差异 + gotchas + gaps）
  ui-catalog/                 控件清单（inventory.json + INVENTORY.md + COVERAGE/SCREENS/API-NOTES）
  examples/EXAMPLES.md        官方示例与可复用模式分析
  prep/ENVIRONMENT.md         环境事实表、能力矩阵、证据索引
  prep/RUNBOOK.md             可复现的安装/开发/测试/构建/截图 Runbook
  prep/evidence/              29 份原始日志 + 14 张截图/渲染结果
prep/
  probe-native/               一次性 CLI 脚手架探针（非目标 app）
  scripts/preflight.sh        幂等环境自检（19 PASS / 0 FAIL / 1 SKIP，约 5.5s；--gui 22 PASS）
reference/mygo/               只读源码 checkout（28 MB，浅克隆）
```

---

## 3. MyGo 项目理解（核心）

### 3.1 框架定位与分层

```
┌────────────────────────────────────────────────────────────────┐
│ 应用层: main.go — App.WhenReady / NewWindow / App.Run          │
├───────────────────────────────┬────────────────────────────────┤
│ Native UI (package ui)        │ Web 前端（系统 webview）        │
│ 视图=Go 函数，每帧重建        │ WKWebView / WebKitGTK / WebView2│
│ GPU 绘制，无 webview          │ typed IPC + 生成的 TS client    │
├───────────────────────────────┴────────────────────────────────┤
│ 桌面 API: Window/Menu/Tray/Dialog/Notification/Shortcut/...    │
│ 平台后端: internal/darwin | windows | linux（purego，无 cgo）  │
└────────────────────────────────────────────────────────────────┘
```

规模（源码统计）：`ui/` 231 个 Go 文件 ≈ 78k 行（含大量测试）；根包 100+ 文件覆盖窗口/菜单/托盘/对话框/通知/剪贴板/拖放/文件关联/更新/协议等；`examples/` 30+ 个完整示例；`website/docs-demo` 64 个文档内嵌预览；`docs/` 114 篇。

### 3.2 Native UI 编程模型（实现 App 前必须内化的规则）

- **视图是状态的函数**：`func (app *T) view(c *ui.Context)`，MyGo 在输入、`Window.Update`、动画等时机再次调用；一帧内可能 rebuild 多次。控件是构造函数调用（`ui.Button(c,"Save")`），调用即返回 `ui.Element`，并在返回值上**查询上一帧以来发生的输入**（`Clicked()`、`Changed()`、`Submitted()`），或用回调（`OnClick`、`OnChange`）。
- **Element 生命周期极短**：一个 `ui.Element` 只在创建它的 build pass 内有效，**下一 pass（甚至同帧下一 pass）即失效**；只能保存 `ui.Handle`/`ui.Ref`。dev 构建与 `Tester` 对陈旧使用直接 panic，production 静默 no-op。`go tool mygo vet` 会检查把 Element/Context 存进字段或 goroutine 的问题。→ **目录 App 的每个页面状态必须放在 app 结构体/注册表里，不能存 Element。**
- **身份与焦点**：`c.Key(key)` / 容器 `Key` 决定跨帧状态（焦点、滚动、编辑缓冲）归属；同父级重复 key 会共享状态并报问题。`Bind(&handle)` 提供持久控制身份，`FocusBind`/`FocusedValue` 把“期望焦点”与“实际焦点”分开。
- **布局**：flexbox + grid（`Column/Row/Box/Grid/Grid 布局/Scroll/Split/Tabs/Sidebar/Toolbar`），CSS 式尺寸/对齐/间距；`Theme.Spacing`（默认 4）统一间距，`Theme.FontSize`（macOS 默认 13，其它平台 14）。
- **主题**：`Theme` 是普通 struct（颜色 + Radius/Spacing/FontSize/Font + Dark 标志），`LightTheme()/DarkTheme()/c.Theme()/c.SetTheme()`；默认跟随系统明暗、强调色、高对比、文本缩放、减少动态（`c.Preferences()`）。→ **应用内“外观实验台”可实时切换这些 token 而不改系统设置。**
- **输入**：指针、滚轮/触控板、键盘、焦点环、快捷键（`ui.Cmd` 在 macOS=Command，其它=Control）、IME、多选/拖拽、上下文菜单；控件基类（`*Base`，如 `ButtonBase/TabsBase/SelectBase`）提供无外观但完整的交互/焦点/无障碍行为，可自定义皮肤。
- **覆盖层**：Dialog/AlertDialog/Popover/Tooltip/Toast/ContextMenu 等有统一 Overlay 语义（焦点陷阱、Escape、遮罩、层级）。
- **导航**：`ui.Router` 以路径（如 `/list/42`、`/files/{path...}`）管理页面历史，支持 back/forward、相对 push、标题、过渡；`Sidebar/Breadcrumbs/BackButton/ForwardButton` 是其 UI 配套。
- **文本栈**：`ui.Text/Textf/RichText` + `ui/editor`（代码编辑器/差异查看器，Zed 风格）+ `ui/markdown`（流式渲染）+ `ui/richtext`（富文本编辑，NSAttributedString 级能力）+ `TextBuffer`（大文档）。
- **渲染/动画**：Painter 自绘、SVG、渐变/阴影/模糊/材质、`Animate/Transition/Timeline/Motion`、`ui/shader`（Go 语法写 shader，Metal/D3D11/OpenGL/CPU/WebGL2）、`plugins/glass`（跨平台 Liquid Glass / ScrollEdge / Blur）、`plugins/loading`（29 个加载指示器）。
- **测试**：`ui.NewTester(view, w, h)` 无窗口渲染、按文本查找控件、模拟点击/输入/快捷键/菜单/滚轮/时间推进（`tt.Advance`）、读取 `tt.Texts()/Image()/Announcements()`；**确定性**、毫秒级，是跨平台截图与行为测试的基础。
- **线程**：view 在主线程；其它 goroutine 通过 `Window.Update`（异步安全）请求重建/刷新；`Invalidate` 不保证同步写可见。
- **无障碍**：控件自带 role/name/state，`Label/Role/Description/Error/Announced`、heading level、菜单角色等；后端分别是 macOS NSAccessibility / Windows UI Automation / Linux ATK→AT-SPI；browser 版暂不支持 AT。
- **多语言/RTL**：`i18n` catalogs（JSON→生成的 typed Go 函数）、`App.Locale/Region`、数字/日期/首周日/12-24 小时制随区域；RTL 由语言自动，`MYGO_DIRECTION=rtl|ltr` 强制；`tt.SetLocale/SetRegion/SetDirection` 可测。

> 权威细节：`research/docs/DIGEST-native-ui.md`（883 行）· 必读陷阱：`research/docs/GOTCHAS.md` · 生成项目自带的 `.agents/skills/mygo-maintenance/SKILL.md`（37 行，已随模板生成在探针里）。

### 3.3 应用层与桌面能力（App 外壳可直接展示/使用）

`mygo.App` 生命周期（WhenReady/Run/OnWindowAllClosed/单实例/深链/文件关联/最近文档/开机启动）、`NewWindow(WindowOptions)`（尺寸/位置/状态记忆/`Frameless`/`TitleBarStyle: TitleBarHidden`/`TrafficLightPosition`/`HideWindowButtons`/`Vibrancy`/`Transparent`/`AlwaysOnTop`/`Panel` 等）、菜单（app menu / 每窗口菜单 / context menu / tray menu / Dock menu / jump list）、托盘、系统对话框、通知、全局快捷键、剪贴板、拖放（`transfer` 多格式）、显示器信息、深浅色/强调色、电源/网络状态、Now Playing、文件监听、secrets、单实例、文档模型（`NewDocuments`）、Launcher/Panel/Flyout、自动更新（签名/增量）、打包（macOS .app+.dmg、Windows NSIS、Linux deb/install.sh）、GitHub Actions 三平台流水线。

> 详情：`research/docs/DIGEST-app-platform.md`（450 行）；官方 Showcase 有 9 个真实产品（Pulse、Kero、Lorca、云音乐、GoRex、Godiff、2048、Uma、MixMusic），证明复杂 Native UI 应用可行。

### 3.4 官方现成“展示”资产（可复用/借鉴）

1. **`examples/gallery`**（2,646 行）：13 页 tour（Overview/Controls/Text/Rich Text/List/Charts/Markdown/Styling/Drawing/Glass/Overlays/Motion/Languages），Router+Sidebar+Toolbar+快捷键+缩放+RTL+语言菜单，10k 行虚拟列表、表格、树、网格、拖拽、图表、富文本、玻璃、动画、overlay 全覆盖；带无窗口 Tester 测试。**是“tour”而非“参考手册”**：没有逐控件 variants/状态/props/代码，也没有平台对比。
2. **`website/docs-demo`**（2,717 行）：文档每页内嵌的**逐组件预览**，`demo(name, view)` 注册表、64 个 demo、可编译 wasm、也可桌面运行；与文档页 1:1 对应。**是“组件目录”的雏形**，但缺元数据、代码、变体、状态、平台说明。
3. 官方 Showcase/Benchmarks 页面：证明产品化能力与性能基线（每次 push 测三平台）。
4. 其他示例：`vibrancy`（标题栏/材质）、`loading`（29 变体矩阵布局）、`counter-native`（最小测试范式）、`native`（桌面 API）、`code-editor`、`markdown-chat`、`notes`、`embed-webview`、`launcher/menubar-*`、`drag-drop`、shader/motion 系列（`wind`/`blackhole`/`chat-glow`/`confetti`/`effort-slider`/`timeline`）。

> 完整分析：`research/examples/EXAMPLES.md`。

---

## 4. UI 覆盖清单（展示内容的基础）

`research/ui-catalog/inventory.json`：**158 个可展示条目**，19 个分类，字段含 constructor/变体/绑定状态/关键方法/事件/状态/无障碍/平台说明/requires/文档路径/源码位置。

| 分类 | 条目 | 说明 |
|---|---:|---|
| Desktop & Platform | 31 | Window、菜单、托盘、对话框、通知、快捷键、剪贴板、拖放、显示器、电源、更新等 |
| Selection Controls | 16 | Checkbox/Radio/Switch/Toggle/Segmented/Tabs/Sidebar 等及其 Base |
| Layout | 13 | Column/Row/Box/Grid/Scroll/Split/Toolbar/Form/Field/Fieldset 等 |
| Text Inputs | 13 | TextInput/TextArea/SearchField/TokenField/Autocomplete/Combobox/Select/Number/Date/Time/EditableText |
| Data Display | 11 | List/Table/Tree/Outline/OutlineTable/GridView/Badge/Avatar/Image/Icon 等 |
| Overlays | 9 | Dialog/AlertDialog/Popover/Tooltip/Toast/ContextMenu/MenuButton/Overlay |
| Editors | 9 | CodeEditor/DiffViewer/FindBar/RichText/Markdown/TextBuffer 等 |
| Navigation | 8 | Router/Sidebar/Breadcrumbs/BackForward/HistoryButtons/Link/Tabs |
| Actions | 7 | Button/PrimaryButton/ButtonBase/Link/MenuButton/Toggle |
| Charts | 6 | Line/Area/Band/Pie/Stack/Time/Plot/Streaming（`ui/chart`） |
| Sliders & Steppers | 5 | Slider/RangeSlider/StepSlider/Stepper/Progress |
| Pickers | 5 | Calendar/DateInput/TimeInput/ColorPicker/ColorWell |
| Feedback & Status | 5 | Spinner/Meter/Rating/Toast/Progress 等 |
| Effects & Materials | 5 | Glass/GlassClear/ScrollEdge/Blur/Shader |
| Text & Typography | 4 | Text/Textf/RichText/字体与样式 |
| Media | 4 | Image/SVG/WebView/Canvas |
| Forms & Fields | 3 | Form/Field/Fieldset |
| Decoration & Drawing | 2 | Painter/Draw、Path/Polyline/Transform |
| Plugins & Extras | 2 | loading（29 指示器）、game |

> 为什么是 158 而不是“控件 100 个”：清单把 **UI 组件、子包（chart/editor/markdown/richtext/shader）、插件（glass/loading）、以及窗口/菜单/托盘等“应用级 UI”** 都算作可展示内容——这正是用户所说“全部 UI 和控件”的范围。
> 另有 `ui.Tester`、inspector、`mygo vet`、frame stats、渲染回退（`MYGO_GPU=0`）、wasm 构建等“开发者体验”内容，归入 App 的 Tooling 页面（见 PLAN）。

`INVENTORY.md`（74 KB）给出逐条可变体/方法/状态/来源；`SCREENS.md`（规划中）给出建议的 App 页面地图；`COVERAGE.md` 对比 gallery/docs-demo 的覆盖缺口。

---

## 5. 跨平台差异（“各系统表现”的事实基础）

完整版：`research/docs/PLATFORM-DIFFERENCES.md`（443 行，含 30+ 行对照表与源码级出处）。要点：

| 层面 | macOS | Windows | Linux |
|---|---|---|---|
| Native UI 渲染 | Metal | Direct3D 11（无 GPU 用 WARP） | OpenGL 3.3/ES 3.0，必要时 cairo CPU |
| 系统字体/默认字号 | SF / 13 | Segoe UI / 14 | GTK 界面字体 / 14 |
| 窗口按钮/隐藏标题栏 | 红绿灯 + `c.TitleBar()` | 分层子窗口画 caption buttons，支持 snap layouts | GTK 标题按钮（Wayland 下可能由 compositor 装饰） |
| 材质/毛玻璃 | 全部 NSVisualEffect 材质 + macOS 26 Liquid Glass | Win11 22H2+ Mica/Acrylic/Tabbed；Liquid Glass→Acrylic；Win10 无 | 无（`c.Vibrancy()==false`） |
| 菜单栏 | 应用级全局菜单（默认菜单） | 每窗口 Win32 菜单（默认无） | 每窗口 GTK 菜单（默认无） |
| 托盘 | NSStatusItem（模板图标、标题文字） | 通知区域图标 | AppIndicator（需 libayatana-appindicator3，必须有菜单） |
| 通知 | UserNotifications（**仅打包 app**） | 气泡 toast | D-Bus |
| 强调色/无障碍偏好 | 完整 | 完整（含 TextScale） | 部分（portal，可能缺失） |
| 快捷键 | `ui.Cmd`=Command；⌘[ / ⌘] 前进后退 | `ui.Cmd`=Control；Alt+←/→ | 同 Windows |
| 窗口定位 | 支持 | 支持 | X11 支持；**Wayland 忽略** |
| 无障碍后端 | NSAccessibility | UI Automation | ATK/AT-SPI |
| 打包 | .app + .dmg（签名/公证需 macOS） | .exe + NSIS 安装器 | 可执行 + .desktop + tar.gz + .deb |

**对本 App 的启示**：控件的外观/行为大多一致（MyGo 自己绘制），但“系统感”体现在窗口 chrome、菜单/托盘、字体、材质、preferences、快捷键与渲染后端。因此：
1. **应用内实时平台档案页**（检测 `runtime.GOOS`、`c.Preferences()`、`c.TitleBar()`、`c.Vibrancy()`、`mygo.Screen.PrimaryDisplay()`、渲染器/字体/缩放），把“当前这台机器”的真实数据摆出来；
2. **外观实验台**（Theme/强调色/Spacing/FontSize/RTL/语言/减少动态/高对比/zoom 实时切换）展示 token 级变化；
3. **真实截图矩阵**：每个平台构建后自动截图（`ui.Render` 无头或 `CapturePage()` 真窗），在 App“Platforms”页并列展示（截图由 CI 生成并作为资源嵌入，或本地运行按平台导出）。

---

## 6. 文档与知识库（已拉取）

- 全站离线文档：`research/docs/llms-full.txt`（1.2 MB / 22,738 行，114 篇，官方 generator 产物，链接已重写为绝对 URL）；索引 `llms.txt`。
- 仓库 Markdown 原文：`reference/mygo/docs/**`（22 + 85 + 9 篇），与站点内容一致（站点由 `website/llms.ts` 从这些 md 生成；仅 6 个文件含 repository-only 块）。
- 本地产出（docs-analyst）：
  - `research/docs/INDEX.md` — 114 篇文档地图 + 摘要 + 相关性标签 + 推荐阅读顺序 + 仓库专有内容清单。
  - `DIGEST-native-ui.md`（883 行）— Native UI 编程模型到各控件/渲染/测试的完整 digest。
  - `DIGEST-app-platform.md`（450 行）— App 生命周期、窗口、菜单、桌面 API、打包、CI 的实践版 digest。
  - `PLATFORM-DIFFERENCES.md`（443 行）— 上述跨平台事实 + 未文档化项标注。
  - `GOTCHAS.md`（337 行）— 硬约束/陷阱清单（生命周期、线程、主题、字体、测试、各平台）。
  - `DOC-GAPS.md` — 文档与源码的缺口（供后续补齐/提 issue）。
- 版本：站点与 checkout 均为 **v0.7.1**（`mygo.Version = "0.7.1"`）；main 领先 release 数个 commit，未观察到 docs/源码漂移；建议项目 pin `v0.7.1`。

---

## 7. 环境准备与可用性验证（实测证据）

主机：macOS 27.0.1 / arm64 / Apple M5 Pro / 64 GB / Metal 4 / 内建 2x 屏 / Dark 模式 / GUI 会话。
仓库：`prep/probe-native`（`mygo init -template native` 生成的一次性探针，非目标 App）。

| 能力 | 结果 | 证据 |
|---|---|---|
| Go 工具链 | ✅ 主机 go1.26.4；进入 MyGo 模块自动选 **go1.27.3**（`GOTOOLCHAIN=auto`，已缓存） | `research/prep/evidence/21-*`、`25-*` |
| mygo CLI | ✅ `mygo 0.7.1`，`~/go/bin/mygo`（**不在 PATH**，需 export）；`@latest`=v0.7.1 | `01/02/03-*` |
| `mygo doctor` | ✅ Go/Bun/macOS 全绿；可选依赖缺：makensis、osslsigncode、Developer ID | `04/10-*` |
| 无窗口测试 | ✅ `go test ./...` 0.39s；`ui.Render`/`Tester.Image` 字节级确定性；默认 light，可 `SetDark` | `06/07/08/09-*` |
| 真实 GUI | ✅ 窗口渲染成功，frame stats 显示 **Metal**；`CapturePage()` 输出 PNG | `13/14/15-*`、`probe-capturepage.png` |
| 热重载 | ✅ `mygo dev` 1.4s 启动；改文件 418ms 重建并重启；Ctrl+C 干净退出 | `17-*` |
| 打包 macOS | ✅ 9.1 MB `.app` + 3.0 MB `.dmg`，ad-hoc 签名，8.9s | `11-*` |
| 交叉编译 | ✅ darwin/universal（18.8 MB app）、linux/amd64（ELF+deb+tar.gz）、windows/amd64（PE32+ exe） | `12/16-*` |
| WebAssembly | ✅ `-platform web` 10.8 MB wasm；`mygo dev -web` 本地 :5174 正常 | `18/20-*` |
| 平台自检 | ✅ `prep/scripts/preflight.sh`：19 PASS / 0 FAIL / 1 SKIP（GUI 可选）；`--gui` 22 PASS | `23/24-*` |
| 截图能力 | ✅ 三种：`ui.Render`（无头、确定性）、`Tester.Image()`（交互后）、`Window.CapturePage()`（真窗） | 见证据目录 |
| 限制 | ⚠️ 无 Windows/Linux 运行时（只能编译）；仅有 Apple Development 证书，无 Developer ID/公证；NSIS/osslsigncode 未装；无头截图仅在同一 OS 内确定性（字体/文本引擎不同） | ENVIRONMENT.md §11/§12 |

> 复现：`prep/scripts/preflight.sh`；完整 Runbook：`research/prep/RUNBOOK.md`；事实表：`research/prep/ENVIRONMENT.md`。
> 注意：探针 `build/`、`.mygo/` 均是临时验证产物；目标 App 应新建独立模块（见 PLAN），不要把探针当起点。

---

## 8. 风险与注意事项（阶段 0 识别）

1. **API 处于 0.x**：v0.7.1 与 v0.8 可能有 breaking change；pin 版本、用 `go tool mygo vet`/`migrate-ui`，并在升级时重跑视觉测试。
2. **Element 生命周期是最容易踩的坑**：目录 App 的 registry 不能持有 Element/Context；所有 demo 状态放 struct；`mygo vet` + Tester 必须进 CI。
3. **跨平台验证受限**：本机只能 macOS 实测；Windows/Linux 需要 GitHub Actions 三种 runner 或真机，才能覆盖菜单/托盘/通知/材质/字体等系统差异。
4. **字体与截图确定性**：同一控件在不同 OS 字体下渲染不同，golden 截图必须 per-OS、带容差；不要跨 OS 比较严格像素。
5. **内容量巨大**：158 条目 × 变体/状态/代码/文案，必须数据驱动 + 复用 docs-demo 的 64 个 demo 代码，否则工期失控。
6. **性能**：目录页包含长列表/图表/编辑器/玻璃效果，需懒加载（每页独立 state、虚拟列表、`ui.Render` 仅测试时用）。
7. **签名/分发**：本机没有 Developer ID；分发给他人需证书/公证（macOS）与 Windows 代码签名；CI 可构建但需 secrets。
8. **浏览器版局限**：wasm 版没有菜单/托盘/通知/快捷键/无障碍，且字体来自浏览器；只能作为“快速浏览”，不能替代桌面版。
9. **许可**：MyGo/示例/gallery/docs-demo 均为 MIT；复用代码需保留版权声明（PLAN 里列出）。
10. **图标与品牌**：目前只有模板占位 icon；正式 icon/名称/identifier 待定（见 PLAN 的开放问题）。

---

## 9. 就绪检查清单（对照用户要求）

- [x] 深入了解 https://mygo.egoist.dev：框架定位、分层、Native UI 模型、桌面 API、生态、真实产品、性能基线。
- [x] 拉取所需文档：全站 114 篇离线 + 索引 + 6 份本地 digest + 逐控件清单 + 示例分析 + 跨平台差异。
- [x] 安装：Go 1.27.3 工具链、mygo 0.7.1 CLI、原生探针项目（pin 版本）。
- [x] 测试：无窗口 view 测试、真实窗口运行与截图、热重载、打包、三平台交叉编译、wasm。
- [x] 可用性检查：`mygo doctor`、preflight 自检、GPU/Metal 验证、确定性截图验证、已知限制清单。
- [x] 未实施目标 App（符合“先不要实施”）。
- [ ] 目标 App 的命名/标识/图标/平台优先级/语言等决策 → 见 [PLAN.md §11 开放问题](PLAN.md#11-开放问题需用户确认附建议默认值)（建议默认值已给出）。

---

## 10. 下一步

按 [TODO.md](TODO.md) 的 Phase 顺序执行（[PLAN.md](PLAN.md) 是方案背景）：先做 Phase 1.1.0（基线/公开仓库/CI）→ 1.2.0（外壳与设计系统），再逐步铺满目录、外观实验台、平台对比与三平台 CI，最后打包发布。开发用 `go tool mygo dev`（含原生 inspector），测试用 `go test ./...` + `go tool mygo vet .`，构建用 `go tool mygo build`。

## 11. 关键命令（速查）

```sh
# 工具链（一次）
export PATH="$HOME/go/bin:$PATH"      # mygo 0.7.1 已安装在这里
cd <app 项目> && go version            # 自动切换到 go1.27.3

# 开发/测试/构建
go tool mygo dev                       # 热重载 + 原生 inspector（F12 / ⌘⌥I）
go test ./... && go tool mygo vet .    # 行为测试 + 生命周期检查
go tool mygo build                     # 本机平台打包（build/<os>-<arch>/）
go tool mygo build -platform darwin/universal,windows/amd64,linux/amd64
go tool mygo build -platform web       # 浏览器版（build/<out>/web）
prep/scripts/preflight.sh --gui        # 环境自检（含真实窗口+截图）

# 常用调试环境变量
MYGO_GPU=0 mygo ...                    # 强制 CPU 渲染（对比/CI）
MYGO_FRAME_STATS=1 mygo ...            # 打印慢帧
MYGO_LOCALE=zh-Hans MYGO_DIRECTION=rtl mygo ...   # 语言/RTL 检查
```
