# RUNBOOK — MyGo native-UI development environment

Reproducible setup, development, testing, packaging, cross-compilation and
inspection steps for the MyGo Explorer workspace. Companion to
[`ENVIRONMENT.md`](ENVIRONMENT.md) (measured facts) and
[`../scripts/preflight.sh`](../../prep/scripts/preflight.sh) (automated check).
Reference: MyGo **v0.7.1**, `reference/mygo` at `b553a90`.

Tested reference environment (2026-10-27): macOS 27.0.1 arm64 (Apple M5 Pro,
Metal 4, GUI session), host Go 1.26.4, auto-selected **go1.27.3**, mygo CLI
**0.7.1**, Bun 1.3.14 (web only), Xcode 27.1.

---

## 0. TL;DR

```sh
# 1. CLI + PATH (one time)
export PATH="$HOME/go/bin:$PATH"
GOTOOLCHAIN=go1.27.3 go install github.com/egoist/mygo/cmd/mygo@v0.7.1

# 2. From the workspace root: one-shot verification
prep/scripts/preflight.sh            # expect: result: PASS (19 passed, 1 skipped)
prep/scripts/preflight.sh --gui      # optional: also opens the probe window ~2s

# 3. Work on the (future) app
cd prep/probe-native                 # or wherever the app is scaffolded
go test ./...                        # headless view tests
go tool mygo vet                     # Go vet + native-UI lifetime checks
go tool mygo dev                     # live reload (Ctrl+C / q quits)
go tool mygo build                   # package macOS .app + .dmg
```

---

## 1. Prerequisites

| Tool | Required version | Why | Install / check |
|---|---|---|---|
| macOS | 27.0.1 arm64 (reference) | GUI runs, dmg packaging | `sw_vers`, `uname -m` |
| Go (host) | 1.26.4+ | bootstrap; runs `GOTOOLCHAIN` downloads and `go install` | `go version`; https://go.dev/dl/ |
| Go toolchain | **1.27.3** (from `go.mod`) | MyGo's module requires it | auto via `GOTOOLCHAIN=auto`; verify `cd prep/probe-native && go version` |
| mygo CLI | **0.7.1** | `init`, `doctor`, scaffold | `go install ...@v0.7.1` |
| Xcode CLI tools | any recent (27.1 here) | optional; macOS packaging/dmg uses system tools, not Xcode | `xcode-select -p` |
| Bun | 1.3.14 (only **web** template) | `mygo init` web template, web dev | `bun --version` |
| GUI session | active WindowServer | real-window runs; `-gui` preflight | `pgrep WindowServer` |

Native UI does **not** need Bun, Node, Xcode, cgo, or a GPU (CPU rendering is a
supported fallback). It does need Go 1.27.3 via the module's `go` directive.

## 2. One-time setup (reproducible, pinned)

### 2.1 Put Go's bin directory on PATH

`go install` writes to `GOBIN`, which is `$HOME/go/bin` here and is **not** on
the default PATH:

```sh
export PATH="$HOME/go/bin:$PATH"          # add to ~/.zshrc for permanence
which mygo || true                        # empty before installing
```

### 2.2 Install the pinned CLI

```sh
GOTOOLCHAIN=go1.27.3 go install github.com/egoist/mygo/cmd/mygo@v0.7.1
mygo version                              # expected: mygo 0.7.1
```

Why pinned: on 2026-10-27 `@latest` also resolved to `v0.7.1`
(`research/prep/evidence/02-cli-versions.log`), but pinning keeps the
scaffolder identical to the release the app will pin.

### 2.3 Confirm the Go toolchain

Nothing to install manually: with `GOTOOLCHAIN=auto` (default), any Go command
inside a module declaring `go 1.27.3` downloads and uses
`golang.org/toolchain@v0.0.1-go1.27.3.darwin-arm64` automatically:

```sh
cd prep/probe-native
go version                                # go1.27.3 darwin/arm64
go env GOROOT                             # .../golang.org/toolchain@v0.0.1-go1.27.3.darwin-arm64
```

For CI or explicit pinning, `export GOTOOLCHAIN=go1.27.3` also works. Never
install a second Go release over the host one; the module line drives selection.
Note that `mygo doctor` run *outside* a module reports the host go1.26.4 — that
is expected, not a failure.

### 2.4 Verify

```sh
mygo doctor          # ✓ go / ✓ bun / ✓ macOS; '-' lines are optional tools
prep/scripts/preflight.sh
```

Expected preflight tail:

```
summary: 19 passed, 0 failed, 1 skipped
result: PASS
```

## 3. Scaffold a native-UI project (throwaway probes live here)

The native template is what the future showcase app will use (one Go module,
`main.go` + view test + `mygo.json` + icon + `.agents/skills/`).

```sh
cd prep
mygo init -template native my-app        # dir must be new or empty
cd my-app
```

Generated tree and its pinned `go.mod` are documented in
[`ENVIRONMENT.md`](ENVIRONMENT.md#2-pinned-project-configuration-reproducibility):
the module has `go 1.27.3`, `tool github.com/egoist/mygo/cmd/mygo`, and
`require github.com/egoist/mygo v0.7.1`.

From here on, **always use `go tool mygo`** (not the global `mygo`) so builds
use the CLI version pinned by the project:

| Task | Command |
|---|---|
| Test the view headlessly | `go test ./...` |
| Lifetime / stored-build-value checks | `go tool mygo vet` |
| Live reload dev | `go tool mygo dev` |
| Package | `go tool mygo build` |
| Upgrade MyGo | `go get -tool github.com/egoist/mygo/cmd/mygo@latest && go mod tidy` |

Existing probes in this workspace (throwaway validation artifacts, not the real
app):

- `prep/probe-native/` — exactly the generated scaffold plus
  `capture_test.go` (headless snapshot/determinism probe).
- `prep/probe-capture/` — copy of the scaffold whose `main.go` calls
  `win.CapturePage()` once (`PROBE_CAPTURE_OUT`) then quits; used to prove
  in-app screenshots of a native-UI window.

## 4. Development loop

```sh
cd prep/probe-native
go test ./...                          # ~0.4 s test; view runs without a window
go tool mygo vet                       # exit 0 = clean
go tool mygo dev                       # window opens; edits rebuild+relaunch
```

`go tool mygo dev` behavior (verified):

- builds `.mygo/darwin-arm64/probe-native Dev.app` (~1.4 s cold), prints
  `➜ Watching for changes`;
- editing a `.go` file prints `Rebuilding ... (<file> changed)` (~0.4 s) and
  relaunches the dev app; a broken build keeps the old app running;
- quit with **Ctrl+C** in the terminal (logs `Stopping ... Dev`, exit 0) or
  type `q` + Enter; the dev app window closes. On macOS the dev app is a real
  bundle with identifier `<id>.dev`.

Browser mode (only if the app also targets browsers):

```sh
go tool mygo dev -web -open=false      # builds wasm, serves http://localhost:5174
curl -sI http://localhost:5174/        # HTTP 200, Cache-Control: no-store
# Ctrl+C to stop; confirm the port is released: lsof -nP -iTCP:5174 -sTCP:LISTEN
```

## 5. Headless snapshots and determinism (recommended for CI)

Two equivalent APIs render a view without a window or GPU:

```go
img := ui.Render(view, 480, 360, 1)   // *image.RGBA, scale = device px per DIP
tt := ui.NewTester(view, 480, 360)    // frozen clock; click/type as a user
tt.Frame()
img = tt.Image()                      // last frame, *image.RGBA
```

Probe: `prep/probe-native/capture_test.go` writes PNGs, checks determinism and
theme control:

```sh
cd prep/probe-native
go test -v -run TestCapture .
# PROBE_CAPTURE_OK evidence=../../research/prep/evidence
```

Verified properties (details in ENVIRONMENT.md §7.2):

- same view/size/scale → **byte-identical PNGs**; `ui.Render` and
  `Tester.Image` agree;
- `MYGO_GPU` does not change headless output (no GPU needed in CI);
- headless default theme is **light regardless of system appearance**; force
  themes with `tt.SetDark(true|false)` (and `tt.SetScale`, `tt.SetPreferences`);
- platform text engines/fonts differ, so render the matrix **per OS** in CI
  (or embed a font with `ui.RegisterFont` for uniform text).

## 6. Build and package

All commands run in the project dir, with `CGO_ENABLED` unset (MyGo builds with
`CGO_ENABLED=0` by default — required for cross-compilation).

### 6.1 macOS (default)

```sh
go tool mygo build
```

Expected (cold, this machine):

```
✓ Compiled darwin/arm64  3.5s
✓ Signed probe-native.app  20ms
✓ Created probe-native-0.1.0-arm64.dmg  5.1s
✓ Built probe-native 0.1.0 in 8.9s
build/darwin-arm64/probe-native.app  9.1 MB
build/darwin-arm64/probe-native-0.1.0-arm64.dmg  3.0 MB
```

The `.app` is **ad-hoc signed** by default (`Signature=adhoc`), which is all
that local validation needs. `-skip-dmg` saves ~5 s; `-debug` keeps the native
UI inspector in the package.

### 6.2 Universal macOS (Apple silicon + Intel)

```sh
go tool mygo build -platform darwin/universal -skip-dmg
lipo -info build/darwin-universal/probe-native.app/Contents/MacOS/probe-native
# → arm64 x86_64 ; .app ≈ 18.8 MB, built in 3.9 s
```

### 6.3 Cross-compile Windows + Linux from macOS

```sh
go tool mygo build -platform darwin/arm64,linux/amd64,windows/amd64 -skip-dmg
```

Expected artifacts (all produced on macOS, no cross C toolchain):

```
build/darwin-arm64/probe-native.app                9.1 MB (adhoc-signed)
build/linux-amd64/probe-native                     9.0 MB ELF
build/linux-amd64/probe-native_0.1.0_amd64.deb     4.0 MB
build/linux-amd64/probe-native-0.1.0-linux-amd64.tar.gz 4.0 MB
build/linux-amd64/probe-native.desktop, install.sh, *.png
build/windows-amd64/probe-native.exe               9.4 MB PE32+ GUI
```

Notes:
- Windows **installer** is skipped on macOS (`makensis` absent; `mygo build`
  downloads NSIS only when run on Windows). Windows `.exe` runs without one.
- Linux `.deb`/`.tar.gz`/desktop entry *are* produced from macOS.
- Keep `-skip-dmg` for cross builds (a dmg adds ~5 s and only makes sense for
  the darwin target).
- Other arch combos: `linux/arm64`, `windows/arm64`, `darwin/amd64` are all
  valid `GOOS/GOARCH` values; `web` is a special platform (below).

### 6.4 Web/wasm (browser build)

```sh
go tool mygo build -platform web -o build-web
# 2.2 s → build-web/web/{index.html, <name>.<hash>.wasm 10.8 MB, wasm_exec.js, icon.png}
```

Serve that directory with any static server; the wasm name is content-hashed
for caching.

### 6.5 Signing / notarization (only when distributing)

Local builds need nothing. To ship outside this Mac, set in `mygo.json`:

```json
{ "macos": { "signingIdentity": "Developer ID Application: ...", "notarize": true } }
```

Requirements: a **Developer ID Application** certificate (this machine has only
an Apple Development identity), notarization credentials for `notarytool`, and
`-skip-notarize` to opt out. Windows: NSIS for installers + `signtool`
(Windows) or `osslsigncode`; updates: `mygo keygen` + `MYGO_UPDATER_PRIVATE_KEY`.
All of this is out of scope for phase-0 validation.

## 7. Run and inspect the real window (briefly!)

Launch the packaged binary directly (stdout/stderr stay attached, unlike `open`):

```sh
BIN=build/darwin-arm64/probe-native.app/Contents/MacOS/probe-native
MYGO_FRAME_STATS=all "$BIN" &            # frame stats on stdout
sleep 2
screencapture -x /tmp/probe-window.png   # full screen; needs Screen Recording perm.
kill %1                                  # close the window; verify: pgrep -fl probe-native
```

Frame stats prove the renderer at runtime:

- `(drawn on the GPU: 33 instances in 5 batches ...)` → **Metal** on macOS;
- `MYGO_GPU=0` (same run style) → `(drawn in memory)` → CPU fallback;
- first frame ~345 ms only on the first launch after boot (Metal pipeline
  setup); later first frames ~13 ms; idle frames ~0.1 ms.

In-app capture (what the future showcase app can use to export screenshots of
itself, incl. from CI):

```go
pngBytes, err := win.CapturePage()   // native-UI window → PNG of its content, 2× pixels
```

Verified: a 480×360 window returned a **960×656 PNG in 25,050 bytes**
(`prep/probe-capture/`, `research/prep/evidence/probe-capturepage.png`).

Cleanup rules (encoded in preflight):

```sh
pkill -f 'probe-native|probe-capture' || true
pkill -f 'mygo dev' || true
lsof -nP -iTCP:5174 -sTCP:LISTEN || true   # no dev server left
```

## 8. Automated preflight

```sh
prep/scripts/preflight.sh              # non-GUI, CI-safe, ~5 s warm
prep/scripts/preflight.sh --gui        # adds real window + Metal + screenshot check (~7 s)
prep/scripts/preflight.sh --verbose    # print failing command output
prep/scripts/preflight.sh --no-log     # do not refresh evidence/preflight-last.log
```

It checks: macOS/arm64, host Go, toolchain 1.27.3, mygo CLI 0.7.1, Bun/Xcode
(optional), probe `go.mod` (`go 1.27.3` + `tool` + MyGo v0.7.1), reference
checkout HEAD `b553a90` + clean tree, `mygo doctor`, `go test ./...`,
`mygo vet`, deterministic headless snapshots, macOS packaging,
linux+windows cross-compile, web/wasm build, optional GUI/Metal render, and
leftover processes. Builds go to a temp dir removed on exit, so re-running is
safe and leaves the workspace unchanged.

Exit code 0 = all PASS; 1 = something FAILed (details/logs printed in verbose
mode). `PROBE_DIR`, `MYGO_BIN`, `EXPECT_REF_HEAD` override defaults.

## 9. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `mygo: command not found` | `$HOME/go/bin` not on PATH → `export PATH="$HOME/go/bin:$PATH"`, or use `go tool mygo` inside the project. |
| `go: downloading go1.27.3` on every shell | First use per module cache; subsequent runs are cached in `$GOMODCACHE`. Persist `GOTOOLCHAIN=go1.27.3` in CI. |
| `mygo doctor` says `go go1.26.4` | You ran it outside a module. Run it inside the project (or with `GOTOOLCHAIN=go1.27.3`). |
| `mygo init` refuses to create the project | Directory must be new or empty; remove/recreate it. |
| `go tool mygo generate` exits 1 | Native-only projects have no frontend client; `generate` is for web apps/bindings (`-o` can force a file). |
| First frame 300+ ms | Metal pipeline setup on first-ever launch; not a hang. |
| GUI window never appears | No WindowServer session (SSH/headless) or the app exited: run the binary directly and read stderr; check `pgrep -x WindowServer`. |
| `mygo dev` seems stuck / no rebuild | Output shows `Watching for changes`; changes must be saved under the project. For scripted shutdown send SIGINT to the innermost `mygo dev` process, then `pgrep -fl 'mygo dev'`. |
| Port 5174 busy for `dev -web` | Use `-port 5200`, or let it pick the next free port; stop old servers (`pkill -f 'mygo dev'`). |
| `screencapture` gives a blank/denied image | Grant the terminal Screen Recording permission (System Settings → Privacy & Security); headless CI should use `CapturePage`/`ui.Render` instead. |
| Cross-compile fails | Must not set `CGO_ENABLED=1`; MyGo is pure Go. Check `go env CGO_ENABLED` and `go.mod` go directive. |
| `codesign`/notarize errors on distribution | No Developer ID Application identity on this Mac (only Apple Development); acquire a Developer ID or build unsigned/ad-hoc for local use. |
| `makensis`/`osslsigncode` warnings | Optional Windows packaging/signing tools, absent on macOS; cross-built `.exe` works without an installer. |
| Preflight fails "reference checkout HEAD" | `reference/mygo` moved off `b553a90`; update `EXPECT_REF_HEAD` deliberately or restore the pin. Never edit that checkout. |

## 10. Reproducing this phase's evidence

Run these from `prep/probe-native` (logs land in `research/prep/evidence/`):

| Evidence | Command |
|---|---|
| Toolchain/CLI | `go version`, `go env GOROOT`, `mygo version`, `mygo doctor` |
| Headless tests/snapshots | `go test -v ./...`; `go test -v -run TestCapture .` |
| GPU determinism | `MYGO_GPU=0 PROBE_EVIDENCE_DIR=/tmp/gpu go test -v -run TestCapture .` then compare `shasum -a 256` |
| macOS package | `time go tool mygo build` |
| Cross-compile | `time go tool mygo build -platform darwin/arm64,linux/amd64,windows/amd64 -skip-dmg` |
| Universal | `time go tool mygo build -platform darwin/universal -skip-dmg` |
| Web | `time go tool mygo build -platform web -o build-web` |
| Real window + GPU | `MYGO_FRAME_STATS=all build/darwin-arm64/probe-native.app/Contents/MacOS/probe-native` (then kill) |
| Live reload | `go tool mygo dev`, edit `main.go`, watch output, Ctrl+C |
| Web dev | `go tool mygo dev -web -open=false`, `curl http://localhost:5174/`, Ctrl+C |
| Everything | `prep/scripts/preflight.sh --gui` |

## 11. Notes for the future showcase app (phase 1+)

1. Keep the pins: `go 1.27.3`, `tool github.com/egoist/mygo/cmd/mygo` with
   `require github.com/egoist/mygo v0.7.1` in `go.mod`; commit `go.sum`.
2. Copy `prep/probe-native/capture_test.go` as the base of a per-OS snapshot
   test: render each showcase view with `ui.Render`, force themes with
   `tt.SetDark`, walk pages in deterministic order, and diff PNGs in CI per OS.
3. For an in-app "export screenshots of itself" feature, use
   `win.CapturePage()` on the native window (works on all three backends; for
   content windows it renders MyGo UI, no OS permission needed).
4. Keep GUI runs brief and always clean up (`pgrep`/`pkill`, close windows).
5. Windows/Linux *runtime* validation and distribution signing remain the
   phase-1 gaps: plan a CI matrix (windows-latest, ubuntu-latest with
   GTK 3/WebKitGTK only if web windows are used) and a Developer ID +
   NSIS/osslsigncode path for release artifacts.
