      *> BANCO: programa principal interactivo.
      *> Login de usuario (RA9), menu de operaciones y acceso a los
      *> procesos batch para supervisores.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BANCO.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           COPY SEL-USUARIOS.

       DATA DIVISION.
       FILE SECTION.
       FD USUARIOS.
       COPY REG-USUARIO.

       WORKING-STORAGE SECTION.
       01 FS-USUARIOS           PIC XX.
       COPY SESION.
       COPY AUD-DATOS.
       COPY BATCH-PARAMS.

       01 WS-OPCION             PIC X.
       01 WS-VACIAS             PIC 9 VALUE 0.
       01 WS-SALIR              PIC X VALUE "N".
       01 WS-SALIR-BATCH        PIC X.
       01 WS-LOGUEADO           PIC X VALUE "N".
       01 WS-INTENTOS           PIC 9 VALUE 0.
       01 WS-ENTRADA            PIC X(20).
       01 WS-USUARIO            PIC X(8).
       01 WS-CLAVE              PIC X(20).
       01 WS-CLAVE-HASH         PIC X(30).
       01 WS-HASH               PIC 9(8).
       01 WS-HOY                PIC X(8).

      *> Parametros para CUENTAS (solo se usan en "PI").
       01 WS-OPC-CUENTAS        PIC XX.
       01 WS-CTA                PIC 9(10) VALUE ZERO.
       01 WS-PIN                PIC X(4) VALUE SPACES.
       01 WS-OK                 PIC X.
       01 WS-MENSAJE            PIC X(40).
       01 WS-OPC-TRANSAC        PIC XX.

       PROCEDURE DIVISION.
       P-PRINCIPAL.
           DISPLAY "=========================================="
           DISPLAY "        SISTEMA BANCARIO - GnuCOBOL"
           DISPLAY "=========================================="
           PERFORM P-LOGIN
               UNTIL WS-LOGUEADO = "S" OR WS-INTENTOS >= 3
           IF WS-LOGUEADO = "N"
               DISPLAY "ERROR: Acceso denegado"
               MOVE 1 TO RETURN-CODE
               STOP RUN
           END-IF

           PERFORM P-MENU UNTIL WS-SALIR = "S"

           MOVE "LOGOUT" TO AUD-OPERACION
           MOVE "OK" TO AUD-RESULTADO
           CALL "AUDITORIA" USING AUD-DATOS
           DISPLAY "Sesion finalizada."
           STOP RUN.

      *> ---------------------------------------------------------
      *> Login: usuario y clave contra USUARIOS.DAT (clave con
      *> hash y el usuario como sal).
      *> ---------------------------------------------------------
       P-LOGIN.
           ADD 1 TO WS-INTENTOS
           DISPLAY "Usuario: " WITH NO ADVANCING
           MOVE SPACES TO WS-ENTRADA
           ACCEPT WS-ENTRADA
           MOVE FUNCTION UPPER-CASE(WS-ENTRADA) TO WS-USUARIO
           DISPLAY "Clave: " WITH NO ADVANCING
           MOVE SPACES TO WS-CLAVE
           ACCEPT WS-CLAVE

           MOVE SPACES TO WS-CLAVE-HASH
           STRING FUNCTION TRIM(WS-CLAVE) DELIMITED BY SIZE
                  WS-USUARIO DELIMITED BY SPACE
                  INTO WS-CLAVE-HASH
           END-STRING
           CALL "HASHCLAVE" USING WS-CLAVE-HASH WS-HASH

           OPEN INPUT USUARIOS
           MOVE WS-USUARIO TO USU-ID
           READ USUARIOS KEY IS USU-ID
               INVALID KEY
                   MOVE ZERO TO USU-CLAVE-HASH
           END-READ
           IF FS-USUARIOS = "00" AND USU-CLAVE-HASH = WS-HASH
               MOVE "S" TO WS-LOGUEADO
               MOVE USU-ID TO SES-USUARIO
               MOVE USU-ROL TO SES-ROL
               DISPLAY "OK: Bienvenido/a, "
                       FUNCTION TRIM(USU-NOMBRE)
           ELSE
               DISPLAY "ERROR: Usuario o clave incorrectos"
           END-IF
           CLOSE USUARIOS

           MOVE WS-USUARIO TO AUD-USUARIO
           MOVE "LOGIN" TO AUD-OPERACION
           MOVE ZERO TO AUD-CUENTA AUD-IMPORTE
           IF WS-LOGUEADO = "S"
               MOVE "OK" TO AUD-RESULTADO
           ELSE
               MOVE "RECHAZADO" TO AUD-RESULTADO
           END-IF
           CALL "AUDITORIA" USING AUD-DATOS.

      *> ---------------------------------------------------------
      *> Menu principal
      *> ---------------------------------------------------------
       P-MENU.
           DISPLAY " "
           DISPLAY "=========================================="
           DISPLAY "   SISTEMA BANCARIO - MENU PRINCIPAL"
           DISPLAY "=========================================="
           DISPLAY "  1. Gestion de clientes"
           DISPLAY "  2. Apertura de cuenta"
           DISPLAY "  3. Deposito"
           DISPLAY "  4. Retiro"
           DISPLAY "  5. Transferencia"
           DISPLAY "  6. Consulta de saldo"
           DISPLAY "  7. Extracto"
           DISPLAY "  8. Procesos batch (supervisor)"
           DISPLAY "  9. Salir"
           DISPLAY "=========================================="
           DISPLAY "Opcion: " WITH NO ADVANCING
           MOVE SPACES TO WS-OPCION
           ACCEPT WS-OPCION

           EVALUATE WS-OPCION
               WHEN "1"
                   CALL "CLIENTES" USING SESION
               WHEN "2"
                   MOVE "AP" TO WS-OPC-CUENTAS
                   PERFORM P-LLAMAR-CUENTAS
               WHEN "3"
                   MOVE "DE" TO WS-OPC-TRANSAC
                   CALL "TRANSAC" USING SESION WS-OPC-TRANSAC
               WHEN "4"
                   MOVE "RE" TO WS-OPC-TRANSAC
                   CALL "TRANSAC" USING SESION WS-OPC-TRANSAC
               WHEN "5"
                   MOVE "TR" TO WS-OPC-TRANSAC
                   CALL "TRANSAC" USING SESION WS-OPC-TRANSAC
               WHEN "6"
                   MOVE "CO" TO WS-OPC-CUENTAS
                   PERFORM P-LLAMAR-CUENTAS
               WHEN "7"
                   CALL "EXTRACTO" USING SESION
               WHEN "8"
                   IF SES-SUPERVISOR
                       MOVE "N" TO WS-SALIR-BATCH
                       PERFORM P-MENU-BATCH
                           UNTIL WS-SALIR-BATCH = "S"
                   ELSE
                       DISPLAY "ERROR: Opcion reservada a supervisores"
                   END-IF
               WHEN "9"
                   MOVE "S" TO WS-SALIR
               WHEN SPACE
      *>           Entrada vacia o fin de archivo (entrada
      *>           redirigida en las pruebas).
                   ADD 1 TO WS-VACIAS
                   IF WS-VACIAS >= 3
                       MOVE "S" TO WS-SALIR
                   END-IF
               WHEN OTHER
                   DISPLAY "ERROR: Opcion invalida"
           END-EVALUATE.

       P-LLAMAR-CUENTAS.
           CALL "CUENTAS" USING SESION WS-OPC-CUENTAS WS-CTA WS-PIN
                                WS-OK WS-MENSAJE.

      *> ---------------------------------------------------------
      *> Submenu de supervisor
      *> ---------------------------------------------------------
       P-MENU-BATCH.
           DISPLAY " "
           DISPLAY "------- PROCESOS (SUPERVISOR) -------"
           DISPLAY "  1. Desbloquear cuenta"
           DISPLAY "  2. Intereses del mes actual"
           DISPLAY "  3. Cierre del mes actual"
           DISPLAY "  4. Reconciliacion de saldos"
           DISPLAY "  5. Ranking de clientes por saldo"
           DISPLAY "  6. Exportar movimientos del mes"
           DISPLAY "  9. Volver"
           DISPLAY "Opcion: " WITH NO ADVANCING
           MOVE SPACES TO WS-OPCION
           ACCEPT WS-OPCION

           MOVE SES-USUARIO TO BAT-USUARIO
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-HOY
           MOVE WS-HOY(1:6) TO BAT-PERIODO
           MOVE 6.00 TO BAT-TASA
           MOVE 0 TO BAT-RC

           EVALUATE WS-OPCION
               WHEN "1"
                   MOVE "DB" TO WS-OPC-CUENTAS
                   PERFORM P-LLAMAR-CUENTAS
               WHEN "2"
                   CALL "INTERES" USING BATCH-PARAMS
               WHEN "3"
                   CALL "CIERRE" USING BATCH-PARAMS
               WHEN "4"
                   CALL "RECONCIL" USING BATCH-PARAMS
               WHEN "5"
                   CALL "RANKING" USING BATCH-PARAMS
               WHEN "6"
                   CALL "EXPORTA" USING BATCH-PARAMS
               WHEN "9"
                   MOVE "S" TO WS-SALIR-BATCH
               WHEN SPACE
                   ADD 1 TO WS-VACIAS
                   IF WS-VACIAS >= 3
                       MOVE "S" TO WS-SALIR-BATCH WS-SALIR
                   END-IF
               WHEN OTHER
                   DISPLAY "ERROR: Opcion invalida"
           END-EVALUATE.
