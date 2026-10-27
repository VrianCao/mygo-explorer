# Examples & reference-implementation analysis (Lead)

Purpose: what already exists in the MyGo repo that the future **MyGo Explorer**
app should learn from, reuse, or surpass. Source: `reference/mygo/examples/`
and `reference/mygo/website/docs-demo/` (read-only checkout, main @ b553a90).

## 1. The two existing "galleries" (the bar to beat)

### `examples/gallery` — the official tour (2,646 lines across 5 files)
A single native-UI window with a 13-page router, sidebar, toolbar, breadcrumbs,
back/forward, Cmd+1…9 shortcuts, browser-style zoom (0.5×–3×), RTL toggle and a
language menu. Pages: Overview, Controls, Text, Rich Text, List, Charts,
Markdown, Styling, Drawing, Glass, Overlays, Motion, Languages
(`examples/gallery/main.go:282`). Highlights:

- App state is one `gallery` struct with ~100 fields; `view` is
  `func (g *gallery) view(c *ui.Context)`; shell = `Row(Sidebar + Column(Toolbar + Router.View(Scroll(page))))`
  (`main.go:337-423`).
- `ui.Sidebar` sections with icons (`pageIcons`), `ui.SidebarItem`, `ui.Badge`,
  `ui.Breadcrumbs`, `ui.BackButton`/`ForwardButton`, `ui.Toolbar`, `ui.Toggle`
  (`main.go:423-508`).
- 10,000-row virtualized `List` with context menus, a chat list of mixed row
  heights, a table with sorting, a tree/outline, a grid-view of swatches,
  drag-reorder tasks.
- Charts (`charts.go`, 323 lines), Markdown (`markdown.go`), rich text
  (`richtext.go`), `plugins/glass` page, custom `Draw` painter, animation
  pages, overlays (dialog/alert/popover/toast/tooltip/context menu/find bar).
- Tests without a window (`main_test.go`, 161 lines): `ui.NewTester`,
  click-by-text, keyboard, router/back/forward, filtered list selection,
  i18n/region formats (`tt.SetRegion`, `tt.SetLocale`). **This is the testing
  model to copy at scale.**
- It is a *tour*, not a reference: it does not systematically show every
  variant/state/prop, has no code snippets, no appearance lab, no
  per-platform comparison, and several API surfaces are absent (see §3).

### `website/docs-demo` — the docs' live component previews (2,717 lines)
A Go native-UI app compiled to **WebAssembly** and embedded per docs page
(`website/docs-demo.ts`; page comment `<!-- preview name height -->`). It is
the closest thing to a component catalog:

- Registry: `demo(name, view)` in `main.go:22-38`, keyed by docs page name;
  **64 demos** covering actions, choices, collections, containers, dates,
  dialogs, drag/drop, markdown, motion, navigation, status, text input,
  charts, code, rich text (`grep 'demo("' website/docs-demo/*.go`).
- An index mode lists every demo in a sidebar and shows it centered
  (`main.go:62-98`) — exactly the "catalog browser" shape we want, but it has
  no metadata, variants, code, or platform information.
- Demo functions close over local state, keep a one-line `status(c, …)` result
  line, and are intentionally tiny (`actions.go`, `choices.go`, …).
- The same Go app runs on the desktop: `go run ./website/docs-demo [name]`.
- Build: `GOOS=js GOARCH=wasm go build` (see `docs/ui/browsers.md`); docs site
  also embeds two full examples (`mayoi`, `loading`) as wasm frames.

## 2. Other examples worth reusing (patterns, not code to copy wholesale)

| Example | Lines | What to reuse in MyGo Explorer |
|---|---|---|
| `counter-native` | 91 | Minimal native-UI skeleton + `ui.NewTester` test (`main_test.go`); the `main.go` shape (`App.WhenReady`, `NewWindow{Content: ui.View}`) |
| `native` | 208 | Menu bar roles, tray, dialogs, notifications, global shortcuts, `mygo.Theme.SetSource`, display info — for a "Desktop integration" screen; note this one is a web-frontend app, APIs are the same from native UI |
| `vibrancy` | ~450 | Sidebar over `Vibrancy`, hidden/inset title bar, `c.TitleBar()`, `DragWindow`, traffic-light inset, material picker (7 window + 7 transient + 3 Win11 + 2 glass materials) — for a "Window chrome & materials" screen |
| `loading` | 101 | Variant-matrix pattern for a whole plugin: `loading.All()` (29 indicators) rendered in cards with options (size/color/easing/cap/pause) — copy this layout for control galleries |
| `code-editor` | 337 | `ui/editor` code editor + diff viewer, completions, hovers, diagnostics, inline diffs |
| `text-input` / `text-buffer` | ~150 / ~large | Custom text field from primitives; large-document text buffers — for "text stack" explanations |
| `markdown-chat` | 184 | `ui/markdown` stream vs view, follow-tail list |
| `notes` | 341 | `ui/richtext` editor with toolbar + Format menu + Markdown shortcuts |
| `chat-glow`, `wind`, `blackhole`, `confetti`, `effort-slider`, `timeline` | 800–1300 each | Motion/shader/effect showcases (`ui/shader`, `ui.Timeline`, transforms, glass) — source material for an "Effects" section |
| `embed-webview` | 172 | Mixing web pages into a native-UI window (`ui.WebView`), overlay controls over the page |
| `launcher`, `menubar-native`, `menubar-flyout`, `flyout` | 148–426 | Panels/flyouts/menu-bar apps, global shortcut, frameless/HUD windows |
| `documents`, `drag-drop`, `clipboard` | 87–130 | Documents/`NewDocuments`, drag data between apps, `transfer` formats |
| `piano`, `terminal`, `farm`, `mayoi` | 600–2400 | Audio, terminal plugin, game plugin — out of scope for a UI catalog but useful as "what else MyGo can do" links |

`examples/gallery` itself compiles to WebAssembly (`mygo build -platform web`),
so the same showcase code can ship native and browser builds — the docs demo
proves this path (`docs/ui/browsers.md`).

## 3. Coverage gaps found so far (to confirm against ui-cataloger's inventory)

The gallery covers a lot but **not everything**, and it does not teach:

- Widgets/areas with no (or little) gallery presence: `ui.WebView`, `ui.Image`,
  `ui.Avatar`, `ui.Calendar`, `ui.DateInput`/`TimeInput`, `ui.ColorPicker`/
  `ColorWell`, `ui.Autocomplete`, `ui.TokenField`, `ui.FindBar`, `ui.Form`/
  `Field`/`Fieldset`, `ui.DiffViewer`, `ui.CodeEditor` (in a separate example),
  `ui.Markdown` (covered), `ui.Accordion`/`Collapsible` (partly), `ui.Meter`,
  `ui.Progress` (status), `ui.Outline` (partly), `ui.Split`, `ui.Stepper`,
  `ui.Table` (covered), `ui.Tree` (partly), `ui.Toolbar` overflow,
  `ui.Segmented`, `ui.Select`/`Combobox` (partly), `ui.SearchField`,
  `ui.Toggle`/`ToggleGroup`, `ui.Tooltip`/`Popover` (partly), `ui.Toast`,
  `ui.Dialog` variants, `ui.HistoryButtons`, `ui.Breadcrumbs` (covered),
  `ui.Rating`, `ui.RangeSlider`, `ui.Slider` (partly), `ui.NumberInput`.
- Cross-cutting behavior no example documents: disabled/readonly/error/loading
  states; keyboard navigation per control; focus rings; accessibility names/
  roles/announcements; RTL per control; i18n/regional formats; light/dark/
  accent variants; text scale/zoom.
- Platform story: no example shows *what differs on macOS vs Windows vs
  Linux* (window chrome, menus, tray, vibrancy/glass availability, fonts,
  shortcuts) and no example produces a per-platform screenshot matrix.
- Developer-facing story: `ui.Tester`, the native inspector, frame stats
  (`MYGO_FRAME_STATS`), rendering fallbacks (`MYGO_GPU=0`), wasm build — all
  documented but not showcased in one place.

## 4. Design implications for MyGo Explorer

1. **Registry-driven catalog, not hand-written pages.** Use a
   `map[string]Component` (or a slice of sections) with metadata: id, title,
   category, docs page, constructor, variants, props, states, demo builder,
   code snippet, platform notes. Generate sidebar/navigation from it. This is
   the docs-demo pattern (`demo()`) extended with metadata and code.
2. **Shell:** router + sidebar (sections: Foundations, Layout, Text, Actions,
   Inputs, Selection, Navigation, Overlays, Collections, Data display, Charts,
   Editors, Media, Motion/Effects, Platform & Desktop, Accessibility & i18n,
   Tooling), toolbar with breadcrumbs/history, theme + appearance controls,
   search (Cmd+K), zoom, RTL toggle.
3. **Per-component page template:** title + docs link + live demo + "Variants"
   row + "States" row (default/hover/pressed/focus/disabled/readonly/error) +
   "Props/methods" table generated from the inventory + code snippet (the
   snippet should be the actual demo source kept in sync) + "Platform notes"
   + "Try it" controls.
4. **Appearance Lab (in-app):** toggle light/dark, accent presets vs
   `c.Preferences().Accent`, Spacing (3/4/5), FontSize/TextScale, Radius,
   direction (LTR/RTL), locale + region formats, zoom, and `SetTheme`.
   `ui.Theme` is a plain struct and `c.SetTheme(*Theme)` exists
   (`ui/theme.go`, `ui/context.go:330-337`), so live switching is cheap.
5. **Real per-platform evidence:** `ui.Render` (`ui/api_gen.go:1637`) and
   `ui.Tester.Image()` (`ui/headless.go:457`) render frames in memory
   (headless, deterministic, any OS/CI), and `Window.CapturePage()`
   (`window.go:1409`) captures a real native-UI window. Use both: a
   `--capture` mode for real screenshots on each OS, and `go test` golden
   images via `ui.Render` for CI on macOS/Windows/Linux runners.
6. **Documentation pairing:** embed code snippets and behavior notes next to
   live widgets; the future app can also show the native inspector
   (`docs/ui/inspector.md`) and frame timing, making it a teaching tool.
7. **Ship both forms:** native `.app`/`.exe`/binary + `-platform web` static
   site (wasm), so anyone can compare in a browser. Note browser caveats
   (no menus/tray/notifications/global shortcuts/a11y in wasm; native fonts
   differ — `docs/ui/browsers.md`).

## 5. Notes / risks

- The gallery and docs-demo are both single-window apps with global mutable
  state; our catalog should still favor a registry + per-screen state structs
  so tests and screenshots are deterministic.
- Reusing gallery code is fine (MIT), but the shell must be extended: search,
  appearance lab, code panel, screenshot/export, platform matrix, and
  metadata-driven props tables.
- docs-demo names map 1:1 to docs pages; keep that mapping so "Open docs"
  always works and documentation gaps are visible.
- Examples use `plugins/glass`, `ui/chart`, `ui/editor`, `ui/markdown`,
  `ui/richtext`, `ui/shader`, `plugins/loading` — these are separate packages
  and must be added to `go.mod`; check `go.mod`/module dependencies when
  building (the base module is `github.com/egoist/mygo`).
