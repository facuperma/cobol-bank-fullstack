      *> RECONCIL (batch): verifica que el saldo de cada cuenta
      *> sea igual a la suma de sus movimientos (RA6).
      *> Las cuentas abren en cero y todo cambio de saldo deja un
      *> movimiento, asi que: saldo = creditos - debitos.
      *> Escribe reports/DISCREPANCIAS.txt. BAT-RC = 1 si hay
      *> diferencias.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. RECONCIL IS INITIAL.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           COPY SEL-MOVIM.
           COPY SEL-CUENTAS.
           SELECT REPORTE ASSIGN TO "reports/DISCREPANCIAS.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-REPORTE.

       DATA DIVISION.
       FILE SECTION.
       FD MOVIMIENTOS.
       COPY REG-MOV.
       FD CUENTAS.
       COPY REG-CUENTA.
       FD REPORTE.
       01 LIN-REPORTE           PIC X(90).

       WORKING-STORAGE SECTION.
       01 FS-MOVIM              PIC XX.
       01 FS-CUENTAS            PIC XX.
       01 FS-REPORTE            PIC XX.
       COPY AUD-DATOS.

       01 WS-MAX-CUENTAS        PIC 9(5) VALUE 5000.
       01 WS-TABLA.
          05 WS-CANT            PIC 9(5) VALUE 0.
          05 WS-ITEM OCCURS 1 TO 5000 TIMES
                     DEPENDING ON WS-CANT
                     INDEXED BY IX.
             10 WT-CUENTA       PIC 9(10).
             10 WT-SUMA         PIC S9(13)V99 COMP-3.
             10 WT-VISTA        PIC X.

       01 WS-FIN                PIC X.
       01 WS-ESPERADO           PIC S9(13)V99 COMP-3.
       01 WS-DIFERENCIAS        PIC 9(6) VALUE 0.
       01 WS-REVISADAS          PIC 9(6) VALUE 0.
       01 WS-SIN-LUGAR          PIC X VALUE "N".

       01 WS-LINEA.
          05 FILLER             PIC X VALUE SPACE.
          05 WL-CUENTA          PIC 9(10).
          05 FILLER             PIC X(3) VALUE SPACES.
          05 WL-ESPERADO        PIC -ZZ,ZZZ,ZZZ,ZZ9.99.
          05 FILLER             PIC X(3) VALUE SPACES.
          05 WL-REAL            PIC -ZZ,ZZZ,ZZZ,ZZ9.99.
          05 FILLER             PIC X(3) VALUE SPACES.
          05 WL-NOTA            PIC X(30).

       01 WS-ED-CANT            PIC ZZZZZ9.

       LINKAGE SECTION.
       COPY BATCH-PARAMS.

       PROCEDURE DIVISION USING BATCH-PARAMS.
       P-PRINCIPAL.
           MOVE 0 TO BAT-RC
           DISPLAY "== RECONCILIACION DE SALDOS =="
           PERFORM P-SUMAR-MOVIMIENTOS
           IF WS-SIN-LUGAR = "S"
               DISPLAY "ERROR: Mas de 5000 cuentas con movimientos"
               MOVE 2 TO BAT-RC
               GOBACK
           END-IF

           OPEN OUTPUT REPORTE
           MOVE " DISCREPANCIAS DE SALDO" TO LIN-REPORTE
           WRITE LIN-REPORTE
           MOVE " CUENTA               ESPERADO             REAL   NOTA"
               TO LIN-REPORTE
           WRITE LIN-REPORTE

           PERFORM P-COMPARAR-CUENTAS
           PERFORM P-MOVIMIENTOS-HUERFANOS

           IF WS-DIFERENCIAS = 0
               MOVE " Sin discrepancias." TO LIN-REPORTE
               WRITE LIN-REPORTE
           ELSE
               MOVE 1 TO BAT-RC
           END-IF
           CLOSE REPORTE

           MOVE WS-REVISADAS TO WS-ED-CANT
           DISPLAY "Cuentas revisadas : " WS-ED-CANT
           MOVE WS-DIFERENCIAS TO WS-ED-CANT
           DISPLAY "Discrepancias     : " WS-ED-CANT
           IF WS-DIFERENCIAS = 0
               DISPLAY "OK: Saldos conciliados"
           ELSE
               DISPLAY "ATENCION: Ver reports/DISCREPANCIAS.txt"
           END-IF

           MOVE BAT-USUARIO TO AUD-USUARIO
           MOVE "RECONCIL" TO AUD-OPERACION
           MOVE ZERO TO AUD-CUENTA AUD-IMPORTE
           MOVE SPACES TO AUD-RESULTADO
           STRING "DISCREPANCIAS " WS-ED-CANT
               DELIMITED BY SIZE INTO AUD-RESULTADO
           END-STRING
           CALL "AUDITORIA" USING AUD-DATOS
           GOBACK.

      *> Acumula en una tabla en memoria el neto de movimientos
      *> por cuenta.
       P-SUMAR-MOVIMIENTOS.
           MOVE "N" TO WS-FIN
           OPEN INPUT MOVIMIENTOS
           IF FS-MOVIM NOT = "00"
               MOVE "S" TO WS-FIN
           END-IF
           PERFORM UNTIL WS-FIN = "S"
               READ MOVIMIENTOS
                   AT END
                       MOVE "S" TO WS-FIN
                   NOT AT END
                       PERFORM P-UBICAR-CUENTA
                       IF WS-SIN-LUGAR = "S"
                           MOVE "S" TO WS-FIN
                       ELSE
                           IF MOV-SUMA
                               ADD MOV-IMPORTE TO WT-SUMA(IX)
                           ELSE
                               SUBTRACT MOV-IMPORTE FROM WT-SUMA(IX)
                           END-IF
                       END-IF
               END-READ
           END-PERFORM
           IF FS-MOVIM NOT = "35"
               CLOSE MOVIMIENTOS
           END-IF.

      *> Deja IX apuntando a la cuenta MOV-NRO-CUENTA en la tabla
      *> (la agrega si no estaba).
       P-UBICAR-CUENTA.
           SET IX TO 1
           SEARCH WS-ITEM
               AT END
                   IF WS-CANT >= WS-MAX-CUENTAS
                       MOVE "S" TO WS-SIN-LUGAR
                   ELSE
                       ADD 1 TO WS-CANT
                       SET IX TO WS-CANT
                       MOVE MOV-NRO-CUENTA TO WT-CUENTA(IX)
                       MOVE ZERO TO WT-SUMA(IX)
                       MOVE "N" TO WT-VISTA(IX)
                   END-IF
               WHEN WT-CUENTA(IX) = MOV-NRO-CUENTA
                   CONTINUE
           END-SEARCH.

       P-COMPARAR-CUENTAS.
           MOVE "N" TO WS-FIN
           OPEN INPUT CUENTAS
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
                       PERFORM P-COMPARAR-UNA
               END-READ
           END-PERFORM
           CLOSE CUENTAS.

       P-COMPARAR-UNA.
           ADD 1 TO WS-REVISADAS
           MOVE ZERO TO WS-ESPERADO
           SET IX TO 1
           IF WS-CANT > 0
               SEARCH WS-ITEM
                   AT END
                       CONTINUE
                   WHEN WT-CUENTA(IX) = CTA-NRO
                       MOVE WT-SUMA(IX) TO WS-ESPERADO
                       MOVE "S" TO WT-VISTA(IX)
               END-SEARCH
           END-IF
           IF WS-ESPERADO NOT = CTA-SALDO
               ADD 1 TO WS-DIFERENCIAS
               MOVE CTA-NRO TO WL-CUENTA
               MOVE WS-ESPERADO TO WL-ESPERADO
               MOVE CTA-SALDO TO WL-REAL
               MOVE "Saldo distinto a movimientos" TO WL-NOTA
               MOVE WS-LINEA TO LIN-REPORTE
               WRITE LIN-REPORTE
               DISPLAY "DISCREPANCIA cuenta " CTA-NRO
           END-IF.

      *> Movimientos de cuentas que no existen en CUENTAS.DAT.
       P-MOVIMIENTOS-HUERFANOS.
           PERFORM VARYING IX FROM 1 BY 1 UNTIL IX > WS-CANT
               IF WT-VISTA(IX) = "N"
                   ADD 1 TO WS-DIFERENCIAS
                   MOVE WT-CUENTA(IX) TO WL-CUENTA
                   MOVE WT-SUMA(IX) TO WL-ESPERADO
                   MOVE ZERO TO WL-REAL
                   MOVE "Cuenta inexistente" TO WL-NOTA
                   MOVE WS-LINEA TO LIN-REPORTE
                   WRITE LIN-REPORTE
                   DISPLAY "DISCREPANCIA cuenta " WT-CUENTA(IX)
                           " (inexistente)"
               END-IF
           END-PERFORM.
