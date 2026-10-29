// Deposito, retiro y transferencia. Las reglas (PIN, limite diario, saldo,
// bloqueo) las aplica el nucleo COBOL; aca solo se valida el formato.

import 'package:flutter/material.dart';

import '../api.dart';
import '../comun.dart';
import '../formato.dart';

enum TipoOperacion { deposito, retiro, transferencia }

class OperacionesPantalla extends StatelessWidget {
  const OperacionesPantalla({super.key});

  @override
  Widget build(BuildContext context) => const DefaultTabController(
        length: 3,
        child: Column(children: [
          TabBar(tabs: [
            Tab(text: 'Depósito', icon: Icon(Icons.south_west)),
            Tab(text: 'Retiro', icon: Icon(Icons.north_east)),
            Tab(text: 'Transferencia', icon: Icon(Icons.swap_horiz)),
          ]),
          Expanded(
            child: TabBarView(children: [
              FormularioOperacion(tipo: TipoOperacion.deposito),
              FormularioOperacion(tipo: TipoOperacion.retiro),
              FormularioOperacion(tipo: TipoOperacion.transferencia),
            ]),
          ),
        ]),
      );
}

class FormularioOperacion extends StatefulWidget {
  const FormularioOperacion({super.key, required this.tipo, this.cuenta});

  final TipoOperacion tipo;
  final String? cuenta;

  @override
  State<FormularioOperacion> createState() => _FormularioOperacionState();
}

class _FormularioOperacionState extends State<FormularioOperacion>
    with AccionAsync, AutomaticKeepAliveClientMixin {
  final _form = GlobalKey<FormState>();
  late final _cuenta = TextEditingController(text: widget.cuenta);
  final _pin = TextEditingController();
  final _destino = TextEditingController();
  final _importe = TextEditingController();
  Resultado? _resultado;

  @override
  bool get wantKeepAlive => true;

  bool get _conPin => widget.tipo != TipoOperacion.deposito;

  String get _accion => switch (widget.tipo) {
        TipoOperacion.deposito => 'Depositar',
        TipoOperacion.retiro => 'Retirar',
        TipoOperacion.transferencia => 'Transferir',
      };

  Future<void> _confirmar() async {
    if (!_form.currentState!.validate()) return;
    final importe = normalizarImporte(_importe.text)!;
    final destino = widget.tipo == TipoOperacion.transferencia ? ' a la cuenta ${_destino.text}' : '';
    final ok = await confirmar(context, '$_accion ${pesos(importe)}',
        '¿Confirma la operación sobre la cuenta ${_cuenta.text}$destino?', accion: _accion);
    if (!ok) return;

    setState(() => _resultado = null);
    final r = await correr(() => switch (widget.tipo) {
          TipoOperacion.deposito => api.deposito(_cuenta.text, importe),
          TipoOperacion.retiro => api.retiro(_cuenta.text, _pin.text, importe),
          TipoOperacion.transferencia => api.transferencia(_cuenta.text, _pin.text, _destino.text, importe),
        });
    // El PIN no queda escrito despues de cada intento.
    _pin.clear();
    if (r != null) {
      setState(() => _resultado = r);
      _importe.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = Theme.of(context);
    return ListView(children: [
      Contenido(
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_resultado != null) _TarjetaResultado(_resultado!),
            AvisoError(error),
            CampoCuenta(
              controller: _cuenta,
              etiqueta: widget.tipo == TipoOperacion.transferencia ? 'Cuenta de origen' : 'Número de cuenta',
            ),
            if (_conPin) ...[espacio, CampoPin(controller: _pin)],
            if (widget.tipo == TipoOperacion.transferencia) ...[
              espacio,
              CampoCuenta(controller: _destino, etiqueta: 'Cuenta de destino'),
            ],
            espacio,
            CampoImporte(controller: _importe),
            if (widget.tipo == TipoOperacion.retiro)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Límite de retiro: \$ 500,00 por cuenta y por día.',
                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ),
            const SizedBox(height: 24),
            BotonCarga(texto: _accion, cargando: cargando, onPressed: _confirmar),
          ]),
        ),
      ),
    ]);
  }
}

class _TarjetaResultado extends StatelessWidget {
  const _TarjetaResultado(this.r);

  final Resultado r;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card(
      color: c.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.check_circle, color: c.onSecondaryContainer, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.mensaje.split('.').first, style: TextStyle(color: c.onSecondaryContainer, fontWeight: FontWeight.w600)),
              Text('Saldo: ${pesos(r.saldo)}', style: TextStyle(color: c.onSecondaryContainer)),
              Text('Operación N° ${r.operacion}',
                  style: TextStyle(color: c.onSecondaryContainer, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }
}
