param(
    [string]$Device = "chrome",
    [switch]$ReuseBackend
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$frontendDir = Join-Path $repoRoot "frontend"
$backendDir = Join-Path $repoRoot "backend"
$venvPython = Join-Path $repoRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    $parentRoot = Split-Path -Parent $repoRoot
    $venvPython = Join-Path $parentRoot ".venv\Scripts\python.exe"
}

if (-not (Test-Path $frontendDir)) {
    throw "Frontend folder not found at: $frontendDir"
}
if (-not (Test-Path $backendDir)) {
    throw "Backend folder not found at: $backendDir"
}
if (-not (Test-Path $venvPython)) {
    throw "Python venv not found at: $venvPython"
}

$backendStartedByScript = $false
$backendProcess = $null

function Test-BackendHealth {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8000/health" -TimeoutSec 3
        return $response -and $response.status
    } catch {
        return $null
    }
}

$existingBackend = $null
try {
    $existingBackend = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
} catch {}

if ($existingBackend -and $ReuseBackend) {
    Write-Host "Using existing backend on port 8000 (PID $($existingBackend.OwningProcess))." -ForegroundColor Yellow
} else {
    if ($existingBackend -and -not $ReuseBackend) {
        Write-Host "Stopping existing backend process on port 8000 (PID $($existingBackend.OwningProcess))." -ForegroundColor Yellow
        Stop-Process -Id $existingBackend.OwningProcess -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }

    Write-Host "Starting backend..." -ForegroundColor Cyan
    $backendProcess = Start-Process -FilePath $venvPython `
        -ArgumentList "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000" `
        -WorkingDirectory $backendDir `
        -PassThru

    $backendStartedByScript = $true

    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        if (Test-BackendHealth) {
            $ready = $true
            break
        }
    }

    if (-not $ready) {
        if ($backendProcess -and -not $backendProcess.HasExited) {
            Stop-Process -Id $backendProcess.Id -Force -ErrorAction SilentlyContinue
        }
        throw "Backend did not become healthy on http://localhost:8000/health"
    }

    Write-Host "Backend is healthy." -ForegroundColor Green
}

Write-Host "Running frontend on device '$Device'..." -ForegroundColor Cyan
try {
    Set-Location $frontendDir
    & flutter run -d $Device
} finally {
    if ($backendStartedByScript -and $backendProcess -and -not $backendProcess.HasExited) {
        Write-Host "Stopping backend (PID $($backendProcess.Id))..." -ForegroundColor Yellow
        Stop-Process -Id $backendProcess.Id -Force -ErrorAction SilentlyContinue
    }
}
