# MyGo Explorer — proposed screen map & app spec

Target: a **native-UI MyGo app** (`mygo.NewWindow(mygo.WindowOptions{Content: ui.View(app.view)})`) that shows every inventory item (`inventory.json`, 158 items), every meaningful variant/state, and how each looks/behaves **on macOS, Windows and Linux**. This file is written so the app can be implemented directly from it; item ids match `inventory.json` / `INVENTORY.md`.

## 0. App shell (build this first)

**Window**: one main window, `Width: 1180, Height: 760`, `MinWidth: 900`, `StateKey: "explorer"`, `TitleBarStyle: mygo.TitleBarHidden` + drawn toolbar via `c.TitleBar()`/`DragWindow()` (shows off the chrome itself; on Linux/Windows the same view picks its controls from `c.TitleBar()`). `Content: ui.View(app.view)`. Optional second real window is opened from the Desktop screen (tray/flyout/dialogs demos).

**Layout**: `Row` → `Sidebar(width 240, selected *string)` built from `SidebarSection`/`SidebarItem(icon, label)` + content `Column(Grow(1), MinWidth(0))` → `Toolbar` (BackButton/ForwardButton from `ui.Router`, Breadcrumbs, Spacer, quick actions) → `Router.View` → per-screen `Scroll` page (`Padding 16, 32; Gap 18`).

**Router** (`ui.NewRouter("/overview")`, `r.Title(...)` per page, paths kebab-case):
`/overview`, `/foundations`, `/layout`, `/actions`, `/text`, `/inputs`, `/selection`, `/sliders`, `/pickers`, `/navigation`, `/overlays`, `/data`, `/charts`, `/editors`, `/markdown-richtext`, `/media`, `/drag-drop`, `/motion`, `/desktop`, `/accessibility`. Detail routes `/data/list/{row}`, `/desktop/window/{demo}`, `/charts/{chart}` demonstrate history/params.

**Global toolbar controls** (appear on every screen; each is a proving ground itself):
- Page switcher: sidebar items with `Badge` counts (e.g. number of variants), sections "Elements", "Content", "Platform".
- History: `BackButton`/`ForwardButton`, `Breadcrumbs` of the route; keyboard Cmd+[ / Alt+Left etc. driven by the router.
- Theme: `Segmented` or `MenuButton` — `System` / `Light` / `Dark`; applies `c.SetTheme(copy)` or lets the default theme follow (`mygo.Theme.Source`). Shows light+dark side-by-side option on Foundations only.
- Accent: shows system accent (`c.Preferences().Accent`), with an override swatch row (demonstrates themes).
- Direction: `Toggle` LTR/RTL (calls `root.Direction(ui.RightToLeft)` — same mechanism as the gallery and docs).
- Locale: `MenuButton` language list (uses `mygo.App.SetLanguages/SetLocale`, `ui.Context.Locale/Region`), re-formats dates/numbers live.
- Zoom: Cmd+= / Cmd+- / Cmd+0 via `c.SetZoom`; shows crisp vector/type at 125%/200% (`c.Zoom()`).
- Platform badge: text `runtime.GOOS` + GPU backend + display scale from `mygo.Screen.PrimaryDisplay()`; a "webview available" dot from `mygo.WebViewAvailable()`.
- State enemy/ally: an **Inspector rail** (right side, collapsible, `Grow(0)`; not the dev inspector) listing the screen's interesting states as `Button`s that force them (e.g. "hover", "pressed", "focus", "disabled", "open", "mixed", "error", "readonly", "loading"). Same rail drives "variant" selection where a screen has many variants.
- `c.Toast("Copied")` feedback for "copy code snippet" buttons. Screen footer shows the doc path + source ref from the inventory.

**Per-screen layout pattern** (consistent, implementable as a helper `demoCard(c, title, body)`): page header (`Text` 26 Bold + one-line purpose + docs/source refs) → 2–4 demo cards, each with a live control + description + "state buttons" row → a `Collapsible` "Variants & states" grid (all variants shown at once, labelled) → a `Collapsible` "Code snippet" (see §0.1) → cross-platform notes text (`Text` muted, `Icon` warning where platform-specific) → optional "API surface" list from inventory `key_methods`/`events`.

**0.1 Code snippet + behavior pairing.** Every demo card carries the exact Go snippet that produced it, stored as a `string` constant beside the view builder. Render with `ui.Text` in a `monospace` font inside a bordered `Column`, with a copy `Button` (`c.WriteClipboard(snippet)` + `c.Toast("Snippet copied")`); a `Toggle` "Show snippet" per page and a global "Show snippets" preference. Recommended pattern: one `demo` struct per showcase:
```go
type demo struct{ id, title, snippet string; build func(*Context) }
```
so the gallery can render variants, the snippet, and the state-rail uniformly; a codegen or hand table can later be split into files if it grows (see "implementation order").

**0.2 Deterministic states.** Do not fake states with styling only: force them with real API where possible (`Disabled(true)`, `ReadOnly(true)`, `Error("…")`, `.Focus()`, `open *bool=true`, `Checked(true)`, `Mixed()`, `Selection`, `Progress(0.4)`), and where the state is pointer-driven (hover/pressed/focus) use a **`Tester`-mode screenshot harness** (`ui.NewTester` + `Move`/`Press`/`Key`, then `Image()`/`Frame()`); details in API-NOTES.md. Keep a per-screen `variant int` + `state int` in app state, exposed by the state rail.

## 1. Overview & Environment — `/overview` — complexity S

Purpose: orientation + honest environment report; prove at a glance "this is running natively on this OS".
- Controls: `ui.View` window card (title bar, `c.Size()`, `c.Theme().Dark`, accent chip), platform card (`runtime.GOOS/GOARCH`, renderer/backend note, display scale from `mygo.Screen.PrimaryDisplay()`), counts from inventory (158 items, 19 categories), "what to try" list, quick `Badge`s for availability (`mygo.WebViewAvailable()`, `mygo.NotificationsSupported()`, vibrancy via `c.Vibrancy()`), buttons to jump to key screens (`Link`/`Button` pushing router), a live spinner/meter/progress trio as first taste.
- Interactions: navigation only; toggle theme/direction/zoom from the toolbar to watch the whole shell react.
- States: light/dark, LTR/RTL; platform-specific truth table.
- Cross-platform: the "availability" card is the single source of truth for what this OS can show (`updater`, `power` events, glass window material, tray, menus, notifications).
- Items: `ui-view-window-content`, `window-new`, `screens`, `theme-appearance`, `progress`, `meter`, `spinner`, `badge`.

## 2. Foundations & Tokens — `/foundations` — complexity M

Purpose: the design-system layer every widget is built from; make theme differences visible side-by-side.
- Controls: color token grid (`Background`, `Surface`, `SurfaceHover`, `SurfacePressed`, `Border`, `Text`, `TextMuted`, `Accent*`, `Danger`, `Warning`, `Success`, `Selection`, `Focus`, `Inverse`, `Scrollbar`) as swatches with hex labels; accent from system (`c.Preferences().Accent`, `HighContrast`, `ReduceMotion`, `TextScale`) + override buttons; typography specimen (all `FontSize` steps, weights, `Italic/Underline/Strikethrough/WavyUnderline`, `LetterSpacing`, `LineHeight`, `TextAlign`, `Font("monospace")`, system `FontFamilies()` list, `RegisterFont` demo); spacing/radius/shadow/blur/opacity tokens via `t.Space(n)`/`t.Rem(n)`; both themes side-by-side (`Row` with two `Column`s, each `SetTheme`? — `c.SetTheme` is per-window; instead render two cards with `t2 := ui.DarkTheme()` explicitly styled tokens, or open a second window); a "theme density" control changing `Spacing` 3/4/5 and `Radius`.
- Interactions: theme buttons, accent override, light/dark compare, zoom; measure text (`c.MeasureText`) readout.
- States: light/dark; high contrast; reduced motion; text scale 1.0/1.25/1.5.
- Cross-platform: default font size 13 on macOS vs 14 elsewhere; macOS continuous corners vs quarter circles; accent can be absent on Linux (draw fallback); high contrast/text scale sources differ per OS (`docs/native.md`).
- Items: `theme-appearance`, `locale-i18n` (formats section), `text` (specimen), `canvas-painter` optional.

## 3. Layout — `/layout` — complexity M

Purpose: teach flexbox+grid with resize and RTL.
- Controls: `Box`, `Column`, `Row` (gap/align/justify/wrap/reverse), `Spacer`, `Divider` (h/v), `Scroll`/`ScrollHorizontal`/`ScrollBoth` (with visible scrollbars, `TrackScroll`, sticky header via `ScrollWith`), `Grid` (fixed/fraction/fit tracks + spans via `Tracks`, `Fixed`, `Fr`, `FitContent`), `Split`/`SplitPercent`/`SplitVertical`/`SplitVerticalPercent` (draggable dividers), `Form`/`Field`/`Fieldset` (label above/beside, errors).
- Interactions: drag split dividers; resize window (MinWidth/percent units); scroll; RTL toggle; zoom.
- States: LTR/RTL, narrow/wide (window resize), scroll positions; disabled fields.
- Cross-platform: none visually; RTL mirroring is shared; scrollbars follow theme width; macOS overlay scrollbars vs Windows/Linux styles only by theme.
- Items: `layout` ids + `form` ids.

## 4. Actions & Buttons — `/actions` — complexity S

Purpose: all clickable actions and their event model.
- Controls: `Button`, `PrimaryButton`, `ButtonBase` (custom-styled button built on the base), `Toggle`/`ToggleBase`/`ToggleGroup` (bold/italic/underline style toolbar group), `MenuButton` with a menu of items/submenu/separators, `Link` (http/https/mailto + router-relative + `SafeToOpen`), `Badge` as attached content.
- Interactions: click counts shown next to each button (`Clicked()`), keyboard Tab/Enter/Space, shortcuts (`.Shortcut`/`OnShortcut`), `OnClick` side effects, disabled reason, focus ring/hover/pressed visuals, `idle`/double-click notes.
- States: default/hover/pressed/focus-visible/disabled; toggle on/off; menu open/chosen.
- Cross-platform: unified look; accent color from OS; Cmd vs Ctrl shortcuts; macOS focus rings vs Windows/Linux drawn focus.
- Items: `button`, `primary-button`, `button-base`, `toggle`, `toggle-base`, `toggle-group`, `menu-button`, `link`, `badge`, `context-menu` (link out).

## 5. Text & Typography — `/text` — complexity M

Purpose: every text capability: styling, wrapping, selection, rich spans, fonts, RTL/CJK/emoji.
- Controls: `Text` matrix (sizes, weights, decorations, colors, alignments, max lines + ellipsis, nowrap/wrap, letter/line spacing), `Textf` formatting (numbers, dates), `RichText` with inline `Span`s and child `Link`/`Text` continuation, selectable text + copy (selection colors, `Selectable`, `TextSelection`, context menu), `Label`/`Description` accessibility demo, `FontFamilies()` list + `RegisterFont` (show a bundled font), `Text` inside `Selectable` container, RTL/`Direction` paragraph, emoji/CJK sample strings, `ShapeText`/`MeasureText` readout.
- Interactions: select/copy, resize to reflow, font picker, weight slider, RTL toggle.
- States: default/hover/pressed/selected/focused; selection; disabled; light/dark.
- Cross-platform: OS text engines (Core Text/DirectWrite/Pango) and system fonts (SF/Segoe UI/Cantarell); fallback & emoji differ; Cmd+C vs Ctrl+C; contextual menus.
- Items: `text`, `textf`, `rich-text`, `link`, `icon`, `canvas-painter` (glyph drawing optional).

## 6. Text Inputs — `/inputs` — complexity M

Purpose: editing controls, keyboard/IME, validation and buffers.
- Controls: `TextInput` (empty/filled/placeholder/password/readonly/disabled/error + `Label`), `TextInputBase` (unstyled custom row), `TextInputBuffer`/`TextInputBufferBase` (indexed `TextBuffer` storage, large doc + selection), `TextArea` (+Base/Buffer) with `Lines` min/max, `Autocomplete` (suggestion list + keyboard), `SearchField`, `TokenField` (tags + suggestions), `NumberInput` (range/step/invalid), `EditableText` (in-place edit of a cell/row), `OnSubmit`/`OnPaste`/`OnTextKey` handlers, clipboard actions (paste/copy as text/HTML), form validation with `Field`/`Form`.
- Interactions: type, paste, select, undo, IME composition (CJK), submit, invalid input, read-only.
- States: default/hover/focused/disabled/readonly/error/placeholder/composition; buffer variants.
- Cross-platform: IME per OS (`NSTextInputClient` vs Windows TSF vs GTK IM); Return-to-submit vs newline; Cmd vs Ctrl editing shortcuts; font/spellchecker differences.
- Items: `text-input*`, `text-area*`, `autocomplete`, `search-field`, `token-field`, `number-input`, `editable-text`, `form`, `field`, `fieldset`.

## 7. Selection Controls — `/selection` — complexity M

Purpose: every choice/state model, themed vs base, keyboard behavior.
- Controls: `Checkbox`/`CheckboxBase`/`CheckboxGroup` (all/some/none + `Mixed`), `Radio`/`RadioBase`/`RadioGroup` (generic `T` e.g. string/int), `Switch`/`SwitchBase`, `Segmented`/`SegmentedBase` (custom track look), `Select`/`SelectBase` (popup, groups, highlighted item), `Combobox`/`ComboboxBase` (filtering options), `Tabs`/`TabsBase` (tab lists).
- Interactions: click/keyboard (Space, arrows, Home/End, type-ahead), disabled, focus ring, mixed state.
- States: checked/unchecked/mixed, selected, open/closed popup, highlighted item, disabled.
- Cross-platform: unified; accent; macOS sidebar-like selection vs elsewhere; keyboard differences in lists (Page Up/Down Linux/Windows).
- Items: `checkbox*`, `radio*`, `switch*`, `segmented*`, `select*`, `combobox*`, `tabs*`.

## 8. Sliders, Steppers & Feedback — `/sliders` — complexity M

Purpose: continuous/numeric input and status displays.
- Controls: `Slider`/`SliderBase` (h/v, custom track), `StepSlider` (discrete + tick labels), `RangeSlider` (min/max), `Stepper` (lo/hi/step), `Rating` (stars), `Progress` (determinate/indeterminate), `Meter` (levels, colored), `Spinner` (sizes/speeds), `loading-spinners` grid (all 29 with Options), plus `Animate`-driven examples.
- Interactions: drag/keyboard (arrows/PageUp/Down/Home/End), range handles, reduce-motion toggle effect on animations.
- States: default/hover/dragging/focused/disabled; min/max; indeterminate.
- Cross-platform: unified; Reduce Motion respected (`ui.Preferences().ReduceMotion`); macOS trackpad vs wheel scrolling.
- Items: `slider*`, `step-slider`, `range-slider`, `stepper`, `rating`, `progress`, `meter`, `spinner`, `loading-spinners`.

## 9. Pickers — `/pickers` — complexity M

Purpose: color/date/time picking across regional formats.
- Controls: `ColorWell` + `ColorPicker` inline (hue slider, saturation/brightness square, hex field, swatches, opacity), `DateInput` + `Calendar` (month grid, today, min/max if supported), `TimeInput` (12/24h per locale), `Field` wrappers, disabled states.
- Interactions: open/select/cancel, keyboard arrows, Escape, region/locale switch (toolbar) to show formatting change.
- States: closed/open; selected; disabled; dark/light.
- Cross-platform: drawn by MyGo (not NSColorPanel) — same look everywhere; date/time order and 12/24h follow OS region; first day of week; RTL.
- Items: `color-picker`, `color-well`, `date-input`, `time-input`, `calendar`.

## 10. Navigation — `/navigation` — complexity M

Purpose: the app's own chrome patterns, with a nested router demo.
- Controls: `Sidebar`/`SidebarSection`/`SidebarItem` (icons, badges, collapsible sections, selection), `Breadcrumbs` (long path ellipsis, chosen index), `BackButton`/`ForwardButton` (disabled at ends, right-click history menu), `Toolbar` (one Tab stop, arrow keys, `Label`), `FindBar` (open/query/matches/current + Cmd+F in demo), `Router`/`Route` (push/replace/mailto links, titles), `Link` for path navigation, `Overlay`-based command palette demo.
- Interactions: navigate/push/back-forward/breadcrumb jump, find bar typing, keyboard shortcuts (Cmd+[ / Alt+Left; mouse side buttons), sidebar keyboard type-ahead.
- States: selected sidebar item, collapsed section, history depth, find open/no-results.
- Cross-platform: macOS Cmd+[ vs Alt+Left on Windows/Linux, trackpad swipe (macOS); window controls in drawn title bar (see Desktop screen).
- Items: `sidebar*`, `breadcrumbs`, `back-button`, `forward-button`, `toolbar`, `find-bar`, `layout` (router page containers).

## 11. Overlays, Dialogs & Toast — `/overlays` — complexity L

Purpose: layered UI, focus/dismiss semantics, the bases vs themed widgets.
- Controls: `Modal` (dim backdrop, focus trap, Escape/outside), `DialogBase` (custom dialog: backdrop+panel), `AlertDialog` (2–3 buttons, returns index, `AlertDismissed`, required-answer loop), `Popover` (below anchor, corner anchors) and `PopoverBase` (custom panel), `Overlay` helper (attach floating elements), `TooltipBase` + `.Tooltip(s)` (above/below, anchored), `ToastBase`/`ToastViewportBase` custom viewport, plus `c.Toast`/`c.ToastAction` (undo pattern), `ContextMenu` (right-click row) and `MenuButton`.
- Interactions: open/close, Escape, click outside, Tab focus trap, Enter default button, toast timers pause on hover/focus, undo action.
- States: closed/open, hover, pressed, focused, dismissed (outside/Escape), required alert.
- Cross-platform: all drawn in-window (unified); native system menus only via `ContextMenu`; `mygo.Dialog` is the native dialog (see Desktop).
- Items: `overlay`, `modal`, `dialog-base`, `alert-dialog`, `popover`, `popover-base`, `tooltip-base`, `toast-base`, `toast-viewport-base`, `context-menu`.

## 12. Data Display — `/data` — complexity L

Purpose: virtualized data surfaces, selection, editing, context menus.
- Controls: `List` variants (10k rows, variable heights/chat, pinned section headers, follow-end, single/multi `Selection`, `ItemKey`, `Label` type-ahead, empty state, `RowWidth` + header `ScrollWith`), `Table` (sortable columns via `SortOrder`, editable cells with `EditableText`, 10k rows, selection), `Tree`/`TreeItem` (expand/collapse levels), `Outline`/`OutlineTable` (file trees, custom rows/cells), `GridView` (photo grid, selection, 10k items), `Collapsible`/`CollapsibleBase` (custom disclosure with `Progress`), `Accordion`/`AccordionItem` (multiple sections, keyboard Up/Down), detail route `/data/list/{row}` for history demo, row `ContextMenu`, `Badge`/`Avatar` in rows, `Focused`/`FocusWithin`.
- Interactions: scroll/large-data performance, select (click, Cmd/Ctrl, Shift, Cmd+A), keyboard navigation, double-click submit, edit cell, context menu, expand/collapse, resize.
- States: hover/selected/focused/disabled/pinned header/following end/empty/collapsed/expanded.
- Cross-platform: Cmd vs Ctrl selection and Page Up/Down; scrollbar theme; row focus ring.
- Items: `list-scrolling`, `table`, `tree`, `tree-item`, `outline`, `outline-table`, `grid-view`, `collapsible`, `collapsible-base`, `accordion`, `accordion-item`, `badge`, `avatar`, `editable-text`.

## 13. Charts — `/charts` — complexity M

Purpose: show the headless chart toolkit and composability.
- Controls: `chart.Plot` with axes/ticks/labels; scales `NewLinear`/`NewBand`/`NewTime` + `Nice`/`Ticks`; marks `chart.Rect`/`Point`/`RuleX`/`RuleY`/`Anchor` with hover tooltips; paths `chart.Line`/`Area`/`Pie`/`Sector` via `Draw`; stacked series `chart.Stack` (standard/normalized); high-rate streaming line with `chart.MinMax`; `chart.Select` (pointer/keyboard) with detail readout; `Label` + data summary for accessibility; theme-driven colors.
- Interactions: hover, select point/band, legend toggles, time-range switch, resize (fraction-based layout), keyboard selection.
- States: default/selected/hovered; light/dark; live streaming.
- Cross-platform: pure drawing — identical; text labels use OS text engine; performance target ~120Hz ProMotion macOS.
- Items: `chart-plot`, `chart-scales`, `chart-marks`, `chart-paths`, `chart-stack-minmax`, `chart-select`.

## 14. Code & Diff Editors — `/editors` — complexity M

Purpose: the code editor/diff viewer surfaces and their options.
- Controls: `editor.View` with a language `MenuButton` (`editor.LanguageFor`/`LanguageNamed`/`Languages`), toggles for wrap/line numbers/whitespace/fold/indent guides, find bar, completions/hover/diagnostics demo (custom `State` hooks), read-only sample, shared-buffer two-editor sample (`NewBuffer`), `editor.DiffView` split/unified with inline highlights, `DiffState` options (`Layout`, `Inline`, `Indicators`, `Editable`), custom render hooks (`DefaultHunkActions`, `DefaultGutterButton`), key bindings viewer (`DefaultBindings`, `CommandNamed`).
- Interactions: type/edit, multi-caret, find/replace, fold, accept/revert in diff, scroll sync, resize.
- States: focused/unfocused, read-only, modified, with diagnostics, folded, diff expanded.
- Cross-platform: keys (Cmd vs Ctrl); OS text shaping; input methods in editor.
- Items: `editor-code`, `editor-diff`, `editor-buffer-langs`, `code-editor` docs.

## 15. Markdown & Rich Text — `/markdown-richtext` — complexity L

Purpose: document content rendering/editing and streaming.
- Controls: `markdown.View` with themed code blocks/tables/task lists/footnotes/math; `markdown.Stream` with reveal unit selector (`ByLine`/`ByWord`/`ByCharacter`/`BySentence`/`ByParagraph`/`AtOnce`) and a "send token" button; `markdown.DefaultCodeBlock` header/copy; `richtext.Editor` with format toolbar (bold/italic/underline/strike/code/headings/lists/quotes/links/tasks/alignment/color), `Formatting` readout, `ReadOnly` sample, `TagStyle`/`OnLink` options, `richtext.EditorBase` custom style; importers `ParseMarkdown`/`ParseHTML`/`ParseRTF` + `Document.Text()` export; link/task click behavior.
- Interactions: edit/format/undo, link insert (Cmd+K), copy as rich text/Markdown, stream reveal, paste rich content.
- States: focused/read-only; formats at selection; streaming vs finished; dark/light theme.
- Cross-platform: Cmd vs Ctrl shortcuts; attributed-text accessibility (VoiceOver/Narrator/Orca) is a highlight to show.
- Items: `markdown-view`, `markdown-stream`, `markdown-code-theme`, `richtext-editor`, `richtext-base`, `richtext-document`.

## 16. Media, Drawing & Web View — `/media` — complexity M

Purpose: image/icon/avatar rendering, custom paint, and embedding a web engine in native UI.
- Controls: `Image` (bitmap + SVG sources; `Fit` contain/cover/stretch; radius/opacity/shadow/cache), `Icon` (SVG shapes in currentColor; labelled vs decorative; sizes/colors), `Avatar` (initials/photo sizes), `svg-bitmap` helpers (`ParseSVG`, `MustParseSVG`, `NewBitmap`, `DecodeBitmap`), `canvas-painter` (Draw/DrawOver: rects/paths/gradients/text/glyphs/focus ring/blur, animated sample), `WebView` demo **only when `mygo.WebViewAvailable()`**: embedded page with native UI around it, load URL/HTML, back/forward/reload, print to PDF, find in page, opacity; otherwise a clear "no webview on this build/platform" state.
- Interactions: fit switch, opacity slider, SVG color; drawing animation; webview navigation.
- States: loading/loaded image, webview loading/error; labelled icon.
- Cross-platform: WebView backends WKWebView/WebView2/WebKitGTK; availability check; a pure native-UI app needs no webview (state this in the card); drawing and SVG identical everywhere.
- Items: `image`, `icon`, `avatar`, `svg-bitmap`, `canvas-painter`, `web-view`, `webview-desktop`.

## 17. Drag & Drop — `/drag-drop` — complexity M

Purpose: in-window typed drag, native drag in/out, drop targets and modifiers.
- Controls: `Draggable` items between two `Column`s (reorder), typed drop zones with `DragOver[T]`/`Drop[T]` (highlight on hover via `Dragged()`/`Dragging()`), native `DropData`/`DataDragOver` accepting text/URL/html/image/files (drop from Finder/Explorer/file manager), `transfer.Data` payload builder, drag out via `DragData`/`DragDataFrom` (to Finder/Explorer or another app), `Window.OnFileDrop` file drop with paths, `DragEnded` reporting, copy/move modifier explanation, "paste equivalent" buttons for keyboard-only users.
- Interactions: drag/reorder, drag out, drop in from OS, modifiers, cancel.
- States: dragging/dragover accepted/rejected/dropped.
- Cross-platform: modifier meanings (Option vs Ctrl; Cmd vs Shift), UTI/MIME handling differences, editor text drag; identical visual language.
- Items: `drag-drop-desktop`, plus `list-scrolling` row drag example.

## 18. Motion, Transforms, Shaders & Glass — `/motion` — complexity L

Purpose: everything that moves or distorts, with a Reduce Motion switch.
- Controls: springs (`Smooth`/`Snappy`/`Bouncy`, `SpringOptions`), curves (`Animation{Duration, Ease}`, `CubicBezier`), `Animate*`/`Spring`/`Loop`/`Keyframes`, `Timeline` (+`AfterPrevious`/`WithPrevious`/`AtTime`/`AtLabel`), `Transition`/`ContentTransition` enter/exit, `Transform` 2D/3D (`Translate/Scale/Rotate/RotateX/Y/Perspective/Skew`), `Effect` shader on an element, `shader.Draw/Fill` samples, `glass.Glass` toolbar/panel/buttons + interactive glass, `glass.Blur` progressive blur, `glass.ScrollEdge` + content scrolling under a bar, `Material` composition, `Cache()`, `Blur()`, `Opacity`/gradient/`Stripes`.
- Interactions: play/pause/replay, drag/fling, toggle Reduce Motion (animations jump to target), toggle shader on/off, scroll under glass.
- States: animating/settled, reduced motion, dark/light, pressed interactive glass.
- Cross-platform: Reduce Motion differences; GPU backend differences only in compile timing; glass plugins render the same look everywhere (window vibrancy is the OS alternative).
- Items: `glass-glass`, `glass-blur`, `glass-scrolledge`, `shader-draw`, `shader-effect`, `canvas-painter`, transform/animation Element methods.

## 19. Desktop & Platform — `/desktop` — complexity L

Purpose: the host-level APIs that make a native app a *desktop* app; opens real windows/menus.
- Sections (each with a "Run" button, an availability badge, and a "what to expect per OS" note):
  1. **Window options/content** (`window-new`, `ui-view-window-content`, `window-controls`): open a second window with chosen options (frameless, transparent, always-on-top, panel, min/max, opacity, progress bar, flash frame) and manipulate it live; show `c.Size()`, `c.TitleBar()`, `c.Vibrancy()`.
  2. **Title bar** (`window-titlebar`): hidden title bar with drawn toolbar (`c.TitleBar()`, `DragWindow`, `MaximizeButton`), traffic-light position (macOS), hide-window-buttons mode.
  3. **Vibrancy / window material** (`window-vibrancy`): sidebar over material, glass/clear glass HUD window, acrylic on Windows 11, Linux fallback (draw background) with `c.Vibrancy()` truth.
  4. **Window state** (`window-state`): save/restore demo (StateKey, custom `WindowStateStore`).
  5. **App menu bar & roles** (`app-menu`): a menu with roles (About/Quit/Preferences/Edit/View/Window/Help), accelerators, checkmarks, submenus, disabled items, icons — inspect result in the real menu bar (macOS app-wide, Linux/Windows per-window).
  6. **Tray + flyout** (`tray`, `flyout`): create/remove tray icon with menu, click/right-click, template icon; open a `NewFlyout` panel (tray-relative/anchored) with vibrancy.
  7. **Native dialogs** (`dialogs-native`): Open (files/folders/multi), Save, Message (types/buttons/checkbox), Error; sheet vs modal.
  8. **Notifications** (`notifications-native`): show notification with title/body/icon, OnClick, clear; sender/messaging layout on macOS; permission/denied state.
  9. **Clipboard** (`clipboard`): text/HTML/image/files round-trip, read on button press, show formats.
  10. **Global shortcuts** (`global-shortcut`): register a shortcut (e.g. CmdOrCtrl+Shift+Y), show status/conflicts, unregister.
  11. **Screens** (`screens`): displays, work area, scale, primary, cursor screen, change listener.
  12. **Dock/JumpList/badges** (`dock-jumplist`): Dock menu/badge/bounce (macOS), jump-list tasks (Windows), badge count; "unsupported" badges elsewhere.
  13. **Now Playing / media keys** (`nowplaying`): publish metadata/state and receive commands; Linux MPRIS note.
  14. **Power & network** (`power`, `network`): keep awake with reason, sleep/resume/lock events log, battery/idle, online/offline banner.
  15. **Secrets** (`secrets`): save/read/delete a token in the OS keychain (never print the value).
  16. **Updater** (`updater`): Enabled/Check state, simulate source/progress in dev; explain signing requirements.
  17. **Shell & deep links** (`shell-integration`, `deep-links`): open URL/file, reveal in file manager, file icons, installed apps (launcher list), register URL scheme + `OnOpenURL` log; `OnOpenFile`.
  18. **Documents & single instance & login** (`documents`, `single-instance`, `open-at-login`, `app-lifecycle`): document window model demo (open/save/autosave/recent), second-instance handoff log, open-at-login toggle, About panel, quit confirmation hooks.
  19. **Webview availability** (`webview-desktop`, see Media screen).
- Interactions: every section is a real action, not a mock; logs events in an `OnEvent` list (app-level event log card).
- States: supported/unsupported/denied/pending per OS; light/dark; active/inactive.
- Cross-platform: this screen is the *platform matrix in app form* — each card must show the current OS's behavior truthfully (e.g. "Linux: window material unavailable", "macOS: app menu is app-wide", "Windows 11: menus follow dark mode").
- Items: `desktop` ids (31).

## 20. Accessibility, RTL & Languages — `/accessibility` — complexity M

Purpose: prove the accessibility tree, keyboard model, localization and RTL are first-class.
- Controls: role/state demo (`Role`, `RoleHeading`, `Label`, `Description`, `Error`, `Checked`, `Mixed`, `Expanded`, `Value`, `Range`, `Step`, `Level`, `ActiveDescendant`) on custom `Box`-built widgets; focus order walker (`Focusable`, `Tab`, `FocusGroup`, `Focus()`/`Focused()`), focus ring demo, `ui.Announce` (screen-reader announcement), accessibility inspector values mirror; language switcher (already in toolbar) + localized numbers/dates/time/currency via `c.Locale()`/`c.Region()`; RTL vs LTR side-by-side layout (sidebar/breadcrumbs/toolbar mirroring, numbers stay LTR), `Direction` override on a subtree; text scale/high-contrast toggles (`Preferences`), and the `-tags mygo_noinspector`/DevTools note.
- Interactions: keyboard-only walkthrough, screen reader (VoiceOver/Narrator/Orca) instructions card, RTL toggle, language switch, text scale.
- States: focus visible, high contrast, reduced motion, LTR/RTL, locales, IME composition.
- Cross-platform: VoiceOver vs Narrator/NVDA vs Orca; mac HighContrast via Increase Contrast, Windows contrast themes, GTK portal; text scale on Windows/GNOME; voice/announcement semantics.
- Items: `accessibility` docs (`Role*`), `locale-i18n`, `theme-appearance`, `text-input-client` docs.

## 21. Suggested implementation order (cuts scope safely)

1. Shell (sidebar/toolbar/router/theme/RTL/state-rail/snippet card) + Overview + Foundations.
2. One representative per category to validate the card pattern: Buttons, Text Inputs, Selection, Sliders, Pickers, Overlays.
3. Layout, Text, Navigation, Data Display (largest, reuse gallery patterns).
4. Charts, Editors, Markdown/Richtext, Media/Drawing.
5. Motion/Shaders/Glass, Drag&Drop.
6. Desktop & Platform (each section can ship independently; mark unsupported per OS).
7. Accessibility/RTL/Languages + `ui.Tester` regression tests + screenshot harness for all states.

## 22. "Showcase every variant" checklist (acceptance)

- [ ] Every inventory id (158) appears on at least one screen and is reachable within two clicks from the sidebar/search; overview screen states the count.
- [ ] Every themed widget is shown next to its `*Base` counterpart (Button, Checkbox, Radio, Switch, Toggle, Slider, Segmented, Select, Combobox, Tabs, Collapsible, Dialog, Popover, Tooltip, Toast, TextInput, TextArea).
- [ ] Every state in each item's `states` is visible: default/hover/pressed/focused/focus-visible/disabled/checked/mixed/selected/open/closed/readonly/error/placeholder/dragging/loading/streaming/reduced-motion.
- [ ] Both themes (system/light/dark), system accent + custom accent, high contrast, text scale, reduce motion.
- [ ] Both directions (LTR/RTL) for at least Layout, Text, Navigation, Data Display, Accessibility screens.
- [ ] Locale switch changes date/time/number formatting live (Pickers + Text + Languages card).
- [ ] Platform truth: every Desktop item has an availability badge and an "unsupported on this OS" explanation; `runtime.GOOS` + backend + scale + webview availability shown in Overview.
- [ ] Code snippet + copy button for every demo card; snippet matches the live code.
- [ ] Window-level demos (title bar, vibrancy, tray, flyout, menus, dialogs, notifications, global shortcut, updater) are real, not mocked; event log records outcomes.
- [ ] `ui.Tester` regression tests: one per screen view (frame + key clicks), `ui.Render` screenshot render after a fixed sequence for visual diffs.

## 23. Risks / open questions for later phases

- Desktop APIs cannot all be exercised in CI/headless (notifications, tray, global shortcuts, global menu, OS keychain, updater); the screen must degrade gracefully and CI should use `ui.Tester` + build-tag guards.
- Cross-OS runtime verification: only macOS is available locally; Windows/Linux behavior must come from cross-compilation + CI + docs statements (the app should display which claims are docs-based).
- WebView demo depends on WKWebView/WebView2/WebKitGTK availability; on Linux a native-only build may lack WebKitGTK → show availability, skip demo.
- Inspector/devtools only present in dev/debug builds; gate the Inspector reference behind `mygo.DevTools` and `mygo build -debug`.
- 158 demos with snippets is a lot of code; keep each demo in its own file per screen and generate the variant/state grids where possible from table-driven data (not codegen required; hand tables fine).
- Locale/i18n: screens' own strings should go through one catalog so the app itself can switch languages (dogfooding).
