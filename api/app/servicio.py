"""Puente con el nucleo COBOL: ejecuta bin/servicio con un pedido por stdin
y separa la respuesta en mensajes OK, errores y lineas de datos "@TIPO|..."."""

import os
import subprocess
import threading
from dataclasses import dataclass, field

from .config import Config


class ErrorServicio(Exception):
    """El nucleo rechazo el pedido (regla de negocio o dato invalido)."""

    def __init__(self, mensaje: str):
        super().__init__(mensaje)
        self.mensaje = mensaje


@dataclass
class Respuesta:
    mensajes: list[str] = field(default_factory=list)
    errores: list[str] = field(default_factory=list)
    datos: list[tuple[str, list[str]]] = field(default_factory=list)
    salida: str = ""

    def filas(self, tipo: str) -> list[list[str]]:
        return [campos for t, campos in self.datos if t == tipo]

    def fila(self, tipo: str) -> list[str] | None:
        filas = self.filas(tipo)
        return filas[0] if filas else None


def interpretar(salida: str) -> Respuesta:
    r = Respuesta(salida=salida)
    for linea in salida.splitlines():
        linea = linea.rstrip()
        if linea.startswith("@"):
            tipo, *campos = linea[1:].split("|")
            r.datos.append((tipo, [c.strip() for c in campos]))
        elif linea.startswith("ERROR:"):
            r.errores.append(linea[len("ERROR:"):].strip())
        elif linea.startswith("OK:"):
            r.mensajes.append(linea[len("OK:"):].strip())
    return r


class Servicio:
    def __init__(self, config: Config):
        self.config = config
        # El nucleo es monousuario (sin bloqueo de registros): los pedidos
        # se atienden de a uno.
        self._lock = threading.Lock()
        self._env = os.environ.copy()
        if config.gnucobol:
            g = config.gnucobol
            self._env["PATH"] = f"{g / 'bin'}{os.pathsep}{self._env.get('PATH', '')}"
            self._env.setdefault("COB_CONFIG_DIR", str(g / "config"))
            self._env.setdefault("COB_LIBRARY_PATH", str(g / "extras"))

    def ejecutar(self, operacion: str, usuario: str, *datos: str) -> Respuesta:
        lineas = [operacion, usuario, *datos]
        for valor in lineas:
            # Un salto de linea correria los datos siguientes; "|" rompe las
            # lineas de respuesta. Los modelos de la API ya los rechazan.
            if any(c in valor for c in "\r\n|"):
                raise ErrorServicio("Caracter no permitido en los datos")
        entrada = ("\n".join(lineas) + "\n").encode("utf-8")
        with self._lock:
            proceso = subprocess.run(
                [str(self.config.servicio)],
                input=entrada,
                capture_output=True,
                cwd=self.config.datos_dir,
                env=self._env,
                timeout=self.config.timeout,
            )
        return interpretar(proceso.stdout.decode("utf-8", errors="replace"))

    def ejecutar_ok(self, operacion: str, usuario: str, *datos: str) -> Respuesta:
        """Como ejecutar, pero un "ERROR:" del nucleo se vuelve excepcion."""
        r = self.ejecutar(operacion, usuario, *datos)
        if r.errores:
            raise ErrorServicio(r.errores[0])
        return r

    def leer_reporte(self, nombre: str) -> str | None:
        ruta = self.config.datos_dir / "reports" / nombre
        if not ruta.is_file():
            return None
        return ruta.read_text(encoding="utf-8", errors="replace")
