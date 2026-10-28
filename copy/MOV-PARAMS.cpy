      *> Parametro del subprograma GRABAMOV.
       01 MOVP.
          05 MOVP-CUENTA        PIC 9(10).
          05 MOVP-OPERACION     PIC 9(12).
          05 MOVP-TIPO          PIC XX.
          05 MOVP-IMPORTE       PIC S9(11)V99 COMP-3.
          05 MOVP-SALDO         PIC S9(11)V99 COMP-3.
          05 MOVP-DESC          PIC X(40).
      *>  Salida: numero de movimiento asignado (0 = error).
          05 MOVP-ID            PIC 9(12).
