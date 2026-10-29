      *> EXTRACTO: movimientos de una cuenta en un periodo, en
      *> pantalla y en reports/EXTRACTO_<cuenta>.txt (RF9).
       IDENTIFICATION DIVISION.
       PROGRAM-ID. EXTRACTO IS INITIAL.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           COPY SEL-CUENTAS.
           COPY SEL-CLIENTES.
           COPY SEL-MOVIM.
           SELECT REPORTE ASSIGN TO WS-ARCHIVO
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-REPORTE.

       DATA DIVISION.
       FILE SECTION.
       FD CUENTAS.
       COPY REG-CUENTA.
       FD CLIENTES.
       COPY REG-CLIENTE.
       FD MOVIMIENTOS.
       COPY REG-MOV.
       FD REPORTE.
       01 LIN-REPORTE           PIC X(100).

       WORKING-STORAGE SECTION.
       01 FS-CUENTAS            PIC XX.
       01 FS-CLIENTES           PIC XX.
       01 FS-MOVIM              PIC XX.
       01 FS-REPORTE            PIC XX.
       COPY AUD-DATOS.
       COPY MODO.

       01 WS-ARCHIVO            PIC X(60).
       01 WS-PROMPT             PIC X(40).
       01 WS-MAX                PIC 99.
       01 WS-NUMERO             PIC 9(12).
       01 WS-OK                 PIC X.
       01 WS-CTA                PIC 9(10).
       01 WS-DESDE              PIC 9(8).
       01 WS-HASTA              PIC 9(8).
       01 WS-HOY                PIC 9(8).
       01 WS-TITULAR            PIC X(62).
       01 WS-FIN                PIC X.
       01 WS-CANTIDAD           PIC 9(6).
       01 WS-SALDO-INICIAL      PIC S9(11)V99 COMP-3.
       01 WS-SALDO-FINAL        PIC S9(11)V99 COMP-3.
       01 WS-CREDITOS           PIC S9(13)V99 COMP-3.
       01 WS-DEBITOS            PIC S9(13)V99 COMP-3.

       01 WS-LINEA-MOV.
          05 FILLER             PIC X VALUE SPACE.
          05 LM-FECHA           PIC 9999/99/99.
          05 FILLER             PIC X VALUE SPACE.
          05 LM-HORA            PIC 99B99B99.
          05 FILLER             PIC X(2) VALUE SPACES.
          05 LM-TIPO            PIC X(13).
          05 LM-SIGNO           PIC X.
          05 LM-IMPORTE         PIC ZZ,ZZZ,ZZ9.99.
          05 FILLER             PIC X(2) VALUE SPACES.
          05 LM-SALDO           PIC -ZZ,ZZZ,ZZ9.99.
          05 FILLER             PIC X(2) VALUE SPACES.
          05 LM-DESC            PIC X(30).

       01 WS-ED-FECHA1          PIC 9999/99/99.
       01 WS-ED-FECHA2          PIC 9999/99/99.
       01 WS-ED-IMPORTE         PIC -ZZ,ZZZ,ZZZ,ZZ9.99.
       01 WS-ED-CANT            PIC ZZZZZ9.
       01 WS-SRV-IMP1           PIC -(11)9.99.
       01 WS-SRV-IMP2           PIC -(11)9.99.
       01 WS-SRV-IMP3           PIC -(11)9.99.
       01 WS-SRV-IMP4           PIC -(11)9.99.
       01 WS-SEPARADOR          PIC X(100) VALUE ALL "=".

       LINKAGE SECTION.
       COPY SESION.

       PROCEDURE DIVISION USING SESION.
       P-PRINCIPAL.
           MOVE SES-USUARIO TO AUD-USUARIO
           MOVE ZERO TO AUD-IMPORTE
           MOVE "EXTRACTO" TO AUD-OPERACION
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-HOY

           MOVE "Numero de cuenta" TO WS-PROMPT
           MOVE 10 TO WS-MAX
           CALL "PEDIRNUM" USING WS-PROMPT WS-MAX WS-NUMERO WS-OK
           IF WS-OK = "N"
               GOBACK
           END-IF
           MOVE WS-NUMERO TO WS-CTA

           MOVE "Desde (AAAAMMDD)" TO WS-PROMPT
           PERFORM P-PEDIR-FECHA
           IF WS-OK = "N"
               GOBACK
           END-IF
           MOVE WS-NUMERO TO WS-DESDE
           MOVE "Hasta (AAAAMMDD)" TO WS-PROMPT
           PERFORM P-PEDIR-FECHA
           IF WS-OK = "N"
               GOBACK
           END-IF
           MOVE WS-NUMERO TO WS-HASTA
           IF WS-DESDE > WS-HASTA
               DISPLAY "ERROR: La fecha desde es posterior a hasta"
               GOBACK
           END-IF

           PERFORM P-LEER-CUENTA
           IF WS-OK = "N"
               GOBACK
           END-IF

           MOVE SPACES TO WS-ARCHIVO
           STRING "reports/EXTRACTO_" WS-CTA ".txt"
               DELIMITED BY SIZE INTO WS-ARCHIVO
           END-STRING
           OPEN OUTPUT REPORTE
           IF FS-REPORTE NOT = "00"
               DISPLAY "ERROR: No se pudo crear " WS-ARCHIVO
               GOBACK
           END-IF

           PERFORM P-ENCABEZADO
           PERFORM P-MOVIMIENTOS
           PERFORM P-TOTALES
           CLOSE REPORTE

           MOVE WS-CTA TO AUD-CUENTA
           MOVE "OK" TO AUD-RESULTADO
           CALL "AUDITORIA" USING AUD-DATOS
           DISPLAY "OK: Extracto generado en "
                   FUNCTION TRIM(WS-ARCHIVO)
           GOBACK.

       P-PEDIR-FECHA.
           MOVE 8 TO WS-MAX
           CALL "PEDIRNUM" USING WS-PROMPT WS-MAX WS-NUMERO WS-OK
           IF WS-OK = "S"
               IF FUNCTION TEST-DATE-YYYYMMDD(WS-NUMERO) NOT = 0
                   DISPLAY "ERROR: Fecha invalida"
                   MOVE "N" TO WS-OK
               END-IF
           END-IF.

       P-LEER-CUENTA.
           OPEN INPUT CUENTAS
           MOVE WS-CTA TO CTA-NRO
           READ CUENTAS KEY IS CTA-NRO
               INVALID KEY
                   MOVE "N" TO WS-OK
                   DISPLAY "ERROR: Cuenta inexistente"
           END-READ
           IF WS-OK = "S"
               OPEN INPUT CLIENTES
               MOVE CTA-ID-CLIENTE TO CLI-ID
               READ CLIENTES KEY IS CLI-ID
                   INVALID KEY
                       MOVE "(titular no encontrado)" TO WS-TITULAR
                   NOT INVALID KEY
                       MOVE SPACES TO WS-TITULAR
                       STRING FUNCTION TRIM(CLI-APELLIDO) ", "
                              FUNCTION TRIM(CLI-NOMBRE)
                              DELIMITED BY SIZE INTO WS-TITULAR
                       END-STRING
               END-READ
               CLOSE CLIENTES
           END-IF
           CLOSE CUENTAS.

       P-ENCABEZADO.
           MOVE WS-DESDE TO WS-ED-FECHA1
           MOVE WS-HASTA TO WS-ED-FECHA2
           MOVE WS-SEPARADOR TO LIN-REPORTE
           PERFORM P-ESCRIBIR
           MOVE SPACES TO LIN-REPORTE
           STRING " EXTRACTO DE CUENTA " WS-CTA
                  "   Titular: " WS-TITULAR
                  DELIMITED BY SIZE INTO LIN-REPORTE
           END-STRING
           PERFORM P-ESCRIBIR
           MOVE SPACES TO LIN-REPORTE
           STRING " Periodo: " WS-ED-FECHA1 " al " WS-ED-FECHA2
                  DELIMITED BY SIZE INTO LIN-REPORTE
           END-STRING
           PERFORM P-ESCRIBIR
           MOVE WS-SEPARADOR TO LIN-REPORTE
           PERFORM P-ESCRIBIR
           MOVE " FECHA      HORA      TIPO                IMPORTE"
               TO LIN-REPORTE
           MOVE "SALDO  DETALLE" TO LIN-REPORTE(57:)
           PERFORM P-ESCRIBIR.

      *> Recorre todos los movimientos: los anteriores al periodo
      *> dan el saldo inicial, los del periodo se listan.
       P-MOVIMIENTOS.
           MOVE ZERO TO WS-SALDO-INICIAL WS-CREDITOS WS-DEBITOS
                        WS-CANTIDAD
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
                       IF MOV-NRO-CUENTA = WS-CTA
                           PERFORM P-PROCESAR-MOV
                       END-IF
               END-READ
           END-PERFORM
           IF FS-MOVIM NOT = "35"
               CLOSE MOVIMIENTOS
           END-IF
           IF WS-CANTIDAD = 0
               MOVE WS-SALDO-INICIAL TO WS-SALDO-FINAL
               MOVE "   (sin movimientos en el periodo)"
                   TO LIN-REPORTE
               PERFORM P-ESCRIBIR
           END-IF.

       P-PROCESAR-MOV.
           EVALUATE TRUE
               WHEN MOV-FECHA < WS-DESDE
                   MOVE MOV-SALDO-POST TO WS-SALDO-INICIAL
               WHEN MOV-FECHA > WS-HASTA
                   CONTINUE
               WHEN OTHER
                   ADD 1 TO WS-CANTIDAD
                   MOVE MOV-SALDO-POST TO WS-SALDO-FINAL
                   IF MOV-SUMA
                       ADD MOV-IMPORTE TO WS-CREDITOS
                       MOVE "+" TO LM-SIGNO
                   ELSE
                       ADD MOV-IMPORTE TO WS-DEBITOS
                       MOVE "-" TO LM-SIGNO
                   END-IF
                   MOVE MOV-FECHA TO LM-FECHA
                   MOVE MOV-HORA TO LM-HORA
                   INSPECT LM-HORA REPLACING ALL " " BY ":"
                   EVALUATE TRUE
                       WHEN MOV-DEPOSITO   MOVE "DEPOSITO" TO LM-TIPO
                       WHEN MOV-RETIRO     MOVE "RETIRO" TO LM-TIPO
                       WHEN MOV-TRANSF-DEB MOVE "TRANSF. DEB" TO LM-TIPO
                       WHEN MOV-TRANSF-CRE MOVE "TRANSF. CRED"
                                               TO LM-TIPO
                       WHEN MOV-INTERES    MOVE "INTERES" TO LM-TIPO
                       WHEN OTHER          MOVE MOV-TIPO TO LM-TIPO
                   END-EVALUATE
                   MOVE MOV-IMPORTE TO LM-IMPORTE
                   MOVE MOV-SALDO-POST TO LM-SALDO
                   MOVE MOV-DESCRIPCION TO LM-DESC
                   MOVE WS-LINEA-MOV TO LIN-REPORTE
                   PERFORM P-ESCRIBIR
                   IF MODO-SERVICIO
                       MOVE MOV-IMPORTE TO WS-SRV-IMP1
                       MOVE MOV-SALDO-POST TO WS-SRV-IMP2
                       DISPLAY "@MOV|" MOV-FECHA "|" MOV-HORA "|"
                               MOV-TIPO "|" FUNCTION TRIM(WS-SRV-IMP1)
                               "|" FUNCTION TRIM(WS-SRV-IMP2) "|"
                               MOV-OPERACION "|"
                               FUNCTION TRIM(MOV-DESCRIPCION)
                   END-IF
           END-EVALUATE.

       P-TOTALES.
           MOVE WS-SEPARADOR TO LIN-REPORTE
           PERFORM P-ESCRIBIR
           MOVE WS-CANTIDAD TO WS-ED-CANT
           MOVE SPACES TO LIN-REPORTE
           STRING " Movimientos      : " WS-ED-CANT
               DELIMITED BY SIZE INTO LIN-REPORTE
           END-STRING
           PERFORM P-ESCRIBIR
           MOVE WS-SALDO-INICIAL TO WS-ED-IMPORTE
           MOVE SPACES TO LIN-REPORTE
           STRING " Saldo inicial    : " WS-ED-IMPORTE
               DELIMITED BY SIZE INTO LIN-REPORTE
           END-STRING
           PERFORM P-ESCRIBIR
           MOVE WS-CREDITOS TO WS-ED-IMPORTE
           MOVE SPACES TO LIN-REPORTE
           STRING " Total creditos   : " WS-ED-IMPORTE
               DELIMITED BY SIZE INTO LIN-REPORTE
           END-STRING
           PERFORM P-ESCRIBIR
           MOVE WS-DEBITOS TO WS-ED-IMPORTE
           MOVE SPACES TO LIN-REPORTE
           STRING " Total debitos    : " WS-ED-IMPORTE
               DELIMITED BY SIZE INTO LIN-REPORTE
           END-STRING
           PERFORM P-ESCRIBIR
           MOVE WS-SALDO-FINAL TO WS-ED-IMPORTE
           MOVE SPACES TO LIN-REPORTE
           STRING " Saldo final      : " WS-ED-IMPORTE
               DELIMITED BY SIZE INTO LIN-REPORTE
           END-STRING
           PERFORM P-ESCRIBIR
           MOVE WS-SEPARADOR TO LIN-REPORTE
           PERFORM P-ESCRIBIR
           IF MODO-SERVICIO
               MOVE WS-SALDO-INICIAL TO WS-SRV-IMP1
               MOVE WS-CREDITOS TO WS-SRV-IMP2
               MOVE WS-DEBITOS TO WS-SRV-IMP3
               MOVE WS-SALDO-FINAL TO WS-SRV-IMP4
               DISPLAY "@TOTALES|" WS-CTA "|" FUNCTION TRIM(WS-TITULAR)
                       "|" WS-CANTIDAD
                       "|" FUNCTION TRIM(WS-SRV-IMP1)
                       "|" FUNCTION TRIM(WS-SRV-IMP2)
                       "|" FUNCTION TRIM(WS-SRV-IMP3)
                       "|" FUNCTION TRIM(WS-SRV-IMP4)
           END-IF.

      *> Cada linea va al archivo y a la pantalla (en modo servicio
      *> la pantalla recibe las lineas de datos en su lugar).
       P-ESCRIBIR.
           WRITE LIN-REPORTE
           IF NOT MODO-SERVICIO
               DISPLAY FUNCTION TRIM(LIN-REPORTE TRAILING)
           END-IF
           MOVE SPACES TO LIN-REPORTE.
