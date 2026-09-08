# Normal post-cap pattern experiment

Normal's original curve remains in place through 55 purrs. Each successful purr after that selects one of four profiles (measured sweep, fast-to-slow, slow-to-fast, and rolling pace), excluding the previous profile. Direction and a small starting-phase offset vary per attempt. Movement stays continuous throughout each attempt; safe-window width, pressure, mistake penalty, and cooldown remain unchanged. Profile speeds stay below the old maximum, with a 0.85 speed factor to leave room for reacting to unfamiliar timing.

400 seeded attempts across different width-breathing ages passed a 75 ms minimum first usable opening, with first openings ranging from roughly 0.49 to 0.89 seconds. Attempts offered either one or two openings without artificially rejecting valid swipes. This is a sampled safety check, not proof of equal perceived difficulty; real playtesting determines whether the variety feels fair.

Run `./build-android.ps1 -PatternTest` to build `builds/android/ObeseCatMeltdown-PatternTest.apk`. It installs as a separate app/package, Normal starts at 55, and progression is not saved or paid out. Choose Normal, land the first purr, then the randomized profiles begin at 56. Easy and Hard keep their existing rules.

The live integraltec.ai version is unchanged pending feedback. Coin rewards now use the shared capped milestones: 15 purrs for 1 coin, 35 for 2, and 50 for 3.
