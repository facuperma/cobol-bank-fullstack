// Cliente de la API REST (api/). Los importes viajan como texto ("1500.00")
// igual que en la API: nunca se convierten a double.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.mensaje, [this.status]);

  final String mensaje;
  final int? status;

  @override
  String toString() => mensaje;
}

class Usuario {
  Usuario.fromJson(Map<String, dynamic> j)
      : usuario = j['usuario'],
        rol = j['rol'],
        nombre = j['nombre'];

  final String usuario;
  final String rol;
  final String nombre;

  bool get supervisor => rol == 'supervisor';
}

class Cuenta {
  Cuenta.fromJson(Map<String, dynamic> j)
      : numero = j['numero'],
        tipo = j['tipo'],
        saldo = j['saldo'],
        estado = j['estado'];

  final String numero;
  final String tipo; // ahorro | corriente
  final String saldo;
  final String estado; // abierta | bloqueada | cerrada

  String get tipoTexto => tipo == 'ahorro' ? 'Caja de ahorro' : 'Cuenta corriente';
}

class Cliente {
  Cliente.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        documento = j['documento'],
        nombre = j['nombre'],
        apellido = j['apellido'],
        fechaNacimiento = DateTime.parse(j['fecha_nacimiento']),
        direccion = j['direccion'],
        telefono = j['telefono'],
        activo = j['activo'],
        cuentas = [for (final c in j['cuentas'] ?? const []) Cuenta.fromJson(c)];

  final int id;
  final String documento;
  final String nombre;
  final String apellido;
  final DateTime fechaNacimiento;
  final String direccion;
  final String telefono;
  final bool activo;
  final List<Cuenta> cuentas;

  String get nombreCompleto => '$apellido, $nombre';
  String get numero => id.toString().padLeft(6, '0');
}

class Saldo {
  Saldo.fromJson(Map<String, dynamic> j)
      : numero = j['numero'],
        tipo = j['tipo'],
        saldo = j['saldo'],
        clienteId = j['cliente_id'],
        titular = j['titular'];

  final String numero;
  final String tipo;
  final String saldo;
  final int clienteId;
  final String titular;
}

class Resultado {
  Resultado.fromJson(Map<String, dynamic> j)
      : mensaje = j['mensaje'],
        saldo = j['saldo'],
        operacion = j['operacion'];

  final String mensaje;
  final String saldo;
  final int operacion;
}

class Movimiento {
  Movimiento.fromJson(Map<String, dynamic> j)
      : fecha = DateTime.parse(j['fecha']),
        hora = j['hora'],
        tipo = j['tipo'],
        importe = j['importe'],
        saldo = j['saldo'],
        operacion = j['operacion'],
        descripcion = j['descripcion'];

  final DateTime fecha;
  final String hora;
  final String tipo; // DE RE TD TC IN
  final String importe;
  final String saldo;
  final int operacion;
  final String descripcion;

  bool get esCredito => tipo == 'DE' || tipo == 'TC' || tipo == 'IN';

  String get tipoTexto => const {
        'DE': 'Depósito',
        'RE': 'Retiro',
        'TD': 'Transferencia enviada',
        'TC': 'Transferencia recibida',
        'IN': 'Intereses',
      }[tipo]!;
}

class Extracto {
  Extracto.fromJson(Map<String, dynamic> j)
      : cuenta = j['cuenta'],
        titular = j['titular'],
        saldoInicial = j['saldo_inicial'],
        creditos = j['creditos'],
        debitos = j['debitos'],
        saldoFinal = j['saldo_final'],
        movimientos = [for (final m in j['movimientos']) Movimiento.fromJson(m)];

  final String cuenta;
  final String titular;
  final String saldoInicial;
  final String creditos;
  final String debitos;
  final String saldoFinal;
  final List<Movimiento> movimientos;
}

class ResultadoProceso {
  ResultadoProceso.fromJson(Map<String, dynamic> j)
      : proceso = j['proceso'],
        periodo = j['periodo'],
        rc = j['rc'],
        salida = j['salida'],
        reporte = j['reporte'];

  final String proceso;
  final String periodo;
  final int rc;
  final String salida;
  final String? reporte;
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Sesion con la API. Avisa a los oyentes cuando se inicia o se cierra
/// (tambien si el servidor responde 401 porque la sesion vencio).
class Api extends ChangeNotifier {
  Api(this.baseUrl, {http.Client? cliente}) : _http = cliente ?? http.Client();

  String baseUrl;
  final http.Client _http;
  String? _token;
  Usuario? _usuario;

  Usuario? get usuario => _usuario;

  Future<dynamic> _pedir(String metodo, String ruta,
      {Object? cuerpo, Map<String, String>? query}) async {
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    http.Response r;
    try {
      var uri = Uri.parse('$base$ruta');
      if (query != null) uri = uri.replace(queryParameters: query);
      final pedido = http.Request(metodo, uri)
        ..headers['Content-Type'] = 'application/json';
      if (_token != null) pedido.headers['Authorization'] = 'Bearer $_token';
      if (cuerpo != null) pedido.body = jsonEncode(cuerpo);
      r = await http.Response.fromStream(
          await _http.send(pedido).timeout(const Duration(seconds: 30)));
    } catch (_) {
      throw ApiException('No se pudo conectar con el servidor ($base)');
    }

    final datos = r.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 400) {
      if (r.statusCode == 401 && _token != null) _cerrarLocal();
      final detalle = datos is Map && datos['detail'] is String
          ? datos['detail'] as String
          : 'Error ${r.statusCode}';
      throw ApiException(detalle, r.statusCode);
    }
    return datos;
  }

  void _cerrarLocal() {
    _token = null;
    _usuario = null;
    notifyListeners();
  }

  // --- Sesion

  Future<void> login(String usuario, String clave) async {
    final j = await _pedir('POST', '/auth/login', cuerpo: {'usuario': usuario, 'clave': clave});
    _token = j['token'];
    _usuario = Usuario.fromJson(j);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _pedir('POST', '/auth/logout');
    } on ApiException {
      // Se cierra localmente aunque el servidor no responda.
    }
    _cerrarLocal();
  }

  // --- Clientes

  Future<List<Cliente>> buscarPorApellido(String apellido) async {
    final j = await _pedir('GET', '/clientes', query: {'apellido': apellido});
    return [for (final c in j) Cliente.fromJson(c)];
  }

  Future<Cliente> cliente(int id) async => Cliente.fromJson(await _pedir('GET', '/clientes/$id'));

  Future<Cliente> clientePorDocumento(String documento) async =>
      Cliente.fromJson(await _pedir('GET', '/clientes/documento/$documento'));

  Future<Cliente> altaCliente({
    required String documento,
    required String nombre,
    required String apellido,
    required DateTime fechaNacimiento,
    String direccion = '',
    String telefono = '',
  }) async =>
      Cliente.fromJson(await _pedir('POST', '/clientes', cuerpo: {
        'documento': documento,
        'nombre': nombre,
        'apellido': apellido,
        'fecha_nacimiento': _iso(fechaNacimiento),
        'direccion': direccion,
        'telefono': telefono,
      }));

  Future<Cliente> modificarCliente(int id, {String direccion = '', String telefono = ''}) async =>
      Cliente.fromJson(await _pedir('PATCH', '/clientes/$id',
          cuerpo: {'direccion': direccion, 'telefono': telefono}));

  Future<String> bajaCliente(int id) async =>
      (await _pedir('DELETE', '/clientes/$id'))['mensaje'];

  // --- Cuentas

  Future<Cuenta> abrirCuenta({
    required int clienteId,
    required String tipo,
    required String pin,
    String depositoInicial = '0',
  }) async =>
      Cuenta.fromJson(await _pedir('POST', '/cuentas', cuerpo: {
        'cliente_id': clienteId,
        'tipo': tipo,
        'pin': pin,
        'deposito_inicial': depositoInicial,
      }));

  Future<Saldo> saldo(String cuenta, String pin) async =>
      Saldo.fromJson(await _pedir('POST', '/cuentas/$cuenta/saldo', cuerpo: {'pin': pin}));

  Future<String> desbloquear(String cuenta) async =>
      (await _pedir('POST', '/cuentas/$cuenta/desbloqueo'))['mensaje'];

  Future<Extracto> extracto(String cuenta, DateTime desde, DateTime hasta) async =>
      Extracto.fromJson(await _pedir('GET', '/cuentas/$cuenta/extracto',
          query: {'desde': _iso(desde), 'hasta': _iso(hasta)}));

  // --- Operaciones

  Future<Resultado> deposito(String cuenta, String importe) async => Resultado.fromJson(
      await _pedir('POST', '/operaciones/deposito', cuerpo: {'cuenta': cuenta, 'importe': importe}));

  Future<Resultado> retiro(String cuenta, String pin, String importe) async =>
      Resultado.fromJson(await _pedir('POST', '/operaciones/retiro',
          cuerpo: {'cuenta': cuenta, 'pin': pin, 'importe': importe}));

  Future<Resultado> transferencia(String origen, String pin, String destino, String importe) async =>
      Resultado.fromJson(await _pedir('POST', '/operaciones/transferencia',
          cuerpo: {'origen': origen, 'pin': pin, 'destino': destino, 'importe': importe}));

  // --- Procesos (supervisor)

  Future<ResultadoProceso> proceso(String nombre, {String? periodo, String? tasa}) async =>
      ResultadoProceso.fromJson(await _pedir('POST', '/procesos/$nombre', cuerpo: {
        if (periodo != null && periodo.isNotEmpty) 'periodo': periodo,
        if (tasa != null && tasa.isNotEmpty) 'tasa': tasa,
      }));
}
