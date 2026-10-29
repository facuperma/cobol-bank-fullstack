// Piezas compartidas por las pantallas: acceso a la sesion, campos con
// validacion, botones con estado de carga y mensajes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'formato.dart';

/// Da acceso a la sesion (Api) desde cualquier pantalla.
class ApiScope extends InheritedNotifier<Api> {
  const ApiScope({super.key, required Api api, required super.child}) : super(notifier: api);

  static Api of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ApiScope>()!.notifier!;

  /// Sin suscribirse a cambios (para usar dentro de callbacks).
  static Api leer(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ApiScope>()!.notifier!;
}

/// Estado comun de una accion contra la API: carga y ultimo error.
mixin AccionAsync<T extends StatefulWidget> on State<T> {
  bool cargando = false;
  String? error;

  Api get api => ApiScope.leer(context);

  Future<R?> correr<R>(Future<R> Function() accion) async {
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      return await accion();
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.mensaje);
      return null;
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }
}

/// Contenido centrado con ancho maximo legible en pantallas grandes.
class Contenido extends StatelessWidget {
  const Contenido({super.key, required this.child, this.ancho = 720});

  final Widget child;
  final double ancho;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ancho),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      );
}

class BotonCarga extends StatelessWidget {
  const BotonCarga({super.key, required this.texto, required this.cargando, this.onPressed, this.icono});

  final String texto;
  final bool cargando;
  final VoidCallback? onPressed;
  final IconData? icono;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: cargando ? null : onPressed,
        icon: cargando
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icono ?? Icons.check),
        label: Text(texto),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
      );
}

class AvisoError extends StatelessWidget {
  const AvisoError(this.mensaje, {super.key});

  final String? mensaje;

  @override
  Widget build(BuildContext context) {
    if (mensaje == null) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.error_outline, color: c.onErrorContainer),
        const SizedBox(width: 12),
        Expanded(child: Text(mensaje!, style: TextStyle(color: c.onErrorContainer))),
      ]),
    );
  }
}

void avisar(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating));
}

Future<bool> confirmar(BuildContext context, String titulo, String texto, {String accion = 'Confirmar'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(accion)),
        ],
      ),
    ) ??
    false;

// --- Campos ------------------------------------------------------------------

const espacio = SizedBox(height: 16);

class CampoCuenta extends StatelessWidget {
  const CampoCuenta({super.key, required this.controller, this.etiqueta = 'Número de cuenta'});

  final TextEditingController controller;
  final String etiqueta;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: etiqueta, prefixIcon: const Icon(Icons.credit_card)),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
        validator: (v) => (v == null || v.isEmpty) ? 'Ingrese el número de cuenta' : null,
      );
}

class CampoPin extends StatelessWidget {
  const CampoPin({super.key, required this.controller, this.etiqueta = 'PIN', this.validar});

  final TextEditingController controller;
  final String etiqueta;
  final String? Function(String)? validar;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: etiqueta, prefixIcon: const Icon(Icons.pin_outlined)),
        keyboardType: TextInputType.number,
        obscureText: true,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
        validator: (v) {
          if (v == null || v.length != 4) return 'El PIN tiene 4 dígitos';
          return validar?.call(v);
        },
      );
}

class CampoImporte extends StatelessWidget {
  const CampoImporte({super.key, required this.controller, this.etiqueta = 'Importe', this.permiteCero = false});

  final TextEditingController controller;
  final String etiqueta;
  final bool permiteCero;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: etiqueta, prefixText: r'$ '),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        validator: (v) {
          if (permiteCero && (v == null || v.trim().isEmpty)) return null;
          final n = normalizarImporte(v ?? '');
          if (n == null) return 'Importe inválido (hasta 2 decimales)';
          if (!permiteCero && esCero(n)) return 'El importe debe ser mayor a cero';
          return null;
        },
      );
}

/// Campo de fecha que abre el calendario.
class CampoFecha extends StatelessWidget {
  const CampoFecha({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.onCambio,
    this.primera,
    this.ultima,
  });

  final String etiqueta;
  final DateTime? valor;
  final ValueChanged<DateTime> onCambio;
  final DateTime? primera;
  final DateTime? ultima;

  @override
  Widget build(BuildContext context) => FormField<DateTime>(
        initialValue: valor,
        validator: (_) => valor == null ? 'Elija una fecha' : null,
        builder: (estado) => InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () async {
            final elegida = await showDatePicker(
              context: context,
              initialDate: valor ?? ultima ?? DateTime.now(),
              firstDate: primera ?? DateTime(1900),
              lastDate: ultima ?? DateTime(2100),
            );
            if (elegida != null) {
              onCambio(elegida);
              estado.didChange(elegida);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: etiqueta,
              prefixIcon: const Icon(Icons.event),
              errorText: estado.errorText,
            ),
            isEmpty: valor == null,
            child: Text(valor == null ? '' : fecha(valor!)),
          ),
        ),
      );
}

class ChipEstado extends StatelessWidget {
  const ChipEstado(this.texto, {super.key, required this.bueno});

  final String texto;
  final bool bueno;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final fondo = bueno ? c.secondaryContainer : c.errorContainer;
    final frente = bueno ? c.onSecondaryContainer : c.onErrorContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(color: frente, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

ChipEstado chipCuenta(String estado) => switch (estado) {
      'abierta' => const ChipEstado('Abierta', bueno: true),
      'bloqueada' => const ChipEstado('Bloqueada', bueno: false),
      _ => const ChipEstado('Cerrada', bueno: false),
    };
