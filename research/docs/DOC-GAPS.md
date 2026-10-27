# Documentation gaps — MyGo docs vs the native-UI API and the showcase app's needs

Phase-0 analysis by docs-analyst. Method: read the repo Markdown
(`reference/mygo/docs/**`, 114 pages, checkout `b553a90` v0.7.1), cross-check
against the UI source (`reference/mygo/ui/*.go`, `api_gen.go`) and audit the
docs programmatically (API mention coverage, internal links, repo-only
blocks). This file lists **gaps and drift**, not the API inventory — that is
`INDEX.md` / `DIGEST-native-ui.md`, and the UI inventory itself belongs to
`research/ui-catalog/`.

## 1. Coverage at a glance (measured)

| Metric | Result |
|---|---|
| Doc pages | 114 — 20 root (`docs/*.md`), 85 native UI (`docs/ui/*.md` incl. README), 9 plugins (`docs/plugins/*.md`) |
| Published vs repo-only | **all 114 pages are published**; only 8 blocks in 6 files are repository-only (table in `INDEX.md`) |
| Internal links | no broken relative links between doc pages; all 85 UI pages are linked from `ui/README.md`, all root pages from `README.md`, all plugin pages from `plugins.md` (audited) |
| Exported `ui` top-level funcs | **148 / 148 mentioned** somewhere in the docs (102 generated constructors + 46 package funcs such as `NewRouter`, `ParseSVG`, `DecodeBitmap`, `LightTheme`, `Shape`) |
| `ui.Context` methods | **29 / 29** generated methods mentioned + 8 more in source docs (`Valid`, `Invalidate`, `Key`, `Services`, `Resolve`, `Focused`, `FocusWithin`) |
| `ui.Element` methods | **237 / 245** mentioned; the 8 never mentioned are `BottomPercent`, `LeftPercent`, `RightPercent`, `Max/MinWidthPercent`, `Max/MinHeightPercent`, `IsDisabled` (minor: `Element.IsDisabled` is the only behavioural one) |
| Docs↔source drift in code samples | none found: every `ui.*` identifier used in doc snippets exists in the source |

So the gap is **not missing API names** — it is **missing synthesis, recipes,
and a few whole topics** that matter for a cross-platform showcase app.

## 2. Missing or thin topics (ordered by impact on MyGo Explorer)

1. **Cross-platform native-UI appearance guide.** The only consolidated
   per-OS table is `docs/architecture.md:4550-4620`, and it is
   desktop-API-centric (menus, tray, notifications, cookies, webview, title
   bars) with native UI only in a few rows (surface, rendering,
   accessibility, drags, vibrancy). There is no page explaining what a
   native-UI app *looks and behaves like* on each OS: fonts/metrics, default
   theme vs system accent, materials/Liquid Glass, scrollbars, corner
   curvature, window chrome, keyboard conventions. `PLATFORM-DIFFERENCES.md`
   in this directory synthesizes it from scattered statements + source.
2. **DPI / display scaling.** The word “DPI”/“scale factor” appears **nowhere
   in `docs/ui/*.md`** (audited); everything is “DIPs”. `Painter.Scale`,
   `c.SetZoom`, `Tester.SetScale` exist but there is no guidance on
   multi-monitor mixed-DPI, 150%/200% Windows scaling, or what a UI should
   expect (per-monitor DPI awareness is mentioned only for the Windows
   manifest, `docs/distribution.md:376-382`).
3. **Multi-window native-UI apps.** Only three passing mentions: a `Content`
   can serve several windows (`ui/views.md:50-51`), a Handle can bind in
   several windows (`ui/input.md:88-90`, `ui/migration.md:125-130`). No guide
   on window management, per-window widget state/focus, dialogs as separate
   windows vs overlays, or focused-window command routing.
4. **Settings/preferences persistence for native-UI apps.** Window geometry
   has `StateKey` (`docs/windows.md:84-128`); app settings have no documented
   pattern (use `App.Path(PathUserData)` + your own file — reading
   `docs/app.md:229-248` is the only hint). The gallery needs a settings
   store (theme, density, language, RTL).
5. **Snapshots / golden-image testing.** `tt.Image()` and `ui.Render` are
   mentioned in one line each (`ui/testing.md:52-54`); no workflow for
   snapshot tests, and cross-OS font differences make byte-comparison
   unsafe. The deterministic clock IS well documented (`ui/testing.md:60-79`).
6. **Native-UI GUI testing on other OSes.** Public docs say nothing about
   running real-window tests on Linux/Windows; the repo-only architecture
   section (`docs/architecture.md:4178-4230`, excluded from the site) covers
   `MYGO_E2E=1`, Xvfb+WebKitGTK containers, Windows runners. A reader of the
   site cannot learn how to validate cross-OS.
7. **Theme reference values.** `ui/styling.md` explains the theme and
   `Preferences`, but the exact defaults (colors, `Radius` 6, `Spacing` 4,
   `ScrollbarWidth` 6) and the preference-derived rules (accent → hover/
   pressed/selection/focus, `AccentText` black-on-light-accent threshold,
   high-contrast mixing, text-scale multiplication) exist only in source
   (`ui/theme.go:105-153`, `ui/preferences.go:39-80`).
8. **Default font size per OS.** 13 on macOS / 14 elsewhere exists only in
   source (`ui/theme.go:98-103`). `ui/text.md` explains fonts but not the
   default size.
9. **`mygo vet` (and `migrate-ui`) CLI reference.** `mygo vet` is used in
   `ui/views.md:191-195`, `ui/migration.md:7-27,187-192` and
   `docs/architecture.md:2143`, but it is **absent from `docs/cli.md`**
   (which lists init/install-skills/dev/build/generate/i18n check/keygen/
   doctor/version only). Same for `migrate-ui` (only described in the
   migration guide).
10. **Custom-widget cookbook end-to-end.** `ui/custom-widgets.md` shows bases
    and `ui.Local`, and `ui/accessibility.md` lists roles/states, but no
    complete worked custom control (base + keyboard + AT + focus ring +
    `SetChanged` + test). Important if the gallery demonstrates
    “headless widgets of your own”.
11. **Window-chrome cookbook.** The pieces are spread over
    `docs/windows.md` (options, flyouts, panels), `ui/windows.md` (title bars,
    zoom, vibrancy) and `docs/frontend.md` (page title bars). No single
    recipe “draw your own title bar for native UI” beyond a short snippet.
12. **Platform matrices beyond the happy path.** No single list of
    Windows 10 vs 11 differences (menus, Mica, corners, snap layouts), Linux
    X11 vs Wayland (positions, decorations, portals, tray), or macOS version
    gating (Liquid Glass 26+, `SetActiveAppearance` private API,
    `macos.minimumSystemVersion` 12.0 default). Scattered across
    `vibrancy.go`, `docs/windows.md`, `docs/menus.md`, `docs/native.md`,
    architecture table.
13. **API reference for the heavy optional packages.** `ui/editor`,
    `ui/richtext`, `ui/markdown`, `ui/chart` have long guides, but their
    exported types/methods are not enumerated (e.g. `editor.Buffer`,
    `richtext.Document`, `chart` scales/marks); the docs defer to
    `go doc -all`. Acceptable, but the gallery implementer should expect
    source/`go doc` reading there.
14. **Mixed native UI + web pages.** Each kind is documented; mixing is one
    paragraph (`docs/README.md:5-17`) plus `ui/web-view.md`. If MyGo Explorer
    demoes mixed windows, expect to assemble the story from
    `docs/frontend.md#custom-title-bars` + `docs/windows.md` + `ui/web-view.md`.
15. **Inspector/performance profiling recipes** are split between
    `ui/inspector.md` (dev tools) and `ui/rendering.md`
    (`MYGO_FRAME_STATS`) — no “how to find and fix a slow frame” walkthrough.

## 3. Stale / ambiguous / inconsistent doc wording found

| Where | Issue |
|---|---|
| `docs/README.md:170` vs `go.mod:3` | docs say “Go 1.27 or later”, the module requires **1.27.3** (toolchain will auto-download, but the stricter floor should be stated). |
| `docs/plugins/glass.md` | the same material is called “macOS 26 and later” (lines 3, 80) and “macOS 27’s” (lines 49, 111, 172). Version naming is inconsistent (the repo is a macOS-27-era checkout while window vibrancy docs say macOS 26 for `NSGlassEffectView`). |
| `docs/ui/performance.md:46-64` | the benchmark commands are repository-only, so the published page’s numbers cannot be reproduced from the site. |
| `docs/ui/migration.md:7-27` | references `go tool mygo vet`/`migrate-ui` but the CLI page omits them (gap 9). |
| `docs/ui/README.md:55-58` | points to `examples/counter-native` and `examples/gallery` — repo/GitHub only; site readers see no rendered gallery source. The examples themselves are the best “how to lay out a gallery” reference and are outside the docs tree. |
| `docs/architecture.md` | a public page with repository-only blocks (3 blocks); contributor content is invisible on the site/`llms-full.txt`, which is easy to miss when reading the published corpus. |
| `docs/i18n.md:194-198` | “before 0.5 …” migration note is the only versioned API change note; no changelog exists in the checkout, so other silent API changes (if any) cannot be tracked from docs. |
| `docs/ui/testing.md` | lists most `Tester` methods, but `SetTitleBar` (used to test hidden-titlebar layouts, `ui/ui_test.go:213-217`) is only in `api_gen.go` godoc, not the guide. |

## 4. Docs that are good (don’t duplicate effort)

- `docs/ui/views.md`, `ui/input.md`, `ui/migration.md` — lifetime, events,
  actions, handles, vet rules (the most important pages for correctness).
- `docs/ui/layout.md`, `ui/styling.md`, `ui/text.md` — complete and precise.
- `docs/ui/list.md`, `ui/scroll.md`, `ui/overlays.md`, `ui/navigation.md`,
  `ui/accessibility.md`, `ui/right-to-left.md`, `ui/testing.md` — thorough.
- `docs/ui/inspector.md`, `ui/rendering.md` — enough to debug and profile.
- `docs/ui/windows.md`, `docs/windows.md`, `docs/menus.md`, `docs/native.md`,
  `docs/i18n.md`, `docs/configuration.md`, `docs/cli.md`,
  `docs/distribution.md`, `docs/github-actions.md` — solid app/platform docs.
- `docs/plugins/glass.md`, `plugins/loading.md` — detailed and ready to use
  for showcase screens.

## 5. Suggested documentation fixes (for a later phase, not this one)

1. Add “Native UI on each platform” page (or a section in
   `docs/ui/windows.md`) covering fonts/sizes, materials, scrollbars, title
   bars, keyboard conventions — this project’s missing keystone.
2. Document `mygo vet`/`migrate-ui` in `docs/cli.md`.
3. Document default theme values and preference derivation in
   `docs/ui/styling.md` (or a “theme reference” subsection).
4. Add a “Display scaling and zoom” note to `docs/ui/layout.md`
   (`Painter.Scale`, `SetZoom`, `Tester.SetScale`).
5. Add “Multiple windows” and “Saving settings” recipes (could live in
   `docs/ui/windows.md` and `docs/app.md`).
6. Add a snapshot-testing recipe to `docs/ui/testing.md` (including the
   cross-OS caveat).
7. Unify the macOS 26/27 naming in `docs/plugins/glass.md`.
8. Publish (or link from docs) the cross-platform testing setup currently in
   the repository-only architecture section.
9. Mention `Tester.SetTitleBar` and `ui.Render` in the testing guide.
10. Fix “Go 1.27” → “Go 1.27.3” in `docs/README.md`/`getting-started.md`.
