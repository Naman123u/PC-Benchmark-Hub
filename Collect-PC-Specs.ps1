# PC Benchmark Hub - read-only Windows hardware scanner
# Collects hardware basics only. It does NOT collect usernames, computer names,
# serial numbers, IP addresses, file contents, or installed application lists.

$ErrorActionPreference = 'SilentlyContinue'

function Get-SafeGB($Bytes) {
    if ($null -eq $Bytes -or [double]$Bytes -le 0) { return $null }
    return [math]::Round(([double]$Bytes / 1GB), 1)
}

try {
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $os = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -First 1
    $board = Get-CimInstance -ClassName Win32_BaseBoard | Select-Object -First 1
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -First 1
    $gpus = @(Get-CimInstance -ClassName Win32_VideoController)
    $ramModules = @(Get-CimInstance -ClassName Win32_PhysicalMemory)
    $drives = @(Get-CimInstance -ClassName Win32_DiskDrive)

    $gpuReport = @($gpus | ForEach-Object {
        $vram = Get-SafeGB $_.AdapterRAM
        $resolution = $null
        if ($_.CurrentHorizontalResolution -and $_.CurrentVerticalResolution) {
            $resolution = "$($_.CurrentHorizontalResolution) x $($_.CurrentVerticalResolution)"
        }
        [ordered]@{
            name = $_.Name
            driverVersion = $_.DriverVersion
            vramGB = $vram
            currentResolution = $resolution
        }
    })

    $moduleReport = @($ramModules | ForEach-Object {
        [ordered]@{
            capacityGB = Get-SafeGB $_.Capacity
            speedMHz = if ($_.Speed) { [int]$_.Speed } else { $null }
        }
    })

    $storageReport = @($drives | ForEach-Object {
        [ordered]@{
            model = $_.Model
            sizeGB = Get-SafeGB $_.Size
            interfaceType = $_.InterfaceType
        }
    })

    $totalRamGB = $null
    if ($cs -and $cs.TotalPhysicalMemory) { $totalRamGB = Get-SafeGB $cs.TotalPhysicalMemory }

    $report = [ordered]@{
        schemaVersion = 1
        source = 'PC Benchmark Hub Scanner'
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        os = [ordered]@{
            name = $os.Caption
            version = $os.Version
            build = $os.BuildNumber
            architecture = $os.OSArchitecture
        }
        cpu = [ordered]@{
            name = $cpu.Name
            cores = $cpu.NumberOfCores
            logicalProcessors = $cpu.NumberOfLogicalProcessors
            maxClockMHz = $cpu.MaxClockSpeed
        }
        gpus = $gpuReport
        memory = [ordered]@{
            totalGB = $totalRamGB
            modules = $moduleReport
        }
        motherboard = [ordered]@{
            manufacturer = $board.Manufacturer
            model = $board.Product
        }
        storage = $storageReport
    }

    $json = $report | ConvertTo-Json -Depth 6
    $desktop = [Environment]::GetFolderPath('Desktop')
    if (-not $desktop) { $desktop = $env:USERPROFILE }
    $outputPath = Join-Path $desktop 'PC-Benchmark-Hub-PC-Specs.json'
    $json | Set-Content -LiteralPath $outputPath -Encoding UTF8

    Write-Host ''
    Write-Host 'PC Benchmark Hub scan complete.' -ForegroundColor Green
    Write-Host "Report saved to: $outputPath" -ForegroundColor Cyan
    Write-Host 'Review the report before importing it into the website.' -ForegroundColor Yellow
    Start-Process 'https://naman123u.github.io/PC-Benchmark-Hub/'
    Write-Host ''
    Write-Host 'The website will NOT receive the report automatically.' -ForegroundColor Yellow
    Write-Host 'On the website, click Import specs JSON and select the report on your Desktop.'
} catch {
    Write-Host "Scanner failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
