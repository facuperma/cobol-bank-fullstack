      *> RANKING (batch): clientes activos ordenados por saldo
      *> total descendente con el verbo SORT (RA8).
      *> El saldo de cada cliente se arma recorriendo sus cuentas
      *> por la clave alternativa CTA-ID-CLIENTE.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. RANKING IS INITIAL.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           COPY SEL-CLIENTES.
           COPY SEL-CUENTAS.
           SELECT TRABAJO ASSIGN TO "data/SORTWK.TMP".
           SELECT REPORTE ASSIGN TO "reports/RANKING_CLIENTES.txt"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-REPORTE.

       DATA DIVISION.
       FILE SECTION.
       FD CLIENTES.
       COPY REG-CLIENTE.
       FD CUENTAS.
       COPY REG-CUENTA.
       SD TRABAJO.
       01 SRT-REGISTRO.
          05 SRT-SALDO          PIC S9(13)V99.
          05 SRT-ID             PIC 9(6).
          05 SRT-CUENTAS        PIC 9(3).
          05 SRT-NOMBRE         PIC X(50).
       FD REPORTE.
       01 LIN-REPORTE           PIC X(90).

       WORKING-STORAGE SECTION.
       01 FS-CLIENTES           PIC XX.
       01 FS-CUENTAS            PIC XX.
       01 FS-REPORTE            PIC XX.
       COPY AUD-DATOS.

       01 WS-FIN                PIC X.
       01 WS-FIN-CTA            PIC X.
       01 WS-SALDO              PIC S9(13)V99 COMP-3.
       01 WS-CANT-CUENTAS       PIC 9(3).
       01 WS-POSICION           PIC 9(5) VALUE 0.

       01 WS-LINEA.
          05 WL-POSICION        PIC ZZZZ9.
          05 FILLER             PIC X(2) VALUE SPACES.
          05 WL-ID              PIC 9(6).
          05 FILLER             PIC X(2) VALUE SPACES.
          05 WL-NOMBRE          PIC X(40).
          05 WL-CUENTAS         PIC ZZ9.
          05 FILLER             PIC X(2) VALUE SPACES.
          05 WL-SALDO           PIC -ZZ,ZZZ,ZZZ,ZZ9.99.

       LINKAGE SECTION.
       COPY BATCH-PARAMS.

       PROCEDURE DIVISION USING BATCH-PARAMS.
       P-PRINCIPAL.
           MOVE 0 TO BAT-RC
           SORT TRABAJO
               ON DESCENDING KEY SRT-SALDO
               ON ASCENDING KEY SRT-ID
               INPUT PROCEDURE IS P-ENTRADA
               OUTPUT PROCEDURE IS P-SALIDA

           MOVE BAT-USUARIO TO AUD-USUARIO
           MOVE "RANKING" TO AUD-OPERACION
           MOVE ZERO TO AUD-CUENTA AUD-IMPORTE
           MOVE "OK" TO AUD-RESULTADO
           CALL "AUDITORIA" USING AUD-DATOS
           DISPLAY "OK: Ranking generado en "
                   "reports/RANKING_CLIENTES.txt"
           GOBACK.

       P-ENTRADA.
           MOVE "N" TO WS-FIN
           OPEN INPUT CLIENTES CUENTAS
           MOVE ZERO TO CLI-ID
           START CLIENTES KEY IS >= CLI-ID
               INVALID KEY
                   MOVE "S" TO WS-FIN
           END-START
           PERFORM UNTIL WS-FIN = "S"
               READ CLIENTES NEXT RECORD
                   AT END
                       MOVE "S" TO WS-FIN
                   NOT AT END
                       IF CLI-ACTIVO
                           PERFORM P-SALDO-CLIENTE
                           MOVE WS-SALDO TO SRT-SALDO
                           MOVE CLI-ID TO SRT-ID
                           MOVE WS-CANT-CUENTAS TO SRT-CUENTAS
                           MOVE SPACES TO SRT-NOMBRE
                           STRING FUNCTION TRIM(CLI-APELLIDO) ", "
                                  FUNCTION TRIM(CLI-NOMBRE)
                                  DELIMITED BY SIZE INTO SRT-NOMBRE
                           END-STRING
                           RELEASE SRT-REGISTRO
                       END-IF
               END-READ
           END-PERFORM
           CLOSE CLIENTES CUENTAS.

       P-SALDO-CLIENTE.
           MOVE ZERO TO WS-SALDO WS-CANT-CUENTAS
           MOVE "N" TO WS-FIN-CTA
           MOVE CLI-ID TO CTA-ID-CLIENTE
           START CUENTAS KEY IS = CTA-ID-CLIENTE
               INVALID KEY
                   MOVE "S" TO WS-FIN-CTA
           END-START
           PERFORM UNTIL WS-FIN-CTA = "S"
               READ CUENTAS NEXT RECORD
                   AT END
                       MOVE "S" TO WS-FIN-CTA
                   NOT AT END
                       IF CTA-ID-CLIENTE NOT = CLI-ID
                           MOVE "S" TO WS-FIN-CTA
                       ELSE
                           IF NOT CTA-CERRADA
                               ADD CTA-SALDO TO WS-SALDO
                               ADD 1 TO WS-CANT-CUENTAS
                           END-IF
                       END-IF
               END-READ
           END-PERFORM.

       P-SALIDA.
           OPEN OUTPUT REPORTE
           MOVE " RANKING DE CLIENTES POR SALDO TOTAL" TO LIN-REPORTE
           PERFORM P-ESCRIBIR
           MOVE "  POS  CLIENTE  NOMBRE" TO LIN-REPORTE
           MOVE "CTAS            SALDO" TO LIN-REPORTE(56:)
           PERFORM P-ESCRIBIR
           MOVE "N" TO WS-FIN
           PERFORM UNTIL WS-FIN = "S"
               RETURN TRABAJO
                   AT END
                       MOVE "S" TO WS-FIN
                   NOT AT END
                       ADD 1 TO WS-POSICION
                       MOVE WS-POSICION TO WL-POSICION
                       MOVE SRT-ID TO WL-ID
                       MOVE SRT-NOMBRE TO WL-NOMBRE
                       MOVE SRT-CUENTAS TO WL-CUENTAS
                       MOVE SRT-SALDO TO WL-SALDO
                       MOVE WS-LINEA TO LIN-REPORTE
                       PERFORM P-ESCRIBIR
               END-RETURN
           END-PERFORM
           CLOSE REPORTE.

       P-ESCRIBIR.
           WRITE LIN-REPORTE
           DISPLAY FUNCTION TRIM(LIN-REPORTE TRAILING)
           MOVE SPACES TO LIN-REPORTE.
