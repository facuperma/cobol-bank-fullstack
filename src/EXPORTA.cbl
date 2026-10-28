      *> EXPORTA (batch): movimientos del periodo en un archivo
      *> plano de ancho fijo (RA10), con registro de cabecera (H),
      *> detalle (D) y cola de control (T). Formato en
      *> docs/DISENO.md.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. EXPORTA IS INITIAL.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           COPY SEL-MOVIM.
           SELECT SALIDA ASSIGN TO WS-ARCHIVO
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-SALIDA.

       DATA DIVISION.
       FILE SECTION.
       FD MOVIMIENTOS.
       COPY REG-MOV.
       FD SALIDA.
       01 LIN-SALIDA            PIC X(120).

       WORKING-STORAGE SECTION.
       01 FS-MOVIM              PIC XX.
       01 FS-SALIDA             PIC XX.
       COPY AUD-DATOS.

       01 WS-ARCHIVO            PIC X(60).
       01 WS-FIN                PIC X VALUE "N".
       01 WS-PERIODO-MOV        PIC 9(6).
       01 WS-CANTIDAD           PIC 9(9) VALUE 0.
       01 WS-TOT-CREDITOS       PIC 9(13)V99 VALUE 0.
       01 WS-TOT-DEBITOS        PIC 9(13)V99 VALUE 0.
       01 WS-HOY                PIC X(8).
       01 WS-ED-CANT            PIC ZZZZZZZZ9.

      *> Largo de cada registro: 120 posiciones.
       01 REG-CABECERA.
          05 CAB-TIPO           PIC X VALUE "H".
          05 CAB-ENTIDAD        PIC X(8) VALUE "BANCOCOB".
          05 CAB-PERIODO        PIC 9(6).
          05 CAB-FECHA-GEN      PIC X(8).
          05 FILLER             PIC X(97) VALUE SPACES.

       01 REG-DETALLE.
          05 DET-TIPO           PIC X VALUE "D".
          05 DET-MOV-ID         PIC 9(12).
          05 DET-OPERACION      PIC 9(12).
          05 DET-CUENTA         PIC 9(10).
          05 DET-FECHA          PIC 9(8).
          05 DET-HORA           PIC 9(6).
          05 DET-CODIGO         PIC XX.
          05 DET-SIGNO          PIC X.
          05 DET-IMPORTE        PIC 9(11)V99.
          05 DET-SALDO-SIGNO    PIC X.
          05 DET-SALDO          PIC 9(11)V99.
          05 DET-DESCRIPCION    PIC X(40).
          05 FILLER             PIC X(1) VALUE SPACE.

       01 REG-COLA.
          05 COL-TIPO           PIC X VALUE "T".
          05 COL-CANTIDAD       PIC 9(9).
          05 COL-CREDITOS       PIC 9(13)V99.
          05 COL-DEBITOS        PIC 9(13)V99.
          05 FILLER             PIC X(80) VALUE SPACES.

       LINKAGE SECTION.
       COPY BATCH-PARAMS.

       PROCEDURE DIVISION USING BATCH-PARAMS.
       P-PRINCIPAL.
           MOVE 0 TO BAT-RC
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-HOY
           MOVE SPACES TO WS-ARCHIVO
           STRING "reports/EXPORT_" BAT-PERIODO ".txt"
               DELIMITED BY SIZE INTO WS-ARCHIVO
           END-STRING

           OPEN OUTPUT SALIDA
           IF FS-SALIDA NOT = "00"
               DISPLAY "ERROR: No se pudo crear " WS-ARCHIVO
               MOVE 2 TO BAT-RC
               GOBACK
           END-IF

           MOVE BAT-PERIODO TO CAB-PERIODO
           MOVE WS-HOY TO CAB-FECHA-GEN
           WRITE LIN-SALIDA FROM REG-CABECERA

           OPEN INPUT MOVIMIENTOS
           IF FS-MOVIM NOT = "00"
               MOVE "S" TO WS-FIN
           END-IF
           PERFORM UNTIL WS-FIN = "S"
               READ MOVIMIENTOS
                   AT END
                       MOVE "S" TO WS-FIN
                   NOT AT END
                       DIVIDE MOV-FECHA BY 100 GIVING WS-PERIODO-MOV
                       IF WS-PERIODO-MOV = BAT-PERIODO
                           PERFORM P-DETALLE
                       END-IF
               END-READ
           END-PERFORM
           IF FS-MOVIM NOT = "35"
               CLOSE MOVIMIENTOS
           END-IF

           MOVE WS-CANTIDAD TO COL-CANTIDAD
           MOVE WS-TOT-CREDITOS TO COL-CREDITOS
           MOVE WS-TOT-DEBITOS TO COL-DEBITOS
           WRITE LIN-SALIDA FROM REG-COLA
           CLOSE SALIDA

           MOVE WS-CANTIDAD TO WS-ED-CANT
           MOVE BAT-USUARIO TO AUD-USUARIO
           MOVE "EXPORTA" TO AUD-OPERACION
           MOVE ZERO TO AUD-CUENTA AUD-IMPORTE
           MOVE SPACES TO AUD-RESULTADO
           STRING "OK PERIODO " BAT-PERIODO " REGISTROS " WS-ED-CANT
               DELIMITED BY SIZE INTO AUD-RESULTADO
           END-STRING
           CALL "AUDITORIA" USING AUD-DATOS
           DISPLAY "OK: " FUNCTION TRIM(WS-ED-CANT)
                   " movimientos exportados a "
                   FUNCTION TRIM(WS-ARCHIVO)
           GOBACK.

       P-DETALLE.
           ADD 1 TO WS-CANTIDAD
           MOVE MOV-ID            TO DET-MOV-ID
           MOVE MOV-OPERACION     TO DET-OPERACION
           MOVE MOV-NRO-CUENTA    TO DET-CUENTA
           MOVE MOV-FECHA         TO DET-FECHA
           MOVE MOV-HORA          TO DET-HORA
           MOVE MOV-TIPO          TO DET-CODIGO
           MOVE MOV-IMPORTE       TO DET-IMPORTE
           MOVE MOV-SALDO-POST    TO DET-SALDO
           MOVE MOV-DESCRIPCION   TO DET-DESCRIPCION
           IF MOV-SUMA
               MOVE "+" TO DET-SIGNO
               ADD MOV-IMPORTE TO WS-TOT-CREDITOS
           ELSE
               MOVE "-" TO DET-SIGNO
               ADD MOV-IMPORTE TO WS-TOT-DEBITOS
           END-IF
           IF MOV-SALDO-POST < 0
               MOVE "-" TO DET-SALDO-SIGNO
           ELSE
               MOVE "+" TO DET-SALDO-SIGNO
           END-IF
           WRITE LIN-SALIDA FROM REG-DETALLE.
