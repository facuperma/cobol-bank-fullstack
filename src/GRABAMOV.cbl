      *> GRABAMOV: agrega un movimiento a MOVIMIENTOS.DAT con
      *> numero, fecha y hora asignados aca.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. GRABAMOV.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           COPY SEL-MOVIM.

       DATA DIVISION.
       FILE SECTION.
       FD MOVIMIENTOS.
       COPY REG-MOV.

       WORKING-STORAGE SECTION.
       01 FS-MOVIM              PIC XX.
       01 WS-AHORA              PIC X(21).
       01 WS-CLAVE              PIC X(3) VALUE "MOV".

       LINKAGE SECTION.
       COPY MOV-PARAMS.

       PROCEDURE DIVISION USING MOVP.
       P-PRINCIPAL.
           MOVE ZERO TO MOVP-ID
           CALL "NUMERADOR" USING WS-CLAVE MOVP-ID
           IF MOVP-ID = ZERO
               GOBACK
           END-IF

           OPEN EXTEND MOVIMIENTOS
           IF FS-MOVIM NOT = "00" AND FS-MOVIM NOT = "05"
               DISPLAY "ERROR: MOVIMIENTOS.DAT FS=" FS-MOVIM
               MOVE ZERO TO MOVP-ID
               GOBACK
           END-IF

           MOVE FUNCTION CURRENT-DATE TO WS-AHORA
           MOVE MOVP-ID           TO MOV-ID
           MOVE MOVP-OPERACION    TO MOV-OPERACION
           MOVE MOVP-CUENTA       TO MOV-NRO-CUENTA
           MOVE WS-AHORA(1:8)     TO MOV-FECHA
           MOVE WS-AHORA(9:6)     TO MOV-HORA
           MOVE MOVP-TIPO         TO MOV-TIPO
           MOVE MOVP-IMPORTE      TO MOV-IMPORTE
           MOVE MOVP-SALDO        TO MOV-SALDO-POST
           MOVE MOVP-DESC         TO MOV-DESCRIPCION
           WRITE REG-MOV
           IF FS-MOVIM NOT = "00"
               DISPLAY "ERROR: no se grabo el movimiento FS="
                       FS-MOVIM
               MOVE ZERO TO MOVP-ID
           END-IF
           CLOSE MOVIMIENTOS
           GOBACK.
