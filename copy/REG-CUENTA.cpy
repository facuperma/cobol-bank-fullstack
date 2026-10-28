      *> Registro de cuenta (CUENTAS.DAT, indexado).
      *> Los importes van en COMP-3 (decimal empaquetado): nunca
      *> punto flotante para dinero.
       01 REG-CUENTA.
          05 CTA-NRO            PIC 9(10).
          05 CTA-ID-CLIENTE     PIC 9(6).
          05 CTA-TIPO           PIC X.
             88 CTA-AHORRO      VALUE "A".
             88 CTA-CORRIENTE   VALUE "C".
          05 CTA-SALDO          PIC S9(11)V99 COMP-3.
          05 CTA-PIN-HASH       PIC 9(8).
          05 CTA-INTENTOS       PIC 9.
          05 CTA-ESTADO         PIC X.
             88 CTA-ABIERTA     VALUE "A".
             88 CTA-BLOQUEADA   VALUE "B".
             88 CTA-CERRADA     VALUE "C".
          05 CTA-RETIRADO-HOY   PIC S9(9)V99 COMP-3.
          05 CTA-FECHA-HOY      PIC 9(8).
      *>  Ultimo periodo (AAAAMM) en que se pagaron intereses:
      *>  hace idempotente al batch de intereses.
          05 CTA-ULT-INTERES    PIC 9(6).
