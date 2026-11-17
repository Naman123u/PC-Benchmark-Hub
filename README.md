# PC Benchmark Hub

A static website for importing a Windows PC hardware report, viewing detected specifications, estimating gaming FPS ranges, and comparing a short list of GPUs.

## Files
- `index.html` — page structure
- `style.css` — responsive dark gaming UI
- `app.js` — report import, spec display, FPS estimate and GPU comparison
- `Collect-PC-Specs.ps1` — read-only Windows hardware collector
- `PC-Spec-Scanner.bat` — launcher for the PowerShell collector

## Publish on GitHub Pages
Keep all files in the repository root. In **Settings → Pages**, publish the `main` branch from `/(root)`.

## Windows scanner
Download `PC-Spec-Scanner.bat` and double-click it. It is self-contained; `Collect-PC-Specs.ps1` is included as the readable source version. It creates `PC-Benchmark-Hub-PC-Specs.json` on the Desktop and opens the website. On the website, use **Import specs JSON** to select the report.

The scanner reads basic CPU, GPU, memory, motherboard, storage and OS details. It does not collect usernames, computer names, serial numbers, IP addresses, file contents or installed application lists. No administrator access is requested. The report stays on the PC until the user selects it in the browser. The website's JavaScript parses the report locally; it does not post it to a server.

## Important accuracy note
The FPS estimator and GPU reference values are simplified estimates for exploration only. They are not results from a real-time benchmark database and should not be used as guaranteed FPS or as the sole basis for a hardware purchase.
