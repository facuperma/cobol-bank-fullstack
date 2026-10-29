import 'package:flutter/material.dart';

import '../comun.dart';

class LoginPantalla extends StatefulWidget {
  const LoginPantalla({super.key});

  @override
  State<LoginPantalla> createState() => _LoginPantallaState();
}

class _LoginPantallaState extends State<LoginPantalla> with AccionAsync {
  final _form = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  late final _servidor = TextEditingController(text: ApiScope.leer(context).baseUrl);
  bool _verServidor = false;

  Future<void> _ingresar() async {
    if (!_form.currentState!.validate()) return;
    api.baseUrl = _servidor.text.trim();
    await correr(() => api.login(_usuario.text.trim(), _clave.text));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.account_balance, size: 56, color: t.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('Banco COBOL', textAlign: TextAlign.center, style: t.textTheme.headlineMedium),
                    Text('Acceso para empleados',
                        textAlign: TextAlign.center,
                        style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 32),
                    AvisoError(error),
                    TextFormField(
                      controller: _usuario,
                      decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person_outline)),
                      textCapitalization: TextCapitalization.characters,
                      autofillHints: const [AutofillHints.username],
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el usuario' : null,
                    ),
                    espacio,
                    TextFormField(
                      controller: _clave,
                      decoration: const InputDecoration(labelText: 'Clave', prefixIcon: Icon(Icons.lock_outline)),
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _ingresar(),
                      validator: (v) => (v == null || v.isEmpty) ? 'Ingrese la clave' : null,
                    ),
                    const SizedBox(height: 24),
                    BotonCarga(texto: 'Ingresar', icono: Icons.login, cargando: cargando, onPressed: _ingresar),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => setState(() => _verServidor = !_verServidor),
                      icon: const Icon(Icons.dns_outlined, size: 18),
                      label: const Text('Servidor'),
                    ),
                    if (_verServidor)
                      TextFormField(
                        controller: _servidor,
                        decoration: const InputDecoration(
                          labelText: 'Dirección de la API',
                          helperText: 'Ej.: http://192.168.0.10:8000',
                        ),
                        keyboardType: TextInputType.url,
                        validator: (v) {
                          final uri = Uri.tryParse(v?.trim() ?? '');
                          return (uri == null || !uri.hasScheme || uri.host.isEmpty) ? 'Dirección inválida' : null;
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
