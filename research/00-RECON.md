# Recon brief — MyGo UI Explorer preparation (shared baseline)

Last updated: 2026-10-27 by Lead. Keep this file read-only for teammates; report corrections to the Lead.

## Goal of this phase (do NOT implement the app yet)

Understand MyGo deeply, pull the documentation we need, and prepare/verify the
development environment (install, build, test, availability checks) for a future
**Native UI app built with MyGo itself** that showcases every MyGo UI element and
control, on every OS MyGo supports (macOS / Windows / Linux), so that users can
see both *what MyGo offers* and *how each control/UI looks and behaves on each
system*.

Implementation is explicitly deferred to a later phase. Environment probes and
throwaway scaffolds are allowed and expected; the real showcase app is not
started in this phase.

## What MyGo is (verified facts)

- Go desktop app framework by egoist (MIT). Docs: https://mygo.egoist.dev
  Repo: https://github.com/egoist/mygo
- Two window content kinds per app, mixable: **web frontend** in the OS webview
  (WKWebView / WebKitGTK / WebView2) or **native UI** drawn by MyGo itself on
  the GPU (Metal on macOS, Direct3D 11 on Windows, OpenGL on Linux), written in
  Go with package `ui`.
- Pure Go, no cgo → cross-compile any target from any machine.
- Native UI is an immediate-mode-ish "view = function of state, rebuilt each
  frame" model built on checked `Element` values; widgets are constructor calls
  (e.g. `ui.Button(c, "Save")`), layout is flexbox + grid, themes follow the
  system appearance. `ui.Tester` tests views headlessly.
- Desktop APIs: windows, menus, tray, dialogs, notifications, global shortcuts,
  deep links, file associations, recent docs, clipboard/drag (package
  `transfer`), Now Playing/media keys, accent color, accessibility settings,
  file watching, single instance, etc.
- Packaging: `mygo build` → macOS `.app` + `.dmg`, Windows `.exe` + installer,
  Linux binary + desktop entry + `.deb`; signing/notarization/auto-update
  supported; GitHub Actions docs exist.
- Official plugins/optional packages include: `ui/chart`, `ui/editor`,
  `ui/markdown`, `ui/richtext`, `ui/shader`, `plugins/glass`, `plugins/game`,
  `plugins/loading`, `plugins/terminal`, `plugins/sqlite`, `plugins/fetch`,
  `plugins/websocket`, `plugins/updater`, `plugins/watch`, `audio`, `i18n`,
  `transfer`.

## Source of truth in this workspace

- `reference/mygo/` — shallow clone of `main` at commit `b553a90` (2026-10-27).
  Release `v0.7.1` tag = `76dd068` (published 2026-10-27T03:06Z). Main is a few
  commits ahead of the release; the site footer says v0.7.1. Treat the checkout
  as **read-only reference**; do not edit it.
  - `reference/mygo/docs/` — Markdown source of the whole docs site
    (`docs/*.md` ~22 pages + `docs/ui/*.md` ~82 pages).
  - `reference/mygo/ui/` — package `ui` (core UI toolkit) incl. generated
    public API `ui/api_gen.go` (6228 lines) and `core*` implementations.
  - `reference/mygo/examples/` — 30+ runnable examples; note `examples/gallery`
    (an existing "tour of the toolkit": layout, widgets, text editing, 10k-row
    list, drawing, overlays) and `examples/counter-native` (view test).
  - `reference/mygo/cmd/mygo/`, `packages/`, `plugins/`, `website/`
    (docs site incl. `website/llms.ts` which builds `/llms-full.txt`).
- `research/docs/llms-full.txt` — full docs as one Markdown file pulled from
  https://mygo.egoist.dev/llms-full.txt (22,738 lines, 1.2 MB).
- `research/docs/llms.txt` — docs index pulled from /llms.txt.

## Environment facts (verified 2026-10-27)

| Item | Value |
|---|---|
| OS | macOS 27.0.1 (Darwin 27.0.0), arm64 |
| GPU | Apple M5 Pro (20 cores), Metal 4 — GUI session active (Finder running) |
| CPU/RAM | 18 cores, 64 GB, ~354 GiB free disk |
| Go | go1.26.4 darwin/arm64 (Homebrew). MyGo `go.mod` requires **go 1.27.3**; `GOTOOLCHAIN=auto` auto-downloads go1.27.x (verified: downloads go1.27.0 for a `go 1.27` probe; will fetch 1.27.3 for the repo). |
| Bun | 1.3.14 |
| Xcode | 27.1 (Swift 6.4) |
| mygo CLI | not installed yet (`mygo` not on PATH) |
| Virtualization | Docker present; no lima/multipass/qemu found. Cross-OS runtime testing may be unavailable locally → plan around cross-compilation + CI. |
| Network | GitHub, mygo.egoist.dev, Go module proxy reachable (GOPROXY=https://goproxy.cn,direct). |

## Write scopes (avoid overlap; the Lead owns root files)

| Area | Owner | Paths |
|---|---|---|
| Docs corpus + digest | docs-analyst | `research/docs/**` (do not overwrite `llms*.txt`; add new files) |
| UI inventory | ui-cataloger | `research/ui-catalog/**` |
| Env prep + probes | env-prep | `prep/**`, `research/prep/**` |
| Examples analysis + final reports | Lead | `research/examples/**`, `PREPARATION.md`, `PLAN.md`, `research/00-RECON.md` |

## Rules

1. Research only — no real app implementation in this phase.
2. Cite file paths + line numbers (repo refs like `reference/mygo/ui/api_gen.go:775`)
   and doc URLs for every non-obvious claim.
3. Record exact commands + observed output for anything environment-related.
4. Never rely on the docs alone where source is available; flag docs/source drift.
5. Report concise findings to the Lead; keep deliverables under the agreed paths.
6. If a toolchain/network/blocking issue appears, message the Lead immediately
   rather than silently retrying for a long time.
