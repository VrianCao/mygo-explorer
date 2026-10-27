# API notes — building the MyGo Explorer gallery

Architecture/implementation notes for phase 1. Sources: `reference/mygo/ui/*.go`, `docs/ui/{views,styling,custom-widgets,testing,accessibility,input,right-to-left,windows}.md`, desktop docs. Signatures cited in `INVENTORY.md`; item ids in `inventory.json`.

## 1. Runtime model (what a gallery can and cannot do)

- **View = function of state.** `ui.View(app.view)` returns the window `*Content`; MyGo calls it on the main thread to build frames after input/model changes and while animating. A frame can contain **several build passes**, so an action can be reflected before paint (`docs/ui/views.md`).
- **Elements are single-build values.** Each `ui.Element` belongs to one build pass; owner/slot/generation are checked. Use `Valid()` for optional elements and `ui.Element{}` for absence. Never store an `Element` in app state or a goroutine. Store `ui.Handle` for persistent control identity, `ui.Services` for callbacks across builds; widget state objects (`ListState`, `GridState`, `OutlineState`, `Router`, `TextBuffer`, `editor.State`, `richtext.Document`, `*ui.SVG`, `*Bitmap`) belong in the app state (`docs/ui/views.md`; `ui/element.go`, `ui/ref.go`).
- **Bound widgets write on construction.** `ui.Checkbox(c, &app.sync, "Sync")` writes the user's edit through the pointer *before the constructor returns*, so the next statement sees it; `Changed()` reports a change in this build pass, `Submitted()` an Enter in a single-line input. `Disabled/ReadOnly/Step` set in a build govern the *following* frames' input (`docs/ui/views.md#events-and-actions`).
- **Event/action ordering.** `Clicked()` is ordinary control flow and sees only state as of that point in the build; `OnClick`/`OnChange`/`OnSubmit` run after the view finishes building and bound input is applied, before the rebuild. To mutate a collection while rendering it, collect the mutation and apply it after the loop, or use `OnClick` (`docs/ui/views.md`).
- **Keys.** `c.Key(id)` is unique among siblings (comparable values; pointer keys by pointer, uncomparable by printed value). Key stateful controls and custom base widgets *before* they build; use `Context.Key` for base widgets. Duplicate sibling keys are a tester panic and dev log.
- **`ui.Local(e, key, init)`** keeps per-element state across frames (frame-local widget state, e.g. a custom widget's `shown bool`). It is one of the 8 excluded api_gen funcs but is the recommended custom-widget state tool (`docs/ui/custom-widgets.md`).
- **`Handle`/`Ref`** (`ui/ref.go`, `Element.Bind/Ref`) for stable identity of a control across frames; `ui.FocusedValue` for reading the focused value of a radio group etc.
- **Goroutines.** The view reads state on the main thread; other goroutines must hand work back (channels/`OnClick`/`mygo` events — see `docs/ui/views.md#change-the-state-from-other-goroutines` and examples/gallery's "updates from other goroutines" demo).

## 2. Themed widgets vs `*Base` (unstyled)

- Many widgets ship in pairs: a **themed** constructor (`Button`, `Checkbox`, `Slider`, `Select`, `Combobox`, `Segmented`, `Tabs`, `Collapsible`, `DialogBase`'s themed sibling `Modal`, `Popover`, `TooltipBase`+`Element.Tooltip`, `Toast*`) and an **unstyled base** returning either an `Element` or a **parts struct** (multiple elements): `ButtonBase`, `CheckboxBase`, `RadioBase`, `SwitchBase`, `ToggleBase`, `SliderBase`, `TabsBase`→`TabsParts{List, Tab(i)}`, `SegmentedBase`→`SegmentedParts{Track, Segment(i)}`, `SelectBase`→`SelectParts[T]{Trigger, Popup(fn), Item(v), Highlighted}`, `ComboboxBase`→`ComboboxParts{Input, Popup(fn), Item(v), Chosen}`, `CollapsibleBase`→`CollapsibleParts{Trigger, Panel, Progress}`, `PopoverBase`, `DialogBase`, `TooltipBase`, `ToastBase`→`ToastParts{ActionButton, CloseButton}`, `ToastViewportBase`, `TextInputBase`, `TextAreaBase`, `*BufferBase`.
- Bases provide behavior + accessibility and leave every color/size/shape to the caller: build on them for the Explorer's "custom widget" demos. Parts get `Key` before construction and must be styled by chaining on the part's element.
- **Theme.** `c.Theme()` returns the window theme (light/dark following the system unless `c.SetTheme(&t)`; `t := *c.Theme()` then edit `Accent/Radius/Spacing/FontSize/Font/Roll...`). `ui.LightTheme()`/`ui.DarkTheme()`; `Theme.follow(Preferences)` applies system `Accent`, `ReduceMotion`, `HighContrast`, `TextScale`. Widget metrics use `t.Space(n)` and `t.Rem(n)`; custom elements should too. Inverse colors for tooltips/toasts. macOS continuous corners vs quarter circles elsewhere; scrollbar width/color; default font 13 macOS / 14 others (`ui/theme.go`, `ui/preferences.go`, `docs/ui/styling.md`).
- **State, not selectors.** No stylesheets: style from state inline (`if row.Hovered() { row.Background(t.SurfaceHover) }`); one element's state can style another. `Element.SetChanged` lets a custom widget report edits like built-ins; `Changed()` then behaves the same.
- **Materials/effects.** `Element.Material(m)` fills the box in place of a background: `glass.Glass` (Regular/Clear, Tint, Interactive, Clarity), `glass.Blur` (Radius + optional gradient Mask), `glass.ScrollEdge`. `Element.Effect(fx)` applies a `shader.Effect` (ColorEffect/DistortionEffect/LayerEffect) over the rendered subtree. `Element.Cache()` keeps a painted subtree in a GPU bitmap; `Element.Blur()` blurs subtree; `Element.Draw/DrawOver/DrawObjects` for custom painting with `Painter`.
- **Custom overlay/layout.** Floating elements: `Absolute/AttachTo/Top/...`, close with `PressedOutside`/`OverlayShortcut`, keep focus with `Modal`; place above content with `ui.Overlay(c, fn)`; custom menus drawn in-window need roles `RoleMenu`/`RoleMenuBar`/`RoleMenuItem*` (`docs/ui/custom-widgets.md`, `overlays.md`).

## 3. Element fluent API (used by `key_methods`)

- **259 methods total**: 245 generated (`ui/api_gen.go`, "`func (_handle Element)`") + 14 hand-written (`OnClick/OnChange/OnSubmit/OnShortcut` in `ui/actions.go`; `Valid/Children/Key/Material` in `ui/frame.go`; `ItemKey/Selection/Rows` in `ui/list_builder.go`; `FocusBind` in `ui/focus_binding.go`; `Bind/Ref` in `ui/ref.go`).
- Groups (representative): **layout/size** `Width/Height/Size/Min*/Max*/Fill*/Grow/Shrink/Basis/AspectRatio/Padding*/Margin*/Gap*/Top/Left/Right/Bottom/Percent/Absolute/Flex`; **style** `Background/Gradient/LinearGradient/ConicGradient/Stripes/Border*/Radius/Shadow/InsetShadow/Opacity/Clip/Blur/Cache/Material/Effect`; **flex/grid** `Row/Column/Grid/Columns/GridRows/ColumnTracks/RowTracks/ColumnSpan/RowSpan/Wrap/Align*/Justify*`; **interaction** `Clicked/Changed/Submitted/Hovered/Pressed/DoubleClicked/RightClicked/DroppedFiles/DragEnded/Focused/FocusWithin/FocusVisible/Disabled/Focusable/Focus/AutoFocus/KeepFocus/Tooltip/ContextMenu/Menu/Cursor`; **accessibility** `Label/Description/Error/Role/Value/Range/Step/Checked/Mixed/Expanded/Level/ActiveDescendant`; **text** `Font/FontSize/FontWeight/Bold/Italic/Underline/Strikethrough/WavyUnderline/TextColor/TextAlign/LineHeight/LetterSpacing/MaxLines/NoWrap/Ellipsis/Selectable/TextSelection/SetTextSelection/TextBackground/SelectionColor/Lang`; **animation/motion** `Animate/AnimateTo/AnimateWith/AnimateColor/AnimatePose/Spring/Loop/Keyframes/Jump/Timeline/Transition/ContentTransition/Transitioning/Settled/Arrived/Velocity`; **transform** `Transform/Translate/Rotate/RotateX/Y/Scale/Skew/Perspective/TransformOrigin/BackfaceHidden`; **state/refs** `Key/Children/InView/ScrollIntoView/TrackScroll/ScrollWith/Valid/FocusBind/LocalToWindow/WindowToLocal`; **drag/drop** `Draggable/Drag/DragData/DragDataFrom/DragOffset/DragVelocity/Dragging/Dragged/DragEnded`.
- Docs for each: `docs/ui/{layout,styling,transforms,motion,transitions,drawing,input,accessibility,list,...}.md`; hover/press/focus are state methods, not CSS.

## 4. Showing states deterministically (Tester vs real interaction)

- `ui.NewTester(view, w, h)` runs a view **without a window**, renders frames in memory, finds elements by text/`Label`, and drives pointer, keyboard, menus and time (`docs/ui/testing.md`; `ui/headless.go`). Use it for the Explorer's own regression tests and for **state snapshots**.
- Tester surface (from `ui/headless.go`, docs): pointer `Click/ClickAt/ClickWith/Press/Release/Move/Scroll/Wheel/Pinch/HoldModifiers/DropFiles`; keyboard `Key/KeyDown/KeyUp/KeyAt/Type/TypeKey/Compose/Command/TextCaret`; menus `RightClick/Menu/ChooseMenuItem/CloseMenu`; window `SetSize/SetScale/SetZoom/SetDark/SetPreferences/SetDirection/SetLocale/SetRegion/SetTitleBar/SetVibrancy/SetFocused`; output `Frame/FramePending/Image/Find/Texts/HasText/Focused/Cursor/Clipboard/OpenedURLs/Announcements/FailOpenURL`; time `Now/Advance`; `WebViewAt`.
- `ui.Render(view, w, h, scale)` draws a single frame to `*image.RGBA` — good for screenshot generation in a test harness (`docs/ui/testing.md`).
- For the Explorer: keep a **state-rail** in app state (`screen`, `variant`, `forcedState`), set real API flags (`Disabled(true)`, `ReadOnly(true)`, `Error(...)`, `open=true`, `Checked`, `Mixed`, `Focused`…) and, for hover/pressed/focus-ring, use `Tester` screenshot jobs (the tester's `Move`/`Press` then `Image()`), never fake the visuals with background colors.
- Animations in tester: time is virtual — `tt.Advance(d)` runs due frames; `tt.FramePending()` tells whether the view keeps asking for frames (`docs/ui/testing.md`). This makes motion demos testable.

## 5. Host-level chrome APIs (root package `mygo`; all inventoried in `inventory.json` Desktop & Platform)

- **Windows/content:** `mygo.NewWindow(WindowOptions{...})` + `ui.View(app.view)` as `Content`; window methods for show/hide/focus/minimize/maximize/fullscreen/bounds/title/represented file/document edited/opacity/shadow/always-on-top/taskbar/workspace/progress/flash/mouse passthrough/content protection; `SetVibrancy`, `SetWindowButtonsTheme`, `SetActiveAppearance`, `CapturePage`, `OnFileDrop` and all window listeners; `WindowStateStore`/`StateKey`.
- **Title bar:** `TitleBarStyle` (`TitleBarDefault/Hidden/HiddenInset`), `c.TitleBar()` → `TitleBar{Height,Left,Right}`, `DragWindow()`, `MaximizeButton()`, `TrafficLightPosition`, `TitleBarHeight`, `HideWindowButtons`.
- **Menus:** `mygo.Menu`/`NewMenu`/`MenuItem`/`MenuRole`/`Separator`/`NewMenuIcon`; app menu vs per-window bars; text-editing/role menus; in-window context menus: `Element.ContextMenu(func(*ui.Menu))`, `Menu.Item/Submenu/Separator/EditItems`, `MenuItem.Checked/Disabled/Shortcut/Chosen`.
- **Tray / flyout:** `mygo.NewTray(TrayOptions{...})` (+SetIcon/SetTitle/SetToolTip/SetMenu/PopUpMenu/Bounds/Destroy/OnClick/OnRightClick/Dark/OnAppearanceChange); `mygo.NewFlyout(FlyoutOptions{...})` (tray-relative, `FitContent`, vibrancy, close on blur/Escape).
- **System dialogs/notifications:** `mygo.Dialog.Open/Save/Message/Error`; `mygo.NewNotification(NotificationOptions)` + `NotificationSender`, `NotificationsSupported()`, `ClearNotifications()`, `App.OnNotificationClick`.
- **Clipboard/data/drag:** `mygo.Clipboard` (text/files/formats), `c.ReadClipboard/WriteClipboard`, `transfer.Data` and `Window.OnFileDrop`; typed in-window drag via `Draggable/Drop/DragOver`; native drag via `DropData/DataDragOver/DragData`.
- **Global shortcuts:** `mygo.GlobalShortcut.Register/IsRegistered/Unregister/UnregisterAll`.
- **Theme/appearance/preferences:** `mygo.Theme.IsDark/Preferences/Source/SetSource/OnUpdated`; `ui` theme + `c.Preferences()` (Accent/ReduceMotion/HighContrast/TextScale).
- **Locale/i18n/RTL:** `App.Languages/PreferredLanguages/SetLanguages/SetLocale/Locale/Region/OnLocaleChanged/OnRegionChanged`, package `i18n`; `c.Locale()/Region()/Direction()`, `ui.LeftToRight`/`RightToLeft`, `Element.Direction`, `Lang`.
- **Screens:** `mygo.Screen.Displays/PrimaryDisplay/CursorScreenPoint/DisplayNearestPoint/DisplayMatching/OnDisplaysChanged`.
- **Dock/jump list/badges:** `App.Dock.SetMenu/SetBadge/Bounce/SetIcon/Hide/Show`, `App.JumpList.SetTasks`, `App.SetBadgeCount`.
- **Media keys:** `mygo.NowPlaying.Set/SetPlayback/OnCommand/Control/Clear`; `MediaCommand`, `PlaybackState`, `NowPlayingInfo`.
- **Power/network/secrets/updater/shell:** `mygo.Power.KeepAwake/OnSuspend/OnResume/OnLockScreen/OnUnlockScreen/IsOnBattery/IdleTime`; `mygo.Network.Status/OnChanged`; `mygo.Secrets.Set/Get/Delete`; `mygo.Updater.Enabled/Check/SetSource/SetPrereleases` (+ plugins/updater); `mygo.Shell.OpenExternal/OpenPath/ShowItemInFolder/TrashItem/FileIcon/InstalledApps/LaunchApp/Beep`.
- **Documents/deep links/instance/login/lifecycle:** `mygo.NewDocuments(DocumentsOptions[T])`, `App.AddRecentDocument/RecentDocuments/ClearRecentDocuments`; `App.RegisterURLScheme/UnregisterURLScheme/IsURLSchemeRegistered/OnOpenURL/OnOpenFile`; `mygo.Protocol.Handle/FileServer`; `App.RequestSingleInstanceLock/OnSecondInstance`; `App.SetOpenAtLogin/OpenAtLogin/WasOpenedAtLogin`; `App.WhenReady/Run/Quit/Exit/Relaunch`, `OnReady/OnBeforeQuit/OnWillQuit/OnQuit/OnActivate/OnDidBecomeActive/OnDidResignActive/OnWindowAllClosed/OnWindowCreated`, `SetName/SetVersion/IsPackaged/Path/SetPath`, `ShowAboutPanel`, `SetActivationPolicy`.
- **Web views:** `win.NewWebView(...)` → `mygo.WebView` (`LoadURL/LoadHTML/LoadFile/Reload/GoBack/GoForward/Eval/EvalContext/SetZoomFactor/SetUserAgent/PrintToPDF/Print/FindInPage/StopFindInPage/OnWillDownload/OnDownloadDone/SetPermissionHandler/...`), `mygo.WebViewAvailable()`, `ui.WebView(c, v)`.

## 6. Subpackages the gallery needs

| Package | Import | Entry points | Docs |
|---|---|---|---|
| chart | `github.com/egoist/mygo/ui/chart` | `Plot`, `Rect/Point/RuleX/RuleY/Anchor`, `Select`, `NewLinear/NewBand/NewTime/Extent`, `Line/Area/Pie/Sector/Polar/Nearest/SliceAt`, `Stack`, `MinMax` | `docs/ui/chart.md` |
| editor | `.../ui/editor` | `View(*State)`, `DiffView(*DiffState)`, `NewBuffer`, `LanguageFor/LanguageNamed/Languages`, `DefaultBindings/CommandNamed`, render hooks `DefaultSeparator/DefaultHunkActions/DefaultGutterButton` | `code-editor.md`, `diff-viewer.md` |
| markdown | `.../ui/markdown` | `View`, `Stream`, `DefaultCodeBlock`, `DefaultTheme`, `FileImages`, `Slug`, `Reveal` | `markdown.md` |
| richtext | `.../ui/richtext` | `Editor`, `EditorBase`, `NewDocument`, `NewText`, `TextOf`, `ParseMarkdown/ParseHTML/ParseRTF`, `DefaultTheme` | `rich-text-editor.md` |
| shader | `.../ui/shader` | `Compile/MustCompile`, `(*Shader).Draw/Fill/FillPath/StrokePath/Text/Effect`, `Options`, `Values`, `Effect` | `shaders.md` |
| glass | `github.com/egoist/mygo/plugins/glass` | `Glass{Style,Tint,Interactive,Clarity}`, `Blur{Radius,Mask}`, `ScrollEdge{}` — attach via `Element.Material` | `docs/plugins/glass.md` |
| loading | `.../plugins/loading` | 29 spinner constructors + `Options`, `All()` | `docs/plugins/loading.md` |
| game | `.../plugins/game` | `View(c, Game)`, `Camera`, `IntegerFit` | `docs/plugins/game.md` |

## 7. Accessibility surface (show it off; it is part of the product)

- Roles (`ui/access.go`): `RoleAuto/RoleNone/RoleGroup/RoleText/RoleButton/RoleLink/RoleCheckBox/RoleRadio/RoleSwitch/RoleSlider/RoleProgress/RoleTextField/RoleImage/RoleList/RoleScroll/RoleDialog/RolePopup/RoleTooltip/RolePopUpButton/RoleTabList/RoleTab/RoleSplitter/RoleStatus/RoleTable/RoleRow/RoleCell/RoleColumnHeader/RoleTree/RoleTreeItem/RoleListItem/RoleMenuButton/RoleToolbar/RoleRadioGroup/RoleToggleButton/RoleComboBox/RoleDisclosure/RoleMeter/RoleStepper/RoleColorWell/RoleAlertDialog/RoleMenu/RoleMenuBar/RoleMenuItem/RoleMenuItemCheckBox/RoleMenuItemRadio/RoleHeading`.
- Names: widget text names it; otherwise `Label`; `Description` adds help text; fields name their control; `Fieldset` legend names the group. States: `Checked/Mixed/Expanded/Value/Range/Step/Level/ActiveDescendant`. Screen readers act on widgets (press, toggle, edit, move focus/selection). `c.Announce(text)` for live announcements.
- Keep custom widgets honest: set `Role`, `Label`, states, `Focusable`, `FocusRing`/`Painter.FocusRing`, take keys with `Shortcut`; for text controls use `HandleTextInput` + retained geometry (`docs/ui/text-input-client.md`).
- Accessibility is OS-native: VoiceOver/macOS, Narrator+NVDA/Windows, Orca/Linux (`docs/ui/accessibility.md`). High contrast/text scale preferences change the default theme.

## 8. RTL, locale, zoom (cross-cutting demo levers)

- Layout direction comes from the app language; `ui.LeftToRight/RightToLeft`; `Element.Direction` applies to an element and its children *before* children are built; popups/overlays take the direction where they were asked for; coordinates are not mirrored (`docs/ui/right-to-left.md`). The gallery's `g.rtl` toggle and `MYGO_DIRECTION=rtl` are proven patterns.
- `c.Locale()/c.Region()`; widgets (dates, numbers, editor texts, menus/dialogs) localize; `i18n` package catalogs; `App.SetLanguages` negotiation. Date/time/number formatting only changes in some widgets (verify per screen).
- `c.SetZoom(z)` (0.25–5) re-lays out at `1/z` size and paints at screen scale × z → crisp text/icons; `c.Zoom()`, `c.Size()` are content DIPs. Good "display sharpness" demo; `Tester.SetZoom` mirrors it (`docs/ui/windows.md#zoom`).

## 9. Excluded APIs (and why) + supporting helpers

- Excluded from inventory: `ui.Local` (state helper; used by custom widgets), `ui.NewTester`/`ui.Render` (headless testing; used by Testing harness), `ui.Drop/DragOver/DropData/DataDragOver` (behaviour helpers on an element; shown via the Drag & Drop screen), `ui.View` (returns `*Content`; inventoried as Desktop item `ui-view-window-content`).
- Supporting helpers not standalone items: `NewBitmap/DecodeBitmap/NewCanvas/RGB/RGBA/Hex/Oklch/Nearest/FocusedValue/Shape/Fixed/Fr/FitContent/Rubberband/Project/CubicBezier/NewRouter/SafeToOpen/ParseSVG/MustParseSVG/NewTextBuffer/UTF16Len/UTF16ByteOffset/ShapeText/ShapeRichText/ShapeRichTextWith/LightTheme/DarkTheme/RegisterFont/FontFamilies`, motion/timeline/transform constructors. They appear in the relevant screens and `INVENTORY.md` accounting.
- Non-UI APIs (audio, network clients, plugins fetch/websocket/sqlite/terminal/watch/updater) are out of scope for a UI catalog except where they change UI (loading/glass/game/webview).

## 10. Docs/source drift observed (flag, do not silently follow docs)

- Docs describe behavior accurately in sampled cases, but some constructors have **no dedicated page** and are documented inside umbrella pages: buffer text controls (`text-input-client.md`), `Overlay` (`overlays.md`), `DialogBase` vs `Modal` (`dialog.md`), base widgets (`custom-widgets.md`), `Tooltip` via `TooltipBase`+`.Tooltip` (`tooltip.md`), toasts via `c.Toast/c.ToastAction`+`ToastBase/ToastViewportBase` (`toast.md`), `TabsBase/SegmentedBase/SelectBase/ComboboxBase/CollapsibleBase` parts (`custom-widgets.md`).
- There is **no themed `Tooltip` or `Dialog`/`Toast` constructor**; themed behavior is a method (`Element.Tooltip`, `Element.Modal`/`Modal(c,…)` for dialogs, `c.Toast`) or the `*Base` parts. Do not invent constructors when implementing.
- `docs/ui/chart.md` documents headless primitives; `charts.go` in gallery is the authoritative composition example (also `chart-streaming`).
- Code editor/diff docs reference `editor.State`/`DiffState` option fields; verify field names in `ui/editor/{editor,diffview}.go` (cited in `inventory.json` source/impl refs) rather than copying prose.
- Cross-platform statements in docs are sometimes per-feature caveats (e.g. title bar styles, vibrancy availability, menu roles, tray AppIndicator, updater signing); the Desktop screen must reflect them with availability badges.

## 11. Performance / gotchas for a 158-demo gallery

- Virtualize with `List/Table/Outline/GridView`; the gallery proves 10k rows and 15k-sample charts are cheap. Avoid building all demo cards on one page: one screen = one `Scroll` page, collapse variant grids with `Collapsible`.
- `Blur`, shader effects and `Cache()` have GPU/CPU cost; render them on demand in dedicated cards, not 50 at once; `Cache()` still still cards.
- `Element.Close`/window destroy semantics: a view can close its own window (Desktop demos!) — the window goes at once, the rest of the frame builds with a still-valid Context (`docs/ui/windows.md#closing`). Guard demos that open/close windows.
- Inspector: dev-only (`F12` / `Alt+Cmd+I`, `Ctrl+Shift+I`; `mygo build -debug` keeps it) and it takes ~250 KB binary; `WindowOptions.Page.DevTools` gates it. Use it while building screens; document it in the Testing/Accessibility screen.
- `ui.Tester` cannot exercise true OS integration (tray/menus/dialogs/notifications/webview) — keep those screens' logic behind small interfaces so tests can fake them; run window-level demos in real windows.
- Fonts: `FontFamilies()` first call queries the OS and is slow; cache it in app state. `RegisterFont` for a bundled monospace/specimen.

## 12. Recommended structure for the future app (phase 1+)

- `main.go`: app state/registry, `ui.NewRouter("/overview")`, `mygo.NewWindow(WindowOptions{Content: ui.View(view), TitleBarStyle: TitleBarHidden, StateKey:"explorer"})`, `mygo.App.WhenReady/Run`.
- `shell.go`: sidebar/toolbar/breadcrumbs/router/state-rail/snippet card/theme+accent+direction+locale controls; `demo` registry (id, title, snippet, build, docs/source refs, variants/states metadata loaded from a Go table mirroring `inventory.json`).
- One file per screen (`screen_layout.go`, `screen_data.go`, …) following SCREENS.md; `demoCard` helper; per-screen `ui.Tester` tests (`_test.go`) + optional `ui.Render` screenshot baselines.
- Desktop demos in `screen_desktop.go` with a small `platformSupported(demoID)` truth table driven by `runtime.GOOS`, `mygo.WebViewAvailable()`, `mygo.NotificationsSupported()`, `c.Vibrancy()`; log outcomes to an in-app event list.
- Keep snippet strings next to builders; copy via `c.WriteClipboard` + toast; a global "show snippets" toggle.
- Do not start this app in phase 0 (research only). Phase 1 should build the shell + one category first, then expand per SCREENS.md §21.
