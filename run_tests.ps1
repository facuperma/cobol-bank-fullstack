# Pruebas automatizadas (Windows). Compila, recarga los datos de prueba
# antes de cada caso y verifica la salida de los programas.
#   .\run_tests.ps1 [-NoBuild] [-GnuCobol C:\GnuCOBOL]
param([switch]$NoBuild, [string]$GnuCobol = $env:GNUCOBOL_HOME)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not $NoBuild) { & .\build.ps1 -GnuCobol $GnuCobol }
$ErrorActionPreference = 'Continue'

$script:fallas = 0
$script:total = 0

function Reset-Datos {
    Remove-Item data\*, reports\* -Force -ErrorAction SilentlyContinue
    & .\bin\batch.exe CARGA CONFIRMAR | Out-Null
}

# Ejecuta el programa interactivo con las lineas indicadas como entrada.
function Invoke-Banco([string[]]$lineas) {
    ($lineas | & .\bin\banco.exe) -join "`n"
}

function Invoke-Batch([string[]]$argumentos) {
    $salida = (& .\bin\batch.exe @argumentos) -join "`n"
    [pscustomobject]@{ Salida = $salida; Rc = $LASTEXITCODE }
}

function Test-Caso([string]$caso, [string]$descripcion, [scriptblock]$cuerpo) {
    $script:total++
    Reset-Datos
    $errores = & $cuerpo
    if ($errores) {
        $script:fallas++
        Write-Host "FALLA $caso - $descripcion" -ForegroundColor Red
        $errores | ForEach-Object { Write-Host "      $_" }
    } else {
        Write-Host "OK    $caso - $descripcion" -ForegroundColor Green
    }
}

# Devuelve un mensaje de error si el patron (regex) no aparece.
function Esperar([string]$texto, [string]$patron) {
    if ($texto -notmatch $patron) { "no aparece: $patron" }
}

$cajero = 'CAJERO01', '1234'
$supervisor = 'SUPER01', '9999'

Test-Caso 'T01' 'Retiro mayor al saldo' {
    $s = Invoke-Banco ($cajero + '4', '1000000004', '2222', '100', '9')
    Esperar $s 'ERROR: Saldo insuficiente'
}

Test-Caso 'T02' 'Cuarto retiro supera el limite diario' {
    $retiro = { param($imp) '4', '1000000005', '3333', $imp }
    $s = Invoke-Banco ($cajero + (& $retiro '200') + (& $retiro '200') +
                       (& $retiro '100') + (& $retiro '50') + '9')
    if (([regex]::Matches($s, 'OK: Retiro realizado')).Count -ne 3) {
        'se esperaban 3 retiros aceptados'
    }
    Esperar $s 'ERROR: Limite diario superado'
}

Test-Caso 'T03' '3 PIN incorrectos bloquean la cuenta' {
    $mal = '4', '1000000001', '0000', '10'
    $s = Invoke-Banco ($cajero + $mal + $mal + $mal +
                       '4', '1000000001', '1234', '10', '9')
    Esperar $s 'intento 1 de 3'
    Esperar $s 'intento 2 de 3'
    Esperar $s 'PIN incorrecto\. Cuenta bloqueada'
    Esperar $s 'ERROR: Cuenta bloqueada'
}

Test-Caso 'T04' 'Transferencia a cuenta inexistente no toca el origen' {
    $s = Invoke-Banco ($cajero + '5', '1000000001', '1234', '1999999999', '100',
                       '6', '1000000001', '1234', '9')
    Esperar $s 'ERROR: Cuenta destino inexistente'
    Esperar $s 'Saldo   :\s+1,500\.00'
}

Test-Caso 'T05' 'Cierre dos veces: mismo resultado, sin movimientos nuevos' {
    $antes = (Get-Item data\MOVIMIENTOS.DAT).Length
    $r1 = Invoke-Batch 'CIERRE'
    $informe = Get-ChildItem reports\CIERRE_*.txt | Select-Object -First 1
    $primero = Get-Content $informe.FullName -Raw
    $r2 = Invoke-Batch 'CIERRE'
    $segundo = Get-Content $informe.FullName -Raw
    if ($r1.Rc -ne 0 -or $r2.Rc -ne 0) { 'codigo de retorno distinto de 0' }
    if ($primero -ne $segundo) { 'los informes difieren' }
    if ((Get-Item data\MOVIMIENTOS.DAT).Length -ne $antes) { 'cambio MOVIMIENTOS.DAT' }
    Esperar $primero 'Depositos\s+6\s+'
}

Test-Caso 'T06' 'Reconciliacion detecta saldo alterado a mano' {
    $r = Invoke-Batch 'RECONCIL'
    if ($r.Rc -ne 0) { 'los datos de prueba deberian conciliar' }
    & .\bin\tstalter.exe 1000000001 | Out-Null
    $r = Invoke-Batch 'RECONCIL'
    if ($r.Rc -ne 1) { "codigo de retorno $($r.Rc), se esperaba 1" }
    Esperar (Get-Content reports\DISCREPANCIAS.txt -Raw) '1000000001'
}

Test-Caso 'T07' 'Transferencia correcta y saldos conciliados' {
    $s = Invoke-Banco ($cajero + '5', '1000000002', '1234', '1000000003', '500',
                       '6', '1000000003', '2222', '9')
    Esperar $s 'OK: Transferencia realizada'
    Esperar $s 'Saldo   :\s+1,300\.00'
    $r = Invoke-Batch 'RECONCIL'
    if ($r.Rc -ne 0) { 'la reconciliacion encontro diferencias' }
}

Test-Caso 'T08' 'Intereses: se pagan una sola vez por periodo' {
    $r1 = Invoke-Batch 'INTERES'
    $r2 = Invoke-Batch 'INTERES'
    Esperar $r1.Salida 'Cuentas procesadas :\s+3'
    Esperar $r1.Salida 'Intereses pagados  :\s+36\.50'
    Esperar $r2.Salida 'Cuentas procesadas :\s+0'
    Esperar $r2.Salida 'Ya pagadas antes   :\s+3'
    $r = Invoke-Batch 'RECONCIL'
    if ($r.Rc -ne 0) { 'la reconciliacion encontro diferencias' }
}

Test-Caso 'T09' 'Alta con documento duplicado' {
    $s = Invoke-Banco ($cajero + '1', '1', '30111222', '9', '9')
    Esperar $s 'ERROR: Documento ya registrado'
}

Test-Caso 'T10' 'Tres claves incorrectas niegan el acceso' {
    $s = Invoke-Banco ('CAJERO01', 'x', 'CAJERO01', 'y', 'CAJERO01', 'z')
    Esperar $s 'ERROR: Acceso denegado'
}

Test-Caso 'T11' 'Un cajero no accede a los procesos de supervisor' {
    $s = Invoke-Banco ($cajero + '8', '9')
    Esperar $s 'ERROR: Opcion reservada a supervisores'
}

Test-Caso 'T12' 'Alta de cliente, apertura con deposito y extracto' {
    $hoy = Get-Date -Format 'yyyyMMdd'
    $s = Invoke-Banco ($cajero +
        '1', '1', '33444555', 'Ana', 'Martinez', '19950101', 'Calle 1', '11-4444-0000', '9',
        '2', '6', 'A', '1111', '1111', '1000',
        '7', '1000000009', $hoy, $hoy, '9')
    Esperar $s 'OK: Cliente 000006 dado de alta'
    Esperar $s 'OK: Cuenta 1000000009 abierta'
    Esperar $s 'Saldo final\s+:\s+1,000\.00'
    $r = Invoke-Batch 'RECONCIL'
    if ($r.Rc -ne 0) { 'la reconciliacion encontro diferencias' }
}

Test-Caso 'T13' 'Supervisor desbloquea una cuenta' {
    $s = Invoke-Banco ($supervisor + '8', '1', '1000000006', '9',
                       '6', '1000000006', '3333', '9')
    Esperar $s 'OK: Cuenta 1000000006 desbloqueada'
    Esperar $s 'Saldo   :\s+250\.00'
}

Test-Caso 'T14' 'Baja rechazada si el cliente tiene saldo' {
    $s = Invoke-Banco ($cajero + '1', '3', '000001', '3', '000004', '9', '9')
    Esperar $s 'ERROR: El cliente tiene saldo'
    Esperar $s 'OK: Cliente 000004 dado de baja'
}

Test-Caso 'T15' 'Exportacion de ancho fijo con cola de control' {
    $r = Invoke-Batch 'EXPORTA'
    $lineas = Get-Content (Get-ChildItem reports\EXPORT_*.txt | Select-Object -First 1).FullName
    if ($lineas[0] -notmatch '^HBANCOCOB') { 'falta la cabecera' }
    if (($lineas | Where-Object { $_ -match '^D' }).Count -ne 6) { 'se esperaban 6 detalles' }
    if ($lineas[-1] -notmatch '^T000000006') { 'la cola no informa 6 registros' }
}

Write-Host ''
Write-Host "Resultado: $($script:total - $script:fallas) de $($script:total) casos OK"
if ($script:fallas -gt 0) { exit 1 }
