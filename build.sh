#!/usr/bin/env bash
# Compila el sistema con GnuCOBOL (Linux / macOS / WSL).
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p bin data reports

COMUNES="src/AUDITORIA.cbl src/NUMERADOR.cbl src/HASHCLAVE.cbl src/GRABAMOV.cbl src/UTILES.cbl"
BATCH="src/INTERES.cbl src/CIERRE.cbl src/RECONCIL.cbl src/RANKING.cbl src/EXPORTA.cbl"
OPCIONES="-x -fstatic-call -Wall -I copy"

echo "Compilando bin/banco..."
cobc $OPCIONES -o bin/banco src/BANCO.cbl src/CLIENTES.cbl src/CUENTAS.cbl \
     src/TRANSAC.cbl src/EXTRACTO.cbl $BATCH $COMUNES
echo "Compilando bin/batch..."
cobc $OPCIONES -o bin/batch src/BATCH.cbl src/CARGA.cbl $BATCH $COMUNES
echo "Compilando bin/tstalter..."
cobc $OPCIONES -o bin/tstalter tests/TSTALTER.cbl

echo "OK: ejecutables en bin/"
