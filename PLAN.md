# MyGo Explorer — 实施计划（提案 v1）

> 状态：**待用户确认后进入实施**。阶段 0（调研/文档/环境）已完成，见 [PREPARATION.md](PREPARATION.md)。
> 依据：`research/ui-catalog/SCREENS.md`（页面规格）、`inventory.json`（158 条目）、`research/docs/*`（文档/平台差异/Gotchas）、`research/prep/*`（环境验证）。
> **执行入口**：[TODO.md](TODO.md)（Project 1.0.0 → Phase 1.1.0…1.10.0，含验收与 GATE 规则）。
> 版本基线：**MyGo v0.7.1**（`github.com/egoist/mygo`），Go **1.27.3**，纯 Go/无 cgo。

---

## 1. 目标与成功标准

### 1.1 目标

1. **展示 MyGo 的全部可用内容**：一套 Native UI 应用，覆盖 158 个可展示条目（控件、布局、文本、覆盖层、数据展示、图表、编辑器、媒体、动效/着色器/玻璃、桌面 API、插件）。
2. **直观对比各系统表现**：审查者能在同一 App 中看到 (a) 当前系统真实运行效果，(b) 外观 token 变化（明暗/强调色/字号/间距/RTL/语言），(c) macOS/Windows/Linux 的真实截图矩阵与差异说明。
3. **本身是 MyGo 的最佳实践样板**：视图/状态/生命周期/测试/无障碍/i18n/打包都按官方建议实现（`mygo-maintenance` skill），可作为社区参考。

### 1.2 成功标准（验收）

- [ ] 单一 Native UI App，macOS/Windows/Linux 均可构建运行（CI 验证），无 webview 依赖。
- [ ] 158/158 inventory 条目在 App 中可达（两跳内），每个条目展示：live demo、变体、状态、关键 API、代码片段、文档链接、平台说明。
- [ ] 100% 覆盖 `ui` 包公开构造函数（完整性测试守护，新版本 MyGo 自动发现缺口）。
- [ ] 外观实验台可实时切换：System/Light/Dark、系统/自定义 accent、Spacing 3/4/5、字号/文本缩放、Radius、LTR/RTL、语言/区域格式、Zoom 50%–300%、Reduce Motion/High Contrast 模拟。
- [ ] 平台页显示：运行时 OS/arch/渲染后端/缩放/字体/强调色/可用能力（tray/menu/vibrancy/glass/webview/notifications…），以及三平台差异矩阵与真实截图。
- [ ] 测试：每页 Tester 冒烟测试 + 关键交互测试；`go tool mygo vet .` 零问题；`go test -race`；三平台 CI 无头截图 golden（per-OS、带容差）。
- [ ] 可访问性：所有可交互 demo 有 Label/角色/键盘路径；Tab 顺序合理；支持 RTL 截图；界面中英双语。
- [ ] 分发产物：macOS `.app`+`.dmg`、Windows `.exe`+installer、Linux binary+`.deb`、可选的 wasm 静态站。
- [ ] 启动 < 1s（native），空闲 0% CPU，二进制 < 30 MB（含截图资源时另行评估）。

### 1.3 非目标（本期不做）

- 不是通用 UI 设计器/代码生成器（不做拖拽搭建、导出代码）。
- 不实现完整文档站替代品（链接到 mygo.egoist.dev 即可）。
- 不追求 Windows/Linux 的签名分发（本机无证书；CI 可产出未签名包）。
- 不包含游戏/终端/音频等“应用类”示例的完整复刻（在 `/desktop`/`/overview` 中以链接或小组件示意）。
- 不做自动更新（可选后置）。

---

## 2. 范围与内容策略

### 2.1 内容来源（优先级）

1. **`ui-catalog/inventory.json`** — 158 条目的权威清单（构造器/变体/状态/方法/平台注记）。
2. **`website/docs-demo/`** 的 64 个 demo（MIT）— 可直接改写为卡片 demo，节省 50%+ 工作量；同样可编译 wasm。
3. **`examples/gallery`**、`examples/loading`、`vibrancy`、`code-editor`、`markdown-chat`、`notes` 等 — 复用其交互与布局模式。
4. **`research/docs/DIGEST-*`** — 文案/说明/平台差异的表述来源（改写为 App 内简短说明，不整篇复制）。

> 覆盖现状（`COVERAGE.md` 实测）：官方示例合计覆盖 **113/158**（gallery 单独 113，其他示例补 17），**28 条完全无示例**——主要是 `*Base` 无外观控件、buffer 输入、Split/Scroll 方向变体，以及 updater/power/network/nowplaying/secrets/dock-jumplist/deep-links 等桌面 API；在线 docs 预览覆盖 111 条（64 页）。**这些正是 MyGo Explorer 相比 gallery/docs-demo 的核心增量。**

### 2.2 页面地图（21 页 + 外壳）

| # | 路由 | 页面 | 复杂度 | 核心内容 |
|---|---|---|---|---|
| 0 | `/` | **Shell** | L | 1180×760 窗口、隐藏标题栏自绘工具栏、侧栏、Router、面包屑/前进后退、主题/语言/RTL/Zoom、状态轨（state rail）、搜索 ⌘K、页面模板 |
| 1 | `/overview` | Overview & Environment | S | 平台卡片（OS/arch/renderer/scale/字体/GPU）、能力徽章、158 条目计数、入口链接、首个控件三连（spinner/meter/progress） |
| 2 | `/foundations` | Foundations & Tokens | M | 颜色 token 全景、accent/高对比/文本缩放、字体样张、间距/圆角/阴影/模糊 token、主题并排对比、`MeasureText` |
| 3 | `/layout` | Layout | M | Column/Row/Box/Spacer/Divider/Wrap、Scroll 三向、Grid、Split 四种、Form/Field/Fieldset、RTL/缩放/窗口尺寸压力 |
| 4 | `/actions` | Actions & Buttons | S | Button/Primary/ButtonBase/Toggle/ToggleGroup/MenuButton/Link/Badge、点击计数、快捷键、disabled |
| 5 | `/text` | Text & Typography | M | 字号/字重/装饰/对齐/MaxLines、RichText、可选中文本、超链接、字体族、CJK/emoji/RTL、`Textf` |
| 6 | `/inputs` | Text Inputs | M | TextInput/TextArea/SearchField/TokenField/Autocomplete/Combobox/Select/Number/Date/Time/EditableText/FindBar + `*Base`/Buffer 变体 |
| 7 | `/selection` | Selection Controls | M | Checkbox/Radio/Switch/Toggle/Segmented/Tabs 及 Base、混合/禁用/只读、组语义 |
| 8 | `/sliders` | Sliders, Steppers & Feedback | M | Slider/Range/Step/Stepper/Progress/Meter/Rating/Spinner/Toast 触发 |
| 9 | `/pickers` | Pickers | M | Calendar/DateInput/TimeInput/ColorPicker/ColorWell、区域格式联动 |
| 10 | `/navigation` | Navigation | M | Sidebar/Breadcrumbs/BackForward/HistoryButtons/Link/Tabs/Router 深链、历史/过渡 |
| 11 | `/overlays` | Overlays, Dialogs & Toast | L | Dialog/AlertDialog/Modal/Popover/Tooltip/Toast/ContextMenu/Overlay/`*Base`、焦点陷阱/Escape |
| 12 | `/data` | Data Display | L | List（1 万行、混合行高、多选）/Table（排序、编辑）/Tree/Outline/OutlineTable/GridView/Badge/Avatar/Image/Icon、行详情路由 |
| 13 | `/charts` | Charts | M | `ui/chart`: Line/Area/Band/Pie/Stack/Time/Streaming/Plot、选择与 tooltip |
| 14 | `/editors` | Code & Diff Editors | M | `ui/editor`: CodeEditor（高亮/补全/hover/diagnostics/fold）、DiffViewer（side-by-side/unified） |
| 15 | `/markdown-richtext` | Markdown & Rich Text | L | `ui/markdown` View/Stream、`ui/richtext` Editor + 格式工具栏、代码块 |
| 16 | `/media` | Media, Drawing & Web View | M | Image（PNG/JPEG/WebP/SVG）、Icon、Painter/Canvas/Path、`ui.WebView`（可用性检测） |
| 17 | `/drag-drop` | Drag & Drop | M | Drag/DragOver/Drop、自定义类型、列表重排、文件拖入、`transfer` 多格式、跨窗口拖放演示 |
| 18 | `/motion` | Motion, Transforms, Shaders & Glass | L | Animate/Transition/Timeline/Keyframes/Pose、Transforms、glass（Glass/Blur/ScrollEdge）、loading（29 个）、shader 示例 |
| 19 | `/desktop` | Desktop & Platform | L | 19 组真实桌面能力（窗口/标题栏/材质/菜单/托盘/对话框/通知/剪贴板/全局快捷键/显示器/Dock/JumpList/NowPlaying/电源/网络/密钥/更新/深链/文档/单实例/开机启动/WebView 可用性），带能力徽章与事件日志 |
| 20 | `/accessibility` | Accessibility, RTL & Languages | M | role/state/label/announce、焦点顺序、键盘走查、屏幕阅读器指引、语言/区域格式切换、RTL 并排 |
| — | `/settings` | 设置（可选抽屉） | S | 持久化外观/语言/截图导出目录/状态轨开关/代码片段默认展开 |

> 每页规格（控件、交互、状态、跨平台注意点、条目 id）已写在 `research/ui-catalog/SCREENS.md`，实现时直接照做。

### 2.3 统一页面模板（保证一致性）

```
页面头：标题(26 Bold) + 一句话目的 + 文档路径/源码位置（可点击打开）
Toolbar：BackButton · ForwardButton · Breadcrumbs · Spacer · [主题] [语言] [RTL] [Zoom] [搜索 ⌘K]
内容（Scroll）：
  ├─ DemoCard × 2–4：标题 + 说明 + live demo + 交互提示 + [复制代码] [重置] [状态按钮组]
  ├─ Collapsible "Variants & states"：一次性平铺全部变体/状态（真实 API 强制，如 Disabled/Error/Checked/Mixed/Focus）
  ├─ Collapsible "API surface"：来自 inventory 的 constructor/key_methods/events/states 表
  ├─ Collapsible "Code"：可复制 Go 片段（与 demo 源码同步，见 §3.6）
  └─ "On macOS / Windows / Linux"：差异说明 + 真实截图缩略图（若已采集）
页脚：条目计数 / 覆盖率徽章（如 “Buttons: 7/7, overall 158/158”）
```

### 2.4 外壳交互细节

- **窗口**：`TitleBarStyle: mygo.TitleBarHidden` + 自绘工具栏（`c.TitleBar()`/`DragWindow`），顺带展示 chrome 能力；`MinWidth 900`；`StateKey: "explorer"` 记住尺寸/位置。
- **侧栏**：`SidebarSection`（Elements / Content / Platform / Tooling）+ `SidebarItem(icon, label, Badge count)`；RTL 自动镜像。
- **命令面板（⌘K / Ctrl+K）**：覆盖层 + `SearchField` + 过滤后的页面/控件列表（数据来自 registry），Enter 跳转；支持 `?` 显示快捷键帮助。
- **快捷键**：⌘1…9 跳页；⌘K 搜索；⌘+/-/0 缩放；⌘[ / ⌘]（Win/Linux Alt+←/→）历史；⌘⇧L 切语言；⌘⇧D 切方向；F12/⌘⌥I 打开原生 inspector（debug 构建）。
- **状态轨（State rail）**：右侧可折叠栏，列出当前页可控状态（如 `open`, `disabled`, `error`, `mixed`, `checked`, `selection index`），点击用真实 API 强制状态；对 hover/pressed 这类指针态，按钮触发“截图模式”用 Tester 渲染（见 §4.7）。
- **搜索与深链**：所有页面/条目有稳定 id 与 kebab-case 路由（如 `/data/list/42`、`/desktop/window/vibrancy`），支持从 URL/命令行参数直达（`--open /charts`）。
- **Toast/复制**：复制代码、复制颜色值统一 `c.Toast` 反馈。

---

## 3. 技术方案

### 3.1 项目结构（建议）

```
MyGoExplorer/
├── app/                             # ← 目标应用（独立 Go module）
│   ├── main.go                      # App.WhenReady / 窗口 / 菜单 / 全局状态 / 设置加载
│   ├── go.mod                       # go 1.27.3 + tool mygo + require mygo v0.7.1
│   ├── go.sum
│   ├── mygo.json                    # name "MyGo Explorer", identifier, version, i18n, resources
│   ├── resources/icon.png           # 1024×1024（最终品牌图标待定）
│   ├── .agents/skills/mygo-maintenance/  # CLI 生成，保留
│   ├── internal/
│   │   ├── catalog/                 # 注册表与元数据
│   │   │   ├── catalog.go           # Entry 类型、Registry、按路由查找、计数/覆盖统计
│   │   │   ├── registry.go          # 汇总各 screen 的注册（init 或显式 slice）
│   │   │   └── screens/             # 每页一个 package，demo + 元数据 + snippet
│   │   │       ├── overview/
│   │   │       ├── foundations/
│   │   │       ├── layout/
│   │   │       ├── actions/
│   │   │       ├── text/
│   │   │       ├── inputs/
│   │   │       ├── selection/
│   │   │       ├── sliders/
│   │   │       ├── pickers/
│   │   │       ├── navigation/
│   │   │       ├── overlays/
│   │   │       ├── data/
│   │   │       ├── charts/
│   │   │       ├── editors/
│   │   │       ├── markdownrichtext/
│   │   │       ├── media/
│   │   │       ├── dragdrop/
│   │   │       ├── motion/
│   │   │       ├── desktop/
│   │   │       └── accessibility/
│   │   ├── shell/                   # 窗口外壳：sidebar/toolbar/router/命令面板/快捷键
│   │   ├── appearance/              # 外观实验台（theme 派生、accent 覆盖、density、text scale）
│   │   ├── platform/                # 运行时档案、能力检测、平台差异数据（来自 PLATFORM-DIFFERENCES）
│   │   ├── capture/                 # 截图/导出（in-app 与测试共用）
│   │   ├── settings/                # settings.json 读写（PathUserConfig）
│   │   ├── snippets/                # 生成的 demo 源码片段（go:embed）
│   │   └── uicheck/                 # completeness 检查（AST 枚举 ui 构造函数）
│   ├── tools/
│   │   ├── snippetgen/              # go generate：抽取 demo 源码 → internal/snippets/*.txt
│   │   └── uicheck/                 # go run：报告/CI 覆盖缺口
│   ├── testdata/golden/<os>/        # 三平台 golden 截图（CI 生成/更新）
│   ├── docs/                        # 可选：内嵌说明
│   └── .github/workflows/ci.yml     # 三平台测试+golden+构建
├── research/ …                      # 阶段 0 产物（保留）
├── prep/ …                          # 探针与 preflight（保留，不进 app）
└── reference/mygo/                  # 只读源码（.gitignore，不提交）
```

> 实施时用 `mygo init -template native app -name "MyGo Explorer" -module <module>` 生成骨架，再把可在 `go.mod` 中 `tool` 的 CLI 与 `mygo.json` 调整好。

### 3.2 依赖与版本（可复现）

```go
// app/go.mod
module <module>            // 待定，见 §13

go 1.27.3

tool github.com/egoist/mygo/cmd/mygo

require github.com/egoist/mygo v0.7.1
// indirect: purego, go-text/typesetting, x/image, x/net, x/text
```

- 全部 UI 能力都在同一个 `github.com/egoist/mygo` 模块内（`ui`、`ui/chart`、`ui/editor`、`ui/markdown`、`ui/richtext`、`ui/shader`、`plugins/glass`、`plugins/loading`），无需额外依赖。
- `tool` 指令让 `go tool mygo dev|build|vet` 使用 pin 的 CLI 版本；全局 `mygo` 仅用于 `init`/`doctor`。
- 升级策略：每次升级 `go get github.com/egoist/mygo@vX.Y.Z` → `go tool mygo vet .` → `go test ./...` → 三平台 golden 对比 → 必要时 `go tool mygo migrate-ui .`（预览，再 `-write`）。锁定版本写进 README。

### 3.3 Catalog 数据模型

```go
// internal/catalog/catalog.go
type Entry struct {
    ID          string      // "button", "text-input", 对应 inventory id
    Title       string      // 显示名（经 i18n）
    Page        string      // 路由，如 "/actions"
    Section     string      // 页内分组
    Constructor string      // "func Button(c *Context, label string) Element"（完整性检查用）
    Covers      []string    // 覆盖的构造器名（含变体，如 PrimaryButton、ButtonBase）
    Kind        Kind        // Widget/Layout/Overlay/DesktopAPI/...
    DocsPath    string      // "docs/ui/button.md"
    SourceRef   string      // "ui/api_gen.go:775"
    Tags        []string    // "base", "platform:darwin", "plugin:glass", "browser:no"
    Availability func(profile platform.Profile) Availability // available/unsupported/needs-plugin
    Variants    []Variant   // 名称 + 构建函数
    States      []StateDemo // 真实 API 强制状态
    Props       []Prop      // 关键方法/事件（来自 inventory key_methods/events）
    Build       func(c *ui.Context) // live demo（可带页级状态闭包）
    Snippet     string      // 由 go generate 注入/校验
}
func (r *Registry) Entries() []*Entry
func (r *Registry) Coverage() (covered, total int)
```

- **注册方式**：每页一个 package，`var Entries = []catalog.Entry{...}`；`internal/catalog/registry.go` 汇总。demo 状态放在各页的 `State` 结构体（由 `screens` 包持有单例，`main` 里创建并注入），避免 `init` 全局可变状态。
- **变体/状态用声明式切片**：`Variants: []Variant{{Name:"Default", Build: func(c){...}}, ...}`，页面统一渲染为网格，新增变体只加一行。
- **完整性测试**（关键创新）：`internal/uicheck` 用 `go/parser` 解析 `go list -m -f '{{.Dir}}' github.com/egoist/mygo` 下的 `ui/api_gen.go`（公开构造器）+ `ui/*.go` 手写构造器，与 registry 的 `Covers` 做集合比较；缺失 → 测试失败并列出名字。排除项（如 `NewTester`/`Render`/`Local`/`Drop` 等非视觉 API）在 `uicheck/exclude.go` 显式列出并注释理由。这样 MyGo 升级新增控件时，App 会自动“提醒”补齐内容。
- **覆盖率页脚/Overview**：显示 `covered/total`（如 158/158）与各分类计数，作为“展示全部”的量化证明。

### 3.4 状态管理与生命周期（按官方规则）

- 全部持久状态放 app 结构体/页面 State（`[]galleryTask`、`ui.ListState`、`ui.Selection[T]`、`*richtext.Document`、`*editor.Buffer` 等），**绝不**存 `ui.Element`/`*ui.Context`。
- 控件身份：循环/动态列表用 `c.Key(...)`/`.ItemKey`；跨帧焦点用 `.Bind(&handle)`/`FocusBind`；只在需要时用 `ui.Handle`。
- 跨 goroutine：动效/假数据用 `Window.Update`/`Services.Invalidate`；demo 内不启无限 goroutine（除 Overview 的时钟、Charts 的流式数据，用显式 job + 取消）。
- 变更集合时用 `OnClick` 而非在构建中直接改 slice；回调在 build 后运行。
- `go tool mygo vet .` 进 CI（检测 Element/Context 误存）；`go test -race` 覆盖共享状态。

### 3.5 主题、外观实验台与平台档案

- **默认主题**：跟随系统（`LightTheme()/DarkTheme()` 已应用 OS accent/contrast/text-scale 规则，见源码 `ui/preferences.go`）。**注意**：若对主题做自定义（覆盖 accent/间距/字号），需每帧 `c.SetTheme(derived)`（`SetTheme` 是 per-frame 的）。
- **AppearanceState**：`mode(system|light|dark)`、`accent(system|custom hex)`、`density(spacing 3|4|5)`、`fontScale(1|1.15|1.3)`、`radius(0|6|10)`、`direction(auto|ltr|rtl)`、`locale(en|zh-Hans|…)`、`zoom(0.5–3)`。组合后派生 `*ui.Theme`：
  ```go
  base := ui.LightTheme(); if dark { base = ui.DarkTheme() }
  t := *base
  if accentSet { t.Accent, t.AccentHover, t.AccentPressed, t.AccentText = ... ; t.Focus = ... }
  t.Spacing *= density; t.FontSize *= fontScale; t.Radius = radius
  c.SetTheme(&t)
  ```
- **系统 accent**：`c.Preferences().Accent`（`image/color`，A=0 表示无 → 回退到主题蓝）；同步展示 `HighContrast/ReduceMotion/ReduceTransparency/TextScale`。
- **方向**：`root.Direction(ui.RightToLeft)`（窗口级）或子元素 `.Direction(ui.RightToLeft)`（局部对比）；`MYGO_DIRECTION` 仅用于启动时。
- **语言**：`mygo.App.SetLocale(tag)` + i18n catalogs；App 自身文案走 catalogs（dogfooding）；数字/日期用 `c.Locale()/c.Region()`。
- **设置持久化**：`dir, _ := mygo.App.Path(mygo.PathUserConfig)` → `settings.json`（App 自身偏好；窗口几何用 `StateKey` 原生状态）。写入防抖，启动时读取；提供“重置设置”。
- **平台档案**（`internal/platform`）：
  - `runtime.GOOS/GOARCH`、`c.Preferences()`、`c.TitleBar()`、`c.Vibrancy()`、`c.Scale()`?（用 `mygo.Screen.PrimaryDisplay().ScaleFactor`）、`c.Zoom()`、`mygo.WebViewAvailable()`、`mygo.NotificationsSupported()`、`mygo.GlobalShortcut`/`mygo.Tray` 可用性试错结果、`mygo.Version`。
  - 渲染后端：开发模式通过 `MYGO_FRAME_STATS` 日志不可读；用 `runtime.GOOS` 推断（macOS Metal / Windows D3D11|WARP / Linux OpenGL|CPU），并注明“推断/文档依据”。
  - 对比数据：`PLATFORM-DIFFERENCES.md` 的矩阵转成 Go 表（行=能力，列=三平台），App 内渲染为 `Table`/`Grid`；每格附“文档依据”标记（docs vs inferred）。

### 3.6 代码片段与 demo 源码同步

- 每个 demo 写在独立文件/函数（如 `screens/actions/button.go`），`//go:generate go run ./tools/snippetgen` 用 AST 抽取指定函数 + 注释，生成 `internal/snippets/<id>.go.txt`（`//go:embed` 引入）。
- 测试校验：重新生成到临时目录，与已提交片段逐字节比较（类似 `gofmt -l`），保证 App 显示的代码永远是最新实现。
- 片段展示：`ui.Text`（`Font("monospace")`）或（可选）`ui/editor` 只读 Buffer 提供高亮；附复制按钮 `c.WriteClipboard(snippet)` + Toast。
- 初期可手工维护片段字符串，M2 再引入 generator；但**必须**在 M2 前建立同步校验。

### 3.7 截图、导出与 golden

三层能力（均已在本机验证可行）：

| 方式 | API | 用途 | 确定性 |
|---|---|---|---|
| 无头渲染 | `ui.Render(view, w, h, scale) *image.RGBA` | CI 三平台 golden、文档/分享图 | 高（同 OS 字节级一致；字体跨 OS 不同） |
| Tester 快照 | `ui.NewTester` + `tt.SetDark/SetPreferences/SetLocale/SetDirection/SetSize/SetScale` + `tt.Click/Key/Advance` + `tt.Image()` | 强制 hover/pressed/focus 等指针态；交互后截图；行为测试 | 高（时钟可控） |
| 真窗截图 | `win.CapturePage() ([]byte, error)`（native UI 走 `captureContent`） | 应用内“导出当前页/全部页”、平台对比素材 | 真实渲染（含 GPU） |

- **In-app**：工具栏“Export ▸” → 当前页 PNG / 全部页面 PNG + `manifest.json`（OS、theme、direction、locale、尺寸、条目 id）写入 `~/Pictures/MyGo Explorer/` 或用户选目录；用于在任意机器上生成该平台证据。
- **CI golden**：`go test ./internal/... -run TestGolden -update` 生成 `testdata/golden/<goos>/…`；PR 校验用 `-update=false`。矩阵：`macos-latest`、`windows-latest`、`ubuntu-latest`（Ubuntu 用 `MYGO_GPU=0` 确保 CPU 渲染，无显示需求）。字体差异 → 只与同 OS baseline 比较，容差参数（如 RMS < 1.5%）。
- **App 内展示**：`ui.Image(ui.DecodeBitmap(...))` 显示 CI 采集的三平台截图（资源放 `resources/platform/<os>/*.png`，`go:embed`；注意体积：按页面缩略图 800×600 WebP/PNG 压缩，控制在 10–15 MB 内；build tag 或仅发布版包含）。
- **可选**：`--capture <dir>` 命令行模式（无交互、逐页截图后退出），供 CI/真机批量产出；实现为启动后由主线程状态机推进（每帧一页，`CapturePage` 完成后 `Next`）。此功能在 M3 评估复杂度，M5 前完成。

### 3.8 无障碍 / i18n / RTL

- 每个 demo：英文 + 中文（catalogs）；`Label` 全量、角色/状态按 inventory 的 `accessibility_notes`；对比色/焦点环随主题。
- Tester 断言：`tt.Announcements()`、`tt.Focused()`、`tt.Texts()`；CI 加 `go vet` 与静态检查（不用外部 linter）。
- RTL：Layout/Text/Navigation/Data/Accessibility 页提供 LTR/RTL 并排预览（子元素 `.Direction`），其余页跟随全局。
- 键盘：Tab 顺序按页面文档顺序；`FocusGroup` 用于工具栏/Tab 条；⌘K/⌘1…9/⌘[/] 与平台惯例一致（`ui.Cmd` 自动映射）。
- 屏幕阅读器说明卡：VoiceOver/Narrator/NVDA/Orca 的试用步骤（文档引用）。

### 3.9 性能

- 每页独立 State + 懒加载（Router 只构建当前页；`Scroll` 虚拟化列表；大 List 用 `ListState`）。
- 重内容（CodeEditor/Markdown/Chart/富文本）只在对应页构建；离开页面即销毁（Element 生命周期天然保证），昂贵对象（Buffer/Document/Bitmap/SVG）按页缓存并在首次进入时创建。
- 图片：`ui.DecodeBitmap` 一次，使用后 `ReleasePixels`（截图缩略图）。
- 目标：页面切换 < 16ms build；空闲 0% CPU；`MYGO_FRAME_STATS=1` 检查慢帧；内存 < 200MB（含截图资源）。
- 参照 `research/docs/DIGEST-native-ui.md` 的性能章节与官方 `docs/ui/performance.md`。

### 3.10 桌面能力演示（`/desktop`）

- 由于 31 个 Desktop 条目无法都在一个 view 内“内嵌展示”，做**真实动作 + 事件日志**：按钮真正调用 `mygo.Dialog/NewTray/GlobalShortcut/Notification/Screen/Clipboard/...`，结果写进页面 Event Log（带时间、成功/错误、平台可用性）。
- 每个 section 有：可用性徽章（available/unsupported/denied）、Run 按钮、结果日志、平台说明、文档链接。
- 可选窗口：`/desktop` 可打开真实的第二窗口（材质/标题栏/Flyout/Tray 面板），并显示 `c.TitleBar()`/`c.Vibrancy()` 实测值；`mygo dev`/`mygo build` 打包后通知才可用（开发 app 也是 bundle，实测可用）。
- CI/无头：这些动作在测试中不执行真实系统调用（用 `//go:build !test` 或运行期开关 guard），只测构建；真机/手动验收。

---

## 4. 跨平台“各系统表现”策略（三层）

1. **运行时真实层（本机）**：Overview/Platform 页报告 `runtime.GOOS`、渲染后端推断、显示器/缩放、字体、系统 accent、preferences、`c.TitleBar()` 实测、能力检测（webview/notifications/tray/glass）。用户在任何平台运行 App 即看到“本机真相”。
2. **外观切换层（同一机器）**：Appearance Lab 实时切换 light/dark、accent（系统/自定义）、spacing/font size/text scale/high contrast/reduce motion、RTL、locale、zoom；Foundations/Text/Layout 等页提供并排对比。这覆盖“token 级系统差异”（颜色、字体、间距、圆角、方向、格式）。
3. **真实跨系统截图层（CI/真机）**：三平台 CI 用 `ui.Render`/`CapturePage` 生成同页面截图，提交到 `testdata/golden/<os>` 并在 App 的 Platforms 页并列展示（标注 OS/字体/渲染器/日期）。覆盖“窗口 chrome、菜单、托盘、材质、通知、字体渲染”等本机无法模拟的差异。

**平台差异内容**：把 `PLATFORM-DIFFERENCES.md` 的矩阵产品化（窗口 chrome、字体/字号、accent/对比度/文本缩放、材质/玻璃、滚动条、键盘惯例、菜单/托盘/通知、打包），每行 3 列 + 依据标记；在 `/desktop` 每节显示该 OS 的真实行为与不可用原因。

**浏览器版（可选但推荐）**：`go tool mygo build -platform web` 生成 wasm 静态站，公开仓库下优先用 **GitHub Pages** 发布（Actions 一步到位、零额外账号；也可用 Cloudflare Pages，按用户级 Cloudflare 指引走 `cf` CLI）。用途：让无法安装桌面版的评审者快速浏览控件外观；但需明确标注 wasm 版不提供菜单/托盘/通知/全局快捷键/无障碍，字体来自浏览器。

---

## 5. 测试与质量门禁

| 类型 | 工具/做法 | 门禁 |
|---|---|---|
| 页面冒烟 | 每页 1 个 `ui.Tester` 测试：构建 view、断言关键文本/计数、点击主要按钮、切换主题/RTL | `go test ./...` 必过 |
| 交互行为 | 关键控件针对性测试（输入/选择/列表键盘/overlay Escape/菜单选择/路由历史/拖放） | 每类 ≥2 条 |
| 生命周期 | `go tool mygo vet .`（Element/Context 误存、goroutine 捕获） | 零告警 |
| 完整性 | `go test ./internal/catalog -run TestCoverage`（AST 枚举 ui 构造器 vs registry） | 100% |
| 截图 golden | 每页 × {light,dark} × 1 尺寸；`ui.Render`；同 OS 比较 + 容差 | CI 三平台 |
| 无障碍 | Tester 断言 labels/roles/announcements；人工 VoiceOver/Narrator/Orca 走查（M5） | 手动清单 |
| i18n | `go tool mygo i18n check`（catalogs 一致性）；切语言断言格式 | 零 error |
| Race/内存 | `go test -race ./...`；`MYGO_FRAME_STATS=1` 抽查 | 零 race |
| 平台构建 | CI 三平台 `go tool mygo build`（含 web） | 全绿 |

> 注意：headless 渲染默认 **light** 主题（探针实测），golden 必须显式 `tt.SetDark(false/true)`；同一 OS 字体确定，跨 OS 不可比。

---

## 6. CI/CD 与分发

> 代码托管已确认：**Public GitHub repo**（用户 2026-10-27 决定）。仓库主页同时承担“在线展示”职责：README 放截图/GIF、平台矩阵、Coverage 徽章。

- **仓库约定（Public）**：
  - 建议仓库名 `mygo-explorer`（公开），`LICENSE` = MIT；`README.md` 含定位、截图（三平台）、158/158 Coverage、构建/运行方式；`CONTRIBUTING`/Issue 模板可选。
  - **不得提交任何密钥**：签名证书、更新私钥、Cloudflare token 等只放 GitHub Actions Secrets（仓库 Settings → Secrets），CI 中通过 env 注入；本地密钥与 `*.p12`、`mygo-update.key` 进 `.gitignore`。
  - 公开仓库的 Actions 免费额度覆盖三平台标准 runner（`macos-latest`/`windows-latest`/`ubuntu-latest`），足以支撑测试 + 截图矩阵 + 构建；Release 资产公开可下载（未签名包标注“未签名/仅供测试”）。
  - 三平台 golden 截图可提交到 `testdata/golden/<os>/`（注意仓库体积：仅保留代表性页面、压缩 PNG/WebP；完整矩阵作为 Actions Artifact / Release 附件，避免仓库无限膨胀）。
- **CI（GitHub Actions）**：三平台矩阵 `macos-latest` / `windows-latest` / `ubuntu-latest`：
  1. checkout → setup-go（读 `go.mod` 的 1.27.3）→ `go test ./...`、`go tool mygo vet .`；
  2. golden 校验（`-update=false`；发布前用 workflow_dispatch 更新并提交）；
  3. `go tool mygo build`（本机平台）+ `-platform web`；
  4. 可选：`platform-capture` job（真机无头截图，Ubuntu 需 `MYGO_GPU=0`/xvfb；mac/win runner 直接跑 headless capture 模式）→ 上传 artifact / 提交到 `testdata/golden`；
  5. 可选：PR 上运行 `go test -race`；main 分支保护要求 CI 绿。
- **发布（M5）**：公开 Release（tag `v0.1.0`）附 macOS/Windows/Linux 构建产物 + 三平台截图压缩包；`go tool mygo build -platform darwin/universal,windows/amd64,windows/arm64,linux/amd64,linux/arm64`；macOS 需 Developer ID + notarize（本机没有，用户提供证书后放 Secrets；没有则发布未签名包并在 Release Notes 说明）；Windows 安装器需 NSIS（CI 的 Ubuntu 可装）；Linux deb 直接可用。
- **Web 部署（可选）**：`mygo build -platform web` → `build/web`。公开仓库下优先 **GitHub Pages**（Actions 直接发布，零额外配置）；也可用 Cloudflare Pages（`cf` CLI / 控制台，遵循用户级 Cloudflare 指引）。用途：浏览器即可浏览控件外观；页面标注 wasm 版限制（无菜单/托盘/通知/全局快捷键/无障碍）。
- **自动更新**：可选（`updates` 配置 + `mygo keygen`，私钥放 Actions Secrets），本期不做。

---

## 7. 里程碑与排期（估算，单人开发；Agent 协作可压缩日历时间）

| 里程碑 | 内容 | 估算 | 验收 |
|---|---|---|---|
| **M0 ✅ 已完成** | 调研、文档、控件清单、环境验证 | — | 本报告 + `preflight.sh` 19 PASS |
| **M1 骨架与试点** | `mygo init` 项目、go.mod 固定、App 外壳（窗口/侧栏/工具栏/Router/命令面板骨架/主题切换/RTL/Zoom）、页面模板组件（DemoCard/状态轨/代码卡/API 表）、Overview + Foundations + 5 个代表页（Actions/Inputs/Selection/Overlays/Data 各 1 页试点）、截图基础设施 spike（`ui.Render` golden + `CapturePage`） | 3–4 天 | App 可运行；试点页完整；Tester 冒烟测试；`mygo vet` 干净；macOS 真实截图 |
| **M2 全量目录** | 21 页全部内容、158 条目全部可达、变体/状态网格、代码片段 generator + 校验、命令面板真实搜索、Coverage 测试 100% | 6–8 天 | 158/158、100% 构造器覆盖、全页截图 |
| **M3 外观与平台** | Appearance Lab 完整（accent 覆盖/density/font scale/contrast/motion/RTL/locale）、Platform Profile + 差异矩阵 + `desktop` 能力检测、截图矩阵嵌入 + `--capture` 模式、i18n en/zh + 语言切换 | 4–5 天 | 三层跨平台呈现可用；en/zh 完整；RTL 测试 |
| **M4 深度内容** | Charts/Editors/Markdown+RichText/Media/Drawing/WebView/DragDrop/Motion+Shaders+Glass+Loading/Desktop 19 组真实动作 + 事件日志 | 5–7 天 | 全部复杂页完成；性能达标 |
| **M5 质量与发布** | 三平台 CI + golden 矩阵、`go test -race`、a11y 走查、打包 dmg/installer/deb/web、README/使用说明、品牌 icon、许可声明 | 4–5 天 | CI 全绿；产物可安装；文档完成 |
| 合计 | | **22–29 人天**（约 4–6 周；并行/Agent 可 2–3 周日历） | |

> 顺序依据 `SCREENS.md §21`：先外壳+代表页，再逐类铺满，最后桌面/无障碍/测试。每完成一页即接入测试与截图，避免末期返工。

---

## 8. 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| Element/Context 生命周期误用 | panic（dev）/静默失效（release） | 工程约定 + `mygo vet` + Tester 覆盖 + code review；registry 只存数据/构建函数 |
| MyGo 0.x API 变动 | 升级破坏 | pin v0.7.1；升级 checklist（vet/test/golden/migrate-ui）；CI 装 pin 版 |
| 内容量 158 条目 | 工期/维护 | 数据驱动 + 复用 docs-demo 64 demos + 每页独立文件；先全量可达再精修 |
| 跨平台验证缺真机 | 平台行为不实 | 三层策略；CI 三 runner；App 内标注“文档依据/推断”；真实截图由 CI 产出 |
| 截图确定性（字体/AA） | golden 抖动 | per-OS baseline + 容差 + 固定尺寸/缩放/主题/时钟；必要时 `MYGO_GPU=0` |
| 桌面 APIs 无法自动测 | 回归 | 真实动作只在手动/真机验收；CI 用构建期 guard 跳过；事件日志辅助手测 |
| 性能（大页面/图表/编辑器） | 卡顿 | 懒加载/每页 state/虚拟列表/Cache；`MYGO_FRAME_STATS` 抽查；复杂页不进首屏 |
| 签名/分发 | 无法给他人安装 | macOS 需 Developer ID+公证；Windows 需证书；未签名包内部使用/自签 |
| wasm 版局限 | 误导 | UI 明示限制；默认推荐桌面版 |
| 许可 | 合规 | 保留 MyGo MIT 版权；复用的 gallery/docs-demo 代码在文件头注明来源（见 §10） |

---

## 9. 工程约定

- **生命周期**：不存 Element/Context；持久状态在 app/State；Handle 只用于焦点/身份；`go tool mygo vet .` 必须干净。
- **身份**：动态列表必给 Key/ItemKey；同父级唯一；`Selection/ListState/Router` 只创建一次。
- **副作用**：I/O/慢计算离 UI 线程；用 `Window.Update`/Services 回传；取消过期任务。
- **命名/路由**：条目 id = inventory id；路由 kebab-case；页面文件按 screen 分组。
- **提交**：小步提交；每页一个 commit 量级；CI 全绿再合并。
- **文档**：每个 demo 上方注释“对应 docs 页面 + inventory id”；README 记录开发/构建/截图命令。
- **许可**：项目整体 MIT；`internal/catalog/screens` 中改写自 MyGo 示例的代码在文件头保留 “Adapted from github.com/egoist/mygo (MIT) — <path>”；App 关于页列出 MyGo 与第三方许可。

---

## 10. 交付物（M5 结束时）

1. `app/` 完整源码（含测试、CI、golden）；
2. 三平台安装包（dmg / NSIS installer / deb）与可选 web 静态站；
3. README（截图 + 使用说明 + 开发指南 + 平台差异说明）；
4. `testdata/golden/<os>` 三平台截图矩阵；
5. Coverage 报告（158/158、构造器 100%）；
6. 可选的 `docs/` 站内说明页。

---

## 11. 开放问题（需用户确认，附建议默认值）

| # | 问题 | 建议默认 |
|---|---|---|
| 1 | App 名称 / identifier / 图标 | 名称 **MyGo Explorer**；identifier `dev.mygoexplorer.app`；图标待设计（先用模板占位，M5 换品牌 icon） |
| 2 | 平台优先级 | 三平台同步（macOS 本机实测；Win/Linux 由 CI + 截图矩阵覆盖） |
| 3 | 代码托管/CI | ✅ **已确认：Public GitHub repo**（2026-10-27）；仓库名建议 `mygo-explorer`，MIT License；CI 三平台矩阵 + Release 公开下载 + 可选 GitHub Pages；密钥只放 Actions Secrets |
| 4 | 界面语言 | **English + 简体中文**（dogfood i18n，可扩展 zh-Hant/ja） |
| 5 | 范围深度 | **全量 158 条目**（含 editor/chart/markdown/richtext/glass/loading/shader 与桌面 API）；M2 先完成核心控件，复杂包在 M4 |
| 6 | 跨平台截图来源 | **GitHub Actions 三平台**生成；本机可选 `--capture` 导出；不要求购买 Windows/Linux 真机 |
| 7 | 分发方式 | 本机未签名构建 +（可选）GitHub Release 附未签名包；签名/公证需用户提供证书（macOS Developer ID、Windows 证书） |
| 8 | Web 版 | **做**（`-platform web`，公开仓库下优先 GitHub Pages，亦可 Cloudflare Pages），明确标注功能限制 |
| 9 | 视觉风格 | 跟随系统主题 + 可切换；品牌只用于图标/标题，不给控件换皮（保证“原生”观感） |
| 10 | 文档正文 | 不内嵌全文；页面头链接在线文档 + 短摘要/代码 |
| 11 | 自动更新/遥测 | 不做（保持简单与隐私） |
| 12 | 是否要在 App 内实时展示本机“真实系统菜单/托盘/通知” | 做（`/desktop` 真实动作 + 事件日志），但需用户在真机验收 |

> 若以上默认值可接受，回复“按默认开始 M1”即可；需要调整的项直接指出。

---

## 12. 附录

### 12.1 关键命令

```sh
cd app
go tool mygo dev                    # 开发（热重载 + inspector）
go test ./... && go test -race ./...
go tool mygo vet .
go tool mygo i18n check             # 有 catalogs 后
go tool mygo build                  # 本机平台
go tool mygo build -platform darwin/universal,windows/amd64,linux/amd64
go tool mygo build -platform web
go generate ./internal/...          # 代码片段生成（M2 引入）
```
环境变量：`MYGO_GPU=0`（CPU 渲染对比/CI）、`MYGO_FRAME_STATS=1`、`MYGO_LOCALE=zh-Hans`、`MYGO_DIRECTION=rtl`、`MYGO_INSPECTOR=1`（debug 构建）。

### 12.2 参考资料（本地）

- `research/docs/DIGEST-native-ui.md` — Native UI 完整指南
- `research/docs/DIGEST-app-platform.md` — App/桌面能力/打包
- `research/docs/PLATFORM-DIFFERENCES.md` — 平台差异事实表
- `research/docs/GOTCHAS.md` — 硬约束/陷阱
- `research/ui-catalog/SCREENS.md` — 21 页规格（逐页条目/交互/状态）
- `research/ui-catalog/inventory.json` / `INVENTORY.md` — 158 条目清单
- `research/ui-catalog/COVERAGE.md` — 示例覆盖缺口（gallery 113/158，28 条无任何示例，含 12 个 `*Base`）
- `research/examples/EXAMPLES.md` — 官方示例/可复用代码分析
- `research/prep/ENVIRONMENT.md` / `RUNBOOK.md` / `prep/scripts/preflight.sh` — 环境与复现
- `reference/mygo/docs/**` — 官方 Markdown；在线版 https://mygo.egoist.dev
