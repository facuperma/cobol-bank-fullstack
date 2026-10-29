      *> TRANSAC: deposito, retiro y transferencia.
      *>   LK-OPCION "DE" deposito (RF5)
      *>             "RE" retiro con PIN y limite diario (RF6, RA1)
      *>             "TR" transferencia atomica (RF7)
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRANSAC IS INITIAL.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           COPY SEL-CUENTAS.

       DATA DIVISION.
       FILE SECTION.
       FD CUENTAS.
       COPY REG-CUENTA.

       WORKING-STORAGE SECTION.
       01 FS-CUENTAS            PIC XX.
       COPY PARAMETROS.
       COPY AUD-DATOS.
       COPY MOV-PARAMS.
       COPY MODO.

       01 WS-PROMPT             PIC X(40).
       01 WS-PROMPT-TXT         PIC X(60).
       01 WS-MAX                PIC 99.
       01 WS-NUMERO             PIC 9(12).
       01 WS-CERO               PIC X VALUE "N".
       01 WS-OK                 PIC X.
       01 WS-MENSAJE            PIC X(40).
       01 WS-ENTRADA            PIC X(50).
       01 WS-OPC-PIN            PIC XX VALUE "PI".
       01 WS-CTA                PIC 9(10).
       01 WS-CTA-DESTINO        PIC 9(10).
       01 WS-PIN                PIC X(4).
       01 WS-IMPORTE            PIC S9(11)V99 COMP-3.
       01 WS-PROYECTADO         PIC S9(11)V99 COMP-3.
       01 WS-SALDO-ORIGEN       PIC S9(11)V99 COMP-3.
       01 WS-SALDO-DESTINO      PIC S9(11)V99 COMP-3.
       01 WS-FECHA-ACTUAL       PIC 9(8).
       01 WS-SECUENCIA          PIC X(3).
       01 WS-OPERACION          PIC 9(12).
       01 WS-SALDO-ED           PIC -ZZ,ZZZ,ZZZ,ZZ9.99.
       01 WS-SRV-IMPORTE        PIC -(11)9.99.

       LINKAGE SECTION.
       COPY SESION.
       01 LK-OPCION             PIC XX.

       PROCEDURE DIVISION USING SESION LK-OPCION.
       P-PRINCIPAL.
           MOVE SES-USUARIO TO AUD-USUARIO
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-FECHA-ACTUAL
           EVALUATE LK-OPCION
               WHEN "DE"
                   PERFORM P-DEPOSITO
               WHEN "RE"
                   PERFORM P-RETIRO
               WHEN "TR"
                   PERFORM P-TRANSFERENCIA
           END-EVALUATE
           GOBACK.

      *> ---------------------------------------------------------
      *> Deposito
      *> ---------------------------------------------------------
       P-DEPOSITO.
           MOVE "DEPOSITO" TO AUD-OPERACION
           PERFORM P-PEDIR-CUENTA
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF
           PERFORM P-PEDIR-IMPORTE
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF

           OPEN I-O CUENTAS
           MOVE WS-CTA TO CTA-NRO
           READ CUENTAS KEY IS CTA-NRO
               INVALID KEY
                   MOVE "N" TO WS-OK
                   MOVE "Cuenta inexistente" TO WS-MENSAJE
               NOT INVALID KEY
                   IF NOT CTA-ABIERTA
                       MOVE "N" TO WS-OK
                       MOVE "Cuenta no operativa" TO WS-MENSAJE
                   END-IF
           END-READ

           IF WS-OK = "S"
               ADD WS-IMPORTE TO CTA-SALDO
               REWRITE REG-CUENTA
               IF FS-CUENTAS = "00"
                   MOVE CTA-SALDO TO WS-SALDO-ORIGEN
               ELSE
                   MOVE "N" TO WS-OK
                   MOVE "Error al actualizar la cuenta" TO WS-MENSAJE
               END-IF
           END-IF
           CLOSE CUENTAS

           IF WS-OK = "N"
               PERFORM P-RECHAZO
               EXIT PARAGRAPH
           END-IF

           PERFORM P-NUEVA-OPERACION
           MOVE WS-CTA            TO MOVP-CUENTA
           MOVE "DE"              TO MOVP-TIPO
           MOVE WS-IMPORTE        TO MOVP-IMPORTE
           MOVE WS-SALDO-ORIGEN   TO MOVP-SALDO
           MOVE "Deposito"        TO MOVP-DESC
           CALL "GRABAMOV" USING MOVP

           MOVE "OK" TO AUD-RESULTADO
           CALL "AUDITORIA" USING AUD-DATOS
           MOVE WS-SALDO-ORIGEN TO WS-SALDO-ED
           DISPLAY "OK: Deposito acreditado. Saldo: " WS-SALDO-ED
           PERFORM P-DATOS-SERVICIO.

      *> ---------------------------------------------------------
      *> Retiro. Orden de validaciones:
      *>  1-2. cuenta abierta y PIN correcto (CUENTAS "PI")
      *>  3. reinicio del acumulado si cambio el dia
      *>  4. limite diario   5. saldo suficiente   6. actualizar
      *> ---------------------------------------------------------
       P-RETIRO.
           MOVE "RETIRO" TO AUD-OPERACION
           PERFORM P-PEDIR-CUENTA
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF
           PERFORM P-PEDIR-PIN
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF
           PERFORM P-PEDIR-IMPORTE
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF

           CALL "CUENTAS" USING SESION WS-OPC-PIN WS-CTA WS-PIN
                                WS-OK WS-MENSAJE
           IF WS-OK = "N"
               PERFORM P-RECHAZO
               EXIT PARAGRAPH
           END-IF

           OPEN I-O CUENTAS
           MOVE WS-CTA TO CTA-NRO
           READ CUENTAS KEY IS CTA-NRO
               INVALID KEY
                   MOVE "N" TO WS-OK
                   MOVE "Cuenta inexistente" TO WS-MENSAJE
           END-READ

           IF WS-OK = "S"
               IF CTA-FECHA-HOY NOT = WS-FECHA-ACTUAL
                   MOVE ZERO TO CTA-RETIRADO-HOY
                   MOVE WS-FECHA-ACTUAL TO CTA-FECHA-HOY
               END-IF

               COMPUTE WS-PROYECTADO = CTA-RETIRADO-HOY + WS-IMPORTE

               IF WS-PROYECTADO > PAR-LIMITE-DIARIO
                   MOVE "N" TO WS-OK
                   MOVE "Limite diario superado" TO WS-MENSAJE
               ELSE
                   IF CTA-SALDO < WS-IMPORTE
                       MOVE "N" TO WS-OK
                       MOVE "Saldo insuficiente" TO WS-MENSAJE
                   ELSE
                       SUBTRACT WS-IMPORTE FROM CTA-SALDO
                       MOVE WS-PROYECTADO TO CTA-RETIRADO-HOY
                       REWRITE REG-CUENTA
                       IF FS-CUENTAS = "00"
                           MOVE CTA-SALDO TO WS-SALDO-ORIGEN
                       ELSE
                           MOVE "N" TO WS-OK
                           MOVE "Error al actualizar la cuenta"
                               TO WS-MENSAJE
                       END-IF
                   END-IF
               END-IF
           END-IF
           CLOSE CUENTAS

           IF WS-OK = "N"
               PERFORM P-RECHAZO
               EXIT PARAGRAPH
           END-IF

           PERFORM P-NUEVA-OPERACION
           MOVE WS-CTA            TO MOVP-CUENTA
           MOVE "RE"              TO MOVP-TIPO
           MOVE WS-IMPORTE        TO MOVP-IMPORTE
           MOVE WS-SALDO-ORIGEN   TO MOVP-SALDO
           MOVE "Retiro"          TO MOVP-DESC
           CALL "GRABAMOV" USING MOVP

           MOVE "OK" TO AUD-RESULTADO
           CALL "AUDITORIA" USING AUD-DATOS
           MOVE WS-SALDO-ORIGEN TO WS-SALDO-ED
           DISPLAY "OK: Retiro realizado. Saldo: " WS-SALDO-ED
           PERFORM P-DATOS-SERVICIO.

      *> ---------------------------------------------------------
      *> Transferencia. Se valida todo antes de tocar saldos; si
      *> el credito en destino falla despues de debitar el origen,
      *> se compensa reacreditando el origen.
      *> ---------------------------------------------------------
       P-TRANSFERENCIA.
           MOVE "TRANSF" TO AUD-OPERACION
           MOVE "Cuenta origen" TO WS-PROMPT
           PERFORM P-PEDIR-CUENTA
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF
           PERFORM P-PEDIR-PIN
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF

           MOVE "Cuenta destino" TO WS-PROMPT
           MOVE 10 TO WS-MAX
           CALL "PEDIRNUM" USING WS-PROMPT WS-MAX WS-NUMERO WS-OK
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF
           MOVE WS-NUMERO TO WS-CTA-DESTINO

           PERFORM P-PEDIR-IMPORTE
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF

           IF WS-CTA-DESTINO = WS-CTA
               MOVE "N" TO WS-OK
               MOVE "Origen y destino son la misma cuenta"
                   TO WS-MENSAJE
               PERFORM P-RECHAZO
               EXIT PARAGRAPH
           END-IF

           CALL "CUENTAS" USING SESION WS-OPC-PIN WS-CTA WS-PIN
                                WS-OK WS-MENSAJE
           IF WS-OK = "N"
               PERFORM P-RECHAZO
               EXIT PARAGRAPH
           END-IF

           OPEN I-O CUENTAS

      *>   1. Validar destino.
           MOVE WS-CTA-DESTINO TO CTA-NRO
           READ CUENTAS KEY IS CTA-NRO
               INVALID KEY
                   MOVE "N" TO WS-OK
                   MOVE "Cuenta destino inexistente" TO WS-MENSAJE
               NOT INVALID KEY
                   IF NOT CTA-ABIERTA
                       MOVE "N" TO WS-OK
                       MOVE "Cuenta destino no operativa"
                           TO WS-MENSAJE
                   END-IF
           END-READ

      *>   2. Validar saldo y debitar origen.
           IF WS-OK = "S"
               MOVE WS-CTA TO CTA-NRO
               READ CUENTAS KEY IS CTA-NRO
                   INVALID KEY
                       MOVE "N" TO WS-OK
                       MOVE "Cuenta origen inexistente" TO WS-MENSAJE
               END-READ
           END-IF
           IF WS-OK = "S"
               IF CTA-SALDO < WS-IMPORTE
                   MOVE "N" TO WS-OK
                   MOVE "Saldo insuficiente" TO WS-MENSAJE
               ELSE
                   SUBTRACT WS-IMPORTE FROM CTA-SALDO
                   REWRITE REG-CUENTA
                   IF FS-CUENTAS = "00"
                       MOVE CTA-SALDO TO WS-SALDO-ORIGEN
                   ELSE
                       MOVE "N" TO WS-OK
                       MOVE "Error al debitar el origen"
                           TO WS-MENSAJE
                   END-IF
               END-IF
           END-IF

      *>   3. Acreditar destino (o compensar).
           IF WS-OK = "S"
               PERFORM P-ACREDITAR-DESTINO
               IF WS-OK = "N"
                   PERFORM P-COMPENSAR-ORIGEN
               END-IF
           END-IF
           CLOSE CUENTAS

           IF WS-OK = "N"
               PERFORM P-RECHAZO
               EXIT PARAGRAPH
           END-IF

      *>   4. Los dos movimientos comparten numero de operacion.
           PERFORM P-NUEVA-OPERACION
           MOVE WS-CTA            TO MOVP-CUENTA
           MOVE "TD"              TO MOVP-TIPO
           MOVE WS-IMPORTE        TO MOVP-IMPORTE
           MOVE WS-SALDO-ORIGEN   TO MOVP-SALDO
           MOVE SPACES            TO MOVP-DESC
           STRING "Transferencia a " WS-CTA-DESTINO
               DELIMITED BY SIZE INTO MOVP-DESC
           END-STRING
           CALL "GRABAMOV" USING MOVP

           MOVE WS-CTA-DESTINO    TO MOVP-CUENTA
           MOVE "TC"              TO MOVP-TIPO
           MOVE WS-SALDO-DESTINO  TO MOVP-SALDO
           MOVE SPACES            TO MOVP-DESC
           STRING "Transferencia de " WS-CTA
               DELIMITED BY SIZE INTO MOVP-DESC
           END-STRING
           CALL "GRABAMOV" USING MOVP

           MOVE "OK" TO AUD-RESULTADO
           CALL "AUDITORIA" USING AUD-DATOS
           MOVE WS-SALDO-ORIGEN TO WS-SALDO-ED
           DISPLAY "OK: Transferencia realizada (operacion "
                   WS-OPERACION "). Saldo origen: " WS-SALDO-ED
           PERFORM P-DATOS-SERVICIO.

       P-ACREDITAR-DESTINO.
           MOVE WS-CTA-DESTINO TO CTA-NRO
           READ CUENTAS KEY IS CTA-NRO
               INVALID KEY
                   MOVE "N" TO WS-OK
           END-READ
           IF WS-OK = "S"
               ADD WS-IMPORTE TO CTA-SALDO
               REWRITE REG-CUENTA
               IF FS-CUENTAS = "00"
                   MOVE CTA-SALDO TO WS-SALDO-DESTINO
               ELSE
                   MOVE "N" TO WS-OK
               END-IF
           END-IF.

       P-COMPENSAR-ORIGEN.
           MOVE "Credito fallido; transferencia revertida"
               TO WS-MENSAJE
           MOVE WS-CTA TO CTA-NRO
           READ CUENTAS KEY IS CTA-NRO
               INVALID KEY
                   MOVE "COMPENSACION FALLIDA: REVISAR"
                       TO WS-MENSAJE
               NOT INVALID KEY
                   ADD WS-IMPORTE TO CTA-SALDO
                   REWRITE REG-CUENTA
                   IF FS-CUENTAS NOT = "00"
                       MOVE "COMPENSACION FALLIDA: REVISAR"
                           TO WS-MENSAJE
                   END-IF
           END-READ
           MOVE "COMPENS" TO AUD-OPERACION
           MOVE WS-CTA TO AUD-CUENTA
           MOVE WS-IMPORTE TO AUD-IMPORTE
           MOVE WS-MENSAJE TO AUD-RESULTADO
           CALL "AUDITORIA" USING AUD-DATOS
           MOVE "TRANSF" TO AUD-OPERACION.

      *> ---------------------------------------------------------
      *> Auxiliares
      *> ---------------------------------------------------------
       P-PEDIR-CUENTA.
           IF WS-PROMPT = SPACES
               MOVE "Numero de cuenta" TO WS-PROMPT
           END-IF
           MOVE 10 TO WS-MAX
           CALL "PEDIRNUM" USING WS-PROMPT WS-MAX WS-NUMERO WS-OK
           MOVE WS-NUMERO TO WS-CTA
           MOVE WS-CTA TO AUD-CUENTA.

       P-PEDIR-PIN.
           MOVE "N" TO WS-OK
           MOVE "PIN" TO WS-PROMPT-TXT
           CALL "LEERTXT" USING WS-PROMPT-TXT WS-ENTRADA
           IF WS-ENTRADA(1:4) IS NUMERIC AND WS-ENTRADA(5:) = SPACES
               MOVE WS-ENTRADA(1:4) TO WS-PIN
               MOVE "S" TO WS-OK
           ELSE
               DISPLAY "ERROR: El PIN debe tener 4 digitos"
           END-IF.

       P-PEDIR-IMPORTE.
           MOVE "Importe" TO WS-PROMPT
           CALL "PEDIRIMP" USING WS-PROMPT WS-CERO WS-IMPORTE WS-OK
           MOVE WS-IMPORTE TO AUD-IMPORTE.

       P-NUEVA-OPERACION.
           MOVE "OPE" TO WS-SECUENCIA
           CALL "NUMERADOR" USING WS-SECUENCIA WS-OPERACION
           MOVE WS-OPERACION TO MOVP-OPERACION.

      *> Datos de respuesta para la API (solo en modo servicio).
       P-DATOS-SERVICIO.
           IF MODO-SERVICIO
               MOVE WS-SALDO-ORIGEN TO WS-SRV-IMPORTE
               DISPLAY "@SALDO|" FUNCTION TRIM(WS-SRV-IMPORTE)
               DISPLAY "@OPERACION|" WS-OPERACION
           END-IF.

       P-RECHAZO.
           DISPLAY "ERROR: " FUNCTION TRIM(WS-MENSAJE)
           MOVE SPACES TO AUD-RESULTADO
           STRING "RECHAZADO " WS-MENSAJE
               DELIMITED BY SIZE INTO AUD-RESULTADO
           END-STRING
           CALL "AUDITORIA" USING AUD-DATOS.
