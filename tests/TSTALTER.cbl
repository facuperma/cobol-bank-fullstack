      *> TSTALTER: herramienta SOLO de pruebas (caso T06).
      *> Suma 100.00 al saldo de una cuenta sin grabar movimiento,
      *> simulando una modificacion manual del archivo.
      *>   tstalter <nro de cuenta>
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TSTALTER.

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
       01 WS-ARG                PIC X(10) VALUE SPACES.

       PROCEDURE DIVISION.
       P-PRINCIPAL.
           ACCEPT WS-ARG FROM ARGUMENT-VALUE
           IF WS-ARG IS NOT NUMERIC
               DISPLAY "Uso: tstalter <cuenta de 10 digitos>"
               MOVE 8 TO RETURN-CODE
               STOP RUN
           END-IF

           OPEN I-O CUENTAS
           MOVE WS-ARG TO CTA-NRO
           READ CUENTAS KEY IS CTA-NRO
               INVALID KEY
                   DISPLAY "Cuenta inexistente"
                   MOVE 8 TO RETURN-CODE
               NOT INVALID KEY
                   ADD 100.00 TO CTA-SALDO
                   REWRITE REG-CUENTA
                   DISPLAY "Saldo alterado: cuenta " CTA-NRO
           END-READ
           CLOSE CUENTAS
           STOP RUN.
