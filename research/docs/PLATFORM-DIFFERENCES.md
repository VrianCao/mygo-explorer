# Platform differences — native UI and app chrome on macOS vs Windows vs Linux

Prepared by docs-analyst (phase 0). Sources: repo Markdown (`reference/mygo/docs/**`,
checkout `b553a90`, v0.7.1), the cross-platform table in
`docs/architecture.md:4550-4620`, and targeted verification in
`reference/mygo/ui/*.go` and `reference/mygo/*.go`. Items marked **UNVERIFIED**
or **THIN** are documented ambiguously or only in source; see
`DOC-GAPS.md`.

Why this matters for MyGo Explorer: MyGo **draws native UI itself** (Metal /
D3D11 / OpenGL), so widget pixels are largely identical across OSes by
design. The real cross-OS differences come from four places, in this order:

1. **System window chrome** drawn *around* the view (title bars, buttons,
   menus, tray, materials).
2. **Desktop preferences** the theme follows (dark mode, accent, contrast,
   text scale, reduce motion, transparency) and **system fonts / text
   engines**.
3. **Platform keyboard/mouse conventions** baked into widgets (shortcut
   modifiers, list paging, context-menu setup, text editing keys).
4. **Backends, packaging and feature availability** (webview, tray library,
   Wayland, signing, notification APIs).

The app can detect most of these at run time: `c.Preferences()`,
`c.Vibrancy()`, `c.Locale()`, `c.Region()`, `runtime.GOOS`,
`mygo.WebViewAvailable()`, `mygo.NotificationsSupported()`. The gallery
should show the same screens everywhere and annotate the differences.

---

## 0. Quick matrix

| Area | macOS | Windows | Linux |
|---|---|---|---|
| Native-UI renderer | Metal | Direct3D 11 (WARP software if no GPU) | OpenGL 3.3/ES 3.0; cairo CPU fallback |
| Text engine / system font | Core Text / SF (default UI size 13) | DirectWrite / Segoe UI (size 14) | Pango / GTK interface font (size 14) |
| Window chrome drawn by view | Hidden title bar: traffic lights; `c.TitleBar()`; `TrafficLightPosition` | Caption buttons drawn in a layered child window; `SetWindowButtonsTheme` | GTK title buttons in header bar; none under some Wayland compositors |
| Materials (window vibrancy) | All `NSVisualEffect` materials + Liquid Glass (macOS 26+) | Windows 11 22H2+: Mica/Acrylic/Tabbed; Liquid Glass → Acrylic; none on Win 10 | None |
| `c.Vibrancy()` | true when material | true in Win 11 22H2+ window with a material | false |
| Accent color | `NSColor.controlAccentColor` | DWM `AccentColor` | settings portal (GNOME 47/KDE); may be absent |
| Text scale | 1 (none) | `TextScaleFactor` | GNOME `text-scaling-factor` (portal) |
| Reduce transparency | yes | yes | no (always false) |
| Menu bar | App-level, default menu installed | Per-window Win32 bar; none by default | Per-window GTK bar; none by default |
| Tray | `NSStatusItem`, template icons, title text | Notification area icon | AppIndicator (needs `libayatana-appindicator3`), menu-only |
| Notifications | UserNotifications; **packaged apps only**; permission prompt; persist in Notification Center | Balloons (toasts); `Group`/`Sender` ignored | D-Bus `org.freedesktop.Notifications`; `Group`/`Sender` ignored |
| Webview available | WKWebView always | WebView2 Runtime needed (Win 11 has it) | WebKitGTK 4.1/4.0 + GTK 3 needed |
| Webview needed by native UI | no | no | no (GTK 3 alone) |
| Window position honored | yes | yes | X11 yes; **Wayland compositor ignores position** |
| Window resize borders without title bar | the window’s own | invisible outside the window + top child window | outer 5 px of the page |
| Accessibility backend | NSAccessibility elements | UI Automation fragments | ATK objects → AT-SPI |
| Packaging | `.app` + `.dmg`; sign/notarize on macOS only | `.exe` + NSIS per-user installer | binary + `.desktop` + tar.gz + `.deb` |
| Min OS (docs/config defaults) | macOS 12.0 (`macos.minimumSystemVersion`) | Windows 10/11 | unknown distribution floor; GTK 3 |
| Continuous (Apple) rounded corners | yes | no (circular) | no (circular) |

Sources: `ui/rendering.md:1-21`, `ui/text.md:147-194`, `ui/theme.go:98-103`,
`ui/paint.go:45-54`, `docs/architecture.md:4550-4620`, `docs/README.md:176-191`,
`docs/windows.md:34-66,130-198`, `docs/menus.md`, `docs/native.md`,
`docs/distribution.md:26-55`.

---

## 1. Window chrome, title bars, frameless windows

Native-UI windows take the same `WindowOptions` as page windows
(`ui/windows.md:1-8`; full table `docs/windows.md:34-66`).

| Option | Behaviour |
|---|---|
| default | system title bar, resizable, 800×600 centered (`docs/windows.md:36-37`) |
| `TitleBarStyle: mygo.TitleBarHidden` | title bar hidden, window buttons float over the content; the view draws the bar under them. `c.TitleBar()` returns `{Height, Left, Right}` of the room the controls take (zero in full screen); `DragWindow()` makes elements drag the window, double-click zooms/minimises as a title bar (`ui/windows.md:20-33`, `ui/context.go:347-358`) |
| `HideWindowButtons: true` | system buttons hidden too; `c.TitleBar()` is zero; the view draws its own calling `Minimize/Maximize/Unmaximize/Close`; **the window keeps its resizable top edge** (`ui/windows.md:38-42`) |
| `Frameless: true` | no title bar/borders; page or view draws everything; with a hidden title bar the resize borders are platform-specific: macOS the window’s own, Linux the outer 5 px of the page, Windows invisible outside the window plus a top child window (`docs/windows.md:51`; architecture table rows “resize borders without a title bar”, “hidden title bar”) |
| `TrafficLightPosition` | macOS only — moves the traffic lights (`docs/windows.md:53`) |
| `TitleBarHeight` | Linux/Windows — height of the title bar the page draws (page-only feature; native UI uses `c.TitleBar()`) (`docs/windows.md:54`) |
| `CornerRadius` | rounds frameless content/material; macOS cuts content and material, Windows 11 rounds via DWM (`docs/windows.md:57`, `ui/windows.md:114-135`) |
| `SetWindowButtonsTheme(mygo.ThemeDark)` | **Windows only** — caption buttons drawn for a dark background in a light app (`docs/windows.md:181-185`) |
| `SetActiveAppearance(true)` | macOS only — keeps a clear-glass panel drawn active; uses a **private AppKit call**; leave off for Mac App Store (`docs/windows.md:176-180`, `ui/windows.md:137-142`) |
| `Panel: true` | launcher/quick-entry panel floating above all apps: `NSPanel` nonactivating (macOS), Wayland `gtk-layer-shell`/sticky utility (Linux), `WS_EX_TOOLWINDOW` owned by a hidden window (Windows) (architecture table “panels”) |
| `Vibrancy`, `Transparent` | see §3 |

Documented asymmetries to design around:

- A **frameless or hidden-titlebar Windows window has no room for a menu
  bar**: Alt/F10 open its menus in a popup from the top-left corner
  (`docs/menus.md:192-198`).
- On **Linux**, a hidden title bar hides the menu bar (like
  `AutoHideMenuBar`); a frameless window shows the bar above the page
  (`docs/menus.md:192-198`).
- On **Wayland**, the compositor decides window placement and draws
  decorations: `SetPosition` is ignored and `Bounds` excludes the
  compositor’s decorations (`docs/windows.md:148-152`); `DisableShadow`
  keeps a frameless/hidden-titlebar window without GTK’s shadow and border
  (`docs/windows.md:60`).
- Window icons (`SetIcon`) apply on Linux/Windows only; macOS ignores them
  (architecture table “window icon”).
- **Snap layouts / taskbar progress / thumbnails** are Windows features;
  Dock behaviours are macOS-only (`docs/app.md:271-287`).

---

## 2. Fonts, text, sizes

- Text is laid out and drawn by the **system text engine** (Core Text /
  DirectWrite / Pango) in the **system font** (SF / Segoe UI / the GTK
  interface font), falling back per script and emoji, with bidi handled by
  the system (`ui/text.md:147-160`). Fonts installed per OS therefore show,
  and the *same* `ui.Text` renders in a different typeface on each OS — the
  most visible cross-platform difference in a gallery.
- **Default theme font size differs**: `13` on macOS, `14` elsewhere
  (`ui/theme.go:98-103`, source-verified). **Not documented** — do not
  hard-code 13/14 in screens; use `t.FontSize`/`t.Rem(n)` (`ui/styling.md:146-152`).
- `Font("monospace")` resolves to the OS monospaced font; `ui.FontFamilies()`
  lists what the OS has (slow first call: tens of ms with hundreds of fonts;
  browsers cannot list system fonts) (`ui/text.md:172-196`).
- Subpixel antialiasing (ClearType) is used **only over an opaque
  background**; text over a vibrancy material is grayscale-antialiased
  (`ui/windows.md:103-106`).
- **Text scale**: Windows’ accessibility text size and GNOME’s text size
  multiply the theme’s `FontSize`; macOS has no text scale
  (`docs/native.md:284-308`, `ui/preferences.go:39-80`). The gallery should
  include a screen showing a large-text-mode comparison.
- Menus, dialogs and native controls use the system’s font and language;
  MyGo’s own strings follow the app language on all platforms
  (`docs/i18n.md:340-382`).
- Font height metrics differ per OS; tests must not assert pixel sizes
  shared across platforms (use `Tester` on one OS, see `GOTCHAS.md`).

---

## 3. Appearance: dark mode, accent, contrast, materials, Liquid Glass

**Dark mode**: `mygo.Theme.SetSource(ThemeSystem|ThemeLight|ThemeDark)`
(also before `Run`), `Theme.IsDark`, `Theme.OnUpdated`; native-UI frames
rebuild automatically when the appearance changes (`docs/native.md:269-282`,
`ui/styling.md:128-129`). Platform sources: `NSApp` appearance; Windows
title bars/menus/native UI and page `prefers-color-scheme`; Linux
`gtk-application-prefer-dark-theme` with a special case that swaps a
Yaru/Yaru-dark theme pair so GTK/WebKitGTK do not misread the light variant
(architecture table “`Theme.SetSource`”).

**Desktop preferences** (`c.Preferences()`, `Theme.Preferences()`;
`docs/native.md:284-324`, `ui/styling.md:163-178`):

| Preference | macOS | Windows | Linux |
|---|---|---|---|
| `Accent` | `NSColor.controlAccentColor` (10.14+) | DWM `AccentColor` | settings portal (GNOME 47/KDE); may be absent (`A == 0`) |
| `HighContrast` | Increase Contrast | contrast themes / `SPI_GETHIGHCONTRAST` | portal higher contrast or a HighContrast GTK theme |
| `TextScale` | always 1 | `TextScaleFactor` | GNOME `text-scaling-factor` |
| `ReduceMotion` | Reduce Motion | animation effects | `gtk-enable-animations` / GNOME animations off |
| `ReduceTransparency` | Reduce Transparency | transparency effects off | no concept → `false` |

MyGo’s default theme applies them (`ui/preferences.go:39-80`,
`ui/runtime.go:506-525`): accent recolors primary buttons, checks, focus
rings, selection; `AccentText` becomes near-black when the accent is light
(luma > 165, e.g. yellow); high contrast darkens borders/muted text and
makes the focus ring opaque; text scale multiplies `FontSize`. These derived
rules are **not in the docs** (see `DOC-GAPS.md`).

**Window materials and Liquid Glass** (`docs/windows.md:56`,
`ui/windows.md:79-142`, `vibrancy.go`):

| Material | macOS | Windows 11 22H2+ | Linux |
|---|---|---|---|
| `VibrancyWindow/Content/Sidebar/Header/Titlebar/UnderWindow/UnderPage` | `NSVisualEffectView` materials | Mica/Tabbed → Mica, Acrylic → HUD; content materials map to Mica | none (`c.Vibrancy()==false`) |
| `VibrancyMenu/Popover/HUD/Sheet/Tooltip/Selection/FullScreenUI` | all materials | transient → Acrylic | none |
| `VibrancyMica/Acrylic/Tabbed` (Win 11 system backdrops) | Mica/Tabbed → under-window, Acrylic → HUD | native | none |
| `VibrancyGlass` / `VibrancyGlassClear` (macOS 26 Liquid Glass) | `NSGlassEffectView`; before macOS 26 → popover/HUD material | Acrylic | none; clear glass stays clear only when the window is drawn active (`SetActiveAppearance`, private API) |

- `c.Vibrancy()` says whether a material actually shows; elsewhere draw a
  background instead (`ui/context.go:360-378`, `ui/windows.md:79-101`).
- Windows materials require a window **created with** one (SetVibrancy only
  changes such windows), and such windows have **no menu bar** (Alt/F10 popup)
  (`docs/windows.md:56,159-162`).
- **Cross-platform Liquid Glass is the `plugins/glass` package**, not window
  vibrancy: `glass.Glass{}`/`ScrollEdge{}`/`Blur{}` are materials drawn by
  MyGo’s own shaders on GPU or CPU, so they look the same on macOS, Windows
  and Linux (`docs/plugins/glass.md:1-12,190-203`). This is the right tool
  for a toolbar-over-scrolling-content demo on all three OSes; window
  `Vibrancy` is the right tool to demo *system* materials.
- Rounded corners: macOS uses **continuous** (Apple) corner curvature, other
  platforms circular (`ui/styling.md:146-150`, `ui/paint.go:45-54`) — visible
  in a close-up comparison.

---

## 4. Scrolling, scroll bars, edges

- Scroll bars are **drawn by MyGo**, overlay-style, width `ScrollbarWidth`
  (default 6 DIP), color `Scrollbar`; they appear while the pointer is over
  the container, take no room, and the vertical one is on the left in RTL
  (`ui/scroll.md:83-101`, `ui/theme.go:47-51`). So they do **not** inherit
  native scrollbar look (macOS overlay scrollbars, Windows 11 bars, GTK
  bars) — call this out in the comparison screen.
- macOS-content scroll edge effects (content fading/frosting under a bar)
  are provided by `glass.ScrollEdge{}` on every platform
  (`docs/plugins/glass.md:78-120`).
- Input differences: **pinch** is reported on macOS, Linux Wayland and
  browsers; on Windows a touchpad pinch arrives as `Ctrl`+scroll
  (`ui/input.md:210-228`). On Linux a **touchscreen** scrolls/pinches like a
  touchpad, tap clicks, long-press (~0.5 s) right-clicks (`ui/input.md:224-228`).
- Wheel notch distance differs by platform; a test/demo that maps a notch to
  a fixed zoom step must account for it (`ui/input.md:236-243` comment in
  the example).
- Reduced motion turns wheel glide into instant scrolling
  (`ui/scroll.md:14-16`).

---

## 5. Keyboard, modifiers, focus conventions

`ui.Cmd` is **Command on macOS, Control elsewhere**
(`ui/keys.go:105-116`, documented `ui/input.md:150-151`). Menu accelerators
use `CmdOrCtrl` (`docs/menus.md:374-388`).

Platform-specific conventions implemented by widgets (source-verified):

| Behaviour | macOS | Windows/Linux |
|---|---|---|
| Router back/forward | ⌘[ / ⌘], touchpad swipe | Alt+←/→ (and the mouse back/forward keys everywhere) (`ui/router.go:589-592`, `ui/navigation.md:82-99`) |
| List PageUp/PageDown | scroll the list | move/extend the selection (`ui/list.go:1150-1170`, `ui/list.md:86-89`) |
| Multi-select modifier | ⌘-click adds, ⇧-click extends | Ctrl-click adds, Shift-click extends; Ctrl+arrow moves without choosing, Ctrl+Space toggles (`ui/list.md:90-97`) |
| Drag & drop copy/move modifiers | Option = copy, Cmd = move | Ctrl = copy, Shift = move (`ui/drag-and-drop.md:131-135`) |
| Text input editing keys | Option/Cmd+arrows, Cmd+Backspace, Ctrl-A/E/B/F/N/P/D/H/K; focus leaves Alt+arrows to navigation | other platforms leave Alt+arrows (back/forward) and function keys to the app (`ui/input.md:161-165`) |
| Text-input context menu | Cut, Copy, Paste, Select All | Windows: Undo + Cut/Copy/Paste/Delete + Select All; Linux: Cut/Copy/Paste/Delete + Select All (`ui/menu.go:525-539`) |
| Context menu opens | on press (right/Control-click) | on release on Windows (`ui/menu.go:340-360`) |
| Developer tools / inspector | ⌘⌥I, ⇧⌘C | Ctrl+Shift+I, Ctrl+Shift+C (`ui/inspector.md:9-13`) |
| Shortcuts on non-Latin layouts | physical key position matches US keys with Cmd/Ctrl/Alt/Super (`ui/input.md:156-159`) | same |

Keyboard focus model is identical everywhere: Tab/Shift+Tab, arrows in
focus groups, Enter/Space activation, Ctrl/Option word-wise movement
(§ input page). Accessibility navigation expectations are the OS’s (VoiceOver
vs Narrator/NVDA vs Orca) — MyGo exposes roles/states per platform backend
(architecture table “native UI accessibility”).

---

## 6. Menus and the tray

- **Menu bar**: macOS = application menu bar, a default menu is installed
  until the app sets its own; Linux/Windows = per-window bars, **none by
  default**; `App.SetMenu` gives every window without its own a menu;
  `Window.SetMenu` per window; `App.SetMenu(nil)` removes
  (`docs/menus.md:160-176`).
- Roles with macOS-only meanings are **left out on other platforms**, so one
  template serves all (`docs/menus.md:85-86`): e.g. `RoleAppMenu`,
  `RoleWindow`, `RoleHelp`, About/Hide/Services/StartSpeaking.
- Windows 11 draws MyGo-rendered menus in the system 11 style (roomier
  items, rounded highlights, faint shortcuts); Windows 10 uses native menu
  bitmaps; macOS uses NSMenu; Linux GTK menus
  (`docs/menus.md:176-181`, architecture “menu item icons”).
- `AutoHideMenuBar` (Linux/Windows only): Alt alone/F10 reveals; on Linux
  first menu opens, on Windows focus enters the bar; shortcuts work
  throughout (`docs/menus.md:182-190`). Full screen hides the bar; Alt/F10
  still pop it up (Windows popup, Linux bar) (`docs/menus.md:200-203`).
- **Tray icons**: macOS `NSStatusItem` (template icons tinted; optional
  title text; user can ⌘-drag to reorder; `PopUpMenu`, `Tray.Bounds`);
  Windows notification area (user chooses overflow; IDs keep choices);
  Linux AppIndicator — **menu required**, activation via `OnClick` only on
  newer lib releases (double-click), needs `libayatana-appindicator3`;
  `NewTray` errors without it (`docs/menus.md:246-372`, `docs/README.md:185`).
- Menu item **icons** differ: macOS NSImage 16 pt (template tinting);
  Windows 11 own icon column, Win 10 check-column bitmaps, no icon on the
  bar items; Linux GTK in menu bars/context menus, none on bar items, tray
  icons via DBusMenu (`icon-data`) (`docs/menus.md:101-158`).

---

## 7. Dialogs, file panels, notifications

- `mygo.Dialog.Open/Save/Message/Error` are the **system** dialogs; `Parent`
  makes them sheets on macOS; all block → call from a goroutine
  (`docs/native.md:7-48`, `ui/overlays.md:99-100`). Buttons/Enter/Escape
  conventions differ per OS (macOS default/cancel buttons, Windows
  custom buttons).
- **Notifications**: macOS UserNotifications — **packaged apps only**
  (`mygo dev`/`mygo build` bundles count), first notification asks
  permission and `Show` waits; `ErrNotificationsDenied`; persist in
  Notification Center until `Close`/`ClearNotifications`; IDs allow clicks
  after relaunch; `Group`/`Sender` (communication notifications with
  entitlement) macOS-only. Linux D-Bus (no Group/Sender, CloseNotification);
  Windows balloons (no Group/Sender). `NotificationsSupported()` reports
  (`docs/native.md:50-155`).
- **Communication notifications** require an Apple App ID capability,
  `INSendMessageIntent`, entitlement + provisioning profile — macOS only
  (`docs/native.md:113-155`).

---

## 8. Window management, panels, taskbar/Dock

| Feature | macOS | Windows | Linux |
|---|---|---|---|
| position honored | yes | yes | X11 yes, Wayland no |
| `SkipTaskbar` | ignored | `ITaskbarList::DeleteTab` | skip-taskbar hint |
| visible on all workspaces | Spaces behaviour | ignored | `gtk_window_stick` |
| window icon | ignored | `WM_SETICON` at DPI | `gtk_window_set_icon` |
| progress bar | Dock tile (NSBoxes) | `ITaskbarList3` per window | Unity launcher entry (app-wide) |
| badge count | Dock label | **not shown** | Unity launcher API count |
| FlashFrame | Dock bounce | `FlashWindowEx` | urgency hint |
| Dock menu / jump list | Dock menu (macOS) | jump lists (Windows) | none |
| start at login | login item (packaged) / launch agent | Run key | XDG autostart |
| recent documents | NSDocumentController | `SHAddToRecentDocs` | GtkRecentManager |
| URL scheme registration | Info.plist (config only) | HKCU\Software\Classes | desktop entry + mimeapps.list |
| file associations | CFBundleDocumentTypes | ProgIDs at install | desktop entry MimeType |
| skip screenshot/protection | yes | yes | ignored |

Sources: architecture table `docs/architecture.md:4550-4620`; `docs/app.md:182-327`;
`docs/windows.md:154-198`.

---

## 9. Language, regional formats, RTL

- The **language the app shows** is resolved the same way everywhere but
  from different OS data: macOS global `AppleLanguages` (not the app’s),
  Linux `LANGUAGE`/`LC_ALL`/`LC_MESSAGES`/`LANG` (read once, no change
  notifications), Windows `GetUserPreferredUILanguages` + `WM_SETTINGCHANGE`
  (`docs/i18n.md:183-219`; architecture “preferred languages”).
- **Kept language**: macOS app defaults `AppleLanguages`; Windows/Linux a
  `locale` file in `App.Path(PathUserData)`; browsers `localStorage`
  (`docs/i18n.md:212-219`).
- **Regional formats**: macOS autoupdating locale (first weekday, `j`
  skeleton hour cycle); Windows `GetLocaleInfoEx`; Linux `nl_langinfo_l`,
  else by region; CLDR fallbacks where the OS has no data
  (`docs/i18n.md:250-276`; architecture “regional formats”). Date/time
  controls follow the region on every platform (`docs/i18n.md:272-276`).
- **RTL**: the window takes the app language’s direction on every platform
  (`docs/ui/right-to-left.md`); `MYGO_DIRECTION=rtl|ltr` overrides;
  on Linux GTK’s own widgets (menus, dialogs) agree (`docs/i18n.md:220-228`).
- **Web-view language**: WebView2 at environment creation (next launch),
  WebKitGTK live, WKWebView next launch (`docs/i18n.md:465-471`).
- Packaging declares languages per platform: `CFBundleLocalizations` +
  `.lproj` folders (macOS), desktop-entry `Name[xx]`/`Comment[xx]` (Linux),
  NSIS installer languages + version strings (Windows)
  (`docs/distribution.md:641-679`).

---

## 10. Mixed native UI + web pages (only if the gallery shows it)

- Availability: WKWebView always on macOS; WebKitGTK 4.1/4.0 + GTK 3 on
  Linux; WebView2 Runtime on Windows 10 (Windows 11 bundles it);
  `mygo.WebViewAvailable()` works from any goroutine and before `Run`
  (`docs/README.md:176-191`; architecture “WebViewAvailable”).
- A native-UI-only app needs **none** of them; a `ui.WebView` element also
  needs the webview (`ui/web-view.md:1-10,46-70`, `docs/windows.md:161-164`).
- Web-view behaviour that differs: cookie APIs (macOS default data store,
  Linux cookies.sqlite + WebKitGTK ≥2.42, Windows WebView2 needs a
  web view/process; changes polled up to 2 s), printing/PDF engines,
  downloads, permissions, custom-scheme origin (`scheme://host` vs
  `http://scheme.localhost` on Windows), `Page.ProcessID` (0 on Linux),
  browser accelerator keys (Windows WebView2 only with inspector), etc.
  Full table: architecture `docs/architecture.md:4550-4620`. Out of scope
  for a native-UI-only gallery.

---

## 11. Packaging & distribution

| | macOS | Windows | Linux |
|---|---|---|---|
| Output | `My App.app` + `my-app-0.1.0-arm64.dmg` (universal → one dmg) | `My App.exe` + `my-app-setup-0.1.0-amd64.exe` | `my-app`, `.desktop`, icon, archive + `install.sh`, `my-app_0.1.0_amd64.deb` |
| Signing | ad-hoc by default; Developer ID + notarization + stapling for distribution; **needs macOS** | certificate or `signCommand`; SmartScreen otherwise | no signing step |
| Install location | drag to Applications (dmg) | per-user `%LOCALAPPDATA%\Programs\<name>`, no admin rights; NSIS | `/opt/<slug>` (deb) or `~/.local/<slug>.app` (install.sh) |
| Extra tools | Xcode tools (`iconutil`, `actool`, notary)` | NSIS (auto-downloaded on Windows; install on macOS/Linux) | none |
| Native UI packaging option | — | — | `linux.webview: false` drops the WebKitGTK dependency from deb/install.sh/doctor |
| Arch | arm64/amd64/universal | amd64/arm64 | amd64/arm64 |
| Cross-build | any machine compiles; sign/dmg only on macOS | any machine compiles; installer needs NSIS | any machine compiles |

Sources: `docs/distribution.md:1-55,266-705`, `docs/configuration.md:112-151`,
`docs/github-actions.md:10-119`. GitHub Actions matrix: macOS runner
(darwin/arm64+amd64), Ubuntu runner for Windows and Linux targets
(`docs/github-actions.md:46-62`). Native-UI projects drop Bun entirely and
build with `go tool mygo build -platform ... -upload`
(`docs/github-actions.md:64-72`, `docs/cli.md:23-25`).

---

## 12. Rendering/performance differences

- Metal (macOS), Direct3D 11 with WARP software fallback (Windows), OpenGL
  3.3/ES 3.0 in GtkGLArea, cairo CPU renderer where OpenGL cannot use a GPU
  (Linux VMs/WSL; Mesa ~50 MB once loaded) (`ui/rendering.md:1-21`).
- macOS keeps three frames while animating for ProMotion displays
  (~4 B/pixel extra) (`ui/rendering.md:45-48`).
- Browsers (optional) use WebGL 2 with the Linux shader; same pixels within
  rounding; CPU fallback if no WebGL2 (`ui/browsers.md:65-70`).
- Measured performance in `ui/performance.md` is macOS/M5/CPU-renderer;
  alloc counts are the portable metric (`ui/performance.md:39-44`).
- Inspector frame timings compare against the display’s refresh interval —
  120 Hz Macs have half the budget of 60 Hz screens (`ui/inspector.md:73-79`).
- No docs compare GPU frame times per platform (**THIN**).

---

## 13. Accessibility backend differences

Same API (`Label`, `Role`, `Description`, `Error`, states,
`c.Announce`, toasts announcing) but different backends: `NSAccessibilityElement`
subclasses (macOS), UI Automation fragments (Windows), ATK objects bridged
to AT-SPI by GTK (Linux) (architecture table “native UI accessibility”).
Rich text formats are exposed via `AXAttributedStringForRange` (VoiceOver),
ATK run attributes (Orca), UI Automation Text pattern (Narrator/NVDA)
(`ui/accessibility.md:77-84`). Browsers: **no AT support** for native UI in
pages (`ui/browsers.md:97-107`). Testable via `tt.Announcements()`
(`ui/testing.md:48-51`).

---

## 14. Undocumented / unclear (flagged for the Lead)

1. **No dedicated cross-platform guide for native-UI appearance.** The only
   consolidated table is `docs/architecture.md:4550-4620`, which is
   desktop-API-centric (its rows mention native UI only for surface,
   rendering, accessibility, drag, title bars, vibrancy).
2. **Default theme font size per OS (13/14)** exists only in source
   (`ui/theme.go:98-103`).
3. **Scrollbar look/width per OS** is MyGo-drawn; docs explain the
   mechanism but not how it compares with native scrollbars.
4. **Windows 10 vs 11 matrix** is partial: menu drawing, rounded corners
   (DWM), snap layouts, Mica availability (Win 11 22H2+) are scattered
   across `docs/menus.md`, `docs/windows.md`, `ui/windows.md`,
   `vibrancy.go`; no one page lists what degrades on Windows 10.
5. **Linux desktop-environment differences** (GNOME vs KDE, X11 vs Wayland,
   portal availability, no accent without portal, no ReduceTransparency) are
   scattered; `docs/native.md:284-324` and architecture rows are the best
   sources.
6. **Windows on ARM64** support is stated (`docs/README.md:182`,
   `docs/distribution.md:26-55`) but not singled out for WebView2/tray.
7. **macOS version gating**: docs reference macOS 26 Liquid Glass and
   “macOS 27” measured glass; `macos.minimumSystemVersion` defaults to 12.0
   — what the gallery shows on older macOS (glass fallbacks) is documented
   only for vibrancy/window glass (`ui/windows.md:130-142`,
   `docs/plugins/glass.md:1-11`), not for the glass plugin (which needs no
   OS, it is shader-drawn).
8. **Screen/DPI**: `Screen` API and DIPs are documented, but no doc covers
   per-monitor scale changes (Windows per-monitor DPI awareness is mentioned
   only in the manifest note `docs/distribution.md:376-382`) or what a
   gallery should expect on 150%/200% displays.
9. **Native-UI testing on non-host OSes** is not documented in the public
   docs (repo-only architecture § Testing, `docs/architecture.md:4178-4230`,
   is excluded from the site); plan cross-OS validation via CI or manual
   runs (see `GOTCHAS.md`).
