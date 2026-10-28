# Reglas de negocio

Los valores configurables están en `copy/PARAMETROS.cpy`.

| Parámetro | Valor |
| --- | --- |
| Límite diario de retiro por cuenta | 500.00 |
| Intentos de PIN antes del bloqueo | 3 |
| Edad mínima del cliente | 18 años |
| Tasa anual de intereses por defecto | 6.00 % |

## Clientes

- El documento tiene entre 7 y 12 dígitos y no puede repetirse (clave alternativa sin duplicados).
- Nombre y apellido son obligatorios y se guardan en mayúsculas.
- La fecha de nacimiento debe existir, no ser futura y el cliente debe ser mayor de edad.
- La modificación cambia dirección y teléfono; un dato vacío conserva el valor anterior.
- La baja es lógica (estado `I`) y solo procede si la suma de saldos de sus cuentas es cero. Al darlo de baja se cierran sus cuentas.

## Cuentas

- Solo un cliente activo puede abrir cuentas.
- El PIN tiene 4 dígitos, se ingresa dos veces y se guarda como hash.
- El depósito inicial es opcional; si lo hay, se registra como movimiento `DE`.

## PIN y bloqueo

- Retiro, transferencia (cuenta origen) y consulta de saldo piden PIN.
- Cada PIN incorrecto suma un intento; al tercero la cuenta pasa a bloqueada y se audita como `BLOQUEO`.
- Un PIN correcto pone el contador en cero.
- Una cuenta bloqueada no opera hasta que un supervisor la desbloquea (menú 8 → 1).

## Operaciones

- Los importes son mayores a cero, con hasta 2 decimales (se acepta `.` o `,`).
- Solo operan las cuentas abiertas.
- **Retiro:** el acumulado diario se reinicia cuando cambia la fecha; se rechaza si el acumulado más el importe supera el límite o si no hay saldo suficiente.
- **Transferencia:** origen y destino deben ser distintos; el destino tiene que existir y estar abierto. No tiene límite diario. Ver la compensación en el README.
- No se permite descubierto, tampoco en cuenta corriente.

## Roles

| Función | Cajero | Supervisor |
| --- | --- | --- |
| Clientes, apertura, depósito, retiro, transferencia, consulta, extracto | Sí | Sí |
| Desbloqueo de cuentas | No | Sí |
| Procesos batch desde el menú | No | Sí |

Desde la línea de comandos, `bin/batch` corre con el usuario `BATCH` (equivale a un job de operación nocturna).

## Procesos batch

- **Intereses:** solo cajas de ahorro abiertas con saldo positivo. `interés = saldo × tasa / 12 / 100`, redondeado a 2 decimales. Una vez por período y cuenta.
- **Cierre:** depósitos, retiros, transferencias e intereses del período (cantidad e importe), total de operaciones, clientes activos y dados de baja, cuentas por estado y saldo total de la cartera. No modifica datos.
- **Reconciliación:** para cada cuenta, `DE + TC + IN − RE − TD` debe ser igual al saldo.
- **Ranking:** clientes activos por saldo total descendente (empate: por número de cliente).
