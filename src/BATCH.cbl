      *> BATCH: punto de entrada de los procesos por lotes, al
      *> estilo de un paso de JCL.
      *>   batch INTERES  [AAAAMM] [tasa anual]
      *>   batch CIERRE   [AAAAMM]
      *>   batch RECONCIL
      *>   batch RANKING
      *>   batch EXPORTA  [AAAAMM]
      *>   batch CARGA    CONFIRMAR   (borra y carga datos de prueba)
      *> AAAAMM por defecto: mes actual. Tasa por defecto: 6.00.
      *> El codigo de retorno es el del proceso (0 = OK).
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY BATCH-PARAMS.
       01 WS-PROCESO            PIC X(10) VALUE SPACES.
       01 WS-ARG2               PIC X(20) VALUE SPACES.
       01 WS-ARG3               PIC X(20) VALUE SPACES.
       01 WS-HOY                PIC X(8).
       01 WS-OK                 PIC X VALUE "S".

       PROCEDURE DIVISION.
       P-PRINCIPAL.
           ACCEPT WS-PROCESO FROM ARGUMENT-VALUE
           ACCEPT WS-ARG2 FROM ARGUMENT-VALUE
           ACCEPT WS-ARG3 FROM ARGUMENT-VALUE
           MOVE FUNCTION UPPER-CASE(WS-PROCESO) TO WS-PROCESO

           MOVE "BATCH" TO BAT-USUARIO
           MOVE 0 TO BAT-RC
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-HOY
           MOVE WS-HOY(1:6) TO BAT-PERIODO
           MOVE 6.00 TO BAT-TASA

           IF WS-PROCESO NOT = "CARGA"
               PERFORM P-PERIODO
               PERFORM P-TASA
           END-IF
           IF WS-OK = "N"
               MOVE 8 TO RETURN-CODE
               STOP RUN
           END-IF

           EVALUATE WS-PROCESO
               WHEN "INTERES"
                   CALL "INTERES" USING BATCH-PARAMS
               WHEN "CIERRE"
                   CALL "CIERRE" USING BATCH-PARAMS
               WHEN "RECONCIL"
                   CALL "RECONCIL" USING BATCH-PARAMS
               WHEN "RANKING"
                   CALL "RANKING" USING BATCH-PARAMS
               WHEN "EXPORTA"
                   CALL "EXPORTA" USING BATCH-PARAMS
               WHEN "CARGA"
                   IF FUNCTION UPPER-CASE(WS-ARG2) = "CONFIRMAR"
                       CALL "CARGA" USING BATCH-PARAMS
                   ELSE
                       DISPLAY "CARGA borra todos los datos. Para "
                               "continuar: batch CARGA CONFIRMAR"
                       MOVE 8 TO BAT-RC
                   END-IF
               WHEN OTHER
                   DISPLAY "Uso: batch INTERES|CIERRE|RECONCIL|"
                           "RANKING|EXPORTA|CARGA [AAAAMM] [tasa]"
                   MOVE 8 TO BAT-RC
           END-EVALUATE

           MOVE BAT-RC TO RETURN-CODE
           STOP RUN.

       P-PERIODO.
           IF WS-ARG2 = SPACES
               EXIT PARAGRAPH
           END-IF
           IF WS-ARG2(1:6) IS NOT NUMERIC OR WS-ARG2(7:) NOT = SPACES
              OR WS-ARG2(5:2) < "01" OR WS-ARG2(5:2) > "12"
               DISPLAY "ERROR: Periodo invalido (use AAAAMM)"
               MOVE "N" TO WS-OK
           ELSE
               MOVE WS-ARG2(1:6) TO BAT-PERIODO
           END-IF.

       P-TASA.
           IF WS-ARG3 = SPACES
               EXIT PARAGRAPH
           END-IF
           IF FUNCTION TEST-NUMVAL(WS-ARG3) NOT = 0
               DISPLAY "ERROR: Tasa invalida"
               MOVE "N" TO WS-OK
               EXIT PARAGRAPH
           END-IF
           IF FUNCTION NUMVAL(WS-ARG3) < 0 OR
              FUNCTION NUMVAL(WS-ARG3) > 100
               DISPLAY "ERROR: La tasa debe estar entre 0 y 100"
               MOVE "N" TO WS-OK
               EXIT PARAGRAPH
           END-IF
           COMPUTE BAT-TASA = FUNCTION NUMVAL(WS-ARG3).
