"""Cada prueba usa el nucleo COBOL real sobre una copia nueva de los datos
de prueba (batch CARGA) en una carpeta temporal.

BANCO_BIN elige otra carpeta de ejecutables; GNUCOBOL_HOME, la instalacion
de GnuCOBOL si no esta en el PATH."""

import os
import subprocess
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.config import RAIZ, Config
from app.main import create_app

BIN = os.environ.get("BANCO_BIN", str(RAIZ / "bin"))
GNUCOBOL = os.environ.get("GNUCOBOL_HOME")


@pytest.fixture
def config(tmp_path):
    (tmp_path / "data").mkdir()
    (tmp_path / "reports").mkdir()
    cfg = Config(bin_dir=Path(BIN), datos_dir=tmp_path,
                 gnucobol=Path(GNUCOBOL) if GNUCOBOL else None)
    batch = cfg.bin_dir / ("batch.exe" if sys.platform == "win32" else "batch")
    env = os.environ.copy()
    if cfg.gnucobol:
        env["PATH"] = f"{cfg.gnucobol / 'bin'}{os.pathsep}{env['PATH']}"
    subprocess.run([str(batch), "CARGA", "CONFIRMAR"], cwd=tmp_path, env=env,
                   capture_output=True, check=True)
    return cfg


@pytest.fixture
def cliente(config):
    return TestClient(create_app(config))


def _login(cliente, usuario, clave):
    r = cliente.post("/auth/login", json={"usuario": usuario, "clave": clave})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['token']}"}


@pytest.fixture
def cajero(cliente):
    return _login(cliente, "CAJERO01", "1234")


@pytest.fixture
def supervisor(cliente):
    return _login(cliente, "SUPER01", "9999")
