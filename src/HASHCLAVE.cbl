      *> HASHCLAVE: hash simple (djb2 modulo un primo) para no
      *> guardar PIN ni claves en texto plano. El llamador agrega
      *> una "sal" (nro de cuenta o usuario) para que dos PIN
      *> iguales no den el mismo hash.
      *> No es criptografico: en produccion se usaria un HSM o una
      *> funcion como PBKDF2/bcrypt.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. HASHCLAVE.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-H                  PIC 9(12).
       01 WS-I                  PIC 99.
       01 WS-LARGO              PIC 99.

       LINKAGE SECTION.
       01 LK-TEXTO              PIC X(30).
       01 LK-HASH               PIC 9(8).

       PROCEDURE DIVISION USING LK-TEXTO LK-HASH.
       P-PRINCIPAL.
           MOVE 5381 TO WS-H
           MOVE ZERO TO WS-LARGO
           INSPECT FUNCTION REVERSE(LK-TEXTO)
               TALLYING WS-LARGO FOR LEADING SPACES
           COMPUTE WS-LARGO = 30 - WS-LARGO

           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-LARGO
               COMPUTE WS-H = FUNCTION MOD(
                   WS-H * 33 + FUNCTION ORD(LK-TEXTO(WS-I:1)),
                   99999989)
           END-PERFORM

           MOVE WS-H TO LK-HASH
           GOBACK.
