      *> CARGA (batch): crea los archivos desde cero con datos de
      *> prueba: 5 clientes, 8 cuentas (algunas en cero y una
      *> bloqueada), sus depositos iniciales y dos usuarios.
      *> BORRA los datos existentes (no el log de auditoria).
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARGA IS INITIAL.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           COPY SEL-CLIENTES.
           COPY SEL-CUENTAS.
           COPY SEL-MOVIM.
           COPY SEL-USUARIOS.
           COPY SEL-CONTROL.

       DATA DIVISION.
       FILE SECTION.
       FD CLIENTES.
       COPY REG-CLIENTE.
       FD CUENTAS.
       COPY REG-CUENTA.
       FD MOVIMIENTOS.
       COPY REG-MOV.
       FD USUARIOS.
       COPY REG-USUARIO.
       FD CONTROL-F.
       COPY REG-CONTROL.

       WORKING-STORAGE SECTION.
       01 FS-CLIENTES           PIC XX.
       01 FS-CUENTAS            PIC XX.
       01 FS-MOVIM              PIC XX.
       01 FS-USUARIOS           PIC XX.
       01 FS-CONTROL            PIC XX.
       COPY AUD-DATOS.

       01 WS-AHORA              PIC X(21).
       01 WS-CLAVE              PIC X(8).
       01 WS-CLAVE-HASH         PIC X(30).
       01 WS-HASH               PIC 9(8).
       01 WS-I                  PIC 99.
       01 WS-NRO-MOV            PIC 9(12) VALUE 0.

      *> Datos de clientes: id, documento, nombre, apellido,
      *> fecha de nacimiento, direccion, telefono.
       01 WS-DATOS-CLIENTES.
          05 FILLER PIC X(80) VALUE
             "00000130111222    JUAN          PEREZ         19850312".
          05 FILLER PIC X(80) VALUE
             "00000227333444    MARIA         GOMEZ         19900725".
          05 FILLER PIC X(80) VALUE
             "00000335555666    CARLOS        RODRIGUEZ     19781102".
          05 FILLER PIC X(80) VALUE
             "00000440777888    LUCIA         FERNANDEZ     19990218".
          05 FILLER PIC X(80) VALUE
             "00000522999000    JORGE         LOPEZ         19650930".
       01 WS-TABLA-CLIENTES REDEFINES WS-DATOS-CLIENTES.
          05 WT-CLIENTE OCCURS 5 TIMES.
             10 WT-CLI-ID       PIC 9(6).
             10 WT-CLI-DOC      PIC X(12).
             10 WT-CLI-NOMBRE   PIC X(14).
             10 WT-CLI-APELLIDO PIC X(14).
             10 WT-CLI-NAC      PIC 9(8).
             10 FILLER          PIC X(26).

      *> Datos de cuentas: numero, cliente, tipo, PIN, estado,
      *> intentos, saldo inicial (9 enteros + 2 decimales).
       01 WS-DATOS-CUENTAS.
          05 FILLER PIC X(40) VALUE
             "1000000001000001A1234A000000150000".
          05 FILLER PIC X(40) VALUE
             "1000000002000001C1234A000000300000".
          05 FILLER PIC X(40) VALUE
             "1000000003000002A2222A000000080000".
          05 FILLER PIC X(40) VALUE
             "1000000004000002A2222A000000000000".
          05 FILLER PIC X(40) VALUE
             "1000000005000003C3333A000001200000".
          05 FILLER PIC X(40) VALUE
             "1000000006000003A3333B300000025000".
          05 FILLER PIC X(40) VALUE
             "1000000007000004A4444A000000000000".
          05 FILLER PIC X(40) VALUE
             "1000000008000005A5555A000000500000".
       01 WS-TABLA-CUENTAS REDEFINES WS-DATOS-CUENTAS.
          05 WT-CUENTA OCCURS 8 TIMES.
             10 WT-CTA-NRO      PIC 9(10).
             10 WT-CTA-CLIENTE  PIC 9(6).
             10 WT-CTA-TIPO     PIC X.
             10 WT-CTA-PIN      PIC X(4).
             10 WT-CTA-ESTADO   PIC X.
             10 WT-CTA-INTENTOS PIC 9.
             10 WT-CTA-SALDO    PIC 9(9)V99.
             10 FILLER          PIC X(6).

       LINKAGE SECTION.
       COPY BATCH-PARAMS.

       PROCEDURE DIVISION USING BATCH-PARAMS.
       P-PRINCIPAL.
           MOVE 0 TO BAT-RC
           MOVE FUNCTION CURRENT-DATE TO WS-AHORA
           OPEN OUTPUT CLIENTES CUENTAS MOVIMIENTOS USUARIOS
                       CONTROL-F

           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 5
               PERFORM P-CLIENTE
           END-PERFORM
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 8
               PERFORM P-CUENTA
           END-PERFORM
           PERFORM P-USUARIOS

           MOVE "CLI" TO CTL-CLAVE
           MOVE 5 TO CTL-VALOR
           WRITE REG-CONTROL
           MOVE "CTA" TO CTL-CLAVE
           MOVE 1000000008 TO CTL-VALOR
           WRITE REG-CONTROL
           MOVE "MOV" TO CTL-CLAVE
           MOVE WS-NRO-MOV TO CTL-VALOR
           WRITE REG-CONTROL
           MOVE "OPE" TO CTL-CLAVE
           MOVE WS-NRO-MOV TO CTL-VALOR
           WRITE REG-CONTROL

           CLOSE CLIENTES CUENTAS MOVIMIENTOS USUARIOS CONTROL-F

           MOVE BAT-USUARIO TO AUD-USUARIO
           MOVE "CARGA" TO AUD-OPERACION
           MOVE ZERO TO AUD-CUENTA AUD-IMPORTE
           MOVE "OK DATOS DE PRUEBA" TO AUD-RESULTADO
           CALL "AUDITORIA" USING AUD-DATOS
           DISPLAY "OK: Datos de prueba cargados "
                   "(5 clientes, 8 cuentas, 2 usuarios)"
           GOBACK.

       P-CLIENTE.
           INITIALIZE REG-CLIENTE
           MOVE WT-CLI-ID(WS-I)       TO CLI-ID
           MOVE WT-CLI-DOC(WS-I)      TO CLI-DOCUMENTO
           MOVE WT-CLI-NOMBRE(WS-I)   TO CLI-NOMBRE
           MOVE WT-CLI-APELLIDO(WS-I) TO CLI-APELLIDO
           MOVE WT-CLI-NAC(WS-I)      TO CLI-FECHA-NAC
           MOVE "AV. SIEMPRE VIVA 742" TO CLI-DIRECCION
           MOVE "11-5555-0000"        TO CLI-TELEFONO
           SET CLI-ACTIVO TO TRUE
           WRITE REG-CLIENTE.

       P-CUENTA.
           INITIALIZE REG-CUENTA
           MOVE WT-CTA-NRO(WS-I)      TO CTA-NRO
           MOVE WT-CTA-CLIENTE(WS-I)  TO CTA-ID-CLIENTE
           MOVE WT-CTA-TIPO(WS-I)     TO CTA-TIPO
           MOVE WT-CTA-SALDO(WS-I)    TO CTA-SALDO
           MOVE WT-CTA-ESTADO(WS-I)   TO CTA-ESTADO
           MOVE WT-CTA-INTENTOS(WS-I) TO CTA-INTENTOS
           MOVE ZERO TO CTA-RETIRADO-HOY CTA-FECHA-HOY
                        CTA-ULT-INTERES
           MOVE SPACES TO WS-CLAVE-HASH
           STRING WT-CTA-PIN(WS-I) CTA-NRO DELIMITED BY SIZE
               INTO WS-CLAVE-HASH
           END-STRING
           CALL "HASHCLAVE" USING WS-CLAVE-HASH WS-HASH
           MOVE WS-HASH TO CTA-PIN-HASH
           WRITE REG-CUENTA

      *>   El saldo inicial entra como deposito para que la
      *>   reconciliacion cierre.
           IF CTA-SALDO > 0
               ADD 1 TO WS-NRO-MOV
               MOVE WS-NRO-MOV        TO MOV-ID MOV-OPERACION
               MOVE CTA-NRO           TO MOV-NRO-CUENTA
               MOVE WS-AHORA(1:8)     TO MOV-FECHA
               MOVE WS-AHORA(9:6)     TO MOV-HORA
               MOVE "DE"              TO MOV-TIPO
               MOVE CTA-SALDO         TO MOV-IMPORTE MOV-SALDO-POST
               MOVE "Deposito inicial (carga)" TO MOV-DESCRIPCION
               WRITE REG-MOV
           END-IF.

       P-USUARIOS.
           MOVE "CAJERO01" TO USU-ID
           MOVE "1234" TO WS-CLAVE
           PERFORM P-HASH-USUARIO
           SET USU-CAJERO TO TRUE
           MOVE "CAJERO DE PRUEBA" TO USU-NOMBRE
           WRITE REG-USUARIO

           MOVE "SUPER01" TO USU-ID
           MOVE "9999" TO WS-CLAVE
           PERFORM P-HASH-USUARIO
           SET USU-SUPERVISOR TO TRUE
           MOVE "SUPERVISOR DE PRUEBA" TO USU-NOMBRE
           WRITE REG-USUARIO.

      *> Mismo armado que el login de BANCO: clave + usuario.
       P-HASH-USUARIO.
           MOVE SPACES TO WS-CLAVE-HASH
           STRING WS-CLAVE DELIMITED BY SPACE
                  USU-ID DELIMITED BY SPACE
                  INTO WS-CLAVE-HASH
           END-STRING
           CALL "HASHCLAVE" USING WS-CLAVE-HASH WS-HASH
           MOVE WS-HASH TO USU-CLAVE-HASH.
