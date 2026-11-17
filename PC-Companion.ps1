param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-fA-F0-9-]{36,128}$')]
    [string]$Token
)

# PC Hub Companion: read-only, loopback-only Windows hardware bridge.
# It does not write a report file and exposes no general-purpose proxy or file endpoint.
$ErrorActionPreference = 'Stop'
$Port = 8765
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
$AllowedOrigins = @('https://naman123u.github.io')
$SteamHeaders = @{ 'User-Agent' = 'PC-Benchmark-Hub/3.0 (local PC compatibility checker)' }
$SearchCache = @{}
$DetailsCache = @{}

function Get-SafeGB([object]$Bytes) {
    if ($null -eq $Bytes) { return $null }
    try {
        $n = [double]$Bytes
        if ($n -le 0) { return $null }
        return [math]::Round($n / 1GB, 1)
    } catch { return $null }
}

function Get-PCSpecs {
    $cpu = $null; $os = $null; $board = $null
    try { $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1 } catch {}
    try { $os = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -First 1 } catch {}
    try { $board = Get-CimInstance -ClassName Win32_BaseBoard | Select-Object -First 1 } catch {}
    try { $gpusRaw = @(Get-CimInstance -ClassName Win32_VideoController) } catch { $gpusRaw = @() }
    try { $ramRaw = @(Get-CimInstance -ClassName Win32_PhysicalMemory) } catch { $ramRaw = @() }
    try { $disksRaw = @(Get-CimInstance -ClassName Win32_DiskDrive) } catch { $disksRaw = @() }

    $gpuList = @($gpusRaw | ForEach-Object {
        $vram = Get-SafeGB $_.AdapterRAM
        [ordered]@{
            name = [string]$_.Name
            vramGB = $vram
            driverVersion = [string]$_.DriverVersion
            videoMode = if ($_.CurrentHorizontalResolution -and $_.CurrentVerticalResolution) { "{0}x{1}" -f $_.CurrentHorizontalResolution, $_.CurrentVerticalResolution } else { $null }
        }
    } | Where-Object { $_.name })

    $modules = @($ramRaw | ForEach-Object {
        [ordered]@{
            capacityGB = Get-SafeGB $_.Capacity
            speedMHz = if ($_.Speed) { [int]$_.Speed } else { $null }
        }
    })
    $totalRam = 0.0
    foreach ($module in $modules) { if ($module.capacityGB) { $totalRam += [double]$module.capacityGB } }

    $storage = @($disksRaw | ForEach-Object {
        [ordered]@{
            model = [string]$_.Model
            sizeGB = Get-SafeGB $_.Size
            mediaType = $null
        }
    } | Where-Object { $_.model })

    return [ordered]@{
        ok = $true
        generatedAt = [DateTime]::UtcNow.ToString('o')
        source = 'PC Hub local Windows companion'
        cpu = [ordered]@{
            name = if ($cpu) { [string]$cpu.Name } else { $null }
            cores = if ($cpu) { [int]$cpu.NumberOfCores } else { $null }
            threads = if ($cpu) { [int]$cpu.NumberOfLogicalProcessors } else { $null }
            maxClockMHz = if ($cpu -and $cpu.MaxClockSpeed) { [int]$cpu.MaxClockSpeed } else { $null }
        }
        gpus = $gpuList
        memory = [ordered]@{
            totalGB = [math]::Round($totalRam, 1)
            modules = $modules
        }
        motherboard = [ordered]@{
            manufacturer = if ($board) { [string]$board.Manufacturer } else { $null }
            model = if ($board) { [string]$board.Product } else { $null }
        }
        os = [ordered]@{
            name = if ($os) { [string]$os.Caption } else { $null }
            version = if ($os) { [string]$os.Version } else { $null }
            build = if ($os) { [string]$os.BuildNumber } else { $null }
            architecture = if ($os) { [string]$os.OSArchitecture } else { $null }
        }
        storage = $storage
    }
}

function Get-QueryValue([string]$Query, [string]$Name) {
    foreach ($part in ($Query.TrimStart('?').Split('&'))) {
        if (-not $part) { continue }
        $kv = $part.Split('=', 2)
        if ($kv.Count -eq 2 -and [uri]::UnescapeDataString($kv[0]) -eq $Name) {
            return [uri]::UnescapeDataString($kv[1].Replace('+', '%20'))
        }
    }
    return ''
}

function Send-Response($Stream, [int]$Status, [object]$Payload, [string]$Origin, [bool]$IsOptions = $false) {
    $reason = switch ($Status) { 200 { 'OK' } 204 { 'No Content' } 400 { 'Bad Request' } 403 { 'Forbidden' } 404 { 'Not Found' } 405 { 'Method Not Allowed' } 502 { 'Bad Gateway' } default { 'Internal Server Error' } }
    $bodyText = if ($IsOptions -or $Status -eq 204) { '' } else { ConvertTo-Json -InputObject $Payload -Depth 12 -Compress }
    $bodyBytes = [Text.Encoding]::UTF8.GetBytes($bodyText)
    $headers = New-Object System.Collections.Generic.List[string]
    $headers.Add("HTTP/1.1 $Status $reason")
    $headers.Add('Content-Type: application/json; charset=utf-8')
    $headers.Add('Cache-Control: no-store')
    $headers.Add('Connection: close')
    $headers.Add("Content-Length: $($bodyBytes.Length)")
    if ($Origin -and $AllowedOrigins -contains $Origin) {
        $headers.Add("Access-Control-Allow-Origin: $Origin")
        $headers.Add('Vary: Origin')
        $headers.Add('Access-Control-Allow-Methods: GET, POST, OPTIONS')
        $headers.Add('Access-Control-Allow-Headers: X-PC-Hub-Token, Content-Type')
        $headers.Add('Access-Control-Allow-Private-Network: true')
        $headers.Add('Access-Control-Max-Age: 600')
    }
    $headerBytes = [Text.Encoding]::ASCII.GetBytes(($headers -join "`r`n") + "`r`n`r`n")
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    if ($bodyBytes.Length -gt 0) { $Stream.Write($bodyBytes, 0, $bodyBytes.Length) }
    $Stream.Flush()
}

function Get-SteamSearch([string]$Term) {
    $key = $Term.ToLowerInvariant()
    if ($SearchCache.ContainsKey($key) -and $SearchCache[$key].until -gt [DateTime]::UtcNow) { return $SearchCache[$key].data }
    $encoded = [uri]::EscapeDataString($Term)
    $url = "https://store.steampowered.com/api/storesearch/?term=$encoded&l=english&cc=IN"
    $result = Invoke-RestMethod -Uri $url -Headers $SteamHeaders -TimeoutSec 20 -Method Get
    $items = @($result.items | ForEach-Object {
        [ordered]@{
            id = [int]$_.id
            name = [string]$_.name
            tiny_image = [string]$_.tiny_image
            metascore = [string]$_.metascore
        }
    })
    $data = [ordered]@{ ok = $true; total = if ($result.total) { [int]$result.total } else { $items.Count }; items = $items }
    $SearchCache[$key] = @{ data = $data; until = [DateTime]::UtcNow.AddMinutes(2) }
    return $data
}

function Get-SteamDetails([int]$AppId) {
    $key = [string]$AppId
    if ($DetailsCache.ContainsKey($key) -and $DetailsCache[$key].until -gt [DateTime]::UtcNow) { return $DetailsCache[$key].data }
    $url = "https://store.steampowered.com/api/appdetails?appids=$AppId&cc=IN&l=english"
    $response = Invoke-RestMethod -Uri $url -Headers $SteamHeaders -TimeoutSec 20 -Method Get
    $entry = $response.PSObject.Properties[$key].Value
    if (-not $entry -or -not $entry.success -or -not $entry.data) { throw 'Steam has no public store details for this app ID.' }
    $g = $entry.data
    $data = [ordered]@{
        ok = $true
        success = $true
        data = [ordered]@{
            name = [string]$g.name
            header_image = [string]$g.header_image
            short_description = [string]$g.short_description
            pc_requirements = $g.pc_requirements
            genres = @($g.genres | ForEach-Object { [string]$_.description })
            release_date = if ($g.release_date) { [string]$g.release_date.date } else { '' }
            website = [string]$g.website
            steam_url = "https://store.steampowered.com/app/$AppId/"
        }
    }
    $DetailsCache[$key] = @{ data = $data; until = [DateTime]::UtcNow.AddHours(8) }
    return $data
}

$listener = $null
try {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
    $listener.Start()
    $pidFile = Join-Path $env:TEMP 'PCHubCompanion.pid'
    Set-Content -LiteralPath $pidFile -Value $PID -Encoding ASCII
    Write-Host "PC Hub companion running on 127.0.0.1:$Port" -ForegroundColor Green
    $shutdown = $false
    while (-not $shutdown) {
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $reader = New-Object System.IO.StreamReader($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
            $requestLine = $reader.ReadLine()
            if (-not $requestLine) { $client.Close(); continue }
            $parts = $requestLine.Split(' ')
            if ($parts.Count -lt 2) { Send-Response $stream 400 @{ error = 'Malformed request.' } '' ; $client.Close(); continue }
            $method = $parts[0].ToUpperInvariant()
            $target = $parts[1]
            $headers = @{}
            while ($true) {
                $line = $reader.ReadLine()
                if ($null -eq $line -or $line -eq '') { break }
                $separator = $line.IndexOf(':')
                if ($separator -gt 0) { $headers[$line.Substring(0, $separator).Trim().ToLowerInvariant()] = $line.Substring($separator + 1).Trim() }
            }
            $origin = [string]$headers['origin']
            $uri = [uri]('http://127.0.0.1' + $target)
            $path = $uri.AbsolutePath
            $query = $uri.Query

            if ($method -eq 'OPTIONS') {
                if ($origin -and $AllowedOrigins -notcontains $origin) { Send-Response $stream 403 @{ error = 'Origin is not allowed.' } '' }
                else { Send-Response $stream 204 @{} $origin $true }
                $client.Close(); continue
            }
            if ($origin -and $AllowedOrigins -notcontains $origin) {
                Send-Response $stream 403 @{ error = 'This website origin is not allowed to access the local companion.' } ''
                $client.Close(); continue
            }
            if ($path -eq '/api/health' -and $method -eq 'GET') {
                Send-Response $stream 200 @{ ok = $true; service = 'PC Hub local companion'; version = '3.0' } $origin
                $client.Close(); continue
            }
            $providedToken = [string]$headers['x-pc-hub-token']
            if (-not $providedToken -or -not [string]::Equals($providedToken, $Token, [StringComparison]::Ordinal)) {
                Send-Response $stream 403 @{ error = 'The temporary companion token is missing or expired. Run START-PC-HUB.bat again.' } $origin
                $client.Close(); continue
            }

            switch ($path) {
                '/api/specs' {
                    if ($method -ne 'GET') { Send-Response $stream 405 @{ error = 'Use GET for hardware scans.' } $origin }
                    else { Send-Response $stream 200 (Get-PCSpecs) $origin }
                }
                '/api/game-search' {
                    if ($method -ne 'GET') { Send-Response $stream 405 @{ error = 'Use GET for game search.' } $origin; break }
                    $term = (Get-QueryValue $query 'q').Trim()
                    if ($term.Length -lt 2 -or $term.Length -gt 80) { Send-Response $stream 400 @{ error = 'Enter a search term between 2 and 80 characters.' } $origin; break }
                    try { Send-Response $stream 200 (Get-SteamSearch $term) $origin }
                    catch { Send-Response $stream 502 @{ error = 'Steam search could not be reached. Check your internet connection and try again.' } $origin }
                }
                '/api/game-details' {
                    if ($method -ne 'GET') { Send-Response $stream 405 @{ error = 'Use GET for game details.' } $origin; break }
                    $idText = Get-QueryValue $query 'id'
                    $appId = 0
                    if (-not [int]::TryParse($idText, [ref]$appId) -or $appId -le 0) { Send-Response $stream 400 @{ error = 'A valid numeric Steam app ID is required.' } $origin; break }
                    try { Send-Response $stream 200 (Get-SteamDetails $appId) $origin }
                    catch { Send-Response $stream 502 @{ error = $_.Exception.Message } $origin }
                }
                '/api/shutdown' {
                    if ($method -ne 'POST') { Send-Response $stream 405 @{ error = 'Use POST to stop the companion.' } $origin }
                    else { Send-Response $stream 200 @{ ok = $true; message = 'PC Hub companion stopped.' } $origin; $shutdown = $true }
                }
                default { Send-Response $stream 404 @{ error = 'Endpoint not found.' } $origin }
            }
        }
        catch {
            try { if ($client.Connected) { $s = $client.GetStream(); Send-Response $s 500 @{ error = 'The local companion encountered an unexpected error.' } '' } } catch {}
        }
        finally { try { $client.Close() } catch {} }
    }
}
catch {
    Write-Host "PC Hub companion could not start on port $Port. Another instance may already be using it." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
}
finally {
    if ($listener) { try { $listener.Stop() } catch {} }
    if ($pidFile -and (Test-Path -LiteralPath $pidFile)) {
        try { if ([int](Get-Content -LiteralPath $pidFile -ErrorAction Stop) -eq $PID) { Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue } } catch {}
    }
}
