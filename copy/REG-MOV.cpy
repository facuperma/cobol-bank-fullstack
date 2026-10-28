      *> Registro de movimiento (MOVIMIENTOS.DAT, secuencial).
      *> MOV-OPERACION agrupa los dos movimientos de una
      *> transferencia (TD y TC comparten el mismo numero).
       01 REG-MOV.
          05 MOV-ID             PIC 9(12).
          05 MOV-OPERACION      PIC 9(12).
          05 MOV-NRO-CUENTA     PIC 9(10).
          05 MOV-FECHA          PIC 9(8).
          05 MOV-HORA           PIC 9(6).
          05 MOV-TIPO           PIC X(2).
             88 MOV-DEPOSITO    VALUE "DE".
             88 MOV-RETIRO      VALUE "RE".
             88 MOV-TRANSF-DEB  VALUE "TD".
             88 MOV-TRANSF-CRE  VALUE "TC".
             88 MOV-INTERES     VALUE "IN".
             88 MOV-SUMA        VALUE "DE" "TC" "IN".
             88 MOV-RESTA       VALUE "RE" "TD".
          05 MOV-IMPORTE        PIC S9(11)V99 COMP-3.
          05 MOV-SALDO-POST     PIC S9(11)V99 COMP-3.
          05 MOV-DESCRIPCION    PIC X(40).
