PC Hub connected scanner patch

Replace my-pc.html in the repository with the supplied file.
Upload PC-Hub-Scanner.bat to the repository root.
In app.js, add the code in APP-JS-PATCH.txt inside setupMyPc().

How it works:
- The BAT downloads the existing PC-Companion.ps1 from the public repository.
- It starts the companion on 127.0.0.1:8765 with a temporary token.
- It opens the My PC page with that token and scan=1.
- The page calls the existing /api/specs endpoint and renders the returned hardware.

The scanner BAT is a launcher, not a compiled EXE. It requires Windows PowerShell and internet access. The website must be published on https://naman123u.github.io for the companion's allowed-origin check to pass.
