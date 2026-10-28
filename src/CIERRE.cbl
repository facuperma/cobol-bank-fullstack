      *> CIERRE (batch): resumen mensual (RA5).
      *> Solo lee: no genera movimientos, por eso correrlo dos
      *> veces da el mismo resultado. Reescribe
      *> reports/CIERRE_<AAAAMM>.txt.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CIERRE IS INITIAL.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           COPY SEL-MOVIM.
           COPY SEL-CLIENTES.
           COPY SEL-CUENTAS.
           SELECT REPORTE ASSIGN TO WS-ARCHIVO
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-REPORTE.

       DATA DIVISION.
       FILE SECTION.
       FD MOVIMIENTOS.
       COPY REG-MOV.
       FD CLIENTES.
       COPY REG-CLIENTE.
       FD CUENTAS.
       COPY REG-CUENTA.
       FD REPORTE.
       01 LIN-REPORTE           PIC X(80).

       WORKING-STORAGE SECTION.
       01 FS-MOVIM              PIC XX.
       01 FS-CLIENTES           PIC XX.
       01 FS-CUENTAS            PIC XX.
       01 FS-REPORTE            PIC XX.
       COPY AUD-DATOS.

       01 WS-ARCHIVO            PIC X(60).
       01 WS-FIN                PIC X.
       01 WS-PERIODO-MOV        PIC 9(6).

       01 WS-TOTALES.
          05 WS-CANT-OPER       PIC 9(9) VALUE 0.
          05 WS-CANT-DEP        PIC 9(9) VALUE 0.
          05 WS-CANT-RET        PIC 9(9) VALUE 0.
          05 WS-CANT-TRF        PIC 9(9) VALUE 0.
          05 WS-CANT-INT        PIC 9(9) VALUE 0.
          05 WS-TOT-DEP         PIC S9(13)V99 COMP-3 VALUE 0.
          05 WS-TOT-RET         PIC S9(13)V99 COMP-3 VALUE 0.
          05 WS-TOT-TRF         PIC S9(13)V99 COMP-3 VALUE 0.
          05 WS-TOT-INT         PIC S9(13)V99 COMP-3 VALUE 0.
          05 WS-CLI-ACTIVOS     PIC 9(9) VALUE 0.
          05 WS-CLI-INACTIVOS   PIC 9(9) VALUE 0.
          05 WS-CTA-ABIERTAS    PIC 9(9) VALUE 0.
          05 WS-CTA-BLOQUEADAS  PIC 9(9) VALUE 0.
          05 WS-CTA-CERRADAS    PIC 9(9) VALUE 0.
          05 WS-CARTERA         PIC S9(15)V99 COMP-3 VALUE 0.

       01 WS-LINEA.
          05 WL-ETIQUETA        PIC X(34).
          05 WL-CANT            PIC ZZZ,ZZZ,ZZ9.
          05 FILLER             PIC X(3) VALUE SPACES.
          05 WL-IMPORTE         PIC -ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99.

       01 WS-SEPARADOR          PIC X(80) VALUE ALL "=".
       01 WS-HOY                PIC 9(8).
       01 WS-ED-FECHA           PIC 9999/99/99.

       LINKAGE SECTION.
       COPY BATCH-PARAMS.

       PROCEDURE DIVISION USING BATCH-PARAMS.
       P-PRINCIPAL.
           MOVE 0 TO BAT-RC
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-HOY
           PERFORM P-LEER-MOVIMIENTOS
           PERFORM P-LEER-CLIENTES
           PERFORM P-LEER-CUENTAS

           MOVE SPACES TO WS-ARCHIVO
           STRING "reports/CIERRE_" BAT-PERIODO ".txt"
               DELIMITED BY SIZE INTO WS-ARCHIVO
           END-STRING
           OPEN OUTPUT REPORTE
           IF FS-REPORTE NOT = "00"
               DISPLAY "ERROR: No se pudo crear " WS-ARCHIVO
               MOVE 2 TO BAT-RC
               GOBACK
           END-IF
           PERFORM P-INFORME
           CLOSE REPORTE

           MOVE BAT-USUARIO TO AUD-USUARIO
           MOVE "CIERRE" TO AUD-OPERACION
           MOVE ZERO TO AUD-CUENTA
           MOVE WS-TOT-DEP TO AUD-IMPORTE
           MOVE SPACES TO AUD-RESULTADO
           STRING "OK PERIODO " BAT-PERIODO
               DELIMITED BY SIZE INTO AUD-RESULTADO
           END-STRING
           CALL "AUDITORIA" USING AUD-DATOS
           DISPLAY "OK: Cierre generado en " FUNCTION TRIM(WS-ARCHIVO)
           GOBACK.

       P-LEER-MOVIMIENTOS.
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
                       DIVIDE MOV-FECHA BY 100 GIVING WS-PERIODO-MOV
                       IF WS-PERIODO-MOV = BAT-PERIODO
                           PERFORM P-ACUMULAR-MOV
                       END-IF
               END-READ
           END-PERFORM
           IF FS-MOVIM NOT = "35"
               CLOSE MOVIMIENTOS
           END-IF.

      *> Una transferencia cuenta como una operacion (se toma el
      *> debito; el credito es la otra mitad).
       P-ACUMULAR-MOV.
           EVALUATE TRUE
               WHEN MOV-DEPOSITO
                   ADD 1 TO WS-CANT-DEP WS-CANT-OPER
                   ADD MOV-IMPORTE TO WS-TOT-DEP
               WHEN MOV-RETIRO
                   ADD 1 TO WS-CANT-RET WS-CANT-OPER
                   ADD MOV-IMPORTE TO WS-TOT-RET
               WHEN MOV-TRANSF-DEB
                   ADD 1 TO WS-CANT-TRF WS-CANT-OPER
                   ADD MOV-IMPORTE TO WS-TOT-TRF
               WHEN MOV-INTERES
                   ADD 1 TO WS-CANT-INT WS-CANT-OPER
                   ADD MOV-IMPORTE TO WS-TOT-INT
           END-EVALUATE.

       P-LEER-CLIENTES.
           MOVE "N" TO WS-FIN
           OPEN INPUT CLIENTES
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
                           ADD 1 TO WS-CLI-ACTIVOS
                       ELSE
                           ADD 1 TO WS-CLI-INACTIVOS
                       END-IF
               END-READ
           END-PERFORM
           CLOSE CLIENTES.

       P-LEER-CUENTAS.
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
                       EVALUATE TRUE
                           WHEN CTA-ABIERTA
                               ADD 1 TO WS-CTA-ABIERTAS
                           WHEN CTA-BLOQUEADA
                               ADD 1 TO WS-CTA-BLOQUEADAS
                           WHEN OTHER
                               ADD 1 TO WS-CTA-CERRADAS
                       END-EVALUATE
                       ADD CTA-SALDO TO WS-CARTERA
               END-READ
           END-PERFORM
           CLOSE CUENTAS.

       P-INFORME.
           MOVE WS-HOY TO WS-ED-FECHA
           MOVE WS-SEPARADOR TO LIN-REPORTE
           PERFORM P-ESCRIBIR
           STRING " CIERRE MENSUAL - PERIODO " BAT-PERIODO
                  "        Emitido: " WS-ED-FECHA
                  DELIMITED BY SIZE INTO LIN-REPORTE
           END-STRING
           PERFORM P-ESCRIBIR
           MOVE WS-SEPARADOR TO LIN-REPORTE
           PERFORM P-ESCRIBIR
           MOVE " CONCEPTO                           CANTIDAD"
               TO LIN-REPORTE
           MOVE "IMPORTE" TO LIN-REPORTE(67:)
           PERFORM P-ESCRIBIR

           MOVE " Depositos" TO WL-ETIQUETA
           MOVE WS-CANT-DEP TO WL-CANT
           MOVE WS-TOT-DEP TO WL-IMPORTE
           PERFORM P-ESCRIBIR-LINEA
           MOVE " Retiros" TO WL-ETIQUETA
           MOVE WS-CANT-RET TO WL-CANT
           MOVE WS-TOT-RET TO WL-IMPORTE
           PERFORM P-ESCRIBIR-LINEA
           MOVE " Transferencias" TO WL-ETIQUETA
           MOVE WS-CANT-TRF TO WL-CANT
           MOVE WS-TOT-TRF TO WL-IMPORTE
           PERFORM P-ESCRIBIR-LINEA
           MOVE " Intereses acreditados" TO WL-ETIQUETA
           MOVE WS-CANT-INT TO WL-CANT
           MOVE WS-TOT-INT TO WL-IMPORTE
           PERFORM P-ESCRIBIR-LINEA
           MOVE " Total de operaciones" TO WL-ETIQUETA
           MOVE WS-CANT-OPER TO WL-CANT
           MOVE ZERO TO WL-IMPORTE
           PERFORM P-ESCRIBIR-LINEA

           MOVE WS-SEPARADOR TO LIN-REPORTE
           PERFORM P-ESCRIBIR
           MOVE " Clientes activos" TO WL-ETIQUETA
           MOVE WS-CLI-ACTIVOS TO WL-CANT
           PERFORM P-ESCRIBIR-CANTIDAD
           MOVE " Clientes dados de baja" TO WL-ETIQUETA
           MOVE WS-CLI-INACTIVOS TO WL-CANT
           PERFORM P-ESCRIBIR-CANTIDAD
           MOVE " Cuentas abiertas" TO WL-ETIQUETA
           MOVE WS-CTA-ABIERTAS TO WL-CANT
           PERFORM P-ESCRIBIR-CANTIDAD
           MOVE " Cuentas bloqueadas" TO WL-ETIQUETA
           MOVE WS-CTA-BLOQUEADAS TO WL-CANT
           PERFORM P-ESCRIBIR-CANTIDAD
           MOVE " Cuentas cerradas" TO WL-ETIQUETA
           MOVE WS-CTA-CERRADAS TO WL-CANT
           PERFORM P-ESCRIBIR-CANTIDAD
           MOVE " Saldo total de cartera" TO WL-ETIQUETA
           MOVE ZERO TO WL-CANT
           MOVE WS-CARTERA TO WL-IMPORTE
           MOVE WS-LINEA TO LIN-REPORTE
           MOVE SPACES TO LIN-REPORTE(35:11)
           PERFORM P-ESCRIBIR
           MOVE WS-SEPARADOR TO LIN-REPORTE
           PERFORM P-ESCRIBIR.

       P-ESCRIBIR-LINEA.
           MOVE WS-LINEA TO LIN-REPORTE
           PERFORM P-ESCRIBIR.

       P-ESCRIBIR-CANTIDAD.
           MOVE WS-LINEA TO LIN-REPORTE
           MOVE SPACES TO LIN-REPORTE(46:)
           PERFORM P-ESCRIBIR.

       P-ESCRIBIR.
           WRITE LIN-REPORTE
           DISPLAY FUNCTION TRIM(LIN-REPORTE TRAILING)
           MOVE SPACES TO LIN-REPORTE.
