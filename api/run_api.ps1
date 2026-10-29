# Levanta la API (Windows). Crea el entorno virtual la primera vez.
#   .\api\run_api.ps1 [-Puerto 8000] [-GnuCobol C:\GnuCOBOL] [-SoloLocal]
# Por defecto escucha en todas las interfaces para que el celular la alcance
# por la red local; -SoloLocal la limita a esta PC.
param([int]$Puerto = 8000, [string]$GnuCobol = $env:GNUCOBOL_HOME, [switch]$SoloLocal)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not $GnuCobol -and (Test-Path C:\GnuCOBOL)) { $GnuCobol = 'C:\GnuCOBOL' }
if ($GnuCobol) { $env:GNUCOBOL_HOME = $GnuCobol }

if (-not (Test-Path ..\bin\servicio.exe)) {
    throw 'Falta bin\servicio.exe. Compile primero con .\build.ps1'
}

if (-not (Test-Path .venv)) {
    Write-Host 'Creando entorno virtual...'
    $python = (Get-Command python -ErrorAction SilentlyContinue).Source
    $local = "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
    if (-not $python -or $python -like '*WindowsApps*') { $python = $local }
    & $python -m venv .venv
    & .venv\Scripts\python.exe -m pip install --disable-pip-version-check -r requirements.txt
}

$hostIp = if ($SoloLocal) { '127.0.0.1' } else { '0.0.0.0' }
Write-Host "API en http://localhost:$Puerto  (documentacion: /docs)"
& .venv\Scripts\python.exe -m uvicorn app.main:app --host $hostIp --port $Puerto
