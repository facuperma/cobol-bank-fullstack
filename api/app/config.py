"""Configuracion de la API, tomada de variables de entorno.

BANCO_BIN       carpeta con servicio(.exe)           (defecto: <raiz>/bin)
BANCO_DATOS     carpeta que contiene data/ y reports/ (defecto: <raiz>)
GNUCOBOL_HOME   instalacion de GnuCOBOL en Windows, para que el
                ejecutable encuentre sus DLL (opcional si ya esta en el PATH)
"""

import os
import sys
from dataclasses import dataclass
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class Config:
    bin_dir: Path
    datos_dir: Path
    gnucobol: Path | None = None
    timeout: float = 30.0

    @property
    def servicio(self) -> Path:
        nombre = "servicio.exe" if sys.platform == "win32" else "servicio"
        return self.bin_dir / nombre


def desde_entorno() -> Config:
    gnucobol = os.environ.get("GNUCOBOL_HOME")
    return Config(
        bin_dir=Path(os.environ.get("BANCO_BIN", RAIZ / "bin")),
        datos_dir=Path(os.environ.get("BANCO_DATOS", RAIZ)),
        gnucobol=Path(gnucobol) if gnucobol else None,
    )
