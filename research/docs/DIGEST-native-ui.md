# Digest — MyGo native UI (`package ui`) for the MyGo Explorer showcase

Purpose: everything a future implementer needs to build a **multi-screen,
themed gallery app** of every MyGo UI element/control with `package ui`,
without re-reading the 85 `docs/ui/*.md` pages. Synthesized from the repo
Markdown at `reference/mygo/docs/**` (read-only checkout `b553a90`, version
0.7.1) and verified against `reference/mygo/ui/*.go` where marked.

Conventions used here:

- `ui/foo.md:12` = `reference/mygo/docs/ui/foo.md`, line 12.
- `ui/foo.go:12` = `reference/mygo/ui/foo.go` (source), line 12.
- `api_gen.go:N` = `reference/mygo/ui/api_gen.go` (generated public API with
  doc comments; every public widget constructor has its godoc there).
- “The published page” is `https://mygo.egoist.dev/docs/ui/<name>.md`; all
  pages are published (see `INDEX.md`).
- Exact commands are in `GOTCHAS.md`; cross-OS behaviour in
  `PLATFORM-DIFFERENCES.md`; known traps in `GOTCHAS.md`.

---

## 1. The programming model

A window showing native UI is created with `WindowOptions.Content`, a
`*ui.Content` made by `ui.View(view)` where
`view func(c *ui.Context)` (`ui/README.md:33-47`, `api_gen.go:2549`):

```go
type counter struct{ n int }

func (app *counter) view(c *ui.Context) {
    ui.Column(c).Fill().Center().Gap(12).Children(func() {
        ui.Text(c, fmt.Sprint(app.n)).FontSize(40).Bold()
        if ui.PrimaryButton(c, "Increment").Clicked() {
            app.n++
        }
    })
}

mygo.App.WhenReady(func() {
    mygo.NewWindow(mygo.WindowOptions{
        Title: "Counter", Width: 320, Height: 240,
        Content: ui.View(app.view),
    })
})
```

- **The view is a function of state.** MyGo calls it on the UI (main) thread
  to build frames after input, after model changes and while something
  animates; *a frame can contain several build passes*, so it can show the
  outcome of an action before painting (`ui/views.md:3-6`).
- **View = immediate mode with checked values.** Widgets are constructor
  calls that return an `ui.Element`; fluent methods configure it; child
  builders are `func()` closures sharing the same `*ui.Context` (`ui/views.md:8-16`).
  This is *not* retained-mode: nothing survives except what you keep in your
  own state (`ListState`, `ScrollState`, `Router`, `ui.Handle`, plain
  values); a widget builds its view from state every pass.
- **One stable `*ui.Context` per window.** Child builders temporarily switch
  its current parent. Pass it to helper methods; **never store it** in
  fields/globals/goroutines (`ui/views.md:8-10`; `ui/frame.go:10-15`; checked
  by `mygo vet`, `ui/migration.md:180-192`).
- **`Content` is not a window.** `ui.View(app.view)` can serve several
  windows, each with its own element state (`ui/views.md:50-51`).
- **One app can mix windows of both kinds** (native UI and web pages)
  (`ui/README.md:61-65`); a native-UI window has `Page() == nil` and ignores
  `URL`/`Page` (`ui/windows.md:1-8`).
- **There is no HTML/CSS/JS and no webview** for native UI; a native-UI-only
  app needs GTK 3 alone on Linux and no WebView2 on Windows
  (`ui/README.md:1-7`, `ui/windows.md:161-164`, `docs/README.md:178-185`).

### 1.1 Frames, build passes, repaint

- A frame = build (run view, possibly several passes) → layout → paint →
  present; the inspector’s Performance tab shows these against the display
  refresh (8.3 ms at 120 Hz, 16.7 ms at 60 Hz) (`ui/inspector.md:73-79`).
- MyGo draws **only when something changes** (input, `Invalidate`, `After`,
  an animation); an idle window draws nothing and frees its in-memory frame
  two seconds after its last frame (`ui/rendering.md:41-43`).
- Handled input is consumed before rebuilding, so an action runs once for
  that input; changed state rebuilds before painting (`ui/views.md:96-97`).
- A view that moves only in `Draw` can ask for repaint-only frames:
  `p.AnimationFrame()`, `p.AnimationFrameRate(fps)`, `p.After(d)`; those
  frames re-paint the last layout without re-running the view
  (`ui/drawing.md:210-247`). While the window is hidden/occluded/minimized
  no frames are drawn (`ui/drawing.md:213-223`).

### 1.2 When state changes

| Where the change comes from | What to call |
|---|---|
| Inside the view, from user input / animation | mutate state directly; MyGo rebuilds |
| Another goroutine (I/O, timers, workers) | `Window.Update(func(){ ... })` — runs on main thread then draws (`ui/views.md:168-180`); `Window.Invalidate()` only redraws |
| Inside the view, ask for another frame | `c.Invalidate()`, `c.After(d)` (`ui/views.md:182-184`) |
| From a callback after build (clipboard/URL) | `Services.Invalidate()`, safe from any goroutine (`Services` doc, `ui/migration.md:180-185`) |
| Change that must not animate | `c.DisableAnimations()` before building what changes (`api_gen.go:320-332`) |

---

## 2. Elements, keys, handles, local state (the lifetime rules)

**This is the #1 correctness area.** Read `ui/views.md:8-20,150-166`,
`ui/input.md:1-13`, `ui/migration.md:29-133`.

- `ui.Element` is a **16-byte checked handle** (owner + arena slot +
  generation) to a private pooled node; the zero value is “absent”
  (`ui/frame.go:58-67`). It is valid **only for the build pass that created
  it** (`ui/element.go:253-260`) and expires *before the next pass, even in
  the same frame* (`ui/migration.md:41-46`).
- Stale use: development builds (and `ui.Tester`) **panic** with
  `ui: element from pass N used in pass M; keep a ui.Handle instead`
  (`ui/frame.go:104-107`, `ui/handles_debug.go:5`); production builds built
  with `mygo build` (tag `mygo_noinspector`) return empty results or ignore
  the mutation (`ui/handles_release.go:5`, `ui/migration.md:41-46`).
  `Valid()` never panics; use it for optional controls; use `ui.Element{}`
  for absence, not `nil` (`ui/migration.md:29-39`).
- **Never keep** `ui.Element`, `ui.Context`, or parts values (`SelectParts`,
  `TabsParts`, …) in app state, package vars, struct fields or goroutines.
  `mygo vet` (type-aware) flags these (`ui/views.md:191-195`,
  `ui/migration.md:187-192`). Store data, `ui.Handle`, `ui.Services`, and
  widget states (`ListState`, `ScrollState`, `GridState`, `Router`) instead.
- **`ui.Handle`** identifies a control across builds (`ui/ref.go:3-8`,
  `ui/migration.md:97-133`). `Bind(&app.handle)` on each build;
  `.Focus()`/`.CancelFocus()`, `Focused(c)`, `FocusWithin(c)`,
  `c.Resolve(handle)`, `Bounds(c)`, `Shortcut(c, mods, key)`; requests wait
  while the control is hidden; one handle may bind in several windows
  (queries take that window’s Context). `ui.Ref` is an alias of `ui.Handle`.
- **Keys** give stateful controls a stable identity across rebuilds:
  `ui.TextInput(c.Key("search"), &app.query)`, `ui.Checkbox(c.Key(todo.ID), …)`.
  Keys are unique among siblings; comparable Go values compare normally
  (pointer = identity); uncomparable values compare by their printed value.
  `Context.Key` is for stateful widgets/custom bases; `Element.Key` keys a
  container before its children are built (`ui/views.md:150-166`,
  `ui/migration.md:48-59`). Duplicate keys under one parent share one state:
  apps log the issue, `Tester` panics (`ui/testing.md:24-26`).
- **`ui.Local(e, key, init)`** keeps state of your own for a widget between
  builds (spreadsheet “Spoiler” example) (`ui/custom-widgets.md:72-95`);
  `SetChanged()` on an element makes `Changed()` true for custom widgets
  (`ui/custom-widgets.md:93-95`).
- **Focus bound to data**: `FocusBind(&app.pane, files)` + `FocusedValue(c,
  &app.pane)`; the field holds the desired focus and user focus updates it
  when no request is pending; zero = none; use one field per window
  (`ui/input.md:92-113`, `ui/migration.md:135-157`).
- **Lists/tables**: configure `ListState` before `Rows`; `state.Handle` gives
  persistent focus/commands; `ItemKey`, `Selection`, `Reorder` etc.
  (`ui/list.md:52-82,222-255`).

---

## 3. Events: polling vs callbacks (input model)

Widgets report what the user did **since the last frame**, as you build them
(`ui/input.md:1-3`). Full model in `ui/views.md:60-147`, `ui/input.md`.

| Style | API | When to use |
|---|---|---|
| Poll inside the view | `Clicked()`, `DoubleClicked()`, `RightClicked()`, `Hovered()`, `Pressed()`, `Dragged()`, `DroppedFiles()`, `Changed()`, `Submitted()`, `Selected()`, `Dismissed()`, … | inline `if`/`break`/`continue` logic; reading bound values immediately |
| Callbacks after construction | `OnClick(fn)`, `OnChange(fn)`, `OnSubmit(fn)`, `OnShortcut`, `SetChanged` | actions that modify the collection being built, or need the whole frame built |
| Bound values | value-pointer widgets (`*bool`, `*string`, `*float64`, `*int`, `*T`, `*time.Time`, `*[]string`) | no handler needed; the widget writes the edit **through the pointer before its constructor returns** |

Rules that matter:

- Actions run **after configuration and bound input, before rebuilding**
  (`ui/migration.md:74-80`); handled input is consumed so it doesn’t repeat.
- Input follows the options of the frame the user acted on: `Disabled`,
  `ReadOnly`, `Step` set in this build govern the next frames’ input
  (`ui/views.md:132-136`).
- Local copies work: `viewed := app.viewed[id]; if ui.Checkbox(c,
  &viewed, "Viewed").Changed() { app.viewed[id] = viewed }`
  (`ui/views.md:112-130`). Same for map reads and derived segmented values
  (`ui/migration.md:82-95`).
- For a click inside a clickable row/button, the innermost control takes it
  (`ui/input.md:35-43`). `RowDoubleClicked` reports a double-click without
  stealing the row’s choice (`ui/list.md:161-174`).
- `ClickModifiers()` gives the modifiers of the last click; `c.Modifiers()`
  gives the ones held now (updates as they change) (`ui/input.md:28-31`).
- Keyboard: a focused button/link takes Enter+Space; checkbox/switch/toggle/
  radio take Space (`ui/input.md:66-70`). A focused button keeps Enter/Space
  so `c.Shortcut(0, ui.KeyEnter)` can be a dialog default button
  (`ui/input.md:139-142`).
- Handled input is consumed before rebuilding; forwarded input (`HandleInput`
  returning false) continues to shortcuts, Tab, context menus and scroll
  containers (`ui/input.md:262-266`).

---

## 4. `ui.Context` and `ui.Services` — the per-frame API surface

`Context` is the view’s only ambient object. All methods, verified in
`ui/api_gen.go:244-611`, `ui/frame.go:29-54`, `ui/context.go:331-462`:

| Group | Methods |
|---|---|
| Identity/state | `Valid()`, `Key(key)`, `Resolve(Handle) Element`, `Focused(Handle)`, `FocusWithin(Handle)`, `Root() Element` |
| Theme/appearance | `Theme() *Theme`, `SetTheme(t)`, `Preferences() Preferences`, `Direction() Direction` |
| Language/formats | `Locale() string`, `Region() string` |
| Layout/window | `Size() (w,h float32)`, `TitleBar() TitleBar{Height,Left,Right}`, `Vibrancy() bool`, `Zoom()`, `SetZoom(z)`, `Modifiers()`, `Now() time.Time` |
| Frames | `Invalidate()`, `After(d)`, `AnimationFrame()`, `DisableAnimations()`, `MeasureText(font Font, s string) (w,h)` |
| Input/commands | `Shortcut(mods, key) bool`, `OnShortcut(mods, key, fn)` |
| Navigation | `Router() *Router` |
| Clipboard/URL | `ReadClipboard()`, `WriteClipboard(s)`, `OpenURL(url)`, `OpenURLThen(url, func(error))` |
| Overlays/toasts | `Toast(msg)`, `ToastAction(msg, label, fn)`, `AddToast(ui.Toast) ID`, `CloseToast(id)`, `Announce(text)` |

`Services` (`c.Services()`) is **persistent**, owns no frame data and does
not retain the window (`ui/services.go:1-15`): `Invalidate()` (any
goroutine), `ReadClipboard/WriteClipboard`, `ReadClipboardData(formats...)`,
`ClipboardFormats()`, `WriteClipboardData(data)`, `OpenURL(url)`,
`SafeToOpen(url)`. Clipboard/URL methods run on the UI thread; publish model
results with `Window.Update` (`ui/migration.md:180-185`).

Theme note: `SetTheme` applies to **the current frame** and widgets built
after the call (`ui/context.go:331-339`) — a custom theme must be set on
every frame from state. `Preferences()` is read once and refreshed on change
(`ui/preferences.go:39-80`).

---

## 5. Layout (flexbox + grid, DIPs)

Full guide `ui/layout.md`; grid `ui/grid.md`. All lengths are
device-independent pixels (DIPs).

**Containers**: `ui.Box`/`ui.Column` (top→bottom, stretch width), `ui.Row`
(left→right, center vertically), `Reverse`, `ui.Spacer` (takes free space),
`ui.Divider`/`Dividers(width,color)` (lines between children; give a `Gap` at
least as wide), `ui.Grid`, scroll views, `ui.List`, `ui.Split`.

**Sizing**: `Width/Height/Size`, `WidthPercent/HeightPercent`,
`Min/MaxWidth/Height` (+ `…Percent`), `Fill/FillWidth/FillHeight`, `Grow(1)`
(≡ `flex:1`), `Shrink`, `Basis`, `BasisPercent`, `AspectRatio`.

**Spacing**: `Gap`, `GapX/GapY`, `Padding`/`Margin` (1, 2 or 4 values as in
CSS), `PaddingX/Y`, `MarginX/Y`; `ui.Auto` margin takes free space
(`Margin(0, ui.Auto)` centers). Logical variants `PaddingStart/End`,
`MarginStart/End`, `BorderStartWidth/EndWidth` follow RTL.

**Alignment**: `Justify(Start|Center|End|SpaceBetween|SpaceAround|SpaceEvenly)`,
`AlignItems(Start|Center|End|Stretch|Baseline)`, `AlignSelf`, `Center()`,
`Wrap`, `WrapReverse`, `AlignContent`; `Baseline` aligns the first line of
text (price + unit example, `ui/layout.md:71-82`).

**Positioning**: `Absolute()` + `Top/Right/Bottom/Left` (+ `…Percent`,
`Start/End` logical) measured from inside the parent’s border, padding
ignored; on in-flow elements `Top/Left/…` move it like CSS relative
positioning. `Attach(at, self)` places a point of the element on a point of
the parent (`ui.AnchorTopRight`, `ui.AnchorCenter`, `ui.AnchorTopEnd`, …), so
badges sit on avatars at any size (`ui/layout.md:84-122`).

**Clipping/visibility**: `Clip()`, `ClipX/ClipY`; `Invisible()` keeps room but
draws nothing and takes no pointer/focus; `Hidden(true)` removes it from
layout but **keeps its state** (scroll offset, editing text, animation) for
when it returns — unlike not building it (`ui/layout.md:124-147`); `Debug`
outlines the box model.

**Grid** (`ui/grid.md`): columns/rows filling row by row; `Columns(n)`,
`ColumnTracks(ui.Fixed(220), ui.Fr(1), ui.FitContent())`, `ColumnSpan`,
`ColumnStart`; `GridRows`/`RowTracks`/`RowSpan`/`RowStart`; `JustifyItems`,
`JustifySelf`.

**Scroll** (`ui/scroll.md`): `ui.Scroll` (vertical), `ui.ScrollHorizontal`,
`ui.ScrollBoth`; wheel/touchpad/scrollbar/keyboard; wheel notches glide,
touchpad follows fingers, `ReduceMotion` disables glide. State:
`ui.ScrollState` with `TrackScroll(&state)` (`X`,`Y`,`MaxX`,`MaxY`;
`math.MaxFloat32` = end), `ScrollTo(x,y, animation)`, `Scrolling()`;
`Element.ScrollIntoView()`, `ScrollbarInsets(...)` for toolbars floating
over content; scrollbar width/color from theme; RTL puts the vertical bar on
the left and counts X from the right.

**Split** (`ui/split.md`): `ui.Split(size *float32, first, second)`,
`SplitVertical`, `SplitPercent`, `SplitVerticalPercent`; draggable divider
(40 DIP min, arrows when focused).

**Keyboard focus traversal**: `Focusable()`, Tab/Shift+Tab, `AutoFocus`,
`Focus()`, `FocusVisible`, `FocusWithin`, focus ring; focus groups for
toolbar/radio/segmented/tab controls (`ui/input.md:62-133`).

---

## 6. Text

Full guide `ui/text.md`.

- `ui.Text(c, s)`, `ui.Textf(c, format, args...)`; wraps at available width.
- Style methods (set on text or any ancestor; inherited): `FontSize`,
  `FontWeight`, `Bold`, `Italic`, `Font`, `LineHeight`, `FixedLineHeight`,
  `TextColor`, `TextAlign`, `Underline`, `WavyUnderline`, `Strikethrough`,
  `DecorationColor`, `DecorationThickness`, `TextBackground`,
  `LetterSpacing`, `FontFeatures` (`"tnum"`, `"liga=0"`), `Lang`.
- Truncation: `SingleLine` (ellipsis), `MaxLines`, `Ellipsis("…")`,
  `NoWrap`.
- **Selectable text**: `Selectable()` on an element shares one selection
  across its `Text`/`RichText` descendants (copy, Shift-selection, Select
  All, `SelectionColor`, `CopyData`, `SelectedTexts`, `Unselectable`); a
  virtualized list only selects what it built — use a scroll view for a whole
  document (`ui/text.md:36-75`).
- **Rich text**: `ui.RichText(c, spans ...ui.Span)` with per-span font/size/
  weight/italic/color/underline/strike/background/letter spacing/features/
  `ObjectWidth|ObjectHeight|ObjectDescent` + `DrawObjects` for inline objects
  (formulas); `Radius` rounds a span background to hug glyphs
  (`ui/text.md:77-121`). Inline elements: `Text`, `Link`, `RichText` built in
  a text’s `Children` continue the paragraph, keep `Clicked/Hovered/focus/
  Tooltip/ContextMenu` (`ui/text.md:122-145`).
- **Fonts**: system text engine (Core Text / DirectWrite / Pango) and system
  font by default; `Font("monospace")`, `Font("Inter, Noto Sans JP")`;
  `ui.RegisterFont(data, family)` (go:embed); `ui.FontFamilies()` →
  `[]ui.FontFamily{Name, Monospaced, Registered}`; `Font.Metrics()`,
  `ui.Shape(s, font) []Glyph`, `Painter.Glyphs` for widget-drawn text
  (`ui/text.md:147-196`, `ui/drawing.md:155-179`). Default theme font size is
  **13 on macOS, 14 elsewhere** (`ui/theme.go:98-103`); docs do not state this
  (see `DOC-GAPS.md`).
- Text shaping is cached for elements; `Shape` itself caches nothing — keep
  glyphs of text drawn every frame (`ui/drawing.md:155-168`).

---

## 7. Styling and theming

Full guide `ui/styling.md` (read it once before building the gallery).

### 7.1 Box styling (on any element)

`Background(c)`, `Gradient(from,to,angle)`, `LinearGradient{Stops,Start,End,
Oklab}`, `ConicGradient`, `Border(width,color)`, `BorderWidth(…4)`,
`BorderColor`, `BorderStyle(ui.BorderDashed)`, `BorderLinearGradient`,
`BorderConicGradient`, `Radius`, `Shadow(x,y,blur,spread,color)` (stackable),
`InsetShadow(…)`, `Stripes(width,gap,angle)`, `Opacity`, `Blur(sigma)`
(GPU bitmap), `Cache()` (retained GPU bitmap for static subtrees),
`Material(m)` (glass plugin), `Cursor(shape)` (many platform shapes),
`Debug`, `Grayscale`/`Effect` for shaders.

- **No stylesheets/selectors**: state-driven styles in the view, e.g.
  `if row.Hovered() { row.Background(t.SurfaceHover) }`; one element’s state
  can style another (`ui/styling.md:116-126`).
- **Colors**: `ui.RGB`, `ui.RGBA`, `ui.Hex`, `ui.Oklch(l,c,h)` (+`.Alpha`),
  `Mix`, `Alpha`, `ui.Transparent`; Oklch wide-gamut colors draw wide on P3
  screens, fall back to sRGB elsewhere (`ui/styling.md:99-114`).
- Borders/corners: border-box sizing; macOS corners are continuous (AppKit/
  SwiftUI style), elsewhere circular (`ui/styling.md:12-17`,
  `ui/paint.go:53`).

### 7.2 Theme (`ui.Theme`, source `ui/theme.go:1-160`)

Fields: `Dark`, `Background`, `Surface/SurfaceHover/SurfacePressed`,
`Border`, `Text/TextMuted`, `Accent/AccentHover/AccentPressed/AccentText`,
`Danger`, `Warning`, `Success`, `Selection`, `Focus`, `Inverse/InverseText`
(tooltips/toasts), `Scrollbar`, `ScrollbarWidth` (default 6),
`Radius` (default 6), `Spacing` (default 4; unit of paddings/gaps/control
sizes — 3 compact, 5 roomy), `FontSize`, `Font`; helpers `t.Space(n)`,
`t.Rem(n)`.

- Defaults: `ui.LightTheme()` (`#ffffff` background, `#f4f4f5` surface,
  `#18181b` text, accent `#2563eb`…) and `ui.DarkTheme()` (`#18181b`,
  `#27272a`, accent `#3b82f6`…) (`ui/theme.go:105-153`).
- **Follow the desktop by default**: the frame’s theme is
  Light/Dark per system appearance, then `.follow(preferences)` applies the
  user’s accent (recomputing hover/pressed/selection/focus; `AccentText`
  turns dark on light accents), high-contrast adjustments (darker borders/
  muted text, opaque focus ring) and `TextScale` × `FontSize`
  (`ui/preferences.go:6-37,39-80`, `ui/runtime.go:506-525`;
  docs summary `ui/styling.md:128-178`).
- Change a copy and set it **every frame**: `t := *c.Theme(); t.Accent =
  ui.Hex("#7c3aed"); t.Radius = 8; t.Spacing = 3; c.SetTheme(&t)`
  (`ui/styling.md:130-141`).
- `c.Preferences()`: `Accent`, `HighContrast`, `TextScale`, `ReduceMotion`
  (`ui/styling.md:163-178`, `docs/native.md:284-324` for the platform
  sources).
- Tooltips/toasts use `Inverse`/`InverseText` (`ui/styling.md:154-161`).
- A frame follows changes of appearance/accent/contrast/text scale/motion
  without app code; tests simulate them with `tt.SetDark`,
  `tt.SetPreferences` (`ui/testing.md:41-47`).

---

## 8. Input: pointer, keyboard, focus, shortcuts, IME, drops

Full guide `ui/input.md`.

- Pointer queries: `Hovered`, `Pressed` (held inside), `Clicked` (activation
  on release/keyboard/AT), `DoubleClicked`, `RightClicked`, `Dragged`
  (distance since last frame while pressing), `PointerPosition`,
  `ClickModifiers`, `PassThrough`; innermost element under the pointer wins
  (`ui/input.md:24-61`).
- `HandleInput(func(ui.InputEvent) bool)` gets raw events before the next
  frame: `ui.InputKeyDown/KeyUp/Text/Scroll/Zoom/Select`, `ev.Key`,
  `ev.PhysicalKey`, `ev.Mods`, `ev.Text`, `ev.X/Y`, `DX/DY`, `Precise`,
  `Scale`; return false to let the event continue. `TextCaret(rect)`,
  `InputMethod(bool)` enable/disable IME for such elements
  (`ui/input.md:210-299`).
- Text inputs handle IME composition, the platform’s editing keys (macOS:
  Option/Cmd-arrows, Ctrl-A/E/B/F/N/P/D/H/K; elsewhere Alt+arrows go
  back/forward), undo/clipboard/selection (`ui/input.md:161-188`).
- Shortcuts: `c.Shortcut(ui.Cmd, ui.KeyS)` (window-wide, after focused
  element), `Element.Shortcut` (focus subtree), `Handle.OnShortcut` (needs
  built enabled control), `c.OnShortcut(...)`; `ui.Cmd` = ⌘ on macOS, Ctrl
  elsewhere; physical-key matching works on non-Latin layouts (Cmd+ы ==
  Cmd+S); `ui.KeyBack/KeyForward`; menu accelerators still work, and Edit
  menu roles (cut/copy/paste/select-all/undo/redo) act on focused text
  (`ui/input.md:135-180`; menus `docs/menus.md:374-403`).
- Focus system: `Focusable`, `AutoFocus`, `Focus`, `Focused`,
  `FocusVisible`, `FocusWithin`, `FocusRing(false)`, persistent
  `Handle`/`Bind`/`FocusBind`, `FocusGroup(ui.Horizontal|Vertical|Both)`
  (arrow-key group as one Tab stop) (`ui/input.md:62-133`).
- Dropped files: `DroppedFiles() []string`, `FileDragOver()`, window
  `OnFileDrop`; window accepts files only over such elements unless it has
  window-level listeners (`ui/input.md:189-208`).
- Drag and drop of values/data: `Drag(value)`, `Drop[T](e)`, `DragOver[T](e)`,
  `DragData/DragDataFrom`, `DroppedFiles`; native formats per platform
  (`ui/drag-and-drop.md:1-128,173-187`; `docs/data-transfer.md`).

---

## 9. Overlays, dialogs, popovers, toasts, tooltips, menus

Guide `ui/overlays.md`; each page. Shared semantics: overlays are above
content; Escape closes the top one unless the focused element takes it;
focus returns to the element that had it; a press outside a popover closes
it **and goes through** to what is under the pointer; dialog backdrop
consumes the press; window shortcuts outside a modal wait
(`ui/overlays.md:27-43`).

| API | Page | Notes |
|---|---|---|
| `ui.Modal(c, &open, func(){...}) Element` | `ui/dialog.md` | dialog over dimmed window; click outside or Escape sets `*open=false`; `Dismissed()` |
| `ui.AlertDialog(c, &open, title, message, buttons...) int` | `ui/alert-dialog.md` | AppKit-style alert; last button = default (accent, focused, Enter); Escape = `ui.AlertDismissed`; click outside does nothing; returns clicked index |
| `ui.Popover(c, anchor, &open, fn)` | `ui/popover.md` | panel below anchor, flips above if no room, follows scroll; press outside closes and passes through |
| `ui.Tooltip(e, fn)` / `TooltipBase` | `ui/tooltip.md` | on hover or keyboard focus; also the element’s accessible description |
| `c.Toast(msg)`, `c.ToastAction(msg,label,fn)`, `c.AddToast(ui.Toast{...})`, `c.CloseToast(id)` | `ui/toast.md` | bottom of window; `Timeout` 0 → 4 s, < 0 → until closed; stack of 3 (newest first); timer pauses on hover/focus/background; Inverse colors; `ToastViewportBase` for a custom look |
| `ui.ContextMenu(build func(*mygo.Menu))` on any element; `MenuButton`; `Menu` items | `ui/context-menu.md`, `ui/menu-button.md`, `docs/menus.md` | native system menus; items built when menu opens; `Chosen()` reports selection next frame |
| `ui.Overlay(c, fn)` | `ui/overlays.md:45-97` | top layer, placed `Absolute` in window DIPs; `AttachTo`, `PressedOutside`, `OverlayShortcut`, `Modal` for your own overlays (drawers, hover cards) |

Overlay layers: popovers/selects/dialogs/toasts stack; a select’s popup
comes before the dialog it is in; Escape closes topmost
(`ui/overlays.md:35-38`). Tooltips/toasts announce to screen readers
(`ui/accessibility.md:96-110`).

---

## 10. Navigation (multi-screen gallery structure)

Guide `ui/navigation.md`.

- `ui.NewRouter("/") *Router` in app state; `router.View(c, func(r *ui.Route))`
  with `r.Match("/pattern/{id}")` / `{path...}`, `r.Param("id")`,
  `r.Title(...)`; pages are matched by a `switch` (`ui/navigation.md:12-51`).
- `Push`, `Replace`, `Back`, `Forward`, `Go`, `Path()`, `Query()`,
  `Location()`; relative paths resolve like links; `ui.Link(c, "Open",
  "/notes/42")` pushes in its router; deep links call `Push`
  (`ui/navigation.md:54-80`).
- Back/forward by keys & mouse buttons: ⌘[ / ⌘] on macOS, Alt+←/→ elsewhere,
  touchpad swipe on macOS, `ui.BackButton`/`ui.ForwardButton(c, router)`
  (right-click lists history); first router in a window takes the keys
  (`ui/navigation.md:82-99`).
- **Layouts**: build anything around `router.View` (sidebar, toolbar) and it
  stays across pages; a page can nest `r.View` for sub-pages (settings
  example) (`ui/navigation.md:101-130`).
- **Pages keep state** in history (ten pages each way), including scroll,
  text and focus; a different query is a new history entry of the same page
  (`ui/navigation.md:132-138`).
- Focus/screen-reader behavior moves focus into the new page, or keeps it in
  the sidebar and announces the page title (`ui/navigation.md:140-146`).
- Transitions: deeper paths slide in from the right, others fade; reduced
  motion fades; `router.Transition = ui.TransitionNone`;
  `router.Animation = &ui.Snappy` (`ui/navigation.md:148-162`).
- Navigation widgets: `ui.Tabs(c, &i, labels...)`, `ui.Sidebar(c, &id, fn)`
  with `SidebarItem`/`SidebarSection`, `ui.Breadcrumbs(c, items, &i)`,
  `BackButton`/`ForwardButton`.
- Browser (wasm) runs the first router on the URL fragment `#/notes/42`
  (`ui/navigation.md:93-99`, `ui/browsers.md:79-82`).

---

## 11. Accessibility (required for a showcase app)

Guide `ui/accessibility.md`. AT (VoiceOver/Orca/Narrator/NVDA) reads native
UI like any app and can operate widgets.

- **Names**: widgets have theirs; text inside names it; non-text needs
  `.Label("…")` (also used to find elements in tests)
  (`ui/accessibility.md:10-22`). `ui.Field` labels its control
  (`ui/form.md`).
- **Roles**: automatic from behavior; override with `.Role(ui.RoleX)`;
  `RoleNone` leaves an element out but not children; extra roles
  `RoleHeading` (+`Level`), `RoleMenu`, `RoleMenuBar`, `RoleMenuItem`,
  `RoleMenuItemCheckBox`, `RoleMenuItemRadio`, `RoleDialog`, `RoleSwitch`
  (`ui/accessibility.md:24-44`).
- **States**: `Checked(on)`/`Mixed()`, `Expanded(open)`, `Value(s)`,
  `Range(lo,hi,value)`+`Step`, `Level(n)`, `ActiveDescendant(e)`; plus
  `Description`, `Error` (`ui/accessibility.md:46-75`).
- **Formats**: rich text editor reports bold/italic/links/headings; text
  fields expose the Text pattern (UI Automation) etc.
- **Lists/tables**: rows announce “5 of 10,000” and scroll into view when AT
  moves out of view (`ui/accessibility.md:86-94`).
- **Announcements**: `c.Announce(text)` for news that doesn’t move focus
  (search done, file saved); toasts announce themselves; router announces
  page titles (`ui/accessibility.md:96-110`).
- Frames are described only once AT asked — apps pay nothing otherwise
  (`ui/accessibility.md:112-113`).
- Every component page ends with what AT sees of it; use that checklist when
  building gallery screens.

---

## 12. i18n, regional formats, RTL

Root guide `docs/i18n.md` (native-UI-specific parts cited), RTL page
`ui/right-to-left.md`.

- **Catalogs**: `mygo.json`/`mygo.config.ts` → `i18n: {dir,
  source}`; JSON ARB files `<BCP47>.json`; ICU MessageFormat (plural,
  select, selectordinal, number/date skeletons); `mygo dev|build|generate`
  write `catalog_gen.go` + TS module with a typed function per key
  (`docs/i18n.md:25-152`). Commit generated code
  (`docs/i18n.md:149-152`).
- **Whole app shows one language**: own messages, MyGo’s controls/menus, and
  pages (`docs/i18n.md:6-9`). Native-UI views rebuild every frame so strings
  follow language changes automatically (`docs/i18n.md:154-168`); what the
  app sets once (window title, own menu labels) must be reset in
  `App.OnLocaleChanged` (`docs/i18n.md:170-181`).
- `c.Locale()` / `c.Region()`; `Element.Lang` for per-element language (Han
  glyph variants); date/time/calendar controls follow region formats
  (`docs/i18n.md:229-249`).
- **MyGo’s own strings** come in English + ja/zh-Hans/zh-Hant packages; apps
  that ship those must import `github.com/egoist/mygo/locales/<tag>` unless
  the generated catalog code does it; override with `mygo.<key>` messages
  (`docs/i18n.md:340-382`). An app with English only shows English MyGo
  strings to a Chinese reader, as AppKit does (`docs/i18n.md:187-198`).
- **Regional formatting**: package `i18n` (`FormatNumber`, `FormatDate`,
  `DateOptions{Skeleton:"yMMMd"}`, `FirstWeekday`, `HourCycle`,
  `Region.FormatLocale(language)`, `Autonym`) with CLDR data; no per-locale
  bloat (`docs/i18n.md:250-338`).
- **Trying languages/layouts**: `mygo dev -lang de`, pseudo-locales `en-XA`
  (longer, accented text) and `ar-XB` (RTL), `MYGO_LOCALE`,
  `App.SetLocale`, `App.OnLocaleChanged` (`docs/i18n.md:427-441`,
  `docs/cli.md:124-140,236`).
- **RTL** (`ui/right-to-left.md`): a window takes the app language’s
  direction; everything mirrors as listed (`Row`, `Align*`, `TextAlign`,
  logical padding/margins/anchors, scrolling, sliders/progress, tabs,
  breadcrumbs, split, table columns, popup placement, text input/caret);
  physical things (`Left/Right`, `Padding(top,right,bottom,left)`, radius
  corners, gradient angles, transforms, drawn pixels, icons, text) do not.
  `Element.Direction(ui.LeftToRight)` for exceptions (phone numbers, code,
  media controls). Test with `MYGO_DIRECTION=rtl`, inspector RTL toggle,
  `Tester.SetDirection(ui.RightToLeft)`. The gallery example already shows
  every control RTL (`ui/right-to-left.md:110-135`).

---

## 13. Drawing, animation, motion, transitions, transforms, shaders

### 13.1 Drawing (`Draw`/`DrawOver`)

`Draw(func(p *ui.Painter, r ui.Rect))` paints after the background;
`DrawOver` after children (`ui/drawing.md:1-9`). Painter (DIPs): `Fill`,
`FillGradient`, `FillConicGradient`, `Stroke`, `StrokeDashed`, `Shadow`,
`Line`, `Image`, `ImageRegion`, `Clip`, `FocusRing`, `Transform`,
`MeasureText`, `Text`, `RichText`, `Glyphs`, `Icon`, paths:
`ui.Path` (`MoveTo/LineTo/QuadTo/CubicTo/Close`, `FillPath`, `StrokePath`,
gradient variants, `Trim`, `Cap/Join/Dash`, `Rect`/rounded rects), canvases
(`ui.NewCanvas(w,h)`, render-to-bitmap, reuse via `p.Image(canvas.Bitmap(),
r, ui.FillBox)`), `p.Now()`, `p.AnimationFrame()`,
`p.AnimationFrameRate(fps)`, `p.After(d)`, `p.Scale()`. Draw functions only
paint — MyGo may call them more than once per frame (`ui/drawing.md:35-40`).

### 13.2 Simple animation

- `Element.Animate(key, target, dur)`/`AnimateWith(..., ease)` returns the
  value for this frame and requests frames until it arrives;
  `AnimateColor`; `Loop`; `AnimateTo` (springs too); easings `ui.Linear`,
  `EaseIn`, `EaseOut`, `EaseInOut`, `CubicBezier`, `Bounce`
  (`ui/drawing.md:181-208`).
- Reduced motion: `Animate` jumps to target; `Loop` continues
  (`ui/drawing.md:249-252`).

### 13.3 Motion (`ui/motion.md`)

Springs `ui.Smooth`, `ui.Snappy`, `ui.Bouncy`, `ui.Animation{Spring:
ui.SpringOptions{Duration,Bounce|Stiffness,Damping,Mass}}`, `.Spring(key,
target, opts)`; curves `ui.Animation{Duration, Ease}`; `.Delay` for
staggering; `AnimatePose(ui.Pose{X,Y,Scale,Rotate,Fade}, anim)` — repaint-only
poses (cheapest motion, e.g. hover lift) (`ui/motion.md:24-110`); gestures
`Draggable(&ui.Point, ui.DraggableOptions{Axis,Bounds,Snap,Inertia,...})`
(`ui/motion.md:112-230`); `Keyframes`, `Timeline` (`Placement`:
`WithPrevious`, `AfterPrevious`, `AtTime`, `AtLabel`, `Seek`, `Pause`,
`Repeat`, `Alternate`), `Arrived`, `Settled`, `Velocity`, `Jump`
(`ui/motion.md:249-460`); out-of-sight behavior (`ui/motion.md:460-521`).

### 13.4 Transitions (`ui/transitions.md`)

`ElementTransition{Duration, Ease|Animation, Position, Size, Colors, Enter,
Exit, Match}`; `Transition(...)`; default 200 ms `EaseOut`; `Enter`/`Exit`
take `ui.Motion{X,Y,Opacity,Scale,Rotate,TransformOrigin,Collapse}`;
`Match` shares identity across parents (photo thumbnail ↔ detail);
`Transitioning()`; rows of a `List` don’t slide (list places them); reduced
motion: colors still animate, fades in place, collapses instant.

### 13.5 Transforms (`ui/transforms.md`)

`Translate`, `Scale`, `Rotate`, `Skew`, `RotateX/RotateY`, `Perspective`,
`Transform(ui.Transform)`, `TransformOrigin`, `BackfaceHidden`; layout
reserves original space; pointer/hit-testing/IME/AT follow; `Bounds()`
(previous frame, transformed), `LayoutBounds()`, `LocalToWindow`,
`WindowToLocal`; `Draw` gets untransformed coordinates; transforms are
appended in call order, parent after child.

### 13.6 Shaders (`ui/shaders.md`)

Package `ui/shader` compiles shaders written in Go syntax; draws on whatever
renderer (Metal, D3D11, OpenGL, WebGL2) or CPU with same pixels; used with
`Effect`/`Draw`; images/uniforms; `plugins/glass` is built on it.

---

## 14. Images, SVG, icons, bitmaps

- `ui.Image(c, src ui.ImageSource)` — bitmap or SVG in its own colors;
  `Fit(ui.Contain|Cover|FillBox)`, `Size`, `Radius`, `Pixelated`,
  `Grayscale` (`ui/image.md`).
- Bitmaps: `ui.DecodeBitmap(data)` (PNG/JPEG/GIF first frame/WebP/BMP, EXIF
  upright; keeps data for re-decode), `ui.NewBitmap(image.Image)`, `Update`,
  `ReleasePixels()`, `Pixelated`; make bitmaps **once**, not in the view
  (`ui/image.md:17-69`).
- SVG: `ui.ParseSVG(data)`/`ui.MustParseSVG`, `ui.Icon(c, svg)` — tinted in
  the text color, height = font size, keeps aspect; works with Lucide/
  Heroicons/Tabler/Material Symbols. `Painter.Icon(p, svg, rect)`.
- `ui.Avatar(c, name, *Bitmap)` — image cropped round or initials on a
  name-derived color; ~2.2× font size.

---

## 15. Widget catalogue (showcase checklist)

Constructors verified in `api_gen.go:632-2574`. “Page” = docs page under
`docs/ui/`. All are `func (c *ui.Context, ...) ui.Element` unless noted.
Events listed are the main polling queries; every widget also supports the
generic pointer/focus/style methods from §2/§7.

### Containers & layout

| API | Page | Notes |
|---|---|---|
| `Box`, `Column`, `Row`, `Spacer`, `Divider` | `layout.md` | flexbox |
| `Grid` | `grid.md` | `Columns`, tracks, spans |
| `Scroll`, `ScrollHorizontal`, `ScrollBoth` | `scroll.md` | + `TrackScroll(*ScrollState)` |
| `Split`, `SplitPercent`, `SplitVertical`, `SplitVerticalPercent` | `split.md` | draggable divider |
| `Collapsible(label, *bool, fn)`, `Accordion(fn)`, `AccordionItem(title, *bool, fn)` | `collapsible.md`, `accordion.md` | disclosure / sections; `Changed()` |
| `Form(fn)`, `Field(label, fn)`, `Fieldset(legend, fn)` | `form.md` | labels for AT + click-to-focus, `Description`, `Error` |
| `Overlay(fn)` | `overlays.md` | top layer |
| `Tabs(&int, labels...)`, `TabsBase` | `tabs.md` | keyboard arrows, `Changed` |
| `Sidebar(&string, fn)`, `SidebarItem(id, *SVG, label)`, `SidebarSection(title, *bool, fn)` | `sidebar.md` | source list with sections |
| `Breadcrumbs(items []string, *int)` | `breadcrumbs.md` | `Changed` |
| `Toolbar(fn)` | `toolbar.md` | hover-less controls, `ui.Spacer`, overflow into menu |

### Actions

| API | Page | Notes |
|---|---|---|
| `Button(label)`, `PrimaryButton(label)` | `button.md` | `Clicked` |
| `ButtonBase()` | `button.md#without-a-look` | headless |
| `Link(label, url)` | `link.md` | opens browser/app scheme; router pages |
| `MenuButton(label, build func(*mygo.Menu))` | `menu-button.md` | `Chosen()` |
| `Toggle(*bool, label)`, `ToggleGroup(fn)`, `ToggleBase` | `toggle.md` | pressed state |
| `Segmented(&int, labels...)`, `SegmentedBase` | `segmented.md` | `Changed` |
| `ContextMenu(build)` (element method) | `context-menu.md` | native menu |
| `BackButton(*Router)`, `ForwardButton(*Router)` | `history-buttons.md` | disabled at ends |

### Choices

| API | Page | Notes |
|---|---|---|
| `Checkbox(*bool, label)`, `CheckboxBase`, `CheckboxGroup(label, fn)` | `checkbox.md` | `Changed` |
| `Switch(*bool)`, `SwitchBase` | `switch.md` | immediate settings |
| `Radio(&T, value T, label)`, `RadioBase`, `RadioGroup(fn)` | `radio.md` | any comparable type |
| `Select(&string, options []string)`, `SelectBase[T]` | `select.md` | native popup; `Changed` |
| `Combobox(&string, options)`, `ComboboxBase` | `combobox.md` | typed filter |
| `Slider(*float64, lo, hi)`, `SliderBase`, `StepSlider(...,step)` | `slider.md` | arrows/Page/Home/End |
| `RangeSlider(*lo, *hi, lo, hi, step)` | `range-slider.md` | two knobs, no crossing |
| `Stepper(*float64, lo, hi, step)` | `stepper.md` | hold repeats |
| `Rating(*int, max)` | `rating.md` | stars, click chosen star clears |
| `Autocomplete(&string, suggestions)` | `autocomplete.md` | Enter/Up/Down |
| `TokenField(*[]string, suggestions)` | `token-field.md` | chips, Enter/comma adds |

### Text input & editing

| API | Page | Notes |
|---|---|---|
| `TextInput(*string)`, `TextArea(*string)`, `TextInputBase`, `TextAreaBase`, `TextInputBuffer`, `TextAreaBuffer` (+Base) | `text-input.md`, `text-input-client.md` | `Changed`, `Submitted`, `Placeholder`, `ReadOnly`, `Password`, `Selectable`, ranges, `OnPaste` |
| `NumberInput(*float64, lo, hi, step)` | `number-input.md` | clamps while typing |
| `SearchField(*string)` | `search-field.md` | Escape clears |
| `EditableText(*string)` | `editable-text.md` | double-click/Enter to edit |
| `FindBar(*bool, *query, matches int, *current)` | `find-bar.md` | prev/next/Done |
| `ui/editor` package (`editor.New`, `editor.Buffer`, `editor.View`, `editor.DiffView`) | `code-editor.md`, `diff-viewer.md` | Zed-like; million-line files |
| `ui/richtext` package (`richtext.NewDocument`, `richtext.Editor`) | `rich-text-editor.md` | attributed text, Format menu roles |
| `ui/markdown` package | `markdown.md` | CommonMark+GFM, streaming friendly |

### Dates, colors

| API | Page | Notes |
|---|---|---|
| `Calendar(*time.Time)` | `calendar.md` | month; arrows/Page keys |
| `DateInput(*time.Time)` | `date-input.md` | region numeric format + calendar popup |
| `TimeInput(*time.Time)` | `time-input.md` | region hour cycle, AM/PM |
| `ColorWell(*ui.Color)`, `ColorPicker(*ui.Color)` | `color-picker.md` | swatch + picker |

### Collections

| API | Page | Notes |
|---|---|---|
| `List(c, *ListState|null, n, rows...)` / `.Rows(func(ui.ListRow))` | `list.md` | virtualized; selection, reorder, drag-select, sticky headers, `FollowEnd` |
| `Table(c, *ListState, columns []TableColumn, n, cell)` | `table.md` | sortable/resizable/reorderable columns, cell selection |
| `Tree(fn)`, `TreeItem(label, *bool, children fn)` | `tree.md` | |
| `Outline(c, *OutlineState[K], roots, children, row)`, `OutlineTable(...)` | `outline.md` | virtualized tree/list/table |
| `GridView(c, *GridState, n, minWidth, height, item)` | `grid-view.md` | virtualized photo grid |

### Dialogs, status, images

| API | Page | Notes |
|---|---|---|
| `Modal`, `AlertDialog`, `Popover`, `Tooltip`, `c.Toast*`, `ToastBase`, `ToastViewportBase` | §9 above | |
| `Progress(value float64)`, `Spinner()`, `Meter(value, lo, hi, *MeterLevels)`, `Badge(text)` | `progress.md`, `spinner.md`, `meter.md`, `badge.md` | |
| `Image`, `Icon`, `Avatar` | §14 | |
| `Text`, `Textf`, `RichText`, `Link` | §6 | |
| `ui.WebView(c, *mygo.WebView)` (window made with `win.NewWebView`) | `web-view.md` | mixed native+web window (optional demo) |
| `ui/chart` package: `chart.Plot`, `Rect`, `Line`, `Area`, `Pie`, `NewLinear/NewBand/NewTime`, marks, selection | `chart.md` | optional demo |
| `plugins/loading` (29 indicators), `plugins/glass` (`glass.Glass{}`, `glass.ScrollEdge{}`, `glass.Blur{}`), `plugins/game`, `plugins/terminal` | `docs/plugins/*.md` | optional screens |

**Nothing else is exposed**: the public element/Context surface is
`api_gen.go` (245 `Element` methods, 29 `Context` methods; plus
frame.go/ref.go/services.go). Use `go doc -all github.com/egoist/mygo/ui`
for the definitive signatures.

---

## 16. Testing with `ui.Tester` (no window)

Guide `ui/testing.md`. `ui.NewTester(view, width, height) *ui.Tester` renders
frames in memory as fast as a unit test.

- Find by text or by `.Label(...)`: `tt.Click("Increment")`,
  `tt.Find("Volume")`, `tt.Focused("Name")`, `tt.Texts()`,
  `tt.HasText("1")`.
- Pointer: `Click`, `ClickAt`, `ClickWith(ui.Shift,"Row 3")`, `Press`,
  `Move`, `Release`, `Scroll` (touchpad), `Wheel` (notch, glides as clock
  advances).
- Keyboard: `Key(ui.Cmd, ui.KeyS)`, `TypeKey`, `Type`, `Compose` (IME),
  `Command("copy")`, `TextCaret`.
- Menus: `RightClick`, `Menu()`, `ChooseMenuItem("Move to","Archive")`.
- Window/desktop: `SetSize`, `SetScale`, `SetZoom`, `SetDark`,
  `SetPreferences`, `SetDirection(ui.RightToLeft)`, `SetFocused`,
  `SetTitleBar(TitleBar{...})`.
- Output: `Find` (box), `Focused`, `Cursor`, `Clipboard`, `OpenedURLs`,
  `Announcements`, `FailOpenURL`; frames: `Frame`, `Image()` (RGBA,
  snapshots), `FramePending()`; `ui.Render(view,w,h,scale) *image.RGBA`.
- **Deterministic clock**: `tt.Now()` stands still; `tt.Advance(d)` runs the
  frames due (animations, `c.After`, double-click interval, caret blink,
  tooltips/toasts). Never sleep in tests; advance the clock
  (`ui/testing.md:60-79`). Undo steps of `editor.Buffer`/`richtext.Document`
  use the system clock.
- Duplicate `Key` under a parent panics in a tester (`ui/testing.md:24-26`).
- The `mygo init -template native` project includes a view test; see
  `examples/counter-native` (`ui/README.md:55-58`).

---

## 17. Inspector (development)

`ui/inspector.md`: chrome-devtools-like panel docked right; opens with View →
Toggle Developer Tools / `F12` / ⌘⌥I (Windows/Linux Ctrl+Shift+I), picker
⇧⌘C; tree with keys/labels, styles/computed/properties tabs, box-model
highlight, accessibility info, frame timings against the refresh interval,
and **Issues** (duplicate keys etc.). Content gets a narrower window
(`c.Size()`). Dev tools on in development builds; `WindowOptions.Page.
DevTools` to disable; production `mygo build` omits the inspector (~250 KB),
`-debug`/`MYGO_INSPECTOR=1` keep it; `go build` keeps it unless
`-tags mygo_noinspector`. Toolbar RTL toggle flips layout.

---

## 18. Rendering & performance (what the app must respect)

- Renderers: Metal (macOS), Direct3D 11 + WARP fallback (Windows), OpenGL
  3.3/ES 3.0 in GtkGLArea (Linux), WebGL 2 (browsers); where OpenGL cannot
  run on a GPU, Linux falls back to a cairo CPU renderer (~1 ms for a large
  window, ~0.1 ms for typical repaints; Mesa/OpenGL costs ~50 MB RAM on
  first native-UI window). `MYGO_GPU=0` forces CPU everywhere;
  `MYGO_GPU=1` forces OpenGL on Linux (`ui/rendering.md:1-21`).
- Frames draw only on change; ~120 Hz ProMotion supported; macOS keeps 3
  frames for animation (~4 B/pixel extra until idle) (`ui/rendering.md:41-48`).
- `MYGO_FRAME_STATS=1` (or `=ms`/`all`) logs slow frames with build/layout/
  paint/present breakdown, pass count, allocations, text layouts, GC
  (`ui/rendering.md:23-39`).
- Measured costs (M5, macOS, CPU renderer, `CGO_ENABLED=0
  GOMAXPROCS=1`): 1,000 static labels 397 µs/frame 0 allocs; visible rows of
  a **million-row list 14.5 µs/frame**; 50 KB Markdown 1.3 ms; retained
  ~2.50 MB Go heap for a warmed 1,000-label view (`ui/performance.md:8-37`).
  Allocations are more stable than timings.
- Gallery implications: use `List`/`Table`/`Outline`/`GridView` for long
  collections (virtualized), `Cache()` for expensive static subtrees,
  `AnimatePose` for repaint-only motion, and only request repaint frames
  from `Draw` for things that move without rebuilding the view.

---

## 19. Browsers (optional: run the same app in a page)

`ui/browsers.md`: `mygo dev -web` (localhost:5174), `mygo build -platform
web`; `GOOS=js GOARCH=wasm`. Works: drawing (WebGL2, CPU fallback), text
(browser fonts), pointer/wheel/keyboard/IME/clipboard text, first router on
`#/fragment`, file drops, HTML context menus, dark mode/reduced motion,
`data-mygo-theme`. **Does not**: accessibility, application menus, trays,
notifications, global shortcuts, file dialogs, non-file drag data, some
OpenType features; `⌘` is Control for the view on a Mac browser; binary
size 8.2 MB wasm (2.2 MB gzip) for the counter, 9.8 MB (2.6 MB) for docs
previews (`ui/browsers.md:63-123`). Useful as a screenshot/demo channel but
not a substitute for desktop testing.

---

## 20. Blueprint for the MyGo Explorer app (recommended structure)

App shell (files suggested, all pure Go, no frontend):

```
main.go            mygo.App.WhenReady + NewWindow(Content: ui.View(app.view))
state.go           app struct: theme seed, router, sidebar id, per-screen state
shell.go           sidebar + toolbar + router pages + menu/tray/commands
screens/*.go       one screen per component group (button, choices, text,
                   collections, overlays, navigation, drawing, motion,
                   system/appearance, widgets-from-other-packages)
```

Suggested shell and screens (this also gives the user the OS-comparison
they want): a `ui.Sidebar` of component groups, `router.View` for screens,
a `Toolbar` with: theme (light/dark/system), accent color override, spacing
(3/4/5), text scale simulation, RTL toggle, reduce-motion toggle, window
chrome demo (hidden title bar / frameless / vibrancy), and a "Platforms"
screen that shows the same controls plus a table of OS facts from
`PLATFORM-DIFFERENCES.md`.

Key recipes (all documented in the pages cited):

1. **Live theme switching** (state → applied every frame):
   `t := *c.Theme(); if app.dark { if !t.Dark { t = *ui.DarkTheme() } } else {
   t = *ui.LightTheme() }; t.Accent = app.accent; t.Radius = app.radius;
   t.Spacing = app.spacing; c.SetTheme(&t)` — the default theme already
   follows the OS; only override what the demo changes
   (`ui/styling.md:128-161`, `ui/context.go:331-339`).
2. **Per-screen router** with layout sidebar staying put
   (`ui/navigation.md:29-51,101-130`).
3. **Menu bar** with roles (`RoleAppMenu`, `RoleEditMenu`, `RoleWindowMenu`)
   and demo commands with accelerators (`docs/menus.md:6-86`); on
   Linux/Windows each window owns its bar, so `Window.SetMenu` for
   per-window demos (`docs/menus.md:160-176`).
4. **Overlays demo**: one screen each for `Modal`, `AlertDialog`, `Popover`,
   `Tooltip`, `c.Toast`/`ToastAction`, `ContextMenu`, and a custom
   `Overlay` drawer (`ui/overlays.md:45-97`).
5. **Window-chrome demo**: `TitleBarHidden` + `c.TitleBar()` + `DragWindow`
   in one window; a `Frameless` + `CornerRadius` + `VibrancyGlassClear` HUD
   window (`ui/windows.md:20-42,79-142`, `docs/windows.md:51-66`).
6. **Cross-OS comparison**: run the same binary on each OS; the app itself
   needs no platform code (compilation is enough). Add a "System" screen
   showing `c.Preferences()` values and live `c.Locale()`/`c.Region()`
   (`ui/styling.md:163-178`, `docs/i18n.md:229-249`).
7. **Tests**: one `ui.Tester` per screen for smoke tests and snapshots
   (`tt.Image()`), deterministic clock (`ui/testing.md`).

---

## 21. Source citations worth keeping open

| Claim | Source |
|---|---|
| Element is a checked 16-byte handle, expires per pass | `ui/frame.go:58-67,104-118`, `ui/element.go:253-260` |
| Dev panic vs production empty result | `ui/handles_debug.go:1-6`, `ui/handles_release.go:1-6`, `ui/migration.md:41-46` |
| Stable Context / no storing | `ui/frame.go:7-15`, `ui/views.md:8-16` |
| Handle semantics & per-window bindings | `ui/ref.go:1-80`, `ui/migration.md:97-133` |
| Theme defaults, font size per OS, preferences derivation | `ui/theme.go:1-160`, `ui/preferences.go:1-80`, `ui/runtime.go:499-525` |
| `SetTheme` per frame | `ui/context.go:331-339` |
| `ui.Cmd` per OS | `ui/keys.go:105-116` |
| List keyboard conventions per OS | `ui/list.go:1150-1175` |
| Router back/forward keys per OS | `ui/router.go:589-592` |
| Text input context menu per OS | `ui/menu.go:525-539` |
| Continuous macOS corners | `ui/paint.go:45-54` |
| 245 Element methods / 29 Context methods | `api_gen.go` (`grep '^func (_handle'`) |
| Widget constructor godocs | `api_gen.go:632-2574` |
