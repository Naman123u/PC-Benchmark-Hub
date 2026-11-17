# PC Benchmark Hub 3.0

A multi-page PC compatibility website with a local Windows hardware companion, live Steam store search, published PC requirements, and searchable GPU/CPU catalogues.

## Files

- `index.html` — dashboard / landing page
- `games.html` — search for games and browse featured titles
- `game.html` — one game's minimum/recommended requirements and PC comparison
- `my-pc.html` — scan, refresh and view your computer's hardware
- `gpus.html` — searchable graphics card catalogue
- `compare.html` — side-by-side GPU comparison
- `cpus.html` — searchable processor catalogue
- `style.css`, `app.js` — shared site design and browser logic
- `PC-Companion.ps1` — local, read-only Windows hardware and Steam lookup bridge
- `START-PC-HUB.bat` — starts the companion and opens the hosted site

## Install on your GitHub Pages site

1. Open your repository: `Naman123u/PC-Benchmark-Hub`.
2. Upload **all files in this folder** to the repository root, replacing the old files with the same names. Keep the `.ps1` and `.bat` files beside the HTML files in the downloaded folder on your PC.
3. Wait for GitHub Pages to publish the new files. The live site should be `https://naman123u.github.io/PC-Benchmark-Hub/`.
4. On the Windows PC you want to scan, extract this ZIP to a normal folder.
5. Double-click `START-PC-HUB.bat` in that extracted folder. Windows may ask you to confirm that you want to run a script; only continue if you downloaded these files from your own trusted copy of this project.
6. The launcher starts the local companion and opens the Game Finder with a one-session connection token. It then scans your PC automatically. Search a game or open **My PC** to view the report.

You must replace/upload the website files to GitHub Pages before using the BAT, because the launcher opens the hosted website URL. The BAT and PowerShell companion must remain together in the same folder on your Windows PC.

## How the automatic scan works

The BAT starts `PC-Companion.ps1` in the background. The companion listens only on `127.0.0.1:8765` (your own computer), reads basic hardware fields using Windows CIM, then responds to the browser's scan request. It does **not** create a JSON report file. The browser saves the scan in its own local storage so it is available when you reopen the site in the same browser profile.

A one-session random token is passed in the launch URL, stored in that browser tab's session storage, and required by the local companion. The companion accepts browser requests only from `https://naman123u.github.io`. It does not expose a general file reader, shell command endpoint, or arbitrary URL proxy. The companion also proxies only the fixed Steam store search/details endpoints so the browser can search without exposing browser CORS restrictions.

Use **My PC → Disconnect companion** to stop the local bridge. Running the BAT again closes an old PC Hub companion first and starts a new one.

## Game catalogue and requirements

The game finder queries Steam's store search when you submit a search term. That lets you search many thousands of Steam-listed titles on demand without bundling a gigantic static list in the website. The local reference catalogue currently contains 119 GPU models and 65 CPU models. It does not include every PC game: titles not listed on Steam (for example some launcher-exclusive games) will not show up. Steam search returns relevant matches for your query; this is not an offline export of the entire Steam catalogue. A game's PC requirements appear only when its Steam store page publishes them.

The original minimum/recommended requirement text is displayed so you can inspect it. The checker recognises common CPU/GPU model names and RAM values, then compares the detected models against approximate relative-tier catalogues. Requirement text varies by publisher, so some models or requirements may remain unrecognised and need manual checking.

**FPS is intentionally not fabricated.** Minimum and recommended specifications do not tell us a game's exact FPS on a specific PC. This build shows whether your hardware appears below, near or above the published requirement tier. It does not claim measured FPS results. A proper FPS estimator would need reliable, game-specific benchmark data for the exact GPU, CPU, resolution and graphics settings.

## Safety and privacy

- The scanner is read-only and does not require administrator rights by design.
- It collects CPU model/core count, GPU model/driver/available VRAM field, RAM module size/speed, motherboard model, Windows version/build and drive model/capacity.
- It does not collect usernames, computer name, serial numbers, IP addresses, personal files, browsing history or installed application lists.
- Hardware data is returned to the browser through loopback and kept in browser local storage. It is not sent to this project's GitHub Pages host.
- Steam search/details requests go from your PC to Steam's public store endpoints. Internet access is required for game search.
- The companion is bound to loopback only; other devices on your Wi-Fi cannot connect to it.

Review the PowerShell file before running it if you want to inspect exactly what it does. Keep Windows Security enabled.

## Troubleshooting

- **The browser says the companion is unreachable:** run the BAT again; accept a browser prompt for local network access if one appears; check that port `8765` is not blocked by security software.
- **The token expired:** rerun `START-PC-HUB.bat`. The token is temporary and is not meant to be copied into a different browser session.
- **Game search does not work:** check your internet connection. Steam may rate-limit or temporarily fail to respond.
- **The game has no requirements:** some publishers do not provide PC requirements in their store listing. PC Hub cannot infer missing official specs.
- **A detected GPU/CPU is not recognised:** the scan can still display the exact detected model, but the catalogue matcher may not have a tier for it yet.
- **The online site has old files:** confirm GitHub Pages is publishing the `main` branch and that all the new files were uploaded to the repository root. Hard-refresh the browser with `Ctrl + F5`.

## Data source note

Game titles and system requirements are retrieved from public Steam store search and app-details responses. This is a community-facing integration with Steam's store endpoints, not an official Steamworks partnership. Hardware tier indices are approximate catalogue hints, not certified benchmark measurements.
