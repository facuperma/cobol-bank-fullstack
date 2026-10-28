      *> CUENTAS: apertura, consulta de saldo, validacion de PIN y
      *> desbloqueo de cuentas.
      *>   LK-OPCION "AP" apertura (interactivo)
      *>             "CO" consulta de saldo (interactivo, pide PIN)
      *>             "PI" valida LK-PIN de LK-CUENTA (no interactivo)
      *>             "DB" desbloqueo (interactivo, solo supervisor)
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUENTAS IS INITIAL.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           COPY SEL-CUENTAS.
           COPY SEL-CLIENTES.

       DATA DIVISION.
       FILE SECTION.
       FD CUENTAS.
       COPY REG-CUENTA.
       FD CLIENTES.
       COPY REG-CLIENTE.

       WORKING-STORAGE SECTION.
       01 FS-CUENTAS            PIC XX.
       01 FS-CLIENTES           PIC XX.
       COPY PARAMETROS.
       COPY AUD-DATOS.
       COPY MOV-PARAMS.

       01 WS-PROMPT             PIC X(40).
       01 WS-MAX                PIC 99.
       01 WS-NUMERO             PIC 9(12).
       01 WS-CERO               PIC X.
       01 WS-OK                 PIC X.
       01 WS-MENSAJE            PIC X(40).
       01 WS-ENTRADA            PIC X(20).
       01 WS-CTA                PIC 9(10).
       01 WS-ID-CLIENTE         PIC 9(6).
       01 WS-PIN                PIC X(4).
       01 WS-PIN2               PIC X(4).
       01 WS-TIPO               PIC X.
       01 WS-IMPORTE            PIC S9(11)V99 COMP-3.
       01 WS-CLAVE-HASH         PIC X(30).
       01 WS-HASH               PIC 9(8).
       01 WS-SECUENCIA          PIC X(3).
       01 WS-SALDO-ED           PIC -ZZ,ZZZ,ZZZ,ZZ9.99.
       01 WS-INTENTO-ED         PIC 9.

       LINKAGE SECTION.
       COPY SESION.
       01 LK-OPCION             PIC XX.
       01 LK-CUENTA             PIC 9(10).
       01 LK-PIN                PIC X(4).
       01 LK-OK                 PIC X.
       01 LK-MENSAJE            PIC X(40).

       PROCEDURE DIVISION USING SESION LK-OPCION LK-CUENTA LK-PIN
                                LK-OK LK-MENSAJE.
       P-PRINCIPAL.
           MOVE "N" TO LK-OK
           MOVE SPACES TO LK-MENSAJE
           MOVE SES-USUARIO TO AUD-USUARIO
           MOVE ZERO TO AUD-IMPORTE

           EVALUATE LK-OPCION
               WHEN "AP"
                   PERFORM P-APERTURA
               WHEN "CO"
                   PERFORM P-CONSULTA
               WHEN "PI"
                   MOVE LK-CUENTA TO WS-CTA
                   MOVE LK-PIN TO WS-PIN
                   PERFORM P-VALIDAR-PIN
                   MOVE WS-OK TO LK-OK
                   MOVE WS-MENSAJE TO LK-MENSAJE
               WHEN "DB"
                   PERFORM P-DESBLOQUEO
           END-EVALUATE
           GOBACK.

      *> ---------------------------------------------------------
      *> Apertura de cuenta (RF4)
      *> ---------------------------------------------------------
       P-APERTURA.
           MOVE "ID de cliente" TO WS-PROMPT
           MOVE 6 TO WS-MAX
           CALL "PEDIRNUM" USING WS-PROMPT WS-MAX WS-NUMERO WS-OK
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF

           OPEN INPUT CLIENTES
           MOVE WS-NUMERO TO CLI-ID
           READ CLIENTES KEY IS CLI-ID
               INVALID KEY
                   MOVE "N" TO WS-OK
                   DISPLAY "ERROR: Cliente inexistente"
               NOT INVALID KEY
                   IF NOT CLI-ACTIVO
                       MOVE "N" TO WS-OK
                       DISPLAY "ERROR: Cliente dado de baja"
                   END-IF
           END-READ
           CLOSE CLIENTES
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF
           MOVE WS-NUMERO TO WS-ID-CLIENTE

           DISPLAY "Tipo (A = caja de ahorro, C = cuenta corriente): "
               WITH NO ADVANCING
           MOVE SPACES TO WS-ENTRADA
           ACCEPT WS-ENTRADA
           MOVE FUNCTION UPPER-CASE(WS-ENTRADA(1:1)) TO WS-TIPO
           IF WS-TIPO NOT = "A" AND WS-TIPO NOT = "C"
               DISPLAY "ERROR: Tipo de cuenta invalido"
               EXIT PARAGRAPH
           END-IF

           DISPLAY "PIN (4 digitos): " WITH NO ADVANCING
           PERFORM P-ACEPTAR-PIN
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF
           MOVE WS-PIN TO WS-PIN2
           DISPLAY "Repetir PIN: " WITH NO ADVANCING
           PERFORM P-ACEPTAR-PIN
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF
           IF WS-PIN NOT = WS-PIN2
               DISPLAY "ERROR: Los PIN no coinciden"
               EXIT PARAGRAPH
           END-IF

           MOVE "Deposito inicial (0 = sin deposito)" TO WS-PROMPT
           MOVE "S" TO WS-CERO
           CALL "PEDIRIMP" USING WS-PROMPT WS-CERO WS-IMPORTE WS-OK
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF

           MOVE "CTA" TO WS-SECUENCIA
           CALL "NUMERADOR" USING WS-SECUENCIA WS-NUMERO
           IF WS-NUMERO = ZERO
               DISPLAY "ERROR: No se pudo numerar la cuenta"
               EXIT PARAGRAPH
           END-IF

           MOVE WS-NUMERO TO WS-CTA
           OPEN I-O CUENTAS
           INITIALIZE REG-CUENTA
           MOVE WS-CTA            TO CTA-NRO
           MOVE WS-ID-CLIENTE     TO CTA-ID-CLIENTE
           MOVE WS-TIPO           TO CTA-TIPO
           MOVE WS-IMPORTE        TO CTA-SALDO
           PERFORM P-HASH-PIN
           MOVE WS-HASH           TO CTA-PIN-HASH
           MOVE ZERO              TO CTA-INTENTOS
           SET CTA-ABIERTA        TO TRUE
           MOVE ZERO              TO CTA-RETIRADO-HOY
           MOVE ZERO              TO CTA-FECHA-HOY
           MOVE ZERO              TO CTA-ULT-INTERES
           WRITE REG-CUENTA
           IF FS-CUENTAS NOT = "00"
               DISPLAY "ERROR: No se pudo grabar la cuenta FS="
                       FS-CUENTAS
               CLOSE CUENTAS
               EXIT PARAGRAPH
           END-IF
           CLOSE CUENTAS

      *>   El deposito inicial queda como movimiento para que la
      *>   reconciliacion cierre: saldo = suma de movimientos.
           IF WS-IMPORTE > 0
               MOVE "OPE" TO WS-SECUENCIA
               CALL "NUMERADOR" USING WS-SECUENCIA MOVP-OPERACION
               MOVE WS-CTA          TO MOVP-CUENTA
               MOVE "DE"            TO MOVP-TIPO
               MOVE WS-IMPORTE      TO MOVP-IMPORTE
               MOVE WS-IMPORTE      TO MOVP-SALDO
               MOVE "Deposito inicial" TO MOVP-DESC
               CALL "GRABAMOV" USING MOVP
           END-IF

           MOVE "APERTURA" TO AUD-OPERACION
           MOVE WS-CTA TO AUD-CUENTA
           MOVE WS-IMPORTE TO AUD-IMPORTE
           MOVE "OK" TO AUD-RESULTADO
           CALL "AUDITORIA" USING AUD-DATOS

           DISPLAY "OK: Cuenta " WS-CTA " abierta".

      *> ---------------------------------------------------------
      *> Consulta de saldo (RF8)
      *> ---------------------------------------------------------
       P-CONSULTA.
           MOVE "Numero de cuenta" TO WS-PROMPT
           MOVE 10 TO WS-MAX
           CALL "PEDIRNUM" USING WS-PROMPT WS-MAX WS-NUMERO WS-OK
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF
           MOVE WS-NUMERO TO WS-CTA

           DISPLAY "PIN: " WITH NO ADVANCING
           PERFORM P-ACEPTAR-PIN
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF

           PERFORM P-VALIDAR-PIN
           IF WS-OK = "N"
               DISPLAY "ERROR: " FUNCTION TRIM(WS-MENSAJE)
               EXIT PARAGRAPH
           END-IF

           OPEN INPUT CUENTAS
           MOVE WS-CTA TO CTA-NRO
           READ CUENTAS KEY IS CTA-NRO
               INVALID KEY
                   MOVE "N" TO WS-OK
           END-READ
           IF WS-OK = "N"
               CLOSE CUENTAS
               DISPLAY "ERROR: Cuenta inexistente"
               EXIT PARAGRAPH
           END-IF

           OPEN INPUT CLIENTES
           MOVE CTA-ID-CLIENTE TO CLI-ID
           READ CLIENTES KEY IS CLI-ID
               INVALID KEY
                   MOVE SPACES TO CLI-NOMBRE CLI-APELLIDO
           END-READ

           MOVE CTA-SALDO TO WS-SALDO-ED
           DISPLAY "------------------------------------------"
           DISPLAY " Cuenta  : " CTA-NRO
           IF CTA-AHORRO
               DISPLAY " Tipo    : Caja de ahorro"
           ELSE
               DISPLAY " Tipo    : Cuenta corriente"
           END-IF
           DISPLAY " Titular : " FUNCTION TRIM(CLI-APELLIDO) ", "
                   FUNCTION TRIM(CLI-NOMBRE)
           DISPLAY " Saldo   : " WS-SALDO-ED
           DISPLAY "------------------------------------------"
           CLOSE CUENTAS CLIENTES

           MOVE "CONSULTA" TO AUD-OPERACION
           MOVE WS-CTA TO AUD-CUENTA
           MOVE "OK" TO AUD-RESULTADO
           CALL "AUDITORIA" USING AUD-DATOS.

      *> ---------------------------------------------------------
      *> Desbloqueo manual (RA2 / RA9: solo supervisor)
      *> ---------------------------------------------------------
       P-DESBLOQUEO.
           IF NOT SES-SUPERVISOR
               DISPLAY "ERROR: Operacion reservada a supervisores"
               EXIT PARAGRAPH
           END-IF

           MOVE "Numero de cuenta a desbloquear" TO WS-PROMPT
           MOVE 10 TO WS-MAX
           CALL "PEDIRNUM" USING WS-PROMPT WS-MAX WS-NUMERO WS-OK
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF

           OPEN I-O CUENTAS
           MOVE WS-NUMERO TO CTA-NRO
           READ CUENTAS KEY IS CTA-NRO
               INVALID KEY
                   DISPLAY "ERROR: Cuenta inexistente"
               NOT INVALID KEY
                   IF CTA-BLOQUEADA
                       SET CTA-ABIERTA TO TRUE
                       MOVE ZERO TO CTA-INTENTOS
                       REWRITE REG-CUENTA
                       MOVE "DESBLOQ" TO AUD-OPERACION
                       MOVE CTA-NRO TO AUD-CUENTA
                       MOVE "OK" TO AUD-RESULTADO
                       CALL "AUDITORIA" USING AUD-DATOS
                       DISPLAY "OK: Cuenta " CTA-NRO " desbloqueada"
                   ELSE
                       DISPLAY "ERROR: La cuenta no esta bloqueada"
                   END-IF
           END-READ
           CLOSE CUENTAS.

      *> ---------------------------------------------------------
      *> Validacion de PIN con bloqueo por intentos (RA2 / RA3).
      *> Entrada: WS-CTA, WS-PIN. Salida: WS-OK, WS-MENSAJE.
      *> ---------------------------------------------------------
       P-VALIDAR-PIN.
           MOVE "N" TO WS-OK
           MOVE SPACES TO WS-MENSAJE
           OPEN I-O CUENTAS
           IF FS-CUENTAS NOT = "00" AND FS-CUENTAS NOT = "05"
               MOVE "Error al abrir cuentas" TO WS-MENSAJE
               EXIT PARAGRAPH
           END-IF

           MOVE WS-CTA TO CTA-NRO
           READ CUENTAS KEY IS CTA-NRO
               INVALID KEY
                   MOVE "Cuenta inexistente" TO WS-MENSAJE
               NOT INVALID KEY
                   PERFORM P-CHEQUEAR-PIN
           END-READ
           CLOSE CUENTAS.

       P-CHEQUEAR-PIN.
           EVALUATE TRUE
               WHEN CTA-BLOQUEADA
                   MOVE "Cuenta bloqueada" TO WS-MENSAJE
               WHEN NOT CTA-ABIERTA
                   MOVE "Cuenta cerrada" TO WS-MENSAJE
               WHEN OTHER
                   PERFORM P-HASH-PIN
                   IF WS-HASH = CTA-PIN-HASH
                       MOVE ZERO TO CTA-INTENTOS
                       MOVE "S" TO WS-OK
                   ELSE
                       ADD 1 TO CTA-INTENTOS
                       IF CTA-INTENTOS >= PAR-MAX-INTENTOS
                           SET CTA-BLOQUEADA TO TRUE
                           MOVE "PIN incorrecto. Cuenta bloqueada"
                               TO WS-MENSAJE
                           MOVE "BLOQUEO" TO AUD-OPERACION
                           MOVE CTA-NRO TO AUD-CUENTA
                           MOVE "CUENTA BLOQUEADA POR PIN"
                               TO AUD-RESULTADO
                           CALL "AUDITORIA" USING AUD-DATOS
                       ELSE
                           MOVE CTA-INTENTOS TO WS-INTENTO-ED
                           STRING "PIN incorrecto (intento "
                                  WS-INTENTO-ED " de "
                                  PAR-MAX-INTENTOS ")"
                                  DELIMITED BY SIZE INTO WS-MENSAJE
                           END-STRING
                       END-IF
                   END-IF
                   REWRITE REG-CUENTA
           END-EVALUATE.

      *> Hash del PIN con el numero de cuenta como sal.
       P-HASH-PIN.
           MOVE SPACES TO WS-CLAVE-HASH
           STRING WS-PIN CTA-NRO DELIMITED BY SIZE
               INTO WS-CLAVE-HASH
           END-STRING
           CALL "HASHCLAVE" USING WS-CLAVE-HASH WS-HASH.

       P-ACEPTAR-PIN.
           MOVE "N" TO WS-OK
           MOVE SPACES TO WS-ENTRADA
           ACCEPT WS-ENTRADA
           IF WS-ENTRADA(1:4) IS NUMERIC AND WS-ENTRADA(5:) = SPACES
               MOVE WS-ENTRADA(1:4) TO WS-PIN
               MOVE "S" TO WS-OK
           ELSE
               DISPLAY "ERROR: El PIN debe tener 4 digitos"
           END-IF.
