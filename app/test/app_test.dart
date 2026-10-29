// Pruebas de interfaz con una API simulada (no hace falta el servidor).

import 'dart:convert';

import 'package:banco_cobol/api.dart';
import 'package:banco_cobol/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object cuerpo, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(cuerpo)), status,
    headers: {'content-type': 'application/json'});

Api _api(Map<String, http.Response Function(http.Request)> rutas, {List<http.Request>? pedidos}) =>
    Api('http://banco.test', cliente: MockClient((pedido) async {
      pedidos?.add(pedido);
      final ruta = '${pedido.method} ${pedido.url.path}';
      final r = rutas[ruta];
      return r == null ? _json({'detail': 'Sin ruta $ruta'}, 404) : r(pedido);
    }));

final _login = {
  'POST /auth/login': (http.Request p) {
    final datos = jsonDecode(p.body);
    if (datos['clave'] != '1234') return _json({'detail': 'Usuario o clave incorrectos'}, 401);
    return _json({'token': 't', 'usuario': 'CAJERO01', 'rol': 'cajero', 'nombre': 'CAJERO DE PRUEBA'});
  },
};

Future<void> _ingresar(WidgetTester tester, String clave) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Usuario'), 'cajero01');
  await tester.enterText(find.widgetWithText(TextFormField, 'Clave'), clave);
  await tester.tap(find.text('Ingresar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login incorrecto muestra el error; correcto entra sin menu de supervisor', (tester) async {
    await tester.pumpWidget(BancoApp(api: _api(_login)));

    await _ingresar(tester, 'mal');
    expect(find.text('Usuario o clave incorrectos'), findsOneWidget);

    await _ingresar(tester, '1234');
    expect(find.text('Operaciones'), findsWidgets);
    expect(find.text('Supervisor'), findsNothing);
  });

  testWidgets('deposito: valida el importe, confirma y muestra el saldo nuevo', (tester) async {
    final pedidos = <http.Request>[];
    final api = _api({
      ..._login,
      'POST /operaciones/deposito': (_) =>
          _json({'mensaje': 'Deposito acreditado. Saldo: 1,750.50', 'saldo': '1750.50', 'operacion': 7}),
    }, pedidos: pedidos);
    await tester.pumpWidget(BancoApp(api: api));
    await _ingresar(tester, '1234');

    await tester.tap(find.text('Operaciones').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Número de cuenta').first, '1000000001');
    await tester.enterText(find.widgetWithText(TextFormField, 'Importe').first, '10,555');
    await tester.tap(find.widgetWithText(FilledButton, 'Depositar'));
    await tester.pumpAndSettle();
    expect(find.text('Importe inválido (hasta 2 decimales)'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Importe').first, '250,5');
    await tester.tap(find.widgetWithText(FilledButton, 'Depositar'));
    await tester.pumpAndSettle();
    expect(find.text(r'Depositar $ 250,50'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Depositar').last);
    await tester.pumpAndSettle();

    final deposito = pedidos.last;
    expect(deposito.headers['Authorization'], 'Bearer t');
    expect(jsonDecode(deposito.body), {'cuenta': '1000000001', 'importe': '250.50'});
    expect(find.text(r'Saldo: $ 1.750,50'), findsOneWidget);
  });

  testWidgets('sesion vencida (401) vuelve al login', (tester) async {
    final api = _api({
      ..._login,
      'GET /clientes': (_) => _json({'detail': 'Sesion invalida o vencida'}, 401),
    });
    await tester.pumpWidget(BancoApp(api: api));
    await _ingresar(tester, '1234');

    await tester.enterText(find.byType(TextField).first, 'PE');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
