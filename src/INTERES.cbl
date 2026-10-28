      *> INTERES (batch): acredita el interes mensual a las cajas
      *> de ahorro abiertas (RA4).
      *>   interes = saldo * tasa anual / 12 / 100, redondeado.
      *> Idempotente: CTA-ULT-INTERES guarda el ultimo periodo
      *> pagado, asi que correrlo dos veces en el mismo mes (o
      *> reanudarlo tras un corte) no paga dos veces.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. INTERES IS INITIAL.

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
       COPY AUD-DATOS.
       COPY MOV-PARAMS.

       01 WS-FIN                PIC X VALUE "N".
       01 WS-INTERES            PIC S9(11)V99 COMP-3.
       01 WS-PROCESADAS         PIC 9(6) VALUE 0.
       01 WS-YA-PAGADAS         PIC 9(6) VALUE 0.
       01 WS-TOTAL              PIC S9(13)V99 COMP-3 VALUE 0.
       01 WS-SECUENCIA          PIC X(3) VALUE "OPE".
       01 WS-ED-CANT            PIC ZZZZZ9.
       01 WS-ED-IMPORTE         PIC -ZZ,ZZZ,ZZZ,ZZ9.99.
       01 WS-ED-TASA            PIC ZZ9.99.

       LINKAGE SECTION.
       COPY BATCH-PARAMS.

       PROCEDURE DIVISION USING BATCH-PARAMS.
       P-PRINCIPAL.
           MOVE 0 TO BAT-RC
           MOVE BAT-TASA TO WS-ED-TASA
           DISPLAY "== INTERESES periodo " BAT-PERIODO
                   " tasa anual " WS-ED-TASA "% =="

           OPEN I-O CUENTAS
           IF FS-CUENTAS NOT = "00"
               DISPLAY "ERROR: No se pudo abrir CUENTAS FS="
                       FS-CUENTAS
               MOVE 2 TO BAT-RC
               GOBACK
           END-IF

           MOVE ZERO TO CTA-NRO
           START CUENTAS KEY IS >= CTA-NRO
               INVALID KEY
                   MOVE "S" TO WS-FIN
           END-START
           PERFORM UNTIL WS-FIN = "S"
               READ CUENTAS NEXT RECORD
                   AT END
                       MOVE "S" TO WS-FIN
                   NOT AT END
                       PERFORM P-PROCESAR-CUENTA
               END-READ
           END-PERFORM
           CLOSE CUENTAS

           MOVE WS-PROCESADAS TO WS-ED-CANT
           DISPLAY "Cuentas procesadas : " WS-ED-CANT
           MOVE WS-YA-PAGADAS TO WS-ED-CANT
           DISPLAY "Ya pagadas antes   : " WS-ED-CANT
           MOVE WS-TOTAL TO WS-ED-IMPORTE
           DISPLAY "Intereses pagados  : " WS-ED-IMPORTE

           MOVE BAT-USUARIO TO AUD-USUARIO
           MOVE "INTERES" TO AUD-OPERACION
           MOVE ZERO TO AUD-CUENTA
           MOVE WS-TOTAL TO AUD-IMPORTE
           MOVE SPACES TO AUD-RESULTADO
           STRING "OK PERIODO " BAT-PERIODO " CUENTAS " WS-ED-CANT
               DELIMITED BY SIZE INTO AUD-RESULTADO
           END-STRING
           CALL "AUDITORIA" USING AUD-DATOS
           GOBACK.

       P-PROCESAR-CUENTA.
           IF NOT CTA-AHORRO OR NOT CTA-ABIERTA OR CTA-SALDO <= 0
               EXIT PARAGRAPH
           END-IF
           IF CTA-ULT-INTERES >= BAT-PERIODO
               ADD 1 TO WS-YA-PAGADAS
               EXIT PARAGRAPH
           END-IF

           COMPUTE WS-INTERES ROUNDED =
               CTA-SALDO * BAT-TASA / 12 / 100
           IF WS-INTERES <= 0
               EXIT PARAGRAPH
           END-IF

           ADD WS-INTERES TO CTA-SALDO
           MOVE BAT-PERIODO TO CTA-ULT-INTERES
           REWRITE REG-CUENTA
           IF FS-CUENTAS NOT = "00"
               DISPLAY "ERROR: No se actualizo la cuenta " CTA-NRO
               MOVE 2 TO BAT-RC
               EXIT PARAGRAPH
           END-IF

           CALL "NUMERADOR" USING WS-SECUENCIA MOVP-OPERACION
           MOVE CTA-NRO           TO MOVP-CUENTA
           MOVE "IN"              TO MOVP-TIPO
           MOVE WS-INTERES        TO MOVP-IMPORTE
           MOVE CTA-SALDO         TO MOVP-SALDO
           MOVE SPACES            TO MOVP-DESC
           STRING "Interes " BAT-PERIODO
               DELIMITED BY SIZE INTO MOVP-DESC
           END-STRING
           CALL "GRABAMOV" USING MOVP

           ADD 1 TO WS-PROCESADAS
           ADD WS-INTERES TO WS-TOTAL.
