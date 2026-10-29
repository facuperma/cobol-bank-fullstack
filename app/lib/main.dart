// App para empleados del banco (cajeros y supervisores). Usa la API REST,
// que a su vez usa el nucleo COBOL.
//
// La direccion de la API se fija al compilar y se puede cambiar en el login:
//   flutter build apk --dart-define=API_URL=http://192.168.0.10:8000

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api.dart';
import 'comun.dart';
import 'pantallas/inicio.dart';
import 'pantallas/login.dart';

const apiPorDefecto = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8000');

/// En la web servida por la propia API (/app/) se usa ese mismo servidor.
String get _apiInicial =>
    kIsWeb && Uri.base.path.startsWith('/app/') ? Uri.base.origin : apiPorDefecto;

void main() => runApp(BancoApp(api: Api(_apiInicial)));

const _semilla = Color(0xFF0B5563);

ThemeData _tema(Brightness brillo) {
  final colores = ColorScheme.fromSeed(seedColor: _semilla, brightness: brillo);
  return ThemeData(
    colorScheme: colores,
    useMaterial3: true,
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colores.outlineVariant),
      ),
    ),
  );
}

class BancoApp extends StatelessWidget {
  const BancoApp({super.key, required this.api});

  final Api api;

  @override
  Widget build(BuildContext context) => ApiScope(
        api: api,
        child: MaterialApp(
          title: 'Banco COBOL',
          debugShowCheckedModeBanner: false,
          theme: _tema(Brightness.light),
          darkTheme: _tema(Brightness.dark),
          locale: const Locale('es', 'AR'),
          supportedLocales: const [Locale('es', 'AR'), Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const _Raiz(),
        ),
      );
}

/// Login o pantalla principal segun haya sesion.
class _Raiz extends StatelessWidget {
  const _Raiz();

  @override
  Widget build(BuildContext context) {
    final usuario = ApiScope.of(context).usuario;
    return usuario == null ? const LoginPantalla() : InicioPantalla(key: ValueKey(usuario.usuario));
  }
}
