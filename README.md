# ObeseCat Meltdown

**A little pet. A lot of fission.** An original, portrait, one-swipe timing game built with Godot 4.7.2. One enormous radioactive cat. One containment ring. Very questionable employment conditions.

## Play now on Windows

Choose **Easy**, **Normal**, or **Hard** before starting. Easy preserves the original tuning. All modes share the opening five purrs; Normal and Hard then ramp with spikes at 12, 24 and 32 purrs, building through 50 to maximum speed and nearly full-bar travel at 55. Normal is neon violet with smooth sweeps; Hard is red with erratic braking and reversals. Best scores are separate for each difficulty. After a meltdown, tap **MODES** along the bottom to change difficulty, or tap to retry the same one.

Double-click `Play.cmd`, or from this folder in PowerShell:

```powershell
.\run.ps1
```

The launcher uses Godot on PATH, or the existing Godot 4.7.2 archive in your Downloads folder. It extracts that archive into a temporary portable engine folder if needed. It downloads nothing. You can specify another Godot 4 executable:

```powershell
.\run.ps1 -Godot 'C:\Tools\Godot\Godot.exe'
```

Tap/click to start. Let the cat inflate. When the ring turns **green** and says **PET NOW**, swipe across the chamber and release. A mouse drag also works, in any direction. A tap is not a pet. After five purrs, the safe zone gradually narrows, changes width, and drifts along the pressure bar as difficulty grows. Early pets increase pressure and irritate the cat; let him settle before trying again. Waiting too long ends the shift. Tap to rebuild after the short failure beat.

Sound, pause, and reduced-effects controls sit along the bottom. Escape pauses. Losing focus pauses the game. Best score and preferences stay local. The launcher stores them in `.godot/portable-data`; running directly through your own editor uses Godot's normal user-data folder. No networking, accounts, analytics, ads, or paid assets.

## Edit and verify

```powershell
.\run.ps1 -Editor
.\run.ps1 -Test
```

Alternatively import `project.godot` in Godot and press F6 on `main.tscn` or F5. Tests exercise the actual rules and input handlers, including spam, timing boundaries, multitouch, cancellation, pause, and retry. `game.gd --capture` support provides deterministic real renderer screenshots:

```powershell
godot --path . -- --capture=ready
godot --path . -- --capture=safe
godot --path . -- --capture=purr
godot --path . -- --capture=lost
```

Captures are written to `captures/`. These are authored test states rendered by the game, not evidence of a manual playthrough.

## Android and desktop export

An Android debug APK has been built and signature-verified at `builds/android/ObeseCatMeltdown.apk`. It targets ARM64, Android 7.0/API 24 or newer, with portrait orientation and no requested permissions. Rebuild on this machine with:

```powershell
.\build-android.ps1
```

The helper uses the installed Java/Android SDK and Godot 4.7.2 templates, creates an isolated configuration under `.godot/android-build`, and verifies the APK signature. It preserves the open editor settings. Keep the existing debug keystore under `.godot/portable-data/Godot/keystores` for compatible updates; do not commit it. The helper accepts `-Godot`, `-AndroidSdk`, and `-JavaSdk` overrides.

For another machine, install matching export templates and configure its SDK/JDK and debug signing key. Android and Windows presets are included.

With those prerequisites installed:

```powershell
godot --headless --path . --export-debug Android builds/android/ObeseCatMeltdown.apk
godot --headless --path . --export-debug 'Windows Desktop' builds/windows/ObeseCatMeltdown.exe
```

Create the destination folders first when using the raw Godot commands. Physical Android performance, audio, touch feel, safe areas, and installation remain untested; the APK is ready for that testing.

A compiled resource package was successfully built at `builds/ObeseCatMeltdown.pck` and smoke-tested with the real OpenGL renderer. It still requires the Godot engine to run. Rebuild and run it with your Godot executable:

```powershell
godot --headless --path . --export-pack 'Windows Desktop' builds/ObeseCatMeltdown.pck
godot --main-pack builds/ObeseCatMeltdown.pck
```

Build outputs are ignored by Git; the complete source and presets are tracked with the project.

See [design and handoff](docs/HANDOFF.md) for mechanics, architecture, and remaining acceptance checks.

## Reactor Supply shop

Open **STORE** beside **MODES** on the ready or results screen. Coins, ownership, and equipped cosmetics are separate for Easy, Normal, and Hard. Purchases auto-equip; select an owned item to equip or remove it. Browse 11 slot categories: head, eyes, neck, left arm, right arm, feet, tail, background, symbol, pet, and special skin. One item per slot can be equipped; previews replace only their slot and do not change your saved outfit. Left/right refer to the cat's own sides. The selected card previews on your actual cat before purchase.

A finished run earns a capped milestone payout once per meltdown: 0–14 purrs = 0 coins, 15–34 = 1 coin, 35–49 = 2 coins, and 50+ = 3 coins. Payment occurs once per meltdown, even below your personal best. Wallets remain difficulty-specific and the per-run payout never exceeds 3 coins.

Fedora: 3 coins; Pikachu tail: 5; necktie: 3; pixel sword (cat's right hand): 5; pixel shield (cat's left hand): 5; Matrix code background: 20. Additional items: peg leg (right foot), cast (left foot), sunglasses, eyeglasses, silver chain, gold chain, and top hat: 3 coins each; eyepatch (right eye) and army helmet: 5 each; camera on a neck strap and animated snow: 10 each. FX LOW freezes both background animations. Cosmetics do not alter game rules.

The developer coin button is disabled in source and public web builds (`DEV_COINS_ENABLED = false`). The earlier phone-testing APK still includes the button. Saves remain in the existing local settings file. No exported builds are updated automatically by source edits.

Further cosmetics: propeller beanie and traffic cone hat (head, 5 each), laser eyes (eyes, 10), oversized headphones (neck, 5), pizza slice (left arm, 3), microphone (right arm, 5), roller skates (both feet, 5), bunny slippers (both feet, 5), devil-arrow tail (tail, 5), concert stage with moving lights and crowd silhouettes (background, 15). FX LOW freezes the propeller, laser glow, stage lights, and crowd movement.

Space/art additions: red phase sword (right arm, 10), blue phase sword (left arm, 10), space helmet (head, 5), soda bottle (right arm, 3), milkshake (left arm, 3), night vision goggles (eyes, 5), guitar neck (tail, 5), paint brush (right arm, 3), paint palette (left arm, 3), game controller (right arm, 3), radioactive background (20). Phase blade glow and the radioactive trefoils/particles animate unless FX LOW is enabled. All items retain separate ownership per difficulty.

ITS machinery addition: CRT Telemetry background (20 coins). A bank of phosphor-green CRT monitors with active oscilloscope sine waves, live memory spectrum bars, rack-mount status LEDs, and an analog gauge needle that dynamically react to the reactor's core charge percentage.

Tribute additions: Singularity / Event Horizon tail (10 coins, swirling gravitational lensing vortex with photon ring and black hole core at the tail tip), The Eliteseum Pit background (20 coins, underground punk venue brick wall with band stickers, crowd surfers in silhouette, and sweeping hot pink / caution-yellow stage strobes), All-Access VIP Laminate (5 coins, black lanyard with pink stitching holding a laminated VIP pass card with barcode), and Pixel Torch (5 coins, blocky 16-bit oak torch with animated 3-frame yellow/orange flame). FX LOW freezes vortex rotation, strobe sweeps, and flame flicker.

Footwear additions (FEET): Hazard Steel-Toe Boots (5 coins, heavy lug soles with caution-yellow steel caps and pull tabs), Punk Combat Boots (5 coins, 8-eyelet black boots with yellow welt stitching and heel pull loops), Checkerboard Slip-Ons (5 coins, vulcanized white rubber loafers with 2-tone checkerboard vamp), Anti-Grav Mag-Boots (10 coins, pressurized lunar astronaut boots with pulsating cyan magnetic solenoids), Light-Up LED High-Tops (5 coins, 90s basketball sneakers with 4 flashing pink/cyan micro-LEDs along the translucent soles), Diving Fins (5 coins, oversized flared caution-yellow rubber flippers with drainage vents), and Mismatched Tube Socks (3 coins, athletic ribbed cotton slouch socks with red and blue stripes). FX LOW freezes solenoid pulsing and LED flashing.

Browser export: run `./build-web.ps1`. See `docs/browser-release.md` for the IntegralTec portfolio integration and update process.
