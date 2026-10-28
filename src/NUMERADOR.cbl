      *> NUMERADOR: devuelve el siguiente numero de una secuencia
      *> (CLI, CTA, MOV, OPE) guardada en CONTROL.DAT.
      *> Si hay un error devuelve cero.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. NUMERADOR.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           COPY SEL-CONTROL.

       DATA DIVISION.
       FILE SECTION.
       FD CONTROL-F.
       COPY REG-CONTROL.

       WORKING-STORAGE SECTION.
       01 FS-CONTROL            PIC XX.
       01 WS-EXISTE             PIC X.

       LINKAGE SECTION.
       01 LK-CLAVE              PIC X(3).
       01 LK-VALOR              PIC 9(12).

       PROCEDURE DIVISION USING LK-CLAVE LK-VALOR.
       P-PRINCIPAL.
           MOVE ZERO TO LK-VALOR
           OPEN I-O CONTROL-F
           IF FS-CONTROL NOT = "00" AND FS-CONTROL NOT = "05"
               DISPLAY "ERROR: CONTROL.DAT FS=" FS-CONTROL
               GOBACK
           END-IF

           MOVE LK-CLAVE TO CTL-CLAVE
           MOVE "S" TO WS-EXISTE
           READ CONTROL-F KEY IS CTL-CLAVE
               INVALID KEY
                   MOVE "N" TO WS-EXISTE
                   MOVE LK-CLAVE TO CTL-CLAVE
                   PERFORM P-VALOR-INICIAL
           END-READ

           ADD 1 TO CTL-VALOR
           IF WS-EXISTE = "S"
               REWRITE REG-CONTROL
           ELSE
               WRITE REG-CONTROL
           END-IF

           IF FS-CONTROL = "00"
               MOVE CTL-VALOR TO LK-VALOR
           ELSE
               DISPLAY "ERROR: no se pudo actualizar CONTROL.DAT"
                       " FS=" FS-CONTROL
           END-IF
           CLOSE CONTROL-F
           GOBACK.

       P-VALOR-INICIAL.
           EVALUATE LK-CLAVE
               WHEN "CTA"
                   MOVE 1000000000 TO CTL-VALOR
               WHEN OTHER
                   MOVE ZERO TO CTL-VALOR
           END-EVALUATE.
