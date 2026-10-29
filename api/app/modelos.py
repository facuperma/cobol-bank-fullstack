"""Modelos de pedido y respuesta. Validan el formato (largo, digitos,
decimales) para dar errores claros por campo; las reglas de negocio las
sigue aplicando el nucleo COBOL. Los importes viajan como texto ("1500.00")
para no pasar nunca por punto flotante."""

from datetime import date
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import AfterValidator, BaseModel, Field, StringConstraints

# Texto libre: sin "|" ni saltos de linea, que el protocolo usa como
# separadores, y con un largo maximo en bytes (los campos COBOL son de ancho
# fijo en bytes y un acento ocupa dos).


def _texto(maximo: int):
    def validar(valor: str) -> str:
        if any(c in valor for c in "|\r\n"):
            raise ValueError("no puede contener '|' ni saltos de linea")
        if len(valor.encode("utf-8")) > maximo:
            raise ValueError(f"maximo {maximo} caracteres")
        return valor

    return Annotated[str, StringConstraints(strip_whitespace=True), AfterValidator(validar)]


def _importe(valor: Decimal) -> Decimal:
    if valor.as_tuple().exponent < -2:
        raise ValueError("maximo 2 decimales")
    return valor


Pin = Annotated[str, StringConstraints(pattern=r"^\d{4}$")]
NroCuenta = Annotated[str, StringConstraints(pattern=r"^\d{1,10}$")]
Importe = Annotated[Decimal, Field(gt=0, le=Decimal("999999999.99")), AfterValidator(_importe)]
ImporteOCero = Annotated[Decimal, Field(ge=0, le=Decimal("999999999.99")), AfterValidator(_importe)]


def texto_importe(valor: Decimal) -> str:
    return f"{valor:.2f}"


# --- Pedidos ---------------------------------------------------------------

class Login(BaseModel):
    usuario: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=8,
                                              pattern=r"^[A-Za-z0-9]+$")]
    clave: _texto(20)


class ClienteNuevo(BaseModel):
    documento: Annotated[str, StringConstraints(pattern=r"^\d{7,12}$")]
    nombre: Annotated[_texto(30), StringConstraints(min_length=1)]
    apellido: Annotated[_texto(30), StringConstraints(min_length=1)]
    fecha_nacimiento: date
    direccion: _texto(50) = ""
    telefono: _texto(15) = ""


class ClienteCambios(BaseModel):
    """Un campo vacio u omitido conserva el valor actual."""
    direccion: _texto(50) = ""
    telefono: _texto(15) = ""


class CuentaNueva(BaseModel):
    cliente_id: Annotated[int, Field(ge=1, le=999999)]
    tipo: Literal["ahorro", "corriente"]
    pin: Pin
    deposito_inicial: ImporteOCero = Decimal("0")


class ConPin(BaseModel):
    pin: Pin


class Deposito(BaseModel):
    cuenta: NroCuenta
    importe: Importe


class Retiro(BaseModel):
    cuenta: NroCuenta
    pin: Pin
    importe: Importe


class Transferencia(BaseModel):
    origen: NroCuenta
    pin: Pin
    destino: NroCuenta
    importe: Importe


class Proceso(BaseModel):
    periodo: Annotated[str, StringConstraints(pattern=r"^\d{4}(0[1-9]|1[0-2])$")] | None = None
    tasa: Annotated[Decimal, Field(ge=0, le=100)] | None = None


# --- Respuestas ------------------------------------------------------------

class Usuario(BaseModel):
    usuario: str
    rol: Literal["cajero", "supervisor"]
    nombre: str


class SesionAbierta(Usuario):
    token: str


class Cuenta(BaseModel):
    numero: str
    tipo: Literal["ahorro", "corriente"]
    saldo: str
    estado: Literal["abierta", "bloqueada", "cerrada"]


class Cliente(BaseModel):
    id: int
    documento: str
    nombre: str
    apellido: str
    fecha_nacimiento: date
    direccion: str
    telefono: str
    activo: bool


class ClienteDetalle(Cliente):
    cuentas: list[Cuenta]


class Saldo(BaseModel):
    numero: str
    tipo: Literal["ahorro", "corriente"]
    saldo: str
    cliente_id: int
    titular: str


class ResultadoOperacion(BaseModel):
    mensaje: str
    saldo: str
    operacion: int


class Movimiento(BaseModel):
    fecha: date
    hora: str
    tipo: Literal["DE", "RE", "TD", "TC", "IN"]
    importe: str
    saldo: str
    operacion: int
    descripcion: str


class Extracto(BaseModel):
    cuenta: str
    titular: str
    desde: date
    hasta: date
    saldo_inicial: str
    creditos: str
    debitos: str
    saldo_final: str
    movimientos: list[Movimiento]


class Mensaje(BaseModel):
    mensaje: str


class ResultadoProceso(BaseModel):
    proceso: str
    periodo: str
    rc: int
    salida: str
    reporte: str | None
