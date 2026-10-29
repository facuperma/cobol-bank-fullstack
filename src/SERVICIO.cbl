      *> SERVICIO: punto de entrada no interactivo para la API.
      *> Atiende un pedido por ejecucion, leido de stdin:
      *>   linea 1  operacion
      *>   linea 2  usuario
      *>   resto    datos, en el mismo orden en que los pide la
      *>            consola (sin prompts)
      *> Operaciones:
      *>   LOGIN          clave
      *>   CLIENTES       opcion del menu de clientes y sus datos
      *>   APERTURA       cliente, tipo, PIN, PIN, deposito inicial
      *>   SALDO          cuenta, PIN
      *>   DESBLOQUEO     cuenta (supervisor)
      *>   DEPOSITO       cuenta, importe
      *>   RETIRO         cuenta, PIN, importe
      *>   TRANSFERENCIA  origen, PIN, destino, importe
      *>   EXTRACTO       cuenta, desde, hasta
      *>   INTERES        periodo, tasa (supervisor; vacios = defecto)
      *>   CIERRE | RECONCIL | RANKING | EXPORTA   periodo (supervisor)
      *> Respuesta por stdout: lineas "OK: ..." o "ERROR: ...", mas
      *> lineas de datos "@TIPO|campo|...". La API autentica con
      *> LOGIN y luego envia el usuario de la sesion en cada pedido.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SERVICIO.

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
       COPY MODO.

       01 WS-OPERACION          PIC X(20).
       01 WS-USUARIO            PIC X(8).
       01 WS-ENTRADA            PIC X(50).
       01 WS-CLAVE              PIC X(20).
       01 WS-CLAVE-HASH         PIC X(30).
       01 WS-HASH               PIC 9(8).
       01 WS-HOY                PIC X(8).
       01 WS-OK                 PIC X.

      *> Parametros para CUENTAS y TRANSAC.
       01 WS-OPC-CUENTAS        PIC XX.
       01 WS-CTA                PIC 9(10) VALUE ZERO.
       01 WS-PIN                PIC X(4) VALUE SPACES.
       01 WS-MENSAJE            PIC X(40).
       01 WS-OPC-TRANSAC        PIC XX.

       PROCEDURE DIVISION.
       P-PRINCIPAL.
           SET MODO-SERVICIO TO TRUE
           MOVE ZERO TO RETURN-CODE
           MOVE SPACES TO WS-ENTRADA
           ACCEPT WS-ENTRADA
      *>   Ignora la marca BOM que agregan algunos clientes UTF-8.
           IF WS-ENTRADA(1:3) = X"EFBBBF"
               MOVE FUNCTION UPPER-CASE(WS-ENTRADA(4:)) TO WS-OPERACION
           ELSE
               MOVE FUNCTION UPPER-CASE(WS-ENTRADA) TO WS-OPERACION
           END-IF
           MOVE SPACES TO WS-ENTRADA
           ACCEPT WS-ENTRADA
           MOVE FUNCTION UPPER-CASE(WS-ENTRADA) TO WS-USUARIO

           IF WS-OPERACION = "LOGIN"
               PERFORM P-LOGIN
               STOP RUN
           END-IF

           PERFORM P-CARGAR-SESION
           IF WS-OK = "N"
               MOVE 1 TO RETURN-CODE
               STOP RUN
           END-IF

           EVALUATE WS-OPERACION
               WHEN "CLIENTES"
                   CALL "CLIENTES" USING SESION
               WHEN "APERTURA"
                   MOVE "AP" TO WS-OPC-CUENTAS
                   PERFORM P-LLAMAR-CUENTAS
               WHEN "SALDO"
                   MOVE "CO" TO WS-OPC-CUENTAS
                   PERFORM P-LLAMAR-CUENTAS
               WHEN "DESBLOQUEO"
                   MOVE "DB" TO WS-OPC-CUENTAS
                   PERFORM P-LLAMAR-CUENTAS
               WHEN "DEPOSITO"
                   MOVE "DE" TO WS-OPC-TRANSAC
                   CALL "TRANSAC" USING SESION WS-OPC-TRANSAC
               WHEN "RETIRO"
                   MOVE "RE" TO WS-OPC-TRANSAC
                   CALL "TRANSAC" USING SESION WS-OPC-TRANSAC
               WHEN "TRANSFERENCIA"
                   MOVE "TR" TO WS-OPC-TRANSAC
                   CALL "TRANSAC" USING SESION WS-OPC-TRANSAC
               WHEN "EXTRACTO"
                   CALL "EXTRACTO" USING SESION
               WHEN "INTERES"
               WHEN "CIERRE"
               WHEN "RECONCIL"
               WHEN "RANKING"
               WHEN "EXPORTA"
                   PERFORM P-PROCESO-BATCH
               WHEN OTHER
                   DISPLAY "ERROR: Operacion desconocida "
                           FUNCTION TRIM(WS-OPERACION)
                   MOVE 1 TO RETURN-CODE
           END-EVALUATE
           STOP RUN.

      *> ---------------------------------------------------------
      *> Login: misma verificacion que BANCO (clave con hash y el
      *> usuario como sal). Devuelve rol y nombre.
      *> ---------------------------------------------------------
       P-LOGIN.
           MOVE SPACES TO WS-CLAVE
           ACCEPT WS-CLAVE
           MOVE SPACES TO WS-CLAVE-HASH
           STRING FUNCTION TRIM(WS-CLAVE) DELIMITED BY SIZE
                  WS-USUARIO DELIMITED BY SPACE
                  INTO WS-CLAVE-HASH
           END-STRING
           CALL "HASHCLAVE" USING WS-CLAVE-HASH WS-HASH

           MOVE WS-USUARIO TO AUD-USUARIO
           MOVE "LOGIN" TO AUD-OPERACION
           MOVE ZERO TO AUD-CUENTA AUD-IMPORTE

           OPEN INPUT USUARIOS
           MOVE WS-USUARIO TO USU-ID
           READ USUARIOS KEY IS USU-ID
               INVALID KEY
                   MOVE ZERO TO USU-CLAVE-HASH
           END-READ
           IF FS-USUARIOS = "00" AND USU-CLAVE-HASH = WS-HASH
               DISPLAY "OK: Bienvenido/a, " FUNCTION TRIM(USU-NOMBRE)
               DISPLAY "@USUARIO|" FUNCTION TRIM(USU-ID) "|" USU-ROL
                       "|" FUNCTION TRIM(USU-NOMBRE)
               MOVE "OK" TO AUD-RESULTADO
           ELSE
               DISPLAY "ERROR: Usuario o clave incorrectos"
               MOVE "RECHAZADO" TO AUD-RESULTADO
               MOVE 1 TO RETURN-CODE
           END-IF
           CLOSE USUARIOS
           CALL "AUDITORIA" USING AUD-DATOS.

      *> El rol sale de USUARIOS.DAT, no del pedido.
       P-CARGAR-SESION.
           MOVE "N" TO WS-OK
           OPEN INPUT USUARIOS
           MOVE WS-USUARIO TO USU-ID
           READ USUARIOS KEY IS USU-ID
               INVALID KEY
                   DISPLAY "ERROR: Usuario inexistente"
               NOT INVALID KEY
                   MOVE USU-ID TO SES-USUARIO
                   MOVE USU-ROL TO SES-ROL
                   MOVE "S" TO WS-OK
           END-READ
           CLOSE USUARIOS.

       P-LLAMAR-CUENTAS.
           CALL "CUENTAS" USING SESION WS-OPC-CUENTAS WS-CTA WS-PIN
                                WS-OK WS-MENSAJE.

      *> ---------------------------------------------------------
      *> Procesos batch (solo supervisor). Periodo vacio = mes
      *> actual; tasa vacia = 6.00.
      *> ---------------------------------------------------------
       P-PROCESO-BATCH.
           IF NOT SES-SUPERVISOR
               DISPLAY "ERROR: Operacion reservada a supervisores"
               MOVE 1 TO RETURN-CODE
               EXIT PARAGRAPH
           END-IF

           MOVE SES-USUARIO TO BAT-USUARIO
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-HOY
           MOVE WS-HOY(1:6) TO BAT-PERIODO
           MOVE 6.00 TO BAT-TASA
           MOVE 0 TO BAT-RC

           MOVE SPACES TO WS-ENTRADA
           ACCEPT WS-ENTRADA
           IF WS-ENTRADA NOT = SPACES
               IF WS-ENTRADA(1:6) IS NOT NUMERIC
                  OR WS-ENTRADA(7:) NOT = SPACES
                  OR WS-ENTRADA(5:2) < "01" OR WS-ENTRADA(5:2) > "12"
                   DISPLAY "ERROR: Periodo invalido (use AAAAMM)"
                   MOVE 1 TO RETURN-CODE
                   EXIT PARAGRAPH
               END-IF
               MOVE WS-ENTRADA(1:6) TO BAT-PERIODO
           END-IF

           MOVE SPACES TO WS-ENTRADA
           ACCEPT WS-ENTRADA
           IF WS-ENTRADA NOT = SPACES AND WS-OPERACION = "INTERES"
               IF FUNCTION TEST-NUMVAL(WS-ENTRADA) NOT = 0
                   DISPLAY "ERROR: Tasa invalida"
                   MOVE 1 TO RETURN-CODE
                   EXIT PARAGRAPH
               END-IF
               IF FUNCTION NUMVAL(WS-ENTRADA) < 0 OR
                  FUNCTION NUMVAL(WS-ENTRADA) > 100
                   DISPLAY "ERROR: La tasa debe estar entre 0 y 100"
                   MOVE 1 TO RETURN-CODE
                   EXIT PARAGRAPH
               END-IF
               COMPUTE BAT-TASA = FUNCTION NUMVAL(WS-ENTRADA)
           END-IF

           EVALUATE WS-OPERACION
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
           END-EVALUATE
           DISPLAY "@RC|" BAT-RC
           DISPLAY "@PERIODO|" BAT-PERIODO.
