"""Sesiones en memoria: token -> usuario. Reiniciar la API cierra todas.

El nucleo COBOL verifica la clave (LOGIN); la API solo recuerda quien
inicio sesion y frena los intentos repetidos de un mismo usuario."""

import secrets
import threading
import time
from dataclasses import dataclass

DURACION = 8 * 3600          # una jornada
MAX_FALLOS = 3               # como el login de la consola
BLOQUEO = 5 * 60


@dataclass(frozen=True)
class Sesion:
    usuario: str
    rol: str                 # "C" cajero, "S" supervisor
    nombre: str
    vence: float

    @property
    def supervisor(self) -> bool:
        return self.rol == "S"


class Sesiones:
    def __init__(self, reloj=time.monotonic):
        self._reloj = reloj
        self._lock = threading.Lock()
        self._por_token: dict[str, Sesion] = {}
        self._fallos: dict[str, tuple[int, float]] = {}

    def bloqueado(self, usuario: str) -> bool:
        with self._lock:
            fallos, desde = self._fallos.get(usuario, (0, 0.0))
            if fallos >= MAX_FALLOS and self._reloj() - desde < BLOQUEO:
                return True
            if fallos >= MAX_FALLOS:
                del self._fallos[usuario]
            return False

    def registrar_fallo(self, usuario: str) -> None:
        with self._lock:
            fallos, _ = self._fallos.get(usuario, (0, 0.0))
            self._fallos[usuario] = (fallos + 1, self._reloj())

    def abrir(self, usuario: str, rol: str, nombre: str) -> str:
        token = secrets.token_urlsafe(32)
        with self._lock:
            self._fallos.pop(usuario, None)
            self._por_token[token] = Sesion(usuario, rol, nombre, self._reloj() + DURACION)
        return token

    def buscar(self, token: str) -> Sesion | None:
        with self._lock:
            sesion = self._por_token.get(token)
            if sesion and sesion.vence < self._reloj():
                del self._por_token[token]
                return None
            return sesion

    def cerrar(self, token: str) -> None:
        with self._lock:
            self._por_token.pop(token, None)
