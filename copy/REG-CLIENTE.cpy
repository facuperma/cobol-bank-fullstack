      *> Registro de cliente (CLIENTES.DAT, indexado).
       01 REG-CLIENTE.
          05 CLI-ID             PIC 9(6).
          05 CLI-DOCUMENTO      PIC X(12).
          05 CLI-NOMBRE         PIC X(30).
          05 CLI-APELLIDO       PIC X(30).
          05 CLI-FECHA-NAC      PIC 9(8).
          05 CLI-DIRECCION      PIC X(50).
          05 CLI-TELEFONO       PIC X(15).
          05 CLI-ESTADO         PIC X.
             88 CLI-ACTIVO      VALUE "A".
             88 CLI-INACTIVO    VALUE "I".
