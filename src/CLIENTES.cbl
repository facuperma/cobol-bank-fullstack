      *> CLIENTES: gestion de clientes.
      *> Alta (RF1), modificacion (RF3), baja logica (RF2),
      *> consulta y busqueda por documento o apellido (RA7).
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLIENTES IS INITIAL.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           COPY SEL-CLIENTES.
           COPY SEL-CUENTAS.

       DATA DIVISION.
       FILE SECTION.
       FD CLIENTES.
       COPY REG-CLIENTE.
       FD CUENTAS.
       COPY REG-CUENTA.

       WORKING-STORAGE SECTION.
       01 FS-CLIENTES           PIC XX.
       01 FS-CUENTAS            PIC XX.
       COPY PARAMETROS.
       COPY AUD-DATOS.

       01 WS-OPCION             PIC X.
       01 WS-VACIAS             PIC 9 VALUE 0.
       01 WS-SALIR              PIC X VALUE "N".
       01 WS-PROMPT             PIC X(40).
       01 WS-MAX                PIC 99.
       01 WS-NUMERO             PIC 9(12).
       01 WS-OK                 PIC X.
       01 WS-ENTRADA            PIC X(50).
       01 WS-TXT                PIC X(50).
       01 WS-LARGO              PIC 99.
       01 WS-ID                 PIC 9(6).
       01 WS-DOCUMENTO          PIC X(12).
       01 WS-HOY                PIC 9(8).
       01 WS-EDAD               PIC 9(3).
       01 WS-SECUENCIA          PIC X(3) VALUE "CLI".
       01 WS-FIN                PIC X.
       01 WS-ENCONTRADOS        PIC 9(5).
       01 WS-SALDO-TOTAL        PIC S9(13)V99 COMP-3.
       01 WS-SALDO-ED           PIC -ZZ,ZZZ,ZZZ,ZZ9.99.
       01 WS-FECHA-ED           PIC 9999/99/99.

       LINKAGE SECTION.
       COPY SESION.

       PROCEDURE DIVISION USING SESION.
       P-PRINCIPAL.
           MOVE SES-USUARIO TO AUD-USUARIO
           MOVE ZERO TO AUD-CUENTA AUD-IMPORTE
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-HOY
           PERFORM P-MENU UNTIL WS-SALIR = "S"
           GOBACK.

       P-MENU.
           DISPLAY " "
           DISPLAY "---------- GESTION DE CLIENTES ----------"
           DISPLAY "  1. Alta de cliente"
           DISPLAY "  2. Modificacion de datos"
           DISPLAY "  3. Baja de cliente"
           DISPLAY "  4. Consulta por ID"
           DISPLAY "  5. Buscar por documento"
           DISPLAY "  6. Buscar por apellido"
           DISPLAY "  9. Volver"
           DISPLAY "Opcion: " WITH NO ADVANCING
           MOVE SPACES TO WS-OPCION
           ACCEPT WS-OPCION

           EVALUATE WS-OPCION
               WHEN "1" PERFORM P-ALTA
               WHEN "2" PERFORM P-MODIFICACION
               WHEN "3" PERFORM P-BAJA
               WHEN "4" PERFORM P-CONSULTA
               WHEN "5" PERFORM P-BUSCAR-DOCUMENTO
               WHEN "6" PERFORM P-BUSCAR-APELLIDO
               WHEN "9" MOVE "S" TO WS-SALIR
               WHEN SPACE
      *>           Entrada vacia (o fin de archivo si la entrada
      *>           viene redirigida): evita un ciclo infinito.
                   ADD 1 TO WS-VACIAS
                   IF WS-VACIAS >= 3
                       MOVE "S" TO WS-SALIR
                   END-IF
               WHEN OTHER
                   DISPLAY "ERROR: Opcion invalida"
           END-EVALUATE.

      *> ---------------------------------------------------------
      *> Alta
      *> ---------------------------------------------------------
       P-ALTA.
           DISPLAY "Documento (7 a 12 digitos): " WITH NO ADVANCING
           PERFORM P-ACEPTAR-DOCUMENTO
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF

           OPEN I-O CLIENTES
           IF FS-CLIENTES NOT = "00" AND FS-CLIENTES NOT = "05"
               DISPLAY "ERROR: No se pudo abrir CLIENTES FS="
                       FS-CLIENTES
               EXIT PARAGRAPH
           END-IF

           MOVE WS-DOCUMENTO TO CLI-DOCUMENTO
           READ CLIENTES KEY IS CLI-DOCUMENTO
               INVALID KEY
                   CONTINUE
               NOT INVALID KEY
                   MOVE "N" TO WS-OK
                   DISPLAY "ERROR: Documento ya registrado (cliente "
                           CLI-ID ")"
           END-READ
           IF WS-OK = "N"
               CLOSE CLIENTES
               EXIT PARAGRAPH
           END-IF

           INITIALIZE REG-CLIENTE
           MOVE WS-DOCUMENTO TO CLI-DOCUMENTO

           DISPLAY "Nombre: " WITH NO ADVANCING
           PERFORM P-ACEPTAR-TEXTO
           MOVE FUNCTION UPPER-CASE(WS-TXT) TO CLI-NOMBRE
           DISPLAY "Apellido: " WITH NO ADVANCING
           PERFORM P-ACEPTAR-TEXTO
           MOVE FUNCTION UPPER-CASE(WS-TXT) TO CLI-APELLIDO
           IF CLI-NOMBRE = SPACES OR CLI-APELLIDO = SPACES
               DISPLAY "ERROR: Nombre y apellido son obligatorios"
               CLOSE CLIENTES
               EXIT PARAGRAPH
           END-IF

           DISPLAY "Fecha de nacimiento (AAAAMMDD): "
               WITH NO ADVANCING
           PERFORM P-ACEPTAR-FECHA-NAC
           IF WS-OK = "N"
               CLOSE CLIENTES
               EXIT PARAGRAPH
           END-IF

           DISPLAY "Direccion: " WITH NO ADVANCING
           PERFORM P-ACEPTAR-TEXTO
           MOVE WS-TXT TO CLI-DIRECCION
           DISPLAY "Telefono: " WITH NO ADVANCING
           PERFORM P-ACEPTAR-TEXTO
           MOVE WS-TXT TO CLI-TELEFONO

           CALL "NUMERADOR" USING WS-SECUENCIA WS-NUMERO
           IF WS-NUMERO = ZERO
               DISPLAY "ERROR: No se pudo numerar el cliente"
               CLOSE CLIENTES
               EXIT PARAGRAPH
           END-IF
           MOVE WS-NUMERO TO CLI-ID WS-ID
           SET CLI-ACTIVO TO TRUE

           WRITE REG-CLIENTE
               INVALID KEY
                   DISPLAY "ERROR: Clave duplicada FS=" FS-CLIENTES
                   MOVE "N" TO WS-OK
           END-WRITE
           CLOSE CLIENTES
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF

           MOVE "ALTA-CLI" TO AUD-OPERACION
           MOVE WS-ID TO AUD-CUENTA
           MOVE "OK" TO AUD-RESULTADO
           CALL "AUDITORIA" USING AUD-DATOS
           DISPLAY "OK: Cliente " WS-ID " dado de alta".

      *> ---------------------------------------------------------
      *> Modificacion: un campo vacio conserva el valor actual.
      *> ---------------------------------------------------------
       P-MODIFICACION.
           PERFORM P-PEDIR-ID
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF

           OPEN I-O CLIENTES
           MOVE WS-ID TO CLI-ID
           READ CLIENTES KEY IS CLI-ID
               INVALID KEY
                   MOVE "N" TO WS-OK
                   DISPLAY "ERROR: Cliente inexistente"
           END-READ
           IF WS-OK = "S" AND NOT CLI-ACTIVO
               MOVE "N" TO WS-OK
               DISPLAY "ERROR: Cliente dado de baja"
           END-IF
           IF WS-OK = "N"
               CLOSE CLIENTES
               EXIT PARAGRAPH
           END-IF

           DISPLAY "Direccion actual: " FUNCTION TRIM(CLI-DIRECCION)
           DISPLAY "Nueva direccion (Enter = sin cambios): "
               WITH NO ADVANCING
           PERFORM P-ACEPTAR-TEXTO
           IF WS-TXT NOT = SPACES
               MOVE WS-TXT TO CLI-DIRECCION
           END-IF
           DISPLAY "Telefono actual: " FUNCTION TRIM(CLI-TELEFONO)
           DISPLAY "Nuevo telefono (Enter = sin cambios): "
               WITH NO ADVANCING
           PERFORM P-ACEPTAR-TEXTO
           IF WS-TXT NOT = SPACES
               MOVE WS-TXT TO CLI-TELEFONO
           END-IF

           REWRITE REG-CLIENTE
           IF FS-CLIENTES = "00"
               MOVE "MODIF-CL" TO AUD-OPERACION
               MOVE WS-ID TO AUD-CUENTA
               MOVE "OK" TO AUD-RESULTADO
               CALL "AUDITORIA" USING AUD-DATOS
               DISPLAY "OK: Datos actualizados"
           ELSE
               DISPLAY "ERROR: No se pudo actualizar FS=" FS-CLIENTES
           END-IF
           CLOSE CLIENTES.

      *> ---------------------------------------------------------
      *> Baja logica: solo si todas sus cuentas estan en cero.
      *> Marca al cliente inactivo y cierra sus cuentas.
      *> ---------------------------------------------------------
       P-BAJA.
           PERFORM P-PEDIR-ID
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF

           OPEN I-O CLIENTES
           MOVE WS-ID TO CLI-ID
           READ CLIENTES KEY IS CLI-ID
               INVALID KEY
                   MOVE "N" TO WS-OK
                   DISPLAY "ERROR: Cliente inexistente"
           END-READ
           IF WS-OK = "S" AND NOT CLI-ACTIVO
               MOVE "N" TO WS-OK
               DISPLAY "ERROR: El cliente ya estaba dado de baja"
           END-IF
           IF WS-OK = "N"
               CLOSE CLIENTES
               EXIT PARAGRAPH
           END-IF

           OPEN I-O CUENTAS
           PERFORM P-SUMAR-SALDOS
           IF WS-SALDO-TOTAL NOT = ZERO
               MOVE WS-SALDO-TOTAL TO WS-SALDO-ED
               DISPLAY "ERROR: El cliente tiene saldo ("
                       FUNCTION TRIM(WS-SALDO-ED) ")"
               CLOSE CUENTAS CLIENTES
               MOVE "BAJA-CLI" TO AUD-OPERACION
               MOVE WS-ID TO AUD-CUENTA
               MOVE "RECHAZADO TIENE SALDO" TO AUD-RESULTADO
               CALL "AUDITORIA" USING AUD-DATOS
               EXIT PARAGRAPH
           END-IF

           PERFORM P-CERRAR-CUENTAS
           CLOSE CUENTAS

           SET CLI-INACTIVO TO TRUE
           REWRITE REG-CLIENTE
           CLOSE CLIENTES

           MOVE "BAJA-CLI" TO AUD-OPERACION
           MOVE WS-ID TO AUD-CUENTA
           MOVE "OK" TO AUD-RESULTADO
           CALL "AUDITORIA" USING AUD-DATOS
           DISPLAY "OK: Cliente " WS-ID " dado de baja".

      *> Suma los saldos de las cuentas no cerradas del cliente
      *> WS-ID recorriendo la clave alternativa CTA-ID-CLIENTE.
       P-SUMAR-SALDOS.
           MOVE ZERO TO WS-SALDO-TOTAL
           MOVE "N" TO WS-FIN
           MOVE WS-ID TO CTA-ID-CLIENTE
           START CUENTAS KEY IS = CTA-ID-CLIENTE
               INVALID KEY
                   MOVE "S" TO WS-FIN
           END-START
           PERFORM UNTIL WS-FIN = "S"
               READ CUENTAS NEXT RECORD
                   AT END
                       MOVE "S" TO WS-FIN
                   NOT AT END
                       IF CTA-ID-CLIENTE NOT = WS-ID
                           MOVE "S" TO WS-FIN
                       ELSE
                           IF NOT CTA-CERRADA
                               ADD CTA-SALDO TO WS-SALDO-TOTAL
                           END-IF
                       END-IF
               END-READ
           END-PERFORM.

       P-CERRAR-CUENTAS.
           MOVE "N" TO WS-FIN
           MOVE WS-ID TO CTA-ID-CLIENTE
           START CUENTAS KEY IS = CTA-ID-CLIENTE
               INVALID KEY
                   MOVE "S" TO WS-FIN
           END-START
           PERFORM UNTIL WS-FIN = "S"
               READ CUENTAS NEXT RECORD
                   AT END
                       MOVE "S" TO WS-FIN
                   NOT AT END
                       IF CTA-ID-CLIENTE NOT = WS-ID
                           MOVE "S" TO WS-FIN
                       ELSE
                           IF NOT CTA-CERRADA
                               SET CTA-CERRADA TO TRUE
                               REWRITE REG-CUENTA
                           END-IF
                       END-IF
               END-READ
           END-PERFORM.

      *> ---------------------------------------------------------
      *> Consultas y busquedas
      *> ---------------------------------------------------------
       P-CONSULTA.
           PERFORM P-PEDIR-ID
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF
           OPEN INPUT CLIENTES
           MOVE WS-ID TO CLI-ID
           READ CLIENTES KEY IS CLI-ID
               INVALID KEY
                   DISPLAY "ERROR: Cliente inexistente"
               NOT INVALID KEY
                   PERFORM P-MOSTRAR-CLIENTE
                   PERFORM P-LISTAR-CUENTAS
           END-READ
           CLOSE CLIENTES.

       P-BUSCAR-DOCUMENTO.
           DISPLAY "Documento: " WITH NO ADVANCING
           PERFORM P-ACEPTAR-DOCUMENTO
           IF WS-OK = "N"
               EXIT PARAGRAPH
           END-IF
           OPEN INPUT CLIENTES
           MOVE WS-DOCUMENTO TO CLI-DOCUMENTO
           READ CLIENTES KEY IS CLI-DOCUMENTO
               INVALID KEY
                   DISPLAY "ERROR: No hay clientes con ese documento"
               NOT INVALID KEY
                   MOVE CLI-ID TO WS-ID
                   PERFORM P-MOSTRAR-CLIENTE
                   PERFORM P-LISTAR-CUENTAS
           END-READ
           CLOSE CLIENTES.

      *> Busqueda por apellido (o su comienzo): recorrido
      *> secuencial completo del archivo.
       P-BUSCAR-APELLIDO.
           DISPLAY "Apellido o inicio del apellido: "
               WITH NO ADVANCING
           PERFORM P-ACEPTAR-TEXTO
           MOVE FUNCTION UPPER-CASE(WS-TXT) TO WS-TXT
           MOVE ZERO TO WS-LARGO
           INSPECT WS-TXT TALLYING WS-LARGO
               FOR CHARACTERS BEFORE INITIAL "  "
           IF WS-LARGO = 0
               DISPLAY "ERROR: Ingrese al menos una letra"
               EXIT PARAGRAPH
           END-IF
           IF WS-LARGO > 30
               MOVE 30 TO WS-LARGO
           END-IF

           MOVE ZERO TO WS-ENCONTRADOS
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
                       IF CLI-APELLIDO(1:WS-LARGO) =
                          WS-TXT(1:WS-LARGO)
                           ADD 1 TO WS-ENCONTRADOS
                           PERFORM P-LINEA-CLIENTE
                       END-IF
               END-READ
           END-PERFORM
           CLOSE CLIENTES
           DISPLAY "Clientes encontrados: " WS-ENCONTRADOS.

       P-MOSTRAR-CLIENTE.
           MOVE CLI-FECHA-NAC TO WS-FECHA-ED
           DISPLAY "------------------------------------------"
           DISPLAY " Cliente    : " CLI-ID
           DISPLAY " Documento  : " CLI-DOCUMENTO
           DISPLAY " Nombre     : " FUNCTION TRIM(CLI-APELLIDO) ", "
                   FUNCTION TRIM(CLI-NOMBRE)
           DISPLAY " Nacimiento : " WS-FECHA-ED
           DISPLAY " Direccion  : " FUNCTION TRIM(CLI-DIRECCION)
           DISPLAY " Telefono   : " FUNCTION TRIM(CLI-TELEFONO)
           IF CLI-ACTIVO
               DISPLAY " Estado     : ACTIVO"
           ELSE
               DISPLAY " Estado     : INACTIVO"
           END-IF.

       P-LINEA-CLIENTE.
           DISPLAY " " CLI-ID "  " CLI-DOCUMENTO "  "
                   FUNCTION TRIM(CLI-APELLIDO) ", "
                   FUNCTION TRIM(CLI-NOMBRE)
                   "  [" CLI-ESTADO "]".

       P-LISTAR-CUENTAS.
           DISPLAY " Cuentas:"
           MOVE "N" TO WS-FIN
           OPEN INPUT CUENTAS
           MOVE WS-ID TO CTA-ID-CLIENTE
           START CUENTAS KEY IS = CTA-ID-CLIENTE
               INVALID KEY
                   DISPLAY "   (sin cuentas)"
                   MOVE "S" TO WS-FIN
           END-START
           PERFORM UNTIL WS-FIN = "S"
               READ CUENTAS NEXT RECORD
                   AT END
                       MOVE "S" TO WS-FIN
                   NOT AT END
                       IF CTA-ID-CLIENTE NOT = WS-ID
                           MOVE "S" TO WS-FIN
                       ELSE
                           MOVE CTA-SALDO TO WS-SALDO-ED
                           DISPLAY "   " CTA-NRO "  " CTA-TIPO
                                   "  " WS-SALDO-ED "  ["
                                   CTA-ESTADO "]"
                       END-IF
               END-READ
           END-PERFORM
           CLOSE CUENTAS
           DISPLAY "------------------------------------------".

      *> ---------------------------------------------------------
      *> Validaciones de entrada
      *> ---------------------------------------------------------
       P-PEDIR-ID.
           MOVE "ID de cliente" TO WS-PROMPT
           MOVE 6 TO WS-MAX
           CALL "PEDIRNUM" USING WS-PROMPT WS-MAX WS-NUMERO WS-OK
           MOVE WS-NUMERO TO WS-ID.

      *> Documento: entre 7 y 12 digitos.
       P-ACEPTAR-DOCUMENTO.
           MOVE "N" TO WS-OK
           PERFORM P-ACEPTAR-TEXTO
           MOVE ZERO TO WS-LARGO
           INSPECT WS-TXT TALLYING WS-LARGO
               FOR CHARACTERS BEFORE INITIAL SPACE
           IF WS-LARGO < 7 OR WS-LARGO > 12
               DISPLAY "ERROR: El documento debe tener 7 a 12 digitos"
               EXIT PARAGRAPH
           END-IF
           IF WS-TXT(1:WS-LARGO) IS NOT NUMERIC
               DISPLAY "ERROR: El documento solo admite digitos"
               EXIT PARAGRAPH
           END-IF
           MOVE WS-TXT(1:WS-LARGO) TO WS-DOCUMENTO
           MOVE "S" TO WS-OK.

      *> Fecha valida, no futura y cliente mayor de edad.
       P-ACEPTAR-FECHA-NAC.
           MOVE "N" TO WS-OK
           PERFORM P-ACEPTAR-TEXTO
           IF WS-TXT(1:8) IS NOT NUMERIC OR WS-TXT(9:) NOT = SPACES
               DISPLAY "ERROR: Fecha invalida (use AAAAMMDD)"
               EXIT PARAGRAPH
           END-IF
           MOVE WS-TXT(1:8) TO CLI-FECHA-NAC
           IF FUNCTION TEST-DATE-YYYYMMDD(CLI-FECHA-NAC) NOT = 0
               DISPLAY "ERROR: Fecha inexistente"
               EXIT PARAGRAPH
           END-IF
           IF CLI-FECHA-NAC >= WS-HOY
               DISPLAY "ERROR: La fecha no puede ser futura"
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-EDAD = (WS-HOY - CLI-FECHA-NAC) / 10000
           IF WS-EDAD < PAR-EDAD-MINIMA
               DISPLAY "ERROR: El cliente debe ser mayor de edad"
               EXIT PARAGRAPH
           END-IF
           MOVE "S" TO WS-OK.

       P-ACEPTAR-TEXTO.
           MOVE SPACES TO WS-ENTRADA
           ACCEPT WS-ENTRADA
           MOVE FUNCTION TRIM(WS-ENTRADA) TO WS-TXT.
