# ObeseCat Meltdown — prototype handoff

## Direction to preserve

Cats are central. The cat is relaxed, enormous, and convinced the player is doing excellent work. Retro containment monitor: near-black, neon cyan, magenta, radioactive green, hand-authored bitmap typography, stepped pixel silhouette, scanlines and separated color outlines. Exact end-screen lines: **FACILITY: LOST** and **CAT: FINE**. No progression systems, monetization, backend, or extra modes.

## Stack decision

The repository initially contained only `.gitattributes`. Unity 6000.4.3f1 and its WebGL module were present, but batch startup exited 198 with `No valid Unity Editor license found`. No license or account changes were attempted. The existing Godot 4.7.2 portable download ran successfully. Godot is the sole implementation; the initial uncompiled Unity scaffold was removed. There is no browser build. Keep this project small and native to Godot.

## Loop and tuning

### Difficulty selection (v0.3.0)

Easy preserves the original tuning below. Normal/Hard share the opening five purrs, then use a staged ramp: score 5 starts at 10% strength, rising to 23% at 11; 12 spikes to 36%, rising to 50% at 23; 24 spikes to 63%, rising to 73% at 31; 32 spikes to 84%, rising to 96% at 50; the final push reaches 100% at 55 and caps there. This interprets the requested ramp-to-50 as the main ramp, followed by the explicit maximum-at-55 endpoint.

Normal's phase speed rises to 3.6 radians/second at 55; Hard's to 4.2. Width floors remain 11–13% Normal and 7.5–9.5% Hard. At 55, both cover the bar with the window's left edge reaching 10% and its right edge reaching 100%. Normal sweeps smoothly. Hard adds bounded variable speed at 12, then braking/reversals at 24 and 32, using deterministic time-based modulation instead of random teleportation. Phase freezes with pause. A successful pet restarts the next Normal/Hard sweep on the right to prevent its only crossing occurring during the input cooldown.

High difficulty is intentionally demanding: across sampled starting phases, shortest longest contiguous windows were ~71 ms Normal and ~33 ms Hard. Tests verify bounds, milestones, the 55-purr cap, identical practice, and 100 successive scoring opportunities. Human phone playtesting remains necessary for feel, especially at the Hard cap.

Themes: Easy lime #beff59; Normal neon violet #c879ff; Hard red #ff505a. Palette mapping covers the cat, UI, safe window, purr, mushroom cloud and warm highlights; cyan/magenta accents stay. Difficulty buttons retain their own identity colors. Normal gets suspicious brows and cosmic flavor text; Hard gets angry brows and sinister petting praise. Text cues remain authoritative so safe/unsafe states do not rely solely on color.

Selection uses three 104x44 logical-pixel buttons, persists between launches, and stays fixed during a run. The failure footer's MODES button returns to selection. Best scores remain independent; legacy `best` migrates to Easy. APK versionCode is 3, versionName 0.3.0, using the existing debug signing key for in-place upgrades.

### Shared rules and original Easy tuning

- Charge begins at 22%. Through the first five successful pets, the safe window is inclusive 66–90%. At 100%, the facility is lost.
- Once the score reaches 5, the next window starts narrowing, breathing in width and drifting smoothly. Difficulty starts at 12% strength and gains 3.5% per additional purr, capping at score 31. Width shrinks from 24 percentage points toward 16–18; the center drifts by up to 4.5 points with a small per-cycle offset. Motion uses reactor age and pauses with gameplay. Reset restores the original window.
- At score 25, drift becomes 25% faster, then gains 3.75% of the original speed per purr until it reaches double speed at score 45. Phase is integrated over simulation time so speed changes cannot teleport the zone. Pause freezes phase; retry resets it. Width and drift distance retain their existing caps.
- Charge rate starts at 20.5 percentage points/second, gains 0.6 points/second per score, caps at 34. Initial safe duration is 1.17 seconds; sampled moving-window passes remain above 0.38 seconds at maximum difficulty. Rendering, ring color, missed-window warnings and pet evaluation all read the same current boundaries.
- A completed swipe of at least 32 logical pixels scores once if safe. It resets pressure to 22%. Any direction works; gesture duration is unconstrained and timing is evaluated on release.
- A bad pet adds 16 percentage points. It also starts/restarts 0.9 seconds of visible irritation, during which a pet cannot score. This closes the loophole where rapid early swipes could push pressure into the safe window and score automatically. A separate 0.36-second cooldown ignores immediate duplicate attempts.
- One finger owns a gesture. Other fingers and canceled touches cannot score. Touch-to-mouse emulation is disabled. Mouse uses the same gesture completion path.
- Failure now plays a 2.8-second authored mushroom-cloud sequence: core ignition, expanding shockwave, rising hot stem, scalloped crown, pixel fallout and signal decay, then the smug surviving cat. A synthesized filtered-noise/sub-bass blast replaces the old failure tone. Retry remains available after 0.65 seconds, allowing players to skip the spectacle. No scene reload. Background/focus loss pauses the reactor until the player resumes.
- Low FX suppresses sparks, shake, skeleton disruption, and shockwaves; scanline opacity drops. Sound is synthesized with short envelopes and a mute control.

## Files

- `reactor.gd`: engine-independent charge/score/penalty rules.
- `game.gd`: input ownership, modes, audio, persistent preferences, animation and scene composition.
- `explosion.gd`: procedural pixel mushroom cloud choreography. Reduced FX retains the cloud but omits shake, debris, shockwave and signal tearing. Render captures: `blast_early`, `blast`, `blast_low`, `lost`.
- `pixel_canvas.gd`, `glyphs.json`: original pixel shapes and complete uppercase bitmap alphabet. No external art/font licenses or sibling project assets.
- `tests/test_reactor.gd`: rules and gesture integration checks against the production implementation.
- `run.ps1`: local portable engine launcher; does not install system software or download packages.
- `export_presets.cfg`: Android ARM64 and Windows setup, awaiting export toolchains.

## Verification and remaining work

Android export completed on 2026-09-04: `builds/android/ObeseCatMeltdown.apk`, 28,284,127 bytes, package `com.obesecat.meltdown`, version 0.1.0, ARM64, min API 24, target API 36. APK Signature Schemes v2/v3 verify, and manifest inspection found no requested permissions. `build-android.ps1` uses an isolated settings copy and the installed SDK build tools 36.0.0, JDK 21 and matching Godot templates. Android texture import compression is enabled. No physical-device installation or runtime test has been performed yet.

Completed on 2026-09-04: rule/input test runner passed; 150 consecutive simulated controlled purrs passed; spam, boundary, touch ownership, canceled touch, pause and retry checks passed. Ready/safe/purr/lost frames were rendered through OpenGL on Radeon RX Vega and visually inspected. Windows resource-pack export produced a 23,984-byte PCK; that compiled package ran for 120 frames and exited successfully. This was automated execution and visual frame review, not a manual or physical-device playtest. The engine's synthesized sound output was not auditioned.

Run `run.ps1 -Test` after mechanical changes. Real OpenGL captures cover ready, safe, purr and failure states. Their fixed states are intentionally separate from interactive playtesting. A sandbox-specific root certificate store warning is emitted by this Godot binary at startup; this offline game still loads, renders and executes tests. No network operation is used by the game.

Before calling this Android-ready, produce/install a debug APK and test on a physical phone: 60-second repeated play; fast and slow swipes; second finger and canceled gesture; background/resume; notches and gesture navigation; sound mute persistence; reduced effects; best-score persistence; stable performance and battery/thermal behavior. Rendering uses immediate pixel primitives for simplicity; profile actual hardware before optimizing or replacing this with an atlas.

The first requested feel pass should focus on forgiving timing and making a single purr delightful. Do not extend scope to upgrade trees, currencies, collections, accounts, ads, or store publishing.
