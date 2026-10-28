      *> Datos de la sesion del usuario logueado. Se pasa a cada
      *> subprograma para auditoria y control de roles.
       01 SESION.
          05 SES-USUARIO        PIC X(8).
          05 SES-ROL            PIC X.
             88 SES-CAJERO      VALUE "C".
             88 SES-SUPERVISOR  VALUE "S".
