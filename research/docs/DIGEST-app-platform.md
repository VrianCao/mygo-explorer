# Digest — MyGo app platform (shell, desktop APIs, packaging) for MyGo Explorer

Purpose: the app-level knowledge needed to build the **shell** of the MyGo
Explorer gallery app: project setup, app lifecycle, windows and window
chrome, menus/tray, desktop APIs, settings, i18n wiring, configuration,
CLI/dev loop, and packaging for macOS/Windows/Linux. Companion:
`DIGEST-native-ui.md` (view/widgets), `PLATFORM-DIFFERENCES.md`,
`GOTCHAS.md`.

Conventions: `docs/foo.md:12` = `reference/mygo/docs/foo.md`; `foo.go:12` =
`reference/mygo/*.go`; `api_gen.go` = `reference/mygo/ui/api_gen.go`.
Checkout `b553a90`, version `mygo.Version = "0.7.1"` (`mygo.go:70`).

---

## 1. Project shape (native UI template)

`mygo init -template native my-app` creates a **Go module alone** — no
frontend, no npm, no Bun (`docs/getting-started.md:73-91`,
`docs/cli.md:56-60`):

```
my-app/
├── main.go          app skeleton: state, view, window
├── main_test.go     ui.Tester view test
├── go.mod           requires github.com/egoist/mygo; CLI as a Go tool
├── mygo.json        name, identifier, version (JSON config)
└── resources/
    └── icon.png     1024×1024 (or icon.icns/icon asset for macOS)
```

- The module pins the CLI as a [tool](https://go.dev/doc/modules/managing-dependencies#tools):
  `go tool mygo dev`, `go tool mygo build`, `go tool mygo generate`
  (`docs/cli.md:23-25`). `go get -tool github.com/egoist/mygo/cmd/mygo@latest`
  updates it (`docs/getting-started.md:87-91`).
- `mygo.json` is equivalent to `mygo.config.ts` and needs **no JS runtime**;
  a project has one or the other (`docs/configuration.md:182-197`). A
  native-UI project omits all frontend fields
  (`docs/configuration.md:37-40,55-67`).
- Minimal config for the gallery:
  ```json
  {
    "name": "MyGo Explorer",
    "identifier": "dev.example.mygoexplorer",
    "version": "0.1.0",
    "icon": "resources/icon.png",
    "i18n": { "dir": "locales", "source": "en" },
    "linux": { "webview": false },
    "macos": { "minimumSystemVersion": "12.0" }
  }
  ```
  Fields: `docs/configuration.md` (`linux.webview: false` matters because a
  native-UI-only app needs GTK 3, not WebKitGTK: `docs/configuration.md:148`,
  `docs/distribution.md:495-520`).

---

## 2. App lifecycle (what goes in `main`)

```go
func main() {
    app := newApp()                              // declare state
    mygo.App.WhenReady(func() {
        app.win = mygo.NewWindow(mygo.WindowOptions{   // windows only after ready
            Title: "MyGo Explorer", Width: 1100, Height: 760,
            MinWidth: 760, MinHeight: 480, StateKey: "main",
            Content: ui.View(app.view),
        })
    })
    if err := mygo.App.Run(); err != nil { log.Fatal(err) }
}
```

- `App.Run()` must be called from the **main goroutine**; it runs the native
  event loop until quit. Windows exist only once ready: create them in
  `WhenReady` or from any goroutine after that (`docs/app.md:6-24`).
- Before `Run`, `main` may set up what applies at launch: `App.SetName`,
  `App.SetMenu`, `App.Dock.SetMenu`, `Theme.SetSource`, `Bind` (web pages
  only), listeners, `SetOpenAtLogin`, `RegisterURLScheme`; it may read
  `App.Path`, `App.Locale`, `Power.IsOnBattery` (`docs/app.md:26-36`).
- **Calling APIs that need the running app before `Run` panics** (clipboard,
  displays, dialogs, notifications, global shortcuts, trays, badges,
  `Theme.IsDark`, `Theme.Preferences`, …) on every platform
  (`docs/app.md:31-36`). The gallery must not read `Theme.Preferences` in
  `main` — do it in views or `WhenReady`.
- Every MyGo API is safe from any goroutine (calls hop to main); listeners
  (OnClose/OnActivate/menu clicks/global shortcuts) run on the main thread —
  keep them short and start goroutines for slow work; bound page methods run
  on their own goroutines (`docs/app.md:38-51`). For native UI the view is
  called on the main thread; publish background results with
  `Window.Update` (`ui/views.md:168-180`).

Lifecycle events (each returns a remover function) (`docs/app.md:52-65`):
`OnReady`/`WhenReady`, `OnActivate(hasVisibleWindows)`, `OnDidBecomeActive`,
`OnDidResignActive`, `OnWindowCreated`, `OnWindowAllClosed`, `OnBeforeQuit`,
`OnWillQuit`, `OnQuit`.

**Quitting**: last window closing quits unless `OnWindowAllClosed` has a
listener; on macOS keep the app running and reopen on `OnActivate`
(`docs/app.md:67-92`). `App.Quit()` (can be cancelled by `OnClose`/
`OnBeforeQuit`/`OnWillQuit`), `App.Exit(code)`, `App.Relaunch()`.
⌘Q, Quit menu item and SIGINT/SIGTERM quit the same way (second signal
exits immediately).

**Single instance** (recommended for the gallery: one window): 
`App.RequestSingleInstanceLock()` → false in the second instance after
passing its command line to the first; `App.OnSecondInstance(func(args,
workingDir))` (`docs/app.md:94-113`).

**Deep links / file associations**: `urlSchemes` and `fileAssociations` in
the config, handled by `App.OnOpenURL`/`App.OnOpenFile` registered before
`Run`; on Windows/Linux a URL starts a new instance → request the single
instance lock; macOS requires config registration, other OSes can
`App.RegisterURLScheme` at run time (`docs/app.md:115-177`).

**Directories** (`App.Path`, created on first use) (`docs/app.md:229-248`):
`PathUserData` (per-app data), `PathCache`, `PathLogs`, `PathResources`
(bundled files), `PathAppData`, `PathHome/Temp/Exe/Desktop/Documents/Downloads/Music/Pictures/Videos`.
Use `PathUserData` for the gallery’s saved preferences if they exceed window
state; `PathResources` for embedded images/fonts shipped via `resources/`
(`docs/distribution.md:117-142`).

**Name/version/dev detection**: packaged apps get name/version from the
config linked in (`App.Name()`, `App.Version()`); `go run` uses the
executable name; `mygo.IsDev()` distinguishes; dev builds are named
`<Name> Dev` with `<identifier>.dev` so data stays apart (`docs/app.md:250-269`,
`docs/cli.md:118-122`).

**Dock/taskbar (macOS/Windows/Linux specifics in PLATFORM-DIFFERENCES.md)**:
`App.SetBadgeCount`, `App.Dock` (badge/icon/menu/bounce/hide), activation
policy (accessory = menu-bar app), `App.SetProgressBar` per window,
`FlashFrame`, jump lists (Windows), `App.SetOpenAtLogin`/`WasOpenedAtLogin`
(`docs/app.md:210-327`).

---

## 3. Windows: the shell surface

Full options table: `docs/windows.md:34-66`. What the gallery shell should
use (native-UI window: `ui/windows.md:1-8`):

| Option | Use in the gallery |
|---|---|
| `Title`, `Width`, `Height`, `MinWidth/MinHeight`, `MaxWidth/MaxHeight` | main window; defaults 800×600 centered, DIPs |
| `StateKey: "main"` | remembers position/size/maximized state in `window-state.json` in user data (overrides X/Y/W/H after first run); give each window its own key (`"main"`, `"prefs"`) (`docs/windows.md:84-128`) |
| `Content: ui.View(app.view)` | native UI |
| `Frameless` / `TitleBarStyle: mygo.TitleBarHidden` / `HideWindowButtons` / `TrafficLightPosition` / `TitleBarHeight` | the window-chrome screens (see `DIGEST-native-ui.md` §15, `PLATFORM-DIFFERENCES.md` §1) |
| `Transparent`, `Vibrancy`, `CornerRadius`, `BackgroundColor`, `Opacity` | materials/glass demo windows |
| `Parent`, `Modal` | modal demo windows (child stays above parent, closes with it; blocks parent) (`docs/windows.md:200-218`) |
| `Panel: true` | launcher-style floating panel (`docs/windows.md:386-468`) |
| `AlwaysOnTop`, `SkipTaskbar`, `AutoHideMenuBar`, `DisableResize/…`, `Hidden`, `Maximized`, `FullScreen` | demo toggles |
| `Page` | page-only; ignored by native UI |

- **Flyouts** (frameless, backgroundless, taskbar-less child placed next to
  an anchor rectangle, may extend beyond the parent window):
  `mygo.NewFlyout(mygo.FlyoutOptions{...})` (`docs/windows.md:219-385`) —
  useful for a “native popover vs ui.Popover” comparison; it is a real
  window, unlike `ui.Popover`.
- **Panels** (`Panel: true`) for a Spotlight-like demo
  (`docs/windows.md:386-468`, `docs/launchers.md`).
- Runtime manipulation: `SetSize/SetContentSize/SetPosition/SetBounds/Center`,
  `Maximize/Unmaximize/Toggle/IsMaximized`, `Minimize/Restore`,
  `SetFullScreen`, `Hide/Show/ShowInactive`, `Focus/Blur`, `SetTitle`,
  `SetResizable/Movable/Minimizable/Maximizable/Closable`, `SetOpacity`,
  `SetAlwaysOnTop`, `SetVibrancy`, `SetVisibleOnAllWorkspaces`,
  `SetContentProtection`, `SetIgnoreMouseEvents`, `SetActiveAppearance`,
  `SetWindowButtonsTheme`, `SetProgressBar`, `FlashFrame`
  (`docs/windows.md:130-198`).
- Window events (main thread; each returns a remover): `OnClose` (can
  `PreventDefault`), `OnClosed`, `OnFocus/OnBlur`, `OnShow/OnHide`,
  `OnResize/OnMove`, `OnMaximize/OnUnmaximize/OnMinimize/OnRestore`,
  `OnEnterFullScreen/OnLeaveFullScreen`, `OnReadyToShow` (first native frame
  for native UI), `OnFileDrop` (`docs/windows.md:469-514`).
- **`Close` vs `Destroy`**: `Close` asks `OnClose` listeners (user-like);
  `Destroy` closes immediately. A view can close its own window; the frame
  ends there (`ui/windows.md:144-159`); open the replacement window first
  since the app quits when the last window closes.
- **Windows of both kinds** can coexist; a native-UI window has
  `Page() == nil` (`docs/README.md:5-17`, `docs/windows.md:22-32`).
- Screen geometry: `mygo.Screen.PrimaryDisplay()/Displays()/DisplayMatching/
  DisplayNearestPoint/CursorScreenPoint/OnDisplaysChanged`, `WorkArea`
  excludes bars/Dock (`docs/native.md:248-267`).

---

## 4. Menus, context menus, tray (shell)

Full guide `docs/menus.md`; examples `docs/menus.md:8-48`. Practical shell
template:

```go
menu := mygo.NewMenu([]*mygo.MenuItem{
    {Role: mygo.RoleAppMenu},   // macOS: app menu (left out on other OSes)
    {Label: "File", Submenu: []*mygo.MenuItem{
        {Label: "New Window", Accelerator: "CmdOrCtrl+N", Click: newWindow},
        mygo.Separator(),
        {Role: mygo.RoleClose},
    }},
    {Role: mygo.RoleEditMenu},  // cut/copy/paste/undo/redo; needed for text inputs
    {Label: "View", Submenu: []*mygo.MenuItem{
        {ID: "theme", Label: "Dark Appearance", Type: mygo.MenuItemCheckbox,
         Checked: themeDark, Click: toggleTheme},
        {Label: "RTL Layout", Type: mygo.MenuItemCheckbox, Click: toggleRTL},
        mygo.Separator(),
        {Role: mygo.RoleToggleDevTools},   // opens the native-UI inspector
        {Role: mygo.RoleToggleFullScreen},
    }},
    {Role: mygo.RoleWindowMenu},
})
mygo.App.SetMenu(menu)  // may be called in main before Run
```

- `MenuItem` fields: `Label`, `Accelerator`, `Click(item, win)`, `Type`
  (Normal/Checkbox/Radio/Separator/Submenu), `Disabled`, `Hidden`,
  `ToolTip`, `Icon`, `ID`, `Role`. Items in use can be changed via
  `SetLabel/SetEnabled/SetVisible/SetChecked/SetAccelerator/SetIcon`;
  `Menu.Append/Insert`; `Menu.ItemByID` (`docs/menus.md:33-99`).
- Roles give standard labels/shortcuts localized by MyGo, including Edit
  roles that drive focused text inputs, Format roles for the rich text
  editor, document roles, window/app roles
  (`docs/menus.md:50-86`). **Keep `RoleEditMenu` and (macOS) `RoleAppMenu`**
  or Cmd+Q / copy-paste stop working (`docs/menus.md:166-169`).
- Accelerators `CmdOrCtrl+N`, `Alt+Shift+F4`, F1–F24, named keys,
  `Num0..Num9` etc. (`docs/menus.md:374-403`). `CmdOrCtrl` = ⌘ on macOS,
  Ctrl elsewhere.
- Per-window menus (Linux/Windows) via `Window.SetMenu`; `AutoHideMenuBar`
  for Alt/F10 reveal (`docs/menus.md:160-203`).
- **Context menus in native UI** are built in the view: `ContextMenu` on an
  element, `ui.MenuButton`, or the `Menu` API (system menu)
  (`docs/ui/context-menu.md`, `docs/ui/menu-button.md`); native-UI views
  can also call `Menu.Popup` from a goroutine.
- **Tray**: `mygo.NewTray(mygo.TrayOptions{Icon, IconIsTemplate, ToolTip,
  Menu})` after ready; `OnClick/OnRightClick`, `SetIcon/SetMenu/SetToolTip/
  SetTitle`, `Destroy`; macOS template icons and titles, Linux AppIndicator
  limits (see PLATFORM-DIFFERENCES.md §6); a tray does **not** keep the app
  running (`docs/menus.md:246-372`).
- **Dock menu** (macOS): `App.Dock.SetMenu`.
- Menu state ↔ app state: items toggle `Checked` before `Click`; for a
  checkbox bound to app state, set `Checked` from state when creating and
  update `item.SetChecked` from the view or callbacks so menus made once stay
  in sync (`docs/menus.md:38-44,88-99`; i18n relabel example
  `docs/i18n.md:170-181`).

---

## 5. Desktop APIs relevant to the showcase

Guide `docs/native.md` (all callable from any goroutine; blocking ones from
goroutines).

- **Dialogs** (`docs/native.md:7-48`): `mygo.Dialog.Open(OpenDialogOptions)`,
  `.Save`, `.Message(MessageOptions{Parent,Type,Message,Detail,Buttons,
  CheckboxLabel})` → `res.Button`, `.Error(title, msg)`. Blocking: call from
  a goroutine; `Parent` makes a sheet on macOS.
- **Notifications** (`docs/native.md:50-155`): `mygo.NewNotification(
  NotificationOptions{Title,Body,ID,Group,Sender,...})`, `Show`, `Close`,
  `OnClick`, `mygo.ClearNotifications()`, `NotificationsSupported()`,
  `ErrNotificationsDenied`; macOS needs a packaged app; `OnNotificationClick`
  for IDs clicked after relaunch. Good “System” screen demo.
- **Clipboard** (`docs/native.md:157-180`): `mygo.Clipboard.WriteText/
  ReadText/WriteHTML/WriteImage/ReadImage/AvailableFormats/Clear`; richer
  `Write(transfer.Data)`/`Read(formats...)`. In native UI also
  `ui.Services`/`c.ReadClipboard/WriteClipboard` (`DIGEST-native-ui.md` §4).
- **Shell** (`docs/native.md:182-246`): `Shell.OpenExternal`,
  `OpenPath`, `ShowItemInFolder`, `TrashItem`, `Beep`, `FileIcon(path,size)`,
  `InstalledApps()`, `LaunchApp(app)`. Great for a “Shell integration”
  screen; remember `InstalledApps` reads the disk (off main thread) and icons
  cost a few ms on the main thread.
- **Theme/dark mode/preferences** (`docs/native.md:269-324`):
  `mygo.Theme.SetSource(ThemeSystem|ThemeLight|ThemeDark)`, `IsDark`,
  `OnUpdated`, `Theme.Preferences()` → `{Accent, ReduceMotion,
  ReduceTransparency, HighContrast, TextScale}`. Inside native UI prefer
  `c.Theme()`/`c.Preferences()` (follows automatically).
- **Power** (`docs/native.md:326-345`): `Power.KeepAwake(reason, display)`,
  `OnSuspend/OnResume/OnLockScreen/OnUnlockScreen`, `IsOnBattery`, `IdleTime`
  — optional demo.
- **Now Playing / media keys** (`docs/native.md:347-394`), **network status &
  proxies** (`docs/native.md:395-486`), **secrets** (`docs/native.md:487-552`:
  macOS Keychain / libsecret / Credential Manager), **watching files**
  (`docs/native.md:553-650`), **global shortcuts** (`docs/native.md:651-676`)
  — peripheral for the gallery but each is a plausible “system” screen.
- **Browsing data / cookies** only matter for web pages (`docs/app.md:329-396`).

---

## 6. Settings / preferences for the gallery app

There is **no built-in settings store** (a documented gap — `DOC-GAPS.md`).
Documented building blocks:

- Window geometry/state: `WindowOptions.StateKey` → `window-state.json` in
  user data, or a custom `WindowStateStore` (`docs/windows.md:84-128`).
- App data files: `App.Path(PathUserData)` + your own JSON/`plugins/sqlite`
  (`docs/app.md:229-248`).
- Theme preference: `mygo.Theme.SetSource` before `Run` restores a saved
  appearance (`docs/native.md:281-282`); the theme itself must be applied in
  the view every frame (`ui/styling.md:130-141`).
- Language: `App.SetLocale(tag)` persists for next launches; `App.Locale()`,
  `App.Languages()`, `i18n.Autonym` for a language menu; `OnLocaleChanged`
  (`docs/i18n.md:183-227`).
- RTL/density/accent toggles: keep in your own state and apply in the view
  (`ui/styling.md`, `ui/right-to-left.md`).
- Suggested: one `settings` struct saved to `<PathUserData>/settings.json`
  on change (debounced) — an app-level pattern not covered by docs.

---

## 7. i18n wiring (app level)

`docs/i18n.md`; the native-UI specifics are in `DIGEST-native-ui.md` §12.
Shell checklist:

- `i18n` block in `mygo.json`; `locales/en.json` (source) + other languages;
  ARB/ICU messages with `@key` metadata; generated `catalog_gen.go` committed
  (`docs/i18n.md:25-152`).
- Import the generated package (blank import if unused directly) so its
  catalogs register (`docs/i18n.md:143-147`); import MyGo’s own translation
  packages for ja/zh-Hans/zh-Hant if shipping those (`docs/i18n.md:340-366`).
- Window titles/menu labels set once must be reset in `App.OnLocaleChanged`
  (`docs/i18n.md:170-181`); views rebuild automatically.
- `mygo dev -lang de`, pseudo locales `en-XA`/`ar-XB` to test layout and RTL
  before translation (`docs/i18n.md:427-441`).
- `mygo i18n check` validates catalogs (`docs/cli.md:186-195`).

---

## 8. CLI & dev loop (native UI project)

`docs/cli.md`; install options: `go tool mygo …` (native template), or
`go install github.com/egoist/mygo/cmd/mygo@latest`
(`docs/cli.md:5-39`). `mygo doctor` checks Go/Bun/webview/Xcode/NSIS/signing
(`docs/cli.md:212-219`).

| Command | Use |
|---|---|
| `mygo init -template native <dir>` | new native project (`docs/cli.md:44-71`) |
| `go tool mygo dev` | live rebuild+restart on Go/config/icon/resource/catalog change; keys `r` rebuild, `c` clear, `q` quit, `h` help; dev app named `<Name> Dev`; `-web` runs in browser; `-lang` forces a language (`docs/cli.md:90-140`) |
| `go tool mygo build` | production build to `build/<os>-<arch>`; `-platform darwin/universal,windows/amd64,...`, `-debug` (keeps inspector), `-o`, `-sign`, `-skip-dmg`, `-skip-notarize`, `-upload` (`docs/cli.md:142-167`) |
| `go tool mygo build -platform web` | static wasm site (`docs/cli.md:152-156`, `docs/ui/browsers.md`) |
| `go tool mygo generate` | write generated code (TS client for pages; catalog functions for i18n) (`docs/cli.md:169-185`) |
| `go tool mygo i18n check` | validate catalogs (`docs/cli.md:186-195`) |
| `go tool mygo migrate-ui .` / `go tool mygo vet .` | source migration to checked elements and build-lifetime vet (`docs/ui/migration.md:7-27`); **`mygo vet` is not listed in `docs/cli.md`** (doc gap) |
| `go tool mygo keygen` | keys for auto-updates (`docs/cli.md:197-211`) |

Environment variables worth knowing (`docs/cli.md:225-237`):
`CGO_ENABLED` (defaults 0), `MYGO_LDFLAGS`, `MYGO_INSPECTOR=1`,
`MYGO_UPDATER_PRIVATE_KEY`, `MYGO_ENV=production`, `MYGO_LOCALE`,
`MYGO_WINDOWS_CERTIFICATE_PASSWORD`; plus runtime `MYGO_GPU`,
`MYGO_FRAME_STATS`, `MYGO_DIRECTION` (`ui/rendering.md:19-24`,
`ui/right-to-left.md:110-119`).

Dev loop for the gallery on macOS: `go tool mygo dev`; production check
`go tool mygo build` (inspector removed; ~250 KB smaller,
`docs/ui/inspector.md:25-30`).

---

## 9. Packaging & distribution (all three OSes from one machine)

`docs/distribution.md`; GitHub Actions `docs/github-actions.md`.

```sh
go tool mygo build \
  -platform darwin/universal,windows/amd64,windows/arm64,linux/amd64,linux/arm64
# outputs in build/<os>-<arch>/ (config out; default for native template is build)
```

| Platform | Outputs | Notes |
|---|---|---|
| macOS | `MyGo Explorer.app` (signed ad-hoc by default) + `.dmg`; universal → one dmg | Gatekeeper blocks ad-hoc apps elsewhere; set `macos.signingIdentity` + `macos.notarize.keychainProfile` to ship; `.icon`/`Assets.car` for macOS 26 layered icons; `minimumSystemVersion` default 12.0 (`docs/distribution.md:56-371`, `docs/configuration.md:112-126`) |
| Windows | `MyGo Explorer.exe` + `my-go-explorer-setup-0.1.0-amd64.exe` (NSIS, per-user in `%LOCALAPPDATA%\Programs`, Start-menu shortcut, uninstaller, URL schemes/file types; silent `/S`) | NSIS auto-downloaded on Windows, install on macOS/Linux (`brew install makensis`, `apt install nsis`); signing optional (`docs/distribution.md:372-494`) |
| Linux | executable named by `slug`, `.desktop`, icon, `install.sh` archive, `.deb` in `/opt/<slug>`; `linux.webview:false` drops WebKitGTK dependency | keep the slug stable; `linux.command` for a CLI command; needs GTK 3 (`docs/distribution.md:495-640`) |

- **Resources**: everything in `resources/` + `resources` config copied into
  the app; read at run time via `App.Path(mygo.PathResources)`; per-platform
  subdirectories `resources/<goos>/…` (`docs/distribution.md:117-182`).
- **Languages**: catalogs declare app languages per OS automatically
  (`docs/distribution.md:641-679`).
- **URL schemes/file types**: config → registered per OS
  (`docs/distribution.md:680-687`).
- **Auto-updates** (optional): `updates` config with `publicKey` + `github`
  or `url`; `mygo keygen`; signed archives; Sparkle-like update window
  (web page or native UI via `plugins/updater/native`) (`docs/updates.md`,
  `docs/configuration.md:96-110`; plugin page `docs/plugins/updater.md`).
- **GitHub Actions**: tag-triggered workflow creates a draft release, then
  a matrix builds macOS (macos-latest), Windows and Linux (ubuntu-latest,
  cross-compiled) and uploads; native-UI projects drop Bun/setup-bun and run
  `go tool mygo build -platform "…" -upload`
  (`docs/github-actions.md:10-119`). Signing secrets: macOS cert+notary,
  `MYGO_WINDOWS_CERTIFICATE_PASSWORD`, `MYGO_UPDATER_PRIVATE_KEY`
  (`docs/github-actions.md:120-330`).

---

## 10. Suggested shell blueprint for MyGo Explorer

```
main.go      settings load, App.WhenReady → NewWindow(Content: ui.View(app.view))
             App.SetMenu(shell menu), tray (optional), single-instance lock
app.go       app struct: settings, router *ui.Router, screen states, handles,
             theme overrides (dark/accent/spacing/RTL/reduce-motion demo)
view.go      view(c): c.SetTheme(app.theme(c)); Row{Sidebar; Column{Toolbar;
             router.View(...)}} + overlays/toasts; per-screen calls
screens/     one file per group (buttons, choices, text, collections,
             date/color, overlays, navigation, motion/drawing, charts/editor/
             markdown/richtext packages, system/appearance, platform matrix)
menu.go      menu template + OnLocaleChanged relabel + per-window menus
settings.go  JSON in App.Path(PathUserData); window geometry via StateKey
```

Shell recommendations:

- One `ui.Sidebar` listing component groups (stable IDs = router paths);
  `Toolbar` for theme/density/RTL/reduce-motion toggles; `router.View` for
  the content; `ui.Tabs` or segmented control inside a screen to show
  variants.
- Include a **“Window chrome”** demo that opens extra windows (hidden title
  bar + `c.TitleBar()` + `DragWindow`, frameless+corner radius+vibrancy,
  modal child, flyout, panel) — this is where OS differences are most
  visible.
- Include a **“System integration”** screen: dialogs, notifications,
  clipboard, shell, displays, `c.Preferences()`, `c.Locale()/Region()`.
- Use `StateKey` per window kind; save app settings to user data; keep the
  optional heavy packages (chart/editor/markdown/richtext/glass/loading) on
  their own screens so startup stays fast.
- Tests: `ui.Tester` per screen (no window), plus manual/CI runs on each OS
  (see `GOTCHAS.md`).

---

## 11. App-level gotchas (short list; full in `GOTCHAS.md`)

- Windows only after ready; app APIs before `Run` panic.
- Last window closes → app quits: create the next window before closing the
  current one (`ui/windows.md:144-159`).
- A blocking dialog called from a view/event blocks the UI — use a goroutine
  (`docs/native.md:9-13`, `docs/ui/overlays.md:99-100`).
- `SetMenu` roles: without `RoleEditMenu` text inputs lose menu copy/paste;
  without `RoleAppMenu` (macOS) Cmd+Q/About/Hide disappear
  (`docs/menus.md:166-169`).
- On macOS a menu set once keeps its labels; relabel on
  `App.OnLocaleChanged` (`docs/i18n.md:170-181`).
- `mygo dev` names the dev app `<Name> Dev` with `.dev` identifier — data
  and single-instance lock are separate from the packaged app
  (`docs/cli.md:118-122`).
- Release builds drop the native-UI inspector unless `-debug`/`MYGO_INSPECTOR`
  (`docs/ui/inspector.md:25-30`).
- Linux packages need `linux.webview: false` to avoid requiring WebKitGTK for
  a native-UI-only app (`docs/configuration.md:148`,
  `docs/distribution.md:495-520`).
