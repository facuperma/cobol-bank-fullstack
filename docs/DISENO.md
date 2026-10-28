# Diseño de archivos

Todos los archivos se crean en `data/` (relativo a la carpeta desde donde se ejecuta).

| Archivo | Organización | Clave primaria | Clave alternativa | Copybook |
| --- | --- | --- | --- | --- |
| CLIENTES.DAT | Indexada | `CLI-ID` | `CLI-DOCUMENTO` (sin duplicados) | REG-CLIENTE |
| CUENTAS.DAT | Indexada | `CTA-NRO` | `CTA-ID-CLIENTE` (con duplicados) | REG-CUENTA |
| MOVIMIENTOS.DAT | Secuencial | — | — | REG-MOV |
| USUARIOS.DAT | Indexada | `USU-ID` | — | REG-USUARIO |
| CONTROL.DAT | Indexada | `CTL-CLAVE` | — | REG-CONTROL |
| AUDITORIA.LOG | Secuencial de líneas, solo `EXTEND` | — | — | — |

## Registros

### Cliente (`REG-CLIENTE`)

| Campo | PIC | Descripción |
| --- | --- | --- |
| CLI-ID | 9(6) | Número de cliente (secuencia `CLI`) |
| CLI-DOCUMENTO | X(12) | Documento, único |
| CLI-NOMBRE / CLI-APELLIDO | X(30) | En mayúsculas |
| CLI-FECHA-NAC | 9(8) | AAAAMMDD |
| CLI-DIRECCION | X(50) | |
| CLI-TELEFONO | X(15) | |
| CLI-ESTADO | X | `A` activo, `I` inactivo (baja lógica) |

### Cuenta (`REG-CUENTA`)

| Campo | PIC | Descripción |
| --- | --- | --- |
| CTA-NRO | 9(10) | Número de cuenta (secuencia `CTA`, desde 1000000001) |
| CTA-ID-CLIENTE | 9(6) | Titular |
| CTA-TIPO | X | `A` caja de ahorro, `C` cuenta corriente |
| CTA-SALDO | S9(11)V99 COMP-3 | Saldo |
| CTA-PIN-HASH | 9(8) | hash(PIN + CTA-NRO) |
| CTA-INTENTOS | 9 | PIN fallidos consecutivos |
| CTA-ESTADO | X | `A` abierta, `B` bloqueada, `C` cerrada |
| CTA-RETIRADO-HOY | S9(9)V99 COMP-3 | Acumulado de retiros del día |
| CTA-FECHA-HOY | 9(8) | Día al que corresponde el acumulado |
| CTA-ULT-INTERES | 9(6) | Último período (AAAAMM) con intereses pagados |

### Movimiento (`REG-MOV`, 104 bytes)

| Campo | PIC | Descripción |
| --- | --- | --- |
| MOV-ID | 9(12) | Número de movimiento (secuencia `MOV`) |
| MOV-OPERACION | 9(12) | Número de operación (secuencia `OPE`); TD y TC de una transferencia comparten el mismo |
| MOV-NRO-CUENTA | 9(10) | |
| MOV-FECHA / MOV-HORA | 9(8) / 9(6) | |
| MOV-TIPO | X(2) | `DE` depósito, `RE` retiro, `TD` transferencia débito, `TC` transferencia crédito, `IN` interés |
| MOV-IMPORTE | S9(11)V99 COMP-3 | Siempre positivo; el tipo define el signo |
| MOV-SALDO-POST | S9(11)V99 COMP-3 | Saldo después del movimiento |
| MOV-DESCRIPCION | X(40) | |

## Exportación de ancho fijo (`reports/EXPORT_AAAAMM.txt`)

Registros de 120 posiciones. Los importes van sin punto decimal, con 2 decimales implícitos (`000000025000` = 250.00).

**Cabecera (H)**

| Posición | Largo | Campo |
| --- | --- | --- |
| 1 | 1 | Tipo `H` |
| 2 | 8 | Entidad `BANCOCOB` |
| 10 | 6 | Período AAAAMM |
| 16 | 8 | Fecha de generación AAAAMMDD |
| 24 | 97 | Espacios |

**Detalle (D)**

| Posición | Largo | Campo |
| --- | --- | --- |
| 1 | 1 | Tipo `D` |
| 2 | 12 | Número de movimiento |
| 14 | 12 | Número de operación |
| 26 | 10 | Cuenta |
| 36 | 8 | Fecha AAAAMMDD |
| 44 | 6 | Hora HHMMSS |
| 50 | 2 | Código de movimiento |
| 52 | 1 | Signo `+` crédito / `-` débito |
| 53 | 13 | Importe (11 enteros + 2 decimales) |
| 66 | 1 | Signo del saldo |
| 67 | 13 | Saldo posterior |
| 80 | 40 | Descripción |
| 120 | 1 | Espacio |

**Cola de control (T)**

| Posición | Largo | Campo |
| --- | --- | --- |
| 1 | 1 | Tipo `T` |
| 2 | 9 | Cantidad de detalles |
| 11 | 15 | Total de créditos (13 + 2 decimales) |
| 26 | 15 | Total de débitos (13 + 2 decimales) |
| 41 | 80 | Espacios |

El receptor valida la cantidad y los totales de la cola contra los detalles, como en los archivos de intercambio bancario.
