# Environment fact sheet — MyGo Explorer (phase 0)

Owner: env-prep. Verified: 2026-10-27 on the machine described below.
Companion: [`RUNBOOK.md`](RUNBOOK.md) (step-by-step reproduction),
[`prep/scripts/preflight.sh`](../../prep/scripts/preflight.sh) (automated checks),
[`evidence/`](evidence/) (raw command output and screenshots).
Read-only reference checkout: `reference/mygo` at `main` `b553a90`; release used:
**MyGo v0.7.1**.

## 1. Fact sheet

| Item | Value | How verified |
|---|---|---|
| OS | macOS 27.0.1, build 26A434, Darwin 27.0.0, arm64 | `sw_vers`, `uname -m` (`evidence/21-*`) |
| Hardware | Apple M5 Pro (18 CPU cores per recon, 20-core GPU), 64 GB RAM, 352 GiB free | `system_profiler`, `df -h` (`evidence/21-*`) |
| Display | Built-in Liquid Retina XDR 3024×1964 @2× (device-pixel scale 2) | `system_profiler` (`evidence/21-*`) |
| GPU API | **Metal 4**, 20 cores | `system_profiler SPDisplaysDataType` → "Metal Support: Metal 4" (`evidence/21-*`) |
| GUI session | Active (WindowServer); system appearance **Dark** (`defaults read -g AppleInterfaceStyle` = Dark) | `pgrep WindowServer`, `defaults` (`evidence/25-*`) |
| Host Go | `go1.26.4 darwin/arm64` (Homebrew, `/opt/homebrew/bin/go`) | `go version` (`evidence/21-*`) |
| Selected Go toolchain | **go1.27.3 darwin/arm64**, auto-downloaded by `GOTOOLCHAIN=auto` from `go.mod`'s `go 1.27.3` | `cd prep/probe-native && go version` → `go1.27.3` (`evidence/21-*`) |
| Toolchain cache | `~/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.27.3.darwin-arm64` (`GOROOT` inside a MyGo module) | `go env GOROOT` (`evidence/25-*`) |
| `GOTOOLCHAIN` | `auto` (host default) | `go env GOTOOLCHAIN` (`evidence/21-*`) |
| mygo CLI | **`mygo 0.7.1`** at `~/go/bin/mygo` (19,705,762 bytes); `GOBIN=$HOME/go/bin`, **not on `PATH`** | `mygo version` (`evidence/03-*`) |
| MyGo module pinned by probe | `github.com/egoist/mygo v0.7.1` | `go list -m` (`evidence/21-*`) |
| Newest release | **v0.7.1** (`go list -m -versions` ends at v0.7.1; `@latest` resolves v0.7.1) | `evidence/02-*` |
| Reference checkout | `reference/mygo` main `b553a90`, clean tree, tag `v0.7.1` = `76dd068` (recon) | `git rev-parse`, `git status` (`evidence/23-*`) |
| Bun | 1.3.14 (needed only by the **web** template, not native UI) | `bun --version` (`evidence/21-*`) |
| Xcode | 27.1 / build 27A9275; `xcode-select -p` = `/Applications/Xcode.app/Contents/Developer` | `xcodebuild -version` (`evidence/21-*`) |
| Signing identities | 1 codesigning identity: "Apple Development: [redacted]" — **no Developer ID Application** | `security find-identity -v -p codesigning` (see §12) |
| Network | GitHub, `mygo.egoist.dev`, Go proxy reachable; `GOPROXY=https://goproxy.cn,direct` | module/toolchain downloads succeeded (`evidence/01-*`, `02-*`) |

Raw facts: `evidence/21-system-facts-artifacts.log`, `evidence/25-toolchain-appearance-api.log`.

## 2. Pinned project configuration (reproducibility)

`mygo init -template native` generated the probe. Its `go.mod` pins everything:

```go
module probe-native

go 1.27.3

tool github.com/egoist/mygo/cmd/mygo

require github.com/egoist/mygo v0.7.1

require (
	github.com/ebitengine/purego v0.11.1 // indirect
	github.com/go-text/typesetting v0.3.5 // indirect
	golang.org/x/image v0.46.0 // indirect
	golang.org/x/net v0.59.0 // indirect
	golang.org/x/text v0.43.0 // indirect
)
```

Three independent pins make builds reproducible:

1. **`go 1.27.3`** — with `GOTOOLCHAIN=auto` (default) the host Go 1.26.4
   downloads and selects go1.27.3 for every command run inside this module.
   Verified: `go version` outside the module says `go1.26.4`; inside it says
   `go1.27.3` (`evidence/21-*`).
2. **`tool github.com/egoist/mygo/cmd/mygo`** — `go tool mygo ...` runs the CLI
   **at the version the module pins**, without requiring a global `mygo` on
   `PATH`. So `go tool mygo dev|build|vet` is reproducible from the checkout;
   the global CLI install is only needed for `mygo init`/`mygo doctor` and for
   starting new projects.
3. **`require github.com/egoist/mygo v0.7.1`** — the library/UI source the app
   compiles against.

Other generated files (all under `prep/probe-native/`):

| File | Contents |
|---|---|
| `main.go` | 59 lines: `app{name,count}` state, `view(*ui.Context)` (title, `TextInput`, greeting, `Row` with `Button`/`Textf`/`PrimaryButton`), `main()` creating a 480×360 native window (`Content: ui.View(a.view)`, `StateKey: "main"`) inside `mygo.App.WhenReady`. |
| `main_test.go` | Headless view test: `ui.NewTester(a.view, 480, 360)`, `tt.Click("+")`, asserts count/text; `tt.Click("Name")` + `tt.Type("Ada")`, asserts greeting. |
| `mygo.json` | `{ "name": "probe-native", "identifier": "com.example.probenative", "version": "0.1.0", "out": "build" }`. |
| `resources/icon.png` | 1024×1024 app icon (87,043 bytes). |
| `.agents/skills/mygo-maintenance/SKILL.md` | 5,042-byte maintenance skill (see §2.1). Also `.../agents/openai.yaml`. |
| `.gitignore` | ignores `build/`, `.mygo/`. |

### 2.1 Generated maintenance skill (`mygo-maintenance`)

Path: `prep/probe-native/.agents/skills/mygo-maintenance/SKILL.md` (37 lines).
It is the maintenance guidance the future app should follow. Summary:

- **Lifetime/identity:** `*ui.Context` is stable per window; never store
  `ui.Element`s or parts (they expire before the next build pass); bind stable
  identity with `c.Key(...)`/`.Bind(&handle)`; read committed geometry with
  `handle.Bounds(c)`.
- **Input/actions:** bound values update after construction; `Changed`/`Submitted`
  notices arrive in the next build pass; `OnClick`/`OnShortcut` run after
  bound input; use `.OnShortcut`/`c.OnShortcut` for scoped commands.
- **State/work:** views may rebuild several times per event — make side effects
  explicit/handled; keep I/O off the UI thread (`Window.Update`,
  `Invalidate`); drawing callbacks paint only.
- **Verification:** reproduce UI changes with `ui.NewTester` (extra frames,
  focus/typing), run `go tool mygo vet .` (checks stored build values and
  goroutine captures), `CGO_ENABLED=0 go test ./...`, and inspect rendered
  output; for upgrades preview with `go tool mygo migrate-ui .`, apply with
  `-write`.
- **Upgrades:** read `docs/ui/migration.md` for major bumps (and `0.x` minor
  bumps), check the pinned source via `go list -m -f '{{.Dir}}' github.com/egoist/mygo`.

`go tool mygo install-skills` re-installs/updates these bundled files
(verified: "Installed skills in .agents/skills", `evidence/22-*`).

## 3. Toolchain setup and selection

Host Go 1.26.4 is enough as a bootstrap; **do not install a second Go
manually**. Options, in order of preference:

1. **Default (used here):** leave `GOTOOLCHAIN=auto`; run any Go command in a
   module whose `go.mod` says `go 1.27.3`. Go downloads
   `golang.org/toolchain@v0.0.1-go1.27.3.darwin-arm64` (~70 MB) once into
   `$GOMODCACHE` and uses it. No `PATH` change; the toolchain follows the
   `go.mod` line automatically.
2. **Explicit pin (CI-friendly):** `export GOTOOLCHAIN=go1.27.3` — same
   download, deterministic even outside the module. `GOTOOLCHAIN=go1.27.3 go version`
   was verified to download and report `go1.27.3` (`evidence/01/21-*`).
3. **`golang.org/dl` wrapper:** `go install golang.org/dl/go1.27.3@latest &&
   go1.27.3 download` puts it in `~/sdk/go1.27.3`. Works, but a second launcher
   name is needed; not used in this workspace.

**`go install` PATH caveat:** `go install github.com/egoist/mygo/cmd/mygo@v0.7.1`
installs to `GOBIN=$HOME/go/bin`, which is *not* on this machine's `PATH`.
Either `export PATH="$HOME/go/bin:$PATH"` (recommended; see RUNBOOK) or call
`go tool mygo` from inside the module.

**Install command actually used:**

```sh
GOTOOLCHAIN=go1.27.3 go install github.com/egoist/mygo/cmd/mygo@v0.7.1
mygo version        # mygo 0.7.1
```

`@latest` resolved to **v0.7.1** on 2026-10-27 (`evidence/02-cli-versions.log`),
so pinning `@v0.7.1` is both current and reproducible.

## 4. `mygo doctor` output and meaning

Outside a project (`evidence/04-doctor-before.log`):

```
✓ go         go version go1.26.4 darwin/arm64
✓ bun        1.3.14
✓ macOS      27.0.1 (WKWebView; macOS 12 or later is required)
- makensis   not found (optional: the Windows installer, ...)
- osslsign   not found (optional: signing Windows apps here (osslsigncode))
✓ gh         /opt/homebrew/bin/gh
- codesign   not found (optional: a Developer ID to sign apps for other Macs)
```

Inside `prep/probe-native` (`evidence/10-vet-doctor-project.log`) the same
checks pass but **`go` reads `go1.27.3`**, because Go selects the toolchain
from `go.mod` before running the CLI. Both exit 0; the `-` lines are optional
tools, not failures. `codesign` here means a **Developer ID** identity (see
§12); plain `codesign` and an Apple Development cert exist.

## 5. CLI v0.7.1 — commands and local status

`mygo --help` (`evidence/03-cli-help.log`, `evidence/19-*`):

| Command | Local status / notes |
|---|---|
| `mygo init [-template web\|native] [dir]` | **PASS** (native; `evidence/05-*`). Needs a new or empty dir. `-name`, `-module`, `-mygo` flags. Web template requires Bun+Vite (not exercised; native UI is the target kind). |
| `mygo dev` / `go tool mygo dev` | **PASS** with live reload (`evidence/17-*`). Flags: `-sign`, `-skip-dev-command`, `-lang`, and with `-web`: `-open`, `-port`. Dev app: `.mygo/darwin-arm64/<name> Dev.app`, identifier `<id>.dev`. |
| `mygo build` / `go tool mygo build` | **PASS** for darwin/arm64, darwin/universal, linux/amd64, windows/amd64, web (`evidence/11,12,16,18-*`). Flags: `-platform`, `-debug`, `-o`, `-sign`, `-skip-dmg`, `-skip-notarize`, `-skip-build-command`, `-upload`. |
| `mygo vet [dir]` / `go tool mygo vet` | **PASS**, exit 0 (`evidence/10-*`). Runs Go vet plus native-UI build-lifetime checks. |
| `mygo doctor` | **PASS** (see §4). |
| `mygo version` | **PASS**, `mygo 0.7.1`. |
| `mygo install-skills` | **PASS**, "Installed skills in .agents/skills" (`evidence/22-*`). |
| `mygo generate` | Expected refusal for a native-only app: exit 1, `error: the project has no frontend to write a client for: set bindings in mygo.json, or pass -o` (`evidence/19-*`). Web-only feature. |
| `mygo i18n check` | Available; no catalogs in probe, not exercised. |
| `mygo migrate-ui [dir]` | Available (preview; `-write` applies): checked UI value API migration for version upgrades. Not exercised (no old API). |
| `mygo keygen` | Available (update-signing key pair, `-o`, `-force`); only needed if shipping auto-updates, not exercised. |

## 6. Capability matrix (verified on this machine)

| Capability | Status | Evidence / measurements |
|---|---|---|
| Install Go 1.27.3 toolchain via `GOTOOLCHAIN=auto` | **PASS** | `evidence/21-*`, `25-*`; toolchain in `$GOMODCACHE` |
| Install `mygo` CLI v0.7.1 | **PASS** | `evidence/01-*`, `03-*`; `mygo 0.7.1` |
| Scaffold native template | **PASS** | `evidence/05-init-native.log`; files listed in §2 |
| Headless view test `go test ./...` | **PASS** | 0.389 s test, ~2.8 s wall incl. compile cold (`evidence/06-*`) |
| `mygo vet` lifetime checks | **PASS** | exit 0 (`evidence/10-*`) |
| Headless snapshot rendering (`ui.Render`, `ui.Tester.Image`) | **PASS**, deterministic | `evidence/07-*`, `08-*`, `09-*`; see §7 |
| Package macOS app (`go tool mygo build`, default darwin/arm64) | **PASS** | 8.9 s cold; `.app` 9.1 MB + `.dmg` 3.0 MB; ad-hoc signed (`evidence/11-*`) |
| Real GUI window renders | **PASS** | window screenshots + `CapturePage` PNG; frame stats "drawn on the GPU" (`evidence/14-*`) |
| Dev hot reload | **PASS** | initial dev build 1.4 s; edit → rebuild+relaunch 418 ms; clean exit (`evidence/17-*`) |
| Cross-compile linux/amd64 from macOS | **PASS** | 9.0 MB ELF + `.deb` + `.tar.gz` + desktop entry/install.sh (`evidence/12-*`) |
| Cross-compile windows/amd64 from macOS | **PASS** (exe only) | 9.4 MB `PE32+ GUI` `.exe`; NSIS installer skipped (makensis absent, only auto-downloaded on Windows) (`evidence/12-*`) |
| darwin/universal (arm64+x86_64) | **PASS** | 3.9 s; fat binary 19,427,040 B; `.app` 18.8 MB; ad-hoc signature (`evidence/16-*`) |
| Web/wasm production build (`-platform web`) | **PASS** | 2.2 s; 10.8 MB content-hashed wasm + index.html + wasm_exec.js + icon (`evidence/18-*`) |
| Browser dev server (`dev -web -open=false`) | **PASS** | built 11.4 MB wasm in 778 ms; HTTP 200 on :5174; `/app.wasm` 11,923,156 B; clean exit (`evidence/20-*`) |
| Automated preflight | **PASS** | 19 passed / 0 failed / 1 skipped without GUI; 22/0/0 with `--gui`; ~5-7 s warm (`evidence/23-*`, `24-*`) |
| Windows/Linux **runtime** validation | **NOT POSSIBLE locally** | No VM/hypervisor for these OSes (recon: Docker only); only cross-compilation verified |
| Developer ID signing / notarization | **NOT AVAILABLE** | No "Developer ID Application" identity; only Apple Development cert; `notarytool` exists but no credentials |
| Windows installer / signing locally | **NOT AVAILABLE** | `makensis`, `osslsigncode` not installed (doctor warnings) |

## 7. Rendering, GPU and deterministic screenshots

Docs of record: `reference/mygo/docs/ui/rendering.md` (GPU backends,
`MYGO_GPU`, `MYGO_FRAME_STATS`), `docs/ui/testing.md` (`ui.NewTester`,
`tt.Image`, `ui.Render`, frozen clock), `docs/ui/text.md:146-190` (text is laid
out/drawn by the **platform** text engine in the **system font**:
DirectWrite/Segoe UI on Windows, Core Text/SF on macOS, Pango/GTK font on
Linux; `ui.RegisterFont` embeds a font for uniform rendering).

### 7.1 GPU path (real window)

Running the packaged app with `MYGO_FRAME_STATS=all` prints per-frame stats:

```
mygo: frame 1 took 344.6 ms: build 0.1, layout 1.3, paint 1.0, present 342.0
  (drawn on the GPU: 33 instances in 5 batches (1 opaque; ...), 0 ops culled, ...)
mygo: frame 2 took 0.1 ms: ... (drawn on the GPU: unchanged, ...)
```

- "drawn on the GPU" is runtime proof that the window renders with **Metal** on
  this Mac (Metal 4, 20-core GPU). `evidence/14a-*`, `15-*`.
- First frame of the **first ever launch** took ~345 ms (Metal pipeline
  creation/compilation); in later runs/preflight the first frame was ~13 ms
  (`evidence/24-*`). Steady-state idle frame ~0.1 ms because MyGo draws only on
  change.
- `MYGO_GPU=0` forces the CPU renderer: frame stats then say `(drawn in
  memory)` and the first frame took 3.6 ms (`evidence/15-*`).

### 7.2 Headless path (CI-friendly snapshot rendering)

`ui.Render(view, w, h, scale)` returns `*image.RGBA`; it is implemented as a
`ui.Tester` at that scale (`reference/mygo/ui/headless.go:216-220`), always
painting in memory. `ui.NewTester(...).Frame()` + `.Image()` gives the same
image (verified byte-identical).

Measured with the probe view, 480×360, on this Mac (`evidence/07-*`):

| Call | Result |
|---|---|
| `ui.Render(view, 480, 360, 1)` first call | 19.8 ms (warmup), 9,878-byte PNG, sha256 `5734e331…` |
| `ui.Render(view, 480, 360, 1)` again | 0.6 ms, **byte-identical** |
| `ui.Render(view, 480, 360, 2)` | 3.1 ms, 960×720, 26,490 bytes, sha256 `c0b474…` (all pixels scaled 2×) |
| `ui.NewTester` + `Frame` + `Image` | 0.7 ms, PNG byte-identical to `ui.Render` |
| `tt.Click("+")` + `Image` | 3.2 ms (view rebuild + repaint) |
| `tt.SetDark(false)` frame | light PNG 9,691 B, sha256 `88b2d1…` |
| `tt.SetDark(true)` frame | dark PNG 9,788 B, sha256 `5bbf17…` (differs, as expected) |
| light frame rendered twice | byte-identical |

Key determinism findings:

1. **Same OS + same inputs → byte-identical PNGs.** Two renders matched,
   across `ui.Render` and `Tester.Image`, and across repeated frames.
2. **`MYGO_GPU` has no effect on headless output.** Default vs `MYGO_GPU=0`
   produced identical bytes for all 6 snapshot files (`evidence/09-*`). CI
   needs no GPU to produce the snapshots.
3. **Headless default theme is LIGHT even though this Mac is in Dark mode.**
   `ui.Render` / a fresh `Tester` do not inherit the system appearance, so
   snapshots are reproducible; use `tt.SetDark(true|false)` (and
   `tt.SetScale`, `tt.SetPreferences`) to force a theme (both verified).
4. **Not platform-identical across OSes:** text rasterization comes from the
   platform text engine + system font (§ docs above), so the future
   per-OS/per-platform screenshot matrix must render **on each target OS**
   (CI matrix) rather than on one machine. `ui.RegisterFont` with an embedded
   font is the option for pixel-identical text everywhere.

### 7.3 Screenshot / capture options (all verified)

| Method | Verified result | Use |
|---|---|---|
| `win.CapturePage()` on a native-UI window | **25,050-byte PNG, 960×656** (2× device pixels of the 480×328 content) written from a goroutine, then clean `App.Quit()` | App-exports-itself matrix (proposed future approach) |
| `screencapture -x file.png` | 3024×1964 PNG, 7.06 MB; window visible, cropped copy 980×620 kept | OS-level evidence of the real window |
| `ui.Render` / `tt.Image` + `png.Encode` | deterministic PNGs (§7.2) | CI snapshot matrix, no GUI needed |
| `tt.SetDark` / `tt.SetScale` | light/dark, 1×/2× renders | Per-theme/per-scale matrix |

`CapturePage` implementation: `reference/mygo/window.go:1409-1426` — for a
window showing `Content` it calls `captureContent()`
(`reference/mygo/content.go:191-216`), which renders the Content on the main
thread, wraps it as `*image.RGBA` and PNG-encodes it. So a native-UI window can
screenshot itself without OS screen-recording permission — important for CI
and for the future app's "export screenshots" feature.

## 8. Build/packaging artifacts (exact commands and sizes)

All from `prep/probe-native` (Go 1.27.3, `CGO_ENABLED=0`, `-trimpath`,
`-tags=mygo_noinspector` — verified in build metadata, `evidence/22-*`).

| Command | Time | Artifacts (bytes) |
|---|---|---|
| `go tool mygo build` (default `darwin/arm64`, with dmg) | **8.9 s** cold (compile 3.5 s, sign 20 ms, dmg 5.1 s) | `build/darwin-arm64/probe-native.app` 9.1 MB (binary 9,248,880) + `probe-native-0.1.0-arm64.dmg` 3.0 MB |
| `go tool mygo build -platform darwin/arm64,linux/amd64,windows/amd64 -skip-dmg` | **8.9 s** | darwin app 9.1 MB; `linux-amd64/probe-native` 9,486,599 ELF, `.deb` 4.0 MB, `.tar.gz` 4.0 MB, `.desktop`, `install.sh`, icons; `windows-amd64/probe-native.exe` 9,825,792 `PE32+ GUI` |
| `go tool mygo build -platform darwin/universal -skip-dmg` | **3.9 s** | `build-universal/darwin-universal/probe-native.app` 18.8 MB; fat binary 19,427,040 B = `arm64 x86_64` (`lipo -info`); ad-hoc signed |
| `go tool mygo build -platform web` | **2.2 s** | `web/index.html` 3 KB, `web/probe-native.7241fb242720.wasm` 11,365,175 B, `wasm_exec.js` 17 KB, `icon.png` 86 KB |
| warm incremental native build (preflight) | ~1 s | same app |

Signing during local builds: `codesign -dv` shows `Signature=adhoc`,
`TeamIdentifier=not set` (default `-sign "-"`). That is sufficient to launch
locally; **no Developer ID / notarization is needed for phase-0 validation**.

## 9. Dev workflow evidence

- `go tool mygo dev` builds `.mygo/darwin-arm64/probe-native Dev.app` in
  **1.4 s**, prints `➜ Watching for changes`, and relaunches on Go changes:
  editing `main.go` produced `Rebuilding probe-native Dev (main.go changed)` /
  `Rebuilt ... 418ms` (`evidence/17-*`); the relaunched window showed the edited
  text (`evidence/probe-dev-hotreload-cropped.png`). `Ctrl+C` (SIGINT) logs
  `Stopping probe-native Dev` and exits 0; no processes remain.
- `go tool mygo dev -web -open=false` builds for browsers (778 ms, 11.4 MB
  wasm), serves `http://localhost:5174/` (`Cache-Control: no-store`),
  `app.wasm` served at 11,923,156 B; exits cleanly; port is released
  (`evidence/20-*`).

## 10. Cleanup / machine hygiene

Rule followed during probes and encoded in the preflight: **brief GUI launches,
close afterwards, no background processes.** Final state verified:
`pgrep -fl 'probe-native|probe-capture|mygo dev'` → nothing.
`research/prep/evidence/preflight-last.log` records the last green preflight.

## 11. Known gotchas / corrections

1. `go/bin` is not on `PATH` → `mygo: command not found`. Use
   `export PATH="$HOME/go/bin:$PATH"` or `go tool mygo` in a module.
2. `mygo doctor` reports **go1.26.4** outside a module and **go1.27.3** inside
   one. Both fine; do not "fix" it by installing another Go.
3. `mygo init` needs a **new or empty** directory. An existing non-empty dir is
   refused.
4. `mygo generate` is web-only: on a native-only app it exits 1 with
   `the project has no frontend to write a client for`.
5. First-ever frame after boot can take ~345 ms for Metal pipeline setup; it is
   not a hang. Later launches ~13 ms; steady-state idle frames ~0.1 ms.
6. `go tool mygo dev` runs a wrapper (`go tool` → cached `mygo dev` → app).
   For scripted shutdown send SIGINT to the innermost `mygo dev` process (or
   run under a terminal and press Ctrl+C / type `q`); verify with `pgrep`.
7. `mygo dev -web` opens a browser by default; use `-open=false` in automation
   and `-port` if 5174 is busy (it picks the next free port itself too).
8. `screencapture` needs macOS Screen Recording permission (it worked here);
   headless CI should use `CapturePage`/`ui.Render` instead.
9. Cross-built Windows app has **no installer** on macOS (NSIS only downloads on
   Windows); cross-built Linux app **does** get `.deb`/`.tar.gz` from macOS.
10. Reference checkout is read-only and pinned: preflight fails if HEAD ≠
    `b553a90` or the tree is dirty.
11. `CGO_ENABLED` prints 1 for the host toolchain, but `mygo build` compiles with
    `CGO_ENABLED=0` (build metadata) — that is why cross-compilation works with
    no cross C toolchain.

## 12. Signing / distribution status (explicit limitations)

- Local: ad-hoc signing; app launches on this Mac only.
- Distribution (macOS): requires `macos.signingIdentity` = a **Developer ID
  Application** certificate and `macos.notarize` (App Store Connect API/Apple
  ID credentials). The machine has only an **Apple Development** identity
  (`security find-identity`), so notarizable builds are **not possible here**;
  `mygo doctor` correctly reports no Developer ID.
- Windows: installer needs NSIS (`makensis` not installed here; `mygo build`
  downloads it when running on Windows) and optional signing needs `signtool`
  (Windows) or `osslsigncode` (absent on this Mac).
- Auto-updates: `mygo keygen` can create the signing key pair; not exercised,
  and requires hosted update endpoints.
- `gh` 2.100.0 is present, so `mygo build -upload` (draft GitHub release) is
  conceivable for future phases.

## 13. Evidence index (`research/prep/evidence/`)

| File | Contents |
|---|---|
| `01-install-cli-v0.7.1.log` | `go install ...@v0.7.1` output |
| `02-cli-versions.log` | all module versions; `@latest` = v0.7.1 |
| `03-cli-help.log` | `mygo version`, `--help`, `init -h`, `build -h` |
| `04-doctor-before.log` | doctor outside a project (host go) |
| `05-init-native.log` | native scaffold creation |
| `06-go-test.log` | cold `go test ./...` |
| `07-headless-capture.log` | `ui.Render`/`Tester` determinism, PNG sizes/hashes, timings |
| `08-headless-capture-gpu0.log` | same test with `MYGO_GPU=0` |
| `09-gpu0-vs-default.log` | sha256 comparison: identical bytes for all snapshots |
| `10-vet-doctor-project.log` | `mygo vet`, doctor inside project (go1.27.3) |
| `11-build-darwin-arm64.log` | cold macOS packaging (app + dmg) |
| `12-crossbuild-arm64-linux-win.log` | darwin+linux+windows build, artifact tree/sizes |
| `13-build-capture-probe.log` | capture-enabled probe build |
| `14-live-run*.log` | real window launch, frame stats (GPU), `CapturePage` result |
| `15-live-run-gpu0*.log` | same with `MYGO_GPU=0` (`drawn in memory`) |
| `16-build-darwin-universal.log` | universal build, `lipo -info`, `codesign -dv` |
| `17-dev-hotreload.log` | `mygo dev`, edit → rebuild 418 ms, clean stop |
| `18-web-wasm-build.log` | `-platform web` artifacts + wasm metadata |
| `19-dev-generate-help.log` | `generate` refusal on native app; dev flags |
| `20-dev-web.log` | browser dev server build/serve, port, clean exit |
| `21-system-facts-artifacts.log` | OS/GPU/go env/bun/xcode/disk, artifact `file`/sizes |
| `22-build-settings-skills.log` | `go version -m` (CGO_ENABLED=0, trimpath, tags), install-skills |
| `23-preflight-run.log` | preflight default run (19 PASS) |
| `24-preflight-gui-run.log` | preflight `--gui` (22 PASS, Metal + screenshot) |
| `25-toolchain-appearance-api.log` | GOROOT/toolchain path, Dark appearance, Tester APIs |
| `probe-window-screencapture(-cropped).png` | real window (pristine probe app) |
| `probe-dev-hotreload(-cropped).png` | window after hot reload (`HOT RELOADED` text) |
| `probe-capturepage.png` | in-app `CapturePage()` output (960×656) |
| `preflight-gui.png` | preflight `--gui` screenshot |
| `probe-render-*.png`, `probe-tester-*.png` | headless snapshots incl. light/dark themes |
| `preflight-last.log` | last green preflight summary |

## 14. Bottom line for the showcase app

The environment is **ready** for a native-UI MyGo showcase app on this Mac:
scaffold, headless tests, deterministic snapshot rendering (per-OS,
theme/scale-controllable), dev hot reload, macOS packaging, universal macOS
builds, and cross-compilation for Windows/Linux (compile-only) all pass with
pure Go and no cgo. Remaining limitations are **runtime validation on
Windows/Linux** (needs CI/VM) and **distribution signing/notarization**
(needs a Developer ID certificate and NSIS/osslsigncode for Windows). Use
`RUNBOOK.md` for the reproducible steps and `prep/scripts/preflight.sh` to
confirm any machine.
