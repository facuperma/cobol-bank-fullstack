      *> UTILES: lectura y validacion de datos ingresados por el
      *> usuario. Cada rutina muestra el error y devuelve OK = "N"
      *> si la entrada no es valida.

      *> LEERTXT: unico punto de entrada de datos. En la consola
      *> muestra el prompt y lee del teclado; en modo servicio lee
      *> la siguiente linea del pedido, sin prompt.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LEERTXT.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY MODO.

       LINKAGE SECTION.
       01 LK-PROMPT             PIC X(60).
       01 LK-VALOR              PIC X(50).

       PROCEDURE DIVISION USING LK-PROMPT LK-VALOR.
       P-PRINCIPAL.
           IF NOT MODO-SERVICIO
               DISPLAY FUNCTION TRIM(LK-PROMPT) ": " WITH NO ADVANCING
           END-IF
           MOVE SPACES TO LK-VALOR
           ACCEPT LK-VALOR
           GOBACK.
       END PROGRAM LEERTXT.

      *> PEDIRNUM: entero positivo de hasta LK-MAX digitos.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PEDIRNUM.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PROMPT             PIC X(60).
       01 WS-ENTRADA            PIC X(50).
       01 WS-TXT                PIC X(50).
       01 WS-LARGO              PIC 99.

       LINKAGE SECTION.
       01 LK-PROMPT             PIC X(40).
       01 LK-MAX                PIC 99.
       01 LK-NUMERO             PIC 9(12).
       01 LK-OK                 PIC X.

       PROCEDURE DIVISION USING LK-PROMPT LK-MAX LK-NUMERO LK-OK.
       P-PRINCIPAL.
           MOVE "N" TO LK-OK
           MOVE ZERO TO LK-NUMERO
           MOVE LK-PROMPT TO WS-PROMPT
           CALL "LEERTXT" USING WS-PROMPT WS-ENTRADA

           MOVE FUNCTION TRIM(WS-ENTRADA) TO WS-TXT
           MOVE ZERO TO WS-LARGO
           INSPECT WS-TXT TALLYING WS-LARGO
               FOR CHARACTERS BEFORE INITIAL SPACE

           IF WS-LARGO = 0 OR WS-LARGO > LK-MAX
               DISPLAY "ERROR: Numero invalido"
               GOBACK
           END-IF
           IF WS-TXT(1:WS-LARGO) IS NOT NUMERIC
               DISPLAY "ERROR: Numero invalido"
               GOBACK
           END-IF

           COMPUTE LK-NUMERO = FUNCTION NUMVAL(WS-TXT(1:WS-LARGO))
           MOVE "S" TO LK-OK
           GOBACK.
       END PROGRAM PEDIRNUM.

      *> PEDIRIMP: importe con hasta 2 decimales (acepta . o ,).
      *> LK-CERO = "S" permite ingresar cero.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PEDIRIMP.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PROMPT             PIC X(60).
       01 WS-ENTRADA            PIC X(50).
       01 WS-VALOR              PIC S9(13)V9(4).
       01 WS-CENTAVOS           PIC S9(15)V9(4).

       LINKAGE SECTION.
       01 LK-PROMPT             PIC X(40).
       01 LK-CERO               PIC X.
       01 LK-IMPORTE            PIC S9(11)V99 COMP-3.
       01 LK-OK                 PIC X.

       PROCEDURE DIVISION USING LK-PROMPT LK-CERO LK-IMPORTE LK-OK.
       P-PRINCIPAL.
           MOVE "N" TO LK-OK
           MOVE ZERO TO LK-IMPORTE
           MOVE LK-PROMPT TO WS-PROMPT
           CALL "LEERTXT" USING WS-PROMPT WS-ENTRADA
           INSPECT WS-ENTRADA REPLACING ALL "," BY "."

           IF WS-ENTRADA = SPACES
               DISPLAY "ERROR: Importe invalido"
               GOBACK
           END-IF
           IF FUNCTION TEST-NUMVAL(WS-ENTRADA) NOT = 0
               DISPLAY "ERROR: Importe invalido"
               GOBACK
           END-IF

           COMPUTE WS-VALOR = FUNCTION NUMVAL(WS-ENTRADA)
           COMPUTE WS-CENTAVOS = WS-VALOR * 100

           EVALUATE TRUE
               WHEN WS-VALOR < 0
               WHEN WS-VALOR > 999999999.99
                   DISPLAY "ERROR: Importe fuera de rango"
               WHEN WS-VALOR = 0 AND LK-CERO NOT = "S"
                   DISPLAY "ERROR: El importe debe ser mayor a cero"
               WHEN WS-CENTAVOS NOT =
                    FUNCTION INTEGER-PART(WS-CENTAVOS)
                   DISPLAY "ERROR: Maximo 2 decimales"
               WHEN OTHER
                   MOVE WS-VALOR TO LK-IMPORTE
                   MOVE "S" TO LK-OK
           END-EVALUATE
           GOBACK.
       END PROGRAM PEDIRIMP.
