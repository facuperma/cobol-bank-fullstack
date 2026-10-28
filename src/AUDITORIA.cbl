      *> AUDITORIA: agrega una linea al log de auditoria.
      *> El log se abre siempre en EXTEND: nunca se borra ni se
      *> reescribe una linea existente.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. AUDITORIA.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT OPTIONAL AUDITORIA-LOG
               ASSIGN TO "data/AUDITORIA.LOG"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-LOG.

       DATA DIVISION.
       FILE SECTION.
       FD AUDITORIA-LOG.
       01 LIN-LOG               PIC X(120).

       WORKING-STORAGE SECTION.
       01 FS-LOG                PIC XX.
       01 WS-AHORA              PIC X(21).
       01 WS-IMPORTE-ED         PIC 9(9).99.

       LINKAGE SECTION.
       COPY AUD-DATOS.

       PROCEDURE DIVISION USING AUD-DATOS.
       P-PRINCIPAL.
           MOVE FUNCTION CURRENT-DATE TO WS-AHORA
           MOVE AUD-IMPORTE TO WS-IMPORTE-ED

           OPEN EXTEND AUDITORIA-LOG
           IF FS-LOG NOT = "00" AND FS-LOG NOT = "05"
               DISPLAY "ERROR: no se pudo abrir el log (FS="
                       FS-LOG ")"
               GOBACK
           END-IF

           MOVE SPACES TO LIN-LOG
           STRING WS-AHORA(1:8)    " "
                  WS-AHORA(9:6)    " "
                  AUD-USUARIO      " "
                  AUD-OPERACION    " CTA:"
                  AUD-CUENTA       " IMP:"
                  WS-IMPORTE-ED    " "
                  AUD-RESULTADO
                  DELIMITED BY SIZE INTO LIN-LOG
           END-STRING
           WRITE LIN-LOG
           CLOSE AUDITORIA-LOG
           GOBACK.
