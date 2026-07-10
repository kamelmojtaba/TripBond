# TripBond Full Stack Startup Script
# Starts FastAPI Backend, Flask AI Server, and optionally Flutter Frontend
# Run with: powershell -ExecutionPolicy Bypass -File start-full-stack.ps1
#
# Reads GOOGLE_MAPS_API_KEY from backend/.env and forwards it to Flutter as
# --dart-define=GOOGLE_API_KEY=... so you don't need to type it manually.

param(
    [switch]$NoFrontend,
    [switch]$NoAI,
    [int]$Port = 8000
)

# ---------------------------------------------------------------------------
# Output helpers (ASCII only - PowerShell on Windows often misreads UTF8/BOM
# scripts when they contain box-drawing or emoji glyphs, which then breaks the
# parser on later lines. Keep this file ASCII to avoid that.)
# ---------------------------------------------------------------------------
function Write-Ok      { param([string]$msg) Write-Host $msg -ForegroundColor Green }
function Write-InfoMsg { param([string]$msg) Write-Host $msg -ForegroundColor Cyan }
function Write-WarnMsg { param([string]$msg) Write-Host $msg -ForegroundColor Yellow }
function Write-ErrMsg  { param([string]$msg) Write-Host $msg -ForegroundColor Red }

function Read-DotEnvValue {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Key
    )
    if (-not (Test-Path $Path)) { return $null }
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        $eq = $trimmed.IndexOf('=')
        if ($eq -lt 1) { continue }
        $name = $trimmed.Substring(0, $eq).Trim()
        if ($name -ne $Key) { continue }
        $value = $trimmed.Substring($eq + 1).Trim()
        # Strip surrounding single or double quotes if present
        if ($value.Length -ge 2) {
            $first = $value.Substring(0, 1)
            $last  = $value.Substring($value.Length - 1, 1)
            if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
                $value = $value.Substring(1, $value.Length - 2)
            }
        }
        return $value
    }
    return $null
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
$RootDir     = (Get-Item $PSScriptRoot).FullName
$BackendDir  = Join-Path $RootDir "backend"
$FrontendDir = Join-Path $RootDir "frontend"
$AIDir       = Join-Path $RootDir "tripbond_ai_backend"
$EnvFile     = Join-Path $BackendDir ".env"

Write-Host "==========================================================" -ForegroundColor Magenta
Write-Host "          TripBond Full Stack Startup Script              " -ForegroundColor Magenta
Write-Host "==========================================================" -ForegroundColor Magenta
Write-InfoMsg "Starting TripBond services..."
Write-InfoMsg ("Root: " + $RootDir)

# Check Python availability
try {
    $PythonVersion = python --version 2>&1
    Write-Ok ("Python found: " + $PythonVersion)
} catch {
    Write-ErrMsg "Python not found in PATH"
    Write-WarnMsg "Please install Python 3.9+ or add to PATH"
    exit 1
}

# Check venv
$VEnvPath = Join-Path $RootDir ".venv"
if (-not (Test-Path $VEnvPath)) {
    Write-WarnMsg ("Virtual environment not found at " + $VEnvPath)
    Write-InfoMsg "Creating virtual environment..."
    python -m venv ".venv"
    Write-Ok "Virtual environment created"
}

# Activate venv
Write-InfoMsg "Activating virtual environment..."
$ActivateScript = Join-Path $VEnvPath "Scripts\Activate.ps1"
& $ActivateScript

# Load Google Maps API key from backend/.env (used by Flutter --dart-define)
$GoogleKey = Read-DotEnvValue -Path $EnvFile -Key 'GOOGLE_MAPS_API_KEY'
if ([string]::IsNullOrWhiteSpace($GoogleKey)) {
    Write-WarnMsg "GOOGLE_MAPS_API_KEY not found in backend/.env - frontend will run without a Google API key."
} else {
    Write-Ok "Loaded GOOGLE_MAPS_API_KEY from backend/.env"
}

# ---------------------------------------------------------------------------
# Start FastAPI Backend
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "----------------- FastAPI Backend ------------------------" -ForegroundColor Yellow
Write-InfoMsg ("Starting FastAPI backend on port " + $Port + "...")
Write-InfoMsg "Command: python backend/run.py"

$BackendScript = @"
cd '$RootDir'
& '$ActivateScript'
Write-Host ''
Write-Host '================================' -ForegroundColor Green
Write-Host 'FastAPI Backend Starting...'      -ForegroundColor Green
Write-Host '================================' -ForegroundColor Green
Write-Host ''
python backend/run.py
"@

$BackendFile = Join-Path $RootDir "start_backend_temp.ps1"
$BackendScript | Out-File -FilePath $BackendFile -Encoding ASCII
# NOTE: pass -File as a single pre-quoted string. PowerShell's Start-Process
# -ArgumentList does NOT reliably quote items containing spaces, which silently
# truncates the path (e.g. "D:\7elha Work\..." becomes "-File D:\7elha") and
# the spawned window dies before -NoExit takes effect.
$BackendArgs = '-NoExit -ExecutionPolicy Bypass -File "' + $BackendFile + '"'
Start-Process -FilePath 'powershell.exe' -ArgumentList $BackendArgs
Write-Ok ("FastAPI backend window opened (http://localhost:" + $Port + ")")
Write-Ok ("  Swagger Docs: http://localhost:" + $Port + "/docs")
Start-Sleep -Seconds 3

# ---------------------------------------------------------------------------
# Start Flask AI Server (Optional)
# ---------------------------------------------------------------------------
if (-not $NoAI) {
    Write-Host ""
    Write-Host "----------------- Flask AI Server ------------------------" -ForegroundColor Cyan
    Write-InfoMsg "Starting Flask AI backend on port 5000..."
    Write-InfoMsg "Command: python tripbond_ai_backend/run_ai.py"

    $AIScript = @"
cd '$RootDir'
& '$ActivateScript'
Write-Host ''
Write-Host '================================' -ForegroundColor Cyan
Write-Host 'Flask AI Server Starting...'     -ForegroundColor Cyan
Write-Host '================================' -ForegroundColor Cyan
Write-Host ''
python tripbond_ai_backend/run_ai.py
"@

    $AIFile = Join-Path $RootDir "start_ai_temp.ps1"
    $AIScript | Out-File -FilePath $AIFile -Encoding ASCII
    $AIArgs = '-NoExit -ExecutionPolicy Bypass -File "' + $AIFile + '"'
    Start-Process -FilePath 'powershell.exe' -ArgumentList $AIArgs
    Write-Ok "Flask AI server window opened (http://localhost:5000)"
    Write-Ok "  Health check: http://localhost:5000/health"
    Start-Sleep -Seconds 2
} else {
    Write-WarnMsg "AI Backend disabled (-NoAI)"
}

# ---------------------------------------------------------------------------
# Start Flutter Frontend (Optional)
# ---------------------------------------------------------------------------
if (-not $NoFrontend) {
    Write-Host ""
    Write-Host "----------------- Flutter Frontend -----------------------" -ForegroundColor Magenta
    Write-InfoMsg "Starting Flutter frontend on Chrome..."

    if ([string]::IsNullOrWhiteSpace($GoogleKey)) {
        $FlutterCmd = "flutter run -d chrome"
    } else {
        # Use single quotes around the value so PowerShell does NOT expand $ signs
        # in the API key, and pass it through to flutter.
        $FlutterCmd = "flutter run -d chrome --dart-define=GOOGLE_API_KEY='" + $GoogleKey + "'"
    }
    Write-InfoMsg ("Command: " + $FlutterCmd)

    $FrontendScript = @"
cd '$FrontendDir'
Write-Host ''
Write-Host '================================' -ForegroundColor Magenta
Write-Host 'Flutter Frontend Starting...'    -ForegroundColor Magenta
Write-Host '================================' -ForegroundColor Magenta
Write-Host ''
$FlutterCmd
"@

    $FrontendFile = Join-Path $RootDir "start_frontend_temp.ps1"
    $FrontendScript | Out-File -FilePath $FrontendFile -Encoding ASCII
    $FrontendArgs = '-NoExit -ExecutionPolicy Bypass -File "' + $FrontendFile + '"'
    Start-Process -FilePath 'powershell.exe' -ArgumentList $FrontendArgs
    Write-Ok "Flutter frontend window opened"
    Write-InfoMsg "  Frontend will open in Chrome"
} else {
    Write-WarnMsg "Frontend disabled (-NoFrontend)"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "          All services started successfully!              " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

Write-Host ""
Write-Host "Service URLs:" -ForegroundColor Cyan
Write-Host ("  FastAPI Backend:  http://localhost:" + $Port) -ForegroundColor White
Write-Host ("  Swagger Docs:     http://localhost:" + $Port + "/docs") -ForegroundColor White

if (-not $NoAI) {
    Write-Host "  Flask AI Server:  http://localhost:5000" -ForegroundColor White
    Write-Host "  AI Health Check:  http://localhost:5000/health" -ForegroundColor White
}

Write-Host ""
Write-Host "Quick Tests:" -ForegroundColor Cyan
Write-Host ("  Backend Health:   curl http://localhost:" + $Port + "/") -ForegroundColor Gray
Write-Host ("  AI Status:        curl http://localhost:" + $Port + "/api/ai/status") -ForegroundColor Gray
Write-Host ("  API Docs:         Open http://localhost:" + $Port + "/docs") -ForegroundColor Gray
Write-Host ""
Write-Host "Commands:" -ForegroundColor Cyan
Write-Host "  Full stack:       powershell -ExecutionPolicy Bypass -File start-full-stack.ps1" -ForegroundColor Gray
Write-Host "  Backend only:     python backend/run.py" -ForegroundColor Gray
Write-Host "  Frontend only:    cd frontend; flutter run -d chrome" -ForegroundColor Gray
Write-Host ""
Write-Host "Note: Each service runs in its own window. Close windows to stop services." -ForegroundColor Yellow
Write-Host ""
