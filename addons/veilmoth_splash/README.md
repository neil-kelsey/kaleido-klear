VERSION: 1.1.0

# Veilmoth splash

A Godot 4.7 boot splash for Veilmoth Games. Copy this folder into another project and both games play the same splash. Nothing in the folder refers to a host game.

The splash shows the dark moth, beats the wings once, wipes to the light moth, then fades into whatever scene you name.

## Install

1. Copy the `veilmoth_splash` folder into the project's `addons/` directory, so the scene is `res://addons/veilmoth_splash/veil_splash.tscn`.
2. Set these two project settings:
   - `application/run/main_scene` = `res://addons/veilmoth_splash/veil_splash.tscn`
   - `veilmoth_splash/next_scene` = the scene to open after the splash, for example `res://scenes/ui/main_menu.tscn`
3. Keep Godot's own boot splash from flashing white. Under `application`:
   - `boot_splash/show_image` = `false`
   - `boot_splash/bg_color` = `#0B0B0B`, written as `Color(0.0431373, 0.0431373, 0.0431373, 1)`

In `project.godot` that looks like:

```
[application]

run/main_scene="res://addons/veilmoth_splash/veil_splash.tscn"
boot_splash/show_image=false
boot_splash/bg_color=Color(0.0431373, 0.0431373, 0.0431373, 1)

[veilmoth_splash]

next_scene="res://scenes/ui/main_menu.tscn"
```

## Which scene comes next

The splash reads a single path, in this order, and loads that scene on a background thread:

1. The exported `next_scene_path` on the splash node, if it is not empty.
2. The project setting `veilmoth_splash/next_scene`.
3. The project setting `application/run/main_scene_after_splash`.

Leave `next_scene_path` empty in the shared scene so every game uses its own project setting and the folder stays identical. `application/run/main_scene_after_splash` is only a fallback for a project that already had that key.

## Timing

`dark_hold_sec` and `light_hold_sec` are exported on the splash (both default to 1.5). They are the knobs to tune.

- The dark moth stays up for at least `dark_hold_sec`. If the next scene is still loading when that time is up, the splash waits for the load.
- Then one wing beat, the dust, and the 0.9s mist wipe run together. The moth swaps from dark to light at the middle of the wipe.
- After the wipe has finished, the light moth holds for `light_hold_sec`.
- The splash then fades out over 0.4s.

When loading is instant, the splash lasts 1.5 + 0.9 + 1.5 + 0.4 = 4.3 seconds. A tap, or `handle_back()` from the host, skips straight to the next scene.

The progress bar stays hidden if the load finishes within 0.3s, so it does not flash on a fast machine. If loading is still going after 0.3s, the bar appears and tracks `ResourceLoader` progress, then hides as soon as the load finishes.

If the operating system asks to reduce animation, the wing beat, dust, and wipe are skipped. The dark hold and the light hold still run, and the fade is 0.28s. There is no switch for this inside the splash.

## Layout

The moth is one 1280×720 canvas. The splash fits that canvas to the viewport width, leaving a margin, and shrinks it further if the height would not fit. It is then centred. Wings at rest already span the canvas, and the beat only draws them inward, so a full flap stays inside the screen. This uses the viewport's visible rectangle, so it follows portrait and landscape windows, phone sizes such as 1080×1920 and 1080×2400, and both the `canvas_items` and `viewport` stretch modes, whatever base resolution the host project uses.
