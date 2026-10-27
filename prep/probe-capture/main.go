package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/ui"
)

// app is the state the window shows. Its view builds the interface from
// it, on the main thread, whenever the window needs a frame: after input,
// after Window.Update, and while something animates.
type app struct {
	name  string
	count int
}

func (a *app) view(c *ui.Context) {
	t := c.Theme()
	ui.Column(c).Fill().Center().Gap(16).Padding(24).Children(func() {
		ui.Text(c, "probe-native").FontSize(26).Bold()
		ui.TextInput(c, &a.name).Placeholder("Your name").Label("Name").Width(240)
		greeting := "Hello!"
		if a.name != "" {
			greeting = fmt.Sprintf("Hello, %s!", a.name)
		}
		ui.Text(c, greeting).TextColor(t.TextMuted)
		ui.Row(c).Gap(10).AlignItems(ui.Center).Children(func() {
			if ui.Button(c, "−").Width(44).Clicked() {
				a.count--
			}
			ui.Textf(c, "%d", a.count).FontSize(20).Width(48).TextAlign(ui.Center)
			if ui.PrimaryButton(c, "+").Width(44).Clicked() {
				a.count++
			}
		})
	})
}

func main() {
	a := &app{}
	var win *mygo.Window
	mygo.App.WhenReady(func() {
		win = mygo.NewWindow(mygo.WindowOptions{
			Title:     "probe-native",
			Width:     480,
			Height:    360,
			MinWidth:  320,
			MinHeight: 280,
			// Opens where the user left it last time.
			StateKey: "main",
			// The window shows the interface MyGo draws, not a web page.
			Content: ui.View(a.view),
		})
		// Probe: Window.CapturePage() for a native-UI (Content) window must
		// return PNG bytes. Captures once, writes them, quits.
		if out := os.Getenv("PROBE_CAPTURE_OUT"); out != "" {
			after := time.Second
			if s := os.Getenv("PROBE_CAPTURE_DELAY"); s != "" {
				if d, err := time.ParseDuration(s); err == nil {
					after = d
				}
			}
			go func() {
				time.Sleep(after)
				png, err := win.CapturePage()
				if err != nil {
					log.Printf("CAPTURE_FAIL: %v", err)
					mygo.App.Exit(1)
					return
				}
				if err := os.WriteFile(out, png, 0o644); err != nil {
					log.Printf("CAPTURE_WRITE_FAIL: %v", err)
					mygo.App.Exit(1)
					return
				}
				log.Printf("CAPTURE_OK: %d bytes -> %s", len(png), out)
				mygo.App.Quit()
			}()
		}
	})
	if err := mygo.App.Run(); err != nil {
		log.Fatal(err)
	}
}
