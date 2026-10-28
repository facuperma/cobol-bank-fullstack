# Datos de prueba

Se cargan con `batch CARGA CONFIRMAR`, que borra los datos existentes (no el log de auditoría).

## Usuarios

| Usuario | Clave | Rol |
| --- | --- | --- |
| CAJERO01 | 1234 | Cajero |
| SUPER01 | 9999 | Supervisor |

## Clientes

| ID | Documento | Nombre |
| --- | --- | --- |
| 000001 | 30111222 | Juan Pérez |
| 000002 | 27333444 | María Gómez |
| 000003 | 35555666 | Carlos Rodríguez |
| 000004 | 40777888 | Lucía Fernández |
| 000005 | 22999000 | Jorge López |

## Cuentas

| Cuenta | Cliente | Tipo | PIN | Saldo | Estado |
| --- | --- | --- | --- | --- | --- |
| 1000000001 | 000001 | Caja de ahorro | 1234 | 1,500.00 | Abierta |
| 1000000002 | 000001 | Cuenta corriente | 1234 | 3,000.00 | Abierta |
| 1000000003 | 000002 | Caja de ahorro | 2222 | 800.00 | Abierta |
| 1000000004 | 000002 | Caja de ahorro | 2222 | 0.00 | Abierta |
| 1000000005 | 000003 | Cuenta corriente | 3333 | 12,000.00 | Abierta |
| 1000000006 | 000003 | Caja de ahorro | 3333 | 250.00 | **Bloqueada** |
| 1000000007 | 000004 | Caja de ahorro | 4444 | 0.00 | Abierta |
| 1000000008 | 000005 | Caja de ahorro | 5555 | 5,000.00 | Abierta |

Cada saldo distinto de cero tiene su movimiento de depósito inicial, así que los datos concilian desde el principio.
