      *> Registro de usuario del sistema (USUARIOS.DAT, indexado).
       01 REG-USUARIO.
          05 USU-ID             PIC X(8).
          05 USU-CLAVE-HASH     PIC 9(8).
          05 USU-ROL            PIC X.
             88 USU-CAJERO      VALUE "C".
             88 USU-SUPERVISOR  VALUE "S".
          05 USU-NOMBRE         PIC X(30).
