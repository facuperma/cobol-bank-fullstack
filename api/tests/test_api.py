import re
from datetime import date


# --- Sesion ------------------------------------------------------------------

def test_login_devuelve_rol(cliente):
    r = cliente.post("/auth/login", json={"usuario": "super01", "clave": "9999"})
    assert r.status_code == 200
    assert r.json()["rol"] == "supervisor"
    assert r.json()["usuario"] == "SUPER01"


def test_login_incorrecto_y_bloqueo_por_intentos(cliente):
    for _ in range(3):
        r = cliente.post("/auth/login", json={"usuario": "CAJERO01", "clave": "mal"})
        assert r.status_code == 401
    r = cliente.post("/auth/login", json={"usuario": "CAJERO01", "clave": "1234"})
    assert r.status_code == 429


def test_sin_token_401(cliente):
    assert cliente.get("/clientes/1").status_code == 401
    r = cliente.get("/clientes/1", headers={"Authorization": "Bearer inventado"})
    assert r.status_code == 401


def test_logout_invalida_el_token(cliente, cajero):
    assert cliente.get("/auth/yo", headers=cajero).status_code == 200
    cliente.post("/auth/logout", headers=cajero)
    assert cliente.get("/auth/yo", headers=cajero).status_code == 401


# --- Clientes y cuentas ------------------------------------------------------

def test_consulta_cliente_con_cuentas(cliente, cajero):
    r = cliente.get("/clientes/1", headers=cajero)
    assert r.status_code == 200
    c = r.json()
    assert (c["apellido"], c["nombre"], c["activo"]) == ("PEREZ", "JUAN", True)
    assert [(x["numero"], x["tipo"], x["saldo"]) for x in c["cuentas"]] == [
        ("1000000001", "ahorro", "1500.00"),
        ("1000000002", "corriente", "3000.00"),
    ]


def test_cliente_inexistente_404(cliente, cajero):
    r = cliente.get("/clientes/999", headers=cajero)
    assert r.status_code == 404
    assert r.json()["detail"] == "Cliente inexistente"


def test_buscar_por_apellido_y_documento(cliente, cajero):
    r = cliente.get("/clientes", params={"apellido": "go"}, headers=cajero)
    assert [c["apellido"] for c in r.json()] == ["GOMEZ"]
    r = cliente.get("/clientes/documento/35555666", headers=cajero)
    assert r.json()["id"] == 3
    assert cliente.get("/clientes", params={"apellido": "zzz"}, headers=cajero).json() == []


def test_alta_apertura_deposito_y_extracto(cliente, cajero):
    r = cliente.post("/clientes", headers=cajero, json={
        "documento": "33444555", "nombre": "Ana", "apellido": "Martínez",
        "fecha_nacimiento": "1995-01-01", "direccion": "Calle 1", "telefono": "11-4444"})
    assert r.status_code == 201, r.text
    nuevo = r.json()
    assert (nuevo["id"], nuevo["apellido"], nuevo["cuentas"]) == (6, "MARTÍNEZ", [])

    r = cliente.post("/cuentas", headers=cajero, json={
        "cliente_id": 6, "tipo": "ahorro", "pin": "1111", "deposito_inicial": "1000"})
    assert r.status_code == 201, r.text
    numero = r.json()["numero"]
    assert numero == "1000000009"

    r = cliente.post("/operaciones/deposito", headers=cajero,
                     json={"cuenta": numero, "importe": "250.75"})
    assert r.json()["saldo"] == "1250.75"

    hoy = date.today().isoformat()
    r = cliente.get(f"/cuentas/{numero}/extracto", headers=cajero,
                    params={"desde": hoy, "hasta": hoy})
    e = r.json()
    assert e["titular"] == "MARTÍNEZ, ANA"
    assert [(x["tipo"], x["importe"]) for x in e["movimientos"]] == [
        ("DE", "1000.00"), ("DE", "250.75")]
    assert e["saldo_final"] == "1250.75"


def test_alta_documento_repetido(cliente, cajero):
    r = cliente.post("/clientes", headers=cajero, json={
        "documento": "30111222", "nombre": "X", "apellido": "Y",
        "fecha_nacimiento": "1990-01-01"})
    assert r.status_code == 400
    assert r.json()["detail"].startswith("Documento ya registrado")


def test_alta_menor_de_edad(cliente, cajero):
    r = cliente.post("/clientes", headers=cajero, json={
        "documento": "44555666", "nombre": "X", "apellido": "Y",
        "fecha_nacimiento": date.today().replace(year=date.today().year - 10).isoformat()})
    assert r.status_code == 400
    assert r.json()["detail"] == "El cliente debe ser mayor de edad"


def test_modificacion_conserva_campos_vacios(cliente, cajero):
    r = cliente.patch("/clientes/1", headers=cajero, json={"telefono": "11-9999"})
    assert r.status_code == 200, r.text
    assert r.json()["telefono"] == "11-9999"
    assert r.json()["direccion"] != ""


def test_baja_con_y_sin_saldo(cliente, cajero):
    r = cliente.delete("/clientes/1", headers=cajero)
    assert r.status_code == 400
    assert r.json()["detail"].startswith("El cliente tiene saldo")
    assert cliente.delete("/clientes/4", headers=cajero).status_code == 200
    assert cliente.get("/clientes/4", headers=cajero).json()["activo"] is False


def test_validacion_de_formato(cliente, cajero):
    r = cliente.post("/operaciones/deposito", headers=cajero,
                     json={"cuenta": "1000000001", "importe": "10.555"})
    assert r.status_code == 422
    assert "importe" in r.json()["detail"]
    r = cliente.post("/clientes", headers=cajero, json={
        "documento": "123", "nombre": "a|b", "apellido": "Y", "fecha_nacimiento": "1990-01-01"})
    assert r.status_code == 422


# --- Operaciones -------------------------------------------------------------

def test_saldo_con_pin(cliente, cajero):
    r = cliente.post("/cuentas/1000000003/saldo", headers=cajero, json={"pin": "2222"})
    assert r.json() == {"numero": "1000000003", "tipo": "ahorro", "saldo": "800.00",
                        "cliente_id": 2, "titular": "GOMEZ, MARIA"}


def test_retiro_saldo_insuficiente(cliente, cajero):
    r = cliente.post("/operaciones/retiro", headers=cajero,
                     json={"cuenta": "1000000004", "pin": "2222", "importe": "100"})
    assert r.status_code == 400
    assert r.json()["detail"] == "Saldo insuficiente"


def test_retiro_limite_diario(cliente, cajero):
    pedido = {"cuenta": "1000000005", "pin": "3333", "importe": "300"}
    assert cliente.post("/operaciones/retiro", headers=cajero, json=pedido).status_code == 200
    r = cliente.post("/operaciones/retiro", headers=cajero, json=pedido)
    assert r.json()["detail"] == "Limite diario superado"


def test_tres_pin_incorrectos_bloquean(cliente, cajero, supervisor):
    for _ in range(3):
        r = cliente.post("/cuentas/1000000001/saldo", headers=cajero, json={"pin": "0000"})
        assert r.status_code == 400
    assert r.json()["detail"] == "PIN incorrecto. Cuenta bloqueada"
    r = cliente.post("/cuentas/1000000001/saldo", headers=cajero, json={"pin": "1234"})
    assert r.json()["detail"] == "Cuenta bloqueada"

    assert cliente.post("/cuentas/1000000001/desbloqueo", headers=cajero).status_code == 403
    r = cliente.post("/cuentas/1000000001/desbloqueo", headers=supervisor)
    assert r.status_code == 200
    r = cliente.post("/cuentas/1000000001/saldo", headers=cajero, json={"pin": "1234"})
    assert r.status_code == 200


def test_transferencia_y_reconciliacion(cliente, cajero, supervisor):
    r = cliente.post("/operaciones/transferencia", headers=cajero, json={
        "origen": "1000000002", "pin": "1234", "destino": "1000000003", "importe": "500"})
    assert r.status_code == 200, r.text
    assert r.json()["saldo"] == "2500.00"

    r = cliente.post("/operaciones/transferencia", headers=cajero, json={
        "origen": "1000000001", "pin": "1234", "destino": "1999999999", "importe": "1"})
    assert r.status_code == 404
    assert r.json()["detail"] == "Cuenta destino inexistente"

    r = cliente.post("/procesos/reconcil", headers=supervisor)
    assert r.json()["rc"] == 0
    assert "OK: Saldos conciliados" in r.json()["salida"]


# --- Procesos ----------------------------------------------------------------

def test_procesos_solo_supervisor(cliente, cajero):
    assert cliente.post("/procesos/cierre", headers=cajero).status_code == 403


def test_intereses_una_vez_y_cierre(cliente, supervisor):
    r = cliente.post("/procesos/interes", headers=supervisor, json={"tasa": "6"})
    assert re.search(r"Intereses pagados  :\s+36\.50", r.json()["salida"])
    r = cliente.post("/procesos/interes", headers=supervisor, json={"tasa": "6"})
    assert re.search(r"Cuentas procesadas :\s+0\b", r.json()["salida"])

    r = cliente.post("/procesos/cierre", headers=supervisor)
    assert r.json()["rc"] == 0
    assert "Depositos" in r.json()["reporte"]


def test_proceso_desconocido(cliente, supervisor):
    assert cliente.post("/procesos/borrar", headers=supervisor).status_code == 404
