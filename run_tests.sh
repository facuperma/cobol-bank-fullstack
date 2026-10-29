#!/usr/bin/env bash
# Pruebas automatizadas (Linux / macOS / WSL). Mismos casos que run_tests.ps1.
#   ./run_tests.sh [--no-build]
set -uo pipefail
cd "$(dirname "$0")"
[ "${1:-}" = "--no-build" ] || ./build.sh || exit 1

TOTAL=0
FALLAS=0
ERRORES=""

reset_datos() {
    rm -f data/* reports/*
    ./bin/batch CARGA CONFIRMAR > /dev/null
}
banco() { printf '%s\n' "$@" | ./bin/banco; }
servicio() { printf '%s\n' "$@" | ./bin/servicio; }
esperar() {  # esperar <texto> <regex extendida>
    echo "$1" | grep -Eq -- "$2" || ERRORES="$ERRORES\n      no aparece: $2"
}
fallar() { ERRORES="$ERRORES\n      $1"; }
caso() {     # caso <id> <descripcion> <funcion>
    TOTAL=$((TOTAL + 1))
    ERRORES=""
    reset_datos
    "$3"
    if [ -n "$ERRORES" ]; then
        FALLAS=$((FALLAS + 1))
        echo -e "FALLA $1 - $2$ERRORES"
    else
        echo "OK    $1 - $2"
    fi
}

CAJERO=(CAJERO01 1234)
SUPER=(SUPER01 9999)

t01() { esperar "$(banco "${CAJERO[@]}" 4 1000000004 2222 100 9)" 'ERROR: Saldo insuficiente'; }

t02() {
    local s
    s=$(banco "${CAJERO[@]}" 4 1000000005 3333 200 4 1000000005 3333 200 \
              4 1000000005 3333 100 4 1000000005 3333 50 9)
    [ "$(echo "$s" | grep -c 'OK: Retiro realizado')" -eq 3 ] || fallar 'se esperaban 3 retiros aceptados'
    esperar "$s" 'ERROR: Limite diario superado'
}

t03() {
    local s
    s=$(banco "${CAJERO[@]}" 4 1000000001 0000 10 4 1000000001 0000 10 \
              4 1000000001 0000 10 4 1000000001 1234 10 9)
    esperar "$s" 'intento 1 de 3'
    esperar "$s" 'intento 2 de 3'
    esperar "$s" 'PIN incorrecto\. Cuenta bloqueada'
    esperar "$s" 'ERROR: Cuenta bloqueada'
}

t04() {
    local s
    s=$(banco "${CAJERO[@]}" 5 1000000001 1234 1999999999 100 6 1000000001 1234 9)
    esperar "$s" 'ERROR: Cuenta destino inexistente'
    esperar "$s" 'Saldo   : +1,500\.00'
}

t05() {
    local antes primero segundo
    antes=$(wc -c < data/MOVIMIENTOS.DAT)
    ./bin/batch CIERRE > /dev/null || fallar 'codigo de retorno distinto de 0'
    primero=$(cat reports/CIERRE_*.txt)
    ./bin/batch CIERRE > /dev/null || fallar 'codigo de retorno distinto de 0'
    segundo=$(cat reports/CIERRE_*.txt)
    [ "$primero" = "$segundo" ] || fallar 'los informes difieren'
    [ "$(wc -c < data/MOVIMIENTOS.DAT)" -eq "$antes" ] || fallar 'cambio MOVIMIENTOS.DAT'
    esperar "$primero" 'Depositos +6 '
}

t06() {
    ./bin/batch RECONCIL > /dev/null || fallar 'los datos de prueba deberian conciliar'
    ./bin/tstalter 1000000001 > /dev/null
    ./bin/batch RECONCIL > /dev/null
    [ $? -eq 1 ] || fallar 'se esperaba codigo de retorno 1'
    esperar "$(cat reports/DISCREPANCIAS.txt)" '1000000001'
}

t07() {
    local s
    s=$(banco "${CAJERO[@]}" 5 1000000002 1234 1000000003 500 6 1000000003 2222 9)
    esperar "$s" 'OK: Transferencia realizada'
    esperar "$s" 'Saldo   : +1,300\.00'
    ./bin/batch RECONCIL > /dev/null || fallar 'la reconciliacion encontro diferencias'
}

t08() {
    local r1 r2
    r1=$(./bin/batch INTERES)
    r2=$(./bin/batch INTERES)
    esperar "$r1" 'Cuentas procesadas : +3'
    esperar "$r1" 'Intereses pagados  : +36\.50'
    esperar "$r2" 'Cuentas procesadas : +0'
    esperar "$r2" 'Ya pagadas antes   : +3'
    ./bin/batch RECONCIL > /dev/null || fallar 'la reconciliacion encontro diferencias'
}

t09() { esperar "$(banco "${CAJERO[@]}" 1 1 30111222 9 9)" 'ERROR: Documento ya registrado'; }

t10() { esperar "$(banco CAJERO01 x CAJERO01 y CAJERO01 z)" 'ERROR: Acceso denegado'; }

t11() { esperar "$(banco "${CAJERO[@]}" 8 9)" 'ERROR: Opcion reservada a supervisores'; }

t12() {
    local hoy s
    hoy=$(date +%Y%m%d)
    s=$(banco "${CAJERO[@]}" 1 1 33444555 Ana Martinez 19950101 'Calle 1' 11-4444-0000 9 \
              2 6 A 1111 1111 1000 7 1000000009 "$hoy" "$hoy" 9)
    esperar "$s" 'OK: Cliente 000006 dado de alta'
    esperar "$s" 'OK: Cuenta 1000000009 abierta'
    esperar "$s" 'Saldo final +: +1,000\.00'
    ./bin/batch RECONCIL > /dev/null || fallar 'la reconciliacion encontro diferencias'
}

t13() {
    local s
    s=$(banco "${SUPER[@]}" 8 1 1000000006 9 6 1000000006 3333 9)
    esperar "$s" 'OK: Cuenta 1000000006 desbloqueada'
    esperar "$s" 'Saldo   : +250\.00'
}

t14() {
    local s
    s=$(banco "${CAJERO[@]}" 1 3 000001 3 000004 9 9)
    esperar "$s" 'ERROR: El cliente tiene saldo'
    esperar "$s" 'OK: Cliente 000004 dado de baja'
}

t15() {
    local f
    ./bin/batch EXPORTA > /dev/null
    f=$(ls reports/EXPORT_*.txt | head -n 1)
    head -n 1 "$f" | grep -q '^HBANCOCOB' || fallar 'falta la cabecera'
    [ "$(grep -c '^D' "$f")" -eq 6 ] || fallar 'se esperaban 6 detalles'
    tail -n 1 "$f" | grep -q '^T000000006' || fallar 'la cola no informa 6 registros'
}

t16() {
    esperar "$(servicio LOGIN super01 9999)" '@USUARIO\|SUPER01\|S\|'
    esperar "$(servicio LOGIN CAJERO01 mal)" 'ERROR: Usuario o clave incorrectos'
}

t17() {
    local s
    s=$(servicio CLIENTES CAJERO01 1 33444555 Ana Martinez 19950101 'Calle 1' 11-4444-0000)
    esperar "$s" '@ID\|000006'
    esperar "$(servicio APERTURA CAJERO01 000006 C 1111 1111 250.50)" '@CUENTA\|1000000009'
    s=$(servicio CLIENTES CAJERO01 4 000006)
    esperar "$s" '@CLIENTE\|000006\|33444555\|ANA\|MARTINEZ\|19950101\|'
    esperar "$s" '@CUENTA\|1000000009\|C\|250\.50\|A'
}

t18() {
    local s
    esperar "$(servicio RETIRO CAJERO01 1000000005 3333 200)" '@SALDO\|11800\.00'
    esperar "$(servicio RETIRO CAJERO01 1000000005 3333 400)" 'ERROR: Limite diario superado'
    esperar "$(servicio TRANSFERENCIA CAJERO01 1000000002 1234 1000000003 500)" '@SALDO\|2500\.00'
    s=$(servicio EXTRACTO CAJERO01 1000000003 20000101 29991231)
    esperar "$s" '@MOV\|[0-9]{8}\|[0-9]{6}\|TC\|500\.00\|1300\.00\|'
    esperar "$s" '@TOTALES\|1000000003\|GOMEZ, MARIA\|000002\|0\.00\|1300\.00\|0\.00\|1300\.00'
    ./bin/batch RECONCIL > /dev/null || fallar 'la reconciliacion encontro diferencias'
}

t19() {
    esperar "$(servicio DESBLOQUEO CAJERO01 1000000006)" 'ERROR: Operacion reservada a supervisores'
    esperar "$(servicio RECONCIL CAJERO01 '' '')" 'ERROR: Operacion reservada a supervisores'
    esperar "$(servicio DEPOSITO NADIE 1000000001 10)" 'ERROR: Usuario inexistente'
    esperar "$(servicio RECONCIL SUPER01 '' '')" '@RC\|0'
}

caso T01 'Retiro mayor al saldo' t01
caso T02 'Cuarto retiro supera el limite diario' t02
caso T03 '3 PIN incorrectos bloquean la cuenta' t03
caso T04 'Transferencia a cuenta inexistente no toca el origen' t04
caso T05 'Cierre dos veces: mismo resultado, sin movimientos nuevos' t05
caso T06 'Reconciliacion detecta saldo alterado a mano' t06
caso T07 'Transferencia correcta y saldos conciliados' t07
caso T08 'Intereses: se pagan una sola vez por periodo' t08
caso T09 'Alta con documento duplicado' t09
caso T10 'Tres claves incorrectas niegan el acceso' t10
caso T11 'Un cajero no accede a los procesos de supervisor' t11
caso T12 'Alta de cliente, apertura con deposito y extracto' t12
caso T13 'Supervisor desbloquea una cuenta' t13
caso T14 'Baja rechazada si el cliente tiene saldo' t14
caso T15 'Exportacion de ancho fijo con cola de control' t15
caso T16 'Servicio: login devuelve rol; clave incorrecta rechazada' t16
caso T17 'Servicio: alta, apertura y consulta con lineas de datos' t17
caso T18 'Servicio: operaciones devuelven saldo y respetan las reglas' t18
caso T19 'Servicio: el rol sale de USUARIOS, no del pedido' t19

echo
echo "Resultado: $((TOTAL - FALLAS)) de $TOTAL casos OK"
[ "$FALLAS" -eq 0 ]
