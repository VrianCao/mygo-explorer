package main

// Throwaway probe (env-prep, phase 0): verifies that a native-UI view can be
// rendered to a PNG without a window or GPU, for deterministic snapshots.
//
//	go test -run TestCapture -v ./...
//
// Writes probe-render-*.png to $PROBE_EVIDENCE_DIR (default ../../research/prep/evidence).

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"image"
	"image/png"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/egoist/mygo/ui"
)

func evidenceDir(t *testing.T) string {
	t.Helper()
	dir := os.Getenv("PROBE_EVIDENCE_DIR")
	if dir == "" {
		dir = filepath.Join("..", "..", "research", "prep", "evidence")
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatalf("mkdir evidence: %v", err)
	}
	return dir
}

func writePNG(t *testing.T, dir, name string, img image.Image) string {
	t.Helper()
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatalf("encode %s: %v", name, err)
	}
	path := filepath.Join(dir, name)
	if err := os.WriteFile(path, buf.Bytes(), 0o644); err != nil {
		t.Fatalf("write %s: %v", name, err)
	}
	sum := sha256.Sum256(buf.Bytes())
	b := img.Bounds()
	t.Logf("%s: %dx%d px, %d bytes, sha256=%s", name, b.Dx(), b.Dy(), buf.Len(), hex.EncodeToString(sum[:8]))
	return path
}

// TestCapture renders the generated counter view headlessly with ui.Render
// (snapshot API) and with a ui.Tester (frame + Image), and checks that two
// renders at the same size are byte-identical (deterministic).
func TestCapture(t *testing.T) {
	dir := evidenceDir(t)
	a := &app{name: "Ada", count: 3}

	const w, h = 480, 360

	start := time.Now()
	img1 := ui.Render(a.view, w, h, 1)
	renderDur := time.Since(start)
	frames := 0
	if img1 == nil {
		t.Fatal("ui.Render returned nil")
	}
	png1 := writePNG(t, dir, "probe-render-scale1.png", img1)
	t.Logf("ui.Render %dx%d scale=1: %v", w, h, renderDur)

	start = time.Now()
	img2 := ui.Render(a.view, w, h, 2)
	render2Dur := time.Since(start)
	writePNG(t, dir, "probe-render-scale2.png", img2)
	t.Logf("ui.Render %dx%d scale=2: %v", w, h, render2Dur)

	// Determinism: same view, same size, same scale -> identical PNG bytes.
	start = time.Now()
	img3 := ui.Render(a.view, w, h, 1)
	render3Dur := time.Since(start)
	png3 := writePNG(t, dir, "probe-render-again.png", img3)
	t.Logf("ui.Render again: %v", render3Dur)
	b1, err := os.ReadFile(png1)
	if err != nil {
		t.Fatal(err)
	}
	b3, err := os.ReadFile(png3)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(b1, b3) {
		t.Errorf("ui.Render is not deterministic: sha256 of first=%x again=%x",
			sha256.Sum256(b1), sha256.Sum256(b3))
	} else {
		t.Logf("ui.Render deterministic: two renders byte-identical (%d bytes)", len(b1))
	}

	// Tester path: drive a frame, then take tt.Image().
	start = time.Now()
	tt := ui.NewTester(a.view, w, h)
	tt.Frame()
	img4 := tt.Image()
	testerDur := time.Since(start)
	if img4 == nil {
		t.Fatal("tt.Image() returned nil")
	}
	writePNG(t, dir, "probe-tester-image.png", img4)
	t.Logf("ui.NewTester+Frame+Image: %v", testerDur)

	// A click/type-driven frame, as the future snapshot matrix will do.
	start = time.Now()
	if err := tt.Click("+"); err != nil {
		t.Fatalf("tester click: %v", err)
	}
	frames++
	img5 := tt.Image()
	writePNG(t, dir, "probe-tester-clicked.png", img5)
	t.Logf("tester click + image: %v (count=%d, frames>%d)", time.Since(start), a.count, frames)

	// Sanity: the render is not blank.
	nonBlank := 0
	for i := 0; i+3 < len(img1.Pix); i += 4 {
		if img1.Pix[i] != img1.Pix[0] || img1.Pix[i+1] != img1.Pix[1] || img1.Pix[i+2] != img1.Pix[2] {
			nonBlank++
		}
	}
	t.Logf("non-uniform pixels in ui.Render output: %d", nonBlank)
	if nonBlank == 0 {
		t.Error("render is uniform (blank)")
	}
	fmt.Printf("PROBE_CAPTURE_OK evidence=%s\n", dir)
}
