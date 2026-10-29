"""API REST del sistema bancario. Cada endpoint arma un pedido para
bin/servicio (nucleo COBOL) y traduce su respuesta a JSON.

    uvicorn app.main:app --host 0.0.0.0 --port 8000
"""

from datetime import date
from typing import Annotated

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import Field, StringConstraints

from . import modelos as m
from .config import RAIZ, Config, desde_entorno
from .servicio import ErrorServicio, Servicio
from .sesiones import Sesion, Sesiones

TIPOS = {"A": "ahorro", "C": "corriente"}
ESTADOS_CUENTA = {"A": "abierta", "B": "bloqueada", "C": "cerrada"}

# Menu de CLIENTES en la consola.
CLI_ALTA, CLI_MODIFICACION, CLI_BAJA, CLI_CONSULTA, CLI_DOCUMENTO, CLI_APELLIDO = "123456"

# Informe que deja cada proceso en reports/.
REPORTES = {
    "INTERES": None,
    "CIERRE": "CIERRE_{periodo}.txt",
    "RECONCIL": "DISCREPANCIAS.txt",
    "RANKING": "RANKING_CLIENTES.txt",
    "EXPORTA": "EXPORT_{periodo}.txt",
}


def _fecha(aaaammdd: str) -> date:
    return date(int(aaaammdd[:4]), int(aaaammdd[4:6]), int(aaaammdd[6:8]))


def _aaaammdd(fecha: date) -> str:
    return fecha.strftime("%Y%m%d")


def _cliente(c: list[str]) -> dict:
    return dict(id=int(c[0]), documento=c[1], nombre=c[2], apellido=c[3],
                fecha_nacimiento=_fecha(c[4]), direccion=c[5], telefono=c[6],
                activo=c[7] == "A")


def _cuenta(c: list[str]) -> m.Cuenta:
    return m.Cuenta(numero=c[0], tipo=TIPOS[c[1]], saldo=c[2], estado=ESTADOS_CUENTA[c[3]])


def _usuario(s: Sesion) -> dict:
    return dict(usuario=s.usuario, rol="supervisor" if s.supervisor else "cajero",
                nombre=s.nombre)


def create_app(config: Config | None = None) -> FastAPI:
    app = FastAPI(title="Banco COBOL", version="1.0")
    app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"],
                       allow_headers=["*"])
    servicio = Servicio(config or desde_entorno())
    sesiones = Sesiones()
    app.state.servicio = servicio
    app.state.sesiones = sesiones

    # --- Errores: siempre {"detail": "<texto>"} para que la app lo muestre.

    @app.exception_handler(ErrorServicio)
    def _error_servicio(_: Request, e: ErrorServicio):
        texto = e.mensaje.lower()
        codigo = 404 if "inexistente" in texto or "no hay clientes" in texto else 400
        return JSONResponse({"detail": e.mensaje}, status_code=codigo)

    @app.exception_handler(RequestValidationError)
    def _error_validacion(_: Request, e: RequestValidationError):
        errores = []
        for err in e.errors():
            campo = ".".join(str(p) for p in err["loc"] if p not in ("body", "query", "path"))
            errores.append(f"{campo}: {err['msg']}" if campo else err["msg"])
        return JSONResponse({"detail": "; ".join(errores)}, status_code=422)

    # --- Autenticacion

    def sesion_actual(authorization: Annotated[str | None, Header()] = None) -> Sesion:
        token = (authorization or "").removeprefix("Bearer ").strip()
        sesion = sesiones.buscar(token) if token else None
        if not sesion:
            raise HTTPException(401, "Sesion invalida o vencida")
        return sesion

    def supervisor(sesion: Annotated[Sesion, Depends(sesion_actual)]) -> Sesion:
        if not sesion.supervisor:
            raise HTTPException(403, "Operacion reservada a supervisores")
        return sesion

    Actual = Annotated[Sesion, Depends(sesion_actual)]
    Supervisor = Annotated[Sesion, Depends(supervisor)]

    @app.post("/auth/login", response_model=m.SesionAbierta, tags=["sesion"])
    def login(datos: m.Login):
        usuario = datos.usuario.upper()
        if sesiones.bloqueado(usuario):
            raise HTTPException(429, "Demasiados intentos. Espere unos minutos")
        r = servicio.ejecutar("LOGIN", usuario, datos.clave)
        fila = r.fila("USUARIO")
        if r.errores or not fila:
            sesiones.registrar_fallo(usuario)
            raise HTTPException(401, "Usuario o clave incorrectos")
        token = sesiones.abrir(fila[0], fila[1], fila[2])
        return m.SesionAbierta(token=token, **_usuario(sesiones.buscar(token)))

    @app.post("/auth/logout", response_model=m.Mensaje, tags=["sesion"])
    def logout(authorization: Annotated[str | None, Header()] = None):
        sesiones.cerrar((authorization or "").removeprefix("Bearer ").strip())
        return m.Mensaje(mensaje="Sesion finalizada")

    @app.get("/auth/yo", response_model=m.Usuario, tags=["sesion"])
    def yo(sesion: Actual):
        return _usuario(sesion)

    # --- Clientes

    def _detalle(r) -> m.ClienteDetalle:
        fila = r.fila("CLIENTE")
        if not fila:
            raise ErrorServicio("Cliente inexistente")
        return m.ClienteDetalle(**_cliente(fila), cuentas=[_cuenta(c) for c in r.filas("CUENTA")])

    @app.get("/clientes", response_model=list[m.Cliente], tags=["clientes"])
    def buscar_clientes(sesion: Actual,
                        apellido: Annotated[str, Query(min_length=1, max_length=30,
                                                       pattern=r"^[^|\r\n]+$")]):
        r = servicio.ejecutar_ok("CLIENTES", sesion.usuario, CLI_APELLIDO, apellido)
        return [_cliente(c) for c in r.filas("CLIENTE")]

    @app.get("/clientes/documento/{documento}", response_model=m.ClienteDetalle,
             tags=["clientes"])
    def cliente_por_documento(sesion: Actual,
                              documento: Annotated[str, StringConstraints(pattern=r"^\d{7,12}$")]):
        return _detalle(servicio.ejecutar_ok("CLIENTES", sesion.usuario, CLI_DOCUMENTO, documento))

    @app.get("/clientes/{cliente_id}", response_model=m.ClienteDetalle, tags=["clientes"])
    def cliente(sesion: Actual, cliente_id: Annotated[int, Field(ge=1, le=999999)]):
        return _detalle(servicio.ejecutar_ok("CLIENTES", sesion.usuario, CLI_CONSULTA,
                                             str(cliente_id)))

    @app.post("/clientes", response_model=m.ClienteDetalle, status_code=201, tags=["clientes"])
    def alta_cliente(sesion: Actual, datos: m.ClienteNuevo):
        r = servicio.ejecutar_ok("CLIENTES", sesion.usuario, CLI_ALTA, datos.documento,
                                 datos.nombre.upper(), datos.apellido.upper(),
                                 _aaaammdd(datos.fecha_nacimiento), datos.direccion,
                                 datos.telefono)
        return cliente(sesion, int(r.fila("ID")[0]))

    @app.patch("/clientes/{cliente_id}", response_model=m.ClienteDetalle, tags=["clientes"])
    def modificar_cliente(sesion: Actual, cliente_id: Annotated[int, Field(ge=1, le=999999)],
                          datos: m.ClienteCambios):
        servicio.ejecutar_ok("CLIENTES", sesion.usuario, CLI_MODIFICACION, str(cliente_id),
                             datos.direccion, datos.telefono)
        return cliente(sesion, cliente_id)

    @app.delete("/clientes/{cliente_id}", response_model=m.Mensaje, tags=["clientes"])
    def baja_cliente(sesion: Actual, cliente_id: Annotated[int, Field(ge=1, le=999999)]):
        r = servicio.ejecutar_ok("CLIENTES", sesion.usuario, CLI_BAJA, str(cliente_id))
        return m.Mensaje(mensaje=r.mensajes[0] if r.mensajes else "Cliente dado de baja")

    # --- Cuentas

    @app.post("/cuentas", response_model=m.Cuenta, status_code=201, tags=["cuentas"])
    def apertura(sesion: Actual, datos: m.CuentaNueva):
        tipo = "A" if datos.tipo == "ahorro" else "C"
        r = servicio.ejecutar_ok("APERTURA", sesion.usuario, str(datos.cliente_id), tipo,
                                 datos.pin, datos.pin, m.texto_importe(datos.deposito_inicial))
        return m.Cuenta(numero=r.fila("CUENTA")[0], tipo=datos.tipo,
                        saldo=m.texto_importe(datos.deposito_inicial), estado="abierta")

    @app.post("/cuentas/{numero}/saldo", response_model=m.Saldo, tags=["cuentas"])
    def saldo(sesion: Actual, numero: m.NroCuenta, datos: m.ConPin):
        c = servicio.ejecutar_ok("SALDO", sesion.usuario, numero, datos.pin).fila("SALDO")
        return m.Saldo(numero=c[0], tipo=TIPOS[c[1]], saldo=c[2], cliente_id=int(c[3]),
                       titular=c[4])

    @app.post("/cuentas/{numero}/desbloqueo", response_model=m.Mensaje, tags=["cuentas"])
    def desbloqueo(sesion: Supervisor, numero: m.NroCuenta):
        r = servicio.ejecutar_ok("DESBLOQUEO", sesion.usuario, numero)
        return m.Mensaje(mensaje=r.mensajes[0])

    @app.get("/cuentas/{numero}/extracto", response_model=m.Extracto, tags=["cuentas"])
    def extracto(sesion: Actual, numero: m.NroCuenta, desde: date, hasta: date):
        r = servicio.ejecutar_ok("EXTRACTO", sesion.usuario, numero, _aaaammdd(desde),
                                 _aaaammdd(hasta))
        t = r.fila("TOTALES")
        movimientos = [
            m.Movimiento(fecha=_fecha(v[0]), hora=f"{v[1][:2]}:{v[1][2:4]}:{v[1][4:6]}",
                         tipo=v[2], importe=v[3], saldo=v[4], operacion=int(v[5]),
                         descripcion=v[6])
            for v in r.filas("MOV")
        ]
        return m.Extracto(cuenta=t[0], titular=t[1], desde=desde, hasta=hasta,
                          saldo_inicial=t[3], creditos=t[4], debitos=t[5], saldo_final=t[6],
                          movimientos=movimientos)

    # --- Operaciones

    def _resultado(r) -> m.ResultadoOperacion:
        return m.ResultadoOperacion(mensaje=r.mensajes[0], saldo=r.fila("SALDO")[0],
                                    operacion=int(r.fila("OPERACION")[0]))

    @app.post("/operaciones/deposito", response_model=m.ResultadoOperacion, tags=["operaciones"])
    def deposito(sesion: Actual, datos: m.Deposito):
        return _resultado(servicio.ejecutar_ok("DEPOSITO", sesion.usuario, datos.cuenta,
                                               m.texto_importe(datos.importe)))

    @app.post("/operaciones/retiro", response_model=m.ResultadoOperacion, tags=["operaciones"])
    def retiro(sesion: Actual, datos: m.Retiro):
        return _resultado(servicio.ejecutar_ok("RETIRO", sesion.usuario, datos.cuenta, datos.pin,
                                               m.texto_importe(datos.importe)))

    @app.post("/operaciones/transferencia", response_model=m.ResultadoOperacion,
              tags=["operaciones"])
    def transferencia(sesion: Actual, datos: m.Transferencia):
        return _resultado(servicio.ejecutar_ok("TRANSFERENCIA", sesion.usuario, datos.origen,
                                               datos.pin, datos.destino,
                                               m.texto_importe(datos.importe)))

    # --- Procesos batch (supervisor)

    @app.post("/procesos/{proceso}", response_model=m.ResultadoProceso, tags=["procesos"])
    def proceso(sesion: Supervisor, proceso: str, datos: m.Proceso | None = None):
        nombre = proceso.upper()
        if nombre not in REPORTES:
            raise HTTPException(404, f"Proceso desconocido: {proceso}")
        datos = datos or m.Proceso()
        tasa = f"{datos.tasa:.2f}" if datos.tasa is not None else ""
        r = servicio.ejecutar_ok(nombre, sesion.usuario, datos.periodo or "", tasa)
        periodo = r.fila("PERIODO")[0]
        archivo = REPORTES[nombre]
        salida = "\n".join(l for l in r.salida.splitlines() if not l.startswith("@"))
        return m.ResultadoProceso(
            proceso=nombre, periodo=periodo, rc=int(r.fila("RC")[0]), salida=salida,
            reporte=servicio.leer_reporte(archivo.format(periodo=periodo)) if archivo else None,
        )

    # Version web de la app (flutter build web --base-href /app/), si existe.
    web = RAIZ / "app" / "build" / "web"
    if web.is_dir():
        app.mount("/app", StaticFiles(directory=web, html=True), name="app")

    return app


app = create_app()
