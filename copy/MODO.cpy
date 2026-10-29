      *> Modo de ejecucion, compartido por todos los programas del
      *> ejecutable (EXTERNAL). SERVICIO lo pone en "S": la entrada
      *> llega sin prompts por stdin y las respuestas incluyen
      *> lineas de datos "@..." para la API. Cualquier otro valor
      *> es el modo interactivo de la consola.
       01 MODO-EJECUCION        PIC X EXTERNAL.
          88 MODO-SERVICIO      VALUE "S".
