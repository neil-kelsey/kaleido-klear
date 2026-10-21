VERSION: 1.2.0

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

The wing beat, the mist sweep, and the dust always play. `respect_reduce_motion` is an exported opt-in and defaults to off, so the operating-system query is ignored unless a game turns it on.

`DisplayServer.accessibility_should_reduce_animation()` returns an int, not a bool: `1` when the system asks for less motion, `0` when it does not, and `-1` when the status is unknown. Godot implements that call on macOS and Windows only. Android, and a headless run, return `-1`. Version 1.1.0 stored the int in a bool. Any value other than `0` becomes true, so `-1` took the reduced-motion path and the splash cut from the dark moth to the light moth with no wing beat.

When `respect_reduce_motion` is on and the call returns exactly `1`, the flap and the wipe still run, in about half the time (0.55 of normal). They are not removed. Unknown (`-1`) does not shorten anything. The dark hold and the light hold stay as they are, and the fade shortens from 0.4s to 0.28s.

## Changelog

### 1.2.0

The flap, mist, and dust play by default. Reduced motion is an explicit opt-in (`respect_reduce_motion`, default false) and, when enabled, only shortens the flap, and only when `accessibility_should_reduce_animation()` returns `1`. It no longer replaces the beat with an instant colour cut. This fixes the Pixel 7a splash: that call returns `-1` (unknown) on Android, and 1.1.0 treated the non-zero int as true, which skipped the wings.

### 1.1.0

Dark and light holds of 1.5s each, a shared `addons/veilmoth_splash` folder, and a rig that fits and centres in any viewport.

## Layout

The moth is one 1280×720 canvas. The splash fits that canvas to the viewport width, leaving a margin, and shrinks it further if the height would not fit. It is then centred. Wings at rest already span the canvas, and the beat only draws them inward, so a full flap stays inside the screen. This uses the viewport's visible rectangle, so it follows portrait and landscape windows, phone sizes such as 1080×1920 and 1080×2400, and both the `canvas_items` and `viewport` stretch modes, whatever base resolution the host project uses.
