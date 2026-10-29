# Compila el sistema con GnuCOBOL en Windows.
#   .\build.ps1                      (cobc en el PATH o GNUCOBOL_HOME definido)
#   .\build.ps1 -GnuCobol C:\GnuCOBOL
param([string]$GnuCobol = $env:GNUCOBOL_HOME)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Get-Command cobc -ErrorAction SilentlyContinue)) {
    if (-not $GnuCobol) {
        throw 'No se encontro cobc. Instale GnuCOBOL o indique su carpeta con -GnuCobol.'
    }
    # Mismo entorno que arma set_env.cmd de la distribucion de GnuCOBOL.
    $env:COB_MAIN_DIR     = "$GnuCobol\"
    $env:COB_CONFIG_DIR   = "$GnuCobol\config"
    $env:COB_COPY_DIR     = "$GnuCobol\copy"
    $env:COB_CFLAGS       = "-I`"$GnuCobol\include`""
    $env:COB_LDFLAGS      = "-L`"$GnuCobol\lib`""
    $env:COB_LIBRARY_PATH = "$GnuCobol\extras"
    $env:PATH             = "$GnuCobol\bin;$env:PATH"
}

New-Item -ItemType Directory -Force bin, data, reports | Out-Null

$comunes = 'src/AUDITORIA.cbl', 'src/NUMERADOR.cbl', 'src/HASHCLAVE.cbl',
           'src/GRABAMOV.cbl', 'src/UTILES.cbl'
$batch   = 'src/INTERES.cbl', 'src/CIERRE.cbl', 'src/RECONCIL.cbl',
           'src/RANKING.cbl', 'src/EXPORTA.cbl'
$opciones = '-x', '-fstatic-call', '-Wall', '-I', 'copy'

function Compilar([string]$salida, [string[]]$fuentes) {
    Write-Host "Compilando $salida..."
    & cobc @opciones -o $salida @fuentes
    if ($LASTEXITCODE -ne 0) { throw "Fallo la compilacion de $salida" }
}

Compilar 'bin/banco.exe' (@('src/BANCO.cbl', 'src/CLIENTES.cbl', 'src/CUENTAS.cbl',
                            'src/TRANSAC.cbl', 'src/EXTRACTO.cbl') + $batch + $comunes)
Compilar 'bin/servicio.exe' (@('src/SERVICIO.cbl', 'src/CLIENTES.cbl', 'src/CUENTAS.cbl',
                               'src/TRANSAC.cbl', 'src/EXTRACTO.cbl') + $batch + $comunes)
Compilar 'bin/batch.exe' (@('src/BATCH.cbl', 'src/CARGA.cbl') + $batch + $comunes)
Compilar 'bin/tstalter.exe' @('tests/TSTALTER.cbl')

Write-Host 'OK: ejecutables en bin\'
