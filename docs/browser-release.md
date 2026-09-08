# Browser release handoff

Run `./build-web.ps1` to export the single-threaded Godot release to `builds/web`. The launch page source is `web/index.html`. `DEV_COINS_ENABLED` is false; the older testing APK is unchanged.

IntegralTec integration:
- `src/pages/Portfolio.jsx`: Meltdown card before COUNTY.EXE in Creative Software.
- `src/index.css`: scoped portrait screenshot styles.
- `src/assets/portfolio/obesecat-meltdown/gameplay.png`: actual game capture.
- `public/games/obesecat-meltdown/`: copy of `builds/web`, including the game subfolder.

For subsequent updates, rebuild the web export and copy its contents to the existing public game folder. Do not run the initial integration helper again (it appends CSS). Build the ITS site through Netlify to retain its existing environment variables. No cross-origin isolation headers are needed for this single-threaded export. The game uses WebGL 2 and stores progress in browser-local storage; clearing site data removes progress. Keep the URL stable for saved progress.

Validation: engine rules, public developer-button exclusion, all cosmetic purchases, slot exclusivity, and persistence tests; browser launch, correctly sized portrait canvas, store, and run start. Physical mobile browser testing is still recommended before announcing broadly.
