# Coverage & gap analysis — existing examples vs. the MyGo Explorer showcase

Owner: ui-cataloger. Companion files: `inventory.json` (158 items), `INVENTORY.md` (tables/counts), `SCREENS.md` (proposed app), `API-NOTES.md`.

## Method

- Inventory items compared by name/constructor against every Go source file in `reference/mygo/examples/**` (excluding `_test.go`), split into `examples/gallery` vs. all other examples; grouped items (subpackages/desktop APIs) were matched by their distinctive API symbols and verified by reading the example.
- "Docs demo" = the item's docs page under `docs/ui/` carries a `<!-- preview ... -->` interactive demo (the docs site builds `website/docs-demo`, a Go/Wasm demo of the real toolkit). 64 of the 84 content pages have one, covering **111 of 158 inventory items**.
- Coverage numbers below are approximations where grouped items span several examples (a grouped desktop item counts as demonstrated when its example uses its API area); the per-item ground truth is in `inventory.json` fields plus the lists in this file.

## Headline numbers

| Bucket | Items | Share |
|---|---:|---:|
| Demonstrated in `examples/gallery` (the existing tour) | 113 | 72% |
| Only in another example (code-editor, loading, native, launcher, …) | 17 | 11% |
| **No example anywhere** | **28** | **18%** |
| Have a docs-site live preview | 111 | 70% |

So the toolkit is already well demonstrated *behaviourally*; the gap the Explorer fills is **systematic cross-platform, all-variant, all-state presentation in one navigable app**, not basic demos.

## 1. What `examples/gallery` already demonstrates

`reference/mygo/examples/gallery` (2,646 lines: `main.go` 1861, `charts.go` 323, `markdown.go` 117, `richtext.go` 79, `languages.go` 105) is a router-based app with a sidebar, toolbar (Back/Forward/Breadcrumbs), zoom and RTL toggle. Pages (`var pages`, main.go:282) and key demos:

| Page | Source | Already demonstrates | Notable inventory items |
|---|---|---|---|
| Overview | main.go:590 | cards, KPI text, sparkline, layout samples, badges, colors | Box/Row/Column, Text, Spacer, Divider, Progress, Badge, chart sparkline |
| Controls | main.go:655 | form controls grid: buttons, toggles, checkboxes, radios, switches, sliders, steppers, select, combobox, autocomplete, token field, rating, meter, date/time inputs, calendar popup, accordion, collapsible, menu button, segmented, tabs | Button, PrimaryButton, Toggle, ToggleGroup, Checkbox, CheckboxGroup, Radio/RadioGroup, Switch, Slider, StepSlider, RangeSlider, Stepper, Rating, Meter, Select, Combobox, Autocomplete, TokenField, DateInput, TimeInput, Calendar, ColorWell, MenuButton, Segmented, Tabs, Accordion(+Item), Collapsible, Field, Fieldset, Form, Toolbar |
| Text | main.go:892 | typography, fonts/sizes/weights, decorations, rich inline spans, selectable text, links, icons, editable text | Text, Textf, RichText, Link, Icon, Image, Avatar, EditableText, `Shape`/font APIs |
| Rich Text | richtext.go:33 | a full rich text editor with a format toolbar | `richtext.Editor`, `richtext.Document`, Formatting/commands |
| List | main.go:954 | 10k-row virtualized List + chat with variable heights/follow-end + sortable Table + OutlineTable file tree + row route (`/list/{row}`) | List, ListState, Selection, Table, TableColumn, OutlineTable, EditableText in table, context menus |
| Charts | charts.go:93 | bar, live streaming line (15k samples), stacked, scatter, donut charts with selection/tooltips | chart.Plot, marks, scales, Stack, paths, Select |
| Markdown | markdown.go:57 | finished Markdown + streaming Markdown showcase | `markdown.View`, `markdown.Stream`, reveal units, code blocks |
| Styling | main.go:1206 | grid layouts, borders, shadows, gradients, stripes, blur, wide-gamut Oklch, transforms, color systems | Grid, gradient/shadow/stripe/blur/transform Element methods, Color/oklch |
| Drawing | main.go:1342 | custom Painter drawing, Canvas, paths, glyphs, shadows | Canvas, Painter, Draw/DrawOver, Shape |
| Glass | main.go:1395 | Liquid Glass toolbar/panel/buttons, scroll-edge, progressive blur, lens | `glass.Glass`, `glass.ScrollEdge`, `glass.Blur`, Material |
| Overlays | main.go:1772 | AlertDialog, Modal, Popover, MenuButton menu, native `mygo.Dialog.Message`, file drops | AlertDialog, Modal, Popover, MenuButton, `mygo.Dialog`, DropData |
| Motion | main.go:1502 | springs, tweens, keyframes, timelines, transitions, drag/fling, content transitions | Animate*/Transition/Keyframes/Timeline/Draggable |
| Languages | languages.go:26 | language menu, localized numbers/dates/time, RTL layout, regions | App.SetLanguages, Locale/Region, Direction, DateInput/TimeInput/Calendar |

Also covered by gallery: Router/Route/Back/Forward/Breadcrumbs/Sidebar(+Item/Section)/Badge, window theming (`c.Theme()`), Tooltip, Clipboard.WriteText, `mygo.NewWindow` native content window, `mygo.App.SetLanguages/WhenReady/Run`, dark/light theme following, 10k-row performance, `ui.Tester` tests (`main_test.go`).

## 2. What other examples cover (gallery gaps they fill)

| Example | Demonstrates (relevant items) |
|---|---|
| `native/` | app + context menus, tray, dialogs, notifications, global shortcut, clipboard, window-title (desktop APIs not shown in gallery) |
| `menubar-native/`, `menubar-flyout/` | tray app; flyout window from tray icon |
| `flyout/` | Flyout windows, glass/vibrancy flyouts, placement |
| `launcher/` | global shortcut, flyout, single-instance, screens, shell, open-at-login, vibrancy |
| `vibrancy/`, `frameless/` | window vibrancy/material, hidden title bar, draggable custom title bar |
| `documents/` | mygo.NewDocuments document model |
| `code-editor/` | `editor.View`, `editor.DiffView`, completions/hovers/diagnostics |
| `markdown-chat/` | `markdown.Stream`, reveal animations |
| `notes/` | `richtext.Editor` in a real app with toolbar |
| `loading/` | 29 `plugins/loading` spinners with options |
| `chart-streaming/` | high-rate chart updates |
| `drag-drop/`, `clipboard/` | native drag & drop + clipboard data model across windows/apps |
| `embed-webview/` | `ui.WebView` + native UI around it |
| `farm/`, `mayoi/` | `plugins/game` game view + pixel fit |
| `blackhole/`, `chat-glow/`, `wind/` | `ui/shader` draws/effects |
| `piano/` | audio + keyboard-driven custom UI |
| `text-input/`, `text-buffer/` | custom text input primitives, TextBuffer |
| `timeline/`, `effort-slider/`, `confetti/` | motion/timeline primitives, custom slider/painting |
| `todo/`, `notes/`, `hello/`, `counter-native/` | app patterns, services/events, Tester-tested view |
| `terminal/` | terminal plugin embedded in native UI |

## 3. What NO example demonstrates (the real gaps)

28 items have no example. They split into three groups:

**A. Unstyled `*Base` widgets (theming/custom-widget story, 12):**
`button-base` (only in a test-scaffold example, not gallery), `checkbox-base`, `radio-base`, `toggle-base`, `segmented-base`, `combobox-base`, `slider-base` (other example only), `text-input-base`/`text-area-base` (other example only), `text-input-buffer`, `text-input-buffer-base`, `text-area-buffer`, `text-area-buffer-base`, `collapsible-base`, `dialog-base`, `popover-base`, `toast-base`, `toast-viewport-base`, `tooltip-base`.
Gallery deliberately shows only themed widgets; no example shows the base → themed graduation or a custom widget built on a base except docs `custom-widgets.md`.

**B. Layout variants not in gallery:** `scroll-horizontal`, `split-percent`, `split-vertical`, `split-vertical-percent` (gallery only uses `Split` horizontally; scroll only vertical/both).

**C. Platform/desktop APIs with no demo anywhere:**
`updater` (auto-update), `power` (keep-awake/sleep hooks), `network` (online/offline status), `nowplaying` (media keys/metadata), `secrets` (OS keychain), `dock-jumplist` (Dock menu/badge/jump list; no example uses Dock/JumpList), `deep-links` (URL schemes/OnOpenURL/OnOpenFile — partial in docs only), plus `app-menu`'s full role system is only partly used (native example), `window-state` persistence, `color-picker` (gallery only uses `ColorWell`), `toast-*` bases (galleries use `c.Toast`, not custom viewports), `overlay` helper, `popover-base`, `outline` (gallery uses `OutlineTable` only).
Also missing in every example: a **side-by-side platform/theme/accent state matrix**, forced hover/pressed/focus/disabled states, mixed LTR/RTL side-by-side, and viewer of *native menu role coverage* on all OSes.

## 4. Coverage by inventory category

| Category | Items | In gallery | Other example only | **No example** |
|---|---:|---:|---:|---:|
| Layout | 13 | 8 | 1 | 4 (`scroll-horizontal`, `split-percent`, `split-vertical`, `split-vertical-percent`) |
| Forms & Fields | 3 | 3 | 0 | 0 |
| Text & Typography | 4 | 4 | 0 | 0 |
| Actions | 7 | 5 | 1 | 1 (`toggle-base`; `button-base` only in a scaffold) |
| Text Inputs | 13 | 7 | 2 | 4 (buffer + base variants) |
| Selection Controls | 16 | 12 | 0 | 4 (`checkbox-base`, `radio-base`, `segmented-base`, `combobox-base`) |
| Sliders & Steppers | 5 | 4 | 1 | 0 |
| Pickers | 5 | 4 | 0 | 1 (`color-picker`; gallery uses ColorWell only) |
| Navigation | 8 | 8 | 0 | 0 |
| Overlays | 9 | 3 | 0 | 6 (`overlay`, `dialog-base`, `popover-base`, `toast-base`, `toast-viewport-base`, `tooltip-base`) |
| Data Display | 11 | 10 | 0 | 1 (`outline`; OutlineTable is in gallery) |
| Media | 4 | 4 | 0 | 0 |
| Feedback & Status | 5 | 5 | 0 | 0 |
| Charts | 6 | 6 | 0 | 0 |
| Editors | 9 | 8 | 1 | 0 |
| Effects & Materials | 5 | 5 | 0 | 0 |
| Decoration & Drawing | 2 | 2 | 0 | 0 |
| Plugins & Extras | 2 | 0 | 2 | 0 |
| Desktop & Platform | 31 | 13 | 11 | 7 (`updater`, `power`, `network`, `nowplaying`, `secrets`, `dock-jumplist`, `deep-links`) |

## 5. Inherently interactive / static-visual / platform-dependent

Needed to design screens that expose real states (see SCREENS.md):

| Class | Count | Examples | Implication |
|---|---:|---|---|
| **Stateful** (bind a `*T`/buffer/state object; must hold real app state) | 91 | all inputs, selection controls, sliders, pickers, lists/tables/trees, editors, overlays with `open *bool` | Explorer needs a state struct per screen and reset/"force state" controls; compile-time variant grids are cheaper for pure visuals |
| **Interactive but stateless** (actions/events without a bound value) | 2 | Button-family, MenuButton | demo with counters/toasts |
| **Static-visual** (display only; theme/typography variants matter) | 34 | Text, Icon, Image, Divider, badges, chart primitives, shader/glass surfaces | can be laid out as comparison grids without interaction |
| **Platform/desktop-dependent** (needs a real OS window, menu bar, notifications, permissions) | 31 | windows/titlebar/vibrancy, app menus, tray, dialogs, notifications, global shortcuts, documents, webview | cannot be shown faithfully inside one content view; needs real windows + explicit "unsupported on this OS" states |

## 6. Docs-only coverage and docs/source drift

- 64 docs pages have live previews; **111 items** are reachable from a docs page with a preview. The previews are `website/docs-demo` — real MyGo UI compiled to Wasm/JS, not mockups, so they are a good behavioural reference.
- Docs pages with **no single constructor** (cross-cutting; must be handled by screens/notes, not one inventory row): `accessibility`, `context-menu`, `custom-widgets`, `drag-and-drop`, `drawing`, `input`, `inspector`, `migration`, `motion`, `navigation`, `performance`, `rendering`, `right-to-left`, `styling`, `testing`, `transforms`, `transitions`, `views`, `windows`, plus subpackage pages `chart`, `code-editor`, `diff-viewer`, `markdown`, `rich-text-editor`, `shaders`.
- Drift/looseness found: `ui/tooltip.md` documents `TooltipBase` and `.Tooltip()` (there is no themed `Tooltip` constructor); toast themed API is `c.Toast`/`c.ToastAction` + `Toast` struct + `*Base` parts; `ui/dialog.md` covers `Modal` (themed) and `DialogBase`; `ui/overlays.md` covers `Overlay`; `lang`/`Direction`/`Role` live on `Element`, not constructors. All recorded in API-NOTES.md.

## 7. Conclusion for the Explorer

The gallery is an excellent *behaviour* tour but a poor *visual catalog*: it is one continuous app biased to macOS dev-time defaults, has no platform/theme/accent matrix, no forced states, no base-vs-themed comparison, no desktop-API surface, and misses every `*Base` widget. The Explorer should therefore:
1. reuse gallery/example patterns for behavior demos (they are proven and copy-paste-able), and
2. add the structured screens in `SCREENS.md` (Foundations, every category with variant/state grids, Desktop & Platform with real windows, Testing/Inspector), with an "OS badge / unavailable" story per platform.
