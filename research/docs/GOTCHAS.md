# Gotchas, hard constraints and pitfalls — MyGo native UI

For the MyGo Explorer implementer. Everything here is either a hard
requirement, a documented trap, or something the docs leave implicit but
source/experience confirms. Sources use the same conventions as the other
digests (`ui/views.md:12` = `reference/mygo/docs/ui/views.md:12`,
`ui/frame.go:64` = `reference/mygo/ui/frame.go:64`). Read this before
writing view code; most items cost hours to debug otherwise.

---

## 1. Toolchain and build requirements

| Requirement | Detail |
|---|---|
| **Go 1.27.3+** | `reference/mygo/go.mod:3` says `go 1.27.3`. Public docs say “Go 1.27 or later” (`docs/README.md:170`, `docs/getting-started.md:8-14`). With an older local Go and `GOTOOLCHAIN=auto`, the toolchain downloads automatically (recon verified go1.27.0 for a `go 1.27` probe; the repo will fetch 1.27.3). |
| **No cgo** | MyGo is pure Go (`docs/README.md:172-174`); CLI builds default `CGO_ENABLED=0` (`docs/cli.md:229`). Do not add cgo dependencies; if unavoidable, set `CGO_ENABLED=1` and a `CC` for cross-builds (`docs/distribution.md:31-33`). |
| **CLI for native projects** | The project pins the CLI as a Go tool: `go tool mygo dev|build|generate` (`docs/cli.md:23-25`). `mygo` is not on PATH in this workspace yet (recon). |
| **No Bun/frontend for native UI** | Native template has no frontend, no npm, no Vite (`docs/getting-started.md:73-91`). Do not add a frontend unless you want the optional `ui.WebView` demo/tabs. |
| **Cross-compile works from any machine** | `-platform darwin/universal,windows/amd64,linux/amd64,...`; only macOS signing/dmgs need macOS, NSIS needed for Windows installers off-Windows (`docs/distribution.md:26-55`; `docs/github-actions.md:10-20`). |
| **Release builds strip the inspector** | `mygo build` drops it (~250 KB); `-debug` or `MYGO_INSPECTOR=1` keeps it; `go build` keeps it unless `-tags mygo_noinspector` (`docs/ui/inspector.md:25-30`). |
| **GUI not available in headless CI for `mygo dev`** | Local runners here are macOS with a GUI session (recon); Linux/Windows validation needs real machines or CI (public docs do not describe GUI-test setup; it is repo-only: `docs/architecture.md:4178-4230`). |

---

## 2. The element/Context lifetime rules (most common source of panics)

1. **An `ui.Element` is valid only for the build pass that created it** —
   it expires *before the next pass, even within the same frame*
   (`ui/element.go:253-260`, `ui/migration.md:41-46`). Do not hold it in a
   field, package var, slice, map, closure that outlives the pass, or send it
   to a goroutine.
2. **Dev builds panic on stale use** with `ui: element from pass N used in
   pass M; keep a ui.Handle instead`; **production builds silently return
   empty/ignore** (`ui/frame.go:104-118`, `ui/handles_debug.go:5`,
   `ui/handles_release.go:5`). A bug can pass in release and explode in dev —
   run `go tool mygo vet .` and tests.
3. **`Valid()` is the safe check** for optional elements; it never panics.
   Use `ui.Element{}` for absence — not `nil`, not zero-valued assignments
   to typed variables (`ui/migration.md:29-39`). Parts values
   (`ui.SelectParts[T]`, `TabsParts`, `ToastParts`, …) obey the same lifetime.
4. **Never store `*ui.Context`.** It is stable per window but only usable
   while building; `mygo vet` flags Context pointers in fields/package
   vars/goroutines (`ui/views.md:8-16,191-195`, `ui/migration.md:187-192`).
   In a helper, pass `c` through and give child builders `func()` closures.
5. **Persistent identity = `ui.Handle`** (alias `ui.Ref`): `Bind(&h)` each
   build; `Focus/CancelFocus/Focused/FocusWithin/Resolve/Bounds/Shortcut`.
   Widget states (`ListState`, `ScrollState`, `GridState`, `Router`) carry
   handles for their own focus.
6. **`ui.Local(e, key, init)`** keeps per-element state across frames — only
   for widget-internal state; real app state belongs to your structs
   (`ui/custom-widgets.md:72-95`).
7. **Widget state creation:** `ui.NewRouter(...)`, `ListState`,
   `ScrollState`, `GridState`, `ui.Handle`, `ui.Selection` must be created
   **once**, with the app state — never inside the view, which runs every
   frame (`ui/views.md:50-58`). Same for bitmaps (`ui.DecodeBitmap`), SVGs
   (`ui.ParseSVG`), fonts (`ui.RegisterFont`) and web views
   (`win.NewWebView`) (`ui/image.md:17-25`, `ui/web-view.md:67-70`).
8. **Duplicate keys under one parent** share state; apps log an inspector
   issue, `ui.Tester` panics where the second key is given
   (`ui/testing.md:24-26`, `ui/inspector.md:81-85`). Keys must be unique
   among siblings; a key names the next outer control and is consumed by it
   (`ui/migration.md:48-59`).

---

## 3. Threading rules

- **The view runs on the main/UI thread** (`docs/app.md:40-47`,
  `ui/views.md:3`). All of MyGo’s public API is callable from any goroutine,
  but calls hop to main and wait — do not block the main thread on work that
  needs the main thread (dialogs, menus, `Menu.Popup`, notifications permission
  prompt).
- **Mutate app state from other goroutines only through `Window.Update`**
  (runs on main, then redraws) or guard it yourself and use
  `Window.Invalidate`/`c.Invalidate` (`ui/views.md:168-184`).
- **Event listeners, menu clicks and global shortcuts run on the main
  thread** — keep them short; start goroutines for I/O (`docs/app.md:44-47`).
- `Services.Invalidate` is the only `Services` method safe from another
  goroutine; clipboard/URL services run on the UI thread
  (`ui/services.go:1-15`, `ui/migration.md:180-185`).
- `Window.Update` and other window methods are safe from any goroutine
  (`docs/windows.md:28-32`).
- **Blocking dialogs** (`mygo.Dialog.*`, file panels) must be called from a
  goroutine when triggered from an event/view; `Parent` gives a sheet on
  macOS (`docs/native.md:7-13`, `docs/ui/overlays.md:99-100`).
- Calls that need the running app **panic before `App.Run`** (clipboard,
  dialogs, notifications, displays, trays, global shortcuts, Dock badge,
  `Theme.IsDark`, `Theme.Preferences`); read only `App.Path`, `App.Locale`,
  `Power.IsOnBattery` etc. before `Run` (`docs/app.md:26-36`).
- `App.Run` must be called from the main goroutine; create windows in
  `WhenReady` or later (`docs/app.md:20-24`).

---

## 4. Build-order / event-order traps

- **Handled input is consumed before rebuilding**, so polling queries
  (`Clicked`, `Changed`, …) are true once per input and callbacks run once
  (`ui/views.md:96-97`, `ui/migration.md:74-80`).
- **Callbacks (`OnClick`, `OnChange`, `OnSubmit`) run after the build and
  after bound input, before the rebuild** — use them when the action mutates
  the collection being built (delete/insert while iterating); otherwise
  polling with `if`/`break` is fine (`ui/views.md:74-97`).
- **Value-bound widgets write through their pointer before the constructor
  returns**; the next statement sees the new value. But `Disabled`,
  `ReadOnly`, `Step`, `Selection`-style options set in this build govern the
  *next* frames’ input (`ui/views.md:99-136`).
- For containers, input is taken when **the builder returns** (a radio
  group’s arrows move among all radios built in that pass) (`ui/views.md:132-136`).
- Configure state before building: `ListState` fields before `Rows`
  (`ui/list.md:81-82`), `SelectBase`/`SegmentedBase` keys via `Context.Key`
  before construction (`ui/custom-widgets.md:28-30`), list handle shortcuts
  may be declared before `Bind` (`ui/migration.md:159-178`).
- A view may run **several passes per frame**; don’t assume side effects in
  the build happen once (`ui/views.md:3-6`; draw functions may be called more
  than once, `ui/drawing.md:35`). Keep the build pure apart from explicit
  user actions.
- Use `c.DisableAnimations()` before building a change that must not animate
  (restoring state, jumping to a result) (`api_gen.go:320-332`).

---

## 5. Focus / keyboard traps

- Tab order follows build order; focusable controls only. A focused
  button/link takes Enter/Space, a toggle/checkbox/switch/radio takes Space —
  plan default-dialog buttons with `c.Shortcut(0, ui.KeyEnter)` instead
  (`ui/input.md:66-70,135-142`).
- Focus requests **wait while the target is hidden**; read actual focus with
  `FocusedValue` when a request is pending (`ui/input.md:72-113`).
- `Handle.Focus()` with no Context **panics if the handle is bound in more
  than one window**; use `Focus(c)`/`CancelFocus(c)` (`ui/ref.go:51-80`,
  `ui/input.md:88-90`).
- `FocusBind` requires a pointer to a comparable field, values unique within
  that field in one window, zero reserved for “no focus”; use separate fields
  per window (`ui/input.md:92-113`, `ui/migration.md:135-157`).
- Focus groups (toolbar/radio/segmented/tabs, `FocusGroup`) are one Tab stop;
  arrows move inside; a slider/text input inside keeps the arrows it takes
  (`ui/input.md:115-133`).
- Text inputs take platform editing keys first; on macOS Ctrl+A/E/B/F/N/P/D/H/K
  and Option/Cmd+arrows are consumed before your shortcuts
  (`ui/input.md:161-165`).
- Shortcuts on non-Latin layouts match physical US keys only with
  Cmd/Ctrl/Alt/Super held (`ui/input.md:156-159`); `ev.PhysicalKey` for
  position-based keys (`ui/input.md:262-266`).
- `Handle.OnShortcut` only fires when the window built an **enabled**
  control for that handle; hidden controls take no command
  (`ui/input.md:176-180`).

---

## 6. Layout/style traps

- **No stylesheets/selectors**: styling is code, rebuilt every frame. Style
  from state (`if row.Hovered() { … }`); `c.SetTheme` applies to the current
  frame, so a custom theme must be set **every frame** (`ui/styling.md:116-141`,
  `ui/context.go:331-339`).
- `Invisible()` vs `Hidden(true)` vs not building: `Hidden` keeps the inner
  state (scroll, editing, animation) but takes no room and is not read by AT;
  not building destroys the state. Choose deliberately
  (`ui/layout.md:124-147`).
- `Clip()` draws the border inside and clips children to the rounded box;
  `Cache()` retains a bitmap — invalidated by size, scale, theme and content
  changes (`ui/style`, `ui/styling.md:67-82`).
- `Attach`/`Absolute` positions are measured from inside the parent’s border;
  automatic margins center between the placed sides; RTL flips logical
  Start/End but **not** physical Left/Right (`ui/layout.md:84-122`,
  `ui/right-to-left.md:96-108`).
- `ui.Spacer` takes free space; `Grow(1)` fills; a list without a size is as
  tall as its rows (surprising in a column — give it `Grow(1)` or a height)
  (`ui/list.md:14-18`).
- `Baseline` alignment uses text lines; images/boxes align by bottom
  (`ui/layout.md:71-82`).
- `Scroll` needs a size or `Grow`; RTL reverses horizontal offset origin
  (`ui/scroll.md:26-32`).
- `Dividers` requires a `Gap` at least as wide as the line or it won’t fit
  (`ui/layout.md:21-26`).
- Draw functions may be called more than once per frame; they must only
  paint, never mutate state (`ui/drawing.md:35-40`).
- Painter coordinates are the element’s **layout** coordinates even under
  transforms; input is *not* transformed by `Painter.Transform` — map
  pointer positions with the inverse (`ui/drawing.md:149-154`,
  `ui/transforms.md:77-93`).
- Text `Shape` caches nothing; cache shaped glyphs yourself if drawn every
  frame (`ui/drawing.md:155-168`).
- Subpixel text antialiasing only over opaque backgrounds; grayscale over
  vibrancy/materials (`ui/windows.md:103-106`).

---

## 7. Widget-specific traps

- **List:** `DragSelect` and `Reorder` are mutually exclusive
  (`ui/list.md:140-149`); changing rows above the viewport keeps place only
  with `Key` (or `KeepOffset` when sorting in place); `Selected` alone never
  right-click-selects (`ui/list.md:84-138`); the focused row stays built when
  scrolled out (good for editing) (`ui/list.md:254-256`).
- **Split:** the divider keeps 40 DIPs from either edge and the first pane
  gives way when the window is too narrow (`ui/split.md`).
- **Segmented/Tabs** need `Context.Key` when built from bases; arrows move
  the choice as one Tab stop (`ui/custom-widgets.md:28-30`).
- **Stepper** repeats while held; **Rating** click on the chosen star clears;
  **RangeSlider** knobs do not cross (`ui/*.md`, one-liners from `llms.txt`).
- **Toasts:** `c.Toast`/`ToastAction`/`AddToast` return/bind IDs; adding an
  existing ID replaces/updates; `Timeout` 0 = 4 s default, <0 = until closed;
  stack shows newest three; Escape closes the focused one
  (`ui/toast.md:34-60`).
- **AlertDialog** returns the clicked button index in the frame it is; Escape
  returns `ui.AlertDismissed`; clicking outside does nothing
  (`ui/alert-dialog.md`).
- **Closing a window from inside the view** ends the frame immediately: open
  the replacement window first, since the app quits when the last window
  closes (`ui/windows.md:144-159`).
- **Popup/dialog/overlay focus:** window shortcuts behind a modal wait; Escape
  closes the topmost; a closing overlay returns focus to where it was
  (`ui/overlays.md:27-43`).
- **Transitions** need a stable ID (Key or sibling position) and animate only
  the element given one; list rows do not slide (list places them)
  (`ui/transitions.md:60-67,167-169`).
- **Animations** need the element to have the same identity across frames;
  `Animate` values are per (element, key) (`ui/motion.md:18-23`).
- **Menus made once** do not reflect state changes — update items with
  `SetChecked/SetLabel/…` or rebuild on locale change
  (`docs/menus.md:88-99`, `docs/i18n.md:170-181`).
- **Images/fonts/SVGs** decoded/registered once, not in the view; call
  `Bitmap.ReleasePixels()` on the main thread to drop CPU copies
  (`ui/image.md:17-43`, `ui/text.md:147-159`).

---

## 8. Accessibility and i18n expectations (not optional)

- Icon-only or drawn controls **must** have `.Label(...)`; custom widgets
  must set `Role`, states (`Checked`, `Expanded`, `Value`, `Range`+`Step`,
  `Level`, `ActiveDescendant`) and be keyboard-operable
  (`ui/accessibility.md:10-75`, `ui/custom-widgets.md:97-104`).
- Animate/announce correctly: `c.Announce` for non-focus-moving outcomes,
  focus moves with dialogs/pages, page titles announced
  (`ui/accessibility.md:96-110`).
- Keep every user-visible string in the catalogs (or a `mygo.<key>`
  override for MyGo’s strings); MyGo’s controls say their own translated
  strings (`docs/i18n.md:340-382`).
- Window titles, own menu labels and anything set once must be refreshed in
  `App.OnLocaleChanged`; views rebuild themselves
  (`docs/i18n.md:154-181`).
- If the app ships ja/zh-Hans/zh-Hant, import MyGo’s `locales/<tag>`
  packages or the catalog loader does it for you; otherwise MyGo’s strings
  fall back to English (`docs/i18n.md:354-382`).
- Design RTL-capable layout from the start (logical padding/alignment;
  `Direction` for exceptions) and test with `MYGO_DIRECTION=rtl` or the
  `en-XA`/`ar-XB` pseudo locales (`ui/right-to-left.md:110-135`,
  `docs/i18n.md:427-441`).

---

## 9. Performance limits and how to stay under them

- Frame budget: **8.3 ms at 120 Hz, 16.7 ms at 60 Hz** (inspector compares
  against the display interval; `ui/inspector.md:73-79`).
- Measured on M5/macOS/CPU renderer: 1,000 labels 397 µs/frame with **0
  allocations**; visible rows of a **million-row list 14.5 µs/frame**;
  50 KB Markdown 1.3 ms/frame; a warmed 1,000-label view retains ~2.5 MB Go
  heap (`ui/performance.md:8-37`). Allocation counts are the portable metric.
- Virtualize: `List`/`Table`/`Outline`/`GridView` build only what is in view
  (`ui/list.md:3-9`, etc.); never render 10k widgets in a scroll view.
- Prefer **repaint-only** motion (`AnimatePose`, `Draw`+`p.AnimationFrame`)
  over view-rebuilding animation for large/static trees
  (`ui/motion.md:67-97`, `ui/drawing.md:210-232`).
- `Cache()` expensive static subtrees; `Cache` is invalidated by content,
  size, scale and theme changes (`ui/styling.md:67-82`).
- Keep the view allocation-light where possible; idle windows draw nothing
  and free the frame buffer after ~2 s (`ui/rendering.md:41-43`).
- Linux CPU fallback is real (VMs/WSL): ~1 ms/frame for a large window, but
  effects/blur (glass) cost much more on CPU
  (`ui/rendering.md:11-21`, `docs/plugins/glass.md:190-203`).
- Use `MYGO_FRAME_STATS=1` while developing; watch build passes, layout,
  text layouts and allocations (`ui/rendering.md:23-39`).
- Windows CPU WARP fallback and Linux Mesa (~50 MB) memory are platform
  costs to expect (`ui/rendering.md:1-21`).

---

## 10. Browsers / WebAssembly caveats (only if you ship the web demo)

`ui/browsers.md` (`mygo dev -web`, `mygo build -platform web`,
`GOOS=js GOARCH=wasm`):

- **No accessibility**, no application/Dock menus, trays, notifications,
  global shortcuts, file dialogs, non-file drag data; `Dialog.Message` uses
  `alert`/`confirm`; clipboard limited to text the app copied (mostly).
- `⌘` is treated as Control for view shortcuts on a Mac browser; font list
  unavailable; some OpenType features not applied (only `kern`).
- File drops have no real paths (backend paths like `/mygo-drop/3/x`).
- First router follows the URL fragment; frame in another page leaves
  history alone.
- Sizes: counter 8.2 MB wasm (2.2 MB gzip), docs previews 9.8 MB (2.6 MB);
  `mygo_noinspector` saves ~350 KB more.
- Keep desktop-only code behind `//go:build !js`; `Protocol.Handle` etc. are
  not in browser builds (`ui/browsers.md:117-123`).

---

## 11. Version / API-drift notes

- Checkout is `b553a90`, `mygo.Version = "0.7.1"` (`mygo.go:70`), matching
  the docs site footer (v0.7.1). The clone is shallow (1 commit, no tags), so
  the recon’s “main is a few commits ahead of tag v0.7.1” cannot be verified
  here; **no docs↔source drift was found** in the areas checked (all `ui.*`
  identifiers used in docs samples exist; all 102 top-level `ui` constructors
  and 29 `Context` methods are mentioned in the docs).
- `mygo vet` and `mygo migrate-ui` are real, documented in the UI guides
  (`ui/views.md:191-195`, `ui/migration.md:7-27`) but **missing from
  `docs/cli.md`** — use them anyway.
- `ui/plugins/glass.md` refers to the same Liquid Glass material as
  “macOS 26” and “macOS 27” in different sections — treat macOS-version
  claims in docs as approximate; feature-detect via `c.Vibrancy()` and the
  glass plugin (which works everywhere) instead of OS version checks.
- `ui.Tester` is in the same module (no build tag) and runs headless; keep
  view tests so API changes surface early.

---

## 12. Environment-specific notes for this workspace (from recon)

- Local Go is 1.26.4 but `GOTOOLCHAIN=auto` fetches 1.27.x; the module
  requires **go 1.27.3** (`go.mod:3`). Bun 1.3.14 present (not needed for
  native UI).
- `mygo` CLI not installed; use `go tool mygo …` in the project (or
  `go run github.com/egoist/mygo/cmd/mygo@latest`).
- macOS 27.0.1, Apple M5 Pro, Metal; Xcode 27.1 available (needed only for
  macOS icon/notarization work). Docker present, no lima/multipass/qemu → no
  local Windows/Linux GUI runtime: validate other OSes via cross-build +
  CI/manual machines.
- `GOPROXY=https://goproxy.cn,direct` is set; first `go tool mygo`/module
  download may fetch the pinned tool.
- Write scope: only `research/docs/**`; `reference/mygo` is read-only.
